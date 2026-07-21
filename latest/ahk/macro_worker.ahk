#Requires AutoHotkey v2.0
; macro_worker.ahk (AutoHotkey v2 port)
;
; A tiny, persistent AHK helper. It does NOT know about "Roll Uppercut" or
; "Server Join" - it only knows how to execute one primitive input command
; at a time (send_key, click, move_mouse, etc). All the *sequencing* and
; *timing* (Q, then Ctrl+RightClick, then wait 0.3s, etc) still lives in
; Python, in macros.py, exactly like today. This script just replaces the
; bottom layer (winutil.py's pynput/keyboard calls) with real AHK Send/Click,
; which is the part that was actually breaking.
;
; Python talks to this script via WM_COPYDATA (SendMessage), which is
; synchronous and sub-millisecond, so your existing time.sleep() calls
; between steps still control the real timing - this is not a "spawn a new
; process per keypress" design.
;
; Same command protocol as the v1.1 script - ahk_bridge.py does not need
; any changes. The script has no #Persistent directive because v2 dropped
; it: a script that registers OnMessage/SetTimer callbacks (as this one
; does) stays resident automatically without one.

#SingleInstance Force
SendMode "Input"           ; matches AHK's fast/reliable default Send mode

; Log file path is passed in as the 2nd script arg (see ahk_bridge.py) so
; both sides write to the exact same file, next to the app. Falls back to
; a sensible default if launched standalone for testing.
LogFile := A_Args.Length >= 2 ? A_Args[2] : A_ScriptDir . "\..\roblox_macro_suite_debug.log"

LogMsg(msg) {
    global LogFile
    ts := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    FileAppend(ts . "  [macro_worker.ahk]  " . msg . "`n", LogFile)
}

LogMsg("worker starting, pid=" . DllCall("GetCurrentProcessId"))

; No hwnd handshake needed here - every AHK script has an automatically
; created main window (hidden by default) as soon as it's running. Python
; finds it by matching this process's PID via EnumWindows, so there's
; nothing version-specific for this script to depend on.

OnMessage(0x4A, ReceiveCopyData)  ; WM_COPYDATA

; ----- Watchdog: exit if the Python app disappears -----
; ahk_bridge.py normally kills us cleanly via stop_worker() on exit, but
; that only runs on a clean shutdown. If Python is killed hard (Task
; Manager, crash, power loss to the GUI process, etc.) that never fires,
; and this script would otherwise be left running forever, still able to
; send input to Roblox with nothing driving it. So: Python passes its own
; PID as the 1st script arg, and we poll every 2s to make sure it's still
; alive; if not, we exit ourselves.
ParentPID := A_Args.Length >= 1 ? A_Args[1] : 0
if (ParentPID)
    SetTimer(CheckParentAlive, 2000)

CheckParentAlive() {
    global ParentPID
    if !ProcessExist(ParentPID) {
        LogMsg("parent process (pid=" . ParentPID . ") gone - exiting")
        ExitApp()
    }
}

ReceiveCopyData(wParam, lParam, msg, hwnd) {
    ; COPYDATASTRUCT: dwData (ptr), cbData (uint, ptr-aligned), lpData (ptr)
    ; - same offset math as the v1 version, just using NumGet's explicit
    ; type param instead of v1's implicit default.
    StringAddress := NumGet(lParam, 2 * A_PtrSize, "UPtr")
    cmd := StrGet(StringAddress, "UTF-8")
    HandleCommand(cmd)
    return true
}

; Command format: "action|arg1|arg2"
HandleCommand(cmd) {
    parts := StrSplit(cmd, "|")
    action := parts[1]

    if (action = "send_key") {
        Send("{" . parts[2] . "}")

    } else if (action = "key_down") {
        Send("{" . parts[2] . " down}")

    } else if (action = "key_up") {
        Send("{" . parts[2] . " up}")

    } else if (action = "click") {
        ; click at current cursor position, matches AHK `Click, Right`
        Click(parts[2])

    } else if (action = "mouse_down") {
        Click(parts[2] . " down")

    } else if (action = "mouse_up") {
        Click(parts[2] . " up")

    } else if (action = "move_mouse") {
        MouseMove(parts[2], parts[3], 0)

    } else if (action = "control_click") {
        ; ControlName, WinTitle (WinTitle optional - defaults to Roblox)
        target_win := (parts.Length >= 3 && parts[3] != "") ? parts[3] : "ahk_exe RobloxPlayerBeta.exe"
        ; v2 has no ErrorLevel for this - ControlClick throws instead, so
        ; the success/failure log messages move into a try/catch.
        try {
            ControlClick(parts[2], target_win)
            LogMsg("control_click OK - clicked [" . parts[2] . "] in [" . target_win . "]")
        } catch as err {
            LogMsg("control_click FAILED - control [" . parts[2] . "] or window [" . target_win . "] not found (" . err.Message . ")")
        }

    } else if (action = "m_feint") {
        ; Runs the ENTIRE original MFeint sequence natively inside AHK,
        ; exactly like the standalone `1::` hotkey did - instead of
        ; Python driving 4 separate commands with time.sleep() calls
        ; trying to fake AHK's default timing. This worker normally runs
        ; under SendMode Input with no delay (fast, for every other
        ; macro); we drop back to AHK's classic SendEvent defaults
        ; (~10ms KeyDelay/MouseDelay - never overridden in this script)
        ; just for this one sequence, then restore Input mode afterward
        ; so nothing else is affected.
        SendMode "Event"
        Send "{RButton}"
        Send "{q}"
        Click()
        Send "{RButton}"
        SendMode "Input"

    } else if (action = "send_text") {
        ; {Text} mode - literal Unicode injection, bypasses VK_SPACE hooks
        ; (this is the exact mechanism the original join-message macro used)
        SendInput("{Text}" . parts[2])

    } else if (action = "join_start") {
        ; parts: msgboxX|msgboxY|sendX|sendY|joinX|joinY|rejoinX|rejoinY|quickFlag|message
        global JN_Active, JN_JoinBtnX, JN_JoinBtnY, JN_RejoinBtnX, JN_RejoinBtnY, JN_QuickMode
        JN_MsgBoxX := parts[2], JN_MsgBoxY := parts[3]
        JN_SendBtnX := parts[4], JN_SendBtnY := parts[5]
        JN_JoinBtnX := parts[6], JN_JoinBtnY := parts[7]
        JN_RejoinBtnX := parts[8], JN_RejoinBtnY := parts[9]
        ; "Quick join + prev" reuses the real Previous Server button, which
        ; the Previous Server loop double-clicks (see PN_ToggleTick below) -
        ; so the rejoin tick needs to double-click too when this is set,
        ; instead of always single-clicking like the normal rejoin path.
        JN_QuickMode := (parts[10] = "1")
        JN_Message := parts[11]

        JN_Active := true

        MouseMove(JN_MsgBoxX, JN_MsgBoxY, 5)
        Click()
        Click()
        Sleep(100)

        SendInput("{Text}" . JN_Message)

        MouseMove(JN_SendBtnX, JN_SendBtnY, 5)
        Click()
        Sleep(200)
        MouseMove(JN_JoinBtnX, JN_JoinBtnY, 5)
        Click()

        SetTimer(JN_ToggleTick, -10)

    } else if (action = "join_stop") {
        global JN_Active, JN_QuickMode
        JN_Active := false
        JN_QuickMode := false
        SetTimer(JN_ToggleTick, 0)

    } else if (action = "prev_start") {
        ; parts: prevX|prevY|joinX|joinY
        global PN_Active, PN_PrevBtnX, PN_PrevBtnY, PN_JoinBtnX, PN_JoinBtnY
        PN_PrevBtnX := parts[2], PN_PrevBtnY := parts[3]
        PN_JoinBtnX := parts[4], PN_JoinBtnY := parts[5]
        PN_Active := true
        SetTimer(PN_ToggleTick, -10)

    } else if (action = "prev_stop") {
        global PN_Active
        PN_Active := false
        SetTimer(PN_ToggleTick, 0)

    } else {
        LogMsg("unknown command: " . cmd)
    }
}

; ----- Server Join loop (native AHK, matches original JN_ToggleTick) -----
JN_Active := false
JN_JoinBtnX := 0
JN_JoinBtnY := 0
JN_RejoinBtnX := 0
JN_RejoinBtnY := 0
JN_QuickMode := false

JN_ToggleTick() {
    global JN_Active, JN_RejoinBtnX, JN_RejoinBtnY, JN_QuickMode, JN_JoinBtnX, JN_JoinBtnY
    if (!JN_Active)
        return

    MouseMove(JN_RejoinBtnX, JN_RejoinBtnY, 5)
    Click()
    ; Quick join + prev clicks the real Previous Server button, which
    ; needs a double-click to register (see PN_ToggleTick) - the normal
    ; rejoin-box button only needs one.
    if (JN_QuickMode)
        Click()
    Sleep(200)

    MouseMove(JN_JoinBtnX, JN_JoinBtnY, 5)
    Click()
    Sleep(200)

    if (JN_Active)
        SetTimer(JN_ToggleTick, -10)
}

; ----- Previous Server loop (native AHK, matches original PN_ToggleTick) -----
PN_Active := false
PN_PrevBtnX := 0
PN_PrevBtnY := 0
PN_JoinBtnX := 0
PN_JoinBtnY := 0

PN_ToggleTick() {
    global PN_Active, PN_PrevBtnX, PN_PrevBtnY, PN_JoinBtnX, PN_JoinBtnY
    if (!PN_Active)
        return

    MouseMove(PN_PrevBtnX, PN_PrevBtnY, 5)
    Click()
    Click()
    Sleep(200)

    MouseMove(PN_JoinBtnX, PN_JoinBtnY, 5)
    Click()
    Sleep(200)

    if (PN_Active)
        SetTimer(PN_ToggleTick, -10)
}

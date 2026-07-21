if not A_IsAdmin hi hi hi
{
    Run *RunAs "%A_ScriptFullPath%"
    ExitApp
}

#SingleInstance, Force
#Persistent
SetBatchLines, -1

; ===== SETTINGS FILE =====
SettingsFile := A_ScriptDir . "\settings.ini"
HtmlTemplateFile := A_ScriptDir . "\gui_template.html"
HtmlRenderFile := A_ScriptDir . "\gui_render.html"

; ===== DEFAULTS (used only if no settings file exists yet) =====
TriggerKey := ""
SpamKey := "7"
SpamDelay := 10
ClickTriggerKey := ""
ClickControlName := "Button2"
RollTriggerKey := ""
RollParryTriggerKey := ""
SHFeintTriggerKey := ""
MFeintTriggerKey := ""

; ===== Server Join macro defaults =====
JoinTriggerKey := ""
JoinMessage := "Foolhardy auburn farmer"

; ===== Server Join click coordinates (not user-editable via GUI, edit here if needed) =====
JN_MsgBoxX := 1451
JN_MsgBoxY := 177
JN_SendBtnX := 1139
JN_SendBtnY := 240
JN_JoinBtnX := 957
JN_JoinBtnY := 626
JN_RejoinBtnX := 1150
JN_RejoinBtnY := 123
JN_RejoinLoops := 10

; ===== Previous Server macro defaults =====
PrevTriggerKey := ""
PN_PrevBtnX := 843
PN_PrevBtnY := 124
PN_JoinBtnX := 957
PN_JoinBtnY := 626
PN_Loops := 10

; ===== Server Screenshot settings (not user-editable via GUI, edit here if needed) =====
SC_RegionX1 := 371
SC_RegionY1 := 12
SC_RegionX2 := 575
SC_RegionY2 := 30
SC_IntervalMs := 60000      ; how often to poll/refresh, in milliseconds
SC_RecaptureDelayMs := 80000  ; how long to wait after detecting a server change before grabbing a confirmation shot
SC_PsScript := A_ScriptDir . "\capture_screenshot.ps1"
SC_ScreenshotFile := A_ScriptDir . "\server_capture.png"
SC_HashOutFile := A_Temp . "\server_capture_hash.txt"
SC_LastHash := ""

; ===== Enable/disable defaults (all ON by default) =====
SpamEnabled := 1
ClickEnabled := 1
RollEnabled := 1
RollParryEnabled := 1
SHFeintEnabled := 1
MFeintEnabled := 1
JoinEnabled := 1
PrevEnabled := 1
ScreenshotEnabled := 1

; ===== Script display names (fixed - not user-editable) =====
SpamName := "Key Spammer"
ClickName := "Clumsy Keybind"
RollName := "Roll Uppercut"
RollParryName := "Roll Parry"
SHFeintName := "Rising Star Feint"
MFeintName := "Mayhem Feint"
JoinName := "Server Join"
PrevName := "Previous Server Join"
ScreenshotName := "Server Screenshot"

; ===== LOAD SAVED SETTINGS =====
IfExist, %SettingsFile%
{
    IniRead, TriggerKey, %SettingsFile%, Settings, TriggerKey, %TriggerKey%
    IniRead, SpamKey, %SettingsFile%, Settings, SpamKey, %SpamKey%
    IniRead, SpamDelay, %SettingsFile%, Settings, SpamDelay, %SpamDelay%
    IniRead, ClickTriggerKey, %SettingsFile%, Settings, ClickTriggerKey, %ClickTriggerKey%
    IniRead, ClickControlName, %SettingsFile%, Settings, ClickControlName, %ClickControlName%
    IniRead, RollTriggerKey, %SettingsFile%, Settings, RollTriggerKey, %RollTriggerKey%
    IniRead, RollParryTriggerKey, %SettingsFile%, Settings, RollParryTriggerKey, %RollParryTriggerKey%
    IniRead, SHFeintTriggerKey, %SettingsFile%, Settings, SHFeintTriggerKey, %SHFeintTriggerKey%
    IniRead, MFeintTriggerKey, %SettingsFile%, Settings, MFeintTriggerKey, %MFeintTriggerKey%
    IniRead, JoinTriggerKey, %SettingsFile%, Settings, JoinTriggerKey, %JoinTriggerKey%
    IniRead, JoinMessage, %SettingsFile%, Settings, JoinMessage, %JoinMessage%
    DebugLog("Startup IniRead: JoinMessage=[" . JoinMessage . "] Len=" . StrLen(JoinMessage))
    IniRead, PrevTriggerKey, %SettingsFile%, Settings, PrevTriggerKey, %PrevTriggerKey%

    ; ===== Blank trigger keys are a valid "unbound" state now (see
    ; Register*Hotkey functions below, which simply skip registering a
    ; hotkey when the key name is blank instead of throwing "Invalid key
    ; name"). No self-heal needed here anymore. =====

    IniRead, SpamEnabled, %SettingsFile%, Enabled, Spam, %SpamEnabled%
    IniRead, ClickEnabled, %SettingsFile%, Enabled, Click, %ClickEnabled%
    IniRead, RollEnabled, %SettingsFile%, Enabled, Roll, %RollEnabled%
    IniRead, RollParryEnabled, %SettingsFile%, Enabled, RollParry, %RollParryEnabled%
    IniRead, SHFeintEnabled, %SettingsFile%, Enabled, SHFeint, %SHFeintEnabled%
    IniRead, MFeintEnabled, %SettingsFile%, Enabled, MFeint, %MFeintEnabled%
    IniRead, JoinEnabled, %SettingsFile%, Enabled, Join, %JoinEnabled%
    IniRead, PrevEnabled, %SettingsFile%, Enabled, Prev, %PrevEnabled%
    IniRead, ScreenshotEnabled, %SettingsFile%, Enabled, Screenshot, %ScreenshotEnabled%
}

; ===== Make the embedded WebBrowser control render in modern (IE11 edge) mode instead of legacy IE7 mode =====
SplitPath, A_AhkPath, HostExeName
RegWrite, REG_DWORD, HKCU, Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION, %HostExeName%, 0x2AF9

CurrentHotkey := ""
RegisterHotkey(TriggerKey, false, SpamEnabled)

CurrentClickHotkey := ""
RegisterClickHotkey(ClickTriggerKey, false, ClickEnabled)

CurrentRollHotkey := ""
RegisterRollHotkey(RollTriggerKey, false, RollEnabled)

CurrentRollParryHotkey := ""
RegisterRollParryHotkey(RollParryTriggerKey, false, RollParryEnabled)

CurrentSHFeintHotkey := ""
RegisterSHFeintHotkey(SHFeintTriggerKey, false, SHFeintEnabled)

CurrentMFeintHotkey := ""
RegisterMFeintHotkey(MFeintTriggerKey, false, MFeintEnabled)

CurrentJoinHotkey := ""
RegisterJoinHotkey(JoinTriggerKey, false, JoinEnabled)

CurrentPrevHotkey := ""
RegisterPrevHotkey(PrevTriggerKey, false, PrevEnabled)

; Start the automatic server screenshot loop (refreshes every SC_IntervalMs), unless disabled
if (ScreenshotEnabled)
    SetTimer, SC_CaptureScreenshot, %SC_IntervalMs%

; ===== BUILD GUI (HTML-based, rendered inside an embedded WebBrowser control) =====
RenderHtmlUi()

Gui, +Resize
Gui, Add, ActiveX, x0 y0 w900 h620 vWB, Shell.Explorer
WB.Navigate("file:///" . StrReplace(HtmlRenderFile, "\", "/"))
ComObjConnect(WB, "WB_")

Gui, Show, w900 h620, Roblox Macro Suite
Return

; ===== Build the rendered HTML from the template + current settings, then write it to disk =====
RenderHtmlUi() {
    global HtmlTemplateFile, HtmlRenderFile
    global TriggerKey, SpamKey, SpamDelay, ClickTriggerKey, ClickControlName
    global RollTriggerKey, RollParryTriggerKey, SHFeintTriggerKey, MFeintTriggerKey
    global JoinTriggerKey, JoinMessage, PrevTriggerKey
    global SpamEnabled, ClickEnabled, RollEnabled, RollParryEnabled, SHFeintEnabled, MFeintEnabled, JoinEnabled, PrevEnabled, ScreenshotEnabled
    global SpamName, ClickName, RollName, RollParryName, SHFeintName, MFeintName, JoinName, PrevName, ScreenshotName
    global SC_ScreenshotFile

    FileRead, Html, %HtmlTemplateFile%

    Html := StrReplace(Html, "__TRIGGER_KEY__", HtmlEscape(TriggerKey))
    Html := StrReplace(Html, "__SPAM_KEY__", HtmlEscape(SpamKey))
    Html := StrReplace(Html, "__SPAM_DELAY__", HtmlEscape(SpamDelay))
    Html := StrReplace(Html, "__CLICK_TRIGGER__", HtmlEscape(ClickTriggerKey))
    Html := StrReplace(Html, "__CLICK_CONTROL__", HtmlEscape(ClickControlName))
    Html := StrReplace(Html, "__ROLL_TRIGGER__", HtmlEscape(RollTriggerKey))
    Html := StrReplace(Html, "__ROLLPARRY_TRIGGER__", HtmlEscape(RollParryTriggerKey))
    Html := StrReplace(Html, "__SHFEINT_TRIGGER__", HtmlEscape(SHFeintTriggerKey))
    Html := StrReplace(Html, "__MFEINT_TRIGGER__", HtmlEscape(MFeintTriggerKey))
    Html := StrReplace(Html, "__JOIN_TRIGGER__", HtmlEscape(JoinTriggerKey))
    Html := StrReplace(Html, "__JOIN_MESSAGE__", HtmlEscape(JoinMessage))
    Html := StrReplace(Html, "__PREV_TRIGGER__", HtmlEscape(PrevTriggerKey))

    Html := StrReplace(Html, "__SPAM_NAME__", HtmlEscape(SpamName))
    Html := StrReplace(Html, "__CLICK_NAME__", HtmlEscape(ClickName))
    Html := StrReplace(Html, "__ROLL_NAME__", HtmlEscape(RollName))
    Html := StrReplace(Html, "__ROLLPARRY_NAME__", HtmlEscape(RollParryName))
    Html := StrReplace(Html, "__SHFEINT_NAME__", HtmlEscape(SHFeintName))
    Html := StrReplace(Html, "__MFEINT_NAME__", HtmlEscape(MFeintName))
    Html := StrReplace(Html, "__JOIN_NAME__", HtmlEscape(JoinName))
    Html := StrReplace(Html, "__PREV_NAME__", HtmlEscape(PrevName))
    Html := StrReplace(Html, "__SCREENSHOT_NAME__", HtmlEscape(ScreenshotName))

    Html := StrReplace(Html, "__STATUS_SPAM__", "Status: Hold [" . KeyLabel(TriggerKey) . "] to spam [" . SpamKey . "]")
    Html := StrReplace(Html, "__STATUS_CLICK__", "Status: Press [" . KeyLabel(ClickTriggerKey) . "] to click [" . ClickControlName . "] (Roblox only)")
    Html := StrReplace(Html, "__STATUS_ROLL__", "Status: Press [" . KeyLabel(RollTriggerKey) . "] to Roll Uppercut (Roblox only)")
    Html := StrReplace(Html, "__STATUS_ROLLPARRY__", "Status: Press [" . KeyLabel(RollParryTriggerKey) . "] to Roll Parry (Roblox only)")
    Html := StrReplace(Html, "__STATUS_SHFEINT__", "Status: Press [" . KeyLabel(SHFeintTriggerKey) . "] to Rising Star Feint (Roblox only)")
    Html := StrReplace(Html, "__STATUS_MFEINT__", "Status: Press [" . KeyLabel(MFeintTriggerKey) . "] to Mayhem Feint (Roblox only)")
    Html := StrReplace(Html, "__STATUS_JOIN__", "Status: Press [" . KeyLabel(JoinTriggerKey) . "] to send [" . JoinMessage . "] and join (Roblox only)")
    Html := StrReplace(Html, "__STATUS_PREV__", "Status: Press [" . KeyLabel(PrevTriggerKey) . "] to rejoin Previous Server (Roblox only)")

    Html := StrReplace(Html, "__CHK_SPAM__", (SpamEnabled ? "checked" : ""))
    Html := StrReplace(Html, "__CHK_CLICK__", (ClickEnabled ? "checked" : ""))
    Html := StrReplace(Html, "__CHK_ROLL__", (RollEnabled ? "checked" : ""))
    Html := StrReplace(Html, "__CHK_ROLLPARRY__", (RollParryEnabled ? "checked" : ""))
    Html := StrReplace(Html, "__CHK_SHFEINT__", (SHFeintEnabled ? "checked" : ""))
    Html := StrReplace(Html, "__CHK_MFEINT__", (MFeintEnabled ? "checked" : ""))
    Html := StrReplace(Html, "__CHK_JOIN__", (JoinEnabled ? "checked" : ""))
    Html := StrReplace(Html, "__CHK_PREV__", (PrevEnabled ? "checked" : ""))
    Html := StrReplace(Html, "__CHK_SCREENSHOT__", (ScreenshotEnabled ? "checked" : ""))

    ScreenshotSrc := ""
    if FileExist(SC_ScreenshotFile)
        ScreenshotSrc := "file:///" . StrReplace(SC_ScreenshotFile, "\", "/")
    Html := StrReplace(Html, "__SCREENSHOT_SRC__", ScreenshotSrc)

    FileDelete, %HtmlRenderFile%
    FileAppend, %Html%, %HtmlRenderFile%, UTF-8
}

HtmlEscape(str) {
    str := StrReplace(str, "&", "&amp;")
    str := StrReplace(str, "<", "&lt;")
    str := StrReplace(str, ">", "&gt;")
    str := StrReplace(str, """", "&quot;")
    return str
}

; ===== Displays "not set" instead of an empty bracket for unbound trigger keys =====
KeyLabel(K) {
    return (K = "" ? "not set" : K)
}

; ===== Keyboard-layout safety net for the backslash-area key. =====
; On ISO/UK keyboards, the key AHK names "\" (OEM_5, top-right near Enter)
; and the extra ISO key AHK names "<>" are two different physical keys, and
; depending on layout/driver it's not always obvious which one a person is
; actually pressing when they mean "backslash". Rather than requiring the
; person to guess correctly, every Register*Hotkey function below binds
; BOTH names whenever either one is set, so either physical key fires the
; same macro. This function returns the list of AHK key names to register
; for a given saved KeyName.
KeyAliases(KeyName) {
    if (KeyName = "\")
        return ["\", "<>"]
    if (KeyName = "<>")
        return ["<>", "\"]
    return [KeyName]
}

; ===== Keep the WebBrowser control filling the window when resized =====
GuiSize:
    if (A_EventInfo = 1) ; minimized
        return
    GuiControl, Move, WB, % "w" . A_GuiWidth . " h" . A_GuiHeight
Return

; ===== WebBrowser event: intercept our custom ahk:// "links" instead of letting it navigate =====
; (Kept as a safety net, but the page no longer actually navigates to ahk://
; URLs - see WB_TitleChange below, which is what the GUI now uses.)
WB_BeforeNavigate2(EventObj, pDisp, URL, Flags, TargetFrameName, PostData, Headers, ByRef Cancel) {
    if (SubStr(URL, 1, 6) = "ahk://") {
        Cancel := true
        ProcessAhkCommand(SubStr(URL, 7))
    }
}

; ===== WebBrowser event: the page sends commands by setting document.title.
; This fires synchronously with no navigation involved at all, so there's
; nothing for IE to fail to resolve - this is what fixes the
; "webpage cannot be displayed" error you were hitting on every button click. =====
global LastTitleCmd := ""
global LastTitleCmdTick := 0

WB_TitleChange(Text) {
    global LastTitleCmd, LastTitleCmdTick
    DebugLog("WB_TitleChange fired. Text=[" . Text . "]")
    if (SubStr(Text, 1, 6) = "ahk://") {
        ; The embedded IE WebBrowser control fires TitleChange TWICE for a
        ; single document.title assignment (a known quirk). Without this
        ; guard every button click runs its command twice - most visibly
        ; doubling "Invalid key name" popups and double-registering hotkeys
        ; on Save. Ignore an identical command seen again within 300ms.
        if (Text = LastTitleCmd) and (A_TickCount - LastTitleCmdTick < 300) {
            DebugLog("Duplicate WB_TitleChange ignored. Text=[" . Text . "]")
            return
        }
        LastTitleCmd := Text
        LastTitleCmdTick := A_TickCount
        ProcessAhkCommand(SubStr(Text, 7))
    }
}

; ===== Temporary debug logger - writes to debug.log next to the script.
; Delete the DebugLog calls (or this function) once things are confirmed working. =====
DebugLog(Msg) {
    FileAppend, % A_Now . " - " . Msg . "`n", % A_ScriptDir . "\debug.log", UTF-8
}

ProcessAhkCommand(Path) {
    DebugLog("ProcessAhkCommand called. Path=[" . Path . "]")
    QueryPos := InStr(Path, "?")
    if (QueryPos) {
        Action := SubStr(Path, 1, QueryPos - 1)
        Query := SubStr(Path, QueryPos + 1)
    } else {
        Action := Path
        Query := ""
    }
    Params := ParseQuery(Query)
    DebugLog("Parsed Action=[" . Action . "] Query=[" . Query . "]")
    if (Params.HasKey("joinmessage"))
        DebugLog("Params[joinmessage] immediately after ParseQuery=[" . Params["joinmessage"] . "] Len=" . StrLen(Params["joinmessage"]))

    if (Action = "setkey") {
        global KeyCaptureInProgress
        if (KeyCaptureInProgress) {
            DebugLog("setkey ignored at dispatch - capture already in progress. Target=[" . Params["target"] . "]")
        } else {
            KeyCaptureInProgress := true
            Target := Params["target"]
            SetTimer, % Func("DoSetKey").Bind(Target), -10
        }
    } else if (Action = "toggle")
        DoToggle(Params["macro"])
    else if (Action = "save")
        DoSave(Params)
    else if (Action = "setjoinmessage")
        DoSetJoinMessage(Params["value"])
    else if (Action = "exit")
        ExitApp
}

ParseQuery(Query) {
    Result := {}
    Loop, Parse, Query, &
    {
        Pair := A_LoopField
        if (Pair = "")
            continue
        EqPos := InStr(Pair, "=")
        if (EqPos) {
            K := SubStr(Pair, 1, EqPos - 1)
            V := SubStr(Pair, EqPos + 1)
        } else {
            K := Pair
            V := ""
        }
        Result[UrlDecode(K)] := UrlDecode(V)
        if (UrlDecode(K) = "joinmessage")
            DebugLog("ParseQuery decoding joinmessage. Raw V=[" . V . "] Decoded=[" . UrlDecode(V) . "] Len=" . StrLen(UrlDecode(V)))
    }
    return Result
}

UrlDecode(str) {
    str := StrReplace(str, "+", " ")
    Out := ""
    Pos := 1
    Loop {
        NextPct := InStr(str, "%",, Pos)
        if (!NextPct) {
            Out .= SubStr(str, Pos)
            break
        }
        Out .= SubStr(str, Pos, NextPct - Pos)
        Hex := SubStr(str, NextPct + 1, 2)
        Out .= Chr(("0x" . Hex) + 0)
        Pos := NextPct + 3
    }
    return Out
}

; ===== Small helpers to push updates into the live WebBrowser DOM =====
SetVal(Id, Value) {
    global WB
    try WB.Document.getElementById(Id).value := Value
}

SetHtml(Id, Text) {
    global WB
    try WB.Document.getElementById(Id).innerText := Text
}

SetChecked(Id, State) {
    global WB
    try WB.Document.getElementById(Id).checked := State
}

SetImgSrc(Path) {
    global WB
    try {
        FileUrl := "file:///" . StrReplace(Path, "\", "/") . "?t=" . A_TickCount
        WB.Document.getElementById("ServerScreenshotImg").src := FileUrl
    }
}

; ===== "Set Key" flow - captures ANY keyboard key via wildcard hotkeys +
; A_ThisHotkey (see CaptureKeyPressed below), then pushes the actual AHK key
; NAME into the page. Deliberately NOT using the Input command: Input records
; the translated CHARACTER a key types, which on ISO/UK keyboards does not
; match the physical key AHK's Hotkey command binds to (e.g. the key that
; types "\" there is named "<>" by AutoHotkey) - so a captured "\" would
; silently bind to the wrong physical key and never fire. Capturing via
; A_ThisHotkey instead records the real, layout-independent key name.
;
; This must NOT run directly from inside the WB_TitleChange COM event
; handler (that caused earlier versions to return instantly instead of
; waiting for a keypress). ProcessAhkCommand schedules it via SetTimer with
; a bound function (Func("DoSetKey").Bind(Target)), which runs it on its own
; thread after the COM call has already returned.
global KeyCaptureInProgress := false

global CapturedHotkeyName := ""

DoSetKey(Target) {
    global KeyCaptureInProgress
    global CapturedHotkeyName

    InputIds := {Trigger: "TriggerKeyInput", SpamKey: "SpamKeyInput", Click: "ClickTriggerKeyInput"
        , Roll: "RollTriggerKeyInput", RollParry: "RollParryTriggerKeyInput", SHFeint: "SHFeintTriggerKeyInput"
        , MFeint: "MFeintTriggerKeyInput", Join: "JoinTriggerKeyInput", Prev: "PrevTriggerKeyInput"}
    StatusIds := {Trigger: "StatusText", SpamKey: "StatusText", Click: "ClickStatusText"
        , Roll: "RollStatusText", RollParry: "RollParryStatusText", SHFeint: "SHFeintStatusText"
        , MFeint: "MFeintStatusText", Join: "JoinStatusText", Prev: "PrevStatusText"}
    Labels := {Trigger: "Trigger", SpamKey: "Spam", Click: "Click Trigger", Roll: "Roll Uppercut"
        , RollParry: "Roll Parry", SHFeint: "Rising Star Feint", MFeint: "Mayhem Feint", Join: "Server Join", Prev: "Previous Server Join"}

    InputId := InputIds[Target]
    StatusId := StatusIds[Target]
    if (!InputId) {
        KeyCaptureInProgress := false
        return
    }

    SetInputsCapturing(true)
    SetHtml(StatusId, "Status: Press any key to set as " . Labels[Target] . " key... (Esc to cancel, auto-cancels in 3s)")
    DebugLog("DoSetKey waiting for input. Target=[" . Target . "]")

    ; ===== Curated list of AutoHotkey key NAMES (not characters) we listen
    ; for during capture. Using dynamic wildcard hotkeys + A_ThisHotkey (below
    ; in CaptureKeyPressed) instead of the Input command means we record the
    ; actual physical key AHK will later bind to, immune to keyboard-layout
    ; character translation. This is what fixes "\" on UK/ISO keyboards -
    ; the physical key that types "\" there is named "<>" by AutoHotkey, and
    ; only capturing the real key name lets the later Hotkey registration
    ; actually match the key the person is pressing. =====
    CaptureKeyList := ["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"
        , "0","1","2","3","4","5","6","7","8","9"
        , "F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12"
        , "Space","Tab","Enter","Escape","Backspace","Delete","Insert","Home","End","PgUp","PgDn"
        , "Up","Down","Left","Right"
        , "LShift","RShift","LCtrl","RCtrl","LAlt","RAlt","LWin","RWin","AppsKey","CapsLock"
        , "-","=","[","]",";","'","``",",",".","/","\","<>"
        , "LButton","RButton","MButton","XButton1","XButton2"
        , "Numpad0","Numpad1","Numpad2","Numpad3","Numpad4","Numpad5","Numpad6","Numpad7","Numpad8","Numpad9"
        , "NumpadAdd","NumpadSub","NumpadMult","NumpadDiv","NumpadEnter","NumpadDot"]

    CapturedHotkeyName := ""
    Hotkey, IfWinActive ; clear context so capture hotkeys fire globally, not just over Roblox
    for index, k in CaptureKeyList {
        try Hotkey, % "*" . k, CaptureKeyPressed, On
    }

    StartTick := A_TickCount
    Loop {
        if (CapturedHotkeyName != "")
            break
        if (A_TickCount - StartTick > 3000)
            break
        Sleep, 10
    }

    Hotkey, IfWinActive
    for index, k in CaptureKeyList {
        try Hotkey, % "*" . k, CaptureKeyPressed, Off
    }

    CapturedKey := CapturedHotkeyName
    DebugLog("DoSetKey captured. CapturedKey=[" . CapturedKey . "]")

    if (CapturedKey = "Escape") {
        SetHtml(StatusId, "Status: " . Labels[Target] . " key capture cancelled - click Set Key to try again")
    } else if (CapturedKey = "") {
        SetHtml(StatusId, "Status: " . Labels[Target] . " key capture timed out - click Set Key to try again")
    } else {
        SetVal(InputId, CapturedKey)
        SetHtml(StatusId, "Status: " . Labels[Target] . " key set to [" . CapturedKey . "] - click Save Settings")
    }

    SetInputsCapturing(false)
    KeyCaptureInProgress := false
}

; Fires once for whichever key the person pressed during capture - see the
; wildcard Hotkey registration loop in DoSetKey above.
CaptureKeyPressed:
    Name := A_ThisHotkey
    StringReplace, Name, Name, *,, All
    CapturedHotkeyName := Name
Return

; ===== Enable/disable all text/number inputs in the HTML GUI. Called around
; the blocking key-capture Input above so a stray keystroke can never land
; half-typed in a textbox while a capture is silently armed. =====
SetInputsCapturing(State) {
    global WB
    try WB.Document.parentWindow.setCapturing(State)
}

; ===== Enable/disable toggle handler =====
DoToggle(Macro) {
    global SpamEnabled, ClickEnabled, RollEnabled, RollParryEnabled, SHFeintEnabled, MFeintEnabled, JoinEnabled, PrevEnabled, ScreenshotEnabled
    global CurrentHotkey, CurrentClickHotkey, CurrentRollHotkey, CurrentRollParryHotkey, CurrentSHFeintHotkey, CurrentMFeintHotkey, CurrentJoinHotkey, CurrentPrevHotkey
    global SC_IntervalMs, SettingsFile

    NewState := false
    HotkeyName := ""

    if (Macro = "Spam") {
        SpamEnabled := !SpamEnabled
        NewState := SpamEnabled
        HotkeyName := CurrentHotkey
    } else if (Macro = "Click") {
        ClickEnabled := !ClickEnabled
        NewState := ClickEnabled
        HotkeyName := CurrentClickHotkey
    } else if (Macro = "Roll") {
        RollEnabled := !RollEnabled
        NewState := RollEnabled
        HotkeyName := CurrentRollHotkey
    } else if (Macro = "RollParry") {
        RollParryEnabled := !RollParryEnabled
        NewState := RollParryEnabled
        HotkeyName := CurrentRollParryHotkey
    } else if (Macro = "SHFeint") {
        SHFeintEnabled := !SHFeintEnabled
        NewState := SHFeintEnabled
        HotkeyName := CurrentSHFeintHotkey
    } else if (Macro = "MFeint") {
        MFeintEnabled := !MFeintEnabled
        NewState := MFeintEnabled
        HotkeyName := CurrentMFeintHotkey
    } else if (Macro = "Join") {
        JoinEnabled := !JoinEnabled
        NewState := JoinEnabled
        HotkeyName := CurrentJoinHotkey
    } else if (Macro = "Prev") {
        PrevEnabled := !PrevEnabled
        NewState := PrevEnabled
        HotkeyName := CurrentPrevHotkey
    } else if (Macro = "Screenshot") {
        ScreenshotEnabled := !ScreenshotEnabled
        NewState := ScreenshotEnabled
        if (ScreenshotEnabled)
            SetTimer, SC_CaptureScreenshot, % SC_IntervalMs
        else
            SetTimer, SC_CaptureScreenshot, Off
    } else {
        return
    }

    if (HotkeyName != "") {
        try {
            Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
            for index, k in KeyAliases(HotkeyName)
                Hotkey, % k, % (NewState ? "On" : "Off")
        }
    }

    IniWrite, % NewState, %SettingsFile%, Enabled, %Macro%
    SetChecked(Macro . "_toggle", NewState)
}

; ===== Save Settings flow - applies + persists all text/key fields =====
DoSave(Params) {
    global TriggerKey, SpamKey, SpamDelay, ClickTriggerKey, ClickControlName
    global RollTriggerKey, RollParryTriggerKey, SHFeintTriggerKey, MFeintTriggerKey
    global JoinTriggerKey, JoinMessage, PrevTriggerKey
    global SpamEnabled, ClickEnabled, RollEnabled, RollParryEnabled, SHFeintEnabled, MFeintEnabled, JoinEnabled, PrevEnabled
    global SettingsFile

    NewTrigger := Params["trigger"]
    NewSpamKey := Params["spamkey"]
    NewDelay := Params["spamdelay"]
    NewClickTrigger := Params["clicktrigger"]
    NewClickControlName := Params["clickcontrol"]
    NewRollTrigger := Params["rolltrigger"]
    NewRollParryTrigger := Params["rollparrytrigger"]
    NewSHFeintTrigger := Params["shfeinttrigger"]
    NewMFeintTrigger := Params["mfeinttrigger"]
    NewJoinTrigger := Params["jointrigger"]
    NewJoinMessage := Params["joinmessage"]
    DebugLog("DoSave: NewJoinMessage right after Params lookup=[" . NewJoinMessage . "] Len=" . StrLen(NewJoinMessage))
    NewPrevTrigger := Params["prevtrigger"]

    ; Guard against a field coming through blank (e.g. a stray DOM/timing
    ; hiccup) silently wiping out a working hotkey and throwing "Invalid key
    ; name" - if a trigger key field is empty, just keep whatever was already
    ; registered instead of overwriting it.
    if (NewTrigger = "")
        NewTrigger := TriggerKey
    if (NewClickTrigger = "")
        NewClickTrigger := ClickTriggerKey
    if (NewRollTrigger = "")
        NewRollTrigger := RollTriggerKey
    if (NewRollParryTrigger = "")
        NewRollParryTrigger := RollParryTriggerKey
    if (NewSHFeintTrigger = "")
        NewSHFeintTrigger := SHFeintTriggerKey
    if (NewMFeintTrigger = "")
        NewMFeintTrigger := MFeintTriggerKey
    if (NewJoinTrigger = "")
        NewJoinTrigger := JoinTriggerKey
    if (NewPrevTrigger = "")
        NewPrevTrigger := PrevTriggerKey

    if (NewDelay = "")
        NewDelay := 10

    RegisterHotkey(NewTrigger, true, SpamEnabled)
    RegisterClickHotkey(NewClickTrigger, true, ClickEnabled)
    RegisterRollHotkey(NewRollTrigger, true, RollEnabled)
    RegisterRollParryHotkey(NewRollParryTrigger, true, RollParryEnabled)
    RegisterSHFeintHotkey(NewSHFeintTrigger, true, SHFeintEnabled)
    RegisterMFeintHotkey(NewMFeintTrigger, true, MFeintEnabled)
    RegisterJoinHotkey(NewJoinTrigger, true, JoinEnabled)
    RegisterPrevHotkey(NewPrevTrigger, true, PrevEnabled)

    TriggerKey := NewTrigger
    SpamKey := NewSpamKey
    SpamDelay := NewDelay
    ClickTriggerKey := NewClickTrigger
    ClickControlName := NewClickControlName
    RollTriggerKey := NewRollTrigger
    RollParryTriggerKey := NewRollParryTrigger
    SHFeintTriggerKey := NewSHFeintTrigger
    MFeintTriggerKey := NewMFeintTrigger
    JoinTriggerKey := NewJoinTrigger
    JoinMessage := NewJoinMessage
    PrevTriggerKey := NewPrevTrigger
    DebugLog("DoSave: JoinMessage right after assignment=[" . JoinMessage . "] Len=" . StrLen(JoinMessage))

    IniWrite, %TriggerKey%, %SettingsFile%, Settings, TriggerKey
    IniWrite, %SpamKey%, %SettingsFile%, Settings, SpamKey
    IniWrite, %SpamDelay%, %SettingsFile%, Settings, SpamDelay
    IniWrite, %ClickTriggerKey%, %SettingsFile%, Settings, ClickTriggerKey
    IniWrite, %ClickControlName%, %SettingsFile%, Settings, ClickControlName
    IniWrite, %RollTriggerKey%, %SettingsFile%, Settings, RollTriggerKey
    IniWrite, %RollParryTriggerKey%, %SettingsFile%, Settings, RollParryTriggerKey
    IniWrite, %SHFeintTriggerKey%, %SettingsFile%, Settings, SHFeintTriggerKey
    IniWrite, %MFeintTriggerKey%, %SettingsFile%, Settings, MFeintTriggerKey
    IniWrite, %JoinTriggerKey%, %SettingsFile%, Settings, JoinTriggerKey
    IniWrite, %JoinMessage%, %SettingsFile%, Settings, JoinMessage
    DebugLog("DoSave: JoinMessage right after IniWrite=[" . JoinMessage . "] Len=" . StrLen(JoinMessage))
    IniWrite, %PrevTriggerKey%, %SettingsFile%, Settings, PrevTriggerKey

    SetHtml("StatusText", "Status: Saved! Hold [" . KeyLabel(TriggerKey) . "] to spam [" . SpamKey . "]")
    SetHtml("ClickStatusText", "Status: Press [" . KeyLabel(ClickTriggerKey) . "] to click [" . ClickControlName . "] (Roblox only)")
    SetHtml("RollStatusText", "Status: Press [" . KeyLabel(RollTriggerKey) . "] to Roll Uppercut (Roblox only)")
    SetHtml("RollParryStatusText", "Status: Press [" . KeyLabel(RollParryTriggerKey) . "] to Roll Parry (Roblox only)")
    SetHtml("SHFeintStatusText", "Status: Press [" . KeyLabel(SHFeintTriggerKey) . "] to Rising Star Feint (Roblox only)")
    SetHtml("MFeintStatusText", "Status: Press [" . KeyLabel(MFeintTriggerKey) . "] to Mayhem Feint (Roblox only)")
    SetHtml("JoinStatusText", "Status: Press [" . KeyLabel(JoinTriggerKey) . "] to send [" . JoinMessage . "] and join (Roblox only)")
    SetHtml("PrevStatusText", "Status: Press [" . KeyLabel(PrevTriggerKey) . "] to rejoin Previous Server (Roblox only)")
}

; ===== Live update for the Join Message field - fires on every keystroke
; (via oninput in the HTML) instead of waiting for Save Settings. Updates
; the live variable used by ServerJoinMacro immediately and persists it too,
; so it survives a restart even if Save Settings is never clicked. =====
DoSetJoinMessage(NewMsg) {
    global JoinMessage, JoinTriggerKey, SettingsFile
    JoinMessage := NewMsg
    IniWrite, %JoinMessage%, %SettingsFile%, Settings, JoinMessage
    SetHtml("JoinStatusText", "Status: Press [" . KeyLabel(JoinTriggerKey) . "] to send [" . JoinMessage . "] and join (Roblox only)")
}

RegisterHotkey(KeyName, IsUpdate := false, IsEnabled := true) {
    global CurrentHotkey
    if (IsUpdate and CurrentHotkey != "") {
        try {
            Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
            for index, k in KeyAliases(CurrentHotkey)
                Hotkey, % k, Off
        }
    }
    if (KeyName = "") {
        CurrentHotkey := ""
        return
    }
    try {
        Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
        for index, k in KeyAliases(KeyName)
            Hotkey, % k, SpamLoop, On
        CurrentHotkey := KeyName
        if (!IsEnabled) {
            Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
            for index, k in KeyAliases(KeyName)
                Hotkey, % k, Off
        }
    } catch e {
        MsgBox, Invalid key name: %KeyName%
    }
}

; Only active while Roblox is the focused window
; NOTE: uses A_ThisHotkey (the physical key that actually fired) rather than
; CurrentHotkey, since CurrentHotkey may now be bound to two aliases (\ and
; <>) - GetKeyState needs to check whichever one the person is holding.
#IfWinActive, ahk_exe RobloxPlayerBeta.exe
SpamLoop:
    while GetKeyState(A_ThisHotkey, "P") {
        Send, % SpamKey
        Sleep, % SpamDelay
    }
Return
#IfWinActive

RegisterClickHotkey(KeyName, IsUpdate := false, IsEnabled := true) {
    global CurrentClickHotkey
    if (IsUpdate and CurrentClickHotkey != "") {
        try {
            Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
            for index, k in KeyAliases(CurrentClickHotkey)
                Hotkey, % k, Off
        }
    }
    if (KeyName = "") {
        CurrentClickHotkey := ""
        return
    }
    try {
        Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
        for index, k in KeyAliases(KeyName)
            Hotkey, % k, ClickMacro, On
        CurrentClickHotkey := KeyName
        if (!IsEnabled) {
            Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
            for index, k in KeyAliases(KeyName)
                Hotkey, % k, Off
        }
    } catch e {
        MsgBox, Invalid key name: %KeyName%
    }
}

; Only active while Roblox is the focused window - clicks a named control inside Roblox itself
#IfWinActive, ahk_exe RobloxPlayerBeta.exe
ClickMacro:
    ControlClick, %ClickControlName%, clumsy 0.3
Return
#IfWinActive

RegisterRollHotkey(KeyName, IsUpdate := false, IsEnabled := true) {
    global CurrentRollHotkey
    if (IsUpdate and CurrentRollHotkey != "") {
        try {
            Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
            for index, k in KeyAliases(CurrentRollHotkey)
                Hotkey, % k, Off
        }
    }
    if (KeyName = "") {
        CurrentRollHotkey := ""
        return
    }
    try {
        Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
        for index, k in KeyAliases(KeyName)
            Hotkey, % k, RollUppercutMacro, On
        CurrentRollHotkey := KeyName
        if (!IsEnabled) {
            Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
            for index, k in KeyAliases(KeyName)
                Hotkey, % k, Off
        }
    } catch e {
        MsgBox, Invalid key name: %KeyName%
    }
}

; Only active while Roblox is the focused window - Q + Ctrl+RightClick combo
#IfWinActive, ahk_exe RobloxPlayerBeta.exe
RollUppercutMacro:
    Send {q}
    Sleep 10
    Send {Ctrl down}
    Sleep 0
    Click Right
    Send {Ctrl up}
Return
#IfWinActive

RegisterRollParryHotkey(KeyName, IsUpdate := false, IsEnabled := true) {
    global CurrentRollParryHotkey
    if (IsUpdate and CurrentRollParryHotkey != "") {
        try {
            Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
            for index, k in KeyAliases(CurrentRollParryHotkey)
                Hotkey, % k, Off
        }
    }
    if (KeyName = "") {
        CurrentRollParryHotkey := ""
        return
    }
    try {
        Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
        for index, k in KeyAliases(KeyName)
            Hotkey, % k, RollParryMacro, On
        CurrentRollParryHotkey := KeyName
        if (!IsEnabled) {
            Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
            for index, k in KeyAliases(KeyName)
                Hotkey, % k, Off
        }
    } catch e {
        MsgBox, Invalid key name: %KeyName%
    }
}

; Only active while Roblox is the focused window - Q, Right Click, F combo
#IfWinActive, ahk_exe RobloxPlayerBeta.exe
RollParryMacro:
    Send, q
    Click, Right
    Send, f
Return
#IfWinActive

RegisterSHFeintHotkey(KeyName, IsUpdate := false, IsEnabled := true) {
    global CurrentSHFeintHotkey
    if (IsUpdate and CurrentSHFeintHotkey != "") {
        try {
            Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
            for index, k in KeyAliases(CurrentSHFeintHotkey)
                Hotkey, % k, Off
        }
    }
    if (KeyName = "") {
        CurrentSHFeintHotkey := ""
        return
    }
    try {
        Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
        for index, k in KeyAliases(KeyName)
            Hotkey, % k, SHFeintMacro, On
        CurrentSHFeintHotkey := KeyName
        if (!IsEnabled) {
            Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
            for index, k in KeyAliases(KeyName)
                Hotkey, % k, Off
        }
    } catch e {
        MsgBox, Invalid key name: %KeyName%
    }
}

; Only active while Roblox is the focused window - Q, Right Click, Ctrl+Right Click hold, Right Click
#IfWinActive, ahk_exe RobloxPlayerBeta.exe
SHFeintMacro:
    Send, q
    Sleep, 50
    Click, Right
    Send, {Ctrl down}
    Click, Right
    Sleep, 300
    Send, {Ctrl up}
    Click, Right
Return
#IfWinActive

RegisterMFeintHotkey(KeyName, IsUpdate := false, IsEnabled := true) {
    global CurrentMFeintHotkey
    if (IsUpdate and CurrentMFeintHotkey != "") {
        try {
            Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
            for index, k in KeyAliases(CurrentMFeintHotkey)
                Hotkey, % k, Off
        }
    }
    if (KeyName = "") {
        CurrentMFeintHotkey := ""
        return
    }
    try {
        Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
        for index, k in KeyAliases(KeyName)
            Hotkey, % k, MFeintMacro, On
        CurrentMFeintHotkey := KeyName
        if (!IsEnabled) {
            Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
            for index, k in KeyAliases(KeyName)
                Hotkey, % k, Off
        }
    } catch e {
        MsgBox, Invalid key name: %KeyName%
    }
}

; Only active while Roblox is the focused window - Right Click hold + Q, Click, Right Click
; (ported from Mayhem_Feint.ahk)
#IfWinActive, ahk_exe RobloxPlayerBeta.exe
MFeintMacro:
    Send {RButton down}
    Send {q}
    Send {RButton up}
    Click
    Send {RButton}
Return
#IfWinActive

RegisterJoinHotkey(KeyName, IsUpdate := false, IsEnabled := true) {
    global CurrentJoinHotkey
    if (IsUpdate and CurrentJoinHotkey != "") {
        try {
            Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
            for index, k in KeyAliases(CurrentJoinHotkey)
                Hotkey, % k, Off
        }
    }
    if (KeyName = "") {
        CurrentJoinHotkey := ""
        return
    }
    try {
        Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
        for index, k in KeyAliases(KeyName)
            Hotkey, % k, ServerJoinMacro, On
        CurrentJoinHotkey := KeyName
        if (!IsEnabled) {
            Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
            for index, k in KeyAliases(KeyName)
                Hotkey, % k, Off
        }
    } catch e {
        MsgBox, Invalid key name: %KeyName%
    }
}

; Only active while Roblox is the focused window - types the join message, sends it,
; joins the server once, then repeatedly rejoins in a loop that runs infinitely
; until the hotkey is pressed again (toggle on/off), same pattern as Previous Server.
JN_ToggleActive := false

#IfWinActive, ahk_exe RobloxPlayerBeta.exe
ServerJoinMacro:
    JN_ToggleActive := !JN_ToggleActive
    if (JN_ToggleActive) {
        MouseMove, % JN_MsgBoxX, % JN_MsgBoxY, 5
        Click
        Click
        Sleep, 100

        ; Type the join message. Roblox binds Space to Jump at a global
        ; input-hook level, so ANY method that sends Space as a real VK_SPACE
        ; keydown (SendRaw/SendEvent/SendInput, delay or no delay) can get it
        ; eaten by the game instead of the chat textbox, which is what was
        ; merging words together. {Text} mode sidesteps this entirely - it
        ; injects literal Unicode characters (KEYEVENTF_UNICODE) instead of
        ; virtual-key events, so there's no VK_SPACE keydown for Roblox's
        ; hook to intercept.
        DebugLog("ServerJoinMacro sending JoinMessage=[" . JoinMessage . "] Len=" . StrLen(JoinMessage))
        Send, {Text}%JoinMessage%

        MouseMove, % JN_SendBtnX, % JN_SendBtnY, 5
        Click
        Sleep, 200
        MouseMove, % JN_JoinBtnX, % JN_JoinBtnY, 5
        Click

        SetTimer, JN_ToggleTick, -10
    } else {
        SetTimer, JN_ToggleTick, Off
    }
return
#IfWinActive

JN_ToggleTick:
    if (!JN_ToggleActive)
        return

    MouseMove, % JN_RejoinBtnX, % JN_RejoinBtnY, 5
    Click
    Sleep, 200

    MouseMove, % JN_JoinBtnX, % JN_JoinBtnY, 5
    Click
    Sleep, 200

    if (JN_ToggleActive)
        SetTimer, JN_ToggleTick, -10
return

RegisterPrevHotkey(KeyName, IsUpdate := false, IsEnabled := true) {
    global CurrentPrevHotkey
    if (IsUpdate and CurrentPrevHotkey != "") {
        try {
            Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
            for index, k in KeyAliases(CurrentPrevHotkey)
                Hotkey, % k, Off
        }
    }
    if (KeyName = "") {
        CurrentPrevHotkey := ""
        return
    }
    try {
        Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
        for index, k in KeyAliases(KeyName)
            Hotkey, % k, PreviousServerMacro, On
        CurrentPrevHotkey := KeyName
        if (!IsEnabled) {
            Hotkey, IfWinActive, ahk_exe RobloxPlayerBeta.exe
            for index, k in KeyAliases(KeyName)
                Hotkey, % k, Off
        }
    } catch e {
        MsgBox, Invalid key name: %KeyName%
    }
}

; Only active while Roblox is the focused window - clicks "Previous Server" then Join,
; on a loop that runs infinitely until the hotkey is pressed again (toggle on/off).
; Uses a non-blocking SetTimer instead of a blocking loop so the second press can
; actually be detected and stop it.
PN_ToggleActive := false

#IfWinActive, ahk_exe RobloxPlayerBeta.exe
PreviousServerMacro:
    PN_ToggleActive := !PN_ToggleActive
    if (PN_ToggleActive)
        SetTimer, PN_ToggleTick, -10
    else
        SetTimer, PN_ToggleTick, Off
return
#IfWinActive

PN_ToggleTick:
    if (!PN_ToggleActive)
        return

    MouseMove, %PN_PrevBtnX%, %PN_PrevBtnY%, 5
    Click
    Click
    Sleep, 200

    MouseMove, %PN_JoinBtnX%, %PN_JoinBtnY%, 5
    Click
    Sleep, 200

    if (PN_ToggleActive)
        SetTimer, PN_ToggleTick, -10
return

; ===== Server Screenshot (automatic, no hotkey - runs on a timer) =====
; Screenshots the region and displays it directly in the GUI. Same file
; gets overwritten every cycle - only while Roblox is the active window.
;
; It also hashes each screenshot. If the hash differs from the last one
; (i.e. the server name text changed - you joined a different server),
; it schedules ONE extra confirmation capture ~60 seconds later, in case
; the tooltip wasn't fully rendered yet at the moment of the change.
CaptureServerScreenshot() {
    global SC_PsScript, SC_ScreenshotFile, SC_HashOutFile
    global SC_RegionX1, SC_RegionY1, SC_RegionX2, SC_RegionY2
    global SC_LastHash, SC_RecaptureDelayMs, ScreenshotEnabled

    if !ScreenshotEnabled
        return

    if !WinActive("ahk_exe RobloxPlayerBeta.exe")
        return

    SC_Cmd := "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ . SC_PsScript . """ -X1 " . SC_RegionX1 . " -Y1 " . SC_RegionY1 . " -X2 " . SC_RegionX2 . " -Y2 " . SC_RegionY2 . " -OutPath """ . SC_ScreenshotFile . """ > """ . SC_HashOutFile . """"

    RunWait, %A_ComSpec% /c %SC_Cmd%,, Hide

    if !FileExist(SC_ScreenshotFile)
        return

    SetImgSrc(SC_ScreenshotFile)

    NewHash := ""
    if FileExist(SC_HashOutFile) {
        FileRead, NewHash, %SC_HashOutFile%
        NewHash := Trim(NewHash, " `t`r`n")
        FileDelete, %SC_HashOutFile%
    }

    if (NewHash != "" and NewHash != SC_LastHash) {
        WasFirstCapture := (SC_LastHash = "")
        SC_LastHash := NewHash
        if !WasFirstCapture
            SetTimer, SC_DelayedRecapture, % "-" . SC_RecaptureDelayMs
    }
}

SC_CaptureScreenshot:
    CaptureServerScreenshot()
Return

; One-shot confirmation capture, fired ~60s after a server change is detected
SC_DelayedRecapture:
    CaptureServerScreenshot()
Return

ExitScript:
GuiClose:
    ExitApp
Return

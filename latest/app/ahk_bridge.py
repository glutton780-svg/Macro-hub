"""
Thin bridge between Python and the persistent macro_worker.ahk process.

Python keeps doing everything it's good at (GUI, settings, global hotkey
*detection*, threading/looping, screenshot polling). The only thing this
module hands off to AHK is the actual input-sending primitive - the part
that was breaking when ported to pynput/keyboard.

Requires AutoHotkey v1.1 (the classic/non-v2 syntax used in macro_worker.ahk)
to be installed. If you have AutoHotkey v2 installed instead, this will
fail: v2 can't run v1 syntax. Get v1.1 specifically from
https://www.autohotkey.com/download/ahk-install.exe (the main download
page defaults to v2 - look for the "other versions" / v1.1 link).

DEBUGGING: every start attempt, exit code, and any error text AHK reports
is appended to the shared app log (see app/applog.py) - by default
%TEMP%\\roblox_macro_suite_debug.log. Check that file first if the worker
won't start.
"""
import ctypes
import os
import subprocess
import sys
import time

import win32gui
import win32process

from . import applog

AHK_EXE = os.environ.get("AHK_EXE", r"C:\Program Files\AutoHotkey\AutoHotkey.exe")

if getattr(sys, "frozen", False):
    # Running from a PyInstaller-built exe - files added via --add-data in
    # build.bat get unpacked next to sys._MEIPASS, not next to this .py.
    _BASE_DIR = sys._MEIPASS
else:
    _BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

WORKER_SCRIPT = os.path.join(_BASE_DIR, "ahk", "macro_worker.ahk")
DEBUG_LOG_FILE = applog.LOG_FILE

WM_COPYDATA = 0x004A


def _log(msg):
    applog.log("ahk_bridge", msg)


class _COPYDATASTRUCT(ctypes.Structure):
    _fields_ = [
        ("dwData", ctypes.c_void_p),
        ("cbData", ctypes.c_ulong),
        ("lpData", ctypes.c_char_p),
    ]


_worker_proc = None
_worker_hwnd = None


def _find_hwnd_for_pid(pid):
    """Every AHK script has an auto-created main window (hidden by default)
    as soon as it's running - EnumWindows sees it even though it's hidden,
    since that only affects IsWindowVisible, not enumeration."""
    found = []

    def cb(hwnd, _):
        try:
            _, whwnd_pid = win32process.GetWindowThreadProcessId(hwnd)
        except Exception:
            return True
        if whwnd_pid == pid:
            found.append(hwnd)
        return True

    win32gui.EnumWindows(cb, None)
    return found[0] if found else None


def _hwnd_is_alive(hwnd):
    return bool(hwnd) and win32gui.IsWindow(hwnd)


def ensure_worker_running(timeout=3.0):
    """Starts macro_worker.ahk if it isn't already running. Call once at
    app startup (e.g. from main.py before the window opens)."""
    global _worker_proc, _worker_hwnd

    if _hwnd_is_alive(_worker_hwnd):
        return

    _log(f"starting worker: AHK_EXE={AHK_EXE} WORKER_SCRIPT={WORKER_SCRIPT}")

    if not os.path.exists(AHK_EXE):
        _log("FAILED: AutoHotkey.exe not found at that path")
        raise RuntimeError(
            f"AutoHotkey.exe not found at {AHK_EXE}. Install AutoHotkey "
            "v1.1, or set the AHK_EXE environment variable to its actual "
            f"location. (See {DEBUG_LOG_FILE} for the debug log.)"
        )

    if not os.path.exists(WORKER_SCRIPT):
        _log("FAILED: macro_worker.ahk not found")
        raise RuntimeError(
            f"macro_worker.ahk not found at {WORKER_SCRIPT}. If this is "
            "the built .exe, rebuild with the updated build.bat that adds "
            '"--add-data \\"ahk;ahk\\"". '
            f"(See {DEBUG_LOG_FILE} for the debug log.)"
        )

    # /ErrorStdOut makes AHK v1.1 write load-time/runtime error text to
    # stdout instead of a popup dialog, so we can actually capture *why*
    # it died instead of just seeing an exit code.
    #
    # Args passed to macro_worker.ahk: [1]=our PID (watchdog, see
    # macro_worker.ahk), [2]=the shared log file path (so both sides write
    # to the exact same file next to the app instead of guessing at it).
    _worker_proc = subprocess.Popen(
        [AHK_EXE, "/ErrorStdOut", os.path.abspath(WORKER_SCRIPT),
         str(os.getpid()), applog.LOG_FILE],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )

    deadline = time.time() + timeout
    while time.time() < deadline:
        exit_code = _worker_proc.poll()
        if exit_code is not None:
            output = (_worker_proc.stdout.read() or "").strip()
            _log(f"FAILED: worker exited immediately, code={exit_code}")
            if output:
                _log(f"AHK error output:\n{output}")
            hint = (
                "AutoHotkey reported an error (see above/log) - likely a "
                "real syntax problem in macro_worker.ahk."
                if output
                else
                "No error text was captured, which usually means AutoHotkey "
                "v2 is installed instead of v1.1 (v2 doesn't support "
                "/ErrorStdOut the same way and shows its own popup for v1 "
                "syntax it can't parse - check for a stray AutoHotkey "
                "dialog on screen/taskbar)."
            )
            raise RuntimeError(
                f"macro_worker.ahk exited immediately (code {exit_code}). "
                f"{hint} Full log: {DEBUG_LOG_FILE}"
            )
        hwnd = _find_hwnd_for_pid(_worker_proc.pid)
        if _hwnd_is_alive(hwnd):
            _worker_hwnd = hwnd
            _log(f"worker running OK, pid={_worker_proc.pid} hwnd={hwnd}")
            return
        time.sleep(0.05)

    _log("FAILED: worker process alive but no window appeared before timeout")
    raise RuntimeError(
        "macro_worker.ahk started but its window never appeared in time. "
        f"AHK_EXE={AHK_EXE}  Full log: {DEBUG_LOG_FILE}"
    )


def stop_worker():
    global _worker_proc, _worker_hwnd
    _log("stop_worker called")
    if _worker_proc and _worker_proc.poll() is None:
        _worker_proc.terminate()
    _worker_proc = None
    _worker_hwnd = None


def send_command(cmd: str):
    """Sends one primitive command string (e.g. 'send_key|q') to the AHK
    worker and blocks until it's been handled (SendMessage is synchronous),
    so your existing time.sleep() calls between steps in macros.py still
    control the real inter-action timing."""
    if not _hwnd_is_alive(_worker_hwnd):
        ensure_worker_running()

    _log(f"send_command: {cmd}")

    data = cmd.encode("utf-8") + b"\x00"
    buf = ctypes.create_string_buffer(data)
    cds = _COPYDATASTRUCT(0, len(data), ctypes.cast(buf, ctypes.c_char_p))
    ctypes.windll.user32.SendMessageW(_worker_hwnd, WM_COPYDATA, 0, ctypes.byref(cds))

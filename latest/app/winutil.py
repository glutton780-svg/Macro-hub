"""
Windows-only input + window helpers.

Window/focus detection (is_roblox_active, foreground_exe_name) stays in
plain Python/pywin32 - that part was never the problem.

The actual input-sending primitives (send_key, click, move_mouse, ...) are
now thin wrappers that hand off to macro_worker.ahk over ahk_bridge, since
AHK's Send/Click/ControlClick are what Roblox reliably accepts.

Requires: pywin32, psutil (see requirements.txt) + AutoHotkey installed
(see ahk_bridge.py for AHK_EXE).
"""
import psutil
import win32gui
import win32process

from . import ahk_bridge as ahk
from . import config

# ---------------------------------------------------------------------------
# Window / focus  (unchanged - pure Python, this part wasn't broken)
# ---------------------------------------------------------------------------

def foreground_exe_name():
    hwnd = win32gui.GetForegroundWindow()
    if not hwnd:
        return ""
    try:
        _, pid = win32process.GetWindowThreadProcessId(hwnd)
        return psutil.Process(pid).name()
    except Exception:
        return ""


def is_roblox_active():
    return foreground_exe_name().lower() == config.ROBLOX_EXE.lower()


# ---------------------------------------------------------------------------
# Input primitives -> delegated to AHK
# ---------------------------------------------------------------------------

def control_click():
    """ClickMacro / 'Clumsy Keybind': always clicks Button2 in the Clumsy
    network-throttling tool's window (titled "clumsy 0.3"), never Roblox -
    that's what the original AHK line `ControlClick, Button2, clumsy 0.3`
    actually did. The port previously left the control name configurable
    and defaulted the target window to Roblox when none was given, which
    is why it never found anything."""
    ahk.send_command("control_click|Button2|clumsy 0.3")


def move_mouse(x, y):
    ahk.send_command(f"move_mouse|{x}|{y}")


def click(button="left"):
    ahk.send_command(f"click|{'Right' if button == 'right' else 'Left'}")


def macro_m_feint():
    """Fires the entire MFeint sequence natively inside macro_worker.ahk
    as a single command, so it reproduces the original standalone AHK
    hotkey's real timing exactly, instead of approximating it with
    Python-side sleeps."""
    ahk.send_command("m_feint")


def mouse_down(button="left"):
    ahk.send_command(f"mouse_down|{'Right' if button == 'right' else 'Left'}")


def mouse_up(button="left"):
    ahk.send_command(f"mouse_up|{'Right' if button == 'right' else 'Left'}")


def send_key(key):
    ahk.send_command(f"send_key|{key}")


def key_down(key):
    ahk.send_command(f"key_down|{key}")


def key_up(key):
    ahk.send_command(f"key_up|{key}")


def send_text_unicode(text):
    # AHK's {Text} mode, sent as one command - same anti-VK_SPACE-hook
    # trick the original AHK script used for the join-message chatbox.
    escaped = text.replace("|", "")  # '|' is our field separator; strip it
    ahk.send_command(f"send_text|{escaped}")


def start_join_loop(message, quick_mode=False):
    """Runs the ENTIRE Server Join sequence + rejoin loop natively inside
    macro_worker.ahk (single command), so it reproduces the original
    standalone AHK hotkey's real click/type/rejoin timing exactly, instead
    of Python driving each step over a round trip.

    quick_mode=True uses config.JOIN["quick_rejoin_btn"] instead of
    "rejoin_btn" for the repeating loop's first mouse move ("Quick join +
    prev"), and - matching the real Previous Server loop - double-clicks
    that spot instead of single-clicking it.
    """
    c = config.JOIN
    rejoin = c["quick_rejoin_btn"] if quick_mode else c["rejoin_btn"]
    msg = message.replace("|", "")  # '|' is our field separator; strip it
    ahk.send_command(
        "join_start|"
        f"{c['msgbox'][0]}|{c['msgbox'][1]}|"
        f"{c['send_btn'][0]}|{c['send_btn'][1]}|"
        f"{c['join_btn'][0]}|{c['join_btn'][1]}|"
        f"{rejoin[0]}|{rejoin[1]}|"
        f"{1 if quick_mode else 0}|"
        f"{msg}"
    )


def stop_join_loop():
    ahk.send_command("join_stop")


def start_prev_loop():
    """Runs the Previous Server rejoin loop natively inside
    macro_worker.ahk, matching the original standalone AHK's timing."""
    c = config.PREV
    ahk.send_command(
        "prev_start|"
        f"{c['prev_btn'][0]}|{c['prev_btn'][1]}|"
        f"{c['join_btn'][0]}|{c['join_btn'][1]}"
    )


def stop_prev_loop():
    ahk.send_command("prev_stop")

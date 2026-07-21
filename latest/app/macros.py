import threading
import time

import keyboard

from . import applog
from . import config
from . import winutil as wu

def _send_key_safe(key):
    wu.send_key(key)


# ---------------------------------------------------------------------------
# Simple one-shot combo macros (ported directly from the AHK hotkey labels)
# ---------------------------------------------------------------------------

def macro_click():
    """ClickMacro / 'Clumsy Keybind': ControlClick, Button2, clumsy 0.3"""
    applog.log("macros", "macro_click")
    wu.control_click()


def macro_roll_uppercut():
    """RollUppercutMacro: Q, then Ctrl+RightClick."""
    applog.log("macros", "macro_roll_uppercut")
    _send_key_safe("q")
    time.sleep(0.01)
    wu.key_down("ctrl")
    time.sleep(0.01)
    wu.click("right")
    wu.key_up("ctrl")


def macro_roll_parry():
    """RollParryMacro: Q, Right Click, F."""
    applog.log("macros", "macro_roll_parry")
    _send_key_safe("q")
    time.sleep(0.01)
    wu.click("right")
    time.sleep(0.01)
    _send_key_safe("f")


def macro_sh_feint():
    """SHFeintMacro: Q, Right Click, Ctrl+Right Click hold, Right Click."""
    applog.log("macros", "macro_sh_feint")
    _send_key_safe("q")
    time.sleep(0.05)
    wu.click("right")
    wu.key_down("ctrl")
    wu.click("right")
    time.sleep(0.3)
    wu.key_up("ctrl")
    wu.click("right")


def macro_m_feint():
    """MFeintMacro: RButton hold + Q, RButton release, Click, RButton.

    Runs natively inside macro_worker.ahk (single "m_feint" command) so
    it reproduces the original standalone AHK hotkey's real timing
    exactly, instead of approximating it with Python-side sleeps.
    """
    applog.log("macros", "macro_m_feint")
    wu.macro_m_feint()


# ---------------------------------------------------------------------------
# Hold-to-repeat Key Spammer
# ---------------------------------------------------------------------------

class SpamController:
    """SpamLoop: while GetKeyState(trigger, "P"), Send spamkey, Sleep delay."""

    def __init__(self):
        self._stop_event = threading.Event()
        self._thread = None

    def start(self, trigger_key, spam_key, delay_ms, is_active_fn):
        self.stop()
        self._stop_event.clear()
        applog.log("macros", f"SpamController.start(trigger_key={trigger_key!r}, spam_key={spam_key!r}, delay_ms={delay_ms})")

        def loop():
            # `is_active_fn` (Roblox focused) and the stop_event set by the
            # hotkey's on-release callback are the normal way this stops.
            # We ALSO poll the physical trigger key's real OS state
            # (keyboard.is_pressed) as a safety net: the original AHK macro
            # used `while GetKeyState(trigger, "P")`, which polls actual
            # key state every iteration and can never miss a release. Our
            # on_up callback relies on receiving a release *event*, and
            # Windows can occasionally drop/coalesce that event (e.g. under
            # focus changes while suppress=True is active) - if that
            # happens with only the event-based approach, nothing ever
            # tells this loop to stop and it spams forever. Polling the
            # real key state directly closes that gap.
            try:
                while (
                    not self._stop_event.is_set()
                    and is_active_fn()
                    and keyboard.is_pressed(trigger_key)
                ):
                    wu.send_key(spam_key)
                    self._stop_event.wait(max(delay_ms, 1) / 1000.0)
            finally:
                if not self._stop_event.is_set():
                    applog.log("macros", "SpamController: trigger key no longer physically held - stopping")
                    self._stop_event.set()

        self._thread = threading.Thread(target=loop, daemon=True)
        self._thread.start()

    def stop(self):
        applog.log("macros", "SpamController.stop")
        self._stop_event.set()


# ---------------------------------------------------------------------------
# Server Join (toggle on/off, first press types+sends+joins, then repeats
# the rejoin+join click pair until pressed again)
# ---------------------------------------------------------------------------

class JoinServerLoop:
    """Toggle on/off. Runs natively inside macro_worker.ahk (like MFeint) -
    Python just tells the worker to start/stop the loop, so the real
    click/type/rejoin timing matches the original standalone AHK exactly.

    get_quick_mode, if supplied, is called at toggle-on time to decide
    whether to use the normal rejoin coordinates or the "Quick join + prev"
    ones (see config.JOIN["quick_rejoin_btn"]).
    """

    def __init__(self, get_join_message, get_quick_mode=None):
        self.get_join_message = get_join_message
        self.get_quick_mode = get_quick_mode or (lambda: False)
        self._active = False

    def toggle(self):
        self._active = not self._active
        applog.log("macros", f"JoinServerLoop.toggle -> active={self._active}")
        if self._active:
            msg = self.get_join_message()
            quick = bool(self.get_quick_mode())
            applog.log("macros", f"JoinServerLoop: starting native loop, message={msg!r} quick_mode={quick}")
            wu.start_join_loop(msg, quick_mode=quick)
        else:
            applog.log("macros", "JoinServerLoop: stopping native loop")
            wu.stop_join_loop()


# ---------------------------------------------------------------------------
# Previous Server (toggle on/off, repeats prev+join click pair)
# ---------------------------------------------------------------------------

class PrevServerLoop:
    """Toggle on/off. Runs natively inside macro_worker.ahk, matching the
    original standalone AHK's PN_ToggleTick timing exactly."""

    def __init__(self):
        self._active = False

    def toggle(self):
        self._active = not self._active
        applog.log("macros", f"PrevServerLoop.toggle -> active={self._active}")
        if self._active:
            applog.log("macros", "PrevServerLoop: starting native loop")
            wu.start_prev_loop()
        else:
            applog.log("macros", "PrevServerLoop: stopping native loop")
            wu.stop_prev_loop()

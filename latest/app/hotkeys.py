"""
Global hotkey registration + the "press any key to bind" capture flow.

Uses the `keyboard` library, which (unlike most Python input libs) can
register hotkeys that fire even when your app's window isn't focused -
required here since these are meant to fire while Roblox has focus.
"""
import queue
import keyboard

from . import applog


class HotkeyManager:
    def __init__(self):
        self._handlers = {}    # macro name -> [hook refs]
        self._down_state = {}  # macro name -> bool, ignores OS key-repeat
        self._key_owners = {}  # key name -> set of macro names currently bound to it

    def unbind(self, macro):
        if macro in self._handlers:
            applog.log("hotkeys", f"unbind({macro})")
        for h in self._handlers.pop(macro, []):
            try:
                keyboard.unhook(h)
            except Exception:
                pass
        self._down_state.pop(macro, None)
        for key, owners in list(self._key_owners.items()):
            owners.discard(macro)
            if not owners:
                del self._key_owners[key]

    def key_conflict(self, key):
        """Returns the set of macro names already bound to `key`, if any."""
        return set(self._key_owners.get(key, ()))

    def _claim_key(self, macro, key):
        self._key_owners.setdefault(key, set()).add(macro)

    def bind_oneshot(self, macro, key, callback):
        """Fires `callback()` once per physical press (ignores OS auto-repeat
        while held), mirroring a normal AHK Hotkey label."""
        self.unbind(macro)
        self._down_state[macro] = False
        self._claim_key(macro, key)

        def on_down(_e):
            if self._down_state.get(macro):
                return
            self._down_state[macro] = True
            applog.log("hotkeys", f"oneshot fired: {macro} (key={key!r})")
            callback()

        def on_up(_e):
            self._down_state[macro] = False

        try:
            # suppress=True blocks the real keypress from reaching whatever
            # window has focus (e.g. Roblox), matching how an AHK hotkey
            # label suppresses its trigger key by default - otherwise the
            # trigger key both fires the macro AND gets typed/sent through
            # to the game.
            h1 = keyboard.on_press_key(key, on_down, suppress=True)
            h2 = keyboard.on_release_key(key, on_up, suppress=True)
            self._handlers[macro] = [h1, h2]
            applog.log("hotkeys", f"bind_oneshot({macro}, key={key!r}) OK")
        except (ValueError, KeyError) as e:
            # Unrecognized key name for this keyboard/layout - surface this
            # to the user instead of crashing the whole app.
            applog.log("hotkeys", f"bind_oneshot({macro}, key={key!r}) FAILED: {e}")

    def bind_hold(self, macro, key, on_down, on_up):
        """Calls on_down() when the key goes down and on_up() when it comes
        back up - used for the hold-to-repeat Spam macro."""
        self.unbind(macro)
        self._claim_key(macro, key)

        def _down(_e):
            applog.log("hotkeys", f"hold-down fired: {macro} (key={key!r})")
            on_down()

        def _up(_e):
            applog.log("hotkeys", f"hold-up fired: {macro} (key={key!r})")
            on_up()

        try:
            h1 = keyboard.on_press_key(key, _down, suppress=True)
            h2 = keyboard.on_release_key(key, _up, suppress=True)
            self._handlers[macro] = [h1, h2]
            applog.log("hotkeys", f"bind_hold({macro}, key={key!r}) OK")
        except (ValueError, KeyError) as e:
            applog.log("hotkeys", f"bind_hold({macro}, key={key!r}) FAILED: {e}")


def capture_next_key(timeout=3.0):
    """
    Blocks the calling thread until the next key is pressed, or `timeout`
    seconds elapse. Returns the key name, 'esc' for Escape, or None on
    timeout.

    This is the port of DoSetKey's capture loop - the AHK version dynamically
    registers ~70 individual wildcard hotkeys to catch "any" key by name; a
    temporary global hook does the same job in one step here.
    """
    q = queue.Queue()

    def on_event(event):
        if event.event_type == keyboard.KEY_DOWN:
            q.put(event.name)

    hook = keyboard.hook(on_event)
    try:
        try:
            key = q.get(timeout=timeout)
            applog.log("hotkeys", f"capture_next_key -> {key!r}")
            return key
        except queue.Empty:
            applog.log("hotkeys", "capture_next_key -> timeout")
            return None
    finally:
        keyboard.unhook(hook)

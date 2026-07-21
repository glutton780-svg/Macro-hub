import base64
import collections
import html as html_lib
import os
import sys
import time
import threading

from . import applog
from . import macros
from . import updater
from . import winutil as wu
from .hotkeys import HotkeyManager, capture_next_key
from .screenshot import ScreenshotManager
from .settings import load_settings, save_settings, data_dir


def _resource_dir():
    """Where bundled read-only files (gui_template.html) live. This is
    PyInstaller's extraction dir when frozen, the project folder otherwise."""
    if getattr(sys, "frozen", False):
        return getattr(sys, "_MEIPASS", os.path.dirname(sys.executable))
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


TEMPLATE_PATH = os.path.join(_resource_dir(), "gui_template.html")

# macro key -> (settings key field, settings enabled field)
MACRO_KEY_FIELD = {
    "Spam": "trigger_key",
    "Click": "click_trigger_key",
    "Roll": "roll_trigger_key",
    "RollParry": "roll_parry_trigger_key",
    "SHFeint": "shfeint_trigger_key",
    "MFeint": "mfeint_trigger_key",
    "Join": "join_trigger_key",
    "Prev": "prev_trigger_key",
}
MACRO_ENABLED_FIELD = {
    "Spam": "spam", "Click": "click", "Roll": "roll", "RollParry": "rollparry",
    "SHFeint": "shfeint", "MFeint": "mfeint", "Join": "join", "Prev": "prev",
}

INPUT_IDS = {
    "Trigger": "TriggerKeyInput", "SpamKey": "SpamKeyInput", "Click": "ClickTriggerKeyInput",
    "Roll": "RollTriggerKeyInput", "RollParry": "RollParryTriggerKeyInput", "SHFeint": "SHFeintTriggerKeyInput",
    "MFeint": "MFeintTriggerKeyInput", "Join": "JoinTriggerKeyInput", "Prev": "PrevTriggerKeyInput",
}
STATUS_IDS = {
    "Trigger": "StatusText", "SpamKey": "StatusText", "Click": "ClickStatusText",
    "Roll": "RollStatusText", "RollParry": "RollParryStatusText", "SHFeint": "SHFeintStatusText",
    "MFeint": "MFeintStatusText", "Join": "JoinStatusText", "Prev": "PrevStatusText",
}
LABELS = {
    "Trigger": "Trigger", "SpamKey": "Spam", "Click": "Click Trigger", "Roll": "Roll Uppercut",
    "RollParry": "Roll Parry", "SHFeint": "Rising Star Feint", "MFeint": "Mayhem Feint",
    "Join": "Server Join", "Prev": "Previous Server Join",
}

TOGGLE_ENABLED_KEY = {
    "Spam": "spam", "Click": "click", "Roll": "roll", "RollParry": "rollparry",
    "SHFeint": "shfeint", "MFeint": "mfeint", "Join": "join", "Prev": "prev", "Screenshot": "screenshot",
}


class App:
    """Owns settings, hotkey bindings, and the pywebview JS bridge (`js_api`)."""

    def __init__(self):
        self.settings = load_settings()
        self.hotkeys = HotkeyManager()
        self.spam = macros.SpamController()
        self.join_loop = macros.JoinServerLoop(
            lambda: self.settings["join_message"],
            lambda: self.settings["join_quick_mode"],
        )
        self.prev_loop = macros.PrevServerLoop()
        self.screenshot = ScreenshotManager(self._on_screenshot_update, data_dir())
        # Leading underscore is load-bearing: pywebview's inject_pywebview()
        # reflectively walks every public (non "_"-prefixed) attribute of
        # this App instance to build the JS bridge, recursing into any
        # non-callable object it finds. A plain `self.window` used to get
        # walked straight into `window.native` - the raw WinForms/WebView2
        # object graph - which has real cycles (Font.Style Bold/Regular,
        # AccessibilityObject.Bounds) that pywebview's id()-based cycle
        # guard can't catch (pythonnet hands back a fresh wrapper, and
        # thus a new id(), on every property access), causing runaway
        # recursion, plus off-UI-thread COM access on WebView2Controller
        # members (that reflection walk runs on a background thread).
        # Keeping this private keeps pywebview from ever touching it.
        self._window = None

        # DOM updates from background threads (screenshot loop, hotkey
        # capture thread, spam/join/prev macro loops) must never call
        # window.evaluate_js() directly - on Windows the WebView2 COM
        # objects live on the main/UI thread's apartment, and touching them
        # from another OS thread throws a native COM exception that kills
        # the process before Python ever sees it (nothing gets logged).
        # Background threads push updates here instead; the page itself
        # polls pop_updates() via pywebview.api, which pywebview always
        # dispatches safely regardless of which thread queued the data.
        self._update_lock = threading.Lock()
        self._pending_updates = collections.deque()

        # Set once check_for_update() finds something newer; consumed by
        # the "applyupdate" action so it doesn't have to re-fetch the
        # manifest right before installing it.
        self._pending_update = None  # (remote_version, manifest) or None

    # ------------------------------------------------------------------
    # HTML rendering (replaces RenderHtmlUi)
    # ------------------------------------------------------------------
    def render_html(self):
        with open(TEMPLATE_PATH, "r", encoding="utf-8") as f:
            tpl = f.read()
        s = self.settings
        e = s["enabled"]

        def esc(v):
            return html_lib.escape(str(v), quote=True)

        def klabel(k):
            return k if k else "not set"

        repl = {
            "__TRIGGER_KEY__": esc(s["trigger_key"]),
            "__SPAM_KEY__": esc(s["spam_key"]),
            "__SPAM_DELAY__": esc(s["spam_delay_ms"]),
            "__CLICK_TRIGGER__": esc(s["click_trigger_key"]),
            "__ROLL_TRIGGER__": esc(s["roll_trigger_key"]),
            "__ROLLPARRY_TRIGGER__": esc(s["roll_parry_trigger_key"]),
            "__SHFEINT_TRIGGER__": esc(s["shfeint_trigger_key"]),
            "__MFEINT_TRIGGER__": esc(s["mfeint_trigger_key"]),
            "__JOIN_TRIGGER__": esc(s["join_trigger_key"]),
            "__JOIN_MESSAGE__": esc(s["join_message"]),
            "__PREV_TRIGGER__": esc(s["prev_trigger_key"]),
            "__CHK_JOIN_QUICK__": "checked" if s["join_quick_mode"] else "",

            "__SPAM_NAME__": "Key Spammer",
            "__CLICK_NAME__": "Clumsy Keybind",
            "__ROLL_NAME__": "Roll Uppercut",
            "__ROLLPARRY_NAME__": "Roll Parry",
            "__SHFEINT_NAME__": "Rising Star Feint",
            "__MFEINT_NAME__": "Mayhem Feint",
            "__JOIN_NAME__": "Server Join",
            "__PREV_NAME__": "Previous Server Join",
            "__SCREENSHOT_NAME__": "Server Screenshot",

            "__STATUS_SPAM__": f"Status: Hold [{klabel(s['trigger_key'])}] to spam [{s['spam_key']}]",
            "__STATUS_CLICK__": f"Status: Press [{klabel(s['click_trigger_key'])}] to click Button2 in Clumsy (while Roblox is focused)",
            "__STATUS_ROLL__": f"Status: Press [{klabel(s['roll_trigger_key'])}] to Roll Uppercut (Roblox only)",
            "__STATUS_ROLLPARRY__": f"Status: Press [{klabel(s['roll_parry_trigger_key'])}] to Roll Parry (Roblox only)",
            "__STATUS_SHFEINT__": f"Status: Press [{klabel(s['shfeint_trigger_key'])}] to Rising Star Feint (Roblox only)",
            "__STATUS_MFEINT__": f"Status: Press [{klabel(s['mfeint_trigger_key'])}] to Mayhem Feint (Roblox only)",
            "__STATUS_JOIN__": f"Status: Press [{klabel(s['join_trigger_key'])}] to send [{s['join_message']}] and join (Roblox only)",
            "__STATUS_PREV__": f"Status: Press [{klabel(s['prev_trigger_key'])}] to rejoin Previous Server (Roblox only)",

            "__CHK_SPAM__": "checked" if e["spam"] else "",
            "__CHK_CLICK__": "checked" if e["click"] else "",
            "__CHK_ROLL__": "checked" if e["roll"] else "",
            "__CHK_ROLLPARRY__": "checked" if e["rollparry"] else "",
            "__CHK_SHFEINT__": "checked" if e["shfeint"] else "",
            "__CHK_MFEINT__": "checked" if e["mfeint"] else "",
            "__CHK_JOIN__": "checked" if e["join"] else "",
            "__CHK_PREV__": "checked" if e["prev"] else "",
            "__CHK_SCREENSHOT__": "checked" if e["screenshot"] else "",
            "__SCREENSHOT_SRC__": self.screenshot.current_file_url(),
            "__LOCAL_VERSION__": esc(updater.local_version() or "dev"),
        }
        for k, v in repl.items():
            tpl = tpl.replace(k, str(v))
        return tpl

    # ------------------------------------------------------------------
    # Startup (call once the pywebview window exists)
    # ------------------------------------------------------------------
    def on_window_created(self):
        applog.log("gui", "on_window_created: rebinding hotkeys and starting screenshot loop")
        self._rebind_all()
        self.screenshot.set_enabled(self.settings["enabled"]["screenshot"])
        self.screenshot.start()
        # Silent check - just shows the banner if something's newer, never
        # installs anything on its own. Manual "Update Now" click required.
        threading.Thread(target=self._do_check_update, daemon=True).start()

    # ------------------------------------------------------------------
    # JS bridge - the page's nav('ahk://action?k=v') calls land here
    # ------------------------------------------------------------------
    def handle_command(self, action, params=None):
        params = params or {}
        applog.log("gui", f"handle_command(action={action!r}, params={params})")
        if action == "setkey":
            threading.Thread(target=self._do_set_key, args=(params.get("target"),), daemon=True).start()
        elif action == "toggle":
            self._do_toggle(params.get("macro"))
        elif action == "save":
            self._do_save(params)
        elif action == "setjoinmessage":
            self._do_set_join_message(params.get("value", ""))
        elif action == "togglejoinquick":
            self._do_toggle_join_quick()
        elif action == "checkupdate":
            threading.Thread(target=self._do_check_update, args=(True,), daemon=True).start()
        elif action == "applyupdate":
            threading.Thread(target=self._do_apply_update, daemon=True).start()
        elif action == "startdrag":
            wu.start_window_drag("Roblox Macro Suite")
        elif action == "minimize":
            if self._window:
                self._window.minimize()
        elif action == "exit":
            if self._window:
                self._window.destroy()

    # ------------------------------------------------------------------
    # DOM push helpers (replace SetVal / SetHtml / SetChecked)
    # ------------------------------------------------------------------
    def _push_update(self, update):
        with self._update_lock:
            self._pending_updates.append(update)

    def pop_updates(self):
        """Exposed on the js_api - the page polls this on an interval
        (see gui_template.html) and applies whatever's queued. This is the
        ONLY path DOM updates take now, so it doesn't matter which thread
        called _js_set_*/_on_screenshot_update; pywebview's js_api dispatch
        handles the actual cross-thread hop safely, unlike evaluate_js."""
        with self._update_lock:
            updates = list(self._pending_updates)
            self._pending_updates.clear()
        return updates

    def _js_set_val(self, elem_id, value):
        self._push_update({"type": "set_val", "id": elem_id, "value": value})

    def _js_set_html(self, elem_id, text):
        self._push_update({"type": "set_html", "id": elem_id, "text": text})

    def _js_set_checked(self, elem_id, state):
        self._push_update({"type": "set_checked", "id": elem_id, "state": bool(state)})

    def _js_set_capturing(self, state):
        self._push_update({"type": "set_capturing", "state": bool(state)})

    def _on_screenshot_update(self, path, png_bytes):
        # data: URI instead of file:// - WebView2 blocks local file://
        # resources when the page HTML came from html=... (no real origin),
        # so file:// silently fails to render even with a valid path.
        b64 = base64.b64encode(png_bytes).decode("ascii")
        url = "data:image/png;base64," + b64
        self._push_update({"type": "screenshot", "url": url})

    # ------------------------------------------------------------------
    # Set Key flow (replaces DoSetKey)
    # ------------------------------------------------------------------
    def _do_set_key(self, target):
        input_id = INPUT_IDS.get(target)
        status_id = STATUS_IDS.get(target)
        label = LABELS.get(target, target)
        if not input_id:
            return

        self._js_set_capturing(True)
        self._js_set_html(status_id, f"Status: Press any key to set as {label} key... (Esc to cancel, auto-cancels in 3s)")

        key = capture_next_key(timeout=3.0)

        if key == "esc":
            self._js_set_html(status_id, f"Status: {label} key capture cancelled - click Set Key to try again")
        elif key is None:
            self._js_set_html(status_id, f"Status: {label} key capture timed out - click Set Key to try again")
        else:
            self._js_set_val(input_id, key)
            self._js_set_html(status_id, f"Status: {label} key set to [{key}] - click Save Settings")

        self._js_set_capturing(False)

    # ------------------------------------------------------------------
    # Enable/disable toggle (replaces DoToggle)
    # ------------------------------------------------------------------
    def _do_toggle(self, macro):
        ekey = TOGGLE_ENABLED_KEY.get(macro)
        if not ekey:
            return
        e = self.settings["enabled"]
        e[ekey] = not e[ekey]
        save_settings(self.settings)

        if macro == "Screenshot":
            self.screenshot.set_enabled(e["screenshot"])
        else:
            self._apply_macro_binding(macro)

        self._js_set_checked(f"{macro}_toggle", e[ekey])

    # ------------------------------------------------------------------
    # Save Settings (replaces DoSave)
    # ------------------------------------------------------------------
    def _do_save(self, params):
        s = self.settings

        def keep_if_blank(new, old):
            return new if new else old

        s["trigger_key"] = keep_if_blank(params.get("trigger", ""), s["trigger_key"])
        s["spam_key"] = params.get("spamkey", s["spam_key"])
        try:
            s["spam_delay_ms"] = int(params.get("spamdelay") or s["spam_delay_ms"] or 10)
        except ValueError:
            s["spam_delay_ms"] = s["spam_delay_ms"] or 10
        s["click_trigger_key"] = keep_if_blank(params.get("clicktrigger", ""), s["click_trigger_key"])
        s["roll_trigger_key"] = keep_if_blank(params.get("rolltrigger", ""), s["roll_trigger_key"])
        s["roll_parry_trigger_key"] = keep_if_blank(params.get("rollparrytrigger", ""), s["roll_parry_trigger_key"])
        s["shfeint_trigger_key"] = keep_if_blank(params.get("shfeinttrigger", ""), s["shfeint_trigger_key"])
        s["mfeint_trigger_key"] = keep_if_blank(params.get("mfeinttrigger", ""), s["mfeint_trigger_key"])
        s["join_trigger_key"] = keep_if_blank(params.get("jointrigger", ""), s["join_trigger_key"])
        s["join_message"] = params.get("joinmessage", s["join_message"])
        s["prev_trigger_key"] = keep_if_blank(params.get("prevtrigger", ""), s["prev_trigger_key"])

        save_settings(s)
        self._rebind_all()

        def klabel(k):
            return k if k else "not set"

        self._js_set_html("StatusText", f"Status: Saved! Hold [{klabel(s['trigger_key'])}] to spam [{s['spam_key']}]")
        self._js_set_html("ClickStatusText", f"Status: Press [{klabel(s['click_trigger_key'])}] to click Button2 in Clumsy (while Roblox is focused)")
        self._js_set_html("RollStatusText", f"Status: Press [{klabel(s['roll_trigger_key'])}] to Roll Uppercut (Roblox only)")
        self._js_set_html("RollParryStatusText", f"Status: Press [{klabel(s['roll_parry_trigger_key'])}] to Roll Parry (Roblox only)")
        self._js_set_html("SHFeintStatusText", f"Status: Press [{klabel(s['shfeint_trigger_key'])}] to Rising Star Feint (Roblox only)")
        self._js_set_html("MFeintStatusText", f"Status: Press [{klabel(s['mfeint_trigger_key'])}] to Mayhem Feint (Roblox only)")
        self._js_set_html("JoinStatusText", f"Status: Press [{klabel(s['join_trigger_key'])}] to send [{s['join_message']}] and join (Roblox only)")
        self._js_set_html("PrevStatusText", f"Status: Press [{klabel(s['prev_trigger_key'])}] to rejoin Previous Server (Roblox only)")

    def _do_toggle_join_quick(self):
        s = self.settings
        s["join_quick_mode"] = not s["join_quick_mode"]
        save_settings(s)
        applog.log("gui", f"_do_toggle_join_quick -> {s['join_quick_mode']}")
        self._js_set_checked("JoinQuick_toggle", s["join_quick_mode"])

    def _do_set_join_message(self, value):
        self.settings["join_message"] = value
        save_settings(self.settings)
        jk = self.settings["join_trigger_key"] or "not set"
        self._js_set_html("JoinStatusText", f"Status: Press [{jk}] to send [{value}] and join (Roblox only)")

    # ------------------------------------------------------------------
    # Self-update (checkupdate / applyupdate)
    # ------------------------------------------------------------------
    def _do_check_update(self, manual=False):
        remote_version, manifest = updater.check_for_update()
        if remote_version is None:
            if manual:
                self._push_update({
                    "type": "update_result",
                    "message": f"You're up to date (version {updater.local_version() or 'dev'}).",
                })
            return
        self._pending_update = (remote_version, manifest)
        self._push_update({
            "type": "update_available",
            "version": remote_version,
            "current": updater.local_version() or "dev",
        })

    def _do_apply_update(self):
        if not self._pending_update:
            # "Update Now" clicked without a fresh check in hand (e.g. banner
            # left open a while) - re-check first rather than installing stale info.
            remote_version, manifest = updater.check_for_update()
            if remote_version is None:
                self._push_update({"type": "update_result", "message": "No update available anymore."})
                return
            self._pending_update = (remote_version, manifest)

        remote_version, manifest = self._pending_update
        self._push_update({"type": "update_result", "message": f"Downloading version {remote_version}..."})
        ok, message = updater.apply_update(remote_version, manifest)
        self._pending_update = None
        self._push_update({"type": "update_result", "message": message})

    # ------------------------------------------------------------------
    # Hotkey (re)binding
    # ------------------------------------------------------------------
    def _guarded(self, fn):
        """Only run a macro while Roblox is the focused window - matches
        every AHK macro label's #IfWinActive, ahk_exe RobloxPlayerBeta.exe."""
        if wu.is_roblox_active():
            threading.Thread(target=fn, daemon=True).start()
        else:
            applog.log("gui", f"_guarded: skipped {getattr(fn, '__name__', fn)} - Roblox not focused")

    def _rebind_all(self):
        for macro in MACRO_KEY_FIELD:
            self._apply_macro_binding(macro)

    def _apply_macro_binding(self, macro):
        key = self.settings[MACRO_KEY_FIELD[macro]]
        enabled = self.settings["enabled"][MACRO_ENABLED_FIELD[macro]]

        self.hotkeys.unbind(macro)
        if not key or not enabled:
            return

        # Two enabled macros sharing one physical key isn't supported: the
        # underlying `keyboard` library only ever runs the FIRST handler
        # registered for a given key and silently drops the rest, so the
        # loser looks like it "randomly" stops firing, and toggling one off
        # can look like nothing happened if the other is still bound to the
        # same key. Refuse the newer binding and surface it instead of
        # letting them silently fight over the key.
        existing = self.hotkeys.key_conflict(key)
        if existing:
            status_id = STATUS_IDS.get(macro)
            label = LABELS.get(macro, macro)
            other = ", ".join(sorted(existing))
            msg = f"Status: [{key}] is already used by {other} - pick a different key for {label}"
            applog.log("gui", f"_apply_macro_binding: REFUSED {macro} on key {key!r} - conflicts with {other}")
            if status_id:
                self._js_set_html(status_id, msg)
            return

        if macro == "Spam":
            self.hotkeys.bind_hold(
                macro, key,
                on_down=lambda: self.spam.start(key, self.settings["spam_key"], self.settings["spam_delay_ms"], wu.is_roblox_active),
                on_up=self.spam.stop,
            )
        elif macro == "Click":
            self.hotkeys.bind_oneshot(macro, key, lambda: self._guarded(macros.macro_click))
        elif macro == "Roll":
            self.hotkeys.bind_oneshot(macro, key, lambda: self._guarded(macros.macro_roll_uppercut))
        elif macro == "RollParry":
            self.hotkeys.bind_oneshot(macro, key, lambda: self._guarded(macros.macro_roll_parry))
        elif macro == "SHFeint":
            self.hotkeys.bind_oneshot(macro, key, lambda: self._guarded(macros.macro_sh_feint))
        elif macro == "MFeint":
            self.hotkeys.bind_oneshot(macro, key, lambda: self._guarded(macros.macro_m_feint))
        elif macro == "Join":
            self.hotkeys.bind_oneshot(macro, key, lambda: self._guarded(self.join_loop.toggle))
        elif macro == "Prev":
            self.hotkeys.bind_oneshot(macro, key, lambda: self._guarded(self.prev_loop.toggle))

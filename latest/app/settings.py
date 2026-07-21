import copy
import json
import os
import sys

from . import applog


def _data_dir():
    """Where settings.json (and the screenshot file) live. Next to the
    script normally; next to the .exe when frozen by PyInstaller, since
    a --onefile build's __file__ points at a temp dir that's wiped on exit."""
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


SETTINGS_FILE = os.path.join(_data_dir(), "settings.json")

DEFAULTS = {
    "ahk_exe_path": "",
    "trigger_key": "",
    "spam_key": "7",
    "spam_delay_ms": 10,
    "click_trigger_key": "",
    "roll_trigger_key": "",
    "roll_parry_trigger_key": "",
    "shfeint_trigger_key": "",
    "mfeint_trigger_key": "",
    "join_trigger_key": "",
    "join_message": "Foolhardy auburn farmer",
    "join_quick_mode": False,
    "prev_trigger_key": "",
    "enabled": {
        "spam": True,
        "click": True,
        "roll": True,
        "rollparry": True,
        "shfeint": True,
        "mfeint": True,
        "join": True,
        "prev": True,
        "screenshot": True,
    },
}


def data_dir():
    return _data_dir()


def load_settings():
    if os.path.exists(SETTINGS_FILE):
        try:
            with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            merged = copy.deepcopy(DEFAULTS)
            for k, v in data.items():
                if k == "enabled" and isinstance(v, dict):
                    merged["enabled"].update(v)
                else:
                    merged[k] = v
            applog.log("settings", f"load_settings: loaded from {SETTINGS_FILE}")
            return merged
        except Exception as e:
            applog.log("settings", f"load_settings: FAILED to parse {SETTINGS_FILE}: {e} - using defaults")
    else:
        applog.log("settings", f"load_settings: {SETTINGS_FILE} doesn't exist yet - using defaults")
    return copy.deepcopy(DEFAULTS)


def save_settings(settings):
    with open(SETTINGS_FILE, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2)
    applog.log("settings", f"save_settings: wrote {SETTINGS_FILE}")

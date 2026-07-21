"""
Central debug logger for the whole app. Every module below uses this
instead of print()/rolling its own log file, so there's exactly one place
to look when something goes wrong.

The log file lives next to the app itself (same folder as settings.json):
next to RobloxMacroSuite.exe when built with PyInstaller, or in the
project folder when running from source with `python main.py`.

Also prints to stdout (visible if you run `python main.py` from a console;
silent/harmless if not).
"""
import datetime
import os
import sys
import threading


def _app_dir():
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


LOG_FILE = os.path.join(_app_dir(), "roblox_macro_suite_debug.log")
_lock = threading.Lock()


def log(tag, msg):
    line = f"{datetime.datetime.now().isoformat(timespec='milliseconds')}  [{tag}]  {msg}"
    print(line)
    try:
        with _lock:
            with open(LOG_FILE, "a", encoding="utf-8") as f:
                f.write(line + "\n")
    except OSError:
        pass

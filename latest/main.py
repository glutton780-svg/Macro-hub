import ctypes
import sys
import threading
import traceback

import webview

from app import ahk_bridge, applog
from app.gui import App


def is_admin():
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def relaunch_as_admin():
    params = " ".join(f'"{a}"' for a in sys.argv)
    ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, params, None, 1)


def _log_uncaught(exc_type, exc_value, exc_tb):
    text = "".join(traceback.format_exception(exc_type, exc_value, exc_tb))
    applog.log("main", f"UNCAUGHT EXCEPTION (main thread):\n{text}")


def _log_uncaught_thread(args):
    text = "".join(traceback.format_exception(args.exc_type, args.exc_value, args.exc_traceback))
    applog.log("main", f"UNCAUGHT EXCEPTION (thread {args.thread.name}):\n{text}")


def main():
    # Without these, an unhandled exception anywhere - main thread or one
    # of the background threads (spam loop, screenshot, hotkey callbacks) -
    # would just silently kill that thread/process with nothing in the log,
    # which is exactly what happened last run.
    sys.excepthook = _log_uncaught
    threading.excepthook = _log_uncaught_thread

    applog.log("main", "app starting")

    if sys.platform != "win32":
        print("This app targets Windows (it drives Roblox via Win32 input APIs).")
        sys.exit(1)

    if not is_admin():
        applog.log("main", "not admin - relaunching elevated")
        relaunch_as_admin()
        sys.exit(0)

    # Starts (or reuses) the persistent macro_worker.ahk process that
    # actually sends keys/clicks to Roblox. Requires AutoHotkey installed -
    # see app/ahk_bridge.py's AHK_EXE if it's not on the default path.
    ahk_bridge.ensure_worker_running()

    app = App()
    html = app.render_html()

    window = webview.create_window(
        "Roblox Macro Suite",
        html=html,
        width=900,
        height=620,
        js_api=app,
        frameless=True,
        easy_drag=False,  # dragging is handled by the .pywebview-drag-region titlebar div instead
    )
    app._window = window

    try:
        webview.start(app.on_window_created, private_mode=False)
        applog.log("main", "webview.start() returned normally (window closed)")
    except Exception:
        applog.log("main", f"webview.start() raised:\n{traceback.format_exc()}")
        raise
    finally:
        applog.log("main", "app exiting - stopping AHK worker")
        ahk_bridge.stop_worker()


if __name__ == "__main__":
    main()

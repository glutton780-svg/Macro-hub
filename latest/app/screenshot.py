"""
Server Screenshot: periodically grabs the configured screen region while
Roblox is focused, and schedules one confirmation re-capture if the image
changed (same "hash it, and if it changed, look again in ~60s" logic as
the AHK SC_* functions) - all in-process with Pillow, no PowerShell needed.
"""
import base64
import hashlib
import io
import os
import threading

from PIL import ImageGrab

from . import applog
from . import config
from . import winutil as wu


class ScreenshotManager:
    def __init__(self, on_update, out_dir):
        self.on_update = on_update  # callback(file_path, png_bytes) after each successful capture
        self.out_file = os.path.join(out_dir, config.SCREENSHOT["out_file"])
        self._last_hash = None
        self._enabled = True
        self._stop_event = threading.Event()
        self._thread = None

    def set_enabled(self, enabled):
        applog.log("screenshot", f"set_enabled({enabled})")
        self._enabled = enabled

    def current_file_url(self):
        """Data URI for whatever's on disk from a previous capture, so the
        GUI has something to show on first render. Deliberately NOT a
        file:// URL - pywebview's WebView2 backend blocks loading local
        file:// resources when the page HTML was set via html=... (no real
        origin), so file:// silently fails to render even though the path
        is valid and the file exists."""
        if not os.path.exists(self.out_file):
            return ""
        try:
            with open(self.out_file, "rb") as f:
                b64 = base64.b64encode(f.read()).decode("ascii")
            return "data:image/png;base64," + b64
        except Exception as e:
            applog.log("screenshot", f"current_file_url FAILED to read {self.out_file}: {e}")
            return ""

    def start(self):
        applog.log("screenshot", f"start (polling {self.out_file})")
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def stop(self):
        applog.log("screenshot", "stop")
        self._stop_event.set()

    def _loop(self):
        interval = config.SCREENSHOT["interval_ms"] / 1000.0
        while not self._stop_event.is_set():
            self._capture_once()
            self._stop_event.wait(interval)

    def _capture_once(self):
        if not self._enabled:
            return
        if not wu.is_roblox_active():
            return

        x1, y1, x2, y2 = config.SCREENSHOT["region"]
        try:
            img = ImageGrab.grab(bbox=(x1, y1, x2, y2))

            buf = io.BytesIO()
            img.save(buf, "PNG")
            png_bytes = buf.getvalue()

            img.save(self.out_file, "PNG")
        except Exception as e:
            applog.log("screenshot", f"capture FAILED: {e}")
            return

        new_hash = hashlib.md5(png_bytes).hexdigest()

        self.on_update(self.out_file, png_bytes)

        if new_hash != self._last_hash:
            was_first_capture = self._last_hash is None
            self._last_hash = new_hash
            applog.log("screenshot", f"capture changed (first={was_first_capture}, hash={new_hash[:8]})")
            if not was_first_capture:
                delay = config.SCREENSHOT["recapture_delay_ms"] / 1000.0
                threading.Timer(delay, self._capture_once).start()

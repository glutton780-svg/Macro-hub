# Changelog

All notable changes to Roblox Macro Suite are logged here, most recent first.

## Unreleased

### Fixed
- Frameless window dragging (the custom titlebar) was choppy and spammed
  the console with repeated `[pywebview] Error while processing
  window.native.AccessibilityObject.Bounds.Empty.Empty...: maximum
  recursion depth exceeded` - pywebview's built-in `.pywebview-drag-region`
  handling on this WebView2/WinForms build polls native window/
  accessibility properties on every mouse-move during a drag, and that
  polling was recursing infinitely. Replaced it with a native OS-driven
  drag (`wu.start_window_drag` sends `WM_NCLBUTTONDOWN`/`HTCAPTION` to the
  window once on mousedown, same trick every frameless-window app uses),
  so Windows runs the whole drag itself with no per-frame polling.
  `gui_template.html`'s titlebar no longer uses the `pywebview-drag-region`
  class; dragging goes through `startTitlebarDrag()` -> the new
  `startdrag` action in `app/gui.py`.

### Added
- Self-updater, ported over from the old GUI.ahk build's
  `uploader.ps1`/`downloader.ps1`:
  - `app/updater.py` - checks `latest/version.txt` on the GitHub repo
    against a local `VERSION` file, and if different, downloads every file
    listed in `latest/manifest.json` (staged in a temp dir first, only
    copied into place if the whole download succeeds) so a network
    failure mid-update can't leave a half-updated app behind. Never
    overwrites `settings.json`, `VERSION`, or `server_capture.png`.
  - Wired into the GUI: silent check on launch, a "Check for updates"
    link in the sidebar, and an update banner with an "Update Now" button
    (`app/gui.py` `_do_check_update`/`_do_apply_update`, new banner markup
    + `update_available`/`update_result` push types in
    `gui_template.html`). Auto-checks but never auto-installs - you always
    click Update Now.
  - `tools/uploader.ps1` (+ `tools/run_uploader.bat`) - dev-side publish
    script, not shipped in the built .exe. Copies the whole project into
    `latest/` in the repo, regenerates `manifest.json`, bumps
    `latest/version.txt`, commits, pushes.
  - `tools/downloader.ps1` (+ `tools/run_downloader.bat`) - standalone
    bootstrap script, port of the old downloader.ps1. No Python/git/GitHub
    account needed; copy it into an empty folder and run it to fetch the
    whole project fresh, or drop it into an existing install to force an
    update without launching the app. `app/updater.py` handles updates
    once the app itself is running; this covers "don't have it running
    yet at all".
  - New `VERSION` file at project root tracking the currently-installed
    version locally.

### Removed
- Removed the hotkey "ignore window" failsafe (`HotkeyManager.ignore_key` /
  `_is_ignored`, and the matching call in `macros._send_key_safe`). It was
  added to stop a macro-injected keystroke (e.g. `RollParry` sending `f`)
  from re-triggering a real hotkey bound to that same physical key, but the
  side effect was that a real press/release landing inside its ~0.25s
  window got silently dropped, which showed up as the key seeming to "stick"
  or not register.
  - **Trade-off to be aware of:** the original bug this guarded against
    (Windows' low-level hook can't always tell an injected keystroke from a
    real one, so it's possible for a hotkey's internal down/up bookkeeping
    to get corrupted and end up thinking the key is permanently held) can
    theoretically resurface, most likely if a macro sends a key that's also
    bound to a hotkey (e.g. `f` inside `RollParry` while `f` is also your
    Parry keybind). If you notice a keybind stop firing until you tap the
    key twice, or firing repeatedly with no press, that's the symptom to
    watch for.
- `macros.set_hotkeys_manager()` and its call site in `gui.py` (only existed
  to wire up the failsafe above).

---

## How this file is maintained

Going forward, every change made to this codebase gets a dated entry below,
newest at the top. Each entry notes what changed, why, and any trade-offs
or follow-ups worth knowing about.

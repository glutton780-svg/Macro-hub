# Roblox Macro Suite (Python port)

A full port of the AHK GUI to Python. Same macro behavior, same HTML/CSS
front-end (rendered via `pywebview` instead of an embedded IE control), no
AutoHotkey involved anywhere.

## Setup (running from source)

```
pip install -r requirements.txt
python main.py
```

## Building a standalone .exe (no Python needed to run it)

```
build.bat
```

Run that once from this folder on Windows (needs Python/pip only for the
build itself). It installs the requirements + PyInstaller, then produces
`dist\RobloxMacroSuite.exe` - a single file with the interpreter and every
dependency baked in. That's the only file you need to share; whoever runs
it doesn't need Python, pip, or anything else installed.

Settings (`settings.json`) and the screenshot file get written next to
wherever the exe actually lives, so they survive between launches.

The app re-launches itself elevated (UAC prompt) on startup, same as the
AHK version - `keyboard`'s global hook and clicking into another process's
window generally need admin rights to work reliably.

pywebview needs a browser engine to render with. On Windows it uses the
**Edge WebView2 Runtime**, which ships with Windows 10/11 by default - if
you're on an older/stripped-down install and the window comes up blank,
grab it from Microsoft's site.

## What changed vs. the AHK version

- **GUI**: same `gui_template.html`/CSS, served through `pywebview` instead
  of the `Shell.Explorer` ActiveX control. Only one JS function (`nav()`)
  changed - it now calls into Python via `pywebview.api` instead of
  abusing `document.title` to smuggle commands out to AHK's `WB_TitleChange`.
- **Settings**: `settings.json` instead of `settings.ini`.
- **Screenshot**: captured directly with Pillow + hashlib, in-process - no
  more shelling out to `capture_screenshot.ps1`. That file isn't needed
  anymore.
- **Hotkeys**: the `keyboard` library's global hooks, gated in code on
  "is Roblox the foreground window" instead of AHK's `#IfWinActive`
  context.
- **Join-message typing**: reproduces the `{Text}`-mode Unicode injection
  trick from the AHK version exactly (`SendInput` + `KEYEVENTF_UNICODE`),
  since that was clearly solving a specific real bug (Roblox eating Space
  as Jump) rather than incidental AHK syntax.

## Self-updater

Ported over from the old GUI.ahk build's `uploader.ps1`/`downloader.ps1`
pair, adapted for this project's multi-file layout:

- **In-app checker** (`app/updater.py`): on launch, and whenever you click
  "Check for updates" in the sidebar, the app compares its local `VERSION`
  file against `latest/version.txt` in the GitHub repo. If they differ, a
  banner appears - clicking **Update Now** downloads every file listed in
  `latest/manifest.json` into a temp folder first, and only copies them
  over your local files if every download succeeded. Your `settings.json`,
  `VERSION`, and `server_capture.png` are never touched by an update.
  Restart the app afterwards to run the new version.
- **Publishing a new version** (`tools/uploader.ps1`, dev-side only, not
  shipped in the built .exe): run it from inside your git clone of the
  repo. It copies the whole project tree into `latest/`, regenerates
  `manifest.json`, bumps `latest/version.txt` to a timestamp, and pushes.
  `tools/run_uploader.bat` is a double-clickable wrapper for it.
- **Fresh installs / bootstrapping** (`tools/downloader.ps1` +
  `tools/run_downloader.bat`): standalone, no Python/git/GitHub account
  needed. Copy just this one file into an empty folder and run it to pull
  the whole project down for the first time - it downloads the same
  `latest/manifest.json` the in-app updater uses. Useful for a new machine
  that doesn't have the app running yet at all; once it does, use the
  in-app updater instead.

The repo/branch the updater checks are configured at the top of
`app/updater.py` (`REPO_USER`, `REPO_NAME`, `BRANCH`).

## Known rough edges to test on your end

- **ISO/UK backslash key**: the AHK version deliberately binds both `\`
  and `<>` as aliases for that physical key. `keyboard`'s key names don't
  necessarily line up 1:1 with AHK's - if you're on a UK/ISO keyboard and
  that key doesn't bind right, let me know and I'll add the matching alias.
- Coordinates in `app/config.py` (`JOIN`, `PREV`, `SCREENSHOT`) are carried
  over unchanged from the AHK file - they're tied to your screen
  resolution/window layout, same as before.

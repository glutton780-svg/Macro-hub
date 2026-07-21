"""
Self-updater: checks the project's GitHub repo for a newer version and can
pull the whole project down and swap it in.

Port of the old GUI.ahk build's uploader.ps1 / downloader.ps1 pair. Same
idea (compare version.txt, pull from raw.githubusercontent.com, no git
required on the machine running the app) but:

  - covers the WHOLE project tree via a manifest.json, not just two
    hardcoded files (this build is a Python package, not a single .ahk +
    .html pair)
  - lives inside the app itself and is wired into the GUI (checkupdate /
    applyupdate actions + the update banner in gui_template.html) instead
    of being a standalone script you double-click
  - never touches your local settings/data even if they show up in a
    manifest someone published, see PROTECTED_FILES/PROTECTED_DIRS

Publishing a new version is a separate concern - see tools/uploader.ps1,
which is the dev-side counterpart to this (bumps version.txt, regenerates
manifest.json, commits, pushes). That script is NOT shipped inside the
built .exe; it's a repo-maintainer tool, same role the old uploader.ps1
had.
"""
import json
import os
import shutil
import sys
import tempfile
import urllib.error
import urllib.request

from . import applog

# ===== CONFIG - same repo as the old downloader.ps1 ====
REPO_USER = "glutton780-svg"
REPO_NAME = "Macro-hub"
BRANCH = "main"
REMOTE_SUBDIR = "latest"  # published files live under this folder in the repo

BASE_URL = f"https://raw.githubusercontent.com/{REPO_USER}/{REPO_NAME}/{BRANCH}/{REMOTE_SUBDIR}"

# Never overwritten by an update, even if a manifest lists them - local
# data/config/runtime output, not shipped source.
PROTECTED_FILES = {"settings.json", "VERSION", "server_capture.png"}
PROTECTED_DIRS = {"__pycache__", ".git", "dist", "build", "data"}


def _project_root():
    """Same convention as app/settings.py's _data_dir() and app/gui.py's
    _resource_dir(): the folder next to main.py normally, next to the
    .exe when frozen by PyInstaller."""
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _version_file():
    return os.path.join(_project_root(), "VERSION")


def local_version():
    path = _version_file()
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return f.read().strip()
        except Exception:
            return ""
    return ""


def _fetch(url, timeout=10):
    req = urllib.request.Request(url, headers={"User-Agent": "roblox-macro-suite-updater"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def _is_protected(rel_path):
    norm = rel_path.replace("\\", "/").lstrip("/")
    if ".." in norm.split("/"):
        return True  # never trust a manifest entry that tries to escape the project dir
    top = norm.split("/")[0]
    base = os.path.basename(norm)
    return base in PROTECTED_FILES or top in PROTECTED_DIRS


def check_for_update():
    """Returns (remote_version, manifest_list) if a different version is
    published on GitHub, or (None, None) if already current / GitHub is
    unreachable / the manifest can't be read. Never raises."""
    try:
        remote_version = _fetch(f"{BASE_URL}/version.txt").decode("utf-8").strip()
    except Exception as e:
        applog.log("updater", f"check_for_update: could not reach GitHub: {e}")
        return None, None

    if remote_version == local_version():
        applog.log("updater", f"check_for_update: already up to date ({remote_version!r})")
        return None, None

    try:
        manifest = json.loads(_fetch(f"{BASE_URL}/manifest.json").decode("utf-8"))
        if not isinstance(manifest, list):
            raise ValueError("manifest.json is not a list")
    except Exception as e:
        applog.log("updater", f"check_for_update: failed to fetch/parse manifest.json: {e}")
        return None, None

    applog.log(
        "updater",
        f"check_for_update: update available, local={local_version()!r} "
        f"remote={remote_version!r}, {len(manifest)} files",
    )
    return remote_version, manifest


def apply_update(remote_version, manifest):
    """Downloads every file in `manifest` into a temp dir first; only if
    ALL downloads succeed does it copy anything over the live project, so
    a mid-update network failure can't leave a half-updated app behind.
    Returns (ok, message)."""
    root = _project_root()
    files = [p for p in manifest if not _is_protected(p)]
    skipped = len(manifest) - len(files)
    if skipped:
        applog.log("updater", f"apply_update: skipping {skipped} protected/unsafe manifest entries")

    tmp_dir = tempfile.mkdtemp(prefix="macro_hub_update_")
    try:
        for rel_path in files:
            norm = rel_path.replace("\\", "/").lstrip("/")
            dest_tmp = os.path.join(tmp_dir, norm)
            os.makedirs(os.path.dirname(dest_tmp), exist_ok=True)
            try:
                data = _fetch(f"{BASE_URL}/{norm}", timeout=20)
            except Exception as e:
                applog.log("updater", f"apply_update: failed downloading {norm}: {e}")
                return False, f"Update failed - couldn't download {norm} ({e}). Nothing was changed."
            with open(dest_tmp, "wb") as f:
                f.write(data)

        # Every file downloaded fine - now copy them over the live project.
        for rel_path in files:
            norm = rel_path.replace("\\", "/").lstrip("/")
            dst = os.path.join(root, norm)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copyfile(os.path.join(tmp_dir, norm), dst)

        with open(_version_file(), "w", encoding="utf-8") as f:
            f.write(remote_version)

        applog.log("updater", f"apply_update: updated to {remote_version}")
        return True, f"Updated to {remote_version}. Restart the app to use the new version."
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)

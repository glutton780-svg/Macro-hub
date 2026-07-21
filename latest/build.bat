@echo off
REM Builds a standalone RobloxMacroSuite.exe that end users can run with
REM no Python/pip install of their own - everything gets bundled in.
REM Run this once, from this folder, on Windows.

python -m pip install --upgrade pip
python -m pip install -r requirements.txt
python -m pip install pyinstaller

python -m PyInstaller --onefile --windowed --name RobloxMacroSuite ^
    --add-data "gui_template.html;." ^
    --add-data "ahk;ahk" ^
    main.py

echo.
echo Done. Your exe is at dist\RobloxMacroSuite.exe
echo That single file is all you need to share - no Python required to run it.
pause

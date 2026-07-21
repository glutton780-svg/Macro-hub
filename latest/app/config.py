"""
Constants that were hardcoded at the top of GUI.ahk and are NOT exposed
in the GUI (the AHK comments said "edit here if needed" for these).
Same deal here - change the numbers, not the code that uses them.
"""

ROBLOX_EXE = "RobloxPlayerBeta.exe"

# ===== Server Join click coordinates =====
JOIN = dict(
    msgbox=(1451, 177),
    send_btn=(1139, 240),
    join_btn=(957, 626),
    rejoin_btn=(1150, 123),
    # "Quick join + prev" mode: same loop, but the first mouse move each
    # cycle goes to the real Previous Server button (same spot as
    # PREV["prev_btn"] below) instead of rejoin_btn, and - like the real
    # Previous Server loop - double-clicks it instead of single-clicking.
    quick_rejoin_btn=(843, 124),
)

# ===== Previous Server click coordinates =====
PREV = dict(
    prev_btn=(843, 124),
    join_btn=(957, 626),
)

# ===== Server Screenshot settings =====
SCREENSHOT = dict(
    region=(371, 12, 575, 30),       # x1, y1, x2, y2
    interval_ms=60000,               # how often to poll/refresh
    recapture_delay_ms=80000,        # confirmation re-capture after a change is detected
    out_file="server_capture.png",
)

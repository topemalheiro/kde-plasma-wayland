#!/bin/bash
# Hubstaff launcher wrapper
# - Sets LC_ALL to avoid locale crash (see memory.md)
# - Runs Hubstaff inside kdocker so minimize/close goes to system tray

export LC_ALL=en_US.UTF-8

# Prevent double-launch (check actual binary, not kdocker to avoid self-match)
if pgrep -x "HubstaffClient.bin.x86_64" > /dev/null 2>&1; then
    echo "Hubstaff is already running." >&2
    exit 0
fi

# Launch Hubstaff via kdocker
# -o = iconify when obscured by other windows
# -q = quiet (no title-change notifications)
# -b = blind mode (suppress warning dialogs)
# -r = remove from pager
# skipTaskbar is handled by the hubstaff-tray-only KWin script instead
exec /home/tope/.local/bin/kdocker -o -q -b -r /home/tope/Hubstaff/HubstaffClient.bin.x86_64 "$@"

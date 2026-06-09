#!/bin/bash
# Hubstaff launcher wrapper
# - Sets LC_ALL to avoid locale crash (see memory.md)
# - Supports native tray mode (via settings.json) or kdocker fallback

export LC_ALL=en_US.UTF-8

# Prevent double-launch (check actual binary, not wrapper to avoid self-match)
if pgrep -x "HubstaffClient.bin.x86_64" > /dev/null 2>&1; then
    echo "Hubstaff is already running." >&2
    exit 0
fi

SETTINGS_FILE="$HOME/.local/share/Hubstaff/settings.json"

# Check if native tray-only mode is configured in settings.json
# taskbar_behavior=1 means "Only in system tray"
# main_window_close_action=2 means "Minimize to system tray"
use_native_tray=false
if command -v python3 &>/dev/null && [ -f "$SETTINGS_FILE" ]; then
    taskbar_behavior=$(python3 -c "import json; d=json.load(open('$SETTINGS_FILE')); print(d.get('client',{}).get('preferences',{}).get('taskbar_behavior',''))" 2>/dev/null)
    close_action=$(python3 -c "import json; d=json.load(open('$SETTINGS_FILE')); print(d.get('client',{}).get('preferences',{}).get('main_window_close_action',''))" 2>/dev/null)
    if [ "$taskbar_behavior" = "1" ] && [ "$close_action" = "2" ]; then
        use_native_tray=true
    fi
fi

if [ "$use_native_tray" = "true" ]; then
    # Native tray mode: launch directly, skip kdocker
    # The KWin rule (hubstaff-tray-only) handles skiptaskbar as safety net
    exec /home/tope/Hubstaff/HubstaffClient.bin.x86_64 "$@"
else
    # Fallback: launch via kdocker for external tray management
    exec /home/tope/.local/bin/kdocker -o -q -b -r /home/tope/Hubstaff/HubstaffClient.bin.x86_64 "$@"
fi

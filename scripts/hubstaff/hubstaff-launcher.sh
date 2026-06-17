#!/bin/bash
export LC_ALL=en_US.UTF-8
if pgrep -x "HubstaffClient.bin.x86_64" > /dev/null 2>&1; then
    echo "Hubstaff is already running." >&2
    exit 0
fi
exec "$HOME/.local/bin/kdocker" -o -q -b -r "$HOME/Hubstaff/HubstaffClient.bin.x86_64" "$@"

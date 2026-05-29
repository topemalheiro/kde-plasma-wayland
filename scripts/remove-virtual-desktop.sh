#!/bin/bash
# Removes the current virtual desktop (minimum 1 remains)

set -e

COUNT=$(qdbus6 org.kde.KWin /VirtualDesktopManager count)
if [ "$COUNT" -le 1 ]; then
    echo "Cannot remove the last virtual desktop."
    exit 1
fi

CURRENT=$(qdbus6 org.kde.KWin /VirtualDesktopManager current)
qdbus6 org.kde.KWin /VirtualDesktopManager removeDesktop "$CURRENT"

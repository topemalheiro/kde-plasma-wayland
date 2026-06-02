#!/bin/bash
# uninstall-servicemenu.sh — Remove the "Open with VS Code:" Dolphin right-click menu
# Usage: ./uninstall-servicemenu.sh

set -e

DESKTOP_FILE="$HOME/.local/share/kio/servicemenus/open-with-code.desktop"
BINARY="$HOME/.local/bin/open-with-code"

echo "=== Uninstalling Open with VS Code: servicemenu ==="

# Remove the servicemenu desktop file
if [ -f "$DESKTOP_FILE" ]; then
    rm "$DESKTOP_FILE"
    echo "  ✗ Removed: $DESKTOP_FILE"
else
    echo "  (not found) $DESKTOP_FILE"
fi

# Remove the helper binary
if [ -f "$BINARY" ]; then
    rm "$BINARY"
    echo "  ✗ Removed: $BINARY"
else
    echo "  (not found) $BINARY"
fi

# Refresh KDE service cache
if command -v kbuildsycoca6 >/dev/null 2>&1; then
    echo "Refreshing KDE service cache..."
    kbuildsycoca6 --noincremental
fi

echo ""
echo "✅ Uninstall complete."
echo "   Restart Dolphin if it is running: killall dolphin"

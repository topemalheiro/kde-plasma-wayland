#!/bin/bash
# make-folder-shortcut.sh — Create a proper KDE folder shortcut (.desktop Type=Link)
# Usage: ./make-folder-shortcut.sh <folder-path> [shortcut-name]
#
# Examples:
#   ./make-folder-shortcut.sh ~/Projects/MyProject
#   ./make-folder-shortcut.sh ~/Projects/MyProject "My Project"
#   ./make-folder-shortcut.sh /mnt/data/Backups Backups

set -e

FOLDER_PATH="${1:-}"
SHORTCUT_NAME="${2:-}"

if [ -z "$FOLDER_PATH" ]; then
    echo "Usage: $0 <folder-path> [shortcut-name]"
    echo ""
    echo "Examples:"
    echo "  $0 ~/Projects/MyProject"
    echo "  $0 ~/Projects/MyProject \"My Project\""
    exit 1
fi

# Resolve to absolute path
FOLDER_PATH="$(realpath -m "$FOLDER_PATH")"

# Derive name from folder if not provided
if [ -z "$SHORTCUT_NAME" ]; then
    SHORTCUT_NAME="$(basename "$FOLDER_PATH")"
fi

# Sanitize filename (remove/replace problematic chars)
FILENAME="$(echo "$SHORTCUT_NAME" | tr ' ' '_' | tr -cd '[:alnum:]_-').desktop"
OUTPUT="$HOME/Desktop/$FILENAME"

# Check if folder exists
if [ ! -d "$FOLDER_PATH" ]; then
    echo "Warning: Folder does not exist yet: $FOLDER_PATH"
    read -p "Create it? [y/N] " reply
    if [[ "$reply" =~ ^[Yy]$ ]]; then
        mkdir -p "$FOLDER_PATH"
    else
        echo "Cancelled."
        exit 1
    fi
fi

# Write the .desktop file
cat > "$OUTPUT" << EOF
[Desktop Entry]
Icon=folder
Name=$SHORTCUT_NAME
Type=Link
URL[$e]=file:$FOLDER_PATH
EOF

chmod +x "$OUTPUT"

echo "✅ Created: $OUTPUT"
echo "   Points to: $FOLDER_PATH"
echo ""
echo "Double-click it on your desktop to open in Dolphin."

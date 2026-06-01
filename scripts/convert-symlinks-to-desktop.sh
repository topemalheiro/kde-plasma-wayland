#!/bin/bash
# Converts Desktop symlinks to .desktop link files
# This makes Dolphin open the TARGET path instead of the symlink path

DESKTOP="$HOME/Desktop"

cd "$DESKTOP" || exit 1

for link in *; do
    if [ -L "$link" ]; then
        target=$(readlink -f "$link")
        if [ -d "$target" ]; then
            # It's a symlink to a directory - convert it
            echo "Converting: $link -> $target"
            
            # Remove the symlink
            rm "$link"
            
            # Create a .desktop link file
            cat > "$link.desktop" <<EOF
[Desktop Entry]
Type=Link
URL=file://$target
Icon=folder
Name=$link
EOF
            
            # Make it executable so it looks like a folder shortcut
            chmod +x "$link.desktop"
        fi
    fi
done

echo "Done. Symlinks converted to .desktop link files."
echo "These will open the target location directly in Dolphin."

#!/bin/bash
# Opens folders and .desktop Type=Link targets in VS Code:

for path in "$@"; do
    target="$path"

    # If it's a .desktop file, check if it's Type=Link and extract URL
    if [[ "$path" == *.desktop ]]; then
        type=$(grep -m1 "^Type=" "$path" 2>/dev/null | cut -d= -f2)
        if [ "$type" = "Link" ]; then
            # Extract URL field (handles URL[$e]= format)
            url=$(grep -m1 "^URL" "$path" 2>/dev/null | cut -d= -f2-)

            # Strip file: prefix if present (handles both file:/ and file:///)
            if [[ "$url" == file://* ]]; then
                url="${url#file://}"
            elif [[ "$url" == file:* ]]; then
                url="${url#file:}"
                # Also strip leading slashes if present after file:
                url="${url#/}"
                url="${url#/}"
            fi

            # Expand $HOME if present
            url="${url/\$HOME/$HOME}"

            if [ -d "$url" ]; then
                target="$url"
            fi
        fi
    fi

    # Resolve symlinks and relative paths
    if [ -e "$target" ]; then
        resolved=$(realpath -m "$target" 2>/dev/null || readlink -f "$target" 2>/dev/null || echo "$target")
        target="$resolved"
    fi

    # Open in VS Code: if it's a directory
    if [ -d "$target" ]; then
        code "$target" &
    fi
done

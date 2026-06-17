#!/bin/bash
# Wrapper for the "Open with VS Code:" Dolphin service menu.
# Installed to ~/.local/bin by install-servicemenu.sh.
# Loops over all selected files/folders and opens each in VS Code:
# while also updating the KDE jumplist state.

for f in "$@"; do
    "$HOME/.local/bin/open-with-code" "$f"
    python3 "$HOME/.local/bin/code-jumplist-manager" add "$f"
done

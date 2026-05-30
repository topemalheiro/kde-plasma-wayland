# KDE Plasma Customization Tasks

## Issues & Fixes

### 1. Dolphin Single-Window Mode ✅ FIXED
**Problem:** Clicking folders/shortcuts opens a new Dolphin window instead of reusing the existing one.
**Fix:** Set `OpenExternallyCalledFolderInNewTab=true` in `~/.config/dolphinrc`.
**Status:** Done. Folders clicked from outside Dolphin will now open in a new tab of the existing window.

### 2. Symlink Path Display in Dolphin ✅ FIXED
**Problem:** When clicking a Desktop symlink (e.g., `Agentic Coding Evals`), Dolphin shows the link path `/home/tope/Desktop/Agentic Coding Evals/` instead of the real target `/home/tope/Projects/Agentic Coding Evals/`.
**Fix:** Converted all Desktop symlinks to `.desktop` link files. These open the target location directly.
**Status:** Done. All 9 Desktop symlinks converted. Double-clicking now opens Dolphin at the actual target path.

### 3. Pin Recent Places to VS Code: Taskbar Icon ✅ WORKAROUND PROVIDED
**Problem:** Recent places appear in the taskbar right-click but cannot be pinned.
**Fix:** Created VS Code: launcher `.desktop` files for common project folders. These can be pinned to the taskbar as separate icons.
**Location:** `~/.local/share/applications/vscode-launchers/`
**Launchers Created:**
- `vscode-agentic-coding.desktop` → Agentic Coding Evals
- `vscode-os-toolkit.desktop` → OS Toolkit
- `vscode-kde.desktop` → KDE Plasma on Wayland
- `vscode-training.desktop` → Training Code
**To pin:** Open the app launcher (Super), search for the project name, right-click → `Pin to Task Manager`.
**Note:** Plasma 6 does not support pinning individual folders inside an app's taskbar menu. This is the best workaround.

### 4. Top-Level "Open with VS Code:" in Dolphin Right-Click ✅ FIXED
**Problem:** "Open Folder With VS Code:" is buried inside a submenu (`Open Folder With > Visual Studio Code:`).
**Fix:** Created KIO servicemenu at `~/.local/share/kio/servicemenus/open-with-code.desktop`.
**Status:** Done. "Open with VS Code:" and "Open Target with VS Code:" now appear at the top level when right-clicking folders in Dolphin.

### 5. Desktop Right-Click "Open with VS Code:" ✅ FIXED
**Problem:** Right-clicking a folder on the desktop shows no "Open with VS Code:" option.
**Fix:** Same KIO servicemenu (issue #4) applies to the desktop folder view.
**Status:** Done. Should appear after relogin or desktop restart.

### 6. .lnk / Shortcut Files Open Target with VS Code: ✅ FIXED
**Problem:** Right-clicking a `.desktop` shortcut or symlink file on the desktop doesn't offer "Open with VS Code:" for the target folder.
**Fix:** The `open-with-code.sh` script resolves symlinks and `.desktop` link files before opening VS Code:.
**Status:** Done. The script handles both regular folders and symlink/link targets.

---

## Files Created

| File | Purpose |
|---|---|
| `scripts/open-with-code.sh` | Resolves symlinks and opens target in VS Code: |
| `scripts/convert-symlinks-to-desktop.sh` | Converts Desktop symlinks to `.desktop` link files |
| `~/.local/share/kio/servicemenus/open-with-code.desktop` | Top-level right-click menu entry for folders |
| `~/.local/share/applications/vscode-launchers/*.desktop` | Taskbar-pinnable VS Code: project launchers |

## Remaining Tasks

- [ ] **Relogin required** for some desktop right-click changes to take effect.
- [ ] Test all right-click menus after relogin.
- [ ] Pin desired VS Code: launchers to taskbar manually.


## KWin Shortcut Trick (Command-Line)

**Problem:** Setting KWin window management shortcuts via System Settings GUI is slow and buried deep in menus.

**Trick:** Use `kwriteconfig6` to directly write to `~/.config/kglobalshortcutsrc`:

```bash
# Set "Keep Window Above Others" to Shift+Alt+Q
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Above Other Windows" "Shift+Alt+Q,,Keep Window Above Others"

# Example: Set "Keep Window Below Others" to Shift+Alt+A
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Below Other Windows" "Shift+Alt+A,,Keep Window Below Others"
```

**Format:** `primaryShortcut,alternateShortcut,description`

**Apply:** Restart KWin (`kwin_wayland --replace &`) or relogin.

**Find available actions:**
```bash
grep -oP '^[^=]+' ~/.config/kglobalshortcutsrc | grep -i "window\|above\|below\|fullscreen\|minimize\|maximize"
```

**Why this is useful:**
- Batch-configure multiple shortcuts via script
- Replicate settings across machines
- Version-control your KDE shortcuts

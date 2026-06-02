# KDE Plasma Customization Tasks

## Overview

This document tracks all KDE Plasma 6 customizations applied to this system. Each entry includes:
- **Problem** — What was broken or missing
- **Method** — Exact technical steps used to fix it
- **Files Modified/Created** — Full paths for audit and reversal
- **Deactivation** — How to undo the change
- **Status** — Current state

---

## Issues & Fixes

### 1. Dolphin Single-Window Mode ✅ FIXED

**Problem:** Clicking folders/shortcuts from outside Dolphin (e.g., desktop, app launcher) opens a new Dolphin window instead of reusing the existing one.

**Method:**
Dolphin's `dolphinrc` config file (`~/.config/dolphinrc`) controls this behavior. The key `OpenExternallyCalledFolderInNewTab` defaults to `false`. Setting it to `true` causes Dolphin to open external folder requests in a new tab of an existing window rather than spawning a new process.

**Command used:**
```bash
kwriteconfig6 --file dolphinrc --group General --key OpenExternallyCalledFolderInNewTab true
```

**Files modified:**
- `~/.config/dolphinrc` — added `OpenExternallyCalledFolderInNewTab=true` under `[General]`

**Deactivation:**
```bash
kwriteconfig6 --file dolphinrc --group General --key OpenExternallyCalledFolderInNewTab false
# Or delete the line manually from ~/.config/dolphinrc
```

**Status:** Done. Folders clicked from outside Dolphin now open in a new tab of the existing window.

---

### 2. Symlink Path Display in Dolphin ✅ FIXED

**Problem:** When clicking a Desktop symlink (e.g., `Agentic Coding Evals`), Dolphin displays the symlink path (`/home/tope/Desktop/Agentic Coding Evals/`) in the location bar instead of the real target path (`/home/tope/Projects/Agentic Coding Evals/`).

**Method:**
KDE `.desktop` files with `Type=Link` are interpreted by Dolphin as "open this URL" rather than "navigate to this file's location." Each Desktop symlink to a directory was replaced with a `.desktop` file containing a `URL` field pointing to the target.

The conversion script (`scripts/convert-symlinks-to-desktop.sh`) automated this:
1. Iterates all symlinks in `~/Desktop`
2. Resolves each symlink with `readlink -f`
3. Deletes the symlink
4. Creates a `.desktop` file with `Type=Link` and `URL=file://<target>`
5. Sets `chmod +x` on the `.desktop` file so KDE treats it as a trusted launcher

**Files created (examples):**
- `~/Desktop/Agentic Coding Evals.desktop` → points to `~/Projects/Agentic Coding Evals`
- `~/Desktop/Training Code.desktop` → points to `~/Projects/Training Code`
- (and 7 others)

**Files modified:**
- Original symlinks in `~/Desktop/` were deleted and replaced with `.desktop` files

**Deactivation:**
There is no automatic reversal script. To undo, manually delete each `.desktop` file and recreate the original symlink:
```bash
rm ~/Desktop/"Agentic Coding Evals.desktop"
ln -s ~/Projects/"Agentic Coding Evals" ~/Desktop/
```

**Status:** Done. All Desktop directory symlinks converted. Double-clicking now opens Dolphin at the actual target path.

---

### 3. Pin Recent Places to VS Code: Taskbar Icon ✅ WORKAROUND PROVIDED

**Problem:** VS Code:'s taskbar icon shows recent folders in its right-click menu, but Plasma 6 does not allow pinning individual folders inside an application's taskbar menu.

**Method:**
Plasma 6's task manager only allows pinning `.desktop` files (applications), not individual documents or folders. The workaround creates standalone `.desktop` launcher files for each project. Each launcher is a full application entry that opens VS Code: with a specific folder. Because they are independent `.desktop` files, they can be individually pinned to the taskbar.

The launchers were created in `~/.local/share/applications/vscode-launchers/` with this structure:
```ini
[Desktop Entry]
Type=Application
Name=KDE Plasma on Wayland (VS Code:)
Exec=/usr/bin/code /home/tope/Projects/KDE-Plasma-on-Wayland
Icon=visual-studio-code
```

After creation, `kbuildsycoca6 --noincremental` refreshes the application menu so they appear in search.

**Files created:**
- `~/.local/share/applications/vscode-launchers/vscode-agentic-coding.desktop`
- `~/.local/share/applications/vscode-launchers/vscode-os-toolkit.desktop`
- `~/.local/share/applications/vscode-launchers/vscode-kde.desktop`
- `~/.local/share/applications/vscode-launchers/vscode-training.desktop`

**Deactivation:**
```bash
rm -rf ~/.local/share/applications/vscode-launchers/
kbuildsycoca6 --noincremental
# Remove any pinned icons from the taskbar manually
```

**Status:** Done. Workaround available. Pinning must be done manually via taskbar right-click.

---

### 4. Top-Level "Open with VS Code:" in Dolphin Right-Click ✅ FIXED

**Problem:** "Open Folder With VS Code:" is buried inside a submenu (`Open Folder With > Visual Studio Code:`) instead of appearing directly in the top-level context menu.

**Method:**
KIO (KDE's I/O framework) supports custom context menus via **servicemenu** `.desktop` files placed in `~/.local/share/kio/servicemenus/`. These files use `X-KDE-ServiceTypes=KonqPopupMenu/Plugin` to register as context menu plugins and `MimeType=inode/directory;application/x-desktop;` to specify which file types they apply to.

The servicemenu (`open-with-code.desktop`) defines an action that invokes the `open-with-code` helper binary with the selected file paths (`%F`).

**Critical security requirement:** KDE enforces that user-owned `.desktop` files in `servicemenus/` must have the **executable bit** set. Without `chmod +x`, Dolphin logs:
```
Access to "/home/tope/.local/share/kio/servicemenus/open-with-code.desktop" denied,
not owned by root and executable flag not set.
```

**Helper binary:**
The `open-with-code.c` program:
1. Checks if the input is a `.desktop` file with `Type=Link`
2. If so, extracts the `URL` field, strips `file://`/`file:` prefixes, expands `$HOME`
3. Resolves symlinks via `realpath()`
4. Verifies the target is a directory
5. Forks and execs `code <target>` for each valid directory

**Install script:** `scripts/install-servicemenu.sh`
- Compiles `open-with-code.c` → `~/.local/bin/open-with-code`
- Copies `open-with-code.desktop` → `~/.local/share/kio/servicemenus/`
- **Sets `chmod +x` on the installed `.desktop` file**
- Runs `kbuildsycoca6 --noincremental` to refresh the service cache

**Files created/modified:**
- `~/.local/share/kio/servicemenus/open-with-code.desktop` (installed by script)
- `~/.local/bin/open-with-code` (compiled by script)

**Deactivation:**
Run the uninstall script:
```bash
./scripts/uninstall-servicemenu.sh
```
Or manually:
```bash
rm ~/.local/share/kio/servicemenus/open-with-code.desktop
rm ~/.local/bin/open-with-code
kbuildsycoca6 --noincremental
killall dolphin
```

**Status:** Done. "Open with VS Code:" appears at the top level. See `scripts/install-servicemenu.sh` and `scripts/uninstall-servicemenu.sh`.

---

### 5. Desktop Right-Click "Open with VS Code:" ✅ FIXED

**Problem:** Right-clicking a folder icon on the Plasma desktop shows no "Open with VS Code:" option.

**Method:**
The Plasma desktop folder view uses the same KIO servicemenu framework as Dolphin. The fix for issue #4 automatically applies here because the servicemenu matches `inode/directory` (folder icons on the desktop have this MIME type).

**Files created:** Same as issue #4

**Deactivation:** Same as issue #4

**Status:** Done. Appears immediately after Dolphin restart or `kbuildsycoca6 --noincremental`.

---

### 6. .desktop / Shortcut Files Open Target with VS Code: ✅ FIXED

**Problem:** Right-clicking a `.desktop` shortcut (Type=Link) or symlink file on the desktop doesn't offer "Open with VS Code:" for the target folder.

**Method:**
The servicemenu matches `application/x-desktop` (MIME type of `.desktop` files). When invoked on a `.desktop` file, the `open-with-code` helper:
1. Opens the file and verifies `Type=Link`
2. Extracts the `URL` field (handles `URL[$e]=` syntax)
3. Strips `file://`, `file:/`, `file:` prefixes
4. Expands `$HOME` environment variable
5. Calls `realpath()` to resolve any remaining symlinks
6. Opens the resolved directory in VS Code:

This ensures that right-clicking a desktop shortcut opens the *target* folder, not the shortcut file itself.

**Files created:** Same as issue #4 (`open-with-code.c` / `open-with-code.sh`)

**Deactivation:** Same as issue #4

**Status:** Done. The helper handles both regular folders and symlink/link targets.

---

### 7. Hubstaff Crash-Restart Loop on Wayland ✅ FIXED

**Problem:** Hubstaff opens, stays visible for ~3 seconds, crashes with exit code 255, and its built-in watchdog immediately restarts it — creating an infinite open/close loop.

**Root Cause:** KDE Plasma's regional format settings (`~/.config/plasma-localerc`) set `LC_TIME=pt_PT.UTF-8`, but the `pt_PT.UTF-8` locale is **not generated** on the system. Hubstaff fails locale initialization and crashes. Its internal watchdog then auto-restarts the child process, causing the loop.

**Method:**
1. Changed `LC_TIME` in `~/.config/plasma-localerc` from `pt_PT.UTF-8` to `en_US.UTF-8` (the latter is generated and valid).
2. Modified the Hubstaff `.desktop` launcher to explicitly set `LC_ALL=en_US.UTF-8` in the `Exec` line, ensuring Hubstaff always launches with a valid locale regardless of session environment.

**Files modified:**
- `~/.config/plasma-localerc` — `LC_TIME=en_US.UTF-8` (was `pt_PT.UTF-8`)
- `~/.local/share/applications/netsoft-com.netsoft.hubstaff.desktop` — `Exec` now points to `hubstaff-launcher.sh`
- `~/Hubstaff/hubstaff-launcher.sh` — new wrapper script that sets `LC_ALL=en_US.UTF-8` before execing the real binary

**Deactivation:**
```bash
# Revert plasma locale setting
kwriteconfig6 --file plasma-localerc --group Formats --key LC_TIME pt_PT.UTF-8

# Revert Hubstaff desktop file
sed -i 's|Exec="/home/tope/Hubstaff/hubstaff-launcher.sh"|Exec="/home/tope/Hubstaff/HubstaffClient.bin.x86_64"|' ~/.local/share/applications/netsoft-com.netsoft.hubstaff.desktop

# Remove wrapper script
rm /home/tope/Hubstaff/hubstaff-launcher.sh
```

**Status:** Done. Hubstaff now launches and stays running.

---

## File Inventory

### Source Files (in repo)

| File | Purpose |
|------|---------|
| `scripts/install-servicemenu.sh` | One-shot install: compiles binary, installs servicemenu, sets +x, refreshes cache |
| `scripts/uninstall-servicemenu.sh` | Removes all traces of the servicemenu and helper binary |
| `scripts/open-with-code.desktop` | KIO servicemenu definition (must be `chmod +x` when installed) |
| `scripts/open-with-code.c` | Helper binary source — resolves .desktop links, opens VS Code: |
| `scripts/open-with-code.sh` | Shell equivalent of the C helper (for reference/debugging) |
| `scripts/convert-symlinks-to-desktop.sh` | Converts Desktop symlinks to `.desktop` link files |
| `make-folder-shortcut.sh` | Creates a single KDE folder shortcut `.desktop` file |

### Installed Files (on system)

| File | Purpose | Deletion Command |
|------|---------|------------------|
| `~/.local/share/kio/servicemenus/open-with-code.desktop` | Dolphin/desktop right-click menu entry | `rm ~/.local/share/kio/servicemenus/open-with-code.desktop` |
| `~/.local/bin/open-with-code` | Compiled helper binary | `rm ~/.local/bin/open-with-code` |
| `~/.local/share/applications/vscode-launchers/*.desktop` | Taskbar-pinnable VS Code: project launchers | `rm -rf ~/.local/share/applications/vscode-launchers/` |
| `~/Desktop/*.desktop` (Type=Link) | Folder shortcuts created from symlinks | Delete individually and recreate symlinks |
| `~/.local/share/applications/netsoft-com.netsoft.hubstaff.desktop` | Hubstaff launcher with locale workaround | `sed -i 's|Exec=env LC_ALL=en_US.UTF-8 |Exec=|' ~/.local/share/applications/netsoft-com.netsoft.hubstaff.desktop` |

### Modified Config Files

| File | Key Changed | Reversal Command |
|------|-------------|------------------|
| `~/.config/dolphinrc` | `OpenExternallyCalledFolderInNewTab=true` | `kwriteconfig6 --file dolphinrc --group General --key OpenExternallyCalledFolderInNewTab false` |
| `~/.config/plasma-localerc` | `LC_TIME=en_US.UTF-8` (was `pt_PT.UTF-8`) | `kwriteconfig6 --file plasma-localerc --group Formats --key LC_TIME pt_PT.UTF-8` |
| `~/.local/share/applications/netsoft-com.netsoft.hubstaff.desktop` | `Exec=env LC_ALL=en_US.UTF-8 ...` (was `Exec="/home/tope/Hubstaff/HubstaffClient.bin.x86_64" %u`) | `sed -i 's|Exec=env LC_ALL=en_US.UTF-8 |Exec=|' ~/.local/share/applications/netsoft-com.netsoft.hubstaff.desktop` |

---

## Security & Deactivation Strategy

### Design Principle: User-Space Only

All customizations are confined to the user's home directory (`~/.local/`, `~/.config/`, `~/Desktop/`). **No root access, system packages, or immutable files are modified.** This means:
- Customizations can be removed entirely by deleting files in `$HOME`
- No package manager conflicts on system upgrades
- Easy to audit: `find ~/.local/share/kio ~/.local/bin ~/.local/share/applications -name "*code*" -o -name "*vscode*"`

### Quick Deactivation (All Customizations)

Run the provided uninstall scripts, then remove remaining files:

```bash
# 1. Remove the Dolphin right-click servicemenu
./scripts/uninstall-servicemenu.sh

# 2. Remove taskbar-pinnable VS Code: launchers
rm -rf ~/.local/share/applications/vscode-launchers/

# 3. Revert Dolphin single-window mode
kwriteconfig6 --file dolphinrc --group General --key OpenExternallyCalledFolderInNewTab false

# 4. Refresh KDE caches
kbuildsycoca6 --noincremental

# 5. Restart affected applications
killall dolphin
kquitapp6 plasmashell && kstart6 plasmashell
```

### Granular Deactivation (Per-Feature)

| Feature | Toggle On | Toggle Off |
|---------|-----------|------------|
| Dolphin single-window mode | `kwriteconfig6 --file dolphinrc --group General --key OpenExternallyCalledFolderInNewTab true` | `kwriteconfig6 --file dolphinrc --group General --key OpenExternallyCalledFolderInNewTab false` |
| Top-level "Open with VS Code:" | `./scripts/install-servicemenu.sh` | `./scripts/uninstall-servicemenu.sh` |
| VS Code: taskbar launchers | Create files in `~/.local/share/applications/vscode-launchers/` | `rm -rf ~/.local/share/applications/vscode-launchers/` |

### Future-Proofing

- **Keep `scripts/install-servicemenu.sh` and `scripts/uninstall-servicemenu.sh` in version control.** These are idempotent and can be re-run after system reinstalls.
- **The `open-with-code.desktop` must always be installed with `chmod +x`.** The install script handles this automatically.
- **KDE upgrades may reset `dolphinrc`.** The `OpenExternallyCalledFolderInNewTab` setting is persistent but can be re-applied with the one-liner above.
- **Plasma 6 taskbar pinning behavior may change.** The VS Code: launcher workaround is independent of VS Code: itself and will survive app updates.

---

## Remaining Tasks

- [x] Test all right-click menus after fix. — **PASSED**
- [ ] Pin desired VS Code: launchers to taskbar manually.

---

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

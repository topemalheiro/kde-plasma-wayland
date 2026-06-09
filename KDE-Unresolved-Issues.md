# KDE Plasma — Unresolved Issues Tracker

> This document tracks issues that are **not yet fixed** or require ongoing workarounds. For completed fixes, see `KDE-Customization-TODO.md`.

---

## Issue 1: Hubstaff Minimizes to Taskbar Instead of System Tray

### Status: ✅ FIXED (two-layer solution)

### Problem
Closing/minimizing the Hubstaff window leaves it visible in the KDE panel/taskbar. The user wants it to disappear from the taskbar entirely and live only as a system tray icon.

### Why kdocker Alone Wasn't Enough
Hubstaff runs as a **native Wayland** window (not XWayland). kdocker is an X11-based tool — its `-t` (skip-taskbar) flag sets X11 window properties that have no effect on native Wayland windows. So while kdocker created the tray icon, the window remained in the taskbar.

### Solution: kdocker + KWin Script

**Layer 1 — kdocker** (`~/Hubstaff/hubstaff-launcher.sh`)
- Creates the system tray icon
- Handles show/hide when clicking the tray icon
- Flags used: `-t -o -q -b -r`

**Layer 2 — KWin Script** (`hubstaff-tray-only`)
- A native Wayland KWin script that hooks `window.minimizedChanged`
- When Hubstaff is minimized → sets `skipTaskbar = true` (hides from taskbar)
- When Hubstaff is restored → sets `skipTaskbar = false` (shows in taskbar)
- Also sets `skipPager` to match

### Files Created/Modified

| File | Purpose |
|------|---------|
| `~/Hubstaff/hubstaff-launcher.sh` | Wraps Hubstaff in kdocker with tray flags |
| `~/.local/share/kwin/scripts/hubstaff-tray-only/` | KWin script for native Wayland taskbar hiding |
| `~/.config/kwinrc` | Enables the KWin script (`hubstaff-tray-onlyEnabled=true`) |

### How to Apply / Verify

The changes are already applied. If Hubstaff is running, **minimize it now** — it should disappear from the taskbar and only the kdocker tray icon should remain. Click the tray icon to restore it.

If it's not working, try reloading KWin:
```bash
qdbus org.kde.KWin /KWin reconfigure
```

Or for a full restart:
```bash
killall HubstaffClient.bin.x86_64 HubstaffCLI.bin.x86_64
~/Hubstaff/hubstaff-launcher.sh &
```

### Deactivation

**Remove kdocker wrapper:**
Edit `~/Hubstaff/hubstaff-launcher.sh` back to:
```bash
#!/bin/bash
export LC_ALL=en_US.UTF-8
exec /home/tope/Hubstaff/HubstaffClient.bin.x86_64 "$@"
```

**Remove KWin script:**
```bash
kpackagetool6 --type KWin/Script --remove hubstaff-tray-only
```

---

## Issue 2: Pasting Images in VS Code: / Kimi Extension Fails

### Status: ✅ FIXED

### Problem
After taking a screenshot with Spectacle, pasting the image into VS Code: (specifically the Kimi extension chat panel) fails with:
> "There is not an image in the clipboard."

### Root Cause
Spectacle copies images to the **Wayland** clipboard as `image/png`. However, VS Code: on KDE Plasma Wayland usually runs under **XWayland**, which reads from the **X11** clipboard — not the Wayland clipboard. KDE's built-in clipboard sync does not reliably propagate `image/png` across the XWayland boundary, so VS Code: sees nothing.

The initial bridge script only copied to the Wayland clipboard, which is why it didn't work.

### Solution: Dual Clipboard Bridge
The `scripts/clipboard-image-bridge.sh` now copies the image to **both** the X11 clipboard (for XWayland apps like VS Code:) and the Wayland clipboard (for native Wayland apps). It also provides `text/uri-list` as a fallback.

### What It Does
1. Detects whether the image is on the Wayland or X11 clipboard
2. Saves it to a temp file
3. Re-copies `image/png` to the **X11 clipboard** via `xclip`
4. Re-copies `image/png` to the **Wayland clipboard** via `wl-copy`
5. Re-copies `text/uri-list` to Wayland as a fallback

### Usage
```bash
# One-shot fix (run this after a failed paste)
scripts/clipboard-image-bridge.sh fix

# Or start the background daemon (auto-fixes every screenshot)
scripts/clipboard-image-bridge.sh start

# Stop the daemon
scripts/clipboard-image-bridge.sh stop
```

### Reprompty Integration
Three actions are available in Reprompty under **Scripts → Clipboard Image Bridge**:
- `clipboard_image_fix` — one-shot fix
- `clipboard_image_monitor_start` — start daemon
- `clipboard_image_monitor_stop` — stop daemon

### Verification
After running `fix`, both clipboards should contain `image/png`:
```bash
# Wayland
wl-paste --list-types

# X11
xclip -selection clipboard -o -target TARGETS
```

### Deactivation
```bash
scripts/clipboard-image-bridge.sh stop
```

---

## Issue 3: Elastic Overscroll — "Scroll Out of Pages"

### Status: ✅ FIXED (app-level flags)

### Problem
Scrolling past the top/bottom of webpages and documents shows empty space with an elastic bounce-back effect.

### Root Cause
There is **no single KDE system setting** for overscroll. Each app stack implements its own elastic overscroll:
- **Chromium/Electron apps** (VS Code:, Chrome, Edge) — Chromium compositor overscroll
- **Firefox/Librewolf** — `apz.overscroll.enabled`
- **Qt 6 native apps** — Limited overscroll via Qt Wayland platform plugin

### Solution: App-Level Flags

**VS Code: (`~/.config/code-flags.conf`)**
```
--disable-overscroll-edge-effect
```
VS Code: reads this file on Linux and appends the flags on launch.

**Google Chrome (`~/.local/share/applications/google-chrome.desktop`)**
Added `--disable-overscroll-edge-effect` to all `Exec=` lines.

**Microsoft Edge (`~/.local/share/applications/microsoft-edge.desktop`)**
Added `--disable-overscroll-edge-effect` to all `Exec=` lines.

**Librewolf (`~/.config/librewolf/librewolf/<profile>/user.js`)**
```js
user_pref("apz.overscroll.enabled", false);
```

### What Was Not Changed
Qt 6 native KDE apps (Dolphin, Kate, etc.) were left as-is. Their overscroll is minimal compared to Chromium, and forcing them to XWayland would degrade fractional scaling and HiDPI behavior.

### How to Apply
**Restart affected apps** for the flags to take effect:
```bash
# Restart VS Code:
killall code; code &

# Restart Chrome/Edge
# (Close all windows and reopen from the app menu)

# Restart Librewolf
# (Close and reopen)
```

### Deactivation

**VS Code:** Delete `~/.config/code-flags.conf`

**Chrome/Edge:** Edit the `.desktop` files in `~/.local/share/applications/` and remove `--disable-overscroll-edge-effect`

**Librewolf:** Edit `~/.config/librewolf/librewolf/<profile>/user.js` and remove the `apz.overscroll.enabled` line

---

## Summary

| Issue | Status | What Was Done |
|-------|--------|--------------|
| Hubstaff tray minimize | ✅ Fixed | kdocker tray icon + KWin script for native Wayland taskbar hiding |
| Image paste failures | ✅ Fixed | Dual clipboard bridge (X11 + Wayland) |
| Elastic overscroll | ✅ Fixed | App-level flags for VS Code:, Chrome, Edge, Librewolf |

---

*Last updated: 2026-06-09*

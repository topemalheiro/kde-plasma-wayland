# KDE Plasma — Unresolved Issues Tracker

> This document tracks issues that are **not yet fixed** or require ongoing workarounds. For completed fixes, see `KDE-Customization-TODO.md`.

---

## Issue 1: Hubstaff Minimizes to Taskbar Instead of System Tray

### Status: ✅ FIXED (three-layer solution)

### Problem
Closing/minimizing the Hubstaff window leaves it visible in the KDE panel/taskbar. The user wants it to disappear from the taskbar entirely and live only as a system tray icon. Additionally, if Hubstaff crashes, it should auto-restart and remain tray-only.

### Why kdocker Alone Wasn't Enough
Hubstaff runs as an **XWayland** window. kdocker is an X11-based tool that docks windows to the system tray. However:
1. kdocker's `-t` (skip-taskbar) flag conflicted with a KWin script, causing `gtk_widget_destroy` assertion failures and crashes
2. If Hubstaff crashed and restarted itself, the new window appeared on the desktop (not docked to tray)
3. Hubstaff also registers its **own** native tray icon via Ayatana/AppIndicator, creating a second tray icon

### Solution: kdocker + KWin Window Rule + Systemd Service

**Layer 1 — kdocker** (`~/Hubstaff/hubstaff-launcher.sh`)
- Creates the system tray icon
- Intercepts close/minimize and hides the window to tray
- Flags used: `-o -q -b -r` (removed `-t` to avoid conflict with KWin rule)

**Layer 2 — KWin Window Rule** (`~/.config/kwinrulesrc`)
- Permanently applies `skipTaskbar=true` and `skipPager=true` to ALL Hubstaff windows
- Works regardless of how Hubstaff is launched (kdocker, watchdog restart, manual launch)
- More reliable than the previous KWin script which toggled on `minimizedChanged`

**Layer 3 — Systemd User Service** (`~/.config/systemd/user/hubstaff.service`)
- Auto-starts Hubstaff at login
- Restarts on crash (`Restart=on-failure`)
- Always launches through the kdocker wrapper
- Disabled the old desktop autostart to avoid double-launch

### Files Created/Modified

| File | Purpose |
|------|---------|
| `~/Hubstaff/hubstaff-launcher.sh` | Wraps Hubstaff in kdocker with LC_ALL fix |
| `~/.config/kwinrulesrc` | KWin window rule for permanent taskbar hiding |
| `~/.config/systemd/user/hubstaff.service` | Auto-start and auto-restart on crash |
| `~/.config/autostart/netsoft-com.netsoft.hubstaff.desktop.disabled` | Old autostart disabled |

### How to Apply / Verify

```bash
# Reload everything
systemctl --user daemon-reload
systemctl --user enable hubstaff.service
systemctl --user restart hubstaff.service
qdbus org.kde.KWin /KWin reconfigure
```

**Note:** There will be **two** tray icons:
1. **kdocker icon** (generic window icon) — click to show/hide the Hubstaff window
2. **Hubstaff native icon** (Ayatana/AppIndicator) — provides Hubstaff-specific menu options

You can close the kdocker icon if you only need Hubstaff's native menu, but you will lose the "close/minimize to tray" behavior.

### Deactivation

```bash
systemctl --user disable hubstaff.service
systemctl --user stop hubstaff.service
mv ~/.config/autostart/netsoft-com.netsoft.hubstaff.desktop.disabled ~/.config/autostart/netsoft-com.netsoft.hubstaff.desktop
# Remove KWin rule via System Settings → Window Rules
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

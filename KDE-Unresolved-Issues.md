# KDE Plasma — Unresolved Issues Tracker

> This document tracks issues that are **not yet fixed** or require ongoing workarounds. For completed fixes, see `KDE-Customization-TODO.md`.

---

## Issue 1: Hubstaff Minimizes to Taskbar Instead of System Tray

### Status: ✅ FIXED (native settings + KWin rule fallback)

### Problem
Closing/minimizing the Hubstaff window leaves it visible in the KDE panel/taskbar. The user wants it to disappear from the taskbar entirely and live only as a system tray icon. Additionally, if Hubstaff crashes, it should auto-restart and remain tray-only.

### Discovery: Hubstaff Has Native Tray-Only Settings

Reverse-engineering the Hubstaff binary revealed built-in preferences for tray behavior:
- `taskbar_behavior` — controls where the app appears (`0` = taskbar+tray, `1` = tray only)
- `main_window_close_action` — controls what happens on close (`0` = quit, `1` = minimize to taskbar, `2` = minimize to tray)
- `use_helper` — background helper for keeping the app alive

These settings are stored in `~/.local/share/Hubstaff/settings.json` under `client.preferences`.

### Solution: Native Settings First, KWin Rule as Safety Net

**Layer 1 — Native Hubstaff Settings** (`~/.local/share/Hubstaff/settings.json`)
- `taskbar_behavior: "1"` → Show only in system tray (hide from taskbar)
- `main_window_close_action: "1" (Minimize)` → Close/minimize goes to tray, not taskbar
- Managed via `~/Hubstaff/hubstaff-settings-manager.py` for easy toggling

**Layer 2 — KWin Window Rule** (`~/.config/kwinrulesrc`)
- Permanently applies `skipTaskbar=true` and `skipPager=true` to ALL Hubstaff windows
- Works as a safety net even if native settings are reset or ignored
- More reliable than the previous KWin script which toggled on `minimizedChanged`

**Layer 3 — Systemd User Service** (`~/.config/systemd/user/hubstaff.service`)
- Auto-starts Hubstaff at login
- Restarts on crash (`Restart=on-failure`)
- Launcher auto-detects native tray mode and skips kdocker when configured
- Disabled the old desktop autostart to avoid double-launch

### Files Created/Modified

| File | Purpose |
|------|---------|
| `~/Hubstaff/hubstaff-launcher.sh` | Smart launcher: native mode when configured, kdocker fallback otherwise |
| `~/Hubstaff/hubstaff-settings-manager.py` | CLI tool to toggle native tray settings |
| `~/.local/share/Hubstaff/settings.json` | Native tray preferences (`taskbar_behavior=1`, `main_window_close_action=2`) |
| `~/.config/kwinrulesrc` | KWin window rule for permanent taskbar hiding |
| `~/.config/systemd/user/hubstaff.service` | Auto-start and auto-restart on crash |
| `~/.config/autostart/netsoft-com.netsoft.hubstaff.desktop.disabled` | Old autostart disabled |

### How to Apply / Verify

```bash
# Apply native tray settings
~/Hubstaff/hubstaff-settings-manager.py tray-only

# Or manually edit settings.json:
#   client.preferences.taskbar_behavior = "1"
#   client.preferences.main_window_close_action = "2"

# Restart Hubstaff via systemd
systemctl --user daemon-reload
systemctl --user enable hubstaff.service
systemctl --user restart hubstaff.service
qdbus org.kde.KWin /KWin reconfigure
```

**Note:** When native tray mode is active, the launcher skips kdocker entirely. Only Hubstaff's **native** tray icon will appear (no duplicate kdocker icon).

### Settings Manager Commands

```bash
# Show current settings
~/Hubstaff/hubstaff-settings-manager.py show

# Enable tray-only mode
~/Hubstaff/hubstaff-settings-manager.py tray-only

# Revert to default behavior
~/Hubstaff/hubstaff-settings-manager.py default

# Set arbitrary preference
~/Hubstaff/hubstaff-settings-manager.py set taskbar_behavior 0
```

### Deactivation

```bash
# Revert to default Hubstaff behavior
~/Hubstaff/hubstaff-settings-manager.py default

# Stop systemd service
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

**Google Chrome / Microsoft Edge**
> ⚠️ **Flag to remember:** `--disable-features=ElasticOverscroll`

Applied via multiple methods for redundancy:
1. **`.desktop` launcher files** (`~/.local/share/applications/`)
2. **`~/.config/chrome-flags.conf`**
3. **`~/.config/microsoft-edge-stable-flags.conf`**
4. **Terminal:** `google-chrome --disable-features=ElasticOverscroll`

The old flag `--disable-overscroll-edge-effect` was removed in Chromium 114+. The new feature name is `ElasticOverscroll`.

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

**Chrome/Edge:**
- Edit `.desktop` files in `~/.local/share/applications/`
- Remove `~/.config/chrome-flags.conf`
- Remove `~/.config/microsoft-edge-stable-flags.conf`

**Librewolf:** Edit `~/.config/librewolf/librewolf/<profile>/user.js` and remove the `apz.overscroll.enabled` line

---

## Summary

| Issue | Status | What Was Done |
|-------|--------|--------------|
| Hubstaff tray minimize | ✅ Fixed | Native tray settings (`taskbar_behavior=1`, `main_window_close_action=2`) + KWin rule fallback |
| Image paste failures | ✅ Fixed | Dual clipboard bridge (X11 + Wayland) |
| Elastic overscroll | ✅ Fixed | App-level flags for VS Code:, Chrome, Edge, Librewolf |

---

*Last updated: 2026-06-09*

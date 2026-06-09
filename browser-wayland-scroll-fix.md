# Browser Wayland Scroll / Clickbox Misalignment Fix

## Problem
On KDE Plasma 6 (Wayland), Chromium-based browsers suffer from:
- Smooth scrolling bouncing past page boundaries (overscroll)
- Click targets becoming misaligned from visual elements after scrolling

This is a known Chromium-on-Wayland coordinate desync bug.

## Fix
Force Chromium-based browsers to use **XWayland** instead of native Wayland. This completely bypasses the coordinate desync bug.

### Files Modified
- `~/.local/share/applications/google-chrome.desktop`
- `~/.local/share/applications/microsoft-edge.desktop`

### Flags Applied
```
--disable-smooth-scrolling
--ozone-platform=x11
```

### Resulting Exec Lines

**Chrome:**
```ini
Exec=/usr/bin/google-chrome-stable --disable-smooth-scrolling --ozone-platform=x11 %U
Exec=/usr/bin/google-chrome-stable --disable-smooth-scrolling --ozone-platform=x11
Exec=/usr/bin/google-chrome-stable --disable-smooth-scrolling --ozone-platform=x11 --incognito
```

**Edge:**
```ini
Exec=/usr/bin/microsoft-edge-stable --disable-smooth-scrolling --ozone-platform=x11 %U
Exec=/usr/bin/microsoft-edge-stable --disable-smooth-scrolling --ozone-platform=x11
Exec=/usr/bin/microsoft-edge-stable --disable-smooth-scrolling --ozone-platform=x11 --inprivate
```

## Revert
Remove the override desktop entries:
```bash
rm ~/.local/share/applications/google-chrome.desktop
rm ~/.local/share/applications/microsoft-edge.desktop
kbuildsycoca6 --noincremental
```

## Notes
- Native Wayland flags (`--disable-features=OverscrollHistoryNavigation,Quic`) were insufficient; the bug is in Chromium's Wayland surface coordinate handling itself.
- XWayland on Plasma 6 handles HiDPI scaling well via `xwayland.scale` settings.
- To verify a browser is running under XWayland: `xeyes` will track the cursor inside the window.

# Browser Wayland Scroll / Clickbox Misalignment Fix

## Problem
On KDE Plasma 6 (Wayland), Chromium-based browsers suffer from:
- Smooth scrolling bouncing past page boundaries (overscroll)
- Click targets becoming misaligned from visual elements after scrolling

This is a known Chromium-on-Wayland coordinate desync bug.

## Fix
Disable smooth scrolling, overscroll history navigation, and QUIC protocol via launch flags.

### Files Modified
- `~/.local/share/applications/google-chrome.desktop`
- `~/.local/share/applications/microsoft-edge.desktop`

### Flags Applied
```
--disable-smooth-scrolling
--disable-features=OverscrollHistoryNavigation,Quic
```

### Resulting Exec Lines

**Chrome:**
```ini
Exec=/usr/bin/google-chrome-stable --disable-smooth-scrolling --disable-features=OverscrollHistoryNavigation,Quic %U
Exec=/usr/bin/google-chrome-stable --disable-smooth-scrolling --disable-features=OverscrollHistoryNavigation,Quic
Exec=/usr/bin/google-chrome-stable --disable-smooth-scrolling --disable-features=OverscrollHistoryNavigation,Quic --incognito
```

**Edge:**
```ini
Exec=/usr/bin/microsoft-edge-stable --disable-smooth-scrolling --disable-features=OverscrollHistoryNavigation,Quic %U
Exec=/usr/bin/microsoft-edge-stable --disable-smooth-scrolling --disable-features=OverscrollHistoryNavigation,Quic
Exec=/usr/bin/microsoft-edge-stable --disable-smooth-scrolling --disable-features=OverscrollHistoryNavigation,Quic --inprivate
```

## Revert
Remove the override desktop entries:
```bash
rm ~/.local/share/applications/google-chrome.desktop
rm ~/.local/share/applications/microsoft-edge.desktop
kbuildsycoca6 --noincremental
```

## Alternative (More Aggressive)
Force XWayland to eliminate all Wayland-specific Chromium bugs:
```bash
--ozone-platform=x11
```

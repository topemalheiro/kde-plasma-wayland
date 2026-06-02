# KDE Display / KWin Customizations

## Bottom-Edge Window Snap Patch (KWin Wayland)

### Problem
When dragging a window to the bottom edge of the screen, KWin only supports snapping to **bottom-left** or **bottom-right quarters** (when already within the 20px left/right edge strips). There is no standalone **bottom-half** snap, and the bottom-right snap zone is governed by `ElectricBorderCornerRatio` (default 25% of screen height) rather than a fixed pixel threshold.

### Solution
Patch `kde-kwin/src/window.cpp` in `Window::checkQuickTilingMaximizationZones()` to add a dedicated bottom-edge trigger using the same 20px threshold as left/right edges.

### File Modified
- `kde-kwin/src/window.cpp`

### Code Change
In `Window::checkQuickTilingMaximizationZones()`, replace the tiling logic with:

```cpp
        if (options->electricBorderTiling()) {
            if (xroot <= area.x() + 20) {
                tile |= QuickTileFlag::Left;
                innerBorder = isInScreen(QPoint(area.x() - 1, yroot));
            } else if (xroot >= area.x() + area.width() - 20) {
                tile |= QuickTileFlag::Right;
                innerBorder = isInScreen(QPoint(area.right() + 1, yroot));
            } else if (yroot >= area.y() + area.height() - 20) {
                tile |= QuickTileFlag::Bottom;
                innerBorder = isInScreen(QPoint(xroot, area.y() + area.height() + 1));
            }
        }

        if (tile & (QuickTileFlag::Left | QuickTileFlag::Right)) {
            if (yroot <= area.y() + area.height() * options->electricBorderCornerRatio()) {
                tile |= QuickTileFlag::Top;
            } else if (yroot >= area.y() + area.height() - area.height() * options->electricBorderCornerRatio()) {
                tile |= QuickTileFlag::Bottom;
            }
            mode = tile;
        } else if (tile != QuickTileMode(QuickTileFlag::None)) {
            mode = tile;
        } else if (options->electricBorderMaximize() && yroot <= area.y() + 5 && isMaximizable()) {
            mode = MaximizeFull;
            innerBorder = isInScreen(QPoint(xroot, area.y() - 1));
        }
```

### Behavior After Patch
| Drag To | Result |
|---|---|
| Bottom edge (within 20px) | **Bottom-half** tile |
| Bottom-right corner | Bottom-right quarter (unchanged) |
| Bottom-left corner | Bottom-left quarter (unchanged) |
| Left edge | Left half (unchanged) |
| Right edge | Right half (unchanged) |
| Top edge (≤5px) | Maximize (unchanged) |

### Build & Install
```bash
cd /path/to/kde-kwin
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr
make -j$(nproc)
sudo make install
# Restart KWin:
kwin_wayland --replace &
```

### Temporary Workaround (No Rebuild)
If you don't want to rebuild KWin, increase the corner ratio so the bottom corner zones become larger. This does **not** give pure bottom-half snapping, but makes bottom-left/right easier to trigger:

```bash
kwriteconfig6 --file kwinrc --group Windows --key ElectricBorderCornerRatio 0.5
```

Default is `0.25` (25%). Higher values = larger corner zones.

---

## Other Notes
*(Add more display/KWin customizations here as needed.)*

#!/bin/bash
# diagnose-kwin-shortcuts.sh
# Run this when Super+G/W/C (or other KWin shortcuts) stop working.
# It collects the state needed to figure out why.

OUT="/tmp/kwin-shortcut-diagnosis.txt"
echo "=== KWin Shortcut Diagnosis ===" > "$OUT"
echo "Timestamp: $(date)" >> "$OUT"
echo "" >> "$OUT"

echo "--- Current virtual desktop ---" >> "$OUT"
qdbus6 org.kde.KWin /KWin org.kde.KWin.currentDesktop 2>/dev/null >> "$OUT" || echo "(failed)" >> "$OUT"

echo "" >> "$OUT"
echo "--- KWin shortcut registrations (Grid/Overview/Cube) ---" >> "$OUT"
qdbus6 --literal org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.allShortcutInfos 2>/dev/null | tr ',' '\n' | grep -iE '"(Grid View|Overview|Cube|Cycle Overview)"' -A 8 >> "$OUT" || echo "(failed)" >> "$OUT"

echo "" >> "$OUT"
echo "--- Try invoking via D-Bus ---" >> "$OUT"
for action in "Grid View" "Overview" "Cube"; do
    echo "Invoking: $action" >> "$OUT"
    qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "$action" 2>&1 >> "$OUT"
    echo "Exit code: $?" >> "$OUT"
    sleep 0.5
done

echo "" >> "$OUT"
echo "--- Loaded KWin effects ---" >> "$OUT"
qdbus6 org.kde.KWin /Effects loadedEffects 2>/dev/null | grep -iE "grid|overview|cube|windowview" >> "$OUT" || echo "(failed)" >> "$OUT"

echo "" >> "$OUT"
echo "--- Recent KWin errors ---" >> "$OUT"
journalctl -b 0 --user-unit plasma-kwin_wayland.service --no-pager -p err --since "5 minutes ago" 2>/dev/null >> "$OUT" || echo "(failed or no errors)" >> "$OUT"

echo ""
echo "Diagnosis written to: $OUT"
echo "Send the contents of that file when the shortcuts are broken."

#!/usr/bin/env python3
"""
Hubstaff Settings Manager
=========================
Manages Hubstaff's native tray/background settings in settings.json.

Settings:
  taskbar_behavior:
    0 = Taskbar and system tray (default)
    1 = Only in system tray

  main_window_close_action:
    0 = Quit / Prompt each time
    1 = Minimize to taskbar
    2 = Minimize to system tray (best for tray-only mode)

  use_helper:
    true / false  — Use background helper (requires restart)
"""

import json
import sys
import shutil
from pathlib import Path

SETTINGS_PATH = Path.home() / ".local/share/Hubstaff/settings.json"


def load_settings():
    with open(SETTINGS_PATH) as f:
        return json.load(f)


def save_settings(data):
    backup = SETTINGS_PATH.with_suffix(".json.bak")
    shutil.copy2(SETTINGS_PATH, backup)
    with open(SETTINGS_PATH, "w") as f:
        json.dump(data, f, indent=4)
    print(f"Settings saved. Backup at: {backup}")


def show_current():
    data = load_settings()
    prefs = data.get("client", {}).get("preferences", {})
    print("Current Hubstaff preferences:")
    for k, v in prefs.items():
        print(f"  {k}: {v}")


def set_tray_only():
    """Configure Hubstaff for tray-only operation (best guess values)."""
    data = load_settings()
    prefs = data.setdefault("client", {}).setdefault("preferences", {})
    prefs["taskbar_behavior"] = "1"
    prefs["main_window_close_action"] = "2"
    save_settings(data)
    print("Configured for tray-only mode:")
    print("  taskbar_behavior = 1 (Only in system tray)")
    print("  main_window_close_action = 2 (Minimize to tray)")
    print("\nRestart Hubstaff for changes to take effect.")


def set_taskbar_and_tray():
    """Restore default taskbar + tray behavior."""
    data = load_settings()
    prefs = data.setdefault("client", {}).setdefault("preferences", {})
    prefs["taskbar_behavior"] = "0"
    prefs["main_window_close_action"] = "1"
    save_settings(data)
    print("Restored default behavior:")
    print("  taskbar_behavior = 0 (Taskbar and system tray)")
    print("  main_window_close_action = 1 (Minimize to taskbar)")
    print("\nRestart Hubstaff for changes to take effect.")


def set_value(key, value):
    """Set an arbitrary preference value."""
    data = load_settings()
    prefs = data.setdefault("client", {}).setdefault("preferences", {})
    prefs[key] = value
    save_settings(data)
    print(f"Set {key} = {value}")
    print("Restart Hubstaff for changes to take effect.")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        print("Usage:")
        print(f"  {sys.argv[0]} show                — Show current settings")
        print(f"  {sys.argv[0]} tray-only           — Configure tray-only mode")
        print(f"  {sys.argv[0]} default             — Restore default behavior")
        print(f"  {sys.argv[0]} set <key> <value>   — Set arbitrary preference")
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "show":
        show_current()
    elif cmd == "tray-only":
        set_tray_only()
    elif cmd == "default":
        set_taskbar_and_tray()
    elif cmd == "set" and len(sys.argv) >= 4:
        set_value(sys.argv[2], sys.argv[3])
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)


if __name__ == "__main__":
    main()

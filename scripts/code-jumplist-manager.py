#!/usr/bin/env python3
"""
code-jumplist-manager.py — Manages VS Code: taskbar jump list (Recent + Pinned places)
Usage:
  python3 code-jumplist-manager.py add <folder-path>      # Add to recent
  python3 code-jumplist-manager.py pin <folder-path>      # Pin a place
  python3 code-jumplist-manager.py unpin <folder-path>    # Unpin a place
  python3 code-jumplist-manager.py clear-recent           # Clear recent (keep pinned)
  python3 code-jumplist-manager.py refresh                # Regenerate code.desktop from state
  python3 code-jumplist-manager.py restore                # Restore state from backup
"""

import fcntl
import json
import os
import shutil
import sys
import time
from pathlib import Path

STATE_DIR = Path.home() / ".config" / "vscode-jumplist"
STATE_FILE = STATE_DIR / "state.json"
BACKUP_FILE = STATE_DIR / "state.json.backup"
LOCK_FILE = STATE_DIR / ".lock"
DESKTOP_FILE = Path.home() / ".local" / "share" / "applications" / "code.desktop"
MAX_RECENT = 10


def init_state():
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    if not STATE_FILE.exists():
        STATE_FILE.write_text('{"recent": [], "pinned": []}')


def read_state():
    init_state()
    with open(STATE_FILE, 'r') as f:
        return json.loads(f.read())


def write_state(state):
    temp_file = STATE_FILE.with_suffix('.tmp')
    with open(temp_file, 'w') as f:
        f.write(json.dumps(state, indent=2))
    os.replace(temp_file, STATE_FILE)


def backup_state():
    if STATE_FILE.exists():
        shutil.copy2(STATE_FILE, BACKUP_FILE)


def restore_state():
    if BACKUP_FILE.exists():
        shutil.copy2(BACKUP_FILE, STATE_FILE)
        refresh_desktop()
        print("✅ State restored from backup.")
    else:
        print("❌ No backup file found.")


def with_lock(func):
    def wrapper(*args, **kwargs):
        with open(LOCK_FILE, 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            try:
                return func(*args, **kwargs)
            finally:
                fcntl.flock(lock, fcntl.LOCK_UN)
    return wrapper


def resolve_path(path):
    path = str(path)
    if not path.endswith('.desktop'):
        return str(Path(path).resolve())
    try:
        desktop_type = None
        url = None
        with open(path, 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith('Type='):
                    desktop_type = line[5:]
                elif line.startswith('URL'):
                    url = line.split('=', 1)[1]
        if desktop_type == 'Link' and url:
            if url.startswith('file://'):
                url = url[7:]
            elif url.startswith('file:'):
                url = url[5:].lstrip('/')
            url = url.replace('$HOME', str(Path.home()))
            resolved = Path(url).resolve()
            if resolved.is_dir():
                return str(resolved)
    except Exception:
        pass
    return str(Path(path).resolve())


@with_lock
def add_recent(path):
    path = resolve_path(path)
    backup_state()
    state = read_state()
    state["pinned"] = [p for p in state["pinned"] if p["uri"] != path]
    state["recent"] = [p for p in state["recent"] if p["uri"] != path]
    state["recent"].insert(0, {
        "uri": path,
        "name": Path(path).name,
        "timestamp": int(time.time())
    })
    state["recent"] = state["recent"][:MAX_RECENT]
    write_state(state)
    refresh_desktop()


@with_lock
def pin_place(path):
    path = resolve_path(path)
    backup_state()
    state = read_state()
    item = next((p for p in state["recent"] if p["uri"] == path), None)
    if item is None:
        item = {"uri": path, "name": Path(path).name, "timestamp": int(time.time())}
    state["recent"] = [p for p in state["recent"] if p["uri"] != path]
    if not any(p["uri"] == path for p in state["pinned"]):
        state["pinned"].append(item)
    write_state(state)
    refresh_desktop()


@with_lock
def unpin_place(path):
    path = resolve_path(path)
    backup_state()
    state = read_state()
    item = next((p for p in state["pinned"] if p["uri"] == path), None)
    state["pinned"] = [p for p in state["pinned"] if p["uri"] != path]
    if item is not None:
        state["recent"] = [p for p in state["recent"] if p["uri"] != path]
        state["recent"].insert(0, item)
    write_state(state)
    refresh_desktop()


@with_lock
def clear_recent():
    backup_state()
    state = read_state()
    pinned_backup = state.get("pinned", [])
    state["recent"] = []
    state["pinned"] = pinned_backup
    write_state(state)
    refresh_desktop()


@with_lock
def refresh_desktop():
    state = read_state()
    recent = state.get("recent", [])
    pinned = state.get("pinned", [])
    actions = ["new-empty-window"]
    action_entries = []
    idx = 0

    for item in pinned:
        idx += 1
        name = item["name"].replace("\\", "\\\\").replace('"', '\\"')
        uri = item["uri"].replace("\\", "\\\\").replace('"', '\\"')
        action_id = f"open-pinned-{idx}"
        actions.append(action_id)
        action_entries.append(
            f"\n[Desktop Action {action_id}]\n"
            f"Name=📌 {name}\n"
            f"Exec=/usr/bin/code \"{uri}\"\n"
            f"Icon=visual-studio-code\n"
        )
        action_id = f"unpin-pinned-{idx}"
        actions.append(action_id)
        action_entries.append(
            f"\n[Desktop Action {action_id}]\n"
            f"Name=📍 Unpin {name}\n"
            f"Exec=python3 {Path.home() / '.local' / 'bin' / 'code-jumplist-manager'} unpin \"{uri}\"\n"
            f"Icon=pin\n"
        )

    for item in recent:
        idx += 1
        name = item["name"].replace("\\", "\\\\").replace('"', '\\"')
        uri = item["uri"].replace("\\", "\\\\").replace('"', '\\"')
        action_id = f"open-recent-{idx}"
        actions.append(action_id)
        action_entries.append(
            f"\n[Desktop Action {action_id}]\n"
            f"Name=🕐 {name}\n"
            f"Exec=/usr/bin/code \"{uri}\"\n"
            f"Icon=visual-studio-code\n"
        )
        action_id = f"pin-recent-{idx}"
        actions.append(action_id)
        action_entries.append(
            f"\n[Desktop Action {action_id}]\n"
            f"Name=📌 Pin {name}\n"
            f"Exec=python3 {Path.home() / '.local' / 'bin' / 'code-jumplist-manager'} pin \"{uri}\"\n"
            f"Icon=pinned\n"
        )

    actions.extend(["clear-recent", "manage-places"])
    manager_path = str(Path.home() / ".local" / "bin" / "code-jumplist-manager")
    action_entries.append(f"""
[Desktop Action clear-recent]
Name=🗑️ Clear Recent Places
Exec=bash -c '{manager_path} clear-recent'
Icon=edit-clear-history

[Desktop Action manage-places]
Name=⚙️ Manage Places...
Exec=bash -c 'code {STATE_FILE}'
Icon=preferences-system
""")

    actions_str = ";".join(actions)
    desktop_content = f"""[Desktop Entry]
Name=Visual Studio Code:
Comment=Code Editing. Redefined.
GenericName=Text Editor
Exec=/usr/bin/code %F
Icon=visual-studio-code
Type=Application
StartupNotify=false
StartupWMClass=Code
Categories=TextEditor;Development;IDE;
MimeType=application/x-code-workspace;
Actions={actions_str};
Keywords=vscode;

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=/usr/bin/code --new-window %F
Icon=visual-studio-code
{''.join(action_entries)}
"""
    DESKTOP_FILE.write_text(desktop_content)
    os.chmod(DESKTOP_FILE, 0o755)
    os.system("kbuildsycoca6 --noincremental >/dev/null 2>&1 &")
    print("✅ Jump list updated. Right-click the VS Code: taskbar icon to see changes.")


def main():
    if len(sys.argv) < 2:
        print("""Usage: code-jumplist-manager <command> [path]
Commands:
  add <path>        Add folder to Recent
  pin <path>        Pin a place
  unpin <path>      Unpin a place
  clear-recent      Clear Recent (Pinned untouched)
  refresh           Regenerate code.desktop from state
  restore           Restore state from backup
""")
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "add":
        add_recent(sys.argv[2])
    elif cmd == "pin":
        pin_place(sys.argv[2])
    elif cmd == "unpin":
        unpin_place(sys.argv[2])
    elif cmd == "clear-recent":
        clear_recent()
    elif cmd == "refresh":
        refresh_desktop()
    elif cmd == "restore":
        restore_state()
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)


if __name__ == "__main__":
    main()

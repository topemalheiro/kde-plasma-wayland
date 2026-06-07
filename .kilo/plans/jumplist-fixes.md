# Plan: Fix KDE Taskbar Jump List — Pin/Unpin Actions + .desktop Shortcut Resolution

## Problem Statement

The VS Code: taskbar jump list (right-click on VS Code: icon in KDE panel) has two issues:

1. **No pin/unpin in the jump list itself** — Users must run command-line scripts to pin/unpin. They want these actions to appear directly in the taskbar context menu.
2. **.desktop shortcuts add the wrong path** — When opening a folder via a `.desktop` shortcut (e.g., `~/Desktop/Agentic Coding Evals.desktop`), the jumplist records the `.desktop` file path instead of the target folder path. This also triggers KDE's "open properties" behavior for `.desktop` files.

---

## Fix 1: Pin/Unpin Actions in Taskbar Context Menu

### Constraint: KDE Desktop Actions Are Flat

KDE Plasma's task manager renders `.desktop` `Actions` as a flat list of clickable menu items. It does **not** support:
- Right-click context menus on individual actions
- Submenus within the jump list
- Toggle/checkbox states on actions

### Solution: Companion Actions

For each recent/pinned entry, generate a **companion action** that performs the pin/unpin operation:

**Menu layout:**
```
New Empty Window
---
📌 KDE-Plasma-on-Wayland       ← opens the folder
📍 Unpin KDE-Plasma-on-Wayland ← unpins it
🕐 Agentic Coding Evals        ← opens the folder
📌 Pin Agentic Coding Evals    ← pins it
---
🗑️ Clear Recent Places
⚙️ Manage Places...
```

**Implementation:**
- In `refresh_desktop()` of `code-jumplist-manager.py`, after generating each `open-pinned-N` action, generate a corresponding `unpin-pinned-N` action.
- After each `open-recent-N` action, generate a corresponding `pin-recent-N` action.
- The pin/unpin actions call `code-jumplist-manager pin|unpin <uri>` and then refresh.
- To avoid action ID collisions, use a separate index counter for management actions.

**Code changes in `code-jumplist-manager.py`:**
```python
# For each pinned item:
actions.append(f"open-pinned-{idx}")
action_entries.append(f"...open action...")
actions.append(f"unpin-pinned-{idx}")
action_entries.append(f"...unpin action...")

# For each recent item:
actions.append(f"open-recent-{idx}")
action_entries.append(f"...open action...")
actions.append(f"pin-recent-{idx}")
action_entries.append(f"...pin action...")
```

---

## Fix 2: Resolve `.desktop` Shortcuts Before Adding to Recent

### Problem

When the Dolphin servicemenu opens a `.desktop` shortcut:
```
Exec=bash -c '... python3 code-jumplist-manager add "$f" ...' bash %F
```

The `$f` variable contains the `.desktop` file path (e.g., `~/Desktop/Agentic Coding Evals.desktop`). The jumplist manager adds this path directly to the `recent` list. This means:
- The recent list shows `.desktop` paths instead of actual folder paths
- Opening those recent entries tries to open the `.desktop` file in VS Code: instead of the target folder
- KDE may show the `.desktop` file's properties dialog instead of executing it

### Solution: Resolve `.desktop` Links in `add_recent()`

In `code-jumplist-manager.py`, add a `resolve_path()` helper:

```python
def resolve_path(path):
    """If path is a .desktop Type=Link file, return the target folder."""
    if not path.endswith('.desktop'):
        return path
    
    try:
        with open(path, 'r') as f:
            desktop_type = None
            url = None
            for line in f:
                line = line.strip()
                if line.startswith('Type='):
                    desktop_type = line[5:]
                elif line.startswith('URL'):
                    url = line.split('=', 1)[1]
            
            if desktop_type == 'Link' and url:
                # Strip file:// prefix
                if url.startswith('file://'):
                    url = url[7:]
                elif url.startswith('file:'):
                    url = url[5:].lstrip('/')
                # Expand $HOME
                url = url.replace('$HOME', str(Path.home()))
                # Resolve to absolute path
                resolved = Path(url).resolve()
                if resolved.is_dir():
                    return str(resolved)
    except Exception:
        pass
    
    return path
```

Call `resolve_path()` at the start of `add_recent()`, `pin_place()`, and `unpin_place()`.

Also apply the same resolution to the servicemenu Exec line, or rely on the manager's resolution.

---

## Files to Modify

| File | Change |
|------|--------|
| `scripts/code-jumplist-manager.py` | Add `resolve_path()` helper; add companion pin/unpin actions in `refresh_desktop()` |
| `~/.local/bin/code-jumplist-manager` | Re-install after modifying the source |

---

## Verification Steps

1. Run `python3 ~/.local/bin/code-jumplist-manager refresh`
2. Right-click VS Code: taskbar icon → verify Pin/Unpin actions appear
3. Click "Pin Agentic Coding Evals" → verify it moves to Pinned section
4. Click "Unpin KDE-Plasma-on-Wayland" → verify it moves to Recent section
5. Open a `.desktop` shortcut from Dolphin → verify the target folder path (not `.desktop` path) appears in Recent

---

## Open Question for User

The pin/unpin actions will appear as **separate entries** in the flat menu (KDE limitation). Is this acceptable, or do you want me to explore modifying KDE Plasma source code to add native right-click support on jump list entries?

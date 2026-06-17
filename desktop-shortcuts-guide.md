# KDE Plasma .desktop Shortcuts — The Complete Guide

## What is this "trick"?

KDE's app menu and taskbar don't run raw shell scripts or commands directly. They only show **`.desktop` files** — small text files that describe an application (name, icon, command to run). 

**The trick:** Write a `.desktop` file → put it in `~/.local/share/applications/` → it appears in the app menu → drag it to the taskbar.

That's how we made the mic icon for VoxType Live.

---

## Method 1: GUI (No Terminal)

### Step 1: Create the .desktop file

1. Open **Dolphin** (file manager)
2. Navigate to `~/.local/share/applications/`  
   (type that in the location bar, or press `Ctrl+L` and paste it)
3. Right-click in empty space → **Create New** → **Text File**
4. Name it `my-shortcut.desktop`
5. Open it in **Kate** (or any text editor)
6. Paste this template:

```ini
[Desktop Entry]
Name=My Shortcut
Comment=What this does
Exec=/path/to/your/script.sh
Icon=audio-input-microphone
Type=Application
Terminal=false
```

7. Save it

### Step 2: Make it executable

1. In Dolphin, right-click the file → **Properties**
2. Go to the **Permissions** tab
3. Check **Is executable**
4. Click OK

### Step 3: Add to taskbar

1. Open the app menu (Meta key)
2. Search for "My Shortcut"
3. **Right-click** it → **Pin to Task Manager**

Or drag it directly from the app menu onto the taskbar.

---

## Method 2: Right-Click on Desktop (Even Easier)

1. Right-click on your **desktop**
2. **Create New** → **Link to Application**
3. Fill in:
   - **General** tab: Name, description
   - **Application** tab: Command (e.g., `/home/user/Projects/OS Toolkit/VoxType/voxtype-live/voxtype-live-toggle.sh`)
   - Click an icon to set it
4. Click **OK**
5. Right-click the new icon → **Cut**
6. Navigate to `~/.local/share/applications/`
7. Paste it there
8. Now it appears in the app menu and can be pinned to taskbar

---

## Method 3: Terminal (Fastest)

```bash
# Create the file
cat > ~/.local/share/applications/my-shortcut.desktop << 'EOF'
[Desktop Entry]
Name=My Shortcut
Comment=What this does
Exec=/path/to/your/script.sh
Icon=audio-input-microphone
Type=Application
Terminal=false
EOF

# Make it executable
chmod +x ~/.local/share/applications/my-shortcut.desktop

# Refresh KDE so it appears immediately
kbuildsycoca6 --noincremental
```

---

## Important Fields Explained

| Field | What it does | Example |
|---|---|---|
| `Name` | Display name in app menu | `VoxType Live` |
| `Comment` | Tooltip text | `Toggle voice dictation` |
| `Exec` | Command to run | `/home/user/voxtype-live/voxtype-live-toggle.sh` |
| `Icon` | Icon name or path | `audio-input-microphone` or `/path/to/icon.png` |
| `Type` | Must be `Application` | `Application` |
| `Terminal` | Show terminal? | `false` (usually) |

### Built-in icons you can use

KDE has hundreds of built-in icons. Common ones:
- `audio-input-microphone` 🎤
- `media-record` ⏺️
- `preferences-desktop-keyboard`
- `system-run` ▶️
- `dialog-information` ℹ️
- `edit-delete` 🗑️

Find more: open app menu → right-click any app → **Edit Application** → click the icon.

---

## The VoxType Live Example

Here's exactly what we created:

```ini
[Desktop Entry]
Name=VoxType
Comment=Toggle VoxType Live dictation (wake/sleep/launch)
Exec=/home/user/Projects/OS Toolkit/VoxType/voxtype-live/voxtype-live-toggle.sh
Icon=audio-input-microphone
Type=Application
Terminal=false
```

Placed at: `~/.local/share/applications/voxtype-record.desktop`

**What the toggle script does:**
- If VoxType Live is running → sends wake/sleep toggle
- If NOT running → launches it

---

## Common Issues

### "Invalid escape sequence" warning

If your path has spaces (like `OS Toolkit`), **don't** escape them with backslashes in the `.desktop` file. Just write the path normally:

```ini
# WRONG:
Exec=/home/user/Projects/OS\ Toolkit/VoxType/...

# CORRECT:
Exec=/home/user/Projects/OS Toolkit/VoxType/...
```

### Shortcut doesn't appear in app menu

Run this to refresh KDE's app cache:
```bash
kbuildsycoca6 --noincremental
```

Or log out and back in.

### Can't pin to taskbar

The `.desktop` file **must** be executable. Right-click → Properties → Permissions → check "Is executable".

### Taskbar icon shows generic gear instead of chosen icon

- Make sure the `Icon=` value is correct
- Try using a full path to a PNG/SVG: `Icon=/home/user/myicon.png`
- Run `kbuildsycoca6 --noincremental`

---

## Native Folder Shortcuts (Type=Link) — Open in Dolphin

**DO NOT use** right-click → "Create New → Link to Location (URL)". KDE creates a **broken symlink** that Dolphin can't open (shows "Type: Unknown", throbs/crashes).

Instead, create a `.desktop` file with `Type=Link`:

### Method 1: Terminal (Fastest)

```bash
# Create the folder shortcut on your Desktop
cat > ~/Desktop/MyFolder.desktop << 'EOF'
[Desktop Entry]
Icon=folder
Name=MyFolder
Type=Link
URL[$e]=file:$HOME/Projects/MyFolder
EOF

# Make it executable (required for KDE to trust it)
chmod +x ~/Desktop/MyFolder.desktop
```

**That's it.** Double-click it → opens in Dolphin. No symlink, no URL nonsense.

### Method 2: GUI (Dolphin + Kate)

1. Right-click desktop → **Create New** → **Text File**
2. Name it `MyFolder.desktop` (must end in `.desktop`!)
3. Open it in Kate, paste:
   ```ini
   [Desktop Entry]
   Icon=folder
   Name=MyFolder
   Type=Link
   URL[$e]=file:$HOME/Projects/MyFolder
   ```
4. Save
5. Right-click the file → **Properties** → **Permissions** → check **Is executable**
6. **OK**

### Why this works

| Approach | What KDE creates | Works? |
|---|---|---|
| Right-click → "Link to Location (URL)" | Symlink pointing to `file:///home/...` | ❌ Broken — symlinks don't understand URLs |
| `.desktop` with `Type=Link` + `URL[$e]` | Desktop entry parsed by KDE | ✅ Opens in Dolphin natively |

The `[$e]` after `URL` enables shell variable expansion (`$HOME` becomes `/home/user`). You can also write the full path:
```ini
URL=file:///home/user/Projects/MyFolder
```

### Important rules

- **Must** have `.desktop` extension
- **Must** be executable (`chmod +x` or Properties → Is executable)
- `Type=Link` (not `Application`)
- `URL[$e]=file:$HOME/...` (not `Exec=`)

---

## Folder Shortcuts (Open in VS Code:, Terminal, etc.)

Want a desktop icon that opens a **folder** in VS Code: instead of Dolphin? This is different from `Type=Link` — here you want an **application launcher** that passes a folder path.

### Using "Link to Application"

1. Right-click desktop → **Create New** → **Link to Application**
2. **General** tab: Name it `VoxType Live Code` (or whatever)
3. **Application** tab:
   - **Program:** `code`
   - **Arguments:** `/home/user/Projects/OS Toolkit/VoxType/voxtype-live`
   - (or just click **Browse...**, select the folder, then change `Exec` to use `code`)
4. Click the icon to pick a folder or VS Code: icon
5. **OK**
6. Cut/paste it into `~/.local/share/applications/`

The `.desktop` file looks like this:

```ini
[Desktop Entry]
Name=VoxType Live Code
Comment=Open VoxType Live folder in VS Code:
Exec=code "/home/user/Projects/OS Toolkit/VoxType/voxtype-live"
Icon=vscode
Type=Application
Terminal=false
```

### Other useful folder openers

| What you want | Program | Arguments |
|---|---|---|
| Open in VS Code: | `code` | `/path/to/folder` |
| Open in terminal | `konsole` | `--workdir /path/to/folder` |
| Open in Dolphin | `dolphin` | `/path/to/folder` |
| Open in file manager | `xdg-open` | `/path/to/folder` |

**Note:** The path is passed as an argument, not as the program itself. `Type=Application` is still correct — KDE knows it's a folder shortcut because the argument is a folder path.

---

## Autostart (Run on Login)

Want the app to start automatically when you log in?

1. Copy the `.desktop` file to `~/.config/autostart/`
2. That's it

```bash
cp ~/.local/share/applications/my-shortcut.desktop ~/.config/autostart/
```

Or in the GUI: **System Settings → Startup and Shutdown → Autostart** → click **Add**.

---

## Quick Reference

| Want to... | Do this |
|---|---|
| Create shortcut | Write `.desktop` file in `~/.local/share/applications/` |
| Add to taskbar | App menu → right-click → Pin to Task Manager |
| Make executable | Right-click → Properties → Permissions → Is executable |
| Run on login | Copy to `~/.config/autostart/` |
| Refresh app menu | `kbuildsycoca6 --noincremental` |
| Find built-in icons | App menu → right-click app → Edit Application |
| Open folder in VS Code: | `Exec=code /path/to/folder` |

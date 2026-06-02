# Recent Places for VS Code:

A VS Code: extension that tracks recently opened folders and workspaces, with the ability to pin favorites for quick access.

## Features

- **Recent Places** — Automatically tracks folders you open. Shows up to 50 recent locations.
- **Pinned Places** — Pin any recent place to keep it permanently accessible.
- **Unpin** — Remove a pin without losing the item (moves back to Recent).
- **Clear Recent** — Wipe the Recent list without affecting Pinned items.
- **Auto-tracking** — Automatically adds workspace folders when you open them.

## Usage

1. Open the **Explorer** sidebar
2. Look for the **"Recent Places"** panel below your file tree
3. Click any folder to open it
4. Right-click a Recent item → **Pin** to move it to Pinned
5. Right-click a Pinned item → **Unpin** to move it back to Recent
6. Right-click the **Recent** header → **Clear Recent** to empty the list

## Commands

| Command | Description |
|---------|-------------|
| `Recent Places: Add Current Folder` | Manually add the current workspace folder |
| `Clear Recent` | Empty the Recent list (confirmation required) |
| `Refresh` | Refresh the tree view |

## Install from source

```bash
cd vscode-recent-places
npm install
npm run compile
npx vsce package
code --install-extension vscode-recent-places-1.0.0.vsix
```

## Data Storage

All data is stored in VS Code:'s global state (`ExtensionContext.globalState`). No files are written outside of VS Code:'s internal storage.

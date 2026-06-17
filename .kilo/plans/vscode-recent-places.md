# Plan: VS Code: "Recent Places" Extension

## Goal
Implement a VS Code: extension that provides a "Recent Places" sidebar panel with persistent tracking, pin/unpin functionality, and the ability to clear recent items without affecting pinned items.

## Architecture

### Project Structure
```
vscode-recent-places/
├── package.json              # Extension manifest
├── tsconfig.json             # TypeScript config
├── src/
│   ├── extension.ts          # Activation & command registration
│   ├── types.ts              # Shared TypeScript interfaces
│   ├── recentPlacesManager.ts # State persistence & business logic
│   ├── recentPlacesTreeProvider.ts  # Sidebar TreeDataProvider
│   └── commands.ts           # Command handlers
└── README.md
```

### Data Model

```typescript
interface Place {
    uri: string;           // Absolute file URI (file:///home/user/Projects/...)
    label: string;         // Display name (basename of path)
    timestamp: number;     // Last accessed (ms since epoch)
}

interface StoredState {
    recent: Place[];       // Ordered by most recent first
    pinned: Place[];       // User-defined order
    version: number;       // For future migrations
}
```

**Persistence:** Use `ExtensionContext.globalState` (stored in VS Code:'s internal DB, survives reloads).

**Constraints:**
- `recent` list: max 50 items, deduplicated by URI
- `pinned` list: no hard limit, deduplicated by URI
- A place can exist in **either** recent or pinned, not both simultaneously

### UI: Tree View

**View Container:** Register a new view in the Explorer sidebar (right panel) titled **"Recent Places"**.

**Tree Structure:**
```
📌 Recent Places
├── 📂 Recent
│   ├── ~/Projects/KDE-Plasma-on-Wayland      [2 min ago]
│   ├── ~/Projects/OS-Toolkit                 [1 hour ago]
│   └── ~/Projects/Training-Code              [3 hours ago]
│
└── 📌 Pinned
    ├── ~/Projects/KDE-Plasma-on-Wayland
    └── ~/Projects/Agentic-Coding-Evals
```

**Click behavior:** Single-click opens the folder in VS Code: (using `vscode.openFolder`).

**Context menus:**
- **Recent item:** `Open`, `Pin`, `Remove from Recent`
- **Pinned item:** `Open`, `Unpin`, `Remove from Pinned`
- **"Recent" header:** `Clear Recent` (confirmation dialog)

### Commands

| Command ID | Title | Description |
|---|---|---|
| `recentPlaces.open` | Open | Open the selected folder/workspace |
| `recentPlaces.pin` | Pin | Move from Recent → Pinned |
| `recentPlaces.unpin` | Unpin | Remove from Pinned |
| `recentPlaces.remove` | Remove | Delete from whichever list it is in |
| `recentPlaces.clearRecent` | Clear Recent | Empty the Recent list (Pinned untouched) |
| `recentPlaces.addCurrent` | Add Current Folder to Recent | Manually add active workspace |
| `recentPlaces.refresh` | Refresh View | Force UI refresh |

### Auto-Tracking Strategy

VS Code: does not expose its internal "recently opened" list via API. The extension will auto-track by:

1. **Workspace change listener:** `vscode.workspace.onDidChangeWorkspaceFolders` fires when folders are added/removed from the workspace. On add, push to Recent.
2. **Manual add:** Command palette entry `Recent Places: Add Current Folder to Recent` for cases where auto-tracking misses something.

**Note:** `vscode.openFolder` causes a full window reload, so the extension cannot intercept folder opens from outside itself. Auto-tracking via `onDidChangeWorkspaceFolders` is the best available mechanism.

### State Management Logic

```
function addToRecent(uri: string):
    - Remove from pinned if present
    - Remove existing entry from recent (dedupe)
    - Insert at front of recent array
    - Trim recent to max 50 items
    - Save state
    - Refresh tree view

function pinPlace(uri: string):
    - Find in recent, remove it
    - Add to end of pinned array
    - Save state
    - Refresh tree view

function unpinPlace(uri: string):
    - Remove from pinned
    - Add to front of recent (optional — could just delete)
    - Save state
    - Refresh tree view

function clearRecent():
    - recent = []
    - pinned is untouched
    - Save state
    - Refresh tree view
```

## Implementation Steps

### Phase 1: Scaffolding
1. Initialize extension with `yo code` or manual scaffold
2. Configure `package.json`:
   - `activationEvents`: `onView:recentPlaces`
   - `contributes.views`: Register `recentPlaces` tree view in `explorer` panel
   - `contributes.commands`: All 7 commands
   - `contributes.menus`: Context menus for `view/item/context`
3. Set up `tsconfig.json` targeting ES2020

### Phase 2: State Manager
1. Implement `RecentPlacesManager` class
2. Wrap `globalState` get/set with typed `StoredState`
3. Implement `addRecent`, `pin`, `unpin`, `remove`, `clearRecent`
4. Handle state migration (version field for future-proofing)

### Phase 3: Tree Provider
1. Implement `RecentPlacesTreeProvider` extending `vscode.TreeDataProvider<TreeNode>`
2. Define `TreeNode` union type: `HeaderNode | PlaceNode`
3. `getChildren()`: Returns `[RecentHeader, PinnedHeader]` at root level; delegates to manager for children
4. `getTreeItem()`: Returns `vscode.TreeItem` with appropriate icon (`folder` for places, `history`/`pinned` for headers)
5. Wire refresh event from manager → provider

### Phase 4: Commands
1. Implement command handlers in `commands.ts`
2. Register all commands in `extension.ts` via `vscode.commands.registerCommand`
3. Bind command arguments from tree view selections

### Phase 5: Auto-Tracking
1. Register `onDidChangeWorkspaceFolders` listener in `extension.ts`
2. On folder add, call `manager.addRecent(uri)`
3. Debounce to avoid duplicate entries during rapid changes

### Phase 6: Polish
1. Add confirmation dialog for `Clear Recent`
2. Add tooltip showing full path and last-opened time
3. Handle invalid/deleted paths gracefully (show strikethrough or warning icon)
4. Add `README.md` with usage instructions

## Key Design Decisions

| Decision | Rationale |
|---|---|
| Use `globalState` not `workspaceState` | Recent places should persist across all VS Code: windows, not just the current workspace |
| Tree view in Explorer panel | Most accessible location; users expect file-related UI here |
| URI deduplication | Prevents the same folder from appearing multiple times in a list |
| Mutual exclusion (recent vs pinned) | A place is either "temporary" (recent) or "permanent" (pinned), never both |
| Clear Recent does not move to Pinned | Explicitly requested: "clear recent without affecting pinned" |
| No file-level tracking | VS Code: API limits us to workspace/folder level; file-level recent is covered by native `Ctrl+R` |

## Testing Strategy

1. **Manual test:** Open extension in Extension Development Host, add folders, pin/unpin, clear, reload window
2. **Edge cases:** Delete a pinned folder externally → should show gracefully in UI; open 51 folders → oldest recent should be evicted

## Packaging

- Build: `vsce package` to produce `.vsix`
- Install: `code --install-extension vscode-recent-places-*.vsix`
- Or publish to VS Code: Marketplace (requires Microsoft account)

## Deactivation/Uninstall

- Uninstall via VS Code: Extensions panel
- State remains in VS Code:'s global storage (harmless, can be cleared with `code --uninstall-extension` which removes associated state)

## Open Questions for User

1. **Scope:** Should this track individual files or only folders/workspaces? (Recommended: folders only — files are handled natively by VS Code:)
2. **Location:** Should the view live in the Explorer sidebar, or a separate panel (e.g., next to Source Control)?
3. **Auto-add:** Should the extension automatically add the current workspace folder on startup, or only when manually opened via the extension?

import * as vscode from 'vscode';
import { RecentPlacesManager } from './recentPlacesManager';
import { RecentPlacesTreeProvider } from './recentPlacesTreeProvider';
import { registerCommands } from './commands';

export function activate(context: vscode.ExtensionContext) {
    const manager = new RecentPlacesManager(context);
    const provider = new RecentPlacesTreeProvider(manager);

    // Register tree view
    const treeView = vscode.window.createTreeView('recentPlaces', {
        treeDataProvider: provider,
    });
    context.subscriptions.push(treeView);

    // Register commands
    const commands = registerCommands(manager, provider);
    context.subscriptions.push(...commands);

    // Auto-track workspace folder changes
    const workspaceChangeDisposable = vscode.workspace.onDidChangeWorkspaceFolders(async (event) => {
        for (const folder of event.added) {
            await manager.addRecent(folder.uri.toString(), folder.name);
        }
        provider.refresh();
    });
    context.subscriptions.push(workspaceChangeDisposable);

    // Add current workspace on startup if not already tracked
    if (vscode.workspace.workspaceFolders) {
        for (const folder of vscode.workspace.workspaceFolders) {
            const recent = manager.getRecent();
            const pinned = manager.getPinned();
            const exists = recent.some(p => p.uri === folder.uri.toString()) ||
                           pinned.some(p => p.uri === folder.uri.toString());
            if (!exists) {
                manager.addRecent(folder.uri.toString(), folder.name).then(() => {
                    provider.refresh();
                });
            }
        }
    }
}

export function deactivate() {}

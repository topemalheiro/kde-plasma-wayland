import * as vscode from 'vscode';
import { Place } from './types';
import { RecentPlacesManager } from './recentPlacesManager';
import { RecentPlacesTreeProvider } from './recentPlacesTreeProvider';

export function registerCommands(
    manager: RecentPlacesManager,
    provider: RecentPlacesTreeProvider,
): vscode.Disposable[] {
    const disposables: vscode.Disposable[] = [];

    disposables.push(
        vscode.commands.registerCommand('recentPlaces.open', async (place: Place) => {
            const uri = vscode.Uri.parse(place.uri);
            // Update timestamp
            await manager.addRecent(place.uri, place.label);
            provider.refresh();
            // Open folder
            await vscode.commands.executeCommand('vscode.openFolder', uri, {
                forceNewWindow: false,
            });
        })
    );

    disposables.push(
        vscode.commands.registerCommand('recentPlaces.pin', async (node: { place: Place }) => {
            const place = node.place;
            if (place) {
                await manager.pinPlace(place.uri);
                provider.refresh();
            }
        })
    );

    disposables.push(
        vscode.commands.registerCommand('recentPlaces.unpin', async (node: { place: Place }) => {
            const place = node.place;
            if (place) {
                await manager.unpinPlace(place.uri);
                provider.refresh();
            }
        })
    );

    disposables.push(
        vscode.commands.registerCommand('recentPlaces.remove', async (node: { place: Place }) => {
            const place = node.place;
            if (place) {
                await manager.removePlace(place.uri);
                provider.refresh();
            }
        })
    );

    disposables.push(
        vscode.commands.registerCommand('recentPlaces.clearRecent', async () => {
            const confirm = await vscode.window.showWarningMessage(
                'Clear all recent places? Pinned items will not be affected.',
                { modal: true },
                'Clear',
            );
            if (confirm === 'Clear') {
                await manager.clearRecent();
                provider.refresh();
            }
        })
    );

    disposables.push(
        vscode.commands.registerCommand('recentPlaces.addCurrent', async () => {
            const workspaceFolders = vscode.workspace.workspaceFolders;
            if (!workspaceFolders || workspaceFolders.length === 0) {
                vscode.window.showInformationMessage('No folder is currently open.');
                return;
            }

            for (const folder of workspaceFolders) {
                await manager.addRecent(folder.uri.toString(), folder.name);
            }
            provider.refresh();
            vscode.window.showInformationMessage('Current folder added to Recent Places.');
        })
    );

    disposables.push(
        vscode.commands.registerCommand('recentPlaces.refresh', () => {
            provider.refresh();
        })
    );

    return disposables;
}

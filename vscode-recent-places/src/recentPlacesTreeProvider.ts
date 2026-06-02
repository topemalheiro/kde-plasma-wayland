import * as vscode from 'vscode';
import { Place } from './types';
import { RecentPlacesManager } from './recentPlacesManager';

export type TreeNode = HeaderNode | PlaceNode;

export class HeaderNode extends vscode.TreeItem {
    constructor(
        public readonly id: string,
        public readonly label: string,
        public readonly collapsibleState: vscode.TreeItemCollapsibleState,
    ) {
        super(label, collapsibleState);
        this.contextValue = id;
        if (id === 'recentHeader') {
            this.iconPath = new vscode.ThemeIcon('history');
        } else {
            this.iconPath = new vscode.ThemeIcon('pinned');
        }
    }
}

export class PlaceNode extends vscode.TreeItem {
    constructor(
        public readonly place: Place,
        public readonly parentId: string,
    ) {
        super(place.label, vscode.TreeItemCollapsibleState.None);
        this.tooltip = `${place.uri}\nLast opened: ${new Date(place.timestamp).toLocaleString()}`;
        this.contextValue = parentId === 'recentHeader' ? 'recentItem' : 'pinnedItem';
        this.iconPath = new vscode.ThemeIcon('folder');
        this.command = {
            command: 'recentPlaces.open',
            title: 'Open',
            arguments: [place],
        };
    }
}

export class RecentPlacesTreeProvider implements vscode.TreeDataProvider<TreeNode> {
    private _onDidChangeTreeData: vscode.EventEmitter<TreeNode | undefined | void> = new vscode.EventEmitter<TreeNode | undefined | void>();
    readonly onDidChangeTreeData: vscode.Event<TreeNode | undefined | void> = this._onDidChangeTreeData.event;

    constructor(private manager: RecentPlacesManager) {}

    refresh(): void {
        this._onDidChangeTreeData.fire();
    }

    getTreeItem(element: TreeNode): vscode.TreeItem {
        return element;
    }

    getChildren(element?: TreeNode): Thenable<TreeNode[]> {
        if (!element) {
            return Promise.resolve([
                new HeaderNode('recentHeader', 'Recent', vscode.TreeItemCollapsibleState.Expanded),
                new HeaderNode('pinnedHeader', 'Pinned', vscode.TreeItemCollapsibleState.Expanded),
            ]);
        }

        if (element instanceof HeaderNode) {
            if (element.id === 'recentHeader') {
                const recent = this.manager.getRecent();
                return Promise.resolve(recent.map(p => new PlaceNode(p, 'recentHeader')));
            } else {
                const pinned = this.manager.getPinned();
                return Promise.resolve(pinned.map(p => new PlaceNode(p, 'pinnedHeader')));
            }
        }

        return Promise.resolve([]);
    }
}

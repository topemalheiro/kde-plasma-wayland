import * as vscode from 'vscode';
import { Place, StoredState, STATE_KEY, STATE_VERSION, MAX_RECENT } from './types';

export class RecentPlacesManager {
    private state: StoredState;

    constructor(private context: vscode.ExtensionContext) {
        const raw = context.globalState.get<StoredState>(STATE_KEY);
        if (raw && raw.version === STATE_VERSION) {
            this.state = raw;
        } else {
            this.state = { recent: [], pinned: [], version: STATE_VERSION };
        }
    }

    getRecent(): Place[] {
        return [...this.state.recent];
    }

    getPinned(): Place[] {
        return [...this.state.pinned];
    }

    async addRecent(uri: string, label?: string): Promise<void> {
        const place: Place = {
            uri,
            label: label || this.uriToLabel(uri),
            timestamp: Date.now(),
        };

        // Remove from pinned if present
        this.state.pinned = this.state.pinned.filter(p => p.uri !== uri);

        // Remove existing entry from recent (dedupe)
        this.state.recent = this.state.recent.filter(p => p.uri !== uri);

        // Insert at front
        this.state.recent.unshift(place);

        // Trim to max
        if (this.state.recent.length > MAX_RECENT) {
            this.state.recent = this.state.recent.slice(0, MAX_RECENT);
        }

        await this.save();
    }

    async pinPlace(uri: string): Promise<void> {
        const existing = this.state.recent.find(p => p.uri === uri);
        if (!existing) {
            return;
        }

        // Remove from recent
        this.state.recent = this.state.recent.filter(p => p.uri !== uri);

        // Add to pinned if not already there
        if (!this.state.pinned.find(p => p.uri === uri)) {
            this.state.pinned.push(existing);
        }

        await this.save();
    }

    async unpinPlace(uri: string): Promise<void> {
        const existing = this.state.pinned.find(p => p.uri === uri);
        if (!existing) {
            return;
        }

        // Remove from pinned
        this.state.pinned = this.state.pinned.filter(p => p.uri !== uri);

        // Add back to recent (front)
        existing.timestamp = Date.now();
        this.state.recent.unshift(existing);

        await this.save();
    }

    async removePlace(uri: string): Promise<void> {
        this.state.recent = this.state.recent.filter(p => p.uri !== uri);
        this.state.pinned = this.state.pinned.filter(p => p.uri !== uri);
        await this.save();
    }

    async clearRecent(): Promise<void> {
        this.state.recent = [];
        await this.save();
    }

    private async save(): Promise<void> {
        await this.context.globalState.update(STATE_KEY, this.state);
    }

    private uriToLabel(uri: string): string {
        try {
            const url = new URL(uri);
            const path = url.pathname;
            const parts = path.split('/').filter(Boolean);
            return parts.length > 0 ? parts[parts.length - 1] : uri;
        } catch {
            const parts = uri.split('/').filter(Boolean);
            return parts.length > 0 ? parts[parts.length - 1] : uri;
        }
    }
}

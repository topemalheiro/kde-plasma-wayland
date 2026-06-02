export interface Place {
    uri: string;
    label: string;
    timestamp: number;
}

export interface StoredState {
    recent: Place[];
    pinned: Place[];
    version: number;
}

export const STATE_KEY = 'recentPlaces.state';
export const STATE_VERSION = 1;
export const MAX_RECENT = 50;

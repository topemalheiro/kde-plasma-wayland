#!/usr/bin/env bash
#
# Clipboard Image Bridge
# Fixes Wayland/XWayland clipboard image compatibility with VS Code: / Kimi extension.
#
# Spectacle (KDE screenshot tool) copies images to the Wayland clipboard as image/png.
# VS Code: on KDE Wayland usually runs under XWayland, which reads from the X11
# clipboard, not the Wayland clipboard. KDE's clipboard sync sometimes fails to
# propagate image/png across the XWayland boundary. This script bridges both
# clipboards explicitly.
#
# Usage:
#   clipboard-image-bridge.sh start    # Start background monitor daemon
#   clipboard-image-bridge.sh fix      # One-shot fix current clipboard
#   clipboard-image-bridge.sh stop     # Stop background monitor daemon
#   clipboard-image-bridge.sh status   # Check if daemon is running
#

set -euo pipefail

SCRIPT_NAME="clipboard-image-bridge"
PIDFILE="/tmp/${SCRIPT_NAME}.pid"
TMPDIR="/tmp/${SCRIPT_NAME}"
SLEEP_INTERVAL=0.5

# Ensure tmp dir exists
mkdir -p "$TMPDIR"

# --- Helpers ---

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

is_image_on_wayland_clipboard() {
    wl-paste --list-types 2>/dev/null | grep -q "^image/png$"
}

is_image_on_x11_clipboard() {
    xclip -selection clipboard -o -target TARGETS 2>/dev/null | grep -q "^image/png$"
}

get_wayland_clipboard_hash() {
    wl-paste --list-types 2>/dev/null | md5sum | awk '{print $1}'
}

fix_clipboard() {
    local source=""

    # Determine which clipboard has the image
    if is_image_on_wayland_clipboard; then
        source="wayland"
    elif is_image_on_x11_clipboard; then
        source="x11"
    else
        local types_w types_x
        types_w=$(wl-paste --list-types 2>/dev/null | tr '\n' ' ' || true)
        types_x=$(xclip -selection clipboard -o -target TARGETS 2>/dev/null | tr '\n' ' ' || true)
        log "No image/png on either clipboard. Wayland types: ${types_w:-(empty)} | X11 types: ${types_x:-(empty)}"
        return 1
    fi

    local timestamp
    timestamp=$(date +%s%N)
    local file="${TMPDIR}/spectacle-clipboard-${timestamp}.png"

    # Save image from whichever clipboard has it
    if [ "$source" = "wayland" ]; then
        wl-paste --type image/png > "$file"
        log "Read image from Wayland clipboard -> $file"
    else
        xclip -selection clipboard -t image/png -o > "$file"
        log "Read image from X11 clipboard -> $file"
    fi

    # Ensure the image is available on BOTH clipboards

    # 1) X11 clipboard (critical for XWayland apps like VS Code:/Kimi)
    # xclip forks a daemon to serve the clipboard; background it so the script doesn't hang
    xclip -selection clipboard -t image/png < "$file" >/dev/null 2>&1 &

    # 2) Wayland clipboard (for native Wayland apps)
    # wl-copy also forks; background it
    wl-copy --type image/png < "$file" >/dev/null 2>&1 &

    # 3) Wayland text/uri-list as fallback (Electron webviews often prefer file URIs)
    echo "file://${file}" | wl-copy --type text/uri-list >/dev/null 2>&1 &

    log "Fixed: copied image/png to X11 + Wayland, and text/uri-list to Wayland"
    return 0
}

cleanup_old_files() {
    # Remove temp files older than 24 hours
    find "$TMPDIR" -name "spectacle-clipboard-*.png" -type f -mmin +1440 -delete 2>/dev/null || true
}

# --- Daemon ---

run_daemon() {
    log "Starting clipboard image monitor (X11 + Wayland)..."

    local last_hash=""
    local current_hash

    # Cleanup old files on start
    cleanup_old_files

    while true; do
        current_hash=$(get_wayland_clipboard_hash)

        if [ "$current_hash" != "$last_hash" ]; then
            last_hash="$current_hash"

            if is_image_on_wayland_clipboard; then
                # Small delay to let Spectacle finish writing to clipboard
                sleep 0.2
                fix_clipboard || true
            fi
        fi

        sleep "$SLEEP_INTERVAL"
    done
}

start_daemon() {
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        log "Daemon already running (PID $(cat "$PIDFILE"))"
        exit 0
    fi

    # Start daemon in background, detached from terminal
    nohup bash -c "$(declare -f log is_image_on_wayland_clipboard is_image_on_x11_clipboard get_wayland_clipboard_hash fix_clipboard cleanup_old_files run_daemon); run_daemon" \
        > /tmp/${SCRIPT_NAME}.log 2>&1 &

    local pid=$!
    echo "$pid" > "$PIDFILE"
    log "Daemon started (PID $pid). Log: /tmp/${SCRIPT_NAME}.log"
}

stop_daemon() {
    if [ -f "$PIDFILE" ]; then
        local pid
        pid=$(cat "$PIDFILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            log "Daemon stopped (PID $pid)"
        else
            log "Daemon not running (stale PID file)"
        fi
        rm -f "$PIDFILE"
    else
        log "Daemon not running (no PID file)"
    fi
}

daemon_status() {
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "Daemon running (PID $(cat "$PIDFILE"))"
        echo "Log: /tmp/${SCRIPT_NAME}.log"
    else
        echo "Daemon not running"
        rm -f "$PIDFILE"
    fi
}

# --- Main ---

case "${1:-}" in
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    fix)
        fix_clipboard
        ;;
    status)
        daemon_status
        ;;
    *)
        echo "Usage: $0 {start|stop|fix|status}"
        echo ""
        echo "  start   Start background clipboard monitor daemon"
        echo "  stop    Stop background clipboard monitor daemon"
        echo "  fix     One-shot fix: copy current clipboard image to both X11 and Wayland"
        echo "  status  Check if daemon is running"
        exit 1
        ;;
esac

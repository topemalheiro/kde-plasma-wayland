# Hubstaff Crash-Restart Loop Fix

## Problem

Hubstaff opens, stays visible for ~3 seconds, crashes with exit code 255, and its built-in watchdog immediately restarts it — creating an infinite open/close loop when launched from the KDE Plasma app menu.

## Root Cause

KDE Plasma's regional format settings (`~/.config/plasma-localerc`) set `LC_TIME=pt_PT.UTF-8`, but the `pt_PT.UTF-8` locale is **not generated** on the system. The locale archive only contains `C`, `C.utf8`, `en_US.utf8`, and `POSIX`.

Hubstaff fails locale initialization and crashes. Its internal watchdog then auto-restarts the child process, causing the loop. This manifests as:

```
Default system locale is unsupported. Either misconfiguration or invalid LANG envvar.
Forcing C locale failed. Probably the app will crash later on.
Locale not supported by C library.
```

## Why the Obvious Fix Didn't Work

KDE Plasma 6 launches apps through systemd user services. When parsing `.desktop` files, the systemd launcher **strips `env` prefixes** from `Exec` lines. So modifying the desktop file to:

```ini
Exec=env LC_ALL=en_US.UTF-8 "/home/tope/Hubstaff/HubstaffClient.bin.x86_64" %u
```

does NOT work — systemd extracts only `"/home/tope/Hubstaff/HubstaffClient.bin.x86_64"` and drops the `env` wrapper, so Hubstaff still crashes with the invalid locale.

## Solution

### Step 1: Fix Plasma Locale Settings

Change `LC_TIME` in `~/.config/plasma-localerc` from `pt_PT.UTF-8` to `en_US.UTF-8`:

```bash
kwriteconfig6 --file plasma-localerc --group Formats --key LC_TIME en_US.UTF-8
```

This fixes the locale for the overall desktop environment on next login.

### Step 2: Create a Wrapper Script

Create `~/Hubstaff/hubstaff-launcher.sh`:

```bash
#!/bin/bash
export LC_ALL=en_US.UTF-8
exec /home/tope/Hubstaff/HubstaffClient.bin.x86_64 "$@"
```

Make it executable:

```bash
chmod +x /home/tope/Hubstaff/hubstaff-launcher.sh
```

### Step 3: Point the Desktop File to the Wrapper

Edit `~/.local/share/applications/netsoft-com.netsoft.hubstaff.desktop`:

```ini
Exec="/home/tope/Hubstaff/hubstaff-launcher.sh" %u
```

Refresh the KDE application cache:

```bash
kbuildsycoca6 --noincremental
```

The wrapper script survives systemd's `Exec` parsing because it's a real executable path, not an `env` prefix.

## Files Modified/Created

| File | Action |
|------|--------|
| `~/.config/plasma-localerc` | Modified: `LC_TIME=en_US.UTF-8` (was `pt_PT.UTF-8`) |
| `~/.local/share/applications/netsoft-com.netsoft.hubstaff.desktop` | Modified: `Exec` points to wrapper script |
| `~/Hubstaff/hubstaff-launcher.sh` | Created: sets `LC_ALL=en_US.UTF-8` before execing binary |

## How to Undo

```bash
# Revert plasma locale setting
kwriteconfig6 --file plasma-localerc --group Formats --key LC_TIME pt_PT.UTF-8

# Revert Hubstaff desktop file
sed -i 's|Exec="/home/tope/Hubstaff/hubstaff-launcher.sh"|Exec="/home/tope/Hubstaff/HubstaffClient.bin.x86_64"|' ~/.local/share/applications/netsoft-com.netsoft.hubstaff.desktop

# Remove wrapper script
rm /home/tope/Hubstaff/hubstaff-launcher.sh
```

## Related: Restoring Portuguese Time Format

If you want `pt_PT.UTF-8` locale back (for Portuguese time/date formatting), generate it system-wide:

```bash
# Uncomment pt_PT locale
sudo sed -i 's/^#pt_PT.UTF-8 UTF-8/pt_PT.UTF-8 UTF-8/' /etc/locale.gen

# Regenerate
sudo locale-gen
```

Then you can safely revert `LC_TIME` back to `pt_PT.UTF-8` in Plasma settings.

## References

- [Hubstaff Linux Download](https://app.hubstaff.com/download)
- Latest stable Linux version at time of fix: **1.9.2**

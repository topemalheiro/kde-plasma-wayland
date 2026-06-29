# Arch + KDE Reinstall Guide (Omen 15 2018)

This repo contains automation for reinstalling Arch Linux with KDE Plasma and the custom KWin build.

## Quick start from Arch live USB

Boot the Arch ISO, connect to the internet, then choose one of the workflows below.

## Option A: Fully automated clean install (wipes whole disk)

Use this if you want to erase the entire disk and install only Arch + KDE.

```bash
curl -L -o /tmp/install-arch-omen15.sh \
  https://raw.githubusercontent.com/topemalheiro/kde-plasma-wayland/master/scripts/install-arch-omen15.sh
# Review the script, then run with WIPE_DISK=true:
WIPE_DISK=true bash /tmp/install-arch-omen15.sh
```

This creates:
- `/dev/nvme0n1p1` — 1 GB EFI partition
- `/dev/nvme0n1p2` — btrfs root with `@` and `@home` subvolumes

Then it installs Arch, KDE, drivers, apps, clones your repos, and builds custom KWin.

> **WARNING:** This erases the entire disk, including Windows.

## Option B: Fully automated dual-boot reinstall (keeps Windows)

Use this if you already have separate Arch partitions and want to keep Windows.

1. Ensure your disk has:
   - An Arch root partition (e.g. `/dev/nvme0n1p5`)
   - A dedicated Arch EFI partition (e.g. `/dev/nvme0n1p7`)
2. Edit `ARCH_ROOT_PART` and `ARCH_ESP_PART` at the top of the script if needed.
3. Run:
   ```bash
   curl -L -o /tmp/install-arch-omen15.sh \
     https://raw.githubusercontent.com/topemalheiro/kde-plasma-wayland/master/scripts/install-arch-omen15.sh
   bash /tmp/install-arch-omen15.sh
   ```

## Option C: Use `archinstall`, then run post-install scripts

If you prefer the official interactive installer:

1. Run `archinstall` and choose your preferred disk layout.
2. Install KDE Plasma and create user `tope`.
3. Reboot.
4. Authenticate GitHub CLI:
   ```bash
   gh auth login
   ```
5. Clone this repo and run the setup scripts:
   ```bash
   mkdir -p ~/Projects
   git clone https://github.com/topemalheiro/kde-plasma-wayland.git ~/Projects/KDE-Plasma-on-Wayland
   ~/Projects/KDE-Plasma-on-Wayland/scripts/setup-user-env.sh
   sudo ~/Projects/KDE-Plasma-on-Wayland/scripts/install-custom-kwin.sh
   reboot
   ```

## Notes

- `CV Project` and `Extra CV-Proj` are excluded from repo automation. Restore them manually from backup.
- Private repos require `gh auth login` or a `GH_TOKEN` environment variable.
- The custom KWin build takes time (10–30 minutes depending on CPU).
- If your laptop has only Windows partitions (no Arch partitions yet), use **Option A** with `WIPE_DISK=true`.

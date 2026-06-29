# Arch + KDE Reinstall Guide (Omen 15 2018)

This repo contains automation for reinstalling Arch Linux with KDE Plasma and the custom KWin build.

## Option A: Fully automated from Arch live USB

Boot the Arch ISO, connect to the internet, then:

```bash
curl -L -o /tmp/install-arch-omen15.sh https://raw.githubusercontent.com/topemalheiro/kde-plasma-wayland/master/scripts/install-arch-omen15.sh
bash /tmp/install-arch-omen15.sh
```

This script will:
1. Format `/dev/nvme0n1p5` as btrfs with `@` and `@home` subvolumes.
2. Install base system, KDE Plasma, graphics drivers, and user apps.
3. Install systemd-boot on `/dev/nvme0n1p7`.
4. Create user `tope`.
5. Clone `/Projects/` and Desktop repos from GitHub.
6. Build and install the custom KWin fork.

> **WARNING:** Edit `ARCH_ROOT_PART`, `ARCH_ESP_PART`, and other variables inside the script if your partition layout differs.

## Option B: Use `archinstall`, then run post-install scripts (recommended)

`archinstall` is the official Arch interactive installer. It is safer and more flexible for disk setup.

1. Boot Arch ISO and connect to the internet.
2. Run `archinstall` and choose:
   - Disk: `/dev/nvme0n1`
   - Filesystem: `btrfs` with subvolumes (or ext4 if you prefer)
   - Bootloader: `systemd-boot`
   - Desktop: `KDE Plasma`
   - User: `tope`
   - Additional packages: `github-cli`, `git`, `vim`
3. Reboot into the new system.
4. Log in and authenticate `gh`:
   ```bash
   gh auth login
   ```
5. Clone this repo to get the scripts:
   ```bash
   mkdir -p ~/Projects
   git clone https://github.com/topemalheiro/kde-plasma-wayland.git ~/Projects/KDE-Plasma-on-Wayland
   ```
6. Recreate `/Projects/` and Desktop folders + shortcuts:
   ```bash
   ~/Projects/KDE-Plasma-on-Wayland/scripts/setup-user-env.sh
   ```
7. Build and install the custom KWin:
   ```bash
   sudo ~/Projects/KDE-Plasma-on-Wayland/scripts/install-custom-kwin.sh
   ```
8. Reboot (or log out and back in) to use the custom KWin.

## Notes

- `CV Project` and `Extra CV-Proj` are excluded from repo automation. Restore them manually from backup.
- Private repos require `gh auth login` or a `GH_TOKEN` environment variable.
- The custom KWin build takes time (10–30 minutes depending on CPU).

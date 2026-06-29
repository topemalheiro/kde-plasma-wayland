#!/bin/bash
# install-arch-omen15.sh — Reinstall Arch Linux + KDE Plasma on HP Omen 15 2018.
#
# Run this from an Arch Linux live USB as root.
#
# Two modes:
#   1. WIPE_DISK=true  — wipes the whole disk and creates a fresh GPT layout.
#   2. WIPE_DISK=false — uses existing Arch partitions (for dual-boot reinstalls).
#
# Before running:
#   1. Boot Arch ISO on the Omen 15.
#   2. Connect to the internet (iwctl / dhcpcd).
#   3. Review/edit the variables below.
#   4. Set WIPE_DISK=true if you want a clean install.
#
# Usage:
#   ./install-arch-omen15.sh [--dry-run]

set -euo pipefail

# ---------------------------------------------------------------------------
# Configurable variables
# ---------------------------------------------------------------------------
DISK="${DISK:-/dev/nvme0n1}"        # Whole system disk
WIPE_DISK="${WIPE_DISK:-false}"     # Set to true to wipe the entire disk
MINIMAL_INSTALL="${MINIMAL_INSTALL:-false}"  # Skip repo clone + KWin build; do those post-boot

# GH_TOKEN: pass at runtime only (GH_TOKEN=xxx ./script.sh).
# NEVER hardcode a GitHub token in this file.

# Used when WIPE_DISK=true
ESP_SIZE="+1G"                      # EFI partition size
SWAP_SIZE=""                        # Leave empty for no swap, e.g. "+8G"

# Used when WIPE_DISK=false (existing Arch install)
ARCH_ROOT_PART="${DISK}p5"          # Arch root partition to format
ARCH_ESP_PART="${DISK}p7"           # Dedicated Arch ESP

HOSTNAME="omen15-arch"
USERNAME="tope"
TIMEZONE="Europe/Lisbon"
LOCALE="en_US.UTF-8"
KEYMAP="us"

# Package selection
BASE_PKGS=(
    base base-devel linux linux-firmware linux-headers
    networkmanager network-manager-applet
    btrfs-progs efibootmgr
    sudo vim git curl wget openssh
)

GRAPHICS_PKGS=(
    mesa vulkan-intel intel-media-driver libva-intel-driver
)

KDE_PKGS=(
    plasma kde-applications
    sddm sddm-kcm
    konsole dolphin kate ark okular
    plasma-pa plasma-nm kwalletmanager
)

FONTS_PKGS=(
    noto-fonts noto-fonts-cjk noto-fonts-emoji
    ttf-dejavu ttf-liberation ttf-font-awesome
)

USER_PKGS=(
    firefox chromium
    code docker docker-compose
    flatpak pacman-contrib
    github-cli
    p7zip unzip unrar
    pipewire pipewire-pulse pipewire-alsa pipewire-jack
    wireplumber
)

ALL_PKGS=("${BASE_PKGS[@]}" "${GRAPHICS_PKGS[@]}" "${KDE_PKGS[@]}" "${FONTS_PKGS[@]}" "${USER_PKGS[@]}")

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err() { echo -e "${RED}[ERROR]${NC} $1"; }

die() { log_err "$1"; exit 1; }

confirm() {
    local msg="$1"
    echo
    log_warn "$msg"
    if [ "$DRY_RUN" = true ]; then
        echo "  DRY RUN: auto-confirming"
        return
    fi
    read -rp "Type YES to continue: " answer
    if [[ "${answer}" != "YES" ]]; then
        die "Aborted by user."
    fi
    echo
}

check_live_env() {
    if [[ $EUID -ne 0 ]]; then
        if [ "$DRY_RUN" = true ]; then
            log_warn "Not running as root, but dry-run mode allows testing."
        else
            die "This script must be run as root (e.g., sudo $0)"
        fi
    fi

    # Unmount any leftover archroot from a previous run
    if findmnt /mnt/archroot >/dev/null 2>&1; then
        log_warn "/mnt/archroot is already mounted; unmounting ..."
        if [ "$DRY_RUN" = false ]; then
            umount -R /mnt/archroot
        fi
    fi

    # Refuse to run if the target root partition is mounted as /
    if [ "$WIPE_DISK" = false ] && findmnt -n -o SOURCE / 2>/dev/null | grep -q "${ARCH_ROOT_PART}$"; then
        die "You appear to be running from the installed Arch system. Boot from a live USB first."
    fi
}

ensure_live_deps() {
    # The live ISO does not always include git, which we need for cloning repos.
    if ! command -v git >/dev/null 2>&1; then
        log_info "Installing git in live environment ..."
        if [ "$DRY_RUN" = true ]; then
            echo "  DRY RUN: would run: pacman -Sy git --needed --noconfirm"
        else
            pacman -Sy git --needed --noconfirm
        fi
    fi
}

verify_partitions() {
    log_info "Current partition layout:"
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,PARTLABEL "${DISK}"
    echo

    if [ "$WIPE_DISK" = true ]; then
        log_warn "WIPE_DISK=true: the entire disk ${DISK} will be erased and repartitioned."
        return
    fi

    if [[ ! -b "${ARCH_ROOT_PART}" ]]; then
        die "Arch root partition ${ARCH_ROOT_PART} not found. Set WIPE_DISK=true for a clean install, or adjust ARCH_ROOT_PART."
    fi

    if [[ ! -b "${ARCH_ESP_PART}" ]]; then
        die "Arch ESP ${ARCH_ESP_PART} not found. Set WIPE_DISK=true for a clean install, or adjust ARCH_ESP_PART."
    fi

    local esp_fs
    esp_fs=$(lsblk -no FSTYPE "${ARCH_ESP_PART}")
    if [[ "${esp_fs}" != "vfat" ]]; then
        die "Expected ${ARCH_ESP_PART} to be vfat, but found ${esp_fs}. Aborting."
    fi
}

wipe_and_partition_disk() {
    log_info "Wiping ${DISK} and creating fresh GPT layout ..."

    # Compute new partition numbers even in dry-run so logs are accurate
    ARCH_ESP_PART="${DISK}p1"
    if [ -n "${SWAP_SIZE}" ]; then
        ARCH_SWAP_PART="${DISK}p2"
        ARCH_ROOT_PART="${DISK}p3"
    else
        ARCH_ROOT_PART="${DISK}p2"
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "  DRY RUN: would wipe ${DISK} and create partitions"
        echo "  DRY RUN: new ESP=${ARCH_ESP_PART}, root=${ARCH_ROOT_PART}"
        if [ -n "${ARCH_SWAP_PART:-}" ]; then
            echo "  DRY RUN: new swap=${ARCH_SWAP_PART}"
        fi
        return
    fi

    # Unmount any partitions on the target disk before wiping
    for part in "${DISK}"*; do
        [ -b "$part" ] || continue
        local mps
        mps=$(findmnt -n -o TARGET "$part" 2>/dev/null) || true
        for mp in $mps; do
            umount -R "$mp" 2>/dev/null || true
        done
    done

    # Wipe disk
    wipefs -af "${DISK}"
    sgdisk -Zo "${DISK}"
    partprobe -s "${DISK}" 2>/dev/null || true
    sleep 3

    # Create EFI partition
    sgdisk -n 0:0:"${ESP_SIZE}" -t 0:ef00 -c 0:"EFI System" "${DISK}"

    # Optional swap partition
    local next_part=2
    if [ -n "${SWAP_SIZE}" ]; then
        sgdisk -n 0:0:"${SWAP_SIZE}" -t 0:8200 -c 0:"Linux swap" "${DISK}"
        next_part=3
    fi

    # Root partition (rest of disk)
    sgdisk -n 0:0:0 -t 0:8300 -c 0:"Linux root" "${DISK}"

    partprobe "${DISK}"
    sleep 2

    # Format ESP
    mkfs.fat -F32 -n "EFI" "${ARCH_ESP_PART}"

    # Format swap if present
    if [ -n "${SWAP_SIZE:-}" ] && [ -n "${ARCH_SWAP_PART:-}" ]; then
        mkswap -L "Swap" "${ARCH_SWAP_PART}"
    fi

    log_info "New layout:"
    lsblk -o NAME,SIZE,FSTYPE,PARTLABEL "${DISK}"
}

format_partitions() {
    if [ "$WIPE_DISK" = true ]; then
        wipe_and_partition_disk
    fi

    log_info "Formatting ${ARCH_ROOT_PART} as btrfs with @ and @home subvolumes ..."
    if [ "$DRY_RUN" = false ]; then
        mkfs.btrfs -f -L "ArchRoot" "${ARCH_ROOT_PART}"

        mkdir -p /mnt/archroot
        mount "${ARCH_ROOT_PART}" /mnt/archroot

        btrfs subvolume create /mnt/archroot/@
        btrfs subvolume create /mnt/archroot/@home

        umount /mnt/archroot
        mount -o subvol=@ "${ARCH_ROOT_PART}" /mnt/archroot
        mkdir -p /mnt/archroot/home
        mount -o subvol=@home "${ARCH_ROOT_PART}" /mnt/archroot/home

        # Mount ESP at /boot so kernels live on the ESP and genfstab picks it up
        mkdir -p /mnt/archroot/boot
        mount "${ARCH_ESP_PART}" /mnt/archroot/boot
    fi
}

pacstrap_base() {
    log_info "Pacstrapping base system (this may take a while) ..."
    if [ "$DRY_RUN" = true ]; then
        echo "  DRY RUN: would run: pacman -Syy"
        echo "  DRY RUN: would run: pacstrap ${ALL_PKGS[*]}"
        return
    fi

    # Update live environment package database
    pacman -Syy --noconfirm

    # Install packages into new root
    pacstrap /mnt/archroot "${ALL_PKGS[@]}"
}

generate_fstab() {
    log_info "Generating fstab ..."
    if [ "$DRY_RUN" = false ]; then
        genfstab -U /mnt/archroot >> /mnt/archroot/etc/fstab
    fi
}

configure_system() {
    log_info "Configuring base system ..."
    if [ "$DRY_RUN" = true ]; then
        echo "  DRY RUN: would configure timezone, locale, hostname, hosts, mkinitcpio"
        return
    fi

    # Make DNS work inside chroot
    cp /etc/resolv.conf /mnt/archroot/etc/resolv.conf

    # Timezone
    arch-chroot /mnt/archroot ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
    arch-chroot /mnt/archroot hwclock --systohc

    # Locale
    sed -i "s/^#${LOCALE}/${LOCALE}/" /mnt/archroot/etc/locale.gen
    arch-chroot /mnt/archroot locale-gen
    echo "LANG=${LOCALE}" > /mnt/archroot/etc/locale.conf

    # Keymap
    echo "KEYMAP=${KEYMAP}" > /mnt/archroot/etc/vconsole.conf

    # Hostname
    echo "${HOSTNAME}" > /mnt/archroot/etc/hostname
    printf '127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t%s.localdomain %s\n' "${HOSTNAME}" "${HOSTNAME}" > /mnt/archroot/etc/hosts

    # Initramfs
    arch-chroot /mnt/archroot mkinitcpio -P

    # Enable services
    arch-chroot /mnt/archroot systemctl enable NetworkManager.service
    arch-chroot /mnt/archroot systemctl enable sddm.service
    arch-chroot /mnt/archroot systemctl enable bluetooth.service
    arch-chroot /mnt/archroot systemctl enable fstrim.timer
    arch-chroot /mnt/archroot systemctl enable docker.service

    # Enable swap if created
    if [ -n "${SWAP_SIZE:-}" ] && [ -n "${ARCH_SWAP_PART:-}" ]; then
        arch-chroot /mnt/archroot swapon "${ARCH_SWAP_PART}" 2>/dev/null || true
        local swap_uuid
        swap_uuid=$(lsblk -no UUID "${ARCH_SWAP_PART}")
        echo "UUID=${swap_uuid} none swap defaults 0 0" >> /mnt/archroot/etc/fstab
    fi
}

install_bootloader() {
    log_info "Installing systemd-boot on ${ARCH_ESP_PART} ..."
    if [ "$DRY_RUN" = true ]; then
        echo "  DRY RUN: would run: bootctl install"
        return
    fi

    # ESP is already mounted at /boot from format_partitions
    arch-chroot /mnt/archroot bootctl install

    # Some UEFI firmware doesn't create the boot entry from bootctl install,
    # so explicitly add it with efibootmgr.
    arch-chroot /mnt/archroot efibootmgr --create --disk "${DISK}" --part "${ARCH_ESP_PART##*p}" \
        --loader '\\EFI\\systemd\\systemd-bootx64.efi' \
        --label 'Arch Linux' || true

    # In full-wipe mode, remove leftover Windows Boot Manager entries from UEFI NVRAM.
    if [ "$WIPE_DISK" = true ]; then
        local win_entries
        win_entries=$(arch-chroot /mnt/archroot efibootmgr -v 2>/dev/null | awk '/Windows Boot Manager/ {print $1}' | tr -d '*')
        for entry in $win_entries; do
            arch-chroot /mnt/archroot efibootmgr -b "$entry" -B
        done
    fi

    local root_uuid
    root_uuid=$(lsblk -no UUID "${ARCH_ROOT_PART}")

    cat > "/mnt/archroot/boot/loader/entries/arch-linux.conf" <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=${root_uuid} rw rootflags=subvol=@ quiet
EOF

    cat > "/mnt/archroot/boot/loader/loader.conf" <<'EOF'
default arch-linux.conf
timeout 5
console-mode max
EOF
}

create_user() {
    log_info "Creating user ${USERNAME} ..."
    if [ "$DRY_RUN" = true ]; then
        echo "  DRY RUN: would create user ${USERNAME} and add to wheel,docker"
        return
    fi

    arch-chroot /mnt/archroot useradd -m -G wheel,docker,audio,video,input -s /bin/bash "${USERNAME}" || true

    # Allow wheel group to sudo
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /mnt/archroot/etc/sudoers

    echo "Set password for ${USERNAME}:"
    arch-chroot /mnt/archroot passwd "${USERNAME}"
}

auth_url() {
    local url="$1"
    if [ -n "${GH_TOKEN:-}" ]; then
        url="${url/https:\/\/github.com\//https:\/\/${GH_TOKEN}@github.com\/}"
    fi
    echo "$url"
}

clone_toolkit_and_run_setup() {
    log_info "Cloning OS-Toolkit and KDE-Plasma-on-Wayland for post-install setup ..."
    if [ "$DRY_RUN" = true ]; then
        echo "  DRY RUN: would clone OS-Toolkit and KDE-Plasma-on-Wayland into /home/${USERNAME}/Projects"
        return
    fi

    local user_projects="/mnt/archroot/home/${USERNAME}/Projects"
    mkdir -p "${user_projects}"

    # Copy current network config so chroot git clone works
    cp /etc/resolv.conf /mnt/archroot/etc/resolv.conf

    # Clone OS-Toolkit first so manifests are available
    git clone "$(auth_url 'https://github.com/topemalheiro/OS-Toolkit.git')" "${user_projects}/OS-Toolkit"

    # Clone KDE-Plasma-on-Wayland for the setup script itself
    git clone --recurse-submodules "$(auth_url 'https://github.com/topemalheiro/kde-plasma-wayland.git')" "${user_projects}/KDE-Plasma-on-Wayland"

    # Run setup as the new user inside the new root
    # (Network is available because resolv.conf was copied.)
    # Pass GH_TOKEN through so private repo clones work unattended.
    arch-chroot /mnt/archroot /bin/bash -c \
        "export GH_TOKEN='${GH_TOKEN:-}'; su - ${USERNAME} -c 'cd /home/${USERNAME}/Projects/KDE-Plasma-on-Wayland && ./scripts/setup-user-env.sh'"

    # Fix ownership of everything in /home
    arch-chroot /mnt/archroot chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}"
}

install_custom_kwin() {
    log_info "Building and installing custom KWin ..."
    if [ "$DRY_RUN" = true ]; then
        echo "  DRY RUN: would run install-custom-kwin.sh in chroot"
        return
    fi

    # KWin source was cloned as a submodule by clone_toolkit_and_run_setup
    local kwin_script="/home/${USERNAME}/Projects/KDE-Plasma-on-Wayland/scripts/install-custom-kwin.sh"
    local chroot_kwin_src="/home/${USERNAME}/Projects/KDE-Plasma-on-Wayland/kde-kwin"

    if [ ! -d "/mnt/archroot${chroot_kwin_src}" ]; then
        log_warn "Custom KWin source not found at /mnt/archroot${chroot_kwin_src}"
        log_warn "Skipping custom KWin install. Run install-custom-kwin.sh manually after first boot."
        return
    fi

    arch-chroot /mnt/archroot /bin/bash -c \
        "KWIN_SRC=${chroot_kwin_src} ${kwin_script}"
}

main() {
    echo "========================================"
    echo " Arch Linux + KDE Installer"
    echo "  HP Omen 15 2018"
    echo "========================================"
    echo

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY RUN mode — no changes will be made."
        echo
    fi

    check_live_env
    ensure_live_deps
    verify_partitions

    echo
    log_warn "This will:"
    if [ "$WIPE_DISK" = true ]; then
        echo "  1. WIPE THE ENTIRE DISK ${DISK}"
        echo "  2. Create new EFI + btrfs root partitions"
        echo "  3. Install Arch base system + KDE Plasma + Omen 15 drivers"
        echo "  4. Install systemd-boot on the new EFI partition"
    else
        echo "  1. Wipe and format ${ARCH_ROOT_PART} as btrfs"
        echo "  2. Install Arch base system + KDE Plasma + Omen 15 drivers"
        echo "  4. Install systemd-boot on ${ARCH_ESP_PART}"
    fi
    echo "  5. Create user ${USERNAME}"
    if [ "$MINIMAL_INSTALL" = true ]; then
        echo "  6. Finish (run post-install-setup.sh after first boot)"
    else
        echo "  6. Clone repos and recreate Desktop shortcuts"
        echo "  7. Build and install the custom KWin fork"
    fi
    echo

    if [ "$WIPE_DISK" = true ]; then
        confirm "Have you backed up all important data? The entire disk will be erased."
    else
        confirm "Have you backed up any important data and booted from an Arch live USB?"
    fi

    format_partitions
    pacstrap_base
    generate_fstab
    configure_system
    install_bootloader
    create_user

    if [ "$MINIMAL_INSTALL" = true ]; then
        log_info "Minimal install: skipping repo setup and custom KWin build."
        log_info "Run post-install-setup.sh after first boot to finish setup."
    else
        clone_toolkit_and_run_setup
        install_custom_kwin
    fi

    echo
    log_info "Done. Reboot into the new system:"
    echo "  umount -R /mnt/archroot"
    echo "  reboot"
}

main "$@"

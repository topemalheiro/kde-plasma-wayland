#!/bin/bash
# install-arch-omen15.sh — Reinstall Arch Linux + KDE Plasma on HP Omen 15 2018.
#
# Run this from an Arch Linux live USB as root.
# It wipes and repartitions only the target Arch root partition; it tries not to
# touch the Windows ESP or Windows partitions.
#
# Before running:
#   1. Boot Arch ISO on the Omen 15.
#   2. Connect to the internet (iwctl / dhcpcd).
#   3. Review/edit the variables below (especially DISK and *_PART).
#   4. If you want to keep Windows, ensure WIN_ESP_PART and WIN_PARTS are correct.
#
# Usage:
#   ./install-arch-omen15.sh [--dry-run]

set -euo pipefail

# ---------------------------------------------------------------------------
# Configurable variables
# ---------------------------------------------------------------------------
DISK="/dev/nvme0n1"                 # Whole system disk
ARCH_ROOT_PART="${DISK}p5"          # Arch root partition to format
ARCH_ESP_PART="${DISK}p7"           # Dedicated Arch ESP (created by separate-arch-esp.sh)
WIN_ESP_PART="${DISK}p1"            # Shared/Windows ESP (do not touch)
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
    plasma plasma-wayland-session kde-applications
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

    if [[ -d /mnt/archroot ]]; then
        log_warn "/mnt/archroot already exists"
    fi

    # Refuse to run if the target root partition is mounted as /
    if findmnt -n -o SOURCE / 2>/dev/null | grep -q "${ARCH_ROOT_PART}$"; then
        die "You appear to be running from the installed Arch system. Boot from a live USB first."
    fi
}

verify_partitions() {
    log_info "Current partition layout:"
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,PARTLABEL "${DISK}"
    echo

    if [[ ! -b "${ARCH_ROOT_PART}" ]]; then
        die "Arch root partition ${ARCH_ROOT_PART} not found. Aborting."
    fi

    if [[ ! -b "${ARCH_ESP_PART}" ]]; then
        die "Arch ESP ${ARCH_ESP_PART} not found. Run separate-arch-esp.sh first, or adjust ARCH_ESP_PART."
    fi

    local esp_fs
    esp_fs=$(lsblk -no FSTYPE "${ARCH_ESP_PART}")
    if [[ "${esp_fs}" != "vfat" ]]; then
        die "Expected ${ARCH_ESP_PART} to be vfat, but found ${esp_fs}. Aborting."
    fi
}

format_partitions() {
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
        mkdir -p /mnt/archroot/efi
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
}

install_bootloader() {
    log_info "Installing systemd-boot on ${ARCH_ESP_PART} ..."
    if [ "$DRY_RUN" = true ]; then
        echo "  DRY RUN: would run: bootctl install --esp-path=/efi"
        return
    fi

    mkdir -p /mnt/archroot/efi
    mount "${ARCH_ESP_PART}" /mnt/archroot/efi
    arch-chroot /mnt/archroot bootctl install --esp-path=/efi

    local root_uuid
    root_uuid=$(lsblk -no UUID "${ARCH_ROOT_PART}")

    cat > "/mnt/archroot/efi/loader/entries/arch-linux.conf" <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=${root_uuid} rw rootflags=subvol=@ quiet
EOF

    cat > "/mnt/archroot/efi/loader/loader.conf" <<'EOF'
default arch-linux.conf
timeout 5
console-mode max
EOF

    umount /mnt/archroot/efi
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
    git clone "https://github.com/topemalheiro/OS-Toolkit.git" "${user_projects}/OS-Toolkit"

    # Clone KDE-Plasma-on-Wayland for the setup script itself
    git clone "https://github.com/topemalheiro/kde-plasma-wayland.git" "${user_projects}/KDE-Plasma-on-Wayland"

    # Run setup as the new user inside the new root
    # (Network is available because resolv.conf was copied.)
    arch-chroot /mnt/archroot /bin/bash -c \
        "su - ${USERNAME} -c 'cd /home/${USERNAME}/Projects/KDE-Plasma-on-Wayland && ./scripts/setup-user-env.sh'"

    # Fix ownership of everything in /home
    arch-chroot /mnt/archroot chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}"
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
    verify_partitions

    echo
    log_warn "This will:"
    echo "  1. Wipe and format ${ARCH_ROOT_PART} as btrfs"
    echo "  2. Install Arch base system + KDE Plasma + Omen 15 drivers"
    echo "  3. Install systemd-boot on ${ARCH_ESP_PART}"
    echo "  4. Create user ${USERNAME}"
    echo "  5. Clone repos and recreate Desktop shortcuts"
    echo

    confirm "Have you backed up all important data and booted from an Arch live USB?"

    format_partitions
    pacstrap_base
    generate_fstab
    configure_system
    install_bootloader
    create_user
    clone_toolkit_and_run_setup

    echo
    log_info "Done. Reboot into the new system:"
    echo "  umount -R /mnt/archroot"
    echo "  reboot"
}

main "$@"

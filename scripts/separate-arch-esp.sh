#!/bin/bash
# separate-arch-esp.sh
# Run this from an Arch Linux live USB to move Arch's systemd-boot ESP
# to its own partition, separate from the shared Windows ESP.
#
# WARNING: This modifies partition tables and bootloader files. It should
# only be run from a live environment, not from the installed Arch system.

set -euo pipefail

DISK="/dev/nvme0n1"
ARCH_ROOT_PART="${DISK}p5"
SHARED_ESP_PART="${DISK}p1"
NEW_ESP_SIZE="+512M"
NEW_ESP_LABEL="ARCHESP"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err() { echo -e "${RED}[ERROR]${NC} $1"; }

die() {
    log_err "$1"
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This script must be run as root (e.g., sudo $0)"
    fi
}

check_live_env() {
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

    if [[ ! -b "${SHARED_ESP_PART}" ]]; then
        die "Shared ESP ${SHARED_ESP_PART} not found. Aborting."
    fi

    local root_fs
    root_fs=$(lsblk -no FSTYPE "${ARCH_ROOT_PART}")
    if [[ "${root_fs}" != "btrfs" ]]; then
        die "Expected ${ARCH_ROOT_PART} to be btrfs, but found ${root_fs}. Aborting."
    fi

    local esp_fs
    esp_fs=$(lsblk -no FSTYPE "${SHARED_ESP_PART}")
    if [[ "${esp_fs}" != "vfat" ]]; then
        die "Expected ${SHARED_ESP_PART} to be vfat, but found ${esp_fs}. Aborting."
    fi
}

confirm() {
    local msg="$1"
    echo
    log_warn "$msg"
    read -rp "Type YES to continue: " answer
    if [[ "${answer}" != "YES" ]]; then
        die "Aborted by user."
    fi
    echo
}

shrink_arch_partition() {
    log_info "Mounting Arch root to resize btrfs..."
    mkdir -p /mnt/archroot
    mount "${ARCH_ROOT_PART}" /mnt/archroot

    log_info "Shrinking ${ARCH_ROOT_PART} by 512 MB..."
    btrfs filesystem resize -512M /mnt/archroot

    log_info "Unmounting Arch root..."
    umount /mnt/archroot
}

create_new_esp() {
    log_info "Creating new ESP partition in freed space..."

    # Determine next partition number
    local last_part_num
    last_part_num=$(lsblk -no NAME "${DISK}" | grep -E "^${DISK#/dev/}p[0-9]+" | sed "s|${DISK#/dev/}p||" | sort -n | tail -1)
    local new_part_num=$((last_part_num + 1))
    local new_part="${DISK}p${new_part_num}"

    log_info "New ESP will be ${new_part}"

    # Create partition with sgdisk
    if ! command -v sgdisk &>/dev/null; then
        die "sgdisk not found. Install gptfdisk or use a different live image."
    fi

    # Find the start sector of the freed space (end of p5)
    local p5_end
    p5_end=$(sgdisk -i 5 "${DISK}" | awk '/Last sector:/ {print $3}' | tr -d ',')
    if [[ -z "${p5_end}" ]]; then
        die "Could not determine end sector of partition 5."
    fi

    local start_sector=$((p5_end + 1))

    sgdisk --new="${new_part_num}:${start_sector}:${NEW_ESP_SIZE}" \
           --typecode="${new_part_num}:ef00" \
           --change-name="${new_part_num}:Arch ESP" \
           "${DISK}"

    partprobe "${DISK}"
    sleep 2

    if [[ ! -b "${new_part}" ]]; then
        die "New partition ${new_part} did not appear. Try rebooting into live USB again."
    fi

    log_info "Formatting ${new_part} as FAT32..."
    mkfs.fat -F32 -n "${NEW_ESP_LABEL}" "${new_part}"

    # Export for later use
    echo "${new_part}" > /tmp/new_arch_esp_part
}

copy_arch_boot_files() {
    local new_part
    new_part=$(cat /tmp/new_arch_esp_part)

    log_info "Mounting ESPs..."
    mkdir -p /mnt/oldesp /mnt/newesp
    mount "${SHARED_ESP_PART}" /mnt/oldesp
    mount "${new_part}" /mnt/newesp

    log_info "Copying Arch bootloader files to new ESP..."
    mkdir -p /mnt/newesp/EFI/Boot
    cp -a /mnt/oldesp/EFI/systemd /mnt/newesp/EFI/
    cp -a /mnt/oldesp/loader /mnt/newesp/
    cp /mnt/newesp/EFI/systemd/systemd-bootx64.efi /mnt/newesp/EFI/Boot/bootx64.efi

    # Ensure loader.conf exists on new ESP
    if [[ ! -f /mnt/newesp/loader/loader.conf ]]; then
        log_warn "Creating default loader.conf on new ESP"
        mkdir -p /mnt/newesp/loader
        cat > /mnt/newesp/loader/loader.conf <<'EOF'
default arch-linux.efi
timeout 5
console-mode max
EOF
    fi

    sync
    log_info "Arch bootloader files copied."
}

update_fstab() {
    local new_part
    new_part=$(cat /tmp/new_arch_esp_part)
    local new_uuid
    new_uuid=$(lsblk -no UUID "${new_part}")

    log_info "New ESP UUID: ${new_uuid}"

    log_info "Backing up /etc/fstab..."
    cp /mnt/archroot/etc/fstab /mnt/archroot/etc/fstab.bak.$(date +%Y%m%d%H%M%S)

    log_info "Updating /etc/fstab to mount new ESP at /efi..."
    sed -i "s|^[[:space:]]*UUID=[^[:space:]]*[[:space:]]*/efi[[:space:]]|UUID=${new_uuid}  /efi  |" /mnt/archroot/etc/fstab

    if ! grep -q "^UUID=${new_uuid}[[:space:]]*/efi" /mnt/archroot/etc/fstab; then
        die "Failed to update /etc/fstab. Please edit it manually."
    fi

    log_info "/etc/fstab updated:"
    grep -E "^[[:space:]]*UUID=" /mnt/archroot/etc/fstab | grep -E "/efi|/boot"
}

chroot_update_bootloader() {
    log_info "Running bootctl update inside chroot..."
    arch-chroot /mnt/archroot bootctl update
}

cleanup_shared_esp() {
    log_info "Removing Arch files from shared Windows ESP..."

    if [[ -d /mnt/oldesp/EFI/systemd ]]; then
        rm -rf /mnt/oldesp/EFI/systemd
    fi

    if [[ -d /mnt/oldesp/loader ]]; then
        rm -rf /mnt/oldesp/loader
    fi

    # Leave Windows files and EFI/Boot alone
    log_info "Shared ESP now contains only:"
    find /mnt/oldesp -maxdepth 3 -type f | sort
}

add_nvram_entry() {
    local new_part
    new_part=$(cat /tmp/new_arch_esp_part)

    log_info "Adding new UEFI boot entry for Arch ESP..."
    efibootmgr --create --disk "${DISK}" --part "${new_part##*p}" \
        --loader '\EFI\systemd\systemd-bootx64.efi' \
        --label 'Arch Linux'

    log_info "Current boot entries:"
    efibootmgr -v

    local new_entry
    new_entry=$(efibootmgr -v | awk '/Arch Linux/ {print $1}' | tr -d '*')
    if [[ -z "${new_entry}" ]]; then
        die "Could not find new Arch boot entry. Check efibootmgr output above."
    fi

    log_info "Setting boot order: ${new_entry} first, Windows second..."
    efibootmgr --bootorder "${new_entry},0000"
}

main() {
    echo "========================================"
    echo " Arch ESP Separation Script"
    echo "========================================"
    echo

    check_root
    check_live_env
    verify_partitions

    echo
    log_warn "This will:"
    echo "  1. Shrink ${ARCH_ROOT_PART} by 512 MB"
    echo "  2. Create a new 512 MB ESP for Arch"
    echo "  3. Copy Arch bootloader files to the new ESP"
    echo "  4. Update /etc/fstab"
    echo "  5. Remove Arch files from the shared Windows ESP"
    echo "  6. Add a new UEFI boot entry for Arch"
    echo

    confirm "Have you backed up any important data and booted from an Arch live USB?"

    shrink_arch_partition
    create_new_esp
    copy_arch_boot_files

    log_info "Mounting Arch root for chroot operations..."
    mount "${ARCH_ROOT_PART}" /mnt/archroot

    update_fstab
    chroot_update_bootloader
    cleanup_shared_esp

    log_info "Unmounting filesystems..."
    umount /mnt/newesp
    umount /mnt/oldesp
    umount /mnt/archroot

    add_nvram_entry

    echo
    log_info "Done. Arch now has its own ESP."
    log_info "Reboot and verify Arch boots. Then boot Windows and run Option C:"
    echo
    echo "  bcdedit /set {current} bootstatuspolicy ignoreallfailures"
    echo "  bcdedit /set {current} recoveryenabled No"
    echo "  powercfg /hibernate off"
    echo
}

main "$@"

#!/usr/bin/env bash
#
# install-base.sh
#
# Base system installer for arch-install-hyprland. Run from the Arch Linux
# live ISO as root. Hardware-agnostic: storage type (HDD/SATA SSD/NVMe),
# CPU vendor (Intel/AMD microcode), and GPU vendor (Intel/AMD/Nvidia driver)
# are all detected automatically at runtime.
#
set -euo pipefail

GITHUB_USER="florflorin78"
REPO="arch-hyprland-installer"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO}/${BRANCH}"

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------

check_internet() {
    if ping -c1 -W2 archlinux.org &>/dev/null; then
        echo "[OK]    Internet connection verified."
    else
        echo "[ERROR] No internet connection. Connect and retry."
        exit 1
    fi
}

check_uefi() {
    if [ -d /sys/firmware/efi ]; then
        echo "[OK]    UEFI boot mode confirmed."
    else
        echo "[ERROR] System is not booted in UEFI mode. GRUB with graphical"
        echo "        theming requires UEFI. Enable UEFI in firmware settings"
        echo "        and reboot from the installation media."
        exit 1
    fi
}

list_disks() {
    echo
    echo "Available disks:"
    lsblk -d -o NAME,SIZE,ROTA,MODEL
    echo
}

# Returns HDD or SSD by reading /sys/block/<disk>/queue/rotational (1 = HDD, 0 = SSD)
detect_disk_type() {
    local disk="$1"
    local rota_file="/sys/block/${disk}/queue/rotational"

    if [ ! -f "$rota_file" ]; then
        echo "unknown"
        return
    fi

    if [ "$(cat "$rota_file")" -eq 1 ]; then
        echo "HDD"
    else
        echo "SSD"
    fi
}

# Returns intel-ucode or amd-ucode based on CPU vendor. Falls back to no
# microcode package on unrecognized vendors (e.g. virtual machines).
detect_microcode_package() {
    local vendor
    vendor=$(grep -m1 "vendor_id" /proc/cpuinfo | awk '{print $NF}')

    case "$vendor" in
        GenuineIntel) echo "intel-ucode" ;;
        AuthenticAMD) echo "amd-ucode" ;;
        *) echo "" ;;
    esac
}

# Returns intel, amd, nvidia, or unknown based on the primary GPU detected via lspci.
detect_gpu_vendor() {
    local gpu_line
    gpu_line=$(lspci -mm 2>/dev/null | grep -Ei "VGA|3D controller" | head -n1)

    if echo "$gpu_line" | grep -qi "intel"; then
        echo "intel"
    elif echo "$gpu_line" | grep -qi "amd\|ati"; then
        echo "amd"
    elif echo "$gpu_line" | grep -qi "nvidia"; then
        echo "nvidia"
    else
        echo "unknown"
    fi
}

# ---------------------------------------------------------------------------
# Partition naming helper
# ---------------------------------------------------------------------------
# NVMe/eMMC devices use a "p" separator before the partition number
# (nvme0n1p1); SATA/virtio devices do not (sda1).
partition_name() {
    local disk="$1"
    local number="$2"

    if [[ "$disk" == *nvme* ]] || [[ "$disk" == *mmcblk* ]]; then
        echo "${disk}p${number}"
    else
        echo "${disk}${number}"
    fi
}

# ---------------------------------------------------------------------------
# Partitioning and formatting
# ---------------------------------------------------------------------------

partition_and_format() {
    local disk_path="$1"

    echo "Partitioning ${disk_path} (GPT: EFI system partition + root)..."
    parted -s "$disk_path" mklabel gpt
    parted -s "$disk_path" mkpart ESP fat32 1MiB 513MiB
    parted -s "$disk_path" set 1 esp on
    parted -s "$disk_path" mkpart primary ext4 513MiB 100%

    local disk_name
    disk_name=$(basename "$disk_path")
    BOOT_PART="/dev/$(partition_name "$disk_name" 1)"
    ROOT_PART="/dev/$(partition_name "$disk_name" 2)"

    echo "Formatting EFI partition (${BOOT_PART}) as FAT32..."
    mkfs.fat -F32 "$BOOT_PART"

    echo "Formatting root partition (${ROOT_PART}) as ext4..."
    mkfs.ext4 -F "$ROOT_PART"

    echo "Mounting target filesystem at /mnt..."
    mount "$ROOT_PART" /mnt
    mkdir -p /mnt/boot
    mount "$BOOT_PART" /mnt/boot

    export BOOT_PART ROOT_PART
}

# ---------------------------------------------------------------------------
# Base system installation
# ---------------------------------------------------------------------------

install_base_system() {
    echo "Installing base system (pacstrap)..."

    local microcode_pkg="$1"
    pacstrap -K /mnt base linux linux-firmware base-devel ${microcode_pkg} \
        networkmanager sudo vim git stow grub efibootmgr pciutils

    echo "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    echo "== arch-install-hyprland: base installation =="
    echo

    check_internet
    check_uefi
    list_disks

    read -rp "Target disk (e.g. sda or nvme0n1, without /dev/): " DISK_NAME
    DISK_PATH="/dev/${DISK_NAME}"

    if [ ! -b "$DISK_PATH" ]; then
        echo "[ERROR] ${DISK_PATH} is not a valid block device."
        exit 1
    fi

    DISK_TYPE=$(detect_disk_type "$DISK_NAME")
    echo "[INFO]  Detected disk type: ${DISK_TYPE}"
    export DISK_TYPE

    echo
    echo "WARNING: all data on ${DISK_PATH} will be erased."
    read -rp "Type 'ERASE' to continue: " CONFIRM
    if [ "$CONFIRM" != "ERASE" ]; then
        echo "Aborted by user."
        exit 1
    fi

    read -rp "Hostname: " HOSTNAME
    read -rp "Username: " USERNAME

    MICROCODE_PKG=$(detect_microcode_package)
    GPU_VENDOR=$(detect_gpu_vendor)
    echo "[INFO]  Detected CPU microcode package: ${MICROCODE_PKG:-none}"
    echo "[INFO]  Detected GPU vendor: ${GPU_VENDOR}"

    partition_and_format "$DISK_PATH"
    install_base_system "$MICROCODE_PKG"

    echo "Fetching chroot-config.sh..."
    curl -fsSL "https://raw.githubusercontent.com/florflorin78/arch-hyprland-installer/main/chroot-config.sh" -o /mnt/root/chroot-config.sh
    chmod +x /mnt/root/chroot-config.sh

    echo "Entering chroot for system configuration..."
    arch-chroot /mnt /root/chroot-config.sh "$HOSTNAME" "$USERNAME" "$BOOT_PART" "$DISK_PATH" "$DISK_TYPE" "$GPU_VENDOR"

    echo
    echo "== Base installation complete =="
    echo "Run 'umount -R /mnt' then 'reboot'."
    echo "After first login, run post-install.sh as ${USERNAME}:"
    echo "curl -fsSL https://raw.githubusercontent.com/florflorin78/arch-hyprland-installer/main/post-install.sh -o post-install.sh && bash post-install.sh"}
}

main
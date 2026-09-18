#!/usr/bin/env bash
#
# chroot-config.sh
#
# System configuration, executed automatically by install-base.sh inside
# arch-chroot. Handles locale, hostname, user creation, bootloader (GRUB,
# instant boot), Plymouth boot splash, SSD TRIM, and NetworkManager. GPU
# driver and KMS module are selected based on detected hardware.
#
# Arguments: $1=hostname  $2=username  $3=boot_partition  $4=disk_path
#            $5=disk_type  $6=gpu_vendor
#
set -euo pipefail

HOSTNAME="$1"
USERNAME="$2"
BOOT_PART="$3"
DISK_PATH="$4"
DISK_TYPE="$5"
GPU_VENDOR="$6"

GITHUB_USER="florflorin78"
REPO="arch-hyprland-installer"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO}/${BRANCH}"

# ---------------------------------------------------------------------------
# Locale and timezone
# ---------------------------------------------------------------------------
configure_locale() {
    echo ">>> Timezone (press Enter for default: Europe/Bucharest)."
    read -rp "Timezone [Europe/Bucharest]: " TIMEZONE
    TIMEZONE="${TIMEZONE:-Europe/Bucharest}"
    if [ ! -e "/usr/share/zoneinfo/${TIMEZONE}" ]; then
        echo "[WARN] Unrecognized timezone '${TIMEZONE}', defaulting to Europe/Bucharest."
        TIMEZONE="Europe/Bucharest"
    fi
    ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
    hwclock --systohc

    sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    locale-gen

    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    echo "KEYMAP=us" > /etc/vconsole.conf
}

# ---------------------------------------------------------------------------
# GPU driver (selected by detected vendor)
# ---------------------------------------------------------------------------
install_gpu_driver() {
    case "$GPU_VENDOR" in
        intel)
            pacman -S --needed --noconfirm mesa vulkan-intel intel-media-driver
            KMS_MODULE="i915"
            ;;
        amd)
            pacman -S --needed --noconfirm mesa vulkan-radeon libva-mesa-driver
            KMS_MODULE="amdgpu"
            ;;
        nvidia)
            pacman -S --needed --noconfirm mesa nvidia-open nvidia-utils
            KMS_MODULE="nvidia"
            ;;
        *)
            echo "[WARN] Unknown GPU vendor, installing generic mesa only."
            pacman -S --needed --noconfirm mesa
            KMS_MODULE=""
            ;;
    esac
    export KMS_MODULE
}

# ---------------------------------------------------------------------------
# Hostname
# ---------------------------------------------------------------------------
configure_hostname() {
    echo "$HOSTNAME" > /etc/hostname
    cat >> /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF
}

# ---------------------------------------------------------------------------
# User account and sudo
# ---------------------------------------------------------------------------
create_user() {
    useradd -m -G wheel -s /bin/bash "$USERNAME"
    echo ">>> Set password for ${USERNAME}:"
    passwd "$USERNAME"
    echo ">>> Set password for root:"
    passwd
}

configure_sudo() {
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
}

# ---------------------------------------------------------------------------
# Bootloader: GRUB, UEFI, instant boot (no visible menu)
# ---------------------------------------------------------------------------
install_grub() {
    echo "Installing GRUB (UEFI)..."
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB "$DISK_PATH"
}

configure_instant_boot() {
    sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
    sed -i 's/^#GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
    if ! grep -q "^GRUB_TIMEOUT_STYLE=" /etc/default/grub; then
        echo "GRUB_TIMEOUT_STYLE=hidden" >> /etc/default/grub
    fi
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub

    grub-mkconfig -o /boot/grub/grub.cfg
}

# ---------------------------------------------------------------------------
# Plymouth boot splash
# ---------------------------------------------------------------------------
install_plymouth() {
    echo "Installing Plymouth..."
    pacman -S --needed --noconfirm plymouth

    # "kms" must precede "plymouth" so the video driver loads before the
    # splash renders, avoiding a resolution-switch flicker.
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block plymouth filesystems fsck)/' /etc/mkinitcpio.conf
    if [ -n "${KMS_MODULE:-}" ]; then
        sed -i "s/^MODULES=.*/MODULES=(${KMS_MODULE})/" /etc/mkinitcpio.conf
    fi

    mkinitcpio -P

    mkdir -p /usr/share/plymouth/themes/arch-install-hyprland
    curl -fsSL "${RAW_BASE}/plymouth-theme/arch-install-hyprland.plymouth" \
        -o /usr/share/plymouth/themes/arch-install-hyprland/arch-install-hyprland.plymouth
    curl -fsSL "${RAW_BASE}/plymouth-theme/arch-install-hyprland.script" \
        -o /usr/share/plymouth/themes/arch-install-hyprland/arch-install-hyprland.script

    plymouth-set-default-theme -R arch-install-hyprland
}

# ---------------------------------------------------------------------------
# Boot time optimizations
# ---------------------------------------------------------------------------
optimize_boot_time() {
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 vt.global_cursor_default=0"/' /etc/default/grub

    if ! grep -q "^GRUB_DISABLE_OS_PROBER=" /etc/default/grub; then
        echo "GRUB_DISABLE_OS_PROBER=true" >> /etc/default/grub
    fi

    grub-mkconfig -o /boot/grub/grub.cfg

    systemctl disable NetworkManager-wait-online.service 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# SSD TRIM (skipped on HDD)
# ---------------------------------------------------------------------------
configure_trim() {
    if [ "$DISK_TYPE" = "SSD" ]; then
        echo "SSD detected: enabling fstrim.timer."
        systemctl enable fstrim.timer
    else
        echo "HDD detected: TRIM not applicable."
    fi
}

# ---------------------------------------------------------------------------
# NetworkManager
# ---------------------------------------------------------------------------
enable_network_manager() {
    systemctl enable NetworkManager
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    configure_locale
    configure_hostname
    create_user
    configure_sudo
    install_gpu_driver      
    install_grub
    configure_instant_boot
    install_plymouth         
    optimize_boot_time
    configure_trim
    enable_network_manager

    echo "== chroot-config.sh complete =="
}

main
#!/usr/bin/env bash
# Step 1 — runs from the Arch ISO: disk -> partitions -> (LUKS) -> pacstrap -> chroot.
set -Eeuo pipefail

export LC_ALL=C.UTF-8
setfont ter-v18b 2>/dev/null || setfont ter-v16b 2>/dev/null || true

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
STEP_TOTAL=7
LOG_FILE=/tmp/arch-hyprland-install.log
: > "$LOG_FILE"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
trap 'die "Error at line $LINENO: $BASH_COMMAND"' ERR

clear
banner

# ---------------------------------------------------------------- 1
step "Checks"
check_root
check_uefi
check_internet

# ---------------------------------------------------------------- 2
part() { [[ $1 =~ [0-9]$ ]] && echo "${1}p$2" || echo "${1}$2"; }   # sda1 / nvme0n1p1

choose_disk() {
    local iso_src iso_disk="" d i=1 n size model tran fs
    local -a disks=()

    iso_src=$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null || true)
    [[ -n $iso_src ]] && iso_disk=$(lsblk -no PKNAME "$iso_src" 2>/dev/null | head -1 || true)

    while read -r d; do
        [[ -n $iso_disk && $d == "/dev/$iso_disk" ]] && continue
        disks+=("$d")
    done < <(lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1}')
    ((${#disks[@]} > 0)) || die "No disk found."

    printf '\n %s%-3s %-14s %-9s %-22s %-6s %s%s\n' "$C_BASE" "#" "Disk" "Size" "Model" "Bus" "Contains" "$C_RESET"
    for d in "${disks[@]}"; do
        size=$(lsblk -dno SIZE "$d" | xargs)
        model=$(lsblk -dno MODEL "$d" | xargs)
        tran=$(lsblk -dno TRAN "$d" | xargs)
        fs=$(lsblk -lno FSTYPE "$d" | sed '/^$/d' | sort -u | tr '\n' ' ')
        printf ' %s%-3s%s %-14s %-9s %-22.22s %-6s %s%s%s\n' \
            "$C_HI" "$i" "$C_RESET" "$d" "$size" "${model:--}" "${tran:--}" "$C_BASE" "${fs:-empty}" "$C_RESET"
        i=$((i + 1))
    done
    echo

    read -r -p " ${C_HI}?${C_RESET} Install on disk number: " n
    [[ $n =~ ^[0-9]+$ ]] && ((n >= 1 && n <= ${#disks[@]})) || die "Invalid choice."
    DISK=${disks[n-1]}
    DISK_INFO="$(lsblk -dno SIZE "$DISK" | xargs) $(lsblk -dno MODEL "$DISK" | xargs)"
}

step "Disk"
choose_disk

# ---------------------------------------------------------------- 3
step "Settings"
ask HOSTNAME "Hostname" "x270"
while :; do
    ask USERNAME "Username (lowercase, no spaces)" ""
    [[ $USERNAME =~ ^[a-z_][a-z0-9_-]{0,30}$ ]] && break
    warn "Invalid username. Example: florin"
done
ask TIMEZONE "Timezone" "Europe/Bucharest"
[[ -f /usr/share/zoneinfo/$TIMEZONE ]] || die "Unknown timezone: $TIMEZONE"

AUTOLOGIN=no
if confirm "Encrypt the disk with LUKS2?"; then
    LUKS=yes
    confirm "Skip the login screen after the disk password? (lock screen stays)" && AUTOLOGIN=yes
else
    LUKS=no
fi

echo
box "Summary" \
    "Disk:       $DISK ($DISK_INFO)" \
    "Layout:     1G EFI (/boot) + ext4 root" \
    "Encryption: $LUKS" \
    "Autologin:  $AUTOLOGIN" \
    "Hostname:   $HOSTNAME" \
    "Username:   $USERNAME" \
    "Timezone:   $TIMEZONE"
echo
warn "ALL data on $DISK will be ERASED."
read -r -p " ${C_HI}?${C_RESET} Type the disk path ($DISK) to confirm: " conf
[[ $conf == "$DISK" ]] || die "Mismatch, aborting. Nothing was changed."

# ---------------------------------------------------------------- 4
step "Live environment"
prepare_live() {
    timedatectl set-ntp true || true
    sed -i -e 's/^#Color/Color/' -e 's/^#ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
}
run_cmd "Syncing clock, configuring pacman" prepare_live
run_cmd "Ranking mirrors" bash -c \
    'timeout 90 reflector --country Romania,Germany,Austria,Hungary,Bulgaria --protocol https --latest 15 --sort rate --save /etc/pacman.d/mirrorlist || true'

# ---------------------------------------------------------------- 5
step "Partitioning"
partition_disk() {
    swapoff -a || true
    umount -R /mnt 2>/dev/null || true
    wipefs -af "$DISK"
    sgdisk --zap-all "$DISK"
    sgdisk -n1:0:+1G -t1:ef00 -c1:ESP "$DISK"
    if [[ $LUKS == yes ]]; then
        sgdisk -n2:0:0 -t2:8309 -c2:cryptroot "$DISK"
    else
        sgdisk -n2:0:0 -t2:8300 -c2:root "$DISK"
    fi
    partprobe "$DISK"
    udevadm settle
    sleep 1
}
run_cmd "Creating GPT partitions" partition_disk

P_ESP=$(part "$DISK" 1)
P_ROOT=$(part "$DISK" 2)
LUKS_UUID=""
ROOT_DEV=$P_ROOT

if [[ $LUKS == yes ]]; then
    echo
    info "Choose the disk encryption password (you type it at every boot)."
    cryptsetup luksFormat --type luks2 "$P_ROOT"
    cryptsetup open "$P_ROOT" cryptroot
    LUKS_UUID=$(blkid -s UUID -o value "$P_ROOT")
    ROOT_DEV=/dev/mapper/cryptroot
fi

format_and_mount() {
    mkfs.fat -F32 -n ESP "$P_ESP"
    mkfs.ext4 -F -L arch "$ROOT_DEV"
    mount -o noatime "$ROOT_DEV" /mnt
    mount --mkdir -o umask=0077 "$P_ESP" /mnt/boot
}
run_cmd "Formatting and mounting" format_and_mount

# ---------------------------------------------------------------- 6
step "Base system"
mapfile -t BASE_PKGS < <(read_list "$SCRIPT_DIR/packages/00-base.txt")
run_cmd "pacstrap (${#BASE_PKGS[@]} packages)" pacstrap -K /mnt "${BASE_PKGS[@]}"
run_cmd "Generating fstab" bash -c 'genfstab -U /mnt >> /mnt/etc/fstab'

copy_repo() {
    rm -rf /mnt/root/arch-hyprland-installer
    cp -a "$SCRIPT_DIR" /mnt/root/arch-hyprland-installer
    {
        printf 'HOSTNAME=%q\n'  "$HOSTNAME"
        printf 'USERNAME=%q\n'  "$USERNAME"
        printf 'TIMEZONE=%q\n'  "$TIMEZONE"
        printf 'LUKS=%q\n'      "$LUKS"
        printf 'LUKS_UUID=%q\n' "$LUKS_UUID"
        printf 'AUTOLOGIN=%q\n' "$AUTOLOGIN"
    } > /mnt/root/install.conf
    chmod 600 /mnt/root/install.conf
}
run_cmd "Copying installer into the new system" copy_repo

# ---------------------------------------------------------------- 7
step "System configuration (chroot)"
info "You will be asked for the root and $USERNAME passwords."
arch-chroot /mnt bash /root/arch-hyprland-installer/chroot-config.sh

rm -f /mnt/root/install.conf
cp "$LOG_FILE" /mnt/var/log/arch-hyprland-install-live.log 2>/dev/null || true
umount -R /mnt
[[ $LUKS == yes ]] && cryptsetup close cryptroot

echo
box "Done in $(fmt_time "$SECONDS")" \
    "Remove the USB stick and reboot." \
    "First login opens the final setup (AUR, git, neovim)." \
    "SUPER + F1 lists every shortcut." \
    "Logs: /var/log/arch-hyprland-install*.log"
echo
if confirm "Reboot now?"; then reboot; fi

#!/usr/bin/env bash
# Step 2 — runs inside the chroot (called by install-base.sh).
set -Eeuo pipefail

export LC_ALL=C.UTF-8
REPO=/root/arch-hyprland-installer
STEP_TOTAL=9
LOG_FILE=/var/log/arch-hyprland-install.log
FAILED_LOG=/var/log/arch-hyprland-failed-packages.log
: > "$LOG_FILE"
: > "$FAILED_LOG"
# shellcheck source=lib/common.sh
source "$REPO/lib/common.sh"
# shellcheck source=/dev/null
source /root/install.conf   # HOSTNAME USERNAME TIMEZONE LUKS LUKS_UUID AUTOLOGIN
trap 'die "Error at line $LINENO: $BASH_COMMAND"' ERR

# ---------------------------------------------------------------- 1
step "Base configuration"
base_config() {
    sed -i -e 's/^#Color/Color/' -e 's/^#ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
    grep -q '^ILoveCandy' /etc/pacman.conf || sed -i '/^Color/a ILoveCandy' /etc/pacman.conf
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    hwclock --systohc
    sed -i -e 's/^#\(en_US.UTF-8 UTF-8\)/\1/' -e 's/^#\(ro_RO.UTF-8 UTF-8\)/\1/' /etc/locale.gen
    locale-gen
    echo 'LANG=en_US.UTF-8' > /etc/locale.conf
    printf 'KEYMAP=us\nFONT=ter-v16n\n' > /etc/vconsole.conf
    echo "$HOSTNAME" > /etc/hostname
    cat > /etc/hosts <<HOSTS
127.0.0.1  localhost
::1        localhost
127.0.1.1  $HOSTNAME.localdomain $HOSTNAME
HOSTS
}
run_cmd "Pacman, time, locale, hostname" base_config

# ---------------------------------------------------------------- 2
step "User"
id "$USERNAME" &>/dev/null || useradd -m -G wheel,video,input,audio -s /bin/zsh "$USERNAME"
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel
new_secret PW "Password for root"
printf 'root:%s\n' "$PW" | chpasswd
new_secret PW "Password for $USERNAME (used to log in)"
printf '%s:%s\n' "$USERNAME" "$PW" | chpasswd
unset PW

# ---------------------------------------------------------------- 3
step "Packages"
for list in 10-system 20-desktop 30-dev 35-ai 40-network 50-security; do
    install_list "$REPO/packages/$list.txt"
done
for g in wireshark docker libvirt kvm uucp lp; do
    getent group "$g" >/dev/null && usermod -aG "$g" "$USERNAME"
done

# ---------------------------------------------------------------- 4
step "System configuration"
system_config() {
    cp -r "$REPO/system/etc/." /etc/
    cp -r "$REPO/system/usr/." /usr/
    sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf 2>/dev/null || true
    if [[ ${AUTOLOGIN:-no} == yes ]]; then
        cat >> /etc/greetd/config.toml <<GREETD

[initial_session]
command = "hyprland-session"
user = "$USERNAME"
GREETD
    fi
}
run_cmd "Power, zram, sysctl, logind, greetd" system_config

# ---------------------------------------------------------------- 5
step "Initramfs and Plymouth"
if [[ $LUKS == yes ]]; then
    HOOKS="base udev plymouth autodetect modconf kms keyboard keymap consolefont block encrypt filesystems fsck"
else
    HOOKS="base udev plymouth autodetect modconf kms keyboard keymap consolefont block filesystems fsck"
fi
initramfs_config() {
    mkdir -p /etc/mkinitcpio.conf.d /usr/share/plymouth/themes
    cat > /etc/mkinitcpio.conf.d/10-arch-hyprland.conf <<MKINIT
MODULES=(i915)
HOOKS=($HOOKS)
MKINIT
    cp -r "$REPO/system/plymouth/hackerlinux" /usr/share/plymouth/themes/
    plymouth-set-default-theme hackerlinux
}
run_cmd "Plymouth theme and hooks" initramfs_config
run_cmd "Building initramfs" mkinitcpio -P

# ---------------------------------------------------------------- 6
step "GRUB"
set_grub() {
    local k=$1 v=$2
    if grep -q "^#\?${k}=" /etc/default/grub; then
        sed -i "s|^#\?${k}=.*|${k}=${v}|" /etc/default/grub
    else
        echo "${k}=${v}" >> /etc/default/grub
    fi
}
grub_config() {
    # silent boot: no kernel/systemd/udev text between the splash and the desktop
    local cmdline="quiet splash loglevel=3 rd.udev.log_level=3 udev.log_level=3 systemd.show_status=false rd.systemd.show_status=false vt.global_cursor_default=0 nowatchdog mem_sleep_default=deep"
    set_grub GRUB_CMDLINE_LINUX_DEFAULT "\"$cmdline\""
    [[ $LUKS == yes ]] && set_grub GRUB_CMDLINE_LINUX "\"cryptdevice=UUID=${LUKS_UUID}:cryptroot\""
    # hidden menu, 1s timeout; hold SHIFT at boot to show it
    set_grub GRUB_TIMEOUT 1
    set_grub GRUB_TIMEOUT_STYLE hidden
    set_grub GRUB_GFXMODE auto
    set_grub GRUB_GFXPAYLOAD_LINUX keep
    set_grub GRUB_TERMINAL_OUTPUT gfxterm
    set_grub GRUB_THEME '"/boot/grub/themes/hackerlinux/theme.txt"'

    local theme_dir=/boot/grub/themes/hackerlinux font=/usr/share/fonts/TTF/DejaVuSansMono.ttf
    mkdir -p "$theme_dir"
    cp -r "$REPO/system/grub-theme/." "$theme_dir/"
    [[ -f $font ]] || font=$(find /usr/share/fonts -name 'DejaVuSansMono.ttf' | head -1)
    grub-mkfont -s 22 -o "$theme_dir/dejavu-mono-22.pf2" "$font"
    grub-mkfont -s 16 -o "$theme_dir/dejavu-mono-16.pf2" "$font"

    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch --recheck
    # fallback path for firmware that drops NVRAM entries (VirtualBox)
    grub-install --target=x86_64-efi --efi-directory=/boot --removable --recheck
    /usr/local/bin/grub-quiet   # also runs grub-mkconfig
}
run_cmd "Installing GRUB" grub_config

# ---------------------------------------------------------------- 7
step "Services"
enable_services() {
    systemctl enable NetworkManager greetd tlp thermald bluetooth \
        fstrim.timer systemd-timesyncd ufw reflector.timer paccache.timer docker.socket libvirtd.socket
    systemctl mask systemd-rfkill.service systemd-rfkill.socket   # TLP handles rfkill
    systemctl mask NetworkManager-wait-online.service              # faster boot
    systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service
}
run_cmd "Enabling services" enable_services

# ---------------------------------------------------------------- 8
step "Dotfiles"
UHOME=/home/$USERNAME
install_dotfiles() {
    rm -rf "$UHOME/arch-hyprland-installer"
    cp -a "$REPO" "$UHOME/arch-hyprland-installer"
    chown -R "$USERNAME:$USERNAME" "$UHOME/arch-hyprland-installer"
    runuser -l "$USERNAME" -c 'cd "$HOME/arch-hyprland-installer" && bash scripts/stow-all.sh'
}
run_cmd "Linking dotfiles with GNU Stow" install_dotfiles

# ---------------------------------------------------------------- 9
step "Summary"
if [[ -s $FAILED_LOG ]]; then
    warn "Packages that failed (see $FAILED_LOG):"
    sed 's/^/    - /' "$FAILED_LOG" >&2
else
    ok "All packages installed"
fi
ok "System configured"

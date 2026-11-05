#!/usr/bin/env bash
# chroot-config.sh — PASUL 2, rulează AUTOMAT în chroot (apelat de install-base.sh).
# Face: pacman, timp/locale, utilizator, pachete, mkinitcpio, GRUB + temă,
#       Plymouth + temă, greetd, configurări de sistem (baterie etc.), servicii, dotfiles.
set -Eeuo pipefail

REPO=/root/arch-hyprland-x270
# shellcheck source=lib/common.sh
source "$REPO/lib/common.sh"
# shellcheck source=/dev/null
source /root/install.conf   # HOSTNAME USERNAME TIMEZONE LUKS LUKS_UUID
trap 'die "Eroare la linia $LINENO: $BASH_COMMAND"' ERR

FAILED_LOG=/var/log/arch-hyprland-failed-packages.log
: > "$FAILED_LOG"

# ------------------------------------------------------------------ pacman
titlu "pacman"
sed -i -e 's/^#Color/Color/' -e 's/^#ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
grep -q '^ILoveCandy' /etc/pacman.conf || sed -i '/^Color/a ILoveCandy' /etc/pacman.conf

# ------------------------------------------------------------------ timp, locale, host
titlu "Timp, locale, hostname"
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc
sed -i -e 's/^#\(en_US.UTF-8 UTF-8\)/\1/' -e 's/^#\(ro_RO.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
printf 'KEYMAP=us\nFONT=ter-v16n\n' > /etc/vconsole.conf
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1  localhost
::1        localhost
127.0.1.1  $HOSTNAME.localdomain $HOSTNAME
EOF

# ------------------------------------------------------------------ utilizator
titlu "Utilizator"
id "$USERNAME" &>/dev/null || useradd -m -G wheel,video,input,audio -s /bin/zsh "$USERNAME"
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel
info "Parola pentru root:"
until passwd root; do warn "Încearcă din nou."; done
info "Parola pentru $USERNAME:"
until passwd "$USERNAME"; do warn "Încearcă din nou."; done

# ------------------------------------------------------------------ pachete
titlu "Pachete (poate dura; depinde de internet)"
for lista in 10-system 20-desktop 30-dev 40-network 50-security; do
    instaleaza_lista "$REPO/packages/$lista.txt"
done

for g in wireshark docker libvirt kvm uucp lp; do
    getent group "$g" >/dev/null && usermod -aG "$g" "$USERNAME"
done

# ------------------------------------------------------------------ configurări de sistem
titlu "Configurări de sistem (baterie, zram, sysctl, logind, greetd)"
cp -r "$REPO/system/etc/." /etc/
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf 2>/dev/null || true

# ------------------------------------------------------------------ mkinitcpio
titlu "mkinitcpio"
if [[ $LUKS == yes ]]; then
    HOOKS="base udev plymouth autodetect modconf kms keyboard keymap consolefont block encrypt filesystems fsck"
else
    HOOKS="base udev plymouth autodetect modconf kms keyboard keymap consolefont block filesystems fsck"
fi
mkdir -p /etc/mkinitcpio.conf.d
cat > /etc/mkinitcpio.conf.d/10-arch-hyprland.conf <<EOF
MODULES=(i915)
HOOKS=($HOOKS)
EOF

# ------------------------------------------------------------------ Plymouth
titlu "Plymouth"
mkdir -p /usr/share/plymouth/themes
cp -r "$REPO/system/plymouth/hackerlinux" /usr/share/plymouth/themes/
plymouth-set-default-theme hackerlinux

mkinitcpio -P

# ------------------------------------------------------------------ GRUB
titlu "GRUB"
set_grub() {   # set_grub CHEIE VALOARE  (înlocuiește sau adaugă în /etc/default/grub)
    local k=$1 v=$2
    if grep -q "^#\?${k}=" /etc/default/grub; then
        sed -i "s|^#\?${k}=.*|${k}=${v}|" /etc/default/grub
    else
        echo "${k}=${v}" >> /etc/default/grub
    fi
}

CMDLINE="quiet splash loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0 nowatchdog mem_sleep_default=deep"
set_grub GRUB_CMDLINE_LINUX_DEFAULT "\"$CMDLINE\""
if [[ $LUKS == yes ]]; then
    set_grub GRUB_CMDLINE_LINUX "\"cryptdevice=UUID=${LUKS_UUID}:cryptroot\""
fi
set_grub GRUB_TIMEOUT 3
set_grub GRUB_GFXMODE auto
set_grub GRUB_GFXPAYLOAD_LINUX keep
set_grub GRUB_TERMINAL_OUTPUT gfxterm
set_grub GRUB_THEME '"/boot/grub/themes/hackerlinux/theme.txt"'

THEME_DIR=/boot/grub/themes/hackerlinux
mkdir -p "$THEME_DIR"
cp -r "$REPO/system/grub-theme/." "$THEME_DIR/"
FONT_TTF=/usr/share/fonts/TTF/DejaVuSansMono.ttf
[[ -f $FONT_TTF ]] || FONT_TTF=$(find /usr/share/fonts -name 'DejaVuSansMono.ttf' | head -1)
grub-mkfont -s 22 -o "$THEME_DIR/dejavu-mono-22.pf2" "$FONT_TTF"
grub-mkfont -s 16 -o "$THEME_DIR/dejavu-mono-16.pf2" "$FONT_TTF"

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch --recheck
# copie de rezervă pe calea standard (VirtualBox și unele BIOS-uri nu țin intrarea NVRAM)
grub-install --target=x86_64-efi --efi-directory=/boot --removable --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# ------------------------------------------------------------------ servicii
titlu "Servicii"
systemctl enable NetworkManager greetd tlp thermald bluetooth \
    fstrim.timer systemd-timesyncd ufw reflector.timer paccache.timer docker.socket
# TLP recomandă să nu existe aceste unități (gestionează el rfkill)
systemctl mask systemd-rfkill.service systemd-rfkill.socket
# fără așteptare inutilă la boot
systemctl mask NetworkManager-wait-online.service
# audio per-utilizator, pornit la cerere
systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service

# ------------------------------------------------------------------ dotfiles + repo în home
titlu "Dotfiles pentru $USERNAME"
UHOME=/home/$USERNAME
rm -rf "$UHOME/arch-hyprland-x270"
cp -a "$REPO" "$UHOME/arch-hyprland-x270"
chown -R "$USERNAME:$USERNAME" "$UHOME/arch-hyprland-x270"
runuser -l "$USERNAME" -c 'cd "$HOME/arch-hyprland-x270" && bash scripts/stow-all.sh'

if [[ -s $FAILED_LOG ]]; then
    warn "Pachete care nu au putut fi instalate (vezi $FAILED_LOG):"
    sed 's/^/    - /' "$FAILED_LOG" >&2
fi

ok "chroot-config terminat."

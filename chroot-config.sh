#!/usr/bin/env bash
# chroot-config.sh
# Rulat automat de install-base.sh, ÎN INTERIORUL arch-chroot.
# Args: $1=hostname  $2=username  $3=boot_partition  $4=disc_path  $5=tip_disc (HDD/SSD)
set -euo pipefail

HOSTNAME="$1"
USERNAME="$2"
BOOT_PART="$3"
DISC_PATH="$4"
TIP_DISC="$5"

GITHUB_USER="florflorin78"
REPO="arch-hyprland-x270"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO}/${BRANCH}"

# ============================================================
# TIMEZONE + LOCALE
# ============================================================
seteaza_timezone_locale() {
    ln -sf /usr/share/zoneinfo/Europe/Bucharest /etc/localtime
    hwclock --systohc

    sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    sed -i 's/^#ro_RO.UTF-8 UTF-8/ro_RO.UTF-8 UTF-8/' /etc/locale.gen
    locale-gen

    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    echo "KEYMAP=us" > /etc/vconsole.conf
}

# ============================================================
# HOSTNAME
# ============================================================
seteaza_hostname() {
    echo "$HOSTNAME" > /etc/hostname
    cat >> /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF
}

# ============================================================
# USER + SUDO
# ============================================================
creeaza_user() {
    useradd -m -G wheel -s /bin/bash "$USERNAME"
    echo ">>> Setează parola pentru utilizatorul ${USERNAME}:"
    passwd "$USERNAME"
    echo ">>> Setează parola pentru root:"
    passwd
}

configureaza_sudo() {
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
}

# ============================================================
# GRUB — instalare + boot instant (timeout=0), fără meniu vizibil
# ============================================================
instaleaza_grub() {
    echo "Instalez GRUB (UEFI)..."
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB "$DISC_PATH"
}

configureaza_grub_boot_instant() {
    # timeout=0 => pornește direct Arch, fără să aștepte input (boot "instant")
    # GRUB_TIMEOUT_STYLE=hidden => nu afișează deloc meniul text, doar splash-ul Plymouth
    sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
    sed -i 's/^#GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
    if ! grep -q "^GRUB_TIMEOUT_STYLE=" /etc/default/grub; then
        echo "GRUB_TIMEOUT_STYLE=hidden" >> /etc/default/grub
    fi

    # Adaug "quiet splash" la kernel, ca să nu se vadă text derulant, ci doar Plymouth
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub

    grub-mkconfig -o /boot/grub/grub.cfg
}

# ============================================================
# PLYMOUTH — splash screen fancy la boot, în loc de consolă text
# ============================================================
instaleaza_plymouth() {
    echo "Instalez Plymouth..."
    pacman -S --needed --noconfirm plymouth

    # HOOKS reordonate + "kms" pus devreme = driverul video (i915, pt Intel HD 520)
    # se încarcă ÎNAINTE de Plymouth. Fără asta, ecranul "sare" o dată (rezoluție
    # mică -> rezoluție mare) când se încarcă driverul abia mai târziu — asta e flicker-ul vizibil. Cu "kms" devreme, tranziția e continuă, fără sărituri.
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block plymouth filesystems fsck)/' /etc/mkinitcpio.conf

    # i915 = driverul kernel pentru grafica Intel a X270-ului. Îl încărcăm explicit
    # devreme (early KMS), nu lăsat să se încarce "cand vrea el" mai târziu.
    sed -i 's/^MODULES=.*/MODULES=(i915)/' /etc/mkinitcpio.conf

    mkinitcpio -P

    # Descarc tema custom din repo și o instalez
    mkdir -p /usr/share/plymouth/themes/x270-fancy
    curl -fsSL "${RAW_BASE}/plymouth-theme/x270-fancy.plymouth" \
        -o /usr/share/plymouth/themes/x270-fancy/x270-fancy.plymouth
    curl -fsSL "${RAW_BASE}/plymouth-theme/x270-fancy.script" \
        -o /usr/share/plymouth/themes/x270-fancy/x270-fancy.script

    plymouth-set-default-theme -R x270-fancy
}

# ============================================================
# BOOT RAPID — reduce timpul de boot la minim
# ============================================================
optimizeaza_boot_rapid() {
    # loglevel=3 = kernelul nu mai printează mesaje pe ecran (le ții tot în `journalctl` dacă ai nevoie de ele, doar nu le mai AFIȘEZI la boot)
    # vt.global_cursor_default=0 = ascunde cursorul care "sare" pe ecran
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 vt.global_cursor_default=0"/' /etc/default/grub

    # Nu avem alt OS de detectat (doar Arch pe disc) -> grub-mkconfig nu mai pierde timp scanând alte partiții pentru dual-boot
    if ! grep -q "^GRUB_DISABLE_OS_PROBER=" /etc/default/grub; then
        echo "GRUB_DISABLE_OS_PROBER=true" >> /etc/default/grub
    fi

    grub-mkconfig -o /boot/grub/grub.cfg

    # NetworkManager-wait-online blochează boot-ul până confirmă că netul e sus.
    # Nu e nevoie de asta ca să ajungi la login — netul se conectează oricum în fundal câteva secunde mai târziu, fără să te blocheze pe ecranul de boot.
    systemctl disable NetworkManager-wait-online.service 2>/dev/null || true
}


# ============================================================
# TRIM — doar dacă discul e SSD (nu strică pe HDD, dar nu are rost)
# ============================================================
activeaza_trim_daca_ssd() {
    if [ "$TIP_DISC" = "SSD" ]; then
        echo "Disc SSD detectat -> activez fstrim.timer (TRIM periodic)."
        systemctl enable fstrim.timer
    else
        echo "Disc HDD detectat -> TRIM nu se aplică, nu activez fstrim.timer."
    fi
}

# ============================================================
# NETWORKMANAGER
# ============================================================
activeaza_networkmanager() {
    systemctl enable NetworkManager
}

# ============================================================
# MAIN
# ============================================================
main() {
    seteaza_timezone_locale
    seteaza_hostname
    creeaza_user
    configureaza_sudo
    instaleaza_grub
    configureaza_grub_boot_instant
    instaleaza_plymouth
    optimizeaza_boot_rapid
    activeaza_trim_daca_ssd
    activeaza_networkmanager

    echo "== chroot-config.sh complet =="
}

main

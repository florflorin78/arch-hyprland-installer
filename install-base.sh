#!/usr/bin/env bash
# install-base.sh — PASUL 1, rulează din Arch ISO (live).
# Face: alegere disc -> partiționare -> (LUKS) -> formatare -> pacstrap -> fstab
#       -> copiază repo-ul în noul sistem -> pornește chroot-config.sh în chroot.
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
trap 'die "Eroare la linia $LINENO: $BASH_COMMAND"' ERR

# ---------------------------------------------------------------- verificări
verifica_root
verifica_uefi
verifica_internet

cat <<'BANNER'

   ___           __      __  __                  __                __
  / _ |  ____ __/ /     / / / /_ _____  ____ ___/ /__ ____  ___/ /
 / __ | / __/ // _ \   / /_/ / // / _ \/ __// _  / _ `/ _ \/ _  /
/_/ |_|/_/  \___/_//_/ \____/\_, / .__/_/   \_,_/\_,_/_//_/\_,_/
                            /___/_/        ThinkPad X270 edition

BANNER

# ---------------------------------------------------------------- alegere disc
alege_disc() {
    titlu "Alegere disc"
    local iso_src iso_disk=""
    iso_src=$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null || true)
    [[ -n $iso_src ]] && iso_disk=$(lsblk -no PKNAME "$iso_src" 2>/dev/null | head -1 || true)

    local -a discuri=()
    local d
    while read -r d; do
        [[ -n $iso_disk && $d == "/dev/$iso_disk" ]] && continue   # nu șterge stick-ul de instalare
        discuri+=("$d")
    done < <(lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1}')

    ((${#discuri[@]} > 0)) || die "Nu am găsit niciun disc."

    local i=1
    for d in "${discuri[@]}"; do
        printf '  %d) %s  %s\n' "$i" "$d" "$(lsblk -dpno SIZE,MODEL,TRAN "$d" | xargs)"
        ((i++))
    done
    local n
    read -r -p "Număr disc: " n
    [[ $n =~ ^[0-9]+$ ]] && ((n >= 1 && n <= ${#discuri[@]})) || die "Alegere invalidă."
    DISC=${discuri[n-1]}

    lsblk "$DISC"
    warn "TOATE datele de pe $DISC vor fi ȘTERSE."
    local conf
    read -r -p "Scrie exact calea discului ($DISC) ca să confirmi: " conf
    [[ $conf == "$DISC" ]] || die "Confirmare greșită, mă opresc."
}

# numele partițiilor: /dev/sda1 dar /dev/nvme0n1p1
part() { [[ $1 =~ [0-9]$ ]] && echo "${1}p$2" || echo "${1}$2"; }

alege_disc

titlu "Setări sistem"
intreaba HOSTNAME "Hostname" "x270"
while :; do
    intreaba USERNAME "Nume utilizator (litere mici)" ""
    [[ $USERNAME =~ ^[a-z_][a-z0-9_-]{0,30}$ ]] && break
    warn "Nume invalid."
done
intreaba TIMEZONE "Fus orar" "Europe/Bucharest"
[[ -f /usr/share/zoneinfo/$TIMEZONE ]] || die "Fus orar inexistent: $TIMEZONE"
if confirma "Criptez discul cu LUKS (recomandat pe laptop)?"; then LUKS=yes; else LUKS=no; fi

# ---------------------------------------------------------------- pregătire live
titlu "Pregătire mediu live"
timedatectl set-ntp true || warn "NTP nu a pornit"
sed -i -e 's/^#Color/Color/' -e 's/^#ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
info "Optimizez mirror-urile (max 90s)..."
timeout 90 reflector --country Romania,Germany,Austria,Hungary,Bulgaria --protocol https \
    --latest 15 --sort rate --save /etc/pacman.d/mirrorlist || warn "reflector a eșuat, folosesc mirror-urile existente"

# ---------------------------------------------------------------- partiționare
titlu "Partiționare $DISC"
swapoff -a || true
umount -R /mnt 2>/dev/null || true
wipefs -af "$DISC"
sgdisk --zap-all "$DISC"
sgdisk -n1:0:+1G -t1:ef00 -c1:ESP "$DISC"
if [[ $LUKS == yes ]]; then
    sgdisk -n2:0:0 -t2:8309 -c2:cryptroot "$DISC"
else
    sgdisk -n2:0:0 -t2:8300 -c2:root "$DISC"
fi
partprobe "$DISC"
udevadm settle
sleep 1

P_ESP=$(part "$DISC" 1)
P_ROOT=$(part "$DISC" 2)
LUKS_UUID=""
ROOT_DEV=$P_ROOT

if [[ $LUKS == yes ]]; then
    titlu "LUKS2 pe $P_ROOT"
    info "Alege o parolă de criptare puternică. Fără ea datele NU se pot recupera."
    cryptsetup luksFormat --type luks2 "$P_ROOT"
    cryptsetup open "$P_ROOT" cryptroot
    LUKS_UUID=$(blkid -s UUID -o value "$P_ROOT")
    ROOT_DEV=/dev/mapper/cryptroot
fi

# ---------------------------------------------------------------- formatare + montare
titlu "Formatare"
mkfs.fat -F32 -n ESP "$P_ESP"
mkfs.ext4 -F -L arch "$ROOT_DEV"
mount -o noatime "$ROOT_DEV" /mnt
mount --mkdir -o umask=0077 "$P_ESP" /mnt/boot   # ESP = /boot (kernelul stă pe FAT32, e ok)

# ---------------------------------------------------------------- pacstrap
titlu "pacstrap (sistemul de bază)"
mapfile -t BASE_PKGS < <(citeste_lista "$SCRIPT_DIR/packages/00-base.txt")
pacstrap -K /mnt "${BASE_PKGS[@]}"

genfstab -U /mnt >> /mnt/etc/fstab
ok "fstab generat"

# ---------------------------------------------------------------- repo + config pentru chroot
titlu "Copiez repo-ul în noul sistem"
rm -rf /mnt/root/arch-hyprland-x270
cp -a "$SCRIPT_DIR" /mnt/root/arch-hyprland-x270
{
    printf 'HOSTNAME=%q\n'  "$HOSTNAME"
    printf 'USERNAME=%q\n'  "$USERNAME"
    printf 'TIMEZONE=%q\n'  "$TIMEZONE"
    printf 'LUKS=%q\n'      "$LUKS"
    printf 'LUKS_UUID=%q\n' "$LUKS_UUID"
} > /mnt/root/install.conf
chmod 600 /mnt/root/install.conf

titlu "Intru în chroot"
arch-chroot /mnt bash /root/arch-hyprland-x270/chroot-config.sh

# ---------------------------------------------------------------- final
titlu "Gata"
rm -f /mnt/root/install.conf
umount -R /mnt
[[ $LUKS == yes ]] && cryptsetup close cryptroot
ok "Instalare terminată. Scoate stick-ul USB."
if confirma "Repornesc acum?"; then reboot; fi

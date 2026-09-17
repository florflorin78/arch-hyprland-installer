#!/usr/bin/env bash
# install-base.sh
# Rulează din Arch ISO live environment, ca root.
# Merge pe orice tip de disc: HDD (sda), SATA SSD (sda), sau NVMe M.2 (nvme0n1).
set -euo pipefail

GITHUB_USER="florflorin78"
REPO="arch-hyprland-x270"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO}/${BRANCH}"

# ============================================================
# VERIFICĂRI PRELIMINARE
# ============================================================

verifica_internet() {
    if ping -c1 -W2 archlinux.org &>/dev/null; then
        echo "[OK] Conexiunea la Internet este activă."
    else
        echo "[EROARE] Nu am conexiune la Internet. Verifică și încearcă din nou."
        exit 1
    fi
}


verifica_uefi() {
    if [ -d /sys/firmware/efi ]; then
        echo "Sistemul este pe UEFI."
    else
        echo "Sistemul nu este pe UEFI."
        exit 1
    fi
}

listeaza_discuri() {
    echo
    echo "Discuri disponibile:"
    lsblk -d -o NAME,SIZE,ROTA,MODEL
    echo
}

# Detectează dacă un disc e HDD sau SSD, uitându-se la /sys/block/<disc>/queue/rotational
# 1 = HDD (are piese mecanice care se rotesc), 0 = SSD (memorie flash, fără piese mobile)
detecteaza_tip_disc() {
    local disc="$1"
    local rota_file="/sys/block/${disc}/queue/rotational"

    if [ ! -f "$rota_file" ]; then
        echo "necunoscut"
        return
    fi

    if [ "$(cat "$rota_file")" -eq 1 ]; then
        echo "HDD"
    else
        echo "SSD"
    fi
}

# ============================================================
# HELPER: numele corect al partițiilor, indiferent de tip disc
# ============================================================
# NVMe (ex: nvme0n1) -> partițiile se numesc nvme0n1p1, nvme0n1p2 (cu "p" înainte de număr)
# SATA (ex: sda)     -> partițiile se numesc sda1, sda2 (fără "p")
nume_partitie() {
    local disc="$1"
    local numar="$2"

    if [[ "$disc" == *nvme* ]] || [[ "$disc" == *mmcblk* ]]; then
        echo "${disc}p${numar}"
    else
        echo "${disc}${numar}"
    fi
}

# ============================================================
# PARTIȚIONARE + FORMATARE (merge identic pe HDD/SSD/NVMe)
# ============================================================

partitioneaza_si_formateaza() {
    local disc_path="$1"   # ex: /dev/sda sau /dev/nvme0n1

    echo "Partiționez ${disc_path} (GPT, EFI + root)..."
    parted -s "$disc_path" mklabel gpt
    parted -s "$disc_path" mkpart ESP fat32 1MiB 513MiB
    parted -s "$disc_path" set 1 esp on
    parted -s "$disc_path" mkpart primary ext4 513MiB 100%

    local disc_name
    disc_name=$(basename "$disc_path")
    BOOT_PART="/dev/$(nume_partitie "$disc_name" 1)"
    ROOT_PART="/dev/$(nume_partitie "$disc_name" 2)"

    echo "Formatez partiția EFI (${BOOT_PART}) ca FAT32..."
    mkfs.fat -F32 "$BOOT_PART"

    echo "Formatez partiția root (${ROOT_PART}) ca ext4..."
    mkfs.ext4 -F "$ROOT_PART"

    echo "Montez partițiile în /mnt..."
    mount "$ROOT_PART" /mnt
    mkdir -p /mnt/boot
    mount "$BOOT_PART" /mnt/boot

    export BOOT_PART ROOT_PART
}

# ============================================================
# PACSTRAP: sistem de bază
# ============================================================

instaleaza_sistem_de_baza() {
    echo "Instalez sistemul de bază (poate dura câteva minute)..."
    pacstrap -K /mnt base linux linux-firmware base-devel intel-ucode \
        networkmanager sudo vim git stow grub efibootmgr

    echo "Generez fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
}

# ============================================================
# MAIN
# ============================================================

main() {
    echo "== Arch Hyprland X270 — instalare de bază =="
    echo

    verifica_internet
    verifica_uefi
    listeaza_discuri

    read -rp "Numele discului pe care instalăm (ex: sda sau nvme0n1, FĂRĂ /dev/): " DISC_NAME
    DISC_PATH="/dev/${DISC_NAME}"

    if [ ! -b "$DISC_PATH" ]; then
        echo "[EROARE] ${DISC_PATH} nu există sau nu e un disc valid."
        exit 1
    fi

    TIP_DISC=$(detecteaza_tip_disc "$DISC_NAME")
    echo "[INFO] Tip disc detectat: ${TIP_DISC}"
    export TIP_DISC

    echo
    echo "!!! ATENȚIE: TOT ce e pe ${DISC_PATH} va fi ȘTERS. !!!"
    read -rp "Scrie exact 'STERGE' ca să continui: " CONFIRM
    if [ "$CONFIRM" != "STERGE" ]; then
        echo "Anulat de utilizator."
        exit 1
    fi

    read -rp "Hostname pentru laptop (ex: x270): " HOSTNAME
    read -rp "Username: " USERNAME

    partitioneaza_si_formateaza "$DISC_PATH"
    instaleaza_sistem_de_baza

    echo "Descarc chroot-config.sh din repo..."
    curl -fsSL "${RAW_BASE}/chroot-config.sh" -o /mnt/root/chroot-config.sh
    chmod +x /mnt/root/chroot-config.sh

    echo "Intru în chroot și configurez sistemul..."
    arch-chroot /mnt /root/chroot-config.sh "$HOSTNAME" "$USERNAME" "$BOOT_PART" "$DISC_PATH" "$TIP_DISC"

    echo
    echo "== Instalare de bază completă =="
    echo "Rulează 'umount -R /mnt' apoi 'reboot'."
    echo "După primul login, rulează post-install.sh ca userul ${USERNAME}:"
    echo "  curl -fsSL ${RAW_BASE}/post-install.sh | bash"
}

main

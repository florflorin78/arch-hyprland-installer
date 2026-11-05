#!/usr/bin/env bash
# lib/common.sh — funcții comune pentru toate scripturile.
# Se "sursează" (source lib/common.sh), nu se rulează direct.

C_RESET=$'\e[0m'
C_RED=$'\e[31m'
C_GREEN=$'\e[32m'
C_YELLOW=$'\e[33m'
C_CYAN=$'\e[36m'
C_BOLD=$'\e[1m'

info()  { printf '%s[*]%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }
ok()    { printf '%s[+]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()  { printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()   { printf '%s[x]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }
titlu() { printf '\n%s== %s ==%s\n' "$C_BOLD" "$*" "$C_RESET"; }

# confirma "Întrebare?"  -> return 0 doar dacă utilizatorul răspunde d/D/y/Y
confirma() {
    local r
    read -r -p "$1 [d/N] " r
    [[ $r =~ ^[dDyY]$ ]]
}

# intreaba VARIABILA "Întrebare" [valoare_implicita]
intreaba() {
    local __var=$1 __q=$2 __def=${3:-} __r
    read -r -p "${__q}${__def:+ [$__def]}: " __r
    printf -v "$__var" '%s' "${__r:-$__def}"
}

verifica_root() {
    [[ $EUID -eq 0 ]] || die "Scriptul trebuie rulat ca root."
}

verifica_internet() {
    info "Verific conexiunea la internet..."
    curl -fsS --max-time 8 -o /dev/null https://archlinux.org \
        || die "Nu am internet. Conectează-te (iwctl pentru Wi-Fi) și reîncearcă."
    ok "Internet OK"
}

verifica_uefi() {
    [[ -d /sys/firmware/efi/efivars ]] \
        || die "Nu e boot UEFI. În VirtualBox: Settings > System > 'Enable EFI'."
    ok "Boot UEFI"
}

# citeste_lista fisier  -> afișează numele pachetelor (ignoră comentarii și linii goale)
citeste_lista() {
    sed -e 's/#.*//' "$1" | awk 'NF{print $1}'
}

# Pachetele eșuate sunt notate aici ca să le poți verifica după instalare
: "${FAILED_LOG:=/var/log/arch-hyprland-failed-packages.log}"

# instaleaza_lista fisier — încearcă totul dintr-o dată; dacă un nume de pachet
# nu există (se mai redenumesc), cade pe instalare pachet cu pachet, ca un pachet
# lipsă să nu strice toată instalarea.
instaleaza_lista() {
    local fisier=$1 p
    local -a pachete
    mapfile -t pachete < <(citeste_lista "$fisier")
    info "Instalez $(basename "$fisier") (${#pachete[@]} pachete)"
    if pacman -S --needed --noconfirm "${pachete[@]}"; then
        return 0
    fi
    warn "Instalarea în bloc a eșuat, încerc pachet cu pachet..."
    for p in "${pachete[@]}"; do
        pacman -S --needed --noconfirm "$p" || {
            warn "Nu am putut instala: $p"
            echo "$p" >> "$FAILED_LOG"
        }
    done
    return 0
}

#!/usr/bin/env bash
# Shared helpers: terminal-style UI (green phosphor). Source this file; do not run it.

C_GRN=$'\e[32m'
C_BRT=$'\e[1;92m'
C_RED=$'\e[1;31m'
C_YEL=$'\e[1;33m'
# resetting returns to plain green, so the whole UI stays green
C_RESET=$'\e[0m\e[32m'

if [[ -t 1 ]]; then
    printf '%s' "$C_GRN"
    trap 'printf "\e[0m\e[?25h"' EXIT
fi


: "${LOG_FILE:=/tmp/arch-hyprland-install.log}"
: "${FAILED_LOG:=/var/log/arch-hyprland-failed-packages.log}"
STEP_NOW=0
STEP_TOTAL=${STEP_TOTAL:-0}
LEAD=48   # width of the "description ....." column

term_width() { local c; c=$(tput cols 2>/dev/null) || c=80; echo "${c:-80}"; }
repeat() { local s="" i; for ((i = 0; i < $2; i++)); do s+="$1"; done; printf '%s' "$s"; }
fmt_time() { printf '%d:%02d' $(($1 / 60)) $(($1 % 60)); }
leader() { local n=$((LEAD - ${#1})); ((n < 2)) && n=2; repeat . "$n"; }

# log-style lines: [ OK ] text ........ detail
log_line() {   # log_line TAG_COLOR TAG TEXT [DETAIL]
    local d=${4:-}
    if [[ -n $d ]]; then
        printf ' %s[ %s ]%s %s %s%s%s %s\n' "$1" "$2" "$C_RESET" "$3" "$C_GRN" "$(leader "$3")" "$C_RESET" "$d"
    else
        printf ' %s[ %s ]%s %s\n' "$1" "$2" "$C_RESET" "$3"
    fi
}
info() { log_line "$C_GRN" ".." "$*"; }
ok()   { log_line "$C_BRT" "OK" "$@"; }
warn() { log_line "$C_YEL" "!!" "$*" >&2; }
die() {
    tput cnorm 2>/dev/null || true
    printf '\n %s[FAIL]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
    [[ -f $LOG_FILE ]] && printf ' %s       full log: %s%s\n' "$C_GRN" "$LOG_FILE" "$C_RESET" >&2
    exit 1
}

sysinfo_kv() {   # key/value rows for the info panel
    local cpu ram boot
    cpu=$(awk -F: '/model name/{gsub(/^ +/,"",$2);print $2;exit}' /proc/cpuinfo | sed 's/(R)//g;s/(TM)//g;s/ CPU//;s/  */ /g' | cut -c1-30)
    ram=$(awk '/MemTotal/{printf "%.1f GB",$2/1048576}' /proc/meminfo)
    [[ -d /sys/firmware/efi/efivars ]] && boot=UEFI || boot=BIOS
    printf '%s\n' "host    $(hostname)" "kernel  $(uname -r)" "cpu     ${cpu:-?}" "ram     $ram" "boot    $boot" "target  ${DISK:-not chosen yet}"
}

banner() {
    local -a logo=(
        ' █████╗ ██████╗  ██████╗██╗  ██╗'
        '██╔══██╗██╔══██╗██╔════╝██║  ██║'
        '███████║██████╔╝██║     ███████║'
        '██╔══██║██╔══██╗██║     ██╔══██║'
        '██║  ██║██║  ██║╚██████╗██║  ██║'
        '╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝')
    local -a kv
    mapfile -t kv < <(sysinfo_kv)
    local i k v
    printf ' %s%s@%s%s:~/arch-hyprland-installer$ %s./%s%s█%s\n\n' "$C_BRT" "${USER:-root}" "$(hostname)" "$C_RESET" "$C_GRN" "$(basename "${0:-install}")" "$C_BRT" "$C_RESET"
    for i in "${!logo[@]}"; do
        printf ' %s%s%s' "$C_BRT" "${logo[i]}" "$C_RESET"
        if [[ -n ${kv[i]:-} ]]; then
            k=${kv[i]%% *}; v=${kv[i]#* }; v=${v#"${v%%[![:space:]]*}"}
            printf '   %s%-8s%s%s' "$C_GRN" "$k" "$C_BRT" "$v"
        fi
        printf '%s\n' "$C_RESET"
    done
    printf '\n %sHYPRLAND · THINKPAD X270 · KEYBOARD-FIRST%s\n' "$C_GRN" "$C_RESET"
}

progress_bar() {   # progress_bar PERCENT [WIDTH]
    local p=$1 w=${2:-40} f
    f=$((p * w / 100))
    printf ' %s[%s%s%s%s]%s %s%3d%%%s' "$C_GRN" "$C_BRT" "$(repeat '█' "$f")" "$C_GRN" "$(repeat '░' $((w - f)))" "$C_RESET" "$C_BRT" "$p" "$C_RESET"
}

# step "Title" -> ── [2/7] Title ────  + overall progress bar
step() {
    STEP_NOW=$((STEP_NOW + 1))
    local txt n
    if ((STEP_TOTAL > 0)); then txt=" [$STEP_NOW/$STEP_TOTAL] $* "; else txt=" $* "; fi
    n=$(($(term_width) - ${#txt} - 3))
    ((n < 4)) && n=4
    printf '\n%s──%s%s%s%s%s\n' "$C_GRN" "$C_BRT" "$txt" "$C_RESET$C_GRN" "$(repeat '─' "$n")" "$C_RESET"
    if ((STEP_TOTAL > 0)); then progress_bar $(((STEP_NOW - 1) * 100 / STEP_TOTAL)); echo; fi
}

# box "Title" "line" ...
box() {
    local title=$1 l w=0
    shift
    for l in "$@" "$title"; do ((${#l} > w)) && w=${#l}; done
    w=$((w + 2))
    printf '%s┌─ %s%s%s %s┐%s\n' "$C_GRN" "$C_BRT" "$title" "$C_RESET$C_GRN" "$(repeat '─' $((w - ${#title} - 2)))" "$C_RESET"
    for l in "$@"; do
        printf '%s│%s %-*s %s│%s\n' "$C_GRN" "$C_RESET" "$((w - 1))" "$l" "$C_GRN" "$C_RESET"
    done
    printf '%s└%s┘%s\n' "$C_GRN" "$(repeat '─' $((w + 1)))" "$C_RESET"
}

# run_cmd "Description" cmd args...
# Runs in the background; shows [ / ] + elapsed time + last log line; output goes to $LOG_FILE.
# Not for interactive commands (cryptsetup, passwd).
run_cmd() {
    local desc=$1
    shift
    local spin='|/-\' i=0 pid rc start=$SECONDS w last tty=1 t
    [[ -t 1 ]] || tty=0

    mkdir -p "$(dirname "$LOG_FILE")"
    printf '\n### %s\n$ %s\n' "$desc" "$*" >> "$LOG_FILE"

    "$@" >> "$LOG_FILE" 2>&1 &
    pid=$!

    if ((tty)); then
        tput civis 2>/dev/null || true
        while kill -0 "$pid" 2>/dev/null; do
            w=$(term_width)
            t=$(fmt_time $((SECONDS - start)))
            last=$(tail -c 400 "$LOG_FILE" | tr '\r' '\n' | sed '/^[[:space:]]*$/d' | tail -1 | cut -c1-$((w - LEAD - 22)))
            printf '\r\e[K %s[ %s ]%s %s %s%s %s%s %s%s%s' \
                "$C_BRT" "${spin:$((i++ % 4)):1}" "$C_RESET" "$desc" "$C_GRN" "$(leader "$desc")" "$C_BRT" "$t" "$C_GRN" "$last" "$C_RESET"
            sleep 0.12
        done
    fi

    wait "$pid" && rc=0 || rc=$?
    ((tty)) && { tput cnorm 2>/dev/null || true; }

    printf '\r\e[K'
    if ((rc == 0)); then
        log_line "$C_BRT" "OK" "$desc" "$(fmt_time $((SECONDS - start)))"
    else
        log_line "$C_RED" "FAIL" "$desc" "exit $rc"
        tail -n 15 "$LOG_FILE" | tr '\r' '\n' | sed 's/^/   | /' >&2
    fi
    return "$rc"
}

# confirm "Question?" -> 0 only on y/Y
confirm() {
    local r
    read -r -p " ${C_BRT}?${C_RESET} $1 ${C_GRN}[y/N]${C_RESET}> ${C_BRT}" r
    printf '%s' "$C_RESET"
    [[ $r =~ ^[yY]$ ]]
}

# ask VAR "Question" [default]
ask() {
    local __var=$1 __q=$2 __def=${3:-} __r
    read -r -p " ${C_BRT}?${C_RESET} ${__q}${__def:+ ${C_GRN}[$__def]${C_RESET}}> ${C_BRT}" __r
    printf '%s' "$C_RESET"
    printf -v "$__var" '%s' "${__r:-$__def}"
}

check_root() { [[ $EUID -eq 0 ]] || die "Run as root."; }
check_internet() {
    curl -fsS --max-time 8 -o /dev/null https://archlinux.org \
        || die "No internet. Connect first (iwctl for Wi-Fi)."
    ok "network" "online"
}
check_uefi() {
    [[ -d /sys/firmware/efi/efivars ]] || die "Not booted in UEFI mode (VirtualBox: Settings > System > Enable EFI)."
    ok "boot mode" "UEFI"
}

# read_list FILE -> package names (comments and blank lines stripped)
read_list() { sed -e 's/#.*//' "$1" | awk 'NF{print $1}'; }

# install_list FILE: install all at once; on failure fall back to one by one.
install_list() {
    local file=$1 p
    local -a pkgs
    mapfile -t pkgs < <(read_list "$file")
    if run_cmd "install $(basename "$file" .txt) (${#pkgs[@]} pkgs)" pacman -S --needed --noconfirm "${pkgs[@]}"; then
        return 0
    fi
    warn "bulk install failed, retrying one by one"
    for p in "${pkgs[@]}"; do
        run_cmd "  $p" pacman -S --needed --noconfirm "$p" || { warn "failed: $p"; echo "$p" >> "$FAILED_LOG"; }
    done
    return 0
}

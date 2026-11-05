#!/usr/bin/env bash
# post-install.sh — PASUL 3, rulează o singură dată, automat, la primul login în Hyprland
# (pornit de ~/.local/bin/first-run). Poate fi rulat și manual oricând: ./post-install.sh
# Face: git identity, yay + pachete AUR, rustup, plugin-uri neovim, cheie SSH, tealdeer.
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

[[ $EUID -ne 0 ]] || die "Rulează ca utilizator normal, nu root."
FAILED_LOG="$HOME/arch-hyprland-failed-aur.log"
: > "$FAILED_LOG"

verifica_internet

# sudo o singură dată + menținut în viață cât timp compilăm pachete AUR
sudo -v
( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
KEEPALIVE=$!
trap 'kill "$KEEPALIVE" 2>/dev/null || true' EXIT

# ------------------------------------------------------------------ git
titlu "Identitate git"
if ! git config --file "$HOME/.gitconfig" user.name >/dev/null 2>&1; then
    intreaba GIT_NAME  "Nume pentru commit-uri" ""
    intreaba GIT_EMAIL "Email pentru commit-uri" ""
    [[ -n $GIT_NAME ]]  && git config --file "$HOME/.gitconfig" user.name  "$GIT_NAME"
    [[ -n $GIT_EMAIL ]] && git config --file "$HOME/.gitconfig" user.email "$GIT_EMAIL"
fi

# repo-ul a fost clonat shallow-free, dar dacă e nevoie:
git -C "$SCRIPT_DIR" fetch --unshallow 2>/dev/null || true

# ------------------------------------------------------------------ yay + AUR
titlu "yay + pachete AUR"
if ! command -v yay >/dev/null; then
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi

mapfile -t AUR_PKGS < <(citeste_lista "$SCRIPT_DIR/packages/aur.txt")
if ((${#AUR_PKGS[@]})); then
    yay -S --needed --noconfirm "${AUR_PKGS[@]}" || {
        warn "Bloc AUR eșuat, încerc pe rând..."
        for p in "${AUR_PKGS[@]}"; do
            yay -S --needed --noconfirm "$p" || { warn "AUR eșuat: $p"; echo "$p" >> "$FAILED_LOG"; }
        done
    }
fi

# ------------------------------------------------------------------ limbaje / unelte
titlu "Rust, neovim, tldr"
command -v rustup >/dev/null && rustup default stable || warn "rustup lipsește"
nvim --headless "+Lazy! sync" +qa 2>/dev/null || warn "Sincronizarea plugin-urilor neovim a eșuat (rulează :Lazy sync manual)"
tldr --update 2>/dev/null || true
xdg-user-dirs-update || true

# ------------------------------------------------------------------ SSH
titlu "Cheie SSH"
if [[ ! -f $HOME/.ssh/id_ed25519 ]] && confirma "Generez o cheie SSH ed25519 (pentru GitHub)?"; then
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$(git config --file "$HOME/.gitconfig" user.email || echo "$USER@$(hostname)")" -f "$HOME/.ssh/id_ed25519"
    info "Cheia publică (adaug-o la GitHub > Settings > SSH keys):"
    cat "$HOME/.ssh/id_ed25519.pub"
fi

# ------------------------------------------------------------------ gata
mkdir -p "$HOME/.local/state/arch-hyprland"
touch "$HOME/.local/state/arch-hyprland/first-run-done"
[[ -s $FAILED_LOG ]] && warn "Pachete AUR eșuate: $(tr '\n' ' ' < "$FAILED_LOG")"

ok "Totul e gata. Scurtătura SUPER+F1 îți arată toate shortcut-urile."

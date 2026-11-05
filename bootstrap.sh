#!/usr/bin/env bash
# bootstrap.sh — singura comandă de care ai nevoie din Arch ISO (live):
#
#   curl -fsSL https://raw.githubusercontent.com/florflorin78/arch-hyprland-x270/main/bootstrap.sh | bash
#
# Clonează tot repo-ul (scripturile au nevoie și de dotfiles/pachete) și pornește installer-ul.
set -Eeuo pipefail

REPO_URL="${REPO_URL:-https://github.com/florflorin78/arch-hyprland-x270.git}"
BRANCH="${BRANCH:-main}"
DEST=/root/arch-hyprland-x270

[[ $EUID -eq 0 ]] || { echo "Rulează ca root (în Arch ISO ești deja root)."; exit 1; }

command -v git >/dev/null || pacman -Sy --noconfirm git

rm -rf "$DEST"
git clone -b "$BRANCH" "$REPO_URL" "$DEST"
cd "$DEST"

# IMPORTANT: la 'curl | bash' stdin e pipe-ul, deci installer-ul nu ar putea citi
# răspunsurile tale. Îl legăm explicit la terminal.
exec bash ./install-base.sh </dev/tty

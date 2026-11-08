#!/usr/bin/env bash
# curl -fsSL https://raw.githubusercontent.com/florflorin78/arch-hyprland-installer/main/bootstrap.sh | bash
set -Eeuo pipefail

REPO_URL="${REPO_URL:-https://github.com/florflorin78/arch-hyprland-installer.git}"
BRANCH="${BRANCH:-main}"
DEST=/root/arch-hyprland-installer

[[ $EUID -eq 0 ]] || { echo "Run as root."; exit 1; }
command -v git >/dev/null || pacman -Sy --noconfirm git

rm -rf "$DEST"
git clone -b "$BRANCH" "$REPO_URL" "$DEST"
cd "$DEST"

# stdin is the pipe under 'curl | bash'; reattach the terminal for prompts
exec bash ./install-base.sh </dev/tty

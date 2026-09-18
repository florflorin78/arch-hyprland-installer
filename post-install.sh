#!/usr/bin/env bash
#
# post-install.sh
#
# User-space setup, run after first login (not as root). Installs yay, the
# packages listed in packages.txt / packages-aur.txt, configures zram and
# sddm, and applies dotfiles via GNU Stow if present.
#
set -euo pipefail

GITHUB_USER="florflorin78"
REPO="arch-hyprland-installer"
BRANCH="main"

if [ "$EUID" -eq 0 ]; then
    echo "[ERROR] Do not run as root. Run as your regular user account."
    exit 1
fi

echo "== post-install: packages, dotfiles, session manager =="

# --- yay (AUR helper) -------------------------------------------------------
if ! command -v yay &>/dev/null; then
    echo "Installing yay..."
    sudo pacman -Sy --needed --noconfirm git base-devel
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
fi

# --- Repository ---------------------------------------------------------
if [ ! -d "$HOME/dotfiles" ]; then
    git clone "https://github.com/${GITHUB_USER}/${REPO}.git" "$HOME/dotfiles"
fi
cd "$HOME/dotfiles"
git checkout "$BRANCH"
git pull

# --- Packages ----------------------------------------------------------
if [ -s "packages.txt" ]; then
    echo "Installing pacman packages..."
    PAC_PKGS=$(grep -v '^[[:space:]]*#' packages.txt | grep -v '^[[:space:]]*$' || true)
    if [ -n "$PAC_PKGS" ]; then
        echo "$PAC_PKGS" | sudo pacman -S --needed --noconfirm -
    fi
fi

if [ -s "packages-aur.txt" ]; then
    echo "Installing AUR packages..."
    AUR_PKGS=$(grep -v '^[[:space:]]*#' packages-aur.txt | grep -v '^[[:space:]]*$' || true)
    if [ -n "$AUR_PKGS" ]; then
        echo "$AUR_PKGS" | yay -S --needed --noconfirm -
    else
        echo "No AUR packages to install."
    fi
fi

# --- zram (compressed swap, auto-scales with installed RAM) --------------
sudo tee /etc/systemd/zram-generator.conf > /dev/null <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF
sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0.service

# --- Dotfiles (applied only if present) ---------------------------------
if [ -d "$HOME/dotfiles/dotfiles" ] && [ -n "$(ls -A "$HOME/dotfiles/dotfiles" 2>/dev/null)" ]; then
    echo "Applying dotfiles via stow..."
    cd "$HOME/dotfiles/dotfiles"
    for dir in */; do
        stow -v -t "$HOME" "${dir%/}"
    done
else
    echo "No dotfiles to apply yet."
fi

# --- SDDM (Display Manager) -------------------------------------------
echo "Enabling SDDM display manager..."
sudo systemctl enable sddm

echo
echo "== post-install.sh complete =="
echo "Run 'reboot'."
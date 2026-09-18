#!/usr/bin/env bash
# post-install.sh
# Rulează ca USER normal (NU root), după primul boot.
set -euo pipefail

GITHUB_USER="florflorin78"
REPO="arch-hyprland-installer"
BRANCH="main"

if [ "$EUID" -eq 0 ]; then
    echo "[EROARE] Nu rula ca root. Rulează ca userul tău normal."
    exit 1
fi

echo "== Post-install: Hyprland + pachete + dotfiles =="

# --- yay (AUR helper) ---
if ! command -v yay &>/dev/null; then
    echo "Instalez yay..."
    sudo pacman -Sy --needed --noconfirm git base-devel
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
fi

# --- Clonăm repo-ul (pentru packages.txt, packages-aur.txt, dotfiles) ---
if [ ! -d "$HOME/dotfiles" ]; then
    git clone "https://github.com/${GITHUB_USER}/${REPO}.git" "$HOME/dotfiles"
fi
cd "$HOME/dotfiles"
git checkout "$BRANCH"
git pull

# --- Pachete pacman ---
echo "Instalez pachetele pacman..."
sudo pacman -S --needed --noconfirm - < packages.txt

# --- Pachete AUR ---
echo "Instalez pachetele AUR..."
yay -S --needed --noconfirm - < packages-aur.txt

# --- zram (swap comprimat) ---
sudo tee /etc/systemd/zram-generator.conf > /dev/null <<EOF
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
EOF
sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0.service

# --- Dotfiles cu stow (doar dacă există deja ceva de aplicat) ---
if [ -d "$HOME/dotfiles/dotfiles" ] && [ -n "$(ls -A "$HOME/dotfiles/dotfiles" 2>/dev/null)" ]; then
    echo "Leg dotfiles-urile cu stow..."
    cd "$HOME/dotfiles/dotfiles"
    for dir in */; do
        stow -v -t "$HOME" "${dir%/}"
    done
else
    echo "Niciun dotfile de aplicat încă — configurăm live după boot, apoi le adăugăm în repo."
fi

# --- greetd (login manager) ---
sudo mkdir -p /etc/greetd
sudo tee /etc/greetd/config.toml > /dev/null <<EOF
[terminal]
vt = 1

[default_session]
command = "tuigreet --cmd Hyprland"
user = "greeter"
EOF
sudo systemctl enable greetd

echo
echo "== post-install.sh complet =="
echo "Rulează 'reboot'. Boot instant (GRUB, timeout=0) -> splash Plymouth -> login -> Hyprland."

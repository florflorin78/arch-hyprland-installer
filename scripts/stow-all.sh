#!/usr/bin/env bash
# scripts/stow-all.sh — leagă dotfiles-urile din repo în $HOME cu GNU Stow.
# Rulează ca utilizator normal; poate fi rulat oricând după ce editezi repo-ul.
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../dotfiles"

PACHETE=(hypr waybar kitty wofi mako zsh starship nvim tmux gtk bin wallpapers)

chmod +x bin/.local/bin/*
mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/state/arch-hyprland" "$HOME/Pictures/wallpapers"

# --no-folding: se leagă fiecare fișier în parte, nu directoare întregi,
# ca aplicațiile care scriu în ~/.config/<app> să nu scrie în repo.
stow --no-folding -t "$HOME" -R "${PACHETE[@]}"
echo "[+] Dotfiles legate în $HOME"

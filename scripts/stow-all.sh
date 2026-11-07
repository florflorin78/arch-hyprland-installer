#!/usr/bin/env bash
# Symlink the dotfiles into $HOME with GNU Stow. Safe to re-run.
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../dotfiles"

PACKAGES=(hypr waybar kitty wofi mako zsh starship nvim tmux gtk fastfetch bin wallpapers)

chmod +x bin/.local/bin/*
mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/state/arch-hyprland" "$HOME/Pictures/wallpapers"

# --no-folding links files, not directories, so apps writing to ~/.config don't write into the repo
stow --no-folding -t "$HOME" -R "${PACKAGES[@]}"
echo "[+] Dotfiles linked into $HOME"

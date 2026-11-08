#!/usr/bin/env bash
# Apply the latest repo to an ALREADY INSTALLED system (no reinstall):
# pull, re-link dotfiles, install new packages, refresh system configs and the boot theme.
#   ~/arch-hyprland-installer/scripts/sync.sh
set -Eeuo pipefail

export LC_ALL=C.UTF-8
REPO=$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
# shellcheck disable=SC2034  # read by lib/common.sh
STEP_TOTAL=6
LOG_FILE="$HOME/arch-hyprland-sync.log"
FAILED_LOG="$HOME/arch-hyprland-failed-packages.log"
: > "$LOG_FILE"
# shellcheck source=../lib/common.sh
source "$REPO/lib/common.sh"
[[ $EUID -ne 0 ]] || die "Run as your normal user (it uses sudo when needed)."

sudo -v

step "Pull the latest version"
run_cmd "git pull" git -C "$REPO" pull --ff-only

step "Dotfiles"
run_cmd "Re-linking dotfiles" bash "$REPO/scripts/stow-all.sh"

step "Packages"
for list in 10-system 20-desktop 30-dev 35-ai 40-network 50-security; do
    mapfile -t pkgs < <(read_list "$REPO/packages/$list.txt")
    run_cmd "pacman: $list" sudo pacman -S --needed --noconfirm "${pkgs[@]}" || {
        for p in "${pkgs[@]}"; do
            run_cmd "  $p" sudo pacman -S --needed --noconfirm "$p" || echo "$p" >> "$FAILED_LOG"
        done
    }
done
if command -v yay >/dev/null; then
    mapfile -t aur < <(read_list "$REPO/packages/aur.txt")
    for p in "${aur[@]}"; do
        run_cmd "AUR: $p" yay -S --needed --noconfirm "$p" || echo "$p" >> "$FAILED_LOG"
    done
fi

d=$(basename "$(ls /usr/share/applications/zen*.desktop 2>/dev/null | head -1)" 2>/dev/null || true)
if [[ -n $d && $d != . ]]; then
    run_cmd "Zen as default browser" xdg-settings set default-web-browser "$d" || true
fi

step "System configs"
copy_etc() {
    # keep the greetd config made at install time (it holds the autologin choice)
    sudo rsync -a --exclude 'greetd/config.toml' "$REPO/system/etc/" /etc/
    sudo systemctl daemon-reload
    sudo systemctl enable --now libvirtd.socket || true
    sudo systemctl restart tlp || true
}
run_cmd "Copying /etc files, reloading services" copy_etc

step "Boot theme (Plymouth + GRUB)"
boot_theme() {
    local cmdline="quiet splash loglevel=3 rd.udev.log_level=3 udev.log_level=3 systemd.show_status=false rd.systemd.show_status=false vt.global_cursor_default=0 nowatchdog mem_sleep_default=deep"
    sudo cp -r "$REPO/system/plymouth/hackerlinux" /usr/share/plymouth/themes/
    sudo cp -r "$REPO/system/grub-theme/." /boot/grub/themes/hackerlinux/
    sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$cmdline\"|" /etc/default/grub
    sudo plymouth-set-default-theme hackerlinux
    sudo mkinitcpio -P
    sudo grub-mkconfig -o /boot/grub/grub.cfg
}
run_cmd "Updating splash, initramfs and GRUB" boot_theme

step "Done"
hyprctl reload >/dev/null 2>&1 || true
[[ -s $FAILED_LOG ]] && warn "Some packages failed, see $FAILED_LOG"
box "Synced" "Dotfiles, packages, configs and boot theme are up to date." \
    "Log out and back in (or reboot) to see everything."

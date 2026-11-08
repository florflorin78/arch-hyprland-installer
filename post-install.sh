#!/usr/bin/env bash
# Step 3 — runs once at first login (started by ~/.local/bin/first-run). Safe to re-run.
set -Eeuo pipefail

export LC_ALL=C.UTF-8
SCRIPT_DIR=$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
STEP_TOTAL=7
LOG_FILE="$HOME/arch-hyprland-post-install.log"
FAILED_LOG="$HOME/arch-hyprland-failed-aur.log"
: > "$LOG_FILE"
: > "$FAILED_LOG"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

[[ $EUID -ne 0 ]] || die "Run as a normal user, not root."

clear
banner
check_internet

# keep sudo alive while AUR packages build
sudo -v
( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
KEEPALIVE=$!
trap 'kill "$KEEPALIVE" 2>/dev/null; printf "\e[0m\e[?25h"' EXIT

# ================================================================ 1. git
step "Git identity"
if ! git config --file "$HOME/.gitconfig" user.name >/dev/null 2>&1; then
    ask GIT_NAME  "Git name" ""
    ask GIT_EMAIL "Git email" ""
    [[ -n $GIT_NAME ]]  && git config --file "$HOME/.gitconfig" user.name  "$GIT_NAME"
    [[ -n $GIT_EMAIL ]] && git config --file "$HOME/.gitconfig" user.email "$GIT_EMAIL"
fi
git -C "$SCRIPT_DIR" fetch --unshallow 2>/dev/null || true

# ================================================================ 2. yay
step "yay"
instaleaza_yay() {
    local tmp
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
}
if command -v yay >/dev/null; then ok "yay already installed"; else run_cmd "Building yay-bin" instaleaza_yay; fi

# ================================================================ 3. AUR (Zen Browser etc.)
step "AUR packages"
mapfile -t AUR_PKGS < <(read_list "$SCRIPT_DIR/packages/aur.txt")
for p in "${AUR_PKGS[@]}"; do
    run_cmd "AUR: $p" yay -S --needed --noconfirm "$p" || {
        warn "AUR failed: $p"; echo "$p" >> "$FAILED_LOG"
    }
done

# Zen as default browser if installed, else Firefox
setare_browser() {
    local d
    d=$(basename "$(ls /usr/share/applications/zen*.desktop 2>/dev/null | head -1)" 2>/dev/null || true)
    [[ -n $d && $d != . ]] || d=firefox.desktop
    xdg-settings set default-web-browser "$d"
    xdg-mime default "$d" x-scheme-handler/http x-scheme-handler/https text/html
    echo "default browser: $d"
}
run_cmd "Setting default browser" setare_browser || true

# ================================================================ 4. Claude Code
step "Claude Code"
# Official native installer (~/.local/bin/claude, self-updating)
install_claude() { curl -fsSL https://claude.ai/install.sh | bash; }
if command -v claude >/dev/null || [[ -x $HOME/.local/bin/claude ]]; then
    ok "Claude Code already installed"
else
    run_cmd "Installing Claude Code" install_claude || warn "Claude Code failed; run: curl -fsSL https://claude.ai/install.sh | bash"
fi

# ================================================================ 5. limbaje / unelte
step "Rust, neovim, tldr"
setup_unelte() {
    command -v rustup >/dev/null && rustup default stable || echo "rustup missing"
    nvim --headless "+Lazy! sync" +qa || echo "Lazy sync failed (run :Lazy sync manually)"
    tldr --update || true
    xdg-user-dirs-update || true
}
run_cmd "Rust stable, neovim plugins, tldr" setup_unelte || true

# ================================================================ 6. SSH
step "SSH key"
if [[ ! -f $HOME/.ssh/id_ed25519 ]] && confirm "Generate an ed25519 SSH key (for GitHub)?"; then
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$(git config --file "$HOME/.gitconfig" user.email || echo "$USER@$(cat /proc/sys/kernel/hostname)")" -f "$HOME/.ssh/id_ed25519"
    info "Public key (add it at GitHub > Settings > SSH keys):"
    cat "$HOME/.ssh/id_ed25519.pub"
else
    ok "Skipped"
fi

# ================================================================ 7. gata
step "Done"
mkdir -p "$HOME/.local/state/arch-hyprland"
touch "$HOME/.local/state/arch-hyprland/first-run-done"
[[ -s $FAILED_LOG ]] && warn "AUR packages failed: $(tr '\n' ' ' < "$FAILED_LOG")"

echo
box "All set" \
    "SUPER + B        browser (Zen)" \
    "SUPER + X        Claude Code" \
    "SUPER + F1       all shortcuts" \
    "Run 'claude' once to sign in."
echo
read -r -p " Press Enter to close..." _

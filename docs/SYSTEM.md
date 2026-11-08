# How this system is put together

## Where things live
| Path | What |
|---|---|
| `~/arch-hyprland-installer` | this repo: installer, dotfiles, package lists, docs |
| `~/.config/hypr/hyprland.lua` | Hyprland: keybinds, look, autostart (Lua) |
| `~/.config/hypr/hyprlock.conf` / `hypridle.conf` | lock screen / auto-lock and sleep |
| `~/.config/waybar/` | top bar |
| `~/.config/kitty/kitty.conf` | terminal |
| `~/.config/zsh/.zshrc` | shell aliases and settings |
| `~/.config/starship.toml` | prompt (user@host:path$) |
| `~/.config/nvim/init.lua` | Neovim |
| `~/.local/bin/` | small helper scripts (help, apps-menu, screenshot, ...) |
| `/etc/tlp.d/10-x270.conf` | battery settings |

The files in `~/.config` are links to `~/arch-hyprland-installer/dotfiles` (GNU Stow).
Edit them, then save the change to GitHub:

```
cd ~/arch-hyprland-installer
git add -A && git commit -m "my change" && git push
```

## Useful
- Reload Hyprland after editing its config: **SUPER + SHIFT + R**; errors: `hyprctl configerrors`
- Update everything: `sudo pacman -Syu && yay -Sua`
- Re-link dotfiles after `git pull`: `~/arch-hyprland-installer/scripts/stow-all.sh`
- Change the portrait: replace `assets/avatar.jpg`, run `python3 assets/generate_wallpaper.py`
- Battery report: `sudo tlp-stat -b`; heavy builds on battery: `sudo tlp ac`

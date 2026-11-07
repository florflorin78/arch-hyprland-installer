# arch-hyprland-installer

Arch Linux + Hyprland for the ThinkPad X270 (i5-6200U, HD 520): dark neon, keyboard-first,
long battery life, with dev, networking and security toolboxes.

## Install (from the Arch ISO, UEFI)

```bash
# connect to the internet first (Wi-Fi: iwctl), then:
curl -fsSL https://raw.githubusercontent.com/florflorin78/arch-hyprland-installer/main/bootstrap.sh | bash
```

It asks for disk, hostname, username, timezone, LUKS and autologin, then your passwords. The rest is automatic.
The first login in Hyprland opens a terminal that finishes setup (AUR incl. Zen, Claude Code, neovim, git, SSH).

Test in VirtualBox first: Settings → System → Enable EFI, 4 GB RAM, 30 GB disk.

## Layout

| Path | Role |
|---|---|
| `bootstrap.sh` | clones the repo, starts the installer |
| `install-base.sh` | live ISO: disk, partitions, LUKS, pacstrap, fstab |
| `chroot-config.sh` | chroot: packages, GRUB, Plymouth, greetd, services, dotfiles |
| `post-install.sh` | first login: yay, AUR, Claude Code, neovim, git, SSH |
| `packages/*.txt` | package lists, one name per line |
| `dotfiles/` | GNU Stow packages → `~` (`scripts/stow-all.sh` re-applies) |
| `system/etc/` | copied to `/etc` (TLP, sysctl, zram, logind, greetd) |
| `assets/generate_wallpaper.py` | regenerates wallpaper, GRUB background, Plymouth logo |

## Shortcuts (SUPER = Windows key). Full searchable list: SUPER + F1

| Key | Action |
|---|---|
| `SUPER+Enter` | terminal (kitty) |
| `SUPER+D` / `SUPER+SHIFT+D` | app launcher / run command |
| `SUPER+B` / `SUPER+SHIFT+B` / `SUPER+CTRL+B` | Zen / qutebrowser / Firefox |
| `SUPER+X` / `SUPER+SHIFT+X` | Claude Code / claude.ai |
| `SUPER+E` / `SUPER+C` | yazi / VS Code |
| `SUPER+N` / `A` / `Y` | network / audio / bluetooth TUIs |
| `SUPER+V` | clipboard history |
| `SUPER+M` | mouse from keyboard (wl-kbptr) |
| `SUPER+Q` | close window |
| `SUPER+F` / `SUPER+Space` | fullscreen / floating |
| `SUPER+h j k l` (or arrows) | focus |
| `SUPER+SHIFT+h j k l` | move window |
| `SUPER+CTRL+h j k l` | resize (hold) |
| `SUPER+1..0` / `SUPER+SHIFT+1..0` | workspace / move window |
| `SUPER+Tab`, `SUPER+[` `]` | next / previous workspace |
| `ALT+Tab` | next window |
| `SUPER+S` / `SUPER+SHIFT+S` | scratchpad / send to scratchpad |
| `Print` / `SUPER+Print` | screenshot full / region |
| `SUPER+SHIFT+Print` | screenshot + annotate (satty) |
| `SUPER+CTRL+Print` | screen recording on/off |
| `SUPER+ALT+Print` | OCR a region to the clipboard |
| `SUPER+W` / `SUPER+SHIFT+W` | next wallpaper / live matrix rain on-off |
| `SUPER+=` | calculator (qalc) |
| `SUPER+CTRL+D` | do not disturb |
| `SUPER+CTRL+Enter` | floating terminal |
| `SUPER+Esc` | lock |
| `SUPER+SHIFT+E` (or Power button) | power menu |
| `SUPER+F10` | eco mode |
| `SUPER+CTRL+N` / `P` | night light / color picker |
| `SUPER+CTRL+M` / `R` | dismiss / restore notifications |
| `Alt+Shift` | switch layout us ↔ ro |
| `SUPER+SHIFT+R` | reload Hyprland config |
| Fn keys | volume, mic, brightness (with OSD) |

kitty: `Ctrl+Shift+T` new tab, `Ctrl+Shift+←/→` switch tabs, `Alt+1..5` jump to tab,
`Ctrl+Shift+\` / `Ctrl+Shift+-` splits, `Ctrl+Alt+h j k l` move between splits. tmux prefix: `Ctrl+a`.

## Look

Matrix-terminal style everywhere: installer (logo, system panel, `[ OK ]` log lines, progress bar),
boot (Plymouth: falling glyphs, boot log, LUKS prompt), login (tuigreet), desktop (green palette),
prompt (`user@host:~/path$`) and a fastfetch intro once per login. A live matrix-rain wallpaper
(kitty panel + cmatrix) runs on AC power only and stops on battery or eco mode.
`python3 assets/generate_wallpaper.py` regenerates wallpapers, GRUB background and Plymouth images.

## Bar

Workspaces, window title, media (MPRIS), pending updates (click to update), stay-awake toggle,
do-not-disturb, CPU, RAM, disk, temperature, brightness, volume, network, bluetooth, battery, layout, power.

## Boot and login

GRUB menu is hidden (hold SHIFT to show). Boot goes: LUKS password (Plymouth) → login (tuigreet),
or straight to the desktop if you chose autologin (only offered with LUKS; the lock screen stays).
CapsLock is not remapped to Esc, because Esc clears the hyprlock password field.

## Battery

Config: `system/etc/tlp.d/10-x270.conf`, plus thermald, zram, nowatchdog, hypridle dimming and
no blur/shadows on battery. `SUPER+F10` also disables animations and drops brightness to 30%.

- Heavy builds on battery: `sudo tlp ac`.
- Check: `sudo tlp-stat -s -b`.
- BIOS: Config → Power → Sleep State → Linux (S3).
- Charge cap at 80% is in the TLP file, commented out.

## Troubleshooting

- Hyprland config errors: `hyprctl configerrors` (config is Lua, Hyprland ≥ 0.55).
- Failed packages: `/var/log/arch-hyprland-failed-packages.log`, `~/arch-hyprland-failed-aur.log`.
- Re-apply dotfiles: `~/arch-hyprland-installer/scripts/stow-all.sh`.
- Claude Desktop only exists for Debian/Ubuntu; on Arch use Claude Code (`claude`).
- Use the security tools only on systems you are authorized to test.

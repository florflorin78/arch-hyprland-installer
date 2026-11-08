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

## Update an installed system (no reinstall)

```bash
cd ~/arch-hyprland-installer && git pull && scripts/sync.sh
```
Pulls the repo, re-links dotfiles, installs new packages, refreshes /etc configs and the boot theme.

## Layout

| Path | Role |
|---|---|
| `bootstrap.sh` | clones the repo, starts the installer |
| `install-base.sh` | live ISO: disk, partitions, LUKS, pacstrap, fstab |
| `chroot-config.sh` | chroot: packages, GRUB, Plymouth, greetd, services, dotfiles |
| `post-install.sh` | first login: yay, AUR, Claude Code, neovim, git, SSH |
| `packages/*.txt` | package lists by purpose: system, desktop, dev, ai, network, security, aur |
| `dotfiles/` | GNU Stow packages → `~` (`scripts/stow-all.sh` re-applies) |
| `system/etc/` | copied to `/etc` (TLP, sysctl, zram, logind, greetd) |
| `assets/generate_wallpaper.py` | regenerates wallpaper, GRUB background, Plymouth logo |

## Shortcuts, apps and guides

On the laptop: **SUPER + H** = all shortcuts (searchable), **SUPER + A** = apps by category with a
one-line description, **SUPER + F1** = help center (shortcuts, apps guide, Linux basics, system map).
Windows move with the **arrow keys**: SUPER+arrows focus, SUPER+SHIFT+arrows move, SUPER+CTRL+arrows resize.

The same guides are in [`docs/`](docs): [KEYBINDS](docs/KEYBINDS.md) · [APPS](docs/APPS.md) ·
[LINUX-BASICS](docs/LINUX-BASICS.md) · [SYSTEM](docs/SYSTEM.md).
The app list comes from `dotfiles/guide/.local/share/arch-hyprland/apps.tsv`
(category, name, kind, command, description, examples), so adding an app there adds it to the menu.

## Look

Subdued cyberpunk / retro-futurist: dark navy, warm yellow accent, teal secondary, soft magenta only
for errors; scanlines, HUD corners, a perspective grid. Your portrait (`assets/avatar.jpg`) is
digitized into characters only (density-sorted glyphs, teal -> yellow), cropped and centred on the
face, and used in: the lock screen, the boot splash (with a HUD ring), fastfetch (coloured ASCII)
and the installer banner (plain ASCII). Wallpapers: night-city skyline (default), grid, clean.
Replace `assets/avatar.jpg` and run `python3 assets/generate_wallpaper.py` to regenerate everything.

`SUPER+SHIFT+W` turns on a live data-rain wallpaper (kitty panel + cmatrix). It is off by default
because it redraws the whole screen; it only runs on AC power.

### Boot without the Lenovo logo

The Lenovo logo comes from the firmware; Linux cannot hide it. What helps:
- BIOS (F1): Config → Network → disable UEFI IPv4 / IPv6 Network Stack (no PXE attempt);
  Startup → Boot → put the SSD first. This makes the logo flash by quickly.
- To replace it with your own: Lenovo's X270 BIOS update package can flash a custom startup logo
  (`assets/bios-logo.gif`, renamed as its README asks). Check the size/format limits in that
  README first; flashing firmware is at your own risk.

After the disk password the splash stays on screen until Hyprland draws (no console text):
`plymouth quit --retain-splash`, `systemd.show_status=false`, Hyprland background = theme navy.
Every few seconds the splash glitches (logo jitter, magenta ghost, bars); the first terminal after
login plays a short "decode" of the ASCII portrait (`~/.local/bin/intro`) before fastfetch.

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
- Not in the official repos (installed from AUR at first login): ffuf, wfuzz, python-impacket. FRR: `yay -S frr` (long compile).
- BIOS: disable Config → Network → UEFI IPv4/IPv6 Network Stack to skip the PXE attempt at boot.
- Failed packages: `/var/log/arch-hyprland-failed-packages.log`, `~/arch-hyprland-failed-aur.log`.
- Re-apply dotfiles: `~/arch-hyprland-installer/scripts/stow-all.sh`.
- Claude Desktop only exists for Debian/Ubuntu; on Arch use Claude Code (`claude`).
- Use the security tools only on systems you are authorized to test.

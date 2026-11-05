# arch-hyprland-x270

Arch Linux + Hyprland pentru ThinkPad X270 (i5-6200U, HD 520, 8–32 GB RAM): dark neon, fără mouse,
autonomie maximă, cu toolbox de dezvoltare, networking și security.

## Instalare (din Arch ISO, UEFI)

```bash
# 1. conectează-te la internet (Wi-Fi: iwctl), apoi:
curl -fsSL https://raw.githubusercontent.com/florflorin78/arch-hyprland-x270/main/bootstrap.sh | bash
```

Installer-ul te întreabă: disc, hostname, utilizator, fus orar, LUKS (da/nu), parole. Restul e automat.
La **primul login** în Hyprland se deschide un terminal care termină setup-ul (AUR, neovim, git, SSH).

### Test în VirtualBox înainte de laptop
Settings → System → **Enable EFI**, minim 4 GB RAM, 30 GB disc, 3D acceleration pornit.
(În VM nu vei vedea autonomia bateriei; TLP și resturile tot se aplică.)

## Structura

| Fișier | Rol |
|---|---|
| `bootstrap.sh` | clonează repo-ul și pornește installer-ul |
| `install-base.sh` | live ISO: disc, partiții, LUKS, pacstrap, fstab |
| `chroot-config.sh` | în chroot: pachete, GRUB+temă, Plymouth, greetd, servicii, dotfiles |
| `post-install.sh` | primul login: yay, AUR, neovim, git, SSH |
| `packages/*.txt` | liste de pachete (adaugi un nume pe linie) |
| `dotfiles/` | pachete GNU Stow → `~` (`scripts/stow-all.sh` le reaplică) |
| `system/etc/` | copiat în `/etc` (TLP, sysctl, zram, logind, greetd...) |
| `assets/generate_wallpaper.py` | regenerează wallpaper + fundal GRUB + logo Plymouth |

## Shortcut-uri (SUPER = tasta Windows). Lista completă și căutabilă: **SUPER + F1**

| Tastă | Acțiune |
|---|---|
| `SUPER+Enter` | terminal (kitty) |
| `SUPER+D` / `SUPER+SHIFT+D` | launcher aplicații / rulează comandă |
| `SUPER+B` / `SUPER+SHIFT+B` | Firefox / qutebrowser (browser din tastatură) |
| `SUPER+E` | file manager yazi |
| `SUPER+C` | VS Code |
| `SUPER+N` / `A` / `Y` | rețea (nmtui) / mixer audio / bluetooth |
| `SUPER+V` | istoric clipboard |
| `SUPER+M` | mouse din tastatură (wl-kbptr, hint-uri pe ecran) |
| `SUPER+Q` | închide fereastra |
| `SUPER+F` / `SUPER+Space` | fullscreen / plutitor |
| `SUPER+h j k l` (sau săgeți) | focus între ferestre |
| `SUPER+SHIFT+h j k l` | mută fereastra |
| `SUPER+CTRL+h j k l` | redimensionează (ține apăsat) |
| `SUPER+1..0` / `SUPER+SHIFT+1..0` | workspace / mută fereastra pe workspace |
| `SUPER+Tab`, `SUPER+[` `]` | workspace următor / anterior |
| `ALT+Tab` | următoarea fereastră |
| `SUPER+S` / `SUPER+SHIFT+S` | scratchpad / trimite în scratchpad |
| `Print` / `SUPER+Print` | screenshot ecran / regiune |
| `SUPER+Esc` | blochează ecranul |
| `SUPER+SHIFT+E` (sau butonul Power) | meniu oprire / repornire / suspend / logout |
| `SUPER+F10` | **eco mode** (baterie maximă) |
| `Alt+Shift` | schimbă layout tastatură `us` ↔ `ro` |
| `SUPER+SHIFT+R` | reîncarcă config Hyprland |
| Taste Fn | volum, mute, microfon, luminozitate (cu notificare) |

În kitty: `Ctrl+Shift+T` tab nou, `Ctrl+Shift+←/→` între taburi, `Alt+1..5` salt la tab,
`Ctrl+Shift+\` / `Ctrl+Shift+-` split vertical/orizontal, `Ctrl+Alt+h j k l` între splituri,
`Ctrl+Shift+E` deschide linkuri cu hint-uri. În tmux: prefix `Ctrl+a`.

## Baterie

Setările sunt în `system/etc/tlp.d/10-x270.conf` (CPU powersave, boost oprit pe baterie, plafon 60%,
PCIe ASPM, USB/Wi-Fi/audio power save, SATA min_power) plus `thermald`, zram, `nowatchdog`,
`vm.dirty_writeback`, luminozitate redusă automat de hypridle și blur/umbre oprite pe baterie.
`SUPER+F10` oprește și animațiile și coboară luminozitatea la 30%.

- Compilări grele pe baterie: `sudo tlp ac` (profil de priză temporar).
- Verificare: `sudo tlp-stat -s -b`, `sudo powertop` (doar citire).
- **BIOS:** Config → Power → Sleep State → **Linux** (S3). Altfel suspend-ul consumă mult.
- Cea mai mare scădere de consum după asta vine de la un SSD/NVMe și luminozitatea ecranului.
- Limitarea încărcării la 80% (viață mai lungă a bateriei) e în fișier, comentată.

## Dacă ceva nu merge

- Erori de config Hyprland: `hyprctl configerrors`. Config-ul e în **Lua** (`hyprland.lua`), cum cere
  Hyprland ≥ 0.55; sintaxa se mai schimbă între versiuni: https://wiki.hypr.land
- Pachete care nu s-au putut instala: `/var/log/arch-hyprland-failed-packages.log` și
  `~/arch-hyprland-failed-aur.log`.
- Reaplică dotfiles: `~/arch-hyprland-x270/scripts/stow-all.sh`.
- Security tools: folosește-le doar pe sisteme și rețele pe care ai autorizare (laborator propriu, CTF, contract).

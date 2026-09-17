# arch-hyprland-x270

Installer pentru Arch Linux + Hyprland (minimal, funcțional) pe ThinkPad X270 —
merge pe orice tip de stocare (HDD, SATA SSD, sau NVMe M.2), cu boot instant
(GRUB, fără meniu vizibil) și splash Plymouth în loc de consolă text.

## Filozofia repo-ului: instalezi, apoi personalizezi, apoi salvezi

1. **Installerul** (`install-base.sh` + `chroot-config.sh` + `post-install.sh`) te duce
   la un Hyprland minimal, funcțional, FĂRĂ opinii impuse — fără keybind-uri sau teme
   deja alese pentru tine.
2. **Personalizezi live** — după ce ai boot-at, configurezi aspectul, keybind-urile,
   aplicațiile, exact cum vrei tu.
3. **Salvezi în `dotfiles/`** — ce ai configurat live se pune în `dotfiles/`, faci commit,
   push. La următoarea reinstalare, `post-install.sh` aplică automat exact configurările
   salvate.

## Instalare (de fiecare dată, de la zero)

1. Boot pe Arch ISO (USB), conectezi la net (`iwctl` dacă e wifi).
2. Rulezi:
   ```bash curl -fsSL https://raw.githubusercontent.com/florflorin78/arch-hyprland-x270/main/install-base.sh | bash
   ```
3. Scriptul: detectează automat tipul discului (HDD/SSD) și tipul de partiție
   (NVMe vs SATA), te întreabă ce disc, cere confirmare explicită înainte de a șterge,
   partiționează, instalează sistemul de bază, GRUB (boot instant) + Plymouth
   (splash grafic), apoi intră singur în chroot și configurează tot.
4. `umount -R /mnt && reboot`.
5. Boot-ul acum e instant — vezi doar splash-ul Plymouth, apoi login (consolă TTY, fără GUI încă).
6. Login cu userul creat, apoi:
   ```bash curl -fsSL https://raw.githubusercontent.com/florflorin78/arch-hyprland-x270/main/post-install.sh | bash
   ```
7. `reboot`. Ajungi la greetd -> Hyprland, la setările lui implicite (fără dotfiles încă,
   dacă e prima rulare).

## Structură

```
install-base.sh        -> partiționare (universal HDD/SSD/NVMe) + pacstrap + cheamă chroot-config.sh
chroot-config.sh        -> user, GRUB (timeout=0), Plymouth, TRIM dacă SSD, NetworkManager
post-install.sh         -> yay, pachete minime Hyprland, zram, greetd, aplică dotfiles/ (dacă există)
packages.txt            -> pachete pacman (set minim)
packages-aur.txt        -> pachete AUR (gol acum)
plymouth-theme/         -> tema splash-ului de boot (editabilă)
dotfiles/                -> gol acum — aici punem configurările după ce le stabilim live
```

## Cum funcționează detectarea automată de disc

- **Tip disc (HDD vs SSD):** citește `/sys/block/<disc>/queue/rotational`. 
  Dacă e SSD, activează automat `fstrim.timer` (TRIM periodic); pe HDD nu.
- **Nume partiții:** 
  NVMe (`nvme0n1`) primește partiții `nvme0n1p1`/`nvme0n1p2` (cu "p"),
  SATA (`sda`) primește `sda1`/`sda2` (fără "p") — scriptul alege automat formatul corect.

## Boot:

1. Power on -> GRUB pornește automat Arch, fără meniu vizibil  (`GRUB_TIMEOUT=0`, `GRUB_TIMEOUT_STYLE=hidden`). 
Ține Shift apăsat la pornire dacă vreodată vrei să vezi meniul.
2. Splash Plymouth (`plymouth-theme/`) — animație minimalistă, cu tranziție fluidă (KMS timpuriu, fără flicker), în loc de text derulant.
3. greetd (tuigreet) -> alegi userul -> Hyprland pornește.

## Următorul pas, TBD


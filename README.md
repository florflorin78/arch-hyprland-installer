# arch-install-hyprland

Automated Arch Linux + Hyprland installer. Hardware-agnostic: storage type
(HDD, SATA SSD, or NVMe M.2), CPU vendor (Intel/AMD microcode), and GPU vendor
(Intel/AMD/Nvidia driver) are all detected automatically at install time, with
instant boot via GRUB and a Plymouth splash screen in place of a text console.

Originally developed for a ThinkPad X270 (Intel i5-6200U, Intel HD 520), the
installer runs unmodified on any UEFI x86_64 system.

## Design principles

1. **Installer stays opinion-free.** `install-base.sh`, `chroot-config.sh`, and
   `post-install.sh` produce a minimal, working Hyprland session — no
   pre-selected keybindings or themes.
2. **Configuration happens post-install**, on the running system.
3. **Finalized configuration is committed to `dotfiles/`**, so subsequent
   reinstalls apply it automatically via `post-install.sh`.

## Installation

### 1. Boot the Arch ISO

If the system boots in Legacy/CSM mode instead of UEFI, enter firmware setup
(F1 on ThinkPad), set Boot Mode to `UEFI Only` under Startup, disable CSM if
present separately, save, and reboot. Verify with `ls /sys/firmware/efi`.

### 2. Connect to the network

Ethernet is automatic. For Wi-Fi:

```bash
iwctl
```

```
device list
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "SSID"
exit
```

SSIDs containing spaces must be quoted as shown above.

Verify connectivity:

```bash
ping -c1 archlinux.org
```

### 3. Run the base installer

```bash
curl -fsSL https://raw.githubusercontent.com/florflorin78/arch-install-hyprland/main/install-base.sh -o install-base.sh
bash install-base.sh
```

Download to a file first, then execute — piping directly into `bash`
(`curl ... | bash`) breaks interactive `read` prompts, since stdin is consumed
by the pipe rather than the terminal.

The script detects disk type (HDD/SSD) and partition naming convention
(NVMe vs. SATA) automatically, prompts for the target disk, requires explicit
confirmation before wiping it, and prompts for hostname and username.

### 4. Reboot

```bash
umount -R /mnt
reboot
```

### 5. Post-install (after first login)

```bash
curl -fsSL https://raw.githubusercontent.com/florflorin78/arch-install-hyprland/main/post-install.sh -o post-install.sh
bash post-install.sh
```

### 6. Final reboot

```bash
reboot
```

Result: instant boot → Plymouth splash → greetd → Hyprland.

## Repository structure

```
install-base.sh       Partitioning (HDD/SSD/NVMe-agnostic), pacstrap, invokes chroot-config.sh
chroot-config.sh       User setup, GRUB (instant boot), Plymouth, TRIM, NetworkManager
post-install.sh        yay, package installation, zram, greetd, dotfiles application
packages.txt           pacman package list
packages-aur.txt        AUR package list
plymouth-theme/         Boot splash theme
dotfiles/                Post-install configuration, managed with GNU Stow
```

## Script reference

### install-base.sh

| Function | Purpose |
|---|---|
| `check_internet` | Verifies connectivity before proceeding |
| `check_uefi` | Aborts if not booted in UEFI mode (required for GRUB EFI target) |
| `list_disks` | Displays available block devices |
| `detect_disk_type` | Reads `/sys/block/<disk>/queue/rotational` to classify HDD vs. SSD |
| `detect_microcode_package` | Reads `/proc/cpuinfo` to select `intel-ucode` or `amd-ucode` |
| `detect_gpu_vendor` | Parses `lspci` output to identify Intel/AMD/Nvidia GPU |
| `partition_name` | Resolves correct partition suffix for NVMe (`p1`) vs. SATA (`1`) |
| `partition_and_format` | Creates GPT layout: 512MB FAT32 EFI partition + ext4 root |
| `install_base_system` | `pacstrap` with base packages and detected microcode, generates fstab |

### chroot-config.sh

| Function | Purpose |
|---|---|
| `configure_locale` | Prompts for timezone, generates locale, sets console keymap |
| `configure_hostname` | `/etc/hostname` and `/etc/hosts` |
| `create_user` | User creation with `wheel` group membership |
| `configure_sudo` | Enables `sudo` for the `wheel` group |
| `install_grub` | GRUB installation, UEFI target |
| `configure_instant_boot` | `GRUB_TIMEOUT=0`, hidden menu |
| `install_gpu_driver` | Installs mesa + vendor-specific driver (Intel/AMD/Nvidia) based on detected hardware |
| `install_plymouth` | Boot splash: early KMS module load (vendor-specific) to avoid resolution-switch flicker |
| `optimize_boot_time` | Reduced kernel log verbosity, disabled `NetworkManager-wait-online` |
| `configure_trim` | Enables `fstrim.timer` conditionally on SSD |
| `enable_network_manager` | Enables NetworkManager service |

### post-install.sh

Installs `yay`, applies `packages.txt` / `packages-aur.txt`, configures zram
(compressed swap), configures `greetd` to launch Hyprland, and applies
`dotfiles/` via `stow` if present.

## Modification reference

| To change... | Edit... |
|---|---|
| Installed packages | `packages.txt` / `packages-aur.txt` |
| Timezone / locale | `chroot-config.sh` → `configure_locale` |
| Boot splash appearance | `plymouth-theme/arch-install-hyprland.script` |
| GRUB timeout behavior | `chroot-config.sh` → `configure_instant_boot` |
| Partition layout | `install-base.sh` → `partition_and_format` |
| Default shell | `chroot-config.sh` → `create_user` |
| Session manager | `post-install.sh`, greetd section |
| Hyprland configuration | `dotfiles/hypr/` (populated post-configuration) |

## Known issues and resolutions

| Symptom | Cause | Resolution |
|---|---|---|
| `read` doesn't wait for input; script exits silently | `curl \| bash` consumes stdin via the pipe | Download with `-o`, then execute the file directly |
| `iwctl` fails to connect to an SSID with spaces | Missing quoting | `station wlan0 connect "SSID With Spaces"` |
| UEFI check fails | Firmware in Legacy/CSM mode | Set Boot Mode to `UEFI Only` in firmware setup |
| `git push` rejected (non-fast-forward) | Local and remote branches diverged | `git pull origin <branch>`, resolve, then push |
| `git pull` requires reconciliation strategy | Modern git requires explicit merge/rebase config | `git config pull.rebase false`, then pull again |
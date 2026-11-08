# Linux basics (what you need every day)

Every command has help: `tldr <cmd>` (short examples), `<cmd> --help`, `man <cmd>` (full manual, `q` to quit).
In the terminal: `Tab` completes, `Ctrl+R` searches history, `Ctrl+C` stops a command, `Ctrl+L` clears.

## Moving around files
| Command | What it does |
|---|---|
| `pwd` | where am I |
| `ls -la` / `ll` | list files (with hidden ones) |
| `cd folder` / `cd ..` / `cd ~` | enter folder / go up / go home |
| `z name` | jump to a folder you visited before (zoxide) |
| `mkdir -p a/b` | create folders |
| `cp file dest` / `mv file dest` | copy / move or rename |
| `rm file` / `rm -r folder` | delete (no recycle bin!) |
| `cat file` / `bat file` | show a file (bat = with colors) |
| `nvim file` | edit a file |
| `find . -name "*.py"` / `fd py` | find files |
| `grep -r text .` / `rg text` | search inside files |

## Permissions and admin
| Command | What it does |
|---|---|
| `sudo <cmd>` | run as administrator (asks your password) |
| `chmod +x script.sh` | make a file executable |
| `chown user:user file` | change owner |
| `ls -l` | `rwx` = read / write / execute for owner, group, others |

## Installing software
| Command | What it does |
|---|---|
| `sudo pacman -Syu` | update the whole system (do it weekly) |
| `pacman -Ss name` | search official packages |
| `sudo pacman -S name` | install |
| `sudo pacman -Rns name` | uninstall (with unused dependencies) |
| `yay -S name` | install from AUR (community packages) |
| `pacman -Qe` | what you installed explicitly |

## Services and logs
| Command | What it does |
|---|---|
| `systemctl status name` | is a service running, last log lines |
| `sudo systemctl start/stop/restart name` | control it now |
| `sudo systemctl enable --now name` | start it now and at every boot |
| `journalctl -b -p err` | errors since boot |
| `journalctl -u name -f` | follow a service's log live |

## Processes and resources
| Command | What it does |
|---|---|
| `btop` | live CPU/RAM/processes (SUPER+SHIFT+T) |
| `ps aux \| grep name` | find a process |
| `kill PID` / `pkill name` | stop a process |
| `free -h` / `duf` / `ncdu ~` | RAM / disks / what fills the disk |

## Network
| Command | What it does |
|---|---|
| `ip a` | interfaces and IP addresses |
| `ip r` | routes (default gateway) |
| `nmcli device wifi list` / `nmtui` | Wi-Fi |
| `ping -c 4 1.1.1.1` | is the internet reachable |
| `ss -tulpn` | which ports are open and which program owns them |
| `dig example.com` | DNS lookup |
| `ssh user@host` | remote shell |

## Git in 6 commands
`git clone URL` · `git status` · `git add .` · `git commit -m "msg"` · `git push` · `git pull`
(or `lazygit` for a visual interface)

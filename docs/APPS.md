# Apps on this system

Open the menu with **SUPER + A** (by category) or **SUPER + D** (search by name).
`gui` = window app, `tui` = full-screen terminal app, `cli` = command you type in the terminal.
For any command, `tldr <command>` shows short examples and `man <command>` the full manual.


## Code & IDE

### VS Code  ·  `code`  ·  gui
Full IDE: editor, debugger, git, extensions, Jupyter notebooks inside the editor.

- `code .`  (open the current folder)
- `Ctrl+Shift+P`  command palette (search any action)
- `Ctrl+backtick`  built-in terminal
- `Install extensions: Python, Jupyter, C/C++, Go, Rust`

### Neovim  ·  `nvim`  ·  tui
Fast keyboard-only editor in the terminal, with code completion (LSP).

- `nvim app.py`
- `i = type, Esc = stop typing, :w = save, :q = quit`
- `Space f f = find files, Space f g = search text, - = file explorer`

### lazygit  ·  `lazygit`  ·  tui
Git with a friendly terminal interface.

- `run it inside a git folder`
- `space = stage file, c = commit, P = push, ? = help`

### GitHub CLI  ·  `gh`  ·  cli
GitHub from the terminal: clone, pull requests, issues.

- `gh auth login`
- `gh repo clone owner/repo`
- `gh pr create`

### Docker  ·  `docker`  ·  cli
Run software in isolated containers.

- `docker run hello-world`
- `docker ps`  (running containers)
- `docker compose up -d`

### k9s  ·  `k9s`  ·  tui
Dashboard for Kubernetes clusters (needs a kubeconfig).

- `k9s`
- `: pods`  (jump to pods), q = back

### Python  ·  `python`  ·  cli
Python 3 with pip, venv and uv.

- `python -m venv .venv && source .venv/bin/activate`
- `uv pip install requests`
- `python script.py`

### Node.js  ·  `node`  ·  cli
JavaScript/TypeScript runtime with npm and pnpm.

- `npm init -y`
- `pnpm add express`
- `node app.js`

### Rust  ·  `cargo`  ·  cli
Rust toolchain (rustup + cargo).

- `cargo new hello && cd hello`
- `cargo run`

### Go  ·  `go`  ·  cli
Go toolchain.

- `go mod init hello`
- `go run .`

### Java  ·  `java`  ·  cli
OpenJDK + Maven.

- `javac Main.java && java Main`
- `mvn package`

### C / C++  ·  `gcc`  ·  cli
gcc, clang, cmake, gdb (debugger), valgrind (memory checks).

- `gcc main.c -o main && ./main`
- `gdb ./main`

### HTTPie  ·  `http`  ·  cli
Readable HTTP requests, good for testing APIs.

- `http GET https://api.github.com/users/octocat`
- `http POST localhost:8000/items name=test`


## AI & LLM

### Claude Code  ·  `claude`  ·  tui
Anthropic's AI assistant in the terminal: reads your project, writes and fixes code.

- `cd my-project && claude`
- `type what you want in plain words`
- `/help inside Claude lists commands`

### Claude (web)  ·  `browser https://claude.ai`  ·  gui
Claude chat in the browser.

- `SUPER+SHIFT+X opens it`

### Local AI chat (Ollama)  ·  `ai-chat`  ·  tui
Run small language models offline on this laptop (slow but private).

- `ai-chat`  (first run downloads ~1.3 GB)
- `ollama list`  (installed models)
- `ollama pull qwen2.5:1.5b`


## Data science & neural networks

### JupyterLab  ·  `notebooks`  ·  gui
Notebooks: code, charts and notes in one page. Best place to learn ML.

- `SUPER+J opens it (files go to ~/notebooks)`
- `Shift+Enter runs a cell`
- `New notebook > Python 3`

### NumPy / pandas / Matplotlib  ·  `python`  ·  cli
Arrays, tables (CSV/Excel) and charts.

- `import pandas as pd`
- `df = pd.read_csv('data.csv')`
- `df.describe()`
- `df.plot()`

### PyTorch  ·  `python`  ·  cli
Build and train neural networks (runs on the CPU here).

- `import torch.nn as nn`
- `model = nn.Sequential(nn.Linear(4, 16), nn.ReLU(), nn.Linear(16, 1))`

### scikit-learn  ·  `python`  ·  cli
Classic machine learning: regression, classification, clustering.

- `from sklearn.linear_model import LinearRegression`
- `LinearRegression().fit(X, y)`


## Networking

### nmtui  ·  `nmtui`  ·  tui
Connect to Wi-Fi, Ethernet and VPNs (also SUPER+N).

- `nmtui`
- `nmcli device wifi list`

### Wireshark  ·  `wireshark`  ·  gui
Capture and inspect network packets with filters.

- `pick an interface, start capture`
- `filter: dns, http, ip.addr == 192.168.1.1`

### termshark  ·  `sudo termshark`  ·  tui
Wireshark inside the terminal.

- `sudo termshark -i wlan0`
- `sudo termshark -r capture.pcap`

### tcpdump  ·  `sudo tcpdump`  ·  cli
Capture packets from the command line.

- `sudo tcpdump -i any port 53`
- `sudo tcpdump -w capture.pcap`

### nmap  ·  `nmap`  ·  cli
Discover hosts and open ports (only on networks you own or may test).

- `nmap -sn 192.168.1.0/24`  (who is online)
- `nmap -sV 192.168.1.10`  (services)

### mtr  ·  `mtr`  ·  tui
Live traceroute + ping: see where the connection is slow.

- `mtr google.com`

### iperf3  ·  `iperf3`  ·  cli
Measure bandwidth between two machines.

- `iperf3 -s`  (server)
- `iperf3 -c 192.168.1.10`  (client)

### dig / whois  ·  `dig`  ·  cli
DNS lookups and domain ownership.

- `dig example.com`
- `dig +short MX gmail.com`
- `whois example.com`

### bmon / iftop / nethogs  ·  `bmon`  ·  tui
Live traffic per interface / connection / process.

- `bmon`
- `sudo iftop`
- `sudo nethogs`

### WireGuard  ·  `wg`  ·  cli
Modern VPN.

- `sudo wg-quick up ./wg0.conf`
- `sudo wg show`

### OpenVPN  ·  `openvpn`  ·  cli
Classic VPN client.

- `sudo openvpn --config client.ovpn`

### picocom / minicom  ·  `picocom`  ·  tui
Serial console for routers and switches (console cable).

- `sudo picocom -b 9600 /dev/ttyUSB0`  (Ctrl+A Ctrl+X to exit)

### Virtual Machine Manager  ·  `virt-manager`  ·  gui
Virtual machines for labs (routers, servers, other OSes).

- `File > New Virtual Machine > choose an ISO`

### BIRD  ·  `birdc`  ·  cli
Routing daemon to practise BGP/OSPF in labs.

- `sudo systemctl start bird`
- `birdc show protocols`

### ipcalc  ·  `ipcalc`  ·  cli
Subnet calculator.

- `ipcalc 192.168.10.0/26`

### mosh  ·  `mosh`  ·  cli
SSH that survives Wi-Fi changes and sleep.

- `mosh user@server`


## Security (authorized testing only)

### Metasploit  ·  `msfconsole`  ·  cli
Exploitation framework for labs and authorized pentests.

- `msfconsole`
- `search smb`
- `use <module>, show options, run`

### OWASP ZAP  ·  `zaproxy`  ·  gui
Web app security scanner and proxy.

- `Automated Scan > URL of your test app`

### Ghidra  ·  `ghidra`  ·  gui
Reverse engineering: decompile binaries.

- `New Project > Import File > double-click to analyse`

### radare2  ·  `r2`  ·  cli
Reverse engineering in the terminal.

- `r2 -A ./binary`
- `afl`  (functions), pdf @ main

### hashcat / John  ·  `hashcat`  ·  cli
Password hash cracking (your own hashes / labs).

- `hashcat -m 0 hashes.txt wordlist.txt`
- `john hashes.txt`

### hydra  ·  `hydra`  ·  cli
Login brute-forcing against your own test services.

- `hydra -l admin -P list.txt ssh://192.168.56.10`

### sqlmap  ·  `sqlmap`  ·  cli
Find SQL injection in test web apps.

- `sqlmap -u 'http://lab/item?id=1' --batch`

### gobuster / ffuf  ·  `gobuster`  ·  cli
Find hidden web paths.

- `gobuster dir -u http://lab -w /usr/share/seclists/Discovery/Web-Content/common.txt`
- `ffuf -u http://lab/FUZZ -w list.txt`

### nikto  ·  `nikto`  ·  cli
Quick web server misconfiguration scan.

- `nikto -h http://lab`

### aircrack-ng  ·  `aircrack-ng`  ·  cli
Wi-Fi security testing (your own network).

- `sudo airmon-ng`
- `sudo airodump-ng wlan0mon`

### bettercap  ·  `sudo bettercap`  ·  cli
Network attacks/monitoring lab tool.

- `sudo bettercap -iface wlan0`
- `help`

### testssl.sh  ·  `testssl.sh`  ·  cli
Check a server's TLS configuration.

- `testssl.sh example.com`

### Tor / proxychains  ·  `proxychains`  ·  cli
Route a command through Tor.

- `sudo systemctl start tor`
- `proxychains curl ifconfig.me`


## System & files

### yazi  ·  `yazi`  ·  tui
File manager in the terminal (also SUPER+E).

- `arrows/hjkl move, Enter open, Space select, d delete, ? help`

### btop  ·  `btop`  ·  tui
See CPU, RAM, disk, network and processes (also SUPER+SHIFT+T).

- `btop`
- `k = kill process, q = quit`

### KeePassXC  ·  `keepassxc`  ·  gui
Password manager (offline database).

- `Database > New Database`

### ncdu  ·  `ncdu`  ·  tui
Find what fills the disk.

- `ncdu ~`

### tldr  ·  `tldr`  ·  cli
Short examples for any command.

- `tldr tar`
- `tldr ssh`

### fastfetch  ·  `fastfetch`  ·  cli
System summary with your logo.

- `fastfetch`


## Office & media

### Zen Browser  ·  `browser`  ·  gui
Main web browser (SUPER+B).

### Firefox  ·  `firefox`  ·  gui
Backup browser (SUPER+CTRL+B).

### LibreOffice  ·  `libreoffice`  ·  gui
Documents, spreadsheets, presentations (opens .docx/.xlsx/.pptx).

### Obsidian  ·  `obsidian`  ·  gui
Markdown notes; good for a learning journal.

### zathura  ·  `zathura`  ·  gui
Fast PDF viewer (j/k scroll, + / - zoom).

- `zathura file.pdf`

### mpv / imv  ·  `mpv`  ·  gui
Video player / image viewer.

- `mpv video.mp4`
- `imv picture.png`


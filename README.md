# Eden
**Personalized, automated deployment of a modular offensive security environment** tailored for WSL or VMWare on Debian-based systems.

## Features
* Secure `sudo` handling using `askpass` with temporary password storage
* Silent logging with color-coded status messages
* Modular, function-based layout for maintainability and clarity
* Environment selection: WSL or VMWare
* Kali Linux APT repository and GPG key integration
* Kali APT pinning to avoid breaking the base system
* Installs and configures:

  * Core utilities and networking tools
  * Docker (with proper keyring setup and user group management)
  * Sliver C2
  * Metasploit Framework
  * Zellij terminal multiplexer
  * Golang
  * Eden AD Tools (Dockerized environment with Impacket, NetExec, BloodHound.py, etc.)
* Docker wrapper `eden` for AD tools with support for:

  * `eden shell`: interactive shell
  * `eden exec "<command>"`: run a command inside the container
  * `eden ps`: show running containers
* Automatic detection and correction of Docker group membership
* `.bashrc` customization with Golang environment setup and useful aliases

## Requirements
* Debian-based system (tested on Debian 12)
* Must be run as a **non-root user** with `sudo` privileges
* Internet connection

## Installation
```bash
git clone https://github.com/yourusername/eden.git
cd eden
chmod +x setup.sh
./setup.sh
```

## Notes
* After the first install, you may need to **log out and back in** or run `newgrp docker` to activate Docker group membership if it was added during setup.
* `eden-ad-tools` uses Docker to isolate tools like `NetExec` and `Impacket`. Your loot directory is mounted at `/home/<user>/loot` inside the container.
* Use `eden shell` for an interactive session, or `eden exec "command"` to run one-liners.

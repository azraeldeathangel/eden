# Eden
![image](https://github.com/user-attachments/assets/91380226-d7b8-4721-9f78-3d7cc8ae539e)

Personalized, automated deployment of a modular offensive security environment tailored for WSL or VMWare on Debian.

## Features
- Secure `sudo` handling using `askpass` with temporary password storage
- Silent logging with color-coded status messages
- Modular function-based layout for maintainability
- Environment selection: WSL or VMWare
- Adds and manages Kali Linux repositories and keyring
- Installs and configures:
  - Core utilities and networking tools
  - Docker (with proper keyring handling)
  - Burp Suite Pro
  - Sliver C2
  - Metasploit Framework
  - Zellij
  - Golang
  - Impacket (via `pipx`)
  - Exegol (via `pipx`)
- Kali APT pinning to avoid breaking base system
- Adds `.bashrc` customizations (Golang env, common aliases)

## Requirements
- Debian-based system (tested on Debian 12)
- Run as a **non-root user** with sudo privileges

```bash
git clone https://github.com/yourusername/eden.git
cd eden
chmod +x setup.sh
./setup.sh

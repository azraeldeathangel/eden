#!/bin/bash
set -euo pipefail

# ===============================
# Globals
# ===============================
TMP_PW=$(mktemp)
ASKPASS_SCRIPT=$(mktemp)
export SUDO_ASKPASS="$ASKPASS_SCRIPT"

# ===============================
# Logging Functions
# ===============================
log_info()    { echo -e "\033[1;34m[*]\033[0m $1"; }
log_success() { echo -e "\033[1;32m[+]\033[0m $1"; }
log_warn()    { echo -e "\033[1;35m[!]\033[0m $1"; }
log_error()   { echo -e "\033[1;31m[-]\033[0m $1"; exit 1; }
log_already() { echo -e "\033[1;35m[*]\033[0m $1 already installed."; }

silent_run() {
  if "$@" > /dev/null 2> >(tee /tmp/setup-error.log >&2); then
    log_success "$*"
  else
    log_error "Command failed: $*"
    cat /tmp/setup-error.log
    exit 1
  fi
}

install_pkg() {
  if dpkg -s "$1" >/dev/null 2>&1; then
    log_already "$1"
  else
    log_info "Installing $1..."
    silent_run sudo -A apt-get install -y "$1"
  fi
}

# ===============================
# Core Functions
# ===============================
banner() {
  echo -e "\033[1;31m
\`7MM\"\"\"YMM       \`7MM                     
  MM    \`7         MM                     
  MM   d      ,M\"\"bMM  .gP\"Ya \`7MMpMMMb.  
  MMmmMM    ,AP    MM ,M'   Yb  MM    MM  
  MM   Y  , 8MI    MM 8M\"\"\"\"\"\"  MM    MM  
  MM     ,M \`Mb    MM YM.    ,  MM    MM  
.JMMmmmmMMM  \`Wbmd\"MML.\`Mbmmd'.JMML  JMML.
\033[0m"
  echo "         Where everything started..."
  echo
}

ensure_not_root() {
  if [ "$(id -u)" -eq 0 ]; then
    log_error "Do not run this script as root. Use a regular user with sudo privileges."
  fi
}

prompt_user() {
  echo -ne "\033[1;34m[*]\033[0m Enter your username: "
  read -r USERNAME
  if ! id "$USERNAME" &>/dev/null; then
    log_error "User '$USERNAME' does not exist."
  fi

  echo -ne "\033[1;34m[*]\033[0m Enter your sudo password: "
  stty -echo
  read -r PASSWORD
  stty echo
  echo "$PASSWORD" > "$TMP_PW"
  chmod 600 "$TMP_PW"

  cat <<EOF > "$ASKPASS_SCRIPT"
#!/bin/bash
cat "$TMP_PW"
EOF
  chmod +x "$ASKPASS_SCRIPT"
}

ask_env() {
  echo
  echo -e "\033[1;34m[x]\033[0m Select your environment:"
  PS3="#? "
  select ENV in "WSL" "VMWare"; do
    case $REPLY in
      1 ) INSTALL_ENV="WSL"; break ;;
      2 ) INSTALL_ENV="VMWare"; break ;;
      * ) echo -e "\033[1;35m[!]\033[0m Select 1 (WSL) or 2 (VMWare)" ;;
    esac
  done
}

update_system() {
  log_info "Updating system..."
  silent_run sudo -A apt-get update
  silent_run sudo -A apt-get upgrade -y
}

install_core_packages() {
  local -r CORE_PKGS=(curl git python3 python3-pip python3-venv pipx unzip gcc vim binwalk file binutils nmap)
  for pkg in "${CORE_PKGS[@]}"; do
    install_pkg "$pkg"
  done
}

add_kali_repo() {
  local -r KALI_LIST="/etc/apt/sources.list.d/kali.list"
  local -r KALI_GPG="/etc/apt/trusted.gpg.d/kali.gpg"
  local -r KALI_KEY_URL="https://archive.kali.org/archive-key.asc"
  local -r KALI_PIN="/etc/apt/preferences.d/kali.pref"
  local -r KALI_REPO="deb http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware"

  # Add repo list if not already present
  if [ ! -f "$KALI_LIST" ] || ! grep -q "^deb .*kali" "$KALI_LIST"; then
    log_info "Adding Kali Linux APT repository..."
    echo "$KALI_REPO" | sudo -A tee "$KALI_LIST" > /dev/null
  else
    log_already "Kali APT source"
  fi

  # Remove old GPG key if it exists
  if [ -f "$KALI_GPG" ]; then
    log_warn "Removing old Kali GPG key..."
    sudo -A rm -f "$KALI_GPG"
  fi

  # Add the updated Kali key
  log_info "Importing Kali GPG key..."
  curl -fsSL "$KALI_KEY_URL" | gpg --dearmor | sudo -A tee "$KALI_GPG" > /dev/null

  # Add APT pinning if not already pinned
  if [ ! -f "$KALI_PIN" ]; then
    log_info "Setting APT pinning for Kali..."
    sudo -A tee "$KALI_PIN" > /dev/null <<EOF
Package: *
Pin: release o=Kali
Pin-Priority: 50
EOF
  else
    log_already "Kali pinning rules"
  fi

  # Update package index
  log_info "Updating package list after Kali repo addition..."
  silent_run sudo -A apt-get update

  log_success "Kali Linux repository and key configured."
}

install_impacket() {
  log_info "Installing Impacket via pipx..."

  if pipx list | grep -q "impacket"; then
    log_already "Impacket (pipx)"
  else
    silent_run pipx install git+https://github.com/fortra/impacket.git
    pipx ensurepath
    log_success "Impacket installed via pipx."
  fi
}

install_zellij() {
  if ! command -v zellij >/dev/null 2>&1; then
    log_info "Installing Zellij..."
    local TMP_DIR
    TMP_DIR=$(mktemp -d)
    curl -sL https://github.com/zellij-org/zellij/releases/download/v0.42.2/zellij-x86_64-unknown-linux-musl.tar.gz -o "$TMP_DIR/zellij.tar.gz"
    tar -xzf "$TMP_DIR/zellij.tar.gz" -C "$TMP_DIR"
    sudo -A mv "$TMP_DIR/zellij" /usr/local/bin/
    rm -rf "$TMP_DIR"
    log_success "Zellij installed."
  else
    log_already "Zellij"
  fi
}

install_golang() {
  local -r GO_TARBALL="go1.24.4.linux-amd64.tar.gz"
  local -r GO_DIR="/home/$USERNAME/.local/go"
  local -r GO_BIN="$GO_DIR/bin/go"

  if ! sudo -u "$USERNAME" "$GO_BIN" version &>/dev/null; then
    log_info "Installing Golang..."
    local TMP_DIR
    TMP_DIR=$(mktemp -d)
    curl -sL -o "$TMP_DIR/$GO_TARBALL" "https://go.dev/dl/$GO_TARBALL"
    sudo -A rm -rf "$GO_DIR"
    sudo -A tar -C "/home/$USERNAME" -xzf "$TMP_DIR/$GO_TARBALL"
    sudo -A mv "/home/$USERNAME/go" "$GO_DIR"
    sudo -A chown -R "$USERNAME:$USERNAME" "$GO_DIR"
    sudo -A ln -sf "$GO_BIN" /usr/local/bin/go
    rm -rf "$TMP_DIR"
    log_success "Golang installed."
  else
    log_already "Golang"
  fi
}

install_vmware_tools() {
  log_info "Setting up VMWare-specific tools..."

  # Burp Suite Pro
  if ! command -v burpsuitepro >/dev/null 2>&1; then
    log_info "Installing Burp Suite Pro..."
    curl -fsSL https://raw.githubusercontent.com/xiv3r/Burpsuite-Professional/main/install.sh | sudo -A sh > /dev/null 2>&1
    log_success "Burp Suite Pro installed."
  else
    log_already "Burp Suite Pro"
  fi

  # Docker
  if ! command -v docker >/dev/null 2>&1; then
    log_info "Installing Docker..."
    sudo -A mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor | sudo -A tee /etc/apt/keyrings/docker.gpg > /dev/null
    sudo -A chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" |
      sudo -A tee /etc/apt/sources.list.d/docker.list > /dev/null
    silent_run sudo -A apt-get update
    silent_run sudo -A apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo -A usermod -aG docker "$USERNAME"
    log_warn "You may need to log out and back in for Docker group changes to take effect."
  else
    log_already "Docker"
  fi

  # Sliver (subshell avoids changing PWD)
  if ! command -v sliver-server >/dev/null 2>&1; then
    (
      mkdir -p "/home/$USERNAME/Tools"
      curl -sL https://github.com/BishopFox/sliver/releases/latest/download/sliver-server_linux -o sliver-server
      chmod +x sliver-*
      sudo -A mv sliver-* /usr/local/bin/
    )
    log_success "Sliver installed."
  else
    log_already "Sliver"
  fi

  # Metasploit
  if ! command -v msfconsole >/dev/null 2>&1; then
    curl -s https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb -o msfinstall
    chmod +x msfinstall
    silent_run ./msfinstall
    rm -f msfinstall
  else
    log_already "Metasploit"
  fi

  # Network tools
  local -r TOOLS=(telnet netcat-openbsd snmpcheck onesixtyone enum4linux-ng nfs-common smbclient smbmap hydra)
  for tool in "${TOOLS[@]}"; do
    install_pkg "$tool"
  done
}

ensure_docker_group_active() {
  if ! groups "$USERNAME" | grep -qw docker; then
    log_info "Adding $USERNAME to the docker group..."
    silent_run sudo -A usermod -aG docker "$USERNAME"
    log_warn "$USERNAME has been added to the docker group."

    echo
    log_warn "Launching a new shell with updated group membership..."
    exec sudo -u "$USERNAME" newgrp docker <<EOF
bash -c "$0"
EOF
    exit 0
  else
    log_success "$USERNAME is already in the docker group."
  fi
}

install_eden_ad_tools() {
  local REPO_DIR="/opt/eden-ad-tools"
  local IMAGE_NAME="eden-ad-tools"
  local LOOT_DIR="/home/$USERNAME/loot"
  local DOCKERFILE="$REPO_DIR/Dockerfile"
  local WRAPPER="/usr/local/bin/eden"

  log_info "Setting up Eden AD tools Docker container..."

  # Create /opt/eden-ad-tools directory
  if [ ! -d "$REPO_DIR" ]; then
    sudo -A mkdir -p "$REPO_DIR"
    sudo -A chown "$USERNAME:$USERNAME" "$REPO_DIR"
  fi

  # Write Dockerfile only if it doesn't exist
  if [ ! -f "$DOCKERFILE" ]; then
    cat <<EOF | sudo -u "$USERNAME" tee "$DOCKERFILE" > /dev/null
  FROM python:3.11-slim
  
  ENV DEBIAN_FRONTEND=noninteractive
  ENV PIPX_HOME=/root/.local/pipx
  ENV PATH=/root/.local/bin:\$PIPX_HOME/venvs/impacket/bin:\$PIPX_HOME/venvs/ldapdomaindump/bin:\$PIPX_HOME/venvs/crackmapexec/bin:\$PATH
  
  RUN apt-get update && \\
      apt-get install -y --no-install-recommends \\
          build-essential git gcc libldap2-dev libsasl2-dev libssl-dev \\
          python3-dev python3-pip pipx \\
      && apt-get clean && rm -rf /var/lib/apt/lists/*
  
  RUN pip install --no-cache-dir pipx && \\
      pipx ensurepath && \\
      pipx install git+https://github.com/fortra/impacket.git && \\
      pipx install git+https://github.com/Pennyw0rth/NetExec
  
  WORKDIR /loot
  CMD ["/bin/bash"]
EOF
  
    log_success "Dockerfile created at $DOCKERFILE"
  else
    log_already "Dockerfile at $DOCKERFILE"
  fi

  # Build Docker image
  if [[ -z $(docker images -q "$IMAGE_NAME") ]]; then
    silent_run sudo -u "$USERNAME" bash -c "cd '$REPO_DIR' && docker build -t '$IMAGE_NAME' --platform=linux/amd64 . > /dev/null 2>&1"
  else
    log_already "Docker image '$IMAGE_NAME' already exists. Skipping build."
  fi

  # Create loot directory
  mkdir -p "$LOOT_DIR"
  sudo -A chown "$USERNAME:$USERNAME" "$LOOT_DIR"

  # Write /usr/local/bin/eden wrapper script only if it doesn't exist
  if [ ! -f "$WRAPPER" ]; then
    sudo tee "$WRAPPER" > /dev/null <<EOF
  #!/bin/bash
  
  IMAGE="$IMAGE_NAME"
  LOOT_DIR="/home/$USERNAME/loot"
  
  print_help() {
    echo "Usage: eden [command]"
    echo "Commands:"
    echo "  shell           Start interactive container"
    echo "  exec \"<cmd>\"    Execute command inside container"
    echo "  ps              Show running Eden containers"
  }
  
  case "\$1" in
    shell)
      exec sudo docker run --rm -it \\
        --network host \\
        -v "\$LOOT_DIR:/loot" \\
        "\$IMAGE"
      ;;
    exec)
      shift
      if [ \$# -eq 0 ]; then
        echo "Missing command. Usage: eden exec \"<command>\""
        exit 1
      fi
      exec sudo docker run --rm -it \\
        --network host \\
        -v "\$LOOT_DIR:/loot" \\
        "\$IMAGE" /bin/bash -c "\$*"
      ;;
    ps)
      sudo docker ps --filter ancestor="\$IMAGE"
      ;;
    help|-h|--help)
      print_help
      ;;
    *)
      echo "Unknown command. Try: eden help"
      exit 1
      ;;
  esac
EOF
  
    sudo chmod +x "$WRAPPER"
    log_success "Wrapper script installed at $WRAPPER"
  else
    log_already "Wrapper script at $WRAPPER"
  fi
}

configure_bashrc() {
  local BASHRC="/home/$USERNAME/.bashrc"
  local USER_HOME="/home/$USERNAME"
  log_info "Appending Golang env and aliases to $BASHRC..."
  echo "" | sudo -u "$USERNAME" tee -a "$BASHRC" > /dev/null
  sudo -u "$USERNAME" bash << EOF
grep -q 'GOPATH=' "$BASHRC" || cat << 'CONFIG' >> "$BASHRC"

# Golang
export GOPATH="$USER_HOME/go"
export PATH="$USER_HOME/.local/go/bin:\$GOPATH/bin:\$PATH"

# Aliases
alias ll='ls -la'
alias gs='git status'
alias update='sudo apt-get update && sudo apt-get upgrade -y'
alias zz='zellij'
CONFIG
EOF
  log_success ".bashrc configured."
}

cleanup() {
  rm -f "$ASKPASS_SCRIPT" "$TMP_PW"
}

main() {
  ensure_not_root
  banner
  prompt_user
  ask_env
  add_kali_repo
  update_system
  install_core_packages
  install_impacket
  install_zellij
  install_golang
  if [ "$INSTALL_ENV" = "VMWare" ]; then
    install_vmware_tools
    ensure_docker_group_active
    install_eden_ad_tools
  fi
  configure_bashrc
  log_success "Initial setup complete. Restart your terminal session."
}

main "$@"

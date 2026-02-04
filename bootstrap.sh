#!/usr/bin/env bash

# Text formatting
BOLD="\e[1m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

# Repository URL
REPO_URL="https://github.com/luciancurteanu/vps.git"

# Determine the correct home directory to use for cloning. When running with sudo,
# prefer the original user's home so we clone into /home/<user>/vps rather than /root/vps.
# If SUDO_USER is not set (can happen when piping through sudo), attempt to find
# the first non-system user from /etc/passwd as a fallback.
if [ "$EUID" -eq 0 ] && [ -z "${SUDO_USER:-}" ]; then
    # pick a likely human user (uid >= 1000)
    fallback_user=$(awk -F: '($3>=1000)&&($1!="nfsnobody"){print $1; exit}' /etc/passwd 2>/dev/null || true)
    if [ -n "$fallback_user" ]; then
        SUDO_USER="$fallback_user"
    fi
fi

if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6 || echo "/home/${SUDO_USER}")
else
    USER_HOME="${HOME}"
fi

REPO_DIR="${USER_HOME}/vps"

# Parse arguments
FORCE_CLONE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force|force)
            FORCE_CLONE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Also allow forcing via environment variable (useful when piping to sudo):
#   BOOTSTRAP_FORCE=1 curl ... | sudo bash -s
if [ -n "${BOOTSTRAP_FORCE:-}${FORCE:-}" ]; then
    case "${BOOTSTRAP_FORCE:-${FORCE:-}}" in
        1|true|yes|on)
            FORCE_CLONE=true
            ;;
    esac
fi

echo -e "${BOLD}VPS Setup Bootstrap${RESET}"
echo "This script will prepare your server for VPS setup."
echo "Repository will be cloned to: ${REPO_DIR}"
echo

# Detect OS
detect_os() {
    if command -v dnf &> /dev/null; then
        OS_TYPE="rhel"
        PKG_MGR="dnf"
    elif command -v apt &> /dev/null; then
        OS_TYPE="debian"
        PKG_MGR="apt"
    elif command -v yum &> /dev/null; then
        OS_TYPE="rhel"
        PKG_MGR="yum"
    else
        echo -e "${RED}Unable to detect package manager.${RESET}"
        exit 1
    fi
    echo -e "${GREEN}Detected OS: $OS_TYPE (using $PKG_MGR)${RESET}"
}

# Install Git
install_git() {
    echo -e "${YELLOW}Checking for Git...${RESET}"
    if ! command -v git &> /dev/null; then
        echo -e "Git is not installed. Installing Git..."
        
        if [ "$OS_TYPE" = "debian" ]; then
            sudo apt update
            sudo apt install -y git
        elif [ "$OS_TYPE" = "rhel" ]; then
            sudo $PKG_MGR install -y epel-release || true
            sudo $PKG_MGR install -y git
        fi
        
        # Verify installation
        if ! command -v git &> /dev/null; then
            echo -e "${RED}Git installation failed. Please install manually.${RESET}"
            exit 1
        else
            echo -e "${GREEN}Git installed successfully!${RESET}"
        fi
    else
        echo -e "${GREEN}Git is already installed.${RESET}"
    fi
}

# Install Ansible
install_ansible() {
    echo -e "${YELLOW}Checking for Ansible...${RESET}"
    if ! command -v ansible-playbook &> /dev/null; then
        echo -e "Ansible is not installed. Installing Ansible..."
        
        if [ "$OS_TYPE" = "debian" ]; then
            sudo apt update
            sudo apt install -y ansible
        elif [ "$OS_TYPE" = "rhel" ]; then
            sudo $PKG_MGR install -y epel-release || true
            if ! sudo $PKG_MGR install -y ansible; then
                echo -e "${YELLOW}Package installation failed, trying with pip...${RESET}"
                sudo $PKG_MGR install -y python3-pip
                sudo pip3 install ansible
            fi
        fi
        
        # Verify installation
        if ! command -v ansible-playbook &> /dev/null; then
            echo -e "${RED}Ansible installation failed. Please install manually.${RESET}"
            exit 1
        else
            echo -e "${GREEN}Ansible installed successfully!${RESET}"
        fi
    else
        echo -e "${GREEN}Ansible is already installed.${RESET}"
    fi
}

# Install Python dependencies
install_python_deps() {
    echo -e "${YELLOW}Checking for Python and pip...${RESET}"
    
    if [ "$OS_TYPE" = "debian" ]; then
        sudo apt install -y python3 python3-pip python3-venv
    elif [ "$OS_TYPE" = "rhel" ]; then
        sudo $PKG_MGR install -y python3 python3-pip
    fi
    
    if command -v python3 &> /dev/null; then
        echo -e "${GREEN}Python $(python3 --version) is installed.${RESET}"
    else
        echo -e "${RED}Python installation failed.${RESET}"
        exit 1
    fi
}

# Install essential tools
install_essentials() {
    echo -e "${YELLOW}Installing essential tools...${RESET}"
    
    if [ "$OS_TYPE" = "debian" ]; then
        sudo apt install -y curl wget rsync sshpass nano
    elif [ "$OS_TYPE" = "rhel" ]; then
        sudo $PKG_MGR install -y curl wget rsync sshpass nano
    fi
    
    echo -e "${GREEN}Essential tools installed.${RESET}"
}

# Clone the repository
clone_repo() {
    echo -e "${YELLOW}Cloning VPS setup repository to ${REPO_DIR}...${RESET}"
    
    # Ensure parent directory exists
    PARENT_DIR=$(dirname "$REPO_DIR")
    mkdir -p "$PARENT_DIR"
    
    if [ -d "$REPO_DIR" ]; then
        if [ "$FORCE_CLONE" = true ]; then
            echo -e "${YELLOW}Removing existing directory $REPO_DIR (force mode)...${RESET}"
            rm -rf "$REPO_DIR"
        else
            echo -e "${YELLOW}Directory $REPO_DIR already exists.${RESET}"
            read -p "Do you want to update it? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cd "$REPO_DIR"
                git pull
                cd - > /dev/null
                echo -e "${GREEN}Repository updated.${RESET}"
                # ensure ownership when updated under sudo
                target_user="${SUDO_USER:-$USER}"
                chown -R "$target_user":"$target_user" "$REPO_DIR" 2>/dev/null || true
                return
            else
                echo -e "${YELLOW}Skipping repository update.${RESET}"
                return
            fi
        fi
    fi

    git clone "$REPO_URL" "$REPO_DIR"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Repository cloned successfully to ${REPO_DIR}${RESET}"
    else
        echo -e "${RED}Failed to clone repository. Please check the URL and your network connection.${RESET}"
        exit 1
    fi

    # Ensure repo files are owned by non-root user when possible
    target_user="${SUDO_USER:-$USER}"
    chown -R "$target_user":"$target_user" "$REPO_DIR" 2>/dev/null || true
}

# If interactive, offer to drop into a shell inside the repo directory.
# If running as root with SUDO_USER set, switch to that user before opening the shell.
if [ -t 1 ]; then
    if [ -d "$REPO_DIR" ]; then
        echo -e "${GREEN}Entering repository directory: ${REPO_DIR}${RESET}"
        if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
            echo -e "${YELLOW}Opening an interactive shell as ${SUDO_USER} inside ${REPO_DIR}${RESET}"
            sudo -H -u "${SUDO_USER}" bash -lic "cd '${REPO_DIR}' && exec \$SHELL"
        else
            cd "$REPO_DIR" || true
            exec "$SHELL"
        fi
    fi
fi

# Make scripts executable
make_executable() {
    echo -e "${YELLOW}Making scripts executable...${RESET}"
    chmod +x "$REPO_DIR/vps.sh"
    chmod +x "$REPO_DIR/bootstrap.sh"
    echo -e "${GREEN}Scripts are now executable.${RESET}"
}

# Auto-change into the repository directory and open an interactive shell when appropriate.
auto_cd() {
    if [ -t 1 ] && [ -d "$REPO_DIR" ]; then
        if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
            echo -e "${GREEN}Opening an interactive shell as ${SUDO_USER} inside ${REPO_DIR}${RESET}"
            sudo -H -u "${SUDO_USER}" bash -lic "cd '${REPO_DIR}' && exec \$SHELL"
        else
            echo -e "${GREEN}Changing into ${REPO_DIR}${RESET}"
            cd "$REPO_DIR" || true
            exec "$SHELL"
        fi
    fi
}

# Main function
main() {
    detect_os
    echo
    install_git
    echo
    install_python_deps
    echo
    install_ansible
    echo
    install_essentials
    echo
    clone_repo
    echo
    make_executable
    echo
    # If running interactively, drop into the repo directory/shell now.
    auto_cd
    echo
    
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════${RESET}"
    echo -e "${GREEN}${BOLD}  Bootstrap Complete!${RESET}"
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════${RESET}"
    echo
    echo -e "${BOLD}Installed Components:${RESET}"
    echo -e "  ✓ Git:     $(git --version 2>/dev/null || echo 'Not found')"
    echo -e "  ✓ Python:  $(python3 --version 2>/dev/null || echo 'Not found')"
    echo -e "  ✓ Ansible: $(ansible --version 2>/dev/null | head -n1 || echo 'Not found')"
    echo -e "  ✓ nano:    $(nano --version 2>/dev/null | head -n1 || echo 'Not found')"
    echo
    echo -e "${BOLD}Next Steps:${RESET}"
    echo -e "  1. Navigate to project: ${GREEN}cd $REPO_DIR${RESET}"
    echo -e "  2. Configure inventory: ${GREEN}cp inventory/hosts.yml.example inventory/hosts.yml${RESET}"
    echo -e "     Then edit: ${GREEN}nano inventory/hosts.yml${RESET}"
    echo -e "  3. Create vault secrets: ${GREEN}cp vars/secrets.yml.example vars/secrets.yml${RESET}"
    echo -e "     Fill in passwords: ${GREEN}nano vars/secrets.yml${RESET}"
    echo -e "     Encrypt the file: ${GREEN}ansible-vault encrypt vars/secrets.yml${RESET}"
    echo -e "  4. Run setup: ${GREEN}./vps.sh install core --domain=yourdomain.com --ask-pass --ask-vault-pass${RESET}"
    echo
    echo -e "${YELLOW}Tip: For testing in a VM, use scripts/vm-launcher/run-vm.ps1${RESET}"
    echo
}

# Run main function
main
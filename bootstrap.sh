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

# Parse arguments and determine force mode
FORCE_CLONE=false

# Check for environment variables first (FORCE=1, F=1, or any truthy value)
if [ -n "${FORCE:-}${F:-}" ]; then
    case "${FORCE:-${F:-}}" in
        1|true|yes|on)
            FORCE_CLONE=true
            ;;
    esac
fi

# When piped (non-interactive stdin), default to force mode unless explicitly disabled
if [ ! -t 0 ] && [ "${FORCE_CLONE}" != true ]; then
    # Allow opt-out with FORCE=0 or F=0
    if [ "${FORCE:-}" != "0" ] && [ "${F:-}" != "0" ]; then
        FORCE_CLONE=true
    fi
fi

# Command line arguments can override
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force|force)
            FORCE_CLONE=true
            shift
            ;;
        --no-force)
            FORCE_CLONE=false
            shift
            ;;
        *)
            shift
            ;;
    esac
done

echo -e "${BOLD}VPS Setup Bootstrap${RESET}"
echo "This script will prepare your server for VPS setup."
echo "Repository will be cloned to: ${REPO_DIR}"
if [ "$FORCE_CLONE" = true ]; then
    echo -e "${YELLOW}Force mode: ENABLED${RESET}"
fi
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
    if ! command -v ansible-playbook &> /dev/null || ! command -v ansible-vault &> /dev/null; then
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
        if ! command -v ansible-playbook &> /dev/null || ! command -v ansible-vault &> /dev/null; then
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
            # Continue to clone below after removal
        else
            echo -e "${YELLOW}Directory $REPO_DIR already exists.${RESET}"
            if [ -t 0 ]; then
                # Only prompt if stdin is a terminal (interactive)
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
            else
                # Non-interactive (piped), skip update
                echo -e "${YELLOW}Skipping repository update (non-interactive mode).${RESET}"
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

    # If force mode was used via -f/--force/force or env var, ensure ownership is set to admin:admin
    # as requested when running: curl ... | bash -s -f
    if [ "$FORCE_CLONE" = true ]; then
        if command -v sudo &> /dev/null; then
            sudo chown -R admin:admin "$REPO_DIR" 2>/dev/null || true
        else
            chown -R admin:admin "$REPO_DIR" 2>/dev/null || true
        fi
    fi
}

## (auto-cd behavior moved to the end of the script inside main -> auto_cd)

# Generate a server-side Ansible SSH key and register any injected control key.
# SSH_PUBLIC_KEY env var: optional public key from the control host (e.g. Windows vps.pub).
# This key is written to ~/.ssh/<label>.pub so 'sync keys' picks it up automatically.
setup_ssh_keys() {
    local ssh_dir="$USER_HOME/.ssh"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    # 1) Generate Ansible self-connect key if missing
    if [ ! -f "$ssh_dir/ansible_id" ]; then
        echo -e "${YELLOW}Generating Ansible SSH key...${RESET}"
        ssh-keygen -t ed25519 -f "$ssh_dir/ansible_id" -N "" -C "ansible-control" > /dev/null 2>&1
        cat "$ssh_dir/ansible_id.pub" >> "$ssh_dir/authorized_keys"
        chmod 600 "$ssh_dir/authorized_keys"
        echo -e "${GREEN}Ansible key generated and added to authorized_keys.${RESET}"
    else
        echo -e "${GREEN}Ansible key already exists.${RESET}"
    fi

    # 2) Register injected control-host public key (e.g. from Windows vps.pub)
    #    Pass it via: SSH_PUBLIC_KEY="ssh-ed25519 AAAA... label" bash bootstrap.sh
    if [ -n "${SSH_PUBLIC_KEY:-}" ]; then
        local label
        label=$(echo "$SSH_PUBLIC_KEY" | awk '{print $NF}' | tr -dc '[:alnum:]-_')
        [ -z "$label" ] && label="control-host"
        local pub_file="$ssh_dir/${label}.pub"
        echo "$SSH_PUBLIC_KEY" > "$pub_file"
        chmod 644 "$pub_file"
        # add to authorized_keys if not already present
        if ! grep -qF "$SSH_PUBLIC_KEY" "$ssh_dir/authorized_keys" 2>/dev/null; then
            echo "$SSH_PUBLIC_KEY" >> "$ssh_dir/authorized_keys"
            chmod 600 "$ssh_dir/authorized_keys"
        fi
        echo -e "${GREEN}Control-host key registered: $pub_file${RESET}"
    fi

    # Fix ownership when running as root on behalf of a user
    local target_user="${SUDO_USER:-$USER}"
    chown -R "$target_user":"$target_user" "$ssh_dir" 2>/dev/null || true
}

# Make scripts executable
make_executable() {
    echo -e "${YELLOW}Making scripts executable...${RESET}"
    find "$REPO_DIR" -name "*.sh" -not -path "*/.git/*" -exec chmod +x {} \;
    # Activate the shared git hooks so post-merge/post-checkout auto-fix permissions on every pull
    if [ -d "$REPO_DIR/.githooks" ]; then
        git -C "$REPO_DIR" config core.hooksPath .githooks
        chmod +x "$REPO_DIR/.githooks/"* 2>/dev/null || true
    fi
    echo -e "${GREEN}Scripts are now executable.${RESET}"
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
    setup_ssh_keys
    echo
    
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════${RESET}"
    echo -e "${GREEN}${BOLD}  Bootstrap Complete!${RESET}"
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════${RESET}"
    echo
    echo -e "${BOLD}Installed Components:${RESET}"
    echo -e "  ✓ Git:     $(git --version 2>/dev/null || echo 'Not found')"
    echo -e "  ✓ Python:  $(python3 --version 2>/dev/null || echo 'Not found')"
    echo -e "  ✓ Ansible: $(ansible --version 2>/dev/null | head -n1 || echo 'Not found')"
    echo -e "  ✓ Ansible Vault: $(ansible-vault --version 2>/dev/null | head -n1 || echo 'Not found')"
    echo -e "  ✓ Nano:    $(nano --version 2>/dev/null | head -n1 || echo 'Not found')"
    echo
    echo -e "${BOLD}Next Steps:${RESET}"
    echo -e "  1. Change to the repository directory:"
    echo -e "     ${GREEN}cd ~/vps${RESET}"
    echo
    echo -e "  2. Configure inventory and secrets:"
    echo -e "     ${GREEN}cp inventory/group_vars/all.yml.example inventory/group_vars/all.yml${RESET}"
    echo -e "     ${GREEN}cp inventory/hosts.yml.example inventory/hosts.yml${RESET}"
    echo -e "     ${GREEN}cp vars/secrets.yml.example vars/secrets.yml${RESET}"
    echo
    echo -e "     Edit the following files to set your domain, SSH user, and other settings:"
    echo -e "     ${GREEN}nano inventory/group_vars/all.yml${RESET}"
    echo -e "     ${GREEN}nano inventory/hosts.yml${RESET}"
    echo -e "     ${GREEN}nano vars/secrets.yml${RESET}"
    echo
    echo -e "     Encrypt the secrets file using Ansible Vault:"
    echo -e "     ${GREEN}ansible-vault encrypt vars/secrets.yml${RESET}"
    echo
    echo -e "  3. Run the setup playbook:"
    echo -e "     ${GREEN}./vps.sh install core --domain=yourdomain.com --ask-pass --ask-vault-pass${RESET}"
    echo
    echo -e "  4. Re-run bootstrap (will force by default when piped):"
    echo -e "     ${GREEN}curl -fsSL https://raw.githubusercontent.com/luciancurteanu/vps/main/bootstrap.sh | bash${RESET}"
    echo -e "     To disable force: ${GREEN}curl ... | FORCE=0 bash${RESET}"
    echo
    echo -e "${YELLOW}Tip: For testing in a VM, use scripts/vm-launcher/run-vm.ps1${RESET}"
    echo
}

# Run main function
main
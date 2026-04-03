#!/usr/bin/env bash

# Text formatting
BOLD="\e[1m"
    # If running piped (curl | bash), auto-clean generated helper files by default
    if [ -z "${CLEAN_GENERATED:-}" ]; then
        CLEAN_GENERATED=1
    fi
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
    # (non-interactive/piped) default behavior remains unchanged here
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

# Generate an SSH key (ed25519) for this control host and update
# the repository secrets file with the public key so playbooks can
# provision servers with the generated key as the admin user's pubkey.
generate_and_register_ssh_key() {
    # Where to place the generated key
    KEY_DIR="$USER_HOME/.ssh"
    KEY_NAME="vps_id_ed25519"
    KEY_PATH="$KEY_DIR/$KEY_NAME"

    # Ensure .ssh exists
    mkdir -p "$KEY_DIR"
    chmod 700 "$KEY_DIR" 2>/dev/null || true

    # If a key already exists at that path, reuse it
    if [ -f "$KEY_PATH" ]; then
        echo -e "${YELLOW}Found existing key at $KEY_PATH, reusing it.${RESET}"
    else
        echo -e "${YELLOW}Generating SSH key pair at $KEY_PATH (no passphrase)...${RESET}"
        # Quietly generate an ed25519 key with an identifiable comment
        ssh-keygen -q -t ed25519 -f "$KEY_PATH" -N "" -C "vps-bootstrap@$(hostname)" || {
            echo -e "${RED}Failed to generate SSH key. Skipping key registration.${RESET}"
            return 1
        }
        chmod 600 "$KEY_PATH" 2>/dev/null || true
        chmod 644 "$KEY_PATH.pub" 2>/dev/null || true
        echo -e "${GREEN}SSH key generated: $KEY_PATH${RESET}"
    fi

    # Read the public key
    if [ -f "$KEY_PATH.pub" ]; then
        PUBKEY=$(cat "$KEY_PATH.pub")
    else
        echo -e "${RED}Public key not found at ${KEY_PATH}.pub. Aborting registration.${RESET}"
        return 1
    fi

    # Path to secrets file inside the cloned repo
    SECRETS_FILE="$REPO_DIR/vars/secrets.yml"
    SECRETS_EXAMPLE="$REPO_DIR/vars/secrets.yml.example"

    # Helper to safely write the pubkey into the secrets file
    if [ -f "$SECRETS_FILE" ]; then
        # Detect ansible-vault encrypted file header
        if head -n1 "$SECRETS_FILE" | grep -q '^\$ANSIBLE_VAULT'; then
            echo -e "${YELLOW}Detected encrypted vars/secrets.yml.${RESET}"
            # Prompt the user for the vault password (use /dev/tty for piped execution)
            VAULT_PASS=""
            if [ -t 0 ]; then
                read -s -p "Enter Ansible Vault password to update vars/secrets.yml (leave empty to skip): " VAULT_PASS
                echo
            elif [ -e /dev/tty ]; then
                read -s -p "Enter Ansible Vault password to update vars/secrets.yml (leave empty to skip): " VAULT_PASS </dev/tty
                echo
            fi

            if [ -n "$VAULT_PASS" ]; then
                TMP_VAULT_FILE=$(mktemp)
                printf "%s" "$VAULT_PASS" > "$TMP_VAULT_FILE"
                chmod 600 "$TMP_VAULT_FILE"
                TMP_DECRYPT=$(mktemp)
                # Try to view (decrypt) using the provided password
                if command -v ansible-vault &> /dev/null && ansible-vault view "$SECRETS_FILE" --vault-password-file "$TMP_VAULT_FILE" > "$TMP_DECRYPT" 2>/dev/null; then
                    # Replace existing variable if present, otherwise append
                    if grep -q '^vault_admin_ssh_public_key:' "$TMP_DECRYPT"; then
                        awk -v key="$PUBKEY" 'BEGIN{q="\""} /^vault_admin_ssh_public_key:/{print "vault_admin_ssh_public_key: " q key q; next} {print}' "$TMP_DECRYPT" > "$TMP_DECRYPT.tmp" && mv "$TMP_DECRYPT.tmp" "$TMP_DECRYPT"
                    else
                        echo "vault_admin_ssh_public_key: \"$PUBKEY\"" >> "$TMP_DECRYPT"
                    fi
                    # Encrypt the modified file and replace the original
                    ansible-vault encrypt "$TMP_DECRYPT" --vault-password-file "$TMP_VAULT_FILE" 2>/dev/null && mv "$TMP_DECRYPT" "$SECRETS_FILE"
                    rm -f "$TMP_VAULT_FILE" 2>/dev/null || true
                    echo -e "${GREEN}Inserted public key into encrypted $SECRETS_FILE and re-encrypted it.${RESET}"
                    # Ensure ownership
                    chown "${SUDO_USER:-$USER}":"${SUDO_USER:-$USER}" "$SECRETS_FILE" 2>/dev/null || true
                    # Remove any helper file if present
                    if [ -f "$REPO_DIR/vars/secrets.generated.yml" ]; then
                        rm -f "$REPO_DIR/vars/secrets.generated.yml" 2>/dev/null || true
                    fi
                    return 0
                else
                    echo -e "${YELLOW}Vault password incorrect or ansible-vault not available; will create helper file instead.${RESET}"
                    rm -f "$TMP_VAULT_FILE" 2>/dev/null || true
                    rm -f "$TMP_DECRYPT" 2>/dev/null || true
                fi
            else
                echo -e "${YELLOW}No vault password provided; will create helper file for manual merge.${RESET}"
            fi
            echo -e "${YELLOW}Creating vars/secrets.generated.yml containing only the public key for you to merge with your encrypted file.${RESET}"
            mkdir -p "$(dirname "$SECRETS_FILE")"
            # Remove any previous generated file to avoid accumulation
            if [ -f "$REPO_DIR/vars/secrets.generated.yml" ]; then
                rm -f "$REPO_DIR/vars/secrets.generated.yml" 2>/dev/null || true
            fi
            cat > "$REPO_DIR/vars/secrets.generated.yml" <<EOF
vault_admin_ssh_public_key: "$PUBKEY"
EOF
            chown "${SUDO_USER:-$USER}":"${SUDO_USER:-$USER}" "$REPO_DIR/vars/secrets.generated.yml" 2>/dev/null || true
            return 0
        fi

        # Replace existing variable if present, otherwise append
        if grep -q '^vault_admin_ssh_public_key:' "$SECRETS_FILE"; then
            # Use awk to safely replace the line
            awk -v key="$PUBKEY" 'BEGIN{q="\""} /^vault_admin_ssh_public_key:/{print "vault_admin_ssh_public_key: " q key q; next} {print}' "$SECRETS_FILE" > "$SECRETS_FILE.tmp" && mv "$SECRETS_FILE.tmp" "$SECRETS_FILE"
            echo -e "${GREEN}Updated vault_admin_ssh_public_key in $SECRETS_FILE${RESET}"
        else
            echo -e "${YELLOW}No vault_admin_ssh_public_key variable found in $SECRETS_FILE; appending it.${RESET}"
            echo "vault_admin_ssh_public_key: \"$PUBKEY\"" >> "$SECRETS_FILE"
        fi
    else
        # If secrets file doesn't exist but an example exists, copy it first
        if [ -f "$SECRETS_EXAMPLE" ]; then
            cp "$SECRETS_EXAMPLE" "$SECRETS_FILE"
            echo -e "${YELLOW}Created $SECRETS_FILE from example.${RESET}"
            # Then replace/append as above
            awk -v key="$PUBKEY" 'BEGIN{q="\""} /^vault_admin_ssh_public_key:/{print "vault_admin_ssh_public_key: " q key q; next} {print}' "$SECRETS_FILE" > "$SECRETS_FILE.tmp" && mv "$SECRETS_FILE.tmp" "$SECRETS_FILE"
            if ! grep -q '^vault_admin_ssh_public_key:' "$SECRETS_FILE"; then
                echo "vault_admin_ssh_public_key: \"$PUBKEY\"" >> "$SECRETS_FILE"
            fi
            echo -e "${GREEN}Wrote vault_admin_ssh_public_key to $SECRETS_FILE${RESET}"
        else
            # Create a minimal secrets file with the public key
            mkdir -p "$(dirname "$SECRETS_FILE")"
            cat > "$SECRETS_FILE" <<EOF
vault_admin_ssh_public_key: "$PUBKEY"
EOF
            echo -e "${GREEN}Created $SECRETS_FILE with new public key.${RESET}"
        fi
    fi

    # Ensure ownership of the updated file matches the non-root user when possible
    chown "${SUDO_USER:-$USER}":"${SUDO_USER:-$USER}" "$SECRETS_FILE" 2>/dev/null || true
}


## (auto-cd behavior moved to the end of the script inside main -> auto_cd)

# Make scripts executable
make_executable() {
    echo -e "${YELLOW}Making scripts executable...${RESET}"
    chmod +x "$REPO_DIR/vps.sh"
    chmod +x "$REPO_DIR/bootstrap.sh"
    chmod +x "$REPO_DIR/encrypt-vault.sh"
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
    # Generate SSH key for control host and register its public key in vars/secrets.yml
    generate_and_register_ssh_key || true
    echo
    make_executable
        echo
        # Optional cleanup of generated secrets helper file if requested
        if [ "${CLEAN_GENERATED:-}" = "1" ]; then
            GENERATED_FILE="$REPO_DIR/vars/secrets.generated.yml"
            if [ -f "$GENERATED_FILE" ]; then
                rm -f "$GENERATED_FILE" 2>/dev/null || true
                echo -e "${YELLOW}Removed generated secrets file: $GENERATED_FILE${RESET}"
            fi
        fi
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
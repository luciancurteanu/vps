#!/usr/bin/env bash

# Define paths
PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CONFIG_FILE="$PROJECT_ROOT/inventory/group_vars/all.yml"
VAULT_FILE="$PROJECT_ROOT/vars/secrets.yml"
HOSTS_FILE="$PROJECT_ROOT/inventory/hosts.yml"

# Text formatting
BOLD="\e[1m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

# Log with timestamp
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Auto-activate per-user Molecule virtualenv if present
if [ -f "$HOME/molecule-env/bin/activate" ]; then
    # shellcheck disable=SC1091
    . "$HOME/molecule-env/bin/activate"
fi

# -----------------------------------------------------------------------------
# YAML helper utilities
# -----------------------------------------------------------------------------
# Read a scalar value from a simple YAML key-value line.
# Supports lines like: key: value  # comment
# Returns an empty string when not found (or default value when provided).
read_yaml_scalar() {
    local file_path="$1"
    local key_name="$2"
    local default_value="${3:-}"

    python3 - "$file_path" "$key_name" "$default_value" <<'PYEOF'
import re
import sys

file_path, key_name, default_value = sys.argv[1:4]
pattern = re.compile(r'^\s*' + re.escape(key_name) + r'\s*:\s*(.*?)\s*(?:#.*)?$')

try:
    with open(file_path, encoding='utf-8') as handle:
        for line in handle:
            match = pattern.match(line)
            if not match:
                continue
            value = match.group(1).strip()
            if value.startswith(('"', "'")) and value.endswith(('"', "'")) and len(value) >= 2:
                value = value[1:-1]
            print(value)
            raise SystemExit(0)
except FileNotFoundError:
    pass

if default_value:
    print(default_value)
PYEOF
}

load_admin_user() {
    local admin_user
    admin_user="$(read_yaml_scalar "$CONFIG_FILE" "admin_user")"

    if [ -z "$admin_user" ]; then
        echo -e "${RED}Error: admin_user is missing from $CONFIG_FILE.${RESET}"
        exit 1
    fi

    echo "$admin_user"
}

read_vault_admin_ssh_public_key() {
    local vault_key
    vault_key="$(read_yaml_scalar "$VAULT_FILE" "vault_admin_ssh_public_key")"
    echo "$vault_key"
}

public_key_line_from_private_key() {
    local private_key_path="$1"

    if [ -f "${private_key_path}.pub" ]; then
        cat "${private_key_path}.pub"
        return 0
    fi

    if command -v ssh-keygen >/dev/null 2>&1; then
        ssh-keygen -y -f "$private_key_path" 2>/dev/null
        return $?
    fi

    return 1
}

private_key_for_public_blob() {
    local target_blob="$1"
    local admin_user_home="$2"
    local candidate_dir candidate_pub candidate_private candidate_blob

    for candidate_dir in "$HOME/.ssh" "$admin_user_home"; do
        [ -d "$candidate_dir" ] || continue

        for candidate_pub in "$candidate_dir"/*.pub; do
            [ -f "$candidate_pub" ] || continue
            candidate_private="${candidate_pub%.pub}"
            [ -f "$candidate_private" ] || continue
            candidate_blob="$(awk '{print $1" "$2}' "$candidate_pub" 2>/dev/null)"
            if [ -n "$target_blob" ] && [ "$candidate_blob" = "$target_blob" ]; then
                echo "$candidate_private"
                return 0
            fi
        done
    done

    return 1
}

write_vault_admin_ssh_public_key() {
    local public_key_line="$1"

    if [ -z "$public_key_line" ]; then
        return 1
    fi

    if [ ! -f "$VAULT_FILE" ]; then
        echo -e "${RED}Error: $VAULT_FILE not found.${RESET}"
        return 1
    fi

    if head -1 "$VAULT_FILE" | grep -q '^\$ANSIBLE_VAULT'; then
        echo -e "${YELLOW}Vault file is encrypted; skipping automatic write to $VAULT_FILE.${RESET}"
        return 0
    fi

    python3 - "$VAULT_FILE" "$public_key_line" <<'PYEOF'
import re
import sys

vault_file = sys.argv[1]
public_key_line = sys.argv[2]
replacement = 'vault_admin_ssh_public_key: "{}"  # auto-synced from ~/.ssh'.format(public_key_line)

with open(vault_file, encoding='utf-8') as handle:
    content = handle.read()

pattern = re.compile(r'^\s*vault_admin_ssh_public_key\s*:\s*.*$', re.MULTILINE)
if pattern.search(content):
    content = pattern.sub(replacement, content, count=1)
else:
    if not content.endswith('\n'):
        content += '\n'
    content += '\n' + replacement + '\n'

with open(vault_file, 'w', encoding='utf-8') as handle:
    handle.write(content)

print('Updated vault_admin_ssh_public_key in {}'.format(vault_file))
PYEOF
}

resolve_inventory_private_key() {
    local domain_name="$1"
    local admin_user="$2"
    local expected_key_path="$HOME/.ssh/${domain_name//./_}"
    local admin_user_home="/home/${admin_user}/.ssh"
    local target_blob source_private_key

    if [ -e "$expected_key_path" ] || [ -L "$expected_key_path" ]; then
        echo "$expected_key_path"
        return 0
    fi

    target_blob="$(read_vault_admin_ssh_public_key)"
    if [ -n "$target_blob" ]; then
        source_private_key="$(private_key_for_public_blob "$target_blob" "$admin_user_home")"
    fi

    if [ -z "$source_private_key" ] && [ -f "$admin_user_home/id_ed25519" ]; then
        source_private_key="$admin_user_home/id_ed25519"
    fi
    if [ -z "$source_private_key" ] && [ -f "$admin_user_home/id_rsa" ]; then
        source_private_key="$admin_user_home/id_rsa"
    fi
    if [ -z "$source_private_key" ] && [ -f "$admin_user_home/private_key" ]; then
        source_private_key="$admin_user_home/private_key"
    fi
    if [ -z "$source_private_key" ] && [ -f "$HOME/.ssh/id_ed25519" ]; then
        source_private_key="$HOME/.ssh/id_ed25519"
    fi
    if [ -z "$source_private_key" ] && [ -f "$HOME/.ssh/id_rsa" ]; then
        source_private_key="$HOME/.ssh/id_rsa"
    fi
    if [ -z "$source_private_key" ] && [ -f "$HOME/.ssh/ansible_id" ]; then
        source_private_key="$HOME/.ssh/ansible_id"
    fi

    if [ -z "$source_private_key" ]; then
        echo -e "${RED}Error: No usable SSH private key found for domain '${domain_name}'.${RESET}"
        echo -e "${YELLOW}Expected inventory key path: ${expected_key_path}${RESET}"
        echo -e "${YELLOW}Checked: ${HOME}/.ssh and /home/${admin_user}/.ssh${RESET}"
        return 1
    fi

    mkdir -p "$HOME/.ssh"
    ln -sfn "$source_private_key" "$expected_key_path"
    chmod 600 "$expected_key_path" 2>/dev/null || true

    echo "$expected_key_path"
    return 0
}

resolve_primary_ansible_host() {
    local host_ip
    host_ip=$(grep -E 'ansible_host:' "$HOSTS_FILE" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"')
    echo "$host_ip"
}

ssh_port_reachable() {
    local host="$1"
    local port="$2"

    if [ -z "$host" ] || [ -z "$port" ]; then
        return 1
    fi

    if command -v timeout >/dev/null 2>&1; then
        timeout 3 bash -c "</dev/tcp/${host}/${port}" >/dev/null 2>&1
    else
        bash -c "</dev/tcp/${host}/${port}" >/dev/null 2>&1
    fi
}

resolve_effective_ssh_port() {
    local configured_port="$1"
    local host_for_probe="$2"

    if [ -z "$configured_port" ]; then
        configured_port="22"
    fi

    if [ -z "$host_for_probe" ]; then
        echo "$configured_port"
        return 0
    fi

    if ssh_port_reachable "$host_for_probe" "$configured_port"; then
        echo "$configured_port"
        return 0
    fi

    if [ "$configured_port" != "22" ] && ssh_port_reachable "$host_for_probe" "22"; then
        echo -e "${YELLOW}Warning:${RESET} SSH port ${configured_port} is unreachable on ${host_for_probe}." >&2
        echo -e "${YELLOW}Using temporary fallback ansible_port=22 for this run to avoid lockout.${RESET}" >&2
        echo "22"
        return 0
    fi

    echo "$configured_port"
    return 0
}

# Display usage information
show_help() {
    echo -e "${BOLD}Usage:${RESET} $0 command module [options]"
    echo
    echo -e "${BOLD}Commands:${RESET}"
    echo "  install      Install components or configurations"
    echo "  create       Create new configurations (like virtual hosts)"
    echo "  remove       Remove configurations or components"
    echo "  sync         Sync local state into config files"
    echo "  db           Database utilities"
    echo
    echo -e "${BOLD}Modules:${RESET}"
    echo "  core         Full server setup (base system, web server, database, etc.)"
    echo "  host         Virtual host management"
    echo "  ssl          SSL certificate management"
    echo "  mariadb      Database server management"
    echo "  keys         SSH public keys (reads ~/.ssh/*.pub → secrets.yml)"
    echo "  tunnel       Open SSH port-forward tunnel (use with: db tunnel)"
    echo
    echo -e "${BOLD}Options:${RESET}"
    echo "  --domain, -d                 Domain name (required for most operations)"
    echo "  --user, -u                   Override system username (default: derived from domain)"
    echo "  --ask-pass                   Ask for SSH password (initial setup)"
    echo "  --ask-vault-pass             Ask for vault password"
    echo "  --vault-password-file=FILE   File containing the vault password"
    echo "  --yes, --assume-yes          Run non-interactively and accept prompts"
    echo "  --help, -h                   Show this help message"
    echo
    echo -e "${BOLD}Examples:${RESET}"
    echo "  $0 install core --domain=yourdomain.com --ask-pass --ask-vault-pass"
    echo "  $0 create host --domain=yourdomain.com --ask-vault-pass"
    echo "  $0 install ssl --domain=yourdomain.com --vault-password-file=~/.vault_pass"
    echo "  $0 sync keys"
    echo "  $0 db tunnel"
}

# Check for Git installation and install if necessary
check_git() {
    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}Git is not installed. Installing Git...${RESET}"
        
        # Detect OS and use appropriate package manager
        if command -v apt &> /dev/null; then
            sudo apt update
            sudo apt install -y git
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y epel-release || true
            sudo dnf install -y git
        elif command -v yum &> /dev/null; then
            sudo yum install -y git
        else
            echo -e "${RED}Unable to detect package manager. Please install Git manually:${RESET}"
            echo "  - For Debian/Ubuntu: sudo apt install -y git"
            echo "  - For RHEL/CentOS: sudo dnf install -y git"
            exit 1
        fi
        
        # Verify installation
        if ! command -v git &> /dev/null; then
            echo -e "${RED}Git installation failed. Please install manually.${RESET}"
            exit 1
        else
            echo -e "${GREEN}Git installed successfully!${RESET}"
        fi
    fi
}

# Check for Ansible installation and offer installation options if missing
check_ansible() {
    if ! command -v ansible-playbook &> /dev/null; then
        echo -e "${RED}Error: Ansible is not installed.${RESET}"
        if [[ -n "$ASSUME_YES" ]]; then
            echo -e "${GREEN}Non-interactive mode: installing Ansible...${RESET}"
            answer="y"
        else
            echo -e "${YELLOW}Would you like to install Ansible now? (y/n)${RESET}"
            read -r answer
        fi

        if [[ "$answer" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}Installing Ansible...${RESET}"
            
            # Detect OS and use appropriate installation method
            if command -v dnf &> /dev/null; then
                # For RHEL/CentOS/Fedora
                echo "Using DNF package manager"
                sudo dnf install -y epel-release || true
                if ! sudo dnf install -y ansible; then
                    echo "DNF installation failed, trying with pip..."
                    if command -v pip3 &> /dev/null; then
                        sudo pip3 install ansible
                    else
                        echo "Installing pip3 first..."
                        sudo dnf install -y python3-pip
                        sudo pip3 install ansible
                    fi
                fi
            elif command -v apt &> /dev/null; then
                sudo apt update
                sudo apt install -y ansible
            elif command -v pip3 &> /dev/null; then
                sudo pip3 install ansible
            elif command -v pip &> /dev/null; then
                sudo pip install ansible
            else
                echo -e "${RED}Unable to detect package manager. Please install Ansible manually:${RESET}"
                echo "  - For RHEL/CentOS: sudo dnf install -y epel-release && sudo dnf install -y ansible"
                echo "  - For Debian/Ubuntu: sudo apt install -y ansible"
                echo "  - Using pip: sudo pip3 install ansible"
                exit 1
            fi
            
            # Verify installation
            if ! command -v ansible-playbook &> /dev/null; then
                echo -e "${RED}Ansible installation failed. Please try installing manually with:${RESET}"
                echo "  sudo pip3 install ansible"
                exit 1
            else
                echo -e "${GREEN}Ansible installed successfully!${RESET}"
            fi
        else
            echo "Please install Ansible manually with one of these commands:"
            echo "  sudo dnf install -y epel-release && sudo dnf install -y ansible"
            echo "  sudo apt install -y ansible"
            echo "  sudo pip3 install ansible"
            exit 1
        fi
    fi
}

# Parse arguments
parse_args() {
    ACTION=""
    MODULE=""
    DOMAIN=""
    USER=""
    ASK_VAULT_PASS=""
    VAULT_PASSWORD_FILE=""
    ASSUME_YES=""

    for arg in "$@"; do
        if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
            show_help
            exit 0
        fi
    done

    while [[ $# -gt 0 ]]; do
        case $1 in
        install | create | remove | sync)
            ACTION="$1"
            shift
            ;;
        core | host | ssl | mariadb | keys | tunnel)
            MODULE="$1"
            shift
            ;;
        db)
            ACTION="$1"
            shift
            ;;
        --domain=* | -d=*)
            DOMAIN="${1#*=}"
            if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
                echo -e "${RED}Error: Invalid domain name '${DOMAIN}'. Only letters, digits, dots, and hyphens are allowed.${RESET}"
                exit 1
            fi
            shift
            ;;
        --user=* | -u=*)
            USER="${1#*=}"
            shift
            ;;
        --ask-pass)
            ASK_SSH_PASS="--ask-pass"
            shift
            ;;
        --ask-vault-pass)
            ASK_VAULT_PASS="--ask-vault-pass"
            shift
            ;;
        --vault-password-file=*)
            VAULT_PASSWORD_FILE="--vault-password-file=${1#*=}"
            shift
            ;;
        --yes|--assume-yes)
            ASSUME_YES="--yes"
            shift
            ;;
        --help | -h)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${RESET}"
            show_help
            exit 1
            ;;
        esac
    done

    if [[ -z "$ACTION" || -z "$MODULE" ]]; then
        echo -e "${RED}Error: Action and module are required.${RESET}"
        show_help
        exit 1
    fi

    if [[ "$MODULE" != "core" && "$MODULE" != "keys" && "$MODULE" != "tunnel" && -z "$DOMAIN" ]]; then
        echo -e "${RED}Error: Domain is required for '$MODULE' operations.${RESET}"
        show_help
        exit 1
    fi

    if [[ -z "$USER" && -n "$DOMAIN" ]]; then
        USER=$(echo "$DOMAIN" | awk -F. '{print $(NF-1)}')
    fi
}

# Create an admin user with passwordless sudo privileges
create_admin_user() {

    local ADMIN_USER
    ADMIN_USER="$(load_admin_user)"
    local sudoers_file="/etc/sudoers.d/${ADMIN_USER}"
    local sudoers_rule="${ADMIN_USER} ALL=(ALL) NOPASSWD:ALL"

    echo -e "${YELLOW}Creating admin user...${RESET}"

    #
    # Create the user if it doesn't exist
    #
    if ! id "$ADMIN_USER" &>/dev/null; then
        if ! sudo useradd -m -s /bin/bash "$ADMIN_USER"; then
            echo -e "${RED}Error: Failed to create user '${ADMIN_USER}'.${RESET}"
            return 1
        fi

        echo -e "${GREEN}User '${ADMIN_USER}' created.${RESET}"
    else
        echo -e "${GREEN}User '${ADMIN_USER}' already exists.${RESET}"
    fi

    #
    # Add to sudo group (Ubuntu / Debian)
    #
    if getent group sudo >/dev/null; then
        if ! id -nG "$ADMIN_USER" | grep -qw sudo; then
            if ! sudo usermod -aG sudo "$ADMIN_USER"; then
                echo -e "${RED}Error: Failed to add '${ADMIN_USER}' to sudo group.${RESET}"
                return 1
            fi
        fi
    fi

    #
    # Add to wheel group (CentOS / Rocky / Alma / RHEL)
    #
    if getent group wheel >/dev/null; then
        if ! id -nG "$ADMIN_USER" | grep -qw wheel; then
            if ! sudo usermod -aG wheel "$ADMIN_USER"; then
                echo -e "${RED}Error: Failed to add '${ADMIN_USER}' to wheel group.${RESET}"
                return 1
            fi
        fi
    fi

    #
    # Configure passwordless sudo
    #
    if [[ ! -f "$sudoers_file" ]]; then

        echo "$sudoers_rule" | sudo tee "$sudoers_file" >/dev/null

        if ! sudo visudo -cf "$sudoers_file" >/dev/null; then
            echo -e "${RED}Error: Invalid sudoers configuration.${RESET}"
            sudo rm -f "$sudoers_file"
            return 1
        fi

        sudo chmod 440 "$sudoers_file"

    elif ! sudo grep -qxF "$sudoers_rule" "$sudoers_file"; then

        echo -e "${YELLOW}Warning:${RESET} ${sudoers_file} already exists with different contents."
        echo -e "${YELLOW}Leaving existing sudoers configuration unchanged.${RESET}"

    fi

    #
    # Verify sudo works
    #
    if ! sudo -l -U "$ADMIN_USER" >/dev/null 2>&1; then
        echo -e "${RED}Error: Failed to verify sudo access for '${ADMIN_USER}'.${RESET}"
        return 1
    fi

    echo -e "${GREEN}Admin user '${ADMIN_USER}' is ready.${RESET}"

    return 0
}

# Generate SSH keys for the configured admin user and ensure authorized_keys
# includes all required public keys without duplicates.
generate_ssh_keys() {

    local ADMIN_USER
    ADMIN_USER="$(load_admin_user)"

    #
    # Validate required variables
    #
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${RED}Error: DOMAIN variable is required.${RESET}"
        return 1
    fi

    #
    # Ensure admin user exists
    #
    if ! id "$ADMIN_USER" &>/dev/null; then
        echo -e "${RED}Error: Admin user '${ADMIN_USER}' does not exist.${RESET}"
        echo -e "${YELLOW}Run create_admin_user first.${RESET}"
        return 1
    fi

    local target_dir="/home/$ADMIN_USER"
    local ssh_dir="$target_dir/.ssh"

    echo -e "${YELLOW}Generating SSH keys for '${ADMIN_USER}'...${RESET}"

    #
    # Create .ssh directory
    #
    if ! sudo mkdir -p "$ssh_dir"; then
        echo -e "${RED}Error: Failed to create ${ssh_dir}.${RESET}"
        return 1
    fi

    sudo chmod 700 "$ssh_dir"
    sudo chown "$ADMIN_USER:$ADMIN_USER" "$ssh_dir"

    #
    # Generate id_rsa only when missing so repeated runs stay idempotent.
    if [ ! -f "$ssh_dir/id_rsa" ]; then
        if ! sudo ssh-keygen \
            -q \
            -t rsa \
            -b 4096 \
            -N "" \
            -C "${DOMAIN} (id_rsa)" \
            -f "$ssh_dir/id_rsa"; then

            echo -e "${RED}Error: Failed to generate id_rsa.${RESET}"
            return 1
        fi
    fi

    # Generate private_key only when missing so repeated runs stay idempotent.
    if [ ! -f "$ssh_dir/private_key" ]; then
        if ! sudo ssh-keygen \
            -q \
            -t rsa \
            -b 4096 \
            -N "" \
            -C "${DOMAIN} (private_key)" \
            -f "$ssh_dir/private_key"; then

            echo -e "${RED}Error: Failed to generate private_key.${RESET}"
            return 1
        fi
    fi

    if [ -f "$ssh_dir/id_rsa" ] && [ ! -f "$ssh_dir/id_rsa.pub" ]; then
        sudo ssh-keygen -y -f "$ssh_dir/id_rsa" | sudo tee "$ssh_dir/id_rsa.pub" >/dev/null || {
            echo -e "${RED}Error: Failed to regenerate id_rsa.pub.${RESET}"
            return 1
        }
    fi

    if [ -f "$ssh_dir/private_key" ] && [ ! -f "$ssh_dir/private_key.pub" ]; then
        sudo ssh-keygen -y -f "$ssh_dir/private_key" | sudo tee "$ssh_dir/private_key.pub" >/dev/null || {
            echo -e "${RED}Error: Failed to regenerate private_key.pub.${RESET}"
            return 1
        }
    fi

    #
    # Create authorized_keys
    #
    sudo touch "$ssh_dir/authorized_keys"

    # Keep existing authorized keys and only add generated keys if missing.
    for pub_file in "$ssh_dir/id_rsa.pub" "$ssh_dir/private_key.pub"; do
        if [ -f "$pub_file" ]; then
            while IFS= read -r key_line; do
                [ -n "$key_line" ] || continue
                grep -qxF "$key_line" "$ssh_dir/authorized_keys" || echo "$key_line" >> "$ssh_dir/authorized_keys"
            done < "$pub_file"
        fi
    done

    # Normalize authorized_keys: remove blank lines and duplicate entries while
    # preserving original order.
    local auth_tmp
    auth_tmp=$(mktemp)
    awk 'NF && !seen[$0]++' "$ssh_dir/authorized_keys" > "$auth_tmp"
    cat "$auth_tmp" > "$ssh_dir/authorized_keys"
    rm -f "$auth_tmp"

    #
    # Permissions
    #
    sudo chmod 700 "$ssh_dir"
    sudo chmod 600 \
        "$ssh_dir/id_rsa" \
        "$ssh_dir/private_key" \
        "$ssh_dir/authorized_keys"

    sudo chmod 644 \
        "$ssh_dir/id_rsa.pub" \
        "$ssh_dir/private_key.pub"

    sudo chown -R "$ADMIN_USER:$ADMIN_USER" "$ssh_dir"

    #
    # Verify generated files
    #
    for file in \
        "$ssh_dir/id_rsa" \
        "$ssh_dir/id_rsa.pub" \
        "$ssh_dir/private_key" \
        "$ssh_dir/private_key.pub" \
        "$ssh_dir/authorized_keys"
    do
        if [[ ! -f "$file" ]]; then
            echo -e "${RED}Error: Missing file: $file${RESET}"
            return 1
        fi
    done

    echo
    echo -e "${GREEN}SSH keys generated successfully.${RESET}"
    echo
    echo "Location:"
    echo "  $ssh_dir"
    echo
    echo "Generated files:"
    echo "  id_rsa"
    echo "  id_rsa.pub"
    echo "  private_key"
    echo "  private_key.pub"
    echo "  authorized_keys"
    echo
    echo "Private keys (copy one of these to your PC):"
    echo "  $ssh_dir/id_rsa"
    echo "  $ssh_dir/private_key"
    echo
    echo "SSH key comments:"
    echo "  ${DOMAIN} (id_rsa)"
    echo "  ${DOMAIN} (private_key)"

    # Keep secrets.yml in sync with the newly generated admin key.
    # Always replace vault_admin_ssh_public_key after successful key generation.
    local preferred_public_key=""
    if [ -f "$ssh_dir/id_rsa.pub" ]; then
        preferred_public_key="$(cat "$ssh_dir/id_rsa.pub")"
    elif [ -f "$ssh_dir/private_key.pub" ]; then
        preferred_public_key="$(cat "$ssh_dir/private_key.pub")"
    fi

    if [ -z "$preferred_public_key" ]; then
        echo -e "${RED}Error: Failed to determine generated public key for ${ADMIN_USER}.${RESET}"
        echo -e "${YELLOW}Expected one of:${RESET} $ssh_dir/id_rsa.pub or $ssh_dir/private_key.pub"
        return 1
    fi

    write_vault_admin_ssh_public_key "$preferred_public_key" || return 1
    echo -e "${GREEN}Replaced vault_admin_ssh_public_key in $VAULT_FILE with newly generated key${RESET}"

    return 0
}

# Sync SSH public keys from ~/.ssh/*.pub into vault_admin_ssh_public_key in secrets.yml
sync_keys() {
    local secrets_file="$PROJECT_ROOT/vars/secrets.yml"

    if [ ! -f "$secrets_file" ]; then
        echo -e "${RED}Error: $secrets_file not found.${RESET}"
        exit 1
    fi

    if head -1 "$secrets_file" | grep -q '^\$ANSIBLE_VAULT'; then
        echo -e "${RED}secrets.yml is encrypted. Decrypt it first:${RESET}"
        echo -e "  ansible-vault decrypt vars/secrets.yml"
        exit 1
    fi

    local tmp_keys
    tmp_keys=$(mktemp)

    for pub_file in "$HOME"/.ssh/*.pub; do
        [ -f "$pub_file" ] || continue
        # skip the ansible self-connect key (not a login key)
        [[ "$pub_file" == *ansible_id.pub ]] && continue
        while IFS= read -r line; do
            [[ "$line" =~ ^(ssh-|ecdsa-|sk-) ]] || continue
            echo "$line" >> "$tmp_keys"
        done < "$pub_file"
    done

    if [ ! -s "$tmp_keys" ]; then
        echo -e "${RED}No public keys found in ~/.ssh/*.pub${RESET}"
        rm -f "$tmp_keys"
        exit 1
    fi

    python3 << PYEOF
import re

secrets_file = "$secrets_file"
tmp_keys = "$tmp_keys"

with open(tmp_keys) as f:
    keys = [line.strip() for line in f if line.strip()]

with open(secrets_file) as f:
    content = f.read()

if len(keys) == 1:
    new_val = 'vault_admin_ssh_public_key: "{}"  # auto-synced from ~/.ssh'.format(keys[0])
else:
    key_lines = '\n'.join('  - "{}"'.format(k) for k in keys)
    new_val = 'vault_admin_ssh_public_key:\n' + key_lines

content = re.sub(
    r'^vault_admin_ssh_public_key:[^\n]*(?:\n  - [^\n]+)*',
    new_val,
    content,
    flags=re.MULTILINE
)

with open(secrets_file, 'w') as f:
    f.write(content)

print('Updated vault_admin_ssh_public_key with {} key(s):'.format(len(keys)))
for k in keys:
    print('  ' + k[:72] + ('...' if len(k) > 72 else ''))
PYEOF

    local exit_code=$?
    rm -f "$tmp_keys"

    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}secrets.yml updated. Run the playbook to sync keys to the server:${RESET}"
        echo -e "  ${BOLD}./vps.sh install core --domain=\$DOMAIN${RESET}"
    else
        echo -e "${RED}Failed to update secrets.yml${RESET}"
        exit 1
    fi
}

# Pull latest code from git remote before running Ansible
git_pull() {
    if git -C "$PROJECT_ROOT" rev-parse --git-dir &>/dev/null; then
        echo -e "${GREEN}Pulling latest code from git...${RESET}"
        # Stash any local modifications (network-mount write-backs) so pull always succeeds
        local stash_output
        stash_output=$(git -C "$PROJECT_ROOT" stash 2>&1)
        if echo "$stash_output" | grep -q "Saved working directory"; then
            echo -e "${YELLOW}Stashed local changes: $stash_output${RESET}"
        fi
        if ! git -C "$PROJECT_ROOT" pull --ff-only 2>&1; then
            echo -e "${YELLOW}Warning: git pull failed (diverged branch). Continuing with current code.${RESET}"
        fi
    fi
}

# Open an SSH tunnel to MariaDB on the remote server so clients can connect locally.
# Usage: ./vps.sh db tunnel [--local-port=PORT]
db_tunnel() {
    local hosts_file="$PROJECT_ROOT/inventory/hosts.yml"
    local all_vars="$PROJECT_ROOT/inventory/group_vars/all.yml"

    local server_ip
    server_ip=$(grep -E 'ansible_host:' "$hosts_file" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"')
    if [ -z "$server_ip" ]; then
        server_ip="<server-ip>"
    fi

    # Read admin_user from all.yml (ansible_user in hosts.yml is a Jinja2 reference)
    local server_user
    server_user=$(grep -E '^admin_user:' "$all_vars" 2>/dev/null | awk '{print $2}' | tr -d '"')
    [ -z "$server_user" ] && server_user="admin"

    # Find the actual SSH key name from exported .pub files in ~/.ssh/ (set by bootstrap.sh)
    local ssh_key
    ssh_key=$(ls "$HOME"/.ssh/*.pub 2>/dev/null | grep -v 'ansible_id\.pub' | head -1 | xargs -I{} basename {} .pub 2>/dev/null)
    [ -z "$ssh_key" ] && ssh_key=$(awk '/ansible_host:/{print prev} {prev=$0}' "$hosts_file" 2>/dev/null | head -1 | tr -d ': ' | tr '.-' '_' | tr -dc '[:alnum:]_')
    [ -z "$ssh_key" ] && ssh_key="vps"

    local db_port
    db_port=$(grep -E '^db_port:' "$all_vars" 2>/dev/null | awk '{print $2}' | tr -d '"')
    [ -z "$db_port" ] && db_port="3307"

    local local_port="${DB_LOCAL_PORT:-${db_port}}"

    log "${GREEN}${BOLD}MariaDB SSH Tunnel${RESET}"
    log "  Server:     ${server_ip}"
    log "  Remote DB:  127.0.0.1:${db_port}  (bound to loopback only)"
    log "  Local port: ${local_port}"
    log ""
    log "${BOLD}Run this on your client machine (Windows/Linux/Mac):${RESET}"
    log "  ssh -N -L ${local_port}:127.0.0.1:${db_port} -i ~/.ssh/${ssh_key} ${server_user}@${server_ip}"
    log ""
    log "${BOLD}Then connect to MariaDB:${RESET}"
    log "  mysql -h 127.0.0.1 -P ${local_port} -u <dbuser> -p"
    log ""
    log "${YELLOW}Note: SSH TCP forwarding must be enabled (AllowTcpForwarding local/yes in sshd_config).${RESET}"
    log "${YELLOW}      Current setting: $(grep AllowTcpForwarding /etc/ssh/sshd_config 2>/dev/null | head -1 | awk '{print $2}')${RESET}"
}




# Prepare SSH prerequisites for Ansible:
# 1) ensure inventory-derived private key path exists
# 2) keep vault_admin_ssh_public_key synced with selected key
setup_ssh_config() {
    local ADMIN_USER
    ADMIN_USER="$(load_admin_user)"

    if [[ -z "$DOMAIN" ]]; then
        return 0
    fi

    local selected_private_key selected_public_key
    selected_private_key="$(resolve_inventory_private_key "$DOMAIN" "$ADMIN_USER")" || return 1
    selected_public_key="$(public_key_line_from_private_key "$selected_private_key")" || return 1

    if [ -n "$selected_public_key" ]; then
        write_vault_admin_ssh_public_key "$selected_public_key" || return 1
        echo -e "${GREEN}Replaced vault_admin_ssh_public_key in $VAULT_FILE from setup_ssh_config${RESET}"
    fi

    echo -e "${GREEN}SSH config prepared:${RESET} $selected_private_key"
    return 0
}

# Run the appropriate Ansible playbook
run_ansible() {
    start_time=$(date +%s)
    
    # Ensure logs directory exists (failsafe in case bootstrap was skipped)
    if [ ! -d "$PROJECT_ROOT/logs" ]; then
        mkdir -p "$PROJECT_ROOT/logs"
        echo -e "${YELLOW}Created missing logs directory: $PROJECT_ROOT/logs${RESET}"
    fi

    timestamp=$(date '+%Y%m%d_%H%M%S')
    log_file="$PROJECT_ROOT/logs/vps-${ACTION}-${MODULE}-${timestamp}.log"
    
    log "${GREEN}Starting operation: $ACTION $MODULE for domain $DOMAIN${RESET}"
    log "Command log: $log_file"

    local configured_ssh_port effective_ssh_port target_host
    configured_ssh_port="$(read_yaml_scalar "$CONFIG_FILE" "ssh_port" "22")"
    target_host="$(resolve_primary_ansible_host)"
    if [ -z "$target_host" ]; then
        target_host="$DOMAIN"
    fi
    effective_ssh_port="$(resolve_effective_ssh_port "$configured_ssh_port" "$target_host")"

    # Keep server SSH configuration aligned with inventory ssh_port, but use
    # ansible_port for temporary controller connectivity fallback.
    extra_vars=(
        -e "domain=${DOMAIN}"
        -e "user=${USER}"
        -e "ssh_port=${configured_ssh_port}"
        -e "ansible_port=${effective_ssh_port}"
    )

    case "$ACTION $MODULE" in
    "install core")
        playbook="playbooks/setup.yml"
        ;;
    "create host")
        playbook="playbooks/create_vhost.yml"
        ;;
    "remove host")
        playbook="playbooks/remove_vhost.yml"
        ;;
    "install ssl")
        playbook="playbooks/ssl.yml"
        ;;
    *)
        echo -e "${RED}Error: Unsupported action-module combination: $ACTION $MODULE${RESET}"
        exit 1
        ;;
    esac

    VAULT_OPTS=""
    if [[ -n "$ASK_VAULT_PASS" ]]; then
        VAULT_OPTS="$ASK_VAULT_PASS"
    elif [[ -n "$VAULT_PASSWORD_FILE" ]]; then
        VAULT_OPTS="$VAULT_PASSWORD_FILE"
    fi

    # Tags: run only setup-tagged tasks for full `install core` operations
    TAGS_OPTS=""
    if [[ "$ACTION" == "install" && "$MODULE" == "core" ]]; then
        TAGS_OPTS="--tags setup"
    fi
    # Log the full command being executed
    {
        echo "========================================"
        echo "VPS Operation Log"
        echo "========================================"
        echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Action: $ACTION $MODULE"
        echo "Domain: $DOMAIN"
        echo "User: $USER"
        echo "Command: ansible-playbook $playbook ${extra_vars[*]} $ASK_SSH_PASS $VAULT_OPTS $TAGS_OPTS"
        echo "Configured ssh_port: ${configured_ssh_port}"
        echo "Effective ansible_port for this run: ${effective_ssh_port}"
        echo "Probe target host: ${target_host}"
        echo "========================================"
        echo ""
    } > "$log_file"

    # Run ansible-playbook with output tee'd to log file
    # Use absolute playbook path so the script works regardless of current working directory
    playbook_path="$PROJECT_ROOT/$playbook"
    ansible-playbook "$playbook_path" "${extra_vars[@]}" $ASK_SSH_PASS $VAULT_OPTS $TAGS_OPTS 2>&1 | tee -a "$log_file"
    
    ansible_exit_code=${PIPESTATUS[0]}

    end_time=$(date +%s)
    duration=$((end_time - start_time))
    minutes=$((duration / 60))
    seconds=$((duration % 60))

    # Append summary to log file
    {
        echo ""
        echo "========================================"
        echo "Operation Summary"
        echo "========================================"
        echo "Exit Code: $ansible_exit_code"
        echo "Duration: ${minutes}m ${seconds}s"
        echo "Completed: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "========================================"
    } >> "$log_file"

    if [ $ansible_exit_code -eq 0 ]; then
        log "${GREEN}Operation completed successfully in ${minutes}m ${seconds}s${RESET}"
        log "${GREEN}Full log saved to: $log_file${RESET}"

        # Auto-run SSL setup after install core or create host (only for .test dev domains)
        if [[ "$ACTION $MODULE" == "install core" || "$ACTION $MODULE" == "create host" ]] && [[ -n "$DOMAIN" ]]; then
            tld="${DOMAIN##*.}"
            if [[ "$tld" == "test" ]]; then
                log "${GREEN}Dev domain (.test) — auto-running SSL setup for ${DOMAIN}...${RESET}"
                ssl_log_file="$PROJECT_ROOT/logs/vps-install-ssl-${timestamp}.log"
                {
                    echo "========================================"
                    echo "VPS SSL Auto-run Log"
                    echo "========================================"
                    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
                    echo "Domain: $DOMAIN"
                    echo "========================================"
                    echo ""
                } > "$ssl_log_file"
                ansible-playbook "$PROJECT_ROOT/playbooks/ssl.yml" \
                    -e "domain=${DOMAIN}" -e "user=${USER}" \
                    $ASK_SSH_PASS $VAULT_OPTS 2>&1 | tee -a "$ssl_log_file"
                ssl_exit_code=${PIPESTATUS[0]}
                if [ $ssl_exit_code -eq 0 ]; then
                    log "${GREEN}SSL setup completed.${RESET}"
                    ca_cert="$PROJECT_ROOT/temp/${DOMAIN}-local-ca.crt"
                    log "${YELLOW}CA cert fetched → import for green HTTPS in your browser:${RESET}"
                    log "  ${BOLD}File: $ca_cert${RESET}"
                    log "  ${BOLD}Windows:${RESET} Double-click → Install → Local Machine → Trusted Root Certification Authorities"
                    log "  ${BOLD}Firefox:${RESET} Settings → Privacy & Security → View Certificates → Authorities → Import"
                else
                    log "${YELLOW}SSL setup failed (exit $ssl_exit_code). Run manually: ./vps.sh install ssl --domain=${DOMAIN}${RESET}"
                    log "${YELLOW}SSL log: $ssl_log_file${RESET}"
                fi
            else
                log "${YELLOW}Production domain — run SSL separately when ready:${RESET}"
                log "  ${BOLD}./vps.sh install ssl --domain=${DOMAIN}${RESET}"
            fi
        fi
    else
        log "${RED}Operation failed with exit code $ansible_exit_code${RESET}"
        log "${RED}Check log for details: $log_file${RESET}"
        exit $ansible_exit_code
    fi
}

# Main function
main() {
    check_git
    parse_args "$@"
    if [[ "$ACTION" == "sync" && "$MODULE" == "keys" ]]; then
        sync_keys
        exit 0
    fi
    if [[ "$ACTION" == "db" && "$MODULE" == "tunnel" ]]; then
        db_tunnel
        exit 0
    fi
    create_admin_user || exit 1
    generate_ssh_keys || exit 1
    setup_ssh_config || exit 1
    check_ansible
    # git_pull
    run_ansible
}

main "$@"

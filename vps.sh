#!/usr/bin/env bash

# Define paths
PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CONFIG_FILE="$PROJECT_ROOT/inventory/group_vars/all.yml"
VAULT_FILE="$PROJECT_ROOT/vars/secrets.yml"

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
        if ! git -C "$PROJECT_ROOT" pull --ff-only 2>&1; then
            echo -e "${YELLOW}Warning: git pull failed (local changes or diverged branch). Continuing with current code.${RESET}"
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

    extra_vars="domain=$DOMAIN user=$USER"

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
        echo "Command: ansible-playbook $playbook -e \"$extra_vars\" $ASK_SSH_PASS $VAULT_OPTS $TAGS_OPTS"
        echo "========================================"
        echo ""
    } > "$log_file"

    # Run ansible-playbook with output tee'd to log file
    # Use absolute playbook path so the script works regardless of current working directory
    playbook_path="$PROJECT_ROOT/$playbook"
    ansible-playbook "$playbook_path" -e "$extra_vars" $ASK_SSH_PASS $VAULT_OPTS $TAGS_OPTS 2>&1 | tee -a "$log_file"
    
    ansible_exit_code=${PIPESTATUS[0]}

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
    check_ansible
    git_pull
    run_ansible
}

main "$@"

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
    echo
    echo -e "${BOLD}Modules:${RESET}"
    echo "  core         Full server setup (base system, web server, database, etc.)"
    echo "  host         Virtual host management"
    echo "  ssl          SSL certificate management"
    echo "  mariadb      Database server management"
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
        install | create | remove)
            ACTION="$1"
            shift
            ;;
        core | host | ssl | mariadb)
            MODULE="$1"
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

    if [[ "$MODULE" != "core" && -z "$DOMAIN" ]]; then
        echo -e "${RED}Error: Domain is required for '$MODULE' operations.${RESET}"
        show_help
        exit 1
    fi

    if [[ -z "$USER" && -n "$DOMAIN" ]]; then
        USER=$(echo "$DOMAIN" | awk -F. '{print $(NF-1)}')
    fi
}

# Run the appropriate Ansible playbook
run_ansible() {
    start_time=$(date +%s)
    
    # Ensure logs directory exists
    mkdir -p "$PROJECT_ROOT/logs"
    
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
    ansible-playbook "$playbook" -e "$extra_vars" $ASK_SSH_PASS $VAULT_OPTS $TAGS_OPTS 2>&1 | tee -a "$log_file"
    
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
    check_ansible
    run_ansible
}

main "$@"

#!/usr/bin/env bash

# Text formatting
BOLD="\e[1m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

# Repository URL
REPO_URL="https://github.com/luciancurteanu/vps.git"
REPO_DIR="vps"

echo -e "${BOLD}VPS Setup Bootstrap${RESET}"
echo "This script will prepare your server for VPS setup."
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
        sudo apt install -y curl wget rsync sshpass
    elif [ "$OS_TYPE" = "rhel" ]; then
        sudo $PKG_MGR install -y curl wget rsync sshpass
    fi
    
    echo -e "${GREEN}Essential tools installed.${RESET}"
}

# Clone the repository
clone_repo() {
    echo -e "${YELLOW}Cloning VPS setup repository...${RESET}"
    
    if [ -d "$REPO_DIR" ]; then
        echo -e "${YELLOW}Directory $REPO_DIR already exists.${RESET}"
        read -p "Do you want to update it? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$REPO_DIR"
            git pull
            cd ..
            echo -e "${GREEN}Repository updated.${RESET}"
        fi
    else
        git clone "$REPO_URL" "$REPO_DIR"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Repository cloned successfully.${RESET}"
        else
            echo -e "${RED}Failed to clone repository. Please check the URL and your network connection.${RESET}"
            exit 1
        fi
    fi
}

# Make scripts executable
make_executable() {
    echo -e "${YELLOW}Making scripts executable...${RESET}"
    chmod +x "$REPO_DIR/vps.sh"
    chmod +x "$REPO_DIR/bootstrap.sh"
    echo -e "${GREEN}Scripts are now executable.${RESET}"
}

# Main function
main() {
    install_git
    clone_repo
    make_executable
    
    echo -e "${GREEN}${BOLD}Bootstrap complete!${RESET}"
    echo -e "You can now navigate to the vps directory and run the setup script:"
    echo -e "${BOLD}cd $REPO_DIR${RESET}"
    echo -e "${BOLD}./vps.sh install core --domain=yourdomain.com --ask-vault-pass${RESET}"
}

# Run main function
main
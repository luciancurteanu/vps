#!/usr/bin/env bash

# Text formatting
BOLD="\e[1m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

# Repository URL - update this with your actual repository URL
REPO_URL="https://github.com/luciancurteanu/vps.git"
REPO_DIR="vps"

echo -e "${BOLD}VPS Setup Bootstrap${RESET}"
echo "This script will prepare your server for VPS setup."

# Install Git
install_git() {
    echo -e "${YELLOW}Checking for Git...${RESET}"
    if ! command -v git &> /dev/null; then
        echo -e "Git is not installed. Installing Git..."
        
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
    else
        echo -e "${GREEN}Git is already installed.${RESET}"
    fi
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
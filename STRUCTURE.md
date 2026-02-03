# VPS Setup Project Structure

This document provides an overview of the VPS Setup project structure to help contributors understand the codebase organization.

## Directory Structure

```
vps/
├── ansible.cfg                 # Ansible configuration file
├── bootstrap.sh                # Bootstrap script for new installations
├── CONTRIBUTING.md             # Contribution guidelines
├── encrypt-vault.sh            # Utility to encrypt vault files
├── LICENSE                     # MIT license file
├── README.md                   # Main project documentation
├── STRUCTURE.md                # This file, explaining project structure
├── update-vm-hosts.sh          # Update VM hosts configuration
├── vps.sh                      # Main command-line interface script
├── vps.md                      # VPS shell script documentation
├── .gitignore                  # Git exclusion patterns
├── docs/                       # Documentation
│   ├── BEGINNER-GUIDE.md       # Comprehensive beginner's guide
│   ├── molecule-deploy-setup.md # Molecule testing setup guide
│   ├── role-readme-template.md # Template for role documentation
│   ├── testing-completion-summary.md # Test status tracking
│   └── usage-examples.md       # Usage examples
├── inventory/                  # Ansible inventory configuration
│   ├── hosts                   # Local host definitions for Ansible 
│   ├── hosts.example           # Example host configuration
│   ├── README.md               # Inventory documentation
│   └── group_vars/             # Group variables for hosts
│       ├── all.yml             # Global variables for all hosts
│       └── webservers.yml      # Variables specific to web servers
├── playbooks/                  # Standalone Ansible playbooks
│   ├── create_vhost.yml        # Playbook for creating virtual hosts
│   ├── README.md               # Playbooks documentation
│   ├── remove_vhost.yml        # Playbook for removing virtual hosts
│   ├── setup.yml               # Main setup playbook
│   ├── site_management.yml     # Site management playbook
│   └── ssl.yml                 # SSL certificate management playbook
├── roles/                      # Ansible roles for different components
│   ├── cockpit/                # Cockpit control panel
│   ├── common/                 # Base system configuration
│   ├── development/            # Development tools installation
│   ├── goproxy/                # GoProxy with Tor integration
│   ├── mail/                   # Mail server (Postfix, Dovecot, etc.)
│   ├── mariadb/                # MariaDB database server
│   ├── nginx/                  # Nginx web server
│   ├── php/                    # PHP-FPM configuration
│   ├── python/                 # Python utilities
│   └── security/               # Security hardening
├── scripts/                    # Automation scripts
│   ├── ci-setup.sh             # CI environment setup (Docker, Molecule)
│   ├── README.md               # Scripts documentation
│   ├── reset-molecule-environment.sh # Reset testing environment
│   ├── resume-deployment.sh    # Resume interrupted deployments
│   ├── run-test.ps1            # Windows wrapper for running tests
│   ├── run-test.sh             # Primary Molecule test runner
│   └── vm-launcher/            # VM automation tools
│       ├── run-vm.ps1          # PowerShell VM launcher
│       └── Binary/             # Fallback mkisofs binaries
├── templates/                  # Global templates
│   ├── README.md               # Templates documentation
│   ├── nginx/                  # Nginx templates
│   ├── php/                    # PHP templates
│   └── website/                # Website templates
└── vars/                       # Global variables
    ├── README.md               # Variables documentation
    ├── secrets.yml             # Encrypted secrets (vault file)
    └── secrets.yml.example     # Example secrets file structure
```

## Key Components

### Main Script

- `vps.sh`: The main command-line interface script that provides a friendly user interface to the Ansible playbooks.

### Scripts

- `scripts/ci-setup.sh`: Automated CI environment setup - installs Docker, creates Python venv, installs Molecule dependencies
- `scripts/run-test.sh`: Primary test runner with auto-install capability
- `scripts/run-test.ps1`: Windows PowerShell wrapper that SSHs to VM and runs tests
- `scripts/reset-molecule-environment.sh`: Resets/cleans the Molecule testing environment
- `scripts/vm-launcher/run-vm.ps1`: PowerShell VM launcher for automated AlmaLinux VM creation and configuration

### Bootstrap

- `bootstrap.sh`: Used for setting up the environment on a fresh system installation. Installs Git, clones the repository, and makes scripts executable.

### Example Configuration Files

The repository includes example configuration files to guide setup without exposing sensitive information:

- `inventory/hosts.yml.example`: Example server inventory configuration
- `vars/secrets.yml.example`: Template for Ansible vault variables showing expected structure
These files should be copied (removing the `.example` extension) and customized with actual configuration values.

### Playbooks

- `playbooks/setup.yml`: Main playbook that sets up a complete server with all components.
- `playbooks/create_vhost.yml`: Creates a new virtual host configuration.
- `playbooks/remove_vhost.yml`: Removes an existing virtual host.
- `playbooks/ssl.yml`: Manages SSL certificates for domains.

### Roles

Each role has a standardized structure:
- `defaults/main.yml`: Default variables
- `tasks/main.yml`: Main tasks
- `templates/`: Role-specific templates
- `handlers/main.yml`: Event handlers
- `README.md`: Role documentation

#### Core Roles

- **common**: Base system configuration including users, SSH, and system limits
- **security**: Firewall, fail2ban, and security hardening
- **nginx**: Web server configuration
- **php**: PHP-FPM setup with per-domain pools
- **mariadb**: Database server installation and optimization

#### Special Roles

- **mail**: Complete mail server stack (Postfix, Dovecot, OpenDKIM, Roundcube)
- **development**: Development tools (Node.js, Composer, Laravel)
- **cockpit**: Modern control panel for web-based administration
- **goproxy**: GoProxy with Tor support for privacy

### Global Templates

- `templates/nginx/vhost.conf.j2`: Template for Nginx virtual host configurations
- `templates/php/pool.conf.j2`: Template for PHP-FPM pool configurations
- `templates/website/`: Default website templates

### Variables

- `inventory/group_vars/all.yml`: Global variables for all hosts
- `vars/secrets.yml`: Encrypted secrets (using Ansible Vault)
- `vars/secrets.yml.example`: Template showing the structure of the vault file

## Development Workflow

1. Modify relevant roles or playbooks
2. Test changes in a development environment
3. Update documentation
4. Create a pull request

## File Management Conventions

- **Example Files**: Configuration templates have `.example` extensions
- **Vault Files**: Sensitive data is stored in `*.yml` files encrypted with Ansible Vault
- **Ignored Files**: The `.gitignore` file prevents committing sensitive information
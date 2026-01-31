# VPS Setup

An Ansible-based automation toolkit for setting up and managing virtual private servers with a complete web, database, and mail stack.

## Features

- **Complete Server Setup**: One-command deployment of a full-featured LEMP stack (Linux, Nginx, MariaDB, PHP)
- **Virtual Host Management**: Easy creation and removal of virtual hosts with proper configurations
- **Mail Server**: Integrated mail server with Postfix, Dovecot, and Roundcube webmail
- **SSL Automation**: Automatic SSL certificate issuance and renewal using Let's Encrypt
- **Security Hardening**: System security configuration including firewall, fail2ban, and SSH hardening
- **Web Automation**: Python utilities, Chrome, and ChromeDriver for web scraping and browser automation
- **Control Panel**: Webmin installation and configuration for web-based administration
- **Multi-domain Support**: Manage multiple domains on a single server
- **Development Tools**: Optional installation of developer tools (Composer, Laravel, Node.js)
- **Proxy Services**: Integrated GoProxy with Tor support for privacy and censorship circumvention
- **Secure Password Management**: Centralized password management using Ansible Vault

## Quick Bootstrap for Fresh Servers

For setting up on a completely fresh OS installation, use our bootstrap script:

```bash
# For CentOS/RHEL systems, install curl first if needed
dnf install -y curl

# Download the bootstrap script
curl -O https://raw.githubusercontent.com/luciancurteanu/vps/master/bootstrap.sh

# Make it executable
chmod +x bootstrap.sh

# Run the bootstrap script
./bootstrap.sh
```

This script will:
1. Install Git if it's not already available
2. Clone the VPS setup repository
3. Make all necessary scripts executable

After bootstrap is complete, navigate to the repository directory and proceed with installation:

```bash
cd vps
./vps.sh install core --domain=yourdomain.com --ask-vault-pass
```

## Ansible Implementation

This project provides an Ansible-based implementation with:

- A declarative approach to server configuration
- Enhanced maintainability through modular roles
- Idempotent execution for reliable deployments
- Flexible configuration with variable management

## Requirements

- CentOS 9 Stream or compatible RHEL-based distribution (some support for Debian/Ubuntu)
- Ansible 2.9 or higher on the control machine
- SSH access to the target server with root or sudo privileges
- Valid domain name(s) with DNS pointing to your server

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/luciancurteanu/vps.git
   cd vps
   ```

2. Configure your inventory:
   ```
   cp inventory/hosts.example inventory/hosts
   ```
   Edit `inventory/hosts` and add your server details using the example file as a template.

3. Create vault file for secrets (strongly recommended):
   ```
   ansible-vault create vars/secrets.yml
   ```
   Add passwords and other sensitive information to this file. See `vars/secrets.yml.example` for the expected format.

## Configuration Example Files

The repository includes several example files to guide your configuration:

- `inventory/hosts.example` - Example server inventory configuration
- `vars/secrets.yml.example` - Template for Ansible vault variables


Copy these example files (removing the `.example` extension) and customize them with your actual configuration values.

## Usage

### Basic Server Setup

To set up a complete server with all components:

```bash
# Run with password prompt for vault
./vps.sh install core --domain=vps.test --ask-vault-pass

# Or using a vault password file
./vps.sh install core --domain=vps.test --vault-password-file=~/.vault_pass
```

This will install and configure:
- Base system with security hardening
- **Swap configuration (2GB)** - Critical for preventing OOM issues
- **Webmin control panel** - Installed FIRST with memory optimizations
- Nginx web server
- PHP-FPM
- MariaDB database server
- Mail server (Postfix, Dovecot, OpenDKIM, Roundcube)
- SSL certificates

**IMPORTANT**: Webmin is now installed automatically as part of the core setup with proper memory management. Do NOT manually install Webmin before running this command, as it may cause memory issues on low-RAM systems.

### Virtual Host Management

Our virtual host management supports two types of domains:
- **Master Domain**: The primary domain that hosts the control panel, mail server, and proxy services
- **Regular Domains**: Additional domains hosted on the same server

By default, the first domain you set up with `install core` becomes your master domain. The system automatically configures:

- Complete user and domain setup
- PHP-FPM pool configuration specific to each domain
- Nginx virtual host configuration
- SFTP access with proper chroot configuration (for master domain only)
- Proper permissions for different file types (PHP vs non-PHP)
- Mail configuration for each domain (Postfix, OpenDKIM)
- Directory structure with logs, tmp, backup, and ssl directories

#### Creating the Master Domain:
```bash
# This first domain automatically becomes your master domain
./vps.sh install core --domain=vps.test
```

#### Adding Regular Domains:
```bash
# Regular domain configurations automatically detect they're not the master
./vps.sh create host --domain=secondary.com
```

#### Explicitly Setting Master Domain:
If you need to specify which domain is the master domain (for advanced setups):
```bash
# Override which domain is considered the master
./vps.sh create host --domain=newdomain.com --extra-vars "master_domain=vps.test"
```

#### Removing a Domain:
```bash
./vps.sh remove host --domain=olddomain.com
```

### SSL Certificate Management

Install SSL certificate for a domain:

```bash
   ./vps.sh install ssl --domain=vps.test

### Database Management

Create a new database and user:

```bash
./vps.sh create database --domain=vps.test --dbname=mydb
```

### Additional Options

The setup script supports various options:

```bash
./vps.sh --help
```

This displays all available commands, modules, and options:

```
Usage: ./vps.sh command module [options]

Commands:
  install      Install components or configurations
  create       Create new configurations (like virtual hosts)
  remove       Remove configurations or components

Modules:
  core         Full server setup (base system, web server, database, etc.)
  host         Virtual host management
  ssl          SSL certificate management
  mariadb      Database server management

Options:
  --domain, -d                 Domain name (required for most operations)
  --user, -u                   Override system username (default: derived from domain)
  --ask-vault-pass             Ask for vault password
  --vault-password-file=FILE   File containing the vault password
  --help, -h                   Show this help message

Examples:
   ./vps.sh install core --domain=vps.test
   ./vps.sh create host --domain=vps.test --ask-vault-pass
   ./vps.sh install ssl --domain=vps.test --vault-password-file=~/.vault_pass
```

## Project Structure

The project follows a modular structure based on Ansible best practices:

```
vps/
├── ansible.cfg                 # Ansible configuration file
├── bootstrap.sh                # Bootstrap script for new installations
├── CONTRIBUTING.md             # Contribution guidelines
├── LICENSE                     # MIT license file
├── README.md                   # Main project documentation
├── STRUCTURE.md                # Detailed structure documentation
├── vps.sh                      # Main command-line interface script
├── .gitignore                  # Git exclusion patterns
├── inventory/                  # Ansible inventory configuration
│   ├── hosts                   # Local host definitions for Ansible 
│   ├── hosts.example           # Example host configuration
│   └── group_vars/             # Variables for groups of hosts
│       ├── all.yml             # Global variables for all hosts
│       └── webservers.yml      # Variables specific to web servers
├── playbooks/                  # Standalone Ansible playbooks
│   ├── create_vhost.yml        # Create virtual host configuration
│   ├── remove_vhost.yml        # Remove virtual host configuration
│   ├── setup.yml               # Main setup playbook
│   └── ssl.yml                 # SSL certificate management
├── roles/                      # Ansible roles for different components
│   ├── common/                 # Base system configuration
│   ├── development/            # Development tools
│   ├── goproxy/                # GoProxy with Tor integration
│   ├── mail/                   # Mail server stack
│   ├── mariadb/                # MariaDB database server
│   ├── nginx/                  # Nginx web server
│   ├── php/                    # PHP-FPM configuration
│   ├── python/                 # Python utilities
│   ├── security/               # Security hardening
│   └── webmin/                 # Webmin control panel
├── templates/                  # Global templates
│   ├── nginx/                  # Nginx templates
│   ├── php/                    # PHP templates
│   └── website/                # Website templates
└── vars/                       # Global variables
    ├── secrets.yml             # Encrypted secrets (vault file)
    └── secrets.yml.example     # Example secrets file
```

## Quick Reference

### Common Tasks

1. **Setting up a new website**:
   ```bash
   # Set up core server components
   ./vps.sh install core --domain=vps.test
   
   # Create a virtual host for a new domain
   ./vps.sh create host --domain=newsite.com
   
   # Install SSL for the new domain
   ./vps.sh install ssl --domain=newsite.com
   ```

2. **Removing a website**:
   ```bash
   ./vps.sh remove host --domain=oldsite.com
   ```

## Security Features

The VPS setup includes several security-focused features:

- Firewall configuration with restricted access
- Fail2ban integration for blocking malicious attempts
- SSH hardening with key-based authentication
- System resource limits to prevent DoS attacks
- Security-enhanced PHP configuration
- SSL/TLS enforcement for all services

## Customization

You can customize the deployment by editing the variables in:
- `inventory/group_vars/all.yml` - Global configuration variables
- `roles/*/defaults/main.yml` - Role-specific default variables

## Troubleshooting

If you encounter issues during installation or operation:

1. Check the Ansible logs for detailed error messages
2. Verify that all required ports are open on your server
3. Ensure DNS records are correctly configured for your domains
4. Check service status with `systemctl status [service-name]`

## Contributing

Contributions are welcome! Please refer to [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Security Best Practices

This project handles sensitive information such as passwords and server details. To maintain security:

1. **Never commit sensitive files**: Real configuration files containing passwords or server details should never be committed to Git
2. **Use Ansible Vault**: Encrypt secrets using `ansible-vault create vars/secrets.yml`
3. **Create configurations from examples**: Copy `.example` files and update with your actual values
4. **Keep vault passwords secure**: Store your Ansible Vault password in a secure location

The `.gitignore` file is configured to exclude sensitive files, but always verify no secrets are being committed before pushing changes.


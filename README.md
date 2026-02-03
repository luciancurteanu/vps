# VPS Setup

Ansible-based automation for deploying and managing LEMP stack servers (Linux, Nginx, MariaDB, PHP) with mail, security, and control panel.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## ✨ Features

- 🚀 **One-Command Setup**: Complete LEMP stack deployment
- 🌐 **Multi-Domain**: Easy virtual host creation and management
- 🔒 **SSL Automation**: Let's Encrypt certificates with auto-renewal
- 📧 **Mail Server**: Postfix, Dovecot, OpenDKIM, Roundcube webmail
- 🛡️ **Security**: Firewall, Fail2ban, SSH hardening
- 🎛️ **Control Panel**: Webmin for web-based administration
- 🔐 **Vault Integration**: Secure password management with Ansible Vault
- 🧪 **Testing**: Automated Molecule tests for all roles

---

## 📋 Requirements

- **OS**: AlmaLinux 9 / RHEL 9 / CentOS Stream 9
- **Control Machine**: Ansible 2.15+ installed
- **Target Server**: SSH access with sudo privileges
- **Domain**: Valid domain with DNS configured

---

## 🚀 Quick Start

### Option 1: Fresh Server Bootstrap

For a completely fresh OS installation:

```bash
# Install curl if needed
sudo dnf install -y curl

# Download and run bootstrap (installs Git, Ansible, Python, clones repo)
curl -fsSL https://raw.githubusercontent.com/luciancurteanu/vps/main/bootstrap.sh | bash

# Navigate to repo
cd ~/vps

# Configure inventory with your server details
cp inventory/hosts.yml.example inventory/hosts.yml
nano inventory/hosts.yml  # Edit: set ansible_host, ansible_user, etc.

# Create encrypted vault for passwords
ansible-vault create vars/secrets.yml
# Add passwords (see vars/secrets.yml.example for required format)

# Run full setup
./vps.sh install core --domain=yourdomain.com --ask-vault-pass
```

### Option 2: Manual Installation

```bash
# Clone repository
git clone https://github.com/luciancurteanu/vps.git
cd vps

# Configure inventory
cp inventory/hosts.yml.example inventory/hosts.yml
nano inventory/hosts.yml  # Edit with your server details

# Create vault for secrets
ansible-vault create vars/secrets.yml
# Add passwords (see vars/secrets.yml.example for format)

# Run full setup
./vps.sh install core --domain=yourdomain.com --ask-vault-pass
```

---

## 📖 Usage Guide

### Core Setup

Install complete server stack (run once):

```bash
./vps.sh install core --domain=yourdomain.com --ask-vault-pass
```

**This installs:**
- ✅ Base system + security hardening
- ✅ Nginx web server
- ✅ PHP-FPM with optimized configuration
- ✅ MariaDB database server
- ✅ Mail server (Postfix, Dovecot, OpenDKIM, Roundcube)
- ✅ Webmin control panel (with memory optimizations)
- ✅ SSL certificates via Let's Encrypt
- ✅ 2GB Swap file (prevents OOM issues)

**Vault password options:**
- Interactive: `--ask-vault-pass` (prompts for password)
- File-based: `--vault-password-file=~/.vault_pass` (reads from file)

### Domain Management

**Add a new domain:**
```bash
./vps.sh create host --domain=newsite.com --ask-vault-pass
```

**Remove a domain:**
```bash
./vps.sh remove host --domain=oldsite.com --ask-vault-pass
```

### SSL Certificates

**Install SSL for a domain:**
```bash
./vps.sh install ssl --domain=yourdomain.com --ask-vault-pass
```

### Database Operations

**Create database and user:**
```bash
./vps.sh create database --domain=yourdomain.com --dbname=mydb --ask-vault-pass
```

---

## 🧪 Development & Testing

### Local VM Testing (Windows)

Automated VM creation and testing using PowerShell:

```powershell
# Quick setup (manual steps after VM creation)
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -UseLocalSSHKey -autoSSH

# Full automated setup (one command - RECOMMENDED)
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -UseLocalSSHKey -FullSetup
```

**FullSetup includes:**
- Creates AlmaLinux 9 VM in VirtualBox
- Installs Docker + Molecule test environment
- Clones project to VM
- Configures SSH keys
- Ready for testing

### Running Molecule Tests

**On the VM (SSH to localhost):**
```bash
ssh localhost  # or ssh admin@192.168.88.8

# Run tests for a specific role
cd ~/vps
bash scripts/run-test.sh common

# Run specific test action
bash scripts/run-test.sh nginx converge
bash scripts/run-test.sh nginx verify
```

**From Windows (via PowerShell):**
```powershell
# SSH to VM and run tests
.\scripts\run-test.ps1 -RoleName common
```

### Environment Setup

**Automated (recommended):**
```bash
# Auto-installs Docker, Molecule, dependencies
sudo bash scripts/ci-setup.sh --yes
```

**Manual setup:**
```bash
# Install Docker
sudo dnf config-manager --add-repo=https://download.docker.com/linux/rhel/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# Create Python venv
python3 -m venv ~/molecule-env
source ~/molecule-env/bin/activate
pip install 'docker<=6.1.3' ansible molecule molecule-docker ansible-lint yamllint 'requests<2.32'
```

### Reset Test Environment

```bash
# Clean molecule environment
bash scripts/reset-molecule-environment.sh

# Fresh VM (from Windows)
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -Recreate -FullSetup
```

---

## 📂 Project Structure

```
vps/
├── vps.sh                      # Main CLI interface
├── bootstrap.sh                # Fresh server setup script
├── ansible.cfg                 # Ansible configuration
├── inventory/                  # Server inventory
│   ├── hosts.yml               # Your servers (gitignored)
│   └── hosts.yml.example       # Template
├── playbooks/                  # Ansible playbooks
│   ├── setup.yml               # Main setup playbook
│   ├── create_vhost.yml        # Add domain
│   ├── remove_vhost.yml        # Remove domain
│   └── ssl.yml                 # SSL management
├── roles/                      # Ansible roles
│   ├── common/                 # Base system
│   ├── nginx/                  # Web server
│   ├── php/                    # PHP-FPM
│   ├── mariadb/                # Database
│   ├── mail/                   # Mail server
│   ├── security/               # Security hardening
│   ├── cockpit/                # Cockpit panel
│   └── ...                     # Other roles
├── scripts/                    # Automation scripts
│   ├── ci-setup.sh             # CI environment setup
│   ├── run-test.sh             # Molecule test runner
│   ├── run-test.ps1            # Windows test wrapper
│   └── vm-launcher/            # VM automation
├── docs/                       # Documentation
│   ├── BEGINNER-GUIDE.md       # Comprehensive guide
│   └── molecule-deploy-setup.md # Testing setup
├── templates/                  # Jinja2 templates
└── vars/                       # Variables
    ├── secrets.yml             # Encrypted (gitignored)
    └── secrets.yml.example     # Template
```

---

## 🔒 Security Best Practices

**Included Security Features:**
- ✅ Firewall (firewalld) with minimal open ports
- ✅ Fail2ban for brute-force protection
- ✅ SSH key-only authentication
- ✅ SELinux enabled
- ✅ Automatic security updates
- ✅ Resource limits (prevent DoS)
- ✅ Secure PHP configuration

**Managing Secrets:**
```bash
# Create encrypted vault
ansible-vault create vars/secrets.yml

# Edit existing vault
ansible-vault edit vars/secrets.yml

# View vault contents
ansible-vault view vars/secrets.yml
```

**Never commit:**
- ❌ `vars/secrets.yml` (encrypted passwords)
- ❌ `inventory/hosts` (server IPs/credentials)
- ❌ `.vault_pass` (vault password file)
- ❌ SSH keys (*.pem, *.key files)

---

## 🎯 Common Tasks

### Setup New Website

```bash
# 1. Initial server setup (run once)
./vps.sh install core --domain=primary.com --ask-vault-pass

# 2. Add additional domain
./vps.sh create host --domain=secondary.com --ask-vault-pass

# 3. Install SSL
./vps.sh install ssl --domain=secondary.com --ask-vault-pass

# 4. Access your sites
# https://primary.com
# https://secondary.com
```

### Remove Website

```bash
./vps.sh remove host --domain=oldsite.com --ask-vault-pass
```

### Access Control Panel

```bash
# Webmin URL (installed automatically)
https://yourdomain.com:10000

# Cockpit URL (if installed)
https://yourdomain.com:9090
```

---

## 🛠️ Troubleshooting

**Check service status:**
```bash
sudo systemctl status nginx
sudo systemctl status php-fpm
sudo systemctl status mariadb
sudo systemctl status postfix
```

**View logs:**
```bash
sudo journalctl -u nginx -f
sudo journalctl -u php-fpm -f
sudo tail -f /var/log/maillog
```

**Test Molecule locally:**
```bash
cd ~/vps
bash scripts/run-test.sh common test
```

**VM issues:**
```powershell
# Clean restart
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -CleanupMode force -Recreate
```

---

## 📚 Documentation

- **[BEGINNER-GUIDE.md](docs/BEGINNER-GUIDE.md)** - Comprehensive beginner's guide
- **[STRUCTURE.md](STRUCTURE.md)** - Detailed project structure
- **[molecule-deploy-setup.md](docs/molecule-deploy-setup.md)** - Testing environment setup
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribution guidelines

---

## 🤝 Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 📜 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 👤 Author

**Lucian Curteanu**  
Website: [https://luciancurteanu.com](https://luciancurteanu.com)  
GitHub: [@luciancurteanu](https://github.com/luciancurteanu)

---

**⭐ If this project helped you, consider giving it a star!**

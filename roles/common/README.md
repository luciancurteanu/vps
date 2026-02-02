# Common Role

Foundation system configuration and hardening for AlmaLinux 9 VPS deployments.

## Description

The `common` role provides essential system configuration that serves as the foundation for all other roles. It handles initial server setup, package installation, user management, SSH hardening, and system locale configuration.

This role is designed to be the **first role** in your playbook, establishing a secure, properly configured baseline before deploying application-specific components.

## Features

- ✅ **Python 3.13 Installation** - Latest Python runtime from EPEL
- ✅ **Essential Packages** - Core utilities (curl, wget, git, htop, vim, etc.)
- ✅ **System Configuration** - Timezone, locale, and hostname setup
- ✅ **Admin User Creation** - Sudo-enabled user with SSH key authentication
- ✅ **SSH Hardening** - Security-focused SSH server configuration
- ✅ **EPEL Repository** - Enables access to additional packages
- ✅ **Idempotent** - Safe to run multiple times
- ✅ **Molecule Tested** - Automated tests verify all functionality

## Requirements

- **OS**: AlmaLinux 9 or RHEL 9
- **Ansible**: 2.9 or higher
- **Network**: Internet access for package downloads
- **Privileges**: Root access or sudo privileges

## Role Variables

Variables are defined in `inventory/group_vars/all.yml`. The role uses prefixed variants (`common_*`) internally to avoid conflicts.

### System Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `timezone` | `Europe/London` | System timezone (TZ database format) |
| `use_local_rtc` | `false` | Use local time for hardware clock |
| `locale` | `en_US.UTF-8` | System locale setting |
| `domain` | `inventory_hostname` | Server hostname (usually your domain) |

### Admin User Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `create_admin_user` | `true` | Create admin user during setup |
| `admin_user` | `admin` | Username for sudo-enabled admin account |
| `admin_group` | `admin` | Primary group for admin user |
| `admin_shell` | `/bin/bash` | Default shell for admin user |
| `admin_password` | `{{ vault_admin_password }}` | Admin password (from vault) |
| `admin_ssh_public_key` | `{{ vault_admin_ssh_public_key }}` | SSH public key for admin (from vault) |

### SSH Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `ssh_port` | `22` | SSH listening port |
| `ssh_permit_root_login` | `no` | Allow root login via SSH |
| `ssh_password_authentication` | `yes` | Allow password authentication |
| `ssh_pubkey_authentication` | `yes` | Allow public key authentication |
| `ssh_allow_agent_forwarding` | `no` | Allow SSH agent forwarding |
| `ssh_allow_tcp_forwarding` | `no` | Allow TCP port forwarding |
| `ssh_x11_forwarding` | `no` | Allow X11 GUI forwarding |
| `ssh_max_auth_tries` | `3` | Maximum authentication attempts |
| `ssh_max_sessions` | `10` | Maximum concurrent sessions |
| `ssh_client_alive_interval` | `300` | Keepalive interval (seconds) |
| `ssh_client_alive_count_max` | `3` | Keepalive messages before disconnect |

**Security Note**: Set `ssh_password_authentication: "no"` after SSH key setup is confirmed working.

### Installed Packages

**Core Packages** (from EPEL and base repos):
- `python3.13` - Latest Python runtime
- `python3.13-pip` - Python package manager
- `epel-release` - Extra Packages for Enterprise Linux
- `curl`, `wget` - Download utilities
- `git` - Version control
- `htop` - Process monitor
- `vim`, `nano` - Text editors
- `tar`, `unzip` - Archive utilities
- `net-tools` - Network utilities
- `bind-utils` - DNS utilities (dig, nslookup)
- `policycoreutils-python-utils` - SELinux management
- `firewalld` - Firewall management (optional)

**Optional Packages** (failures ignored):
- Additional utilities that may not be available in all repositories

## Dependencies

None. This role is designed to be the first role executed and has no dependencies on other roles.

## Example Usage

### Basic Installation

```yaml
---
- name: Configure base system
  hosts: all
  become: true
  roles:
    - common
```

### Custom Timezone and Admin User

```yaml
---
- name: Configure system with custom settings
  hosts: all
  become: true
  roles:
    - role: common
      vars:
        timezone: "America/New_York"
        admin_user: "webadmin"
        admin_group: "webadmin"
```

### Production SSH Hardening

```yaml
---
- name: Secure production server
  hosts: production
  become: true
  roles:
    - role: common
      vars:
        ssh_port: 2222
        ssh_permit_root_login: "no"
        ssh_password_authentication: "no"  # Key-only auth
        ssh_max_auth_tries: 2
```

### Multi-Server Setup

```yaml
---
- name: Configure multiple servers
  hosts: webservers
  become: true
  roles:
    - role: common
      vars:
        timezone: "UTC"
        create_admin_user: true
```

## Installation Order

The `common` role **must** be the first role in your playbook:

```yaml
roles:
  - common          # ← ALWAYS FIRST - System foundation
  - webmin          # Server management panel
  - security        # Additional security hardening
  - nginx           # Web server
  - python          # Python applications
  - php             # PHP runtime
  - mariadb         # Database server
  - mail            # Mail server
  - cockpit         # System monitoring
  - development     # Development tools
  - goproxy         # Go proxy (if needed)
```

## What This Role Does

### 1. System Configuration

- **Hostname**: Sets server hostname (usually domain name)
- **Timezone**: Configures system timezone
- **Locale**: Sets system locale (language/encoding)
- **RTC**: Configures hardware clock (UTC vs local time)

### 2. Package Management

- **EPEL Repository**: Installs EPEL for additional packages
- **Python 3.13**: Installs latest Python from EPEL
- **Core Utilities**: Installs essential system tools
- **Optional Packages**: Attempts to install additional tools (failures ignored)

### 3. User Management

- **Admin User Creation**: Creates sudo-enabled admin user
- **SSH Key Setup**: Configures SSH public key authentication
- **Password Configuration**: Sets user password from vault
- **Sudo Privileges**: Grants passwordless sudo access
- **Group Creation**: Creates admin group if needed

### 4. SSH Hardening

- **Security Settings**: Applies SSH server hardening
- **Port Configuration**: Sets SSH listening port
- **Authentication**: Configures key-based and/or password auth
- **Access Control**: Disables root login, limits sessions
- **Keepalive**: Configures session timeout settings
- **Service Restart**: Applies configuration changes

### 5. System Preparation

- **Directory Creation**: Creates essential system directories
- **Service Configuration**: Ensures required services are running
- **Package Cache**: Updates package repository metadata

## What This Role Does NOT Do

- ❌ Firewall rules configuration (handled by individual roles)
- ❌ Application installation (nginx, PHP, database, etc.)
- ❌ SSL certificate setup
- ❌ Swap file creation
- ❌ Kernel tuning or optimization
- ❌ Automatic security updates configuration
- ❌ Log rotation setup
- ❌ Backup configuration

These tasks are handled by specialized roles or should be configured separately.

## Testing

The role includes comprehensive Molecule tests.

### Run Tests

```bash
# From role directory
cd roles/common
molecule test

# Or use project script
./scripts/run-test.sh common test
```

### Test Coverage

The test suite verifies:

- ✅ Python 3.13 installation from EPEL
- ✅ Essential packages installed
- ✅ Timezone configuration
- ✅ Locale settings
- ✅ Admin user creation
- ✅ SSH key authentication
- ✅ Sudo privileges
- ✅ SSH service running and configured
- ✅ SSH hardening applied

**Latest Test Results**: All 14 checks passed ✅

## Initial Server Setup

### First Deployment

1. **Prepare inventory**:
   ```bash
   cp inventory/hosts.yml.example inventory/hosts.yml
   # Edit inventory/hosts with your server IP
   ```

2. **Configure variables**:
   ```bash
   cp inventory/group_vars/all.yml.example inventory/group_vars/all.yml
   # Edit all.yml with your settings
   ```

3. **Create vault for secrets**:
   ```bash
   ansible-vault create vars/secrets.yml
   ```
   
   Add:
   ```yaml
   vault_admin_password: "your-strong-password"
   vault_admin_ssh_public_key: "ssh-rsa AAAA... your-key"
   ```

4. **Run common role** (initial setup uses root):
   ```bash
   ansible-playbook -i inventory/hosts playbooks/setup.yml \
     --ask-vault-pass \
     --extra-vars "ansible_user=root"
   ```

5. **Subsequent runs** (use admin user):
   ```bash
   ansible-playbook -i inventory/hosts playbooks/setup.yml \
     --ask-vault-pass
   ```

### SSH Key Setup

After first run with password authentication:

1. Test SSH key access:
   ```bash
   ssh -i ~/.ssh/your_key admin@your-server
   ```

2. If successful, disable password authentication:
   ```yaml
   # In inventory/group_vars/all.yml
   ssh_password_authentication: "no"
   ```

3. Re-run playbook to apply change:
   ```bash
   ansible-playbook -i inventory/hosts playbooks/setup.yml
   ```

## Troubleshooting

### Python 3.13 Installation Fails

**Symptom**: Package not found or installation error

**Solution**: Ensure EPEL repository is available:

```bash
# Check EPEL is installed
rpm -qa | grep epel-release

# Manually install EPEL if needed
dnf install -y epel-release

# Verify Python 3.13 is available
dnf search python3.13
```

### Admin User Creation Fails

**Symptom**: User not created or sudo access denied

**Solution**: Check vault variables:

```bash
# Verify secrets.yml exists and contains required variables
ansible-vault view vars/secrets.yml

# Required variables:
# - vault_admin_password
# - vault_admin_ssh_public_key (optional but recommended)
```

### SSH Connection Refused After Hardening

**Symptom**: Cannot connect via SSH after running role

**Solution**: Check SSH configuration:

```bash
# From console/IPMI/KVM (not SSH):
systemctl status sshd
journalctl -u sshd -n 50

# Verify SSH port
ss -tlnp | grep sshd

# Check configuration syntax
sshd -t

# Revert to defaults if needed
cp /etc/ssh/sshd_config.rpmsave /etc/ssh/sshd_config
systemctl restart sshd
```

### Locked Out After Disabling Password Auth

**Symptom**: SSH key auth not working, password auth disabled

**Solution**: Access via console/IPMI and re-enable:

```bash
# Edit SSH config
vi /etc/ssh/sshd_config

# Change:
PasswordAuthentication yes

# Restart SSH
systemctl restart sshd

# Test key authentication before disabling password auth again
```

### Timezone Not Applied

**Symptom**: `date` command shows wrong timezone

**Solution**: 

```bash
# Check current timezone
timedatectl

# Manually set if needed
timedatectl set-timezone Europe/London

# List available timezones
timedatectl list-timezones
```

### Package Installation Failures

**Symptom**: Some packages fail to install

**Solution**: This is expected for optional packages. Check logs:

```bash
# Review installation output
# Failures in optional_packages are ignored
# Failures in core packages indicate repository issues

# Update package cache
dnf clean all
dnf makecache

# Check for broken repositories
dnf repolist
```

## Security Considerations

### Default Configuration

The default configuration provides a balance between security and usability:

- ✅ Root login disabled via SSH
- ✅ Admin user with sudo access
- ⚠️ Password authentication enabled (for initial setup)
- ✅ SSH on standard port 22
- ✅ Session limits configured
- ✅ Keepalive prevents hung connections

### Production Hardening

For production deployments, consider:

1. **Disable Password Authentication**:
   ```yaml
   ssh_password_authentication: "no"
   ```

2. **Change SSH Port**:
   ```yaml
   ssh_port: 2222  # Non-standard port reduces automated attacks
   ```

3. **Restrict Authentication Attempts**:
   ```yaml
   ssh_max_auth_tries: 2
   ```

4. **Use Strong Passwords**:
   - Generate with: `openssl rand -base64 32`
   - Store in Ansible vault

5. **Limit SSH Sessions**:
   ```yaml
   ssh_max_sessions: 5
   ```

6. **Configure Firewall**:
   - Handled by individual roles
   - Ensure SSH port is allowed before changing

### Vault Management

**Never commit secrets to git**:

```bash
# Create vault
ansible-vault create vars/secrets.yml

# Edit vault
ansible-vault edit vars/secrets.yml

# Change vault password
ansible-vault rekey vars/secrets.yml
```

## File Structure

```
roles/common/
├── defaults/
│   └── main.yml              # Default variables (prefixed with common_)
├── handlers/
│   └── main.yml              # Service handlers
├── meta/
│   └── main.yml              # Role metadata
├── molecule/
│   └── default/
│       ├── converge.yml      # Test playbook
│       ├── molecule.yml      # Molecule configuration
│       ├── prepare.yml       # Test environment setup
│       └── verify.yml        # Verification tests
├── tasks/
│   ├── main.yml              # Main task orchestration
│   ├── ssh.yml               # SSH hardening tasks
│   └── users.yml             # User management tasks
├── templates/
│   └── sshd_config.j2        # SSH configuration template
├── vars/
│   └── redhat.yml            # RedHat family package lists
└── README.md                 # This file
```

## Variables Reference

Variables are inherited from `inventory/group_vars/all.yml` and prefixed internally:

| Global Variable | Internal Variable | Purpose |
|----------------|-------------------|---------|
| `timezone` | `common_timezone` | System timezone |
| `locale` | `common_locale` | System locale |
| `domain` | `common_hostname` | Server hostname |
| `admin_user` | `common_admin_user` | Admin username |
| `admin_password` | `common_admin_password` | Admin password |
| `ssh_port` | `common_ssh_port` | SSH port |
| ... | ... | ... |

This prevents variable collisions when multiple roles are used.

## Post-Installation

After the common role completes:

1. **Verify admin user access**:
   ```bash
   ssh admin@your-server
   sudo -v  # Test sudo access
   ```

2. **Check Python version**:
   ```bash
   python3.13 --version
   pip3.13 --version
   ```

3. **Verify timezone**:
   ```bash
   timedatectl
   ```

4. **Review SSH configuration**:
   ```bash
   sudo cat /etc/ssh/sshd_config
   ```

5. **Proceed to next role**:
   - Usually `webmin` or `security`

## Version History

- **Current**: Python 3.13 from EPEL, comprehensive SSH hardening, admin user creation
- **Previous**: Basic system setup with minimal packages

## License

MIT

## Author Information

VPS Automation Project  
Role: Foundation system configuration for AlmaLinux 9

## Related Roles

- **security** - Additional security hardening (fail2ban, firewall rules)
- **webmin** - Server management panel (requires admin user from this role)
- All other roles depend on the foundation provided by `common`

## Support

For issues or questions:
1. Check [troubleshooting section](#troubleshooting)
2. Review [security considerations](#security-considerations)
3. Run molecule tests to verify installation
4. Check role tasks in [tasks/main.yml](tasks/main.yml)
5. Verify variables in `inventory/group_vars/all.yml`
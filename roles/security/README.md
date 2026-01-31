# Security Role

This role implements system security hardening measures with a focus on firewall configuration (iptables or firewalld), fail2ban protection, and access control.

## Features

- Firewall configuration supporting both iptables (default) and firewalld
- Default deny policy with explicit allow rules
- IPv6 support
- Comprehensive fail2ban implementation with:
  - Custom filters for mail services (Postfix, Dovecot)
  - Database protection (MariaDB)
  - Web protection (badbot, badurl filters)
  - Permanent bans (-1 bantime) for detected threats
- Customizable allow/deny rules
- Mail-specific security configurations

## Requirements

- Ansible 2.9 or higher
- AlmaLinux 9 or compatible distribution
- Root access for firewall configuration

## Role Variables

The security role uses variables defined in the inventory or playbook. Important variables include:

```yaml
# Firewall settings
firewall_enabled: true
firewall_service: iptables  # iptables (recommended) or firewalld
firewall_use_ipv6: true
firewall_initialize: true  # Initialize fail2ban chains on first run

# SSH configuration
ssh_port: 22  # Custom SSH port for better security

# Allowed services in firewall
firewall_allowed_services:
  - { proto: tcp, port: 80 }    # HTTP
  - { proto: tcp, port: 443 }   # HTTPS

# Mail service ports (used when domain is master_domain)
mail_service_ports:
  - { proto: tcp, port: 25 }    # SMTP
  - { proto: tcp, port: 587 }   # SMTP (submission)
  - { proto: tcp, port: 465 }   # SMTPS
  # ...and more

# Fail2ban configuration
fail2ban_enabled: true
fail2ban_services:
  - sshd
  - postfix
  - dovecot
  - mariadb
  - badbot
  - badurl

# IP addresses to whitelist in fail2ban
allowed_ips: "149.102.153.46/32 66.249.64.0/19 31.5.191.35/32"
```

Prefixed equivalents (`security_firewall_enabled`, `security_firewall_service`, `security_firewall_use_ipv6`, `security_firewall_initialize`, `security_firewall_allowed_services`, `security_mail_service_ports`, `security_ssh_port`, `security_ssh_service_name`, `security_fail2ban_enabled`, `security_fail2ban_services`, `security_fail2ban_socket_timeout`, `security_allowed_ips`) are provided to avoid collisions with other roles; prefer these in new inventories.

## Configuration Details

The role performs the following security tasks:

### Firewall Configuration

**Iptables Mode (Default):**
1. Ensures firewalld is disabled and removed (for RedHat/CentOS)
2. Installs and configures iptables and iptables-services
3. Configures default deny policy
4. Allows established connections
5. Explicitly allows configured services
6. Enables logging for dropped packets
7. Configures IPv6 rules when enabled

**Firewalld Mode (Optional):**
1. Installs and enables firewalld service
2. Configures zones and services
3. Adds HTTP/HTTPS services
4. Adds SSH service
5. Adds mail service ports (when domain matches master_domain)
6. Enables immediate and permanent rules

### Fail2ban Implementation

1. Installs fail2ban and required dependencies
2. Configures fail2ban to use permanent bans (-1 bantime)
3. Sets up custom filters for various services:
   - SSH (aggressive mode)
   - Mail services (Postfix, Dovecot)
   - Database (MariaDB)
   - Web protection (badbot, badurl)
4. Initializes the fail2ban chains with test bans/unbans
5. Configures email notifications for bans

### Mail Service Security
When `domain == master_domain`:
1. Adds fail2ban filters for mail services (Postfix, Dovecot)
2. Configures iptables to allow mail-related ports:
   - SMTP: 25, 587, 465
   - POP3: 110, 995
   - IMAP: 143, 993

## Example Playbook

```yaml
- hosts: servers
  roles:
    - role: security
      vars:
        firewall_allowed_services:
          - { proto: tcp, port: 80 }    # HTTP
          - { proto: tcp, port: 443 }   # HTTPS
          - { proto: tcp, port: 2222 }  # Custom SSH port
        ssh_port: 2222
```

## Integration with Other Roles

The security role should be applied early in the provisioning process, typically after the common role but before service-specific roles to ensure basic protection is in place.

## License

MIT
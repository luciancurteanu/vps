# VPS Setup Playbooks

This directory contains standalone Ansible playbooks for different aspects of VPS management.

## Available Playbooks

### setup.yml

The main playbook for setting up a complete VPS with all components.

- **Purpose**: Full server provisioning with web, database, mail, and security components
- **Usage**: `./vps.sh install core --domain=vps.test --ask-pass --ask-vault-pass`
- **Requirements**: Domain name pointing to server IP
- **Components Installed**:
  - Common server tools
  - Security and firewall configuration
  - Nginx web server
  - PHP-FPM
  - MariaDB database server
  - Mail server stack (Postfix, Dovecot, OpenDKIM)
  - Webmin control panel
  - Development tools (optional)
  - GoProxy (on master domain only)

### create_vhost.yml

Creates a new virtual host configuration for hosting an additional website.

- **Purpose**: Set up a new domain on the server
- **Usage**: `./vps.sh create host --domain=newdomain.com`
- **Requirements**: Existing server setup via setup.yml
- **Operations Performed**:
  - Creates system user
  - Sets up directory structure
  - Configures Nginx virtual host
  - Creates PHP-FPM pool
  - Configures mail for the domain
  - Sets proper permissions
  - Configures SFTP access if master domain

### remove_vhost.yml

Removes a virtual host configuration and optionally its files.

- **Purpose**: Clean up domains no longer needed
- **Usage**: `./vps.sh remove host --domain=olddomain.com`
- **Requirements**: Existing virtual host
- **Operations Performed**:
  - Backs up website files
  - Removes Nginx configuration
  - Removes PHP-FPM configuration
  - Removes website files (optional)
  - Removes SSL certificates (optional)
  - Removes system user (optional)

### ssl.yml

Obtains and installs SSL certificates using Let's Encrypt.

- **Purpose**: Secure websites with HTTPS
- **Usage**: `./vps.sh install ssl --domain=vps.test --ask-vault-pass`
- **Requirements**: Existing virtual host configuration
- **Operations Performed**:
  - Installs Certbot
  - Obtains SSL certificate
  - Sets up auto-renewal
  - Configures Nginx with SSL optimizations

## Security Considerations

All playbooks:
- Require `become: yes` (root privileges)
- Use vault for sensitive data
- Apply proper file permissions
- Follow security best practices

## Variables

These playbooks use variables from multiple sources:
- Command line arguments
- `inventory/group_vars/all.yml` for global settings
- `vars/secrets.yml` for sensitive data
- Role-specific defaults

## Dependencies

These playbooks depend on the roles in the `roles/` directory and are designed to be used with the `vps.sh` script for a streamlined experience.
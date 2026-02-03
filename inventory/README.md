# VPS Setup Inventory

This directory contains Ansible inventory files and group variables that define server configurations for the VPS setup project.

## Directory Structure

- `hosts` - Local inventory file defining server groups and connections 
- `group_vars/` - Variables for groups of hosts
  - `all.yml` - Global variables used across all servers
  - `webservers.yml` - Variables specific to web servers

## Inventory File (hosts)

The `hosts` file defines the server groups and connection details. Servers can be organized into groups based on their roles:

```ini
[all:vars]
ansible_connection=ssh

[webservers]
# Add your server(s) here, for example:
# yourdomain.com ansible_host=192.168.1.100

[database]
# Add database servers here

[mail]
# Add mail servers here
```

### How to Configure

1. Make a copy of `hosts.example` if it doesn't exist:
   ```bash
   cp hosts.example hosts
   ```

2. Add your server details:
   ```ini
   [webservers]
   yourdomain.com ansible_host=192.168.1.100 ansible_user=root
   ```

3. Optional: Configure connection variables:
   ```ini
   [webservers:vars]
   ansible_port=2222
   ansible_user=admin
   ```

## Group Variables

### all.yml

This file contains global variables used by all servers. Key sections include:

1. **System Configuration**: 
   - Default user settings
   - SSH configuration
   - Firewall settings
   - Default paths

2. **Domain Configuration**:
   - Master domain settings
   - Subdomain configuration
   - Domain handling

3. **Software Versions**:
   - PHP version
   - MariaDB version
   - Nginx version

4. **Mail Configuration**:
   - Mail domain settings
   - Email administrator contacts
   - Mail database settings

5. **Control Panel Configuration**:
   - Webmin settings
   - Control panel access

### webservers.yml

This file contains variables specific to web servers, including:

1. **Nginx Configuration**:
   - Worker processes and connections
   - Keepalive settings
   - Client max body size

2. **PHP-FPM Configuration**:
   - Memory limits
   - Execution time
   - Upload limits

3. **Virtual Host Settings**:
   - Default virtual host creation
   - Server name configuration

## Variable Precedence

Variables follow Ansible's variable precedence rules, with more specific variables overriding more general ones:

1. Command-line extra vars (highest precedence)
2. Host-specific variables (host_vars/)
3. Group-specific variables (group_vars/)
4. Role default variables (lowest precedence)

## Vault Integration

Sensitive variables like passwords should not be stored in the group_vars files. Instead, they should be stored in the Ansible Vault (`vars/secrets.yml`).

## Example Usage

When running VPS setup commands, you can target specific server groups:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --limit webservers
```

This will only apply the configuration to servers in the 'webservers' group.
# Cockpit Role

Modern web-based server management interface for monitoring and administering Linux servers.

## Overview

This role installs and configures [Cockpit](https://cockpit-project.org/), a lightweight, web-based server management tool that provides real-time monitoring, service management, and system administration capabilities through a clean, intuitive interface.

## Features

- **Lightweight**: Uses 30-50MB RAM vs. traditional control panels (6GB+)
- **Real-time Monitoring**: CPU, memory, disk, network, and service status
- **Service Management**: Start, stop, restart, and configure systemd services
- **Storage Management**: Manage disks, filesystems, LVM, and RAID
- **Network Management**: Configure interfaces, firewall, and connections
- **Container Support**: Manage Podman containers (optional module)
- **Package Management**: Install and update system packages
- **Terminal Access**: Built-in web terminal with sudo support
- **Logs Viewer**: Browse and search systemd journal logs
- **Multi-user**: PAM-based authentication with role-based access

## Requirements

- AlmaLinux 9 / RHEL 9
- Ansible 2.9+
- nginx (for reverse proxy)
- iptables (for firewall rules)

## Role Variables

### Default Variables (`defaults/main.yml`)

```yaml
# Cockpit port (default: 9090)
cockpit_port: 9090

# Cockpit subdomain (e.g., cpanel.yourdomain.com)
cockpit_subdomain: "cpanel.{{ domain }}"

# Enable nginx reverse proxy
cockpit_nginx_proxy: true

# Allowed origins for CORS
cockpit_origins:
  - "http://{{ cockpit_subdomain }}"
  - "https://{{ cockpit_subdomain }}"
  - "http://{{ ansible_default_ipv4.address }}:{{ cockpit_port }}"
  - "https://{{ ansible_default_ipv4.address }}:{{ cockpit_port }}"

# Allow unencrypted connections (nginx handles SSL)
cockpit_allow_unencrypted: true
```

### Inventory Variables

From `inventory/group_vars/all.yml`:

```yaml
# Default admin user (used for Cockpit login)
default_user: admin

# Firewall settings
firewall_enabled: true
firewall_service: iptables
```

## Dependencies

- `nginx` role (for reverse proxy setup)
- `security` role (for firewall configuration)

## Installation

The role installs the following packages:

- `cockpit` - Core Cockpit web service
- `cockpit-storaged` - Storage management module
- `cockpit-networkmanager` - Network configuration module
- `cockpit-podman` - Container management module
- `cockpit-packagekit` - Package management module

## Usage

### Basic Usage

Include the role in your playbook:

```yaml
- hosts: servers
  roles:
    - cockpit
```

### With Custom Configuration

```yaml
- hosts: servers
  roles:
    - role: cockpit
      vars:
        cockpit_port: 9090
        cockpit_subdomain: "admin.{{ domain }}"
        cockpit_nginx_proxy: true
```

### Access Methods

**Via Subdomain (Recommended)**:
```
http://cpanel.yourdomain.com
```

**Direct IP Access**:
```
https://SERVER_IP:9090
```

### Login Credentials

Use any valid system user with sudo privileges:

- **Username**: `admin` (or your `default_user`)
- **Password**: System user password

## Features and Capabilities

### System Monitoring
- Real-time CPU, memory, disk, and network graphs
- Process monitoring and management
- System load and uptime tracking
- Temperature sensors (if available)

### Service Management
View and manage all systemd services:
- nginx
- php-fpm
- mariadb
- postfix
- dovecot
- fail2ban
- cockpit
- And all other system services

### Storage Management
- View disk usage and partitions
- Create and manage LVM volumes
- RAID configuration
- Filesystem mounting and unmounting
- NFS and iSCSI support

### Network Configuration
- Network interface management
- Firewall rules (firewalld/iptables)
- Bridge and bond configuration
- VLAN setup

### Terminal Access
- Full bash terminal in browser
- Sudo support for administrative tasks
- Multiple concurrent sessions

### Logs and Troubleshooting
- Browse systemd journal logs
- Filter by service, priority, or time
- Export logs for analysis
- Real-time log streaming

### Container Management (Podman)
- List and manage containers
- Pull and run images
- View container logs
- Resource usage monitoring

## Security Considerations

### Authentication
- PAM-based system authentication
- Root login blocked by default (use sudo)
- Session timeout after inactivity
- Failed login attempt tracking

### Network Security
- Firewall rules automatically configured
- HTTPS support via nginx proxy
- WebSocket connections secured
- CORS protection with allowed origins

### Access Control
- User-based permissions via PAM
- Sudo required for administrative tasks
- SELinux integration (if enabled)

## Nginx Proxy Configuration

The role automatically configures nginx as a reverse proxy:

- **Upstream**: http://127.0.0.1:9090
- **WebSocket Support**: Enabled for real-time updates
- **Timeouts**: 60s connect, 300s read/write
- **Buffering**: Disabled for real-time data
- **Headers**: Proper forwarding for CORS and authentication

## Firewall Configuration

Automatic iptables rules:

```bash
iptables -A INPUT -p tcp --dport 9090 -j ACCEPT
```

## Troubleshooting

### Login Issues

**Problem**: Login succeeds but redirects back to login page  
**Solution**: Ensure `AllowUnencrypted = true` in `/etc/cockpit/cockpit.conf`

**Problem**: "Permission denied" for root user  
**Solution**: Cockpit blocks root login by default. Use `admin` or `admin` user with sudo.

### Proxy Issues

**Problem**: "Bad Gateway" error after login  
**Solution**: Check nginx is proxying to HTTP not HTTPS backend:
```bash
proxy_pass http://cockpit;  # Correct
proxy_pass https://cockpit; # Incorrect - causes TLS handshake errors
```

**Problem**: WebSocket connections failing  
**Solution**: Verify WebSocket upgrade headers in nginx config

### Service Issues

**Problem**: Cockpit not starting  
**Solution**: 
```bash
sudo systemctl status cockpit.socket
sudo journalctl -u cockpit -n 50
```

### Performance

**Problem**: High memory usage  
**Solution**: Cockpit is lightweight (30-50MB). If higher, check for:
- Multiple concurrent sessions
- Container management module loading many containers
- Large log files being viewed

## Comparison with Webmin

| Feature | Cockpit | Webmin |
|---------|---------|--------|
| Memory Usage | 30-50MB | 6GB+ (with monitoring) |
| Architecture | Modern, systemd-native | Legacy Perl CGI |
| Performance | Fast, responsive | Slow, crashes on low RAM |
| Real-time Updates | WebSocket-based | Polling (high CPU) |
| Container Support | Native Podman integration | Limited |
| Package Management | Modern PackageKit | Legacy |
| Security | PAM, SELinux aware | Custom auth |

## Migration from Webmin

The role automatically removes old Webmin nginx configurations:
- `/etc/nginx/conf.d/webmin.conf`
- `/etc/nginx/sites-enabled/cpanel.{{ domain }}.conf`
- `/etc/nginx/sites-available/cpanel.{{ domain }}.conf`

To completely remove Webmin:
```bash
sudo systemctl stop webmin
sudo systemctl disable webmin
sudo systemctl mask webmin
sudo dnf remove webmin
```

## Examples

### View Running Services
1. Login to Cockpit
2. Navigate to **Services** in left menu
3. Filter or search for service name
4. Click service to view details, logs, start/stop

### Manage Firewall
1. Navigate to **Networking** → **Firewall**
2. View active rules
3. Add/remove rules
4. Configure zones

### Monitor System Resources
1. Dashboard shows real-time graphs
2. Click **System** for detailed metrics
3. View process list and resource usage
4. Access hardware information

### Container Management
1. Navigate to **Podman Containers**
2. Pull images from registries
3. Create and run containers
4. View logs and resource usage

## Files

```
roles/cockpit/
├── tasks/
│   └── main.yml                    # Installation and configuration tasks
├── templates/
│   ├── cockpit.conf.j2             # Cockpit web service configuration
│   └── nginx/
│       └── cockpit.conf.j2         # Nginx reverse proxy configuration
├── defaults/
│   └── main.yml                    # Default variables
├── handlers/
│   └── main.yml                    # Service handlers
├── meta/
│   └── main.yml                    # Role metadata
└── README.md                       # This file
```

## License

MIT

## Author

VPS Setup Project

## Contributing

Contributions welcome! Please submit pull requests or open issues for bugs and feature requests.

## Links

- [Cockpit Project](https://cockpit-project.org/)
- [Cockpit Documentation](https://cockpit-project.org/guide/latest/)
- [GitHub Repository](https://github.com/cockpit-project/cockpit)

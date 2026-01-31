# Webmin Role

Clean, vanilla installation of Webmin server management panel for AlmaLinux 9.

## Description

This role installs [Webmin](https://webmin.com/) using the official repository with default configuration. No customizations, optimizations, or modifications are applied - providing a clean base installation that can be configured through Webmin's web interface.

The role handles repository setup, package installation, firewall configuration, and service management. An optional nginx reverse proxy template is available for SSL-enabled access via custom subdomain.

## Features

- ✅ **Vanilla Installation** - Official Webmin package with defaults
- ✅ **Automatic Firewall Rules** - iptables configuration for Webmin port
- ✅ **Service Management** - Systemd service enabled and started
- ✅ **Version Pinning** - Optional version specification for reproducible deployments
- ✅ **Nginx Proxy Template** - Optional SSL reverse proxy configuration
- ✅ **Idempotent** - Safe to run multiple times
- ✅ **Molecule Tested** - Automated tests verify installation and accessibility

## Requirements

- **OS**: AlmaLinux 9 or RHEL 9
- **Ansible**: 2.9 or higher
- **Dependencies**: `common` role must run before this role
- **Firewall**: iptables (configured by `common` role)

## Role Variables

All variables are defined in [defaults/main.yml](defaults/main.yml):

### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `webmin_enabled` | `true` | Enable/disable Webmin installation |
| `webmin_port` | `10000` | Webmin listening port (default HTTP) |
| `webmin_version` | `""` | Webmin version to install (empty = latest) |

### Repository Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `webmin_repo_url` | `https://download.webmin.com/download/yum` | Official Webmin repository URL |
| `webmin_gpg_key` | `https://download.webmin.com/jcameron-key.asc` | GPG key for package verification |

### Nginx Proxy (Optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `webmin_nginx_proxy` | `false` | Enable nginx reverse proxy configuration |
| `webmin_subdomain` | `cpanel.{{ domain }}` | Subdomain for nginx proxy access |
| `webmin_ssl_enabled` | `false` | SSL configuration status (for nginx proxy) |

**Note**: `webmin_ssl_enabled` indicates whether SSL termination is handled by nginx. Webmin itself runs on HTTP when using reverse proxy.

## Dependencies

This role requires the `common` role to run first. The common role provides:
- System configuration and updates
- Firewall setup (iptables)
- Basic security hardening
- Admin user creation

## Example Usage

### Basic Installation

```yaml
---
- name: Deploy VPS with Webmin
  hosts: all
  become: true
  roles:
    - common
    - webmin
```

### Pinned Version

```yaml
---
- name: Deploy specific Webmin version
  hosts: all
  become: true
  roles:
    - common
    - role: webmin
      vars:
        webmin_version: "2.105"
```

### With Custom Port

```yaml
---
- name: Deploy Webmin on custom port
  hosts: all
  become: true
  roles:
    - common
    - role: webmin
      vars:
        webmin_port: 12000
```

## Installation Order

Webmin should be installed early in the deployment sequence, after `common` but before application stack components:

```yaml
roles:
  - common          # System setup, firewall, security
  - webmin          # Server management panel
  - security        # Additional security hardening
  - nginx           # Web server
  - python          # Python runtime
  - php             # PHP runtime
  - mariadb         # Database server
  - mail            # Mail server
  - cockpit         # System monitoring
  - development     # Development tools
  - goproxy         # Go proxy (if needed)
```

## What This Role Does

1. **Repository Setup**
   - Adds official Webmin YUM repository
   - Configures GPG key verification

2. **Package Installation**
   - Installs Webmin package (latest or specified version)
   - Handles upgrades if version specified differs from installed

3. **Service Configuration**
   - Enables Webmin service via systemd
   - Starts Webmin service

4. **Firewall Configuration**
   - Creates iptables rule for Webmin port
   - Saves iptables configuration

5. **Verification**
   - Checks Webmin web interface accessibility
   - Validates service is responding

## What This Role Does NOT Do

This is a **vanilla installation**. The role deliberately does not:

- ❌ Modify Webmin configuration files
- ❌ Change port settings in miniserv.conf
- ❌ Install or configure themes
- ❌ Disable modules or features
- ❌ Apply memory optimizations
- ❌ Configure dashboard preferences
- ❌ Modify SSL settings
- ❌ Create Webmin users

All post-installation configuration should be done through Webmin's web interface or by extending this role.

## Nginx Reverse Proxy (Optional)

An nginx configuration template is available at [templates/nginx/webmin.conf.j2](templates/nginx/webmin.conf.j2). This template is **not** automatically deployed by the role.

To use the nginx proxy:

1. Set `webmin_nginx_proxy: true` in your playbook
2. Ensure nginx role runs after webmin
3. Configure SSL certificates (via Let's Encrypt or manual)
4. Update `webmin_subdomain` and `webmin_ssl_enabled` variables

The template provides:
- HTTP to HTTPS redirect
- SSL termination at nginx
- Reverse proxy to Webmin backend
- Gzip compression
- Security headers
- Login redirect fix (critical for post-login functionality)

Example configuration matching your old server setup:

```yaml
- role: webmin
  vars:
    webmin_port: 10000
    webmin_nginx_proxy: true
    webmin_subdomain: "cpanel.{{ domain }}"
    webmin_ssl_enabled: true
```

This allows access via `https://cpanel.yourdomain.com` instead of `http://server-ip:10000`.

## Testing

This role includes comprehensive Molecule tests.

### Run Tests

```bash
# From role directory
cd roles/webmin
molecule test

# Or use project script
./scripts/run-test.sh webmin test
```

### Test Coverage

The test suite verifies:

- ✅ Webmin package installation
- ✅ Version file existence
- ✅ Service enabled and active
- ✅ Port configuration in miniserv.conf
- ✅ Webmin process running
- ✅ Web interface accessibility (HTTP/HTTPS based on `webmin_ssl_enabled`)

**Latest Test Results**: All 14 verification tasks passed ✅

## Accessing Webmin

### Direct Access (Default)

After installation, access Webmin at:

```
http://YOUR_SERVER_IP:10000
```

Default credentials:
- **Username**: `root`
- **Password**: Your system root password

### Via Nginx Proxy (If Configured)

With nginx proxy enabled:

```
https://cpanel.yourdomain.com
```

## Troubleshooting

### Webmin Not Accessible

Check service status:

```bash
systemctl status webmin
```

Verify Webmin is listening:

```bash
ss -tlnp | grep 10000
netstat -tlnp | grep 10000
```

Check firewall rules:

```bash
iptables -L INPUT -n | grep 10000
```

Test local connectivity:

```bash
curl -I http://localhost:10000
```

### Check Webmin Version

```bash
cat /etc/webmin/version
```

### View Webmin Logs

```bash
journalctl -u webmin -f
tail -f /var/webmin/miniserv.log
```

### Firewall Issues

If firewall blocks access:

```bash
# Verify rule exists
iptables -L INPUT -n -v | grep 10000

# Manually add rule if needed
iptables -I INPUT -p tcp --dport 10000 -j ACCEPT
iptables-save > /etc/sysconfig/iptables
```

### SSL Certificate Errors

Webmin uses self-signed certificate by default. For production:

1. Use nginx reverse proxy with Let's Encrypt
2. Or configure custom SSL in Webmin web interface: Webmin → Webmin Configuration → SSL Encryption

## Security Considerations

### Default Configuration

- **Port Exposure**: Port 10000 is exposed to internet if firewall allows
- **Authentication**: Uses system root credentials (strong password required)
- **SSL**: Self-signed certificate by default (browser warnings expected)
- **Access Control**: No IP restrictions by default

### Recommended Hardening

For production deployments:

1. **Use Nginx Proxy**: Enable SSL with valid certificates
2. **Restrict Access**: Configure IP allowlist in Webmin or firewall
3. **Strong Passwords**: Ensure root password is strong
4. **Change Default Port**: Consider non-standard port
5. **Enable 2FA**: Configure in Webmin after installation
6. **Regular Updates**: Keep Webmin updated

### Nginx Proxy Benefits

Using nginx reverse proxy provides:
- Valid SSL certificates (Let's Encrypt)
- Custom subdomain access
- Additional security headers
- Rate limiting capabilities
- Request logging
- Hide internal port from exposure

## File Structure

```
roles/webmin/
├── defaults/
│   └── main.yml              # Default variables
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
│   └── main.yml              # Main installation tasks
├── templates/
│   └── nginx/
│       └── webmin.conf.j2    # Nginx reverse proxy template
└── README.md                 # This file
```

## Version History

- **Current**: Vanilla installation, nginx proxy template available
- **Previous**: Memory-optimized version with theme customizations (deprecated)

## License

MIT

## Author Information

VPS Automation Project  
Role: Webmin installation for AlmaLinux 9

## Related Roles

- **common** - System setup and prerequisites
- **nginx** - Web server (required for reverse proxy)
- **security** - Additional security hardening

## Support

For issues or questions:
1. Check [troubleshooting section](#troubleshooting)
2. Review [Webmin documentation](https://webmin.com/docs.html)
3. Run molecule tests to verify installation
4. Check role tasks in [tasks/main.yml](tasks/main.yml)

# Nginx Role

High-performance Nginx web server with optimized defaults for hosting multiple websites on AlmaLinux 9.

## Description

The `nginx` role installs and configures Nginx mainline with production-ready optimizations for modern web applications. It provides a solid foundation for hosting multiple websites with dedicated virtual hosts, SSL/TLS support, PHP-FPM integration, and comprehensive security configurations.

This role is designed to be deployed **after** the `common` role and typically **before** PHP/database roles in your playbook.

## Features

- ✅ **Nginx Mainline** - Latest stable version from official repository
- ✅ **Performance Optimized** - Tuned for high concurrency and throughput
- ✅ **SSL/TLS Ready** - Secure cipher configuration (TLSv1.2 + TLSv1.3)
- ✅ **PHP-FPM Integration** - Unix socket support for PHP applications
- ✅ **Static File Caching** - 30-day browser caching for assets
- ✅ **Gzip Compression** - Optimal compression for faster delivery
- ✅ **Security Headers** - CSP, X-Content-Type-Options, X-XSS-Protection
- ✅ **Default Server** - Returns 444 for undefined/unknown hosts
- ✅ **SELinux Support** - Home directory hosting with proper contexts
- ✅ **Configuration Testing** - Automatic `nginx -t` before applying changes
- ✅ **Idempotent** - Safe to run multiple times
- ✅ **Molecule Tested** - Automated tests verify all functionality

## Requirements

- **OS**: AlmaLinux 9 or RHEL 9
- **Ansible**: 2.9 or higher
- **Dependencies**: None (common role recommended but not required)
- **Privileges**: Root access or sudo privileges

## Role Variables

Variables are defined in `defaults/main.yml`. All settings have sensible production defaults.

### Nginx Version

| Variable | Default | Description |
|----------|---------|-------------|
| `nginx_mainline` | `true` | Install mainline (latest stable) vs stable (older LTS) |

### System Resources

| Variable | Default | Description |
|----------|---------|-------------|
| `nginx_nofile_limit` | `65536` | File descriptor limit for nginx user |
| `nginx_worker_connections` | `20480` | Max simultaneous connections per worker |

### Performance Tuning

| Variable | Default | Description |
|----------|---------|-------------|
| `nginx_client_body_timeout` | `"10s"` | Timeout for reading client request body |
| `nginx_send_timeout` | `"2s"` | Timeout for transmitting response to client |
| `nginx_keepalive_timeout` | `"30s"` | Keep-alive connection timeout |
| `nginx_keepalive_requests` | `10000` | Max requests per keep-alive connection |
| `nginx_client_body_buffer_size` | `"128k"` | Buffer size for reading client request body |
| `nginx_client_header_buffer_size` | `"32k"` | Buffer size for reading client request headers |
| `nginx_large_client_header_buffers` | `"8 64k"` | Number and size of large header buffers |
| `nginx_client_header_timeout` | `"3m"` | Timeout for reading client request headers |
| `nginx_types_hash_max_size` | `2048` | Max size of types hash tables |
| `nginx_client_max_body_size` | `"500M"` | Maximum upload file size |

### Gzip Compression

| Variable | Default | Description |
|----------|---------|-------------|
| `nginx_gzip` | `"on"` | Enable gzip compression |
| `nginx_gzip_comp_level` | `6` | Compression level (1-9, 6 recommended) |
| `nginx_gzip_buffers` | `"16 8k"` | Number and size of compression buffers |

### Cache Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `nginx_cache_dir` | `/etc/nginx/cache` | FastCGI cache directory location |

### Virtual Host Variables

These are set per-vhost by `create_vhost.yml` and `ssl.yml` playbooks:

| Variable | Usage | Description |
|----------|-------|-------------|
| `domain` | **Required** | Domain name for virtual host |
| `nginx_ssl_enabled` | `false`/`true` | HTTP-only vs HTTPS mode |

## Dependencies

None. This role can be used standalone or integrated with other roles.

**Recommended Order**:
```yaml
roles:
  - common          # System foundation
  - security        # Firewall/fail2ban
  - nginx           # ← Web server (this role)
  - python          # Python applications
  - php             # PHP runtime
  - mariadb         # Database
```

## Example Usage

### Basic Installation

```yaml
---
- name: Install Nginx
  hosts: webservers
  become: true
  roles:
    - nginx
```

### Performance Tuning

```yaml
---
- name: Install high-performance Nginx
  hosts: webservers
  become: true
  roles:
    - role: nginx
      vars:
        nginx_worker_connections: 40960
        nginx_client_max_body_size: "1G"
        nginx_keepalive_requests: 20000
```

### Custom Timeouts

```yaml
---
- name: Install Nginx with custom timeouts
  hosts: webservers
  become: true
  roles:
    - role: nginx
      vars:
        nginx_keepalive_timeout: "60s"
        nginx_client_body_timeout: "30s"
        nginx_send_timeout: "5s"
```

### Stable Branch

```yaml
---
- name: Install Nginx stable
  hosts: webservers
  become: true
  roles:
    - role: nginx
      vars:
        nginx_mainline: false  # Use older LTS version
```

## What This Role Does

### 1. Repository Setup

- **Adds Nginx Repository**: Official nginx.org repository for AlmaLinux 9
- **Mainline/Stable**: Configures mainline or stable branch based on `nginx_mainline`
- **GPG Keys**: Imports official Nginx signing keys

### 2. Package Installation

- **Nginx Package**: Installs latest nginx from official repository
- **Dependency Handling**: Resolves all package dependencies
- **Version Management**: Maintains specified version branch

### 3. Main Configuration

- **nginx.conf**: Comprehensive main configuration with optimized settings
- **Backup**: Creates `.bak` backup before first modification (idempotent)
- **Worker Processes**: Auto-configured based on CPU cores
- **Connection Limits**: Optimized for high concurrency
- **Timeouts**: Balanced for performance and resource usage
- **Buffers**: Sized for modern applications

### 4. Default Server

- **Unknown Host Handler**: Returns 444 (connection close) for undefined domains
- **Port 80 Listener**: Default server on HTTP
- **Security**: Prevents nginx from serving content for unmapped domains
- **Logging**: Separate access/error logs for default server monitoring

### 5. Directory Structure

- **Cache Directory**: Creates `/etc/nginx/cache` for FastCGI caching
- **sites-available/**: Virtual host configurations
- **sites-enabled/**: Symlinks to enabled virtual hosts
- **Runtime Directory**: `/run/nginx` for PID file

### 6. System Configuration

- **File Limits**: Sets nofile limit (65536) for nginx user
- **Systemd Integration**: Configures PID file location via systemd override
- **tmpfiles.d**: Ensures runtime directory persists across reboots

### 7. SELinux Configuration

- **Home Directory Access**: `httpd_enable_homedirs` for `/home/domain/` hosting
- **Network Connections**: `httpd_can_network_connect` for proxying
- **PID File Context**: `httpd_var_run_t` for proper systemd integration
- **Context Application**: Runs `restorecon` to apply SELinux contexts

### 8. Service Management

- **Configuration Testing**: Runs `nginx -t` before applying changes
- **Service Enable**: Ensures nginx starts on boot
- **Service Start**: Starts nginx service if not running

## What This Role Does NOT Do

- ❌ Virtual host creation (use `playbooks/create_vhost.yml`)
- ❌ SSL certificate generation (use `playbooks/ssl.yml`)
- ❌ PHP-FPM installation/configuration (use `php` role)
- ❌ Database setup (use `mariadb` role)
- ❌ Firewall rules (handled by `security` role)
- ❌ Domain DNS configuration
- ❌ Application deployment
- ❌ Log rotation setup (uses system defaults)

## Virtual Host Management

Virtual hosts are managed through dedicated playbooks, not directly by this role.

### Creating a Virtual Host

```bash
# Create HTTP-only virtual host
ansible-playbook -i inventory/hosts.yml playbooks/create_vhost.yml \
  --extra-vars "domain=vps.test"
```

This creates:
- `/etc/nginx/sites-available/vps.test.conf`
- `/etc/nginx/sites-enabled/vps.test.conf` (symlink)
- `/home/vps.test/public_html/` (document root)
- `/home/vps.test/logs/` (access/error logs)

### Adding SSL/TLS

```bash
# Obtain Let's Encrypt certificate and enable HTTPS
ansible-playbook -i inventory/hosts.yml playbooks/ssl.yml \
  --extra-vars "domain=vps.test email=admin@vps.test"
```

This adds:
- Let's Encrypt SSL certificate
- HTTPS server block (port 443)
- HTTP → HTTPS redirect
- OCSP stapling, HSTS preload
- Security headers (CSP, X-Content-Type-Options, etc.)

### Removing a Virtual Host

```bash
# Remove virtual host and clean up
ansible-playbook -i inventory/hosts.yml playbooks/remove_vhost.yml \
  --extra-vars "domain=vps.test"
```

### Virtual Host Template Features

Each virtual host includes:

**HTTP Block** (always):
- Static file caching (30 days)
- Security headers (CSP, X-Content-Type-Options, X-XSS-Protection)
- PHP-FPM integration via Unix socket
- try_files with `/index.php?$args` fallback
- Trailing slash removal

**HTTPS Block** (when `nginx_ssl_enabled: true`):
- All HTTP features plus:
- TLSv1.2 + TLSv1.3 protocols
- Secure cipher suites
- OCSP stapling
- HSTS preload
- SSL session caching (10m)
- HTTP → HTTPS redirect

## Testing

The role includes comprehensive Molecule tests.

### Run Tests

```bash
# From role directory
cd roles/nginx
molecule test

# Or use project script
./scripts/run-test.sh nginx test
```

### Test Coverage

The test suite verifies:

- ✅ Nginx package installed from official repository
- ✅ Service running and enabled
- ✅ Configuration syntax valid (`nginx -t`)
- ✅ Main configuration file deployed
- ✅ Default server configuration present
- ✅ Cache directory created
- ✅ sites-available/ directory exists
- ✅ sites-enabled/ directory exists
- ✅ Nginx listening on port 80
- ✅ Idempotent (no changes on second run)
- ✅ Configuration backups created once only

**Latest Test Results**: All 12 verification tests passed ✅

## Troubleshooting

### Nginx Installation Fails

**Symptom**: Package not found or repository error

**Solution**: Verify repository configuration:

```bash
# Check if nginx repository is configured
dnf repolist | grep nginx

# Manually add repository if needed
cat > /etc/yum.repos.d/nginx.repo <<EOF
[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF

# Install nginx
dnf install -y nginx
```

### Nginx Won't Start

**Symptom**: `systemctl start nginx` fails

**Solution**: Check configuration and logs:

```bash
# Test configuration syntax
nginx -t

# Check for port conflicts
ss -tlnp | grep :80

# Review error logs
journalctl -u nginx -n 50
tail -f /var/log/nginx/error.log

# Check SELinux denials
ausearch -m avc -ts recent | grep nginx

# Verify PID file directory
ls -ld /run/nginx
```

### Configuration Test Fails

**Symptom**: `nginx -t` reports errors

**Solution**: Check specific error messages:

```bash
# Run configuration test
nginx -t

# Common issues:
# - Syntax error: Check nginx.conf and vhost configs
# - Unknown directive: Verify nginx version supports directive
# - File not found: Check include paths and file existence

# Restore from backup if needed
cp /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
nginx -t
systemctl restart nginx
```

### SELinux Denials

**Symptom**: Permission denied errors in error log

**Solution**: Check and configure SELinux:

```bash
# Check SELinux status
sestatus

# View nginx-related denials
ausearch -m avc -ts recent | grep nginx

# Enable home directory access
setsebool -P httpd_enable_homedirs 1

# Enable network connections (for proxying)
setsebool -P httpd_can_network_connect 1

# Fix file contexts
restorecon -Rv /etc/nginx
restorecon -Rv /run/nginx
restorecon -Rv /home/*/public_html

# If issues persist, check audit log
grep nginx /var/log/audit/audit.log | audit2why
```

### Port 80 Already in Use

**Symptom**: Cannot bind to port 80

**Solution**: Find and stop conflicting service:

```bash
# Find what's using port 80
ss -tlnp | grep :80
lsof -i :80

# Common conflicts: httpd, apache2
systemctl stop httpd
systemctl disable httpd

# Then start nginx
systemctl start nginx
```

### Virtual Host Not Working

**Symptom**: Domain returns default server 444 or wrong site

**Solution**: Check virtual host configuration:

```bash
# Verify config exists
ls -l /etc/nginx/sites-available/
ls -l /etc/nginx/sites-enabled/

# Check symlink
ls -l /etc/nginx/sites-enabled/vps.test.conf

# Test configuration
nginx -t

# Check server_name directive
grep server_name /etc/nginx/sites-available/vps.test.conf

# Reload nginx
systemctl reload nginx

# Test with curl
curl -H "Host: vps.test" http://localhost/
```

### 502 Bad Gateway (PHP-FPM)

**Symptom**: Nginx returns 502 for PHP files

**Solution**: Check PHP-FPM socket:

```bash
# Verify socket exists
ls -l /var/run/php-fpm/vps.test.sock

# Check PHP-FPM service
systemctl status php-fpm

# Review PHP-FPM error log
tail -f /var/log/php-fpm/error.log

# Verify socket path in nginx config
grep fastcgi_pass /etc/nginx/sites-enabled/vps.test.conf

# Check socket permissions
ls -l /var/run/php-fpm/

# SELinux context for socket
ls -lZ /var/run/php-fpm/
```

### High Memory Usage

**Symptom**: Nginx consuming excessive memory

**Solution**: Tune worker and buffer settings:

```yaml
# In defaults/main.yml or playbook vars
nginx_worker_connections: 10240  # Reduce from 20480
nginx_client_body_buffer_size: "64k"  # Reduce from 128k
nginx_large_client_header_buffers: "4 32k"  # Reduce from 8 64k

# Monitor memory
ps aux | grep nginx
top -p $(pgrep nginx | tr '\n' ',' | sed 's/,$//')
```

## Security Considerations

### Default Configuration

The default configuration provides production-ready security:

- ✅ TLSv1.2 + TLSv1.3 only (no SSLv3, TLSv1.0, TLSv1.1)
- ✅ Secure cipher suites (modern browsers)
- ✅ HSTS preload (when SSL enabled)
- ✅ OCSP stapling (when SSL enabled)
- ✅ Content Security Policy (CSP) headers
- ✅ X-Content-Type-Options: nosniff
- ✅ X-XSS-Protection: 1; mode=block
- ✅ Default server returns 444 (close connection)
- ✅ Configuration testing before reload

### Production Hardening

For additional security:

1. **Enable SSL/TLS for all sites**:
   ```bash
   ansible-playbook playbooks/ssl.yml --extra-vars "domain=vps.test"
   ```

2. **Disable default server** (after all vhosts configured):
   ```bash
   # Remove or rename default.conf
   mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.disabled
   systemctl reload nginx
   ```

3. **Rate limiting** (add to nginx.conf or vhost):
   ```nginx
   limit_req_zone $binary_remote_addr zone=one:10m rate=10r/s;
   limit_req zone=one burst=20 nodelay;
   ```

4. **Hide nginx version**:
   ```nginx
   # Already included in nginx.conf
   server_tokens off;
   ```

5. **Firewall integration**:
   ```bash
   # Handled by security role
   firewall-cmd --permanent --add-service=http
   firewall-cmd --permanent --add-service=https
   firewall-cmd --reload
   ```

6. **ModSecurity WAF** (optional, separate role):
   ```bash
   dnf install nginx-mod-security
   ```

### SSL/TLS Best Practices

- ✅ Use Let's Encrypt for free certificates
- ✅ Enable OCSP stapling (already configured)
- ✅ Configure HSTS with preload (already configured)
- ✅ Use strong ciphers (already configured)
- ✅ Disable old protocols (already configured)
- ✅ Renew certificates automatically (certbot timer)

## File Structure

```
roles/nginx/
├── defaults/
│   └── main.yml              # Default variables
├── handlers/
│   └── main.yml              # Service restart handler
├── meta/
│   └── main.yml              # Role metadata
├── molecule/
│   └── default/
│       ├── converge.yml      # Test playbook
│       ├── create.yml        # Container creation
│       ├── destroy.yml       # Container cleanup
│       ├── molecule.yml      # Molecule configuration
│       ├── prepare.yml       # Test environment setup
│       └── verify.yml        # Verification tests (12 checks)
├── tasks/
│   ├── main.yml              # Main installation/config tasks
│   └── site_management.yml   # Vhost enable/disable/remove
├── templates/
│   ├── default.conf.j2       # Default server config
│   ├── nginx.conf.j2         # Main nginx configuration
│   └── vhost.conf.j2         # Virtual host template
└── README.md                 # This file
```

## Configuration Files

### nginx.conf.j2

Main configuration with:
- Worker process auto-configuration
- Connection limits and timeouts
- Buffer size tuning
- Gzip compression
- SSL session cache
- FastCGI cache zone
- Includes sites-enabled/*.conf

### default.conf.j2

Default server that:
- Listens on port 80 as default
- Returns 444 for unknown hosts
- Logs requests for monitoring

### vhost.conf.j2

Virtual host template with:
- HTTP and HTTPS server blocks
- Static file caching (30 days)
- Security headers
- PHP-FPM integration
- SSL/TLS configuration (when enabled)
- OCSP stapling
- HSTS preload
- try_files fallback

## Path Conventions

All virtual hosts follow this structure:

```
/home/vps.test/
├── public_html/          # Document root (nginx serves from here)
│   ├── index.html
│   └── index.php
└── logs/                 # Access and error logs
    ├── access.log
    └── error.log
```

PHP-FPM sockets:
```
/var/run/php-fpm/vps.test.sock
```

SSL certificates:
```
/etc/letsencrypt/live/vps.test/
├── fullchain.pem
└── privkey.pem
```

## Integration with Other Roles

### PHP Role

The nginx role integrates seamlessly with the PHP role:

```yaml
---
- name: Web server with PHP
  hosts: webservers
  become: true
  roles:
    - nginx
    - php  # Creates PHP-FPM pools per domain
```

PHP-FPM pools are created by `create_vhost.yml` playbook with matching socket paths.

### Security Role

Firewall rules for HTTP/HTTPS:

```yaml
---
- name: Web server with firewall
  hosts: webservers
  become: true
  roles:
    - nginx
    - security  # Opens ports 80 and 443
```

The security role automatically opens required ports when nginx is installed.

### MariaDB Role

Database backend for web applications:

```yaml
---
- name: Complete web stack
  hosts: webservers
  become: true
  roles:
    - common
    - nginx
    - php
    - mariadb  # Database backend
```

## Performance Optimization

### Worker Configuration

Workers auto-configure based on CPU cores. Override if needed:

```bash
# Check CPU cores
nproc

# Set workers manually in nginx.conf.j2
worker_processes 4;  # Or auto (default)
```

### Connection Tuning

For high-traffic sites:

```yaml
nginx_worker_connections: 40960
nginx_keepalive_requests: 20000
nginx_keepalive_timeout: "60s"
```

### Buffer Tuning

For large uploads:

```yaml
nginx_client_max_body_size: "2G"
nginx_client_body_buffer_size: "256k"
```

### Caching

Enable FastCGI caching for dynamic content (requires additional configuration in vhost):

```nginx
fastcgi_cache_path /etc/nginx/cache levels=1:2 keys_zone=PHPCACHE:100m inactive=60m;
fastcgi_cache PHPCACHE;
fastcgi_cache_valid 200 60m;
```

## Post-Installation

After the nginx role completes:

1. **Verify nginx is running**:
   ```bash
   systemctl status nginx
   nginx -v
   ```

2. **Test configuration**:
   ```bash
   nginx -t
   curl -I http://localhost/
   ```

3. **Create first virtual host**:
   ```bash
   ansible-playbook playbooks/create_vhost.yml \
     --extra-vars "domain=vps.test"
   ```

4. **Add SSL certificate**:
   ```bash
   ansible-playbook playbooks/ssl.yml \
     --extra-vars "domain=vps.test email=admin@vps.test"
   ```

5. **Deploy application**:
   - Upload files to `/home/vps.test/public_html/`
   - Set proper ownership: `chown -R nginx:nginx /home/vps.test/`

## Version History

- **Current**: Mainline 1.25+, comprehensive security headers, molecule tests, idempotent backups
- **Previous**: Basic nginx setup with minimal configuration

## License

MIT

## Author Information

VPS Automation Project  
Role: High-performance Nginx web server for AlmaLinux 9

## Related Documentation

- [Nginx Official Documentation](https://nginx.org/en/docs/)
- [Virtual Host Management](../../playbooks/README.md)
- [SSL/TLS Setup](../../docs/ssl-setup.md)
- [PHP-FPM Integration](../php/README.md)

## Support

For issues or questions:
1. Check [troubleshooting section](#troubleshooting)
2. Review [security considerations](#security-considerations)
3. Run molecule tests: `cd roles/nginx && molecule test`
4. Check nginx error logs: `tail -f /var/log/nginx/error.log`
5. Test configuration: `nginx -t`
6. Review role tasks: [tasks/main.yml](tasks/main.yml)
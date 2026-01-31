# PHP Role

Enterprise-grade PHP 8.4 and PHP-FPM installation and configuration for AlmaLinux 9, optimized for security, performance, and integration with Nginx web server. This role provides a production-ready PHP environment with comprehensive extension support and hardened security settings.

## Description

This role installs PHP 8.4 from Remi's repository and configures PHP-FPM with Unix socket communication for optimal performance. It implements security best practices, performance optimizations through OPcache, and proper permission management for web hosting environments. The role is designed to work seamlessly with the Nginx role for complete web server stack deployment.

## Features

- ✅ **PHP 8.4 Installation** - Latest PHP version from Remi repository
- ✅ **PHP-FPM Configuration** - Unix socket for Nginx integration
- ✅ **Performance Optimization** - OPcache with 128MB memory allocation
- ✅ **Security Hardening** - Proper file permissions and directory ownership
- ✅ **Extension Support** - Comprehensive PHP extension installation
- ✅ **Service Management** - Systemd integration with auto-start
- ✅ **Configuration Backup** - Automatic backup of original www.conf
- ✅ **Per-Domain Pools** - Support for isolated PHP-FPM pools per virtual host
- ✅ **Nginx Integration** - User/group alignment with Nginx worker processes
- ✅ **Testing Coverage** - Full Molecule test suite with idempotence verification

## Requirements

- **Ansible**: 2.9 or higher
- **Platform**: AlmaLinux 9
- **Dependencies**: Nginx role (recommended for full web stack)
- **Privileges**: Root or sudo access
- **Network**: Internet access for package downloads

## Role Variables

All configurable variables are defined in [defaults/main.yml](defaults/main.yml). Below are the key variables with their default values and descriptions.

### Core PHP Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `php_version` | `"8.4"` | PHP version to install from Remi repository |
| `nginx_user` | `nginx` | User for PHP-FPM processes (matches Nginx) |
| `nginx_group` | `nginx` | Group for PHP-FPM processes (matches Nginx) |

### PHP-FPM Socket Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `php_fpm_listen` | `/var/run/php-fpm/php-fpm.sock` | Unix socket path for PHP-FPM communication |

**Socket Details:**
- Per-domain pools use: `/var/run/php-fpm/{{ domain }}.sock`
- Socket owner: `nginx:nginx` (mode `0660`)
- Provides faster communication than TCP sockets
- Reduces network overhead

### OPcache Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `php_opcache_enable` | `1` | Enable OPcache acceleration |
| `php_opcache_memory_consumption` | `128` | OPcache memory size (MB) |
| `php_opcache_interned_strings_buffer` | `8` | String buffer size (MB) |
| `php_opcache_max_accelerated_files` | `4000` | Maximum cached files |
| `php_opcache_revalidate_freq` | `2` | File check frequency (seconds) |
| `php_opcache_fast_shutdown` | `1` | Enable fast shutdown |
| `php_opcache_enable_cli` | `1` | Enable OPcache for CLI |

**OPcache Benefits:**
- Caches compiled PHP bytecode in memory
- Reduces server load and improves response times
- Optimized for production workloads
- Per-domain pools get 256MB OPcache allocation

## Dependencies

This role works standalone but is optimized for integration with:

- **nginx**: Web server role (recommended) - provides the web server that communicates with PHP-FPM
- **common**: Base system configuration
- **security**: Firewall and SSH hardening

## Installation Steps

The role executes the following tasks in order:

1. **Repository Setup**
   - Adds Remi PHP repository for AlmaLinux 9
   - Enables PHP 8.4 module from Remi

2. **User/Group Creation**
   - Creates `nginx` system group
   - Creates `nginx` system user (nologin shell)
   - Ensures proper ownership for PHP-FPM processes

3. **Package Installation**
   - Installs PHP 8.4 and PHP-FPM core packages
   - Installs essential PHP extensions (see Extensions section)

4. **Configuration**
   - Backs up original `/etc/php-fpm.d/www.conf`
   - Configures PHP-FPM Unix socket: `/run/php-fpm/www.sock`
   - Sets nginx user/group for socket ownership
   - Configures OPcache in `/etc/php.ini`

5. **Directory Setup**
   - Creates `/var/run/php-fpm` directory
   - Sets ownership on `/var/log/php-fpm` (nginx:root)
   - Configures `/var/lib/php` permissions (root:nginx)
   - Secures session directory: `/var/lib/php/session` (mode 0700)

6. **Service Management**
   - Enables php-fpm systemd service
   - Starts PHP-FPM service
   - Validates socket creation
   - Displays service status and logs

## PHP Extensions Installed

The role installs these production-ready extensions:

| Extension | Purpose |
|-----------|---------|
| `php-mysqlnd` | MySQL/MariaDB native driver |
| `php-zip` | ZIP archive handling |
| `php-gd` | Image processing (GD library) |
| `php-curl` | HTTP client (cURL) |
| `php-pear` | PHP Extension and Application Repository |
| `php-bcmath` | Arbitrary precision mathematics |
| `php-gmp` | GNU Multiple Precision arithmetic |
| `php-json` | JSON encoding/decoding |
| `php-pecl-apcu` | Alternative PHP Cache (user cache) |

**Extension Selection:**
- Chosen for common web application requirements
- WordPress, Laravel, and general PHP framework support
- Database connectivity and caching capabilities

## Example Playbook

### Basic Installation

```yaml
---
- hosts: webservers
  become: true
  roles:
    - role: php
```

### Custom PHP Version

```yaml
---
- hosts: webservers
  become: true
  roles:
    - role: php
      vars:
        php_version: "8.4"
```

### Full Web Stack

```yaml
---
- hosts: webservers
  become: true
  roles:
    - role: common
    - role: nginx
    - role: php
    - role: mariadb
```

## Per-Domain PHP-FPM Pools

While this role configures the global PHP-FPM setup, individual domain configurations are managed by virtual host playbooks.

### Pool Creation

Per-domain pools are created via [playbooks/create_vhost.yml](../../playbooks/create_vhost.yml):

```yaml
- name: Deploy PHP-FPM pool for domain
  template:
    src: pool.conf.j2
    dest: "/etc/php-fpm.d/{{ domain }}.conf"
  notify: Restart php-fpm
```

### Pool Template

The [pool.conf.j2](templates/pool.conf.j2) template provides:

**Process Management:**
- Dynamic PM: 100 max children, 20 start servers
- 10-30 spare servers range
- 1000 max requests per child

**Security Settings:**
- `open_basedir`: `/home/{{ domain }}`
- Disabled functions: `passthru`, `system`
- Session isolation: `/home/{{ domain }}/tmp`
- Per-domain error logging

**Resource Limits:**
- 1GB memory limit
- 512MB upload size
- 256MB per-domain OPcache

**Socket Configuration:**
- Path: `/var/run/php-fpm/{{ domain }}.sock`
- Owner: `nginx:nginx` (mode 0660)

### Example Domain Pool

```ini
[vps.test]
user = vps.test
group = vps.test
listen = /var/run/php-fpm/vps.test.sock
listen.owner = nginx
listen.group = nginx
pm = dynamic
pm.max_children = 100
php_admin_value[memory_limit] = 1024M
php_admin_value[opcache.memory_consumption] = 256
```

## Testing

This role includes comprehensive Molecule tests for quality assurance.

### Test Execution

```bash
# Run full test suite
cd roles/php
molecule test

# Individual test phases
molecule create    # Create test container
molecule converge  # Apply role
molecule verify    # Run verification tests
molecule destroy   # Clean up
```

### Test Coverage

**Converge Phase:**
- ✅ PHP 8.4 installation from Remi repository
- ✅ PHP-FPM service installation and configuration
- ✅ Nginx user/group creation
- ✅ Extension installation verification
- ✅ OPcache configuration
- ✅ Directory permissions setup
- ✅ Unix socket configuration
- ✅ Service startup and status check

**Idempotence Phase:**
- ✅ No changes on second run (21 tasks, 0 changed)
- ✅ Configuration stability verification

**Verify Phase:**
- ✅ PHP-FPM binary presence
- ✅ PHP extensions loaded (mysqlnd, zip, gd, curl, etc.)
- ✅ Unix socket exists: `/run/php-fpm/www.sock`
- ✅ PEAR CLI availability
- ✅ Service running status

### Test Results (from log)

```
PLAY RECAP - Converge
almalinux9: ok=22 changed=13 unreachable=0 failed=0

PLAY RECAP - Idempotence
almalinux9: ok=21 changed=0 unreachable=0 failed=0

PLAY RECAP - Verify
almalinux9: ok=8 changed=0 unreachable=0 failed=0
```

**Status:** ✅ All tests passing

**Status:** ✅ All tests passing

## Troubleshooting

### PHP-FPM Service Issues

**Service won't start:**
```bash
# Check service status
systemctl status php-fpm

# View detailed logs
journalctl -u php-fpm -n 50

# Check PHP-FPM error log
tail -f /var/log/php-fpm/error.log

# Test configuration syntax
php-fpm -t
```

**Common causes:**
- Configuration syntax errors in `/etc/php-fpm.d/*.conf`
- Permission issues on socket directory
- Port/socket already in use
- Missing dependencies

### Socket Connection Problems

**Nginx can't connect to socket:**
```bash
# Check socket exists
ls -la /var/run/php-fpm/

# Verify socket permissions
stat /var/run/php-fpm/www.sock

# Check nginx user membership
id nginx

# Test socket communication
echo "<?php phpinfo();" | php-fpm -c /etc/php.ini
```

**Resolution:**
- Ensure `nginx` user exists: `id nginx`
- Verify socket owner: `listen.owner = nginx`
- Check socket mode: `listen.mode = 0660`
- Restart both services: `systemctl restart php-fpm nginx`

### Performance Issues

**High memory usage:**
```bash
# Check OPcache usage
php -r "print_r(opcache_get_status());"

# Monitor PHP-FPM processes
ps aux | grep php-fpm

# Check process manager settings
grep "^pm\." /etc/php-fpm.d/www.conf
```

**Optimization:**
- Adjust `pm.max_children` based on RAM
- Increase OPcache memory: `php_opcache_memory_consumption`
- Review `php_opcache_revalidate_freq` for production

**Slow response times:**
- Enable OPcache if disabled
- Check `pm.max_requests` (current: 1000)
- Monitor slow logs: `/home/{{ domain }}/logs/php_error.log`
- Verify database connection pooling

### Extension Loading Issues

**Extension not loaded:**
```bash
# List loaded extensions
php -m

# Check extension ini files
ls /etc/php.d/

# Verify extension availability
dnf list installed | grep php-
```

**Resolution:**
- Install missing extension: `dnf install php-extension-name`
- Check ini file syntax: `php --ini`
- Restart PHP-FPM after changes

### Permission Denied Errors

**Common scenarios:**
```bash
# Fix session directory permissions
chmod 0700 /var/lib/php/session
chown -R nginx:nginx /var/lib/php/session

# Fix upload directory permissions
chown nginx:nginx /home/{{ domain }}/tmp
chmod 0755 /home/{{ domain }}/tmp

# Fix log directory permissions
chown nginx:root /var/log/php-fpm
chmod 0755 /var/log/php-fpm
```

### Configuration Rollback

**Restore original configuration:**
```bash
# Restore www.conf backup
cp /etc/php-fpm.d/www.conf.bak /etc/php-fpm.d/www.conf

# Restart service
systemctl restart php-fpm

# Verify service health
systemctl status php-fpm
```

## Security Considerations

### File Permissions

**Critical directories:**
- `/etc/php-fpm.d/`: `0755` (config files: `0644`)
- `/var/run/php-fpm/`: `0755` (sockets: `0660`)
- `/var/lib/php/session/`: `0700` (nginx:nginx)
- `/var/log/php-fpm/`: `0755` (nginx:root)

**Per-domain isolation:**
```ini
php_admin_value[open_basedir] = /home/{{ domain }}
php_admin_value[session.save_path] = /home/{{ domain }}/tmp
php_admin_value[upload_tmp_dir] = /home/{{ domain }}/tmp
```

### Disabled Functions

For security, dangerous functions are disabled in per-domain pools:
```ini
php_admin_value[disable_functions] = passthru,system
```

**Additional hardening (optional):**
```ini
disable_functions = exec,shell_exec,passthru,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source
```

### Socket Security

- Unix sockets are more secure than TCP sockets (no network exposure)
- Socket mode `0660` restricts access to owner and group
- Only `nginx` user/group can communicate with PHP-FPM

### OPcache Security

**Production settings:**
```ini
opcache.validate_timestamps = 0  # Disable for production (manual cache clear)
opcache.enable_cli = 0            # Disable for CLI in production
```

**Current settings (defaults/main.yml):**
- `opcache.validate_timestamps = 1` (enabled for development)
- `opcache.revalidate_freq = 2` (check files every 2 seconds)

## Performance Tuning

### Process Manager Optimization

**Calculate max_children:**
```bash
# Formula: (Total RAM - System RAM) / Average Process Size
# Example: (8GB - 2GB) / 50MB = 120 max_children

# Check current memory usage
ps aux | grep php-fpm | awk '{sum+=$6} END {print sum/NR/1024 " MB average"}'
```

**Recommended PM settings:**
```ini
pm = dynamic
pm.max_children = 120        # Based on available RAM
pm.start_servers = 30        # 25% of max_children
pm.min_spare_servers = 20    # 15-20% of max_children
pm.max_spare_servers = 60    # 50% of max_children
pm.max_requests = 1000       # Restart worker after N requests
```

### OPcache Optimization

**Production settings:**
```yaml
php_opcache_memory_consumption: 256          # Increase for large apps
php_opcache_max_accelerated_files: 10000    # Increase for many files
php_opcache_validate_timestamps: 0           # Disable timestamp checks
```

**Monitor OPcache:**
```bash
# Install opcache GUI (optional)
wget https://raw.githubusercontent.com/amnuts/opcache-gui/master/index.php -O /var/www/html/opcache.php

# Or check via CLI
php -r "var_dump(opcache_get_status());"
```

### Resource Limits

**Per-domain pool tuning:**
```ini
php_admin_value[memory_limit] = 1024M        # Adjust per application needs
php_admin_value[max_execution_time] = 300    # Increase for long processes
php_admin_value[max_input_time] = 300        # Increase for large uploads
php_admin_value[post_max_size] = 512M        # Match upload needs
php_admin_value[upload_max_filesize] = 512M  # Match post_max_size
```

## Integration with Nginx

### Nginx Virtual Host Configuration

**FastCGI configuration block:**
```nginx
location ~ \.php$ {
    fastcgi_pass unix:/var/run/php-fpm/{{ domain }}.sock;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    include fastcgi_params;
    
    # Performance tuning
    fastcgi_buffer_size 128k;
    fastcgi_buffers 256 16k;
    fastcgi_busy_buffers_size 256k;
    fastcgi_temp_file_write_size 256k;
    
    # Timeouts
    fastcgi_connect_timeout 60s;
    fastcgi_send_timeout 300s;
    fastcgi_read_timeout 300s;
}
```

### Socket Communication Flow

```
HTTP Request → Nginx → Unix Socket → PHP-FPM Pool → PHP Script → Response
                ↓                         ↓
          /etc/nginx/            /etc/php-fpm.d/
        sites-enabled/           {{ domain }}.conf
      {{ domain }}.conf
```

**Advantages of Unix sockets:**
- 10-15% faster than TCP loopback
- Lower CPU overhead
- No network stack involvement
- Better security (filesystem permissions)

## File Structure

```
roles/php/
├── defaults/
│   └── main.yml                 # Default variables
├── handlers/
│   └── main.yml                 # Service restart handler
├── molecule/
│   └── default/
│       ├── converge.yml         # Test playbook
│       ├── molecule.yml         # Molecule configuration
│       ├── verify.yml           # Verification tests
│       └── molecule_vm_terminal_output.log  # Test results
├── tasks/
│   ├── main.yml                 # Main task file (157 lines)
│   └── config.yml               # Alternative config (not used)
├── templates/
│   └── pool.conf.j2             # Per-domain pool template
└── README.md                    # This file
```

## Contributing

When modifying this role:

1. Update variables in [defaults/main.yml](defaults/main.yml)
2. Test changes with Molecule: `molecule test`
3. Ensure idempotence (0 changes on second run)
4. Update this README with new features
5. Document security implications

## License

MIT

## Author Information

This role is part of the VPS automation project for enterprise web hosting environments.
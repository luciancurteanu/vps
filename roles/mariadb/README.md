# MariaDB Role

Comprehensive MariaDB database server installation and configuration with enterprise-grade security hardening, adaptive performance tuning, automated backup management, and production-ready user administration for AlmaLinux 9 environments.

## Description

This role provides a complete MariaDB database solution for production VPS deployments. It installs MariaDB from the AppStream repository (ensuring native RHEL 9 compatibility), implements security best practices including removal of test databases and anonymous users, configures performance settings based on available system resources, establishes automated backup routines, and creates standard database users with appropriate privileges. The role supports idempotent operations, configuration backups, and comprehensive validation.

## Features

- **MariaDB 11.4 Installation**: Native AppStream packages for RHEL 9 compatibility
- **Security Hardening**: 
  - Root password configuration with vault support
  - Anonymous user removal
  - Test database removal
  - Remote root login disabled
  - Unix socket authentication
- **Performance Optimization**:
  - Adaptive tuning based on server memory (2GB/4GB/8GB+ tiers)
  - InnoDB buffer pool optimization
  - Query cache configuration
  - Connection pooling
  - Event scheduler enabled
- **Backup Management**:
  - Automated daily backups via cron
  - Configurable backup retention
  - Compression support
  - Backup directory management
- **User Management**:
  - Secure password handling via Ansible Vault
  - Standard user creation (remote_user, webclient)
  - Granular privilege assignment
- **Configuration Backups**: Automatic .bak files before modifications
- **Idempotent Operations**: Safe for repeated execution
- **Systemd Integration**: Service management with automatic startup

## Requirements

### System Requirements
- **Distribution**: AlmaLinux 9, CentOS Stream 9
- **Architecture**: x86_64
- **Memory**: Minimum 2GB RAM (4GB+ recommended for production)
- **Disk Space**: 500MB for MariaDB + space for databases and backups

### Software Requirements
- **Ansible**: 2.9 or higher
- **Python**: 3.9+ (installed by role)
- **Ansible Collections**: 
  - `community.mysql` (3.8.0+)
  - `ansible.builtin`

### Dependencies
- **Python Packages** (installed automatically):
  - `python3-PyMySQL` - Required for Ansible mysql modules

## Role Variables

### Core Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `mariadb_version` | `"11.4"` | MariaDB version (from AppStream) |
| `db_root_user` | `"root"` | Database root username |
| `db_root_password` | `{{ vault_db_root_password }}` | Root password (from vault or env) |

### User Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `db_remote_user` | `{{ vault_db_remote_user \| default('remote_user') }}` | Remote database administrator username |
| `db_remote_password` | `{{ vault_db_remote_password }}` | Remote user password (from vault) |
| `db_webclient_password` | `{{ vault_db_webclient_password }}` | Webclient user password (from vault) |

### Network Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `db_bind_address` | `"127.0.0.1"` | Listen address (127.0.0.1=localhost, 0.0.0.0=all) |
| `db_port` | `3306` | MySQL/MariaDB port |

### Performance Tuning

| Variable | Default | Description |
|----------|---------|-------------|
| `db_optimize_for_server` | `true` | Enable adaptive performance tuning |
| `db_character_set` | `"utf8mb4"` | Default character set |
| `db_collation` | `"utf8mb4_unicode_ci"` | Default collation |

### Backup Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `db_backup_dir` | `"/var/backups/mysql"` | Backup directory path |
| `setup_db_backups` | `true` | Enable automated backups |

### Security Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `db_allow_remote_root` | `false` | Allow root login from remote hosts |
| `db_remove_test_database` | `true` | Remove test database during setup |
| `db_remove_anonymous_users` | `true` | Remove anonymous user accounts |

## Dependencies

None. This role is self-contained and will install all required packages and dependencies.

## Installation Phases

The role executes in the following phases:

### Phase 1: Package Installation
1. Install MariaDB server packages from AppStream
2. Install MariaDB client packages
3. Install python3-PyMySQL for Ansible integration

### Phase 2: Directory Structure
1. Create log directory (`/var/log/mariadb`)
2. Create custom configuration directory (`/etc/mysql/conf.d`)
3. Create backup directory (`/var/backups/mysql`)

### Phase 3: Configuration
1. Backup existing `server.cnf` to `server.cnf.bak`
2. Deploy `server.cnf` template with optimized settings
3. Backup existing `client.cnf` to `client.cnf.bak`
4. Deploy `client.cnf` template

### Phase 4: Service Startup
1. Enable MariaDB service
2. Start MariaDB service
3. Wait for socket availability

### Phase 5: Security Hardening
1. Check for existing setup flag
2. Set root password (first run only)
3. Create root credentials file (`/root/.my.cnf`)
4. Remove anonymous users
5. Remove test database
6. Disable remote root login
7. Create setup complete flag

### Phase 6: User Management
1. Create remote_user with full privileges (% host)
2. Create webclient user (localhost)

### Phase 7: Performance Tuning
1. Detect server memory
2. Calculate optimal settings
3. Configure InnoDB buffer pool
4. Configure query cache
5. Configure connection limits

### Phase 8: Backup Setup
1. Create backup directory
2. Deploy backup script
3. Configure cron schedule

## Database Users Created

| Username | Host | Privileges | Purpose |
|----------|------|------------|---------|
| `root` | `localhost` | ALL | Database administrator (socket auth) |
| `{{ db_remote_user }}` | `%` | ALL | Remote database administration |
| `webclient` | `localhost` | ALL | Web application database access |

**Note**: All passwords are managed via Ansible Vault or environment variables for security.

## Example Playbook

### Basic Usage

```yaml
---
- hosts: database_servers
  become: true
  roles:
    - role: mariadb
```

### Custom Configuration

```yaml
---
- hosts: database_servers
  become: true
  vars:
    db_bind_address: "0.0.0.0"  # Listen on all interfaces
    db_backup_dir: "/mnt/backups/mysql"
    db_remote_user: "dbadmin"
  roles:
    - role: mariadb
```

### With Vault Variables

```yaml
---
- hosts: database_servers
  become: true
  vars_files:
    - vars/secrets.yml  # Contains vault_db_root_password, etc.
  roles:
    - role: mariadb
```

### Vault File Structure (`vars/secrets.yml`)

```yaml
---
vault_db_root_password: "SuperSecureRootPass123!"
vault_db_remote_user: "admin"
vault_db_remote_password: "SecureAdminPass456!"
vault_db_webclient_password: "WebClientPass789!"
```

Encrypt with: `ansible-vault encrypt vars/secrets.yml`

## Performance Tuning

The role automatically adjusts settings based on available memory:

### Memory-Based Configuration Tiers

| Memory | InnoDB Buffer Pool | Max Connections | Query Cache | Optimization Level |
|--------|-------------------|-----------------|-------------|-------------------|
| < 2GB | 512MB | 100 | 32MB | Minimal |
| 2-4GB | 1GB | 150 | 64MB | Standard |
| 4-8GB | 2GB | 200 | 128MB | Enhanced |
| 8GB+ | 4GB | 300 | 256MB | Maximum |

### Manual Performance Override

```yaml
# In group_vars/all.yml or host_vars
db_optimize_for_server: false  # Disable automatic tuning

# Manually set in templates/server.cnf.j2:
innodb_buffer_pool_size = 4G
max_connections = 500
query_cache_size = 512M
```

## Testing

### Molecule Test Results

**Test Environment**: Docker (dokken/almalinux-9)  
**Test Framework**: Ansible Molecule 6.0.3  
**Date**: January 31, 2026

#### Test Matrix
- **Dependency**: ✅ Passed
- **Syntax**: ✅ Passed
- **Create**: ✅ Passed
- **Prepare**: ✅ Passed (15 tasks, 4 changed)
- **Converge**: ✅ Passed (19 tasks, 7 changed)
- **Idempotence**: ✅ Passed (18 tasks, 0 changed)
- **Verify**: ✅ Passed (18 tasks, 0 changed)

#### Converge Phase Details
```
TASK SUMMARY (First Run):
- Install MariaDB packages: changed
- Create log directory: changed
- Create config directory: changed
- Backup server.cnf: changed
- Configure server.cnf: ok (already exists from previous run)
- Backup client.cnf: changed
- Configure client.cnf: ok
- Enable/start MariaDB: ok
- Create database users: changed (2 users)
- Create backup directory: changed
- Setup backup cron: changed
- Performance tuning: changed (2 tasks)

PLAY RECAP:
✅ ok=19 changed=7 unreachable=0 failed=0 skipped=6 rescued=0 ignored=0
```

#### Idempotence Phase Details
```
PLAY RECAP:
✅ ok=18 changed=0 unreachable=0 failed=0 skipped=6 rescued=0 ignored=0

Result: IDEMPOTENT ✅
All tasks return 'ok' status on second run - no unnecessary changes made.
```

#### Verify Phase
- All services verified running
- All configuration files verified present
- All database users verified created
- All backup configurations verified in place

## Troubleshooting

### Issue: MariaDB fails to start

**Symptoms**: Service fails with "Unit mariadb.service failed to start"

**Solutions**:
```bash
# Check logs
sudo journalctl -xeu mariadb.service

# Verify configuration syntax
sudo mysqld --verbose --help

# Check file permissions
sudo ls -la /var/lib/mysql
sudo chown -R mysql:mysql /var/lib/mysql

# Check SELinux contexts
sudo restorecon -R /var/lib/mysql
```

### Issue: Cannot connect to MariaDB

**Symptoms**: "ERROR 2002: Can't connect to local MySQL server through socket"

**Solutions**:
```bash
# Verify service is running
sudo systemctl status mariadb

# Check socket file exists
ls -la /var/lib/mysql/mysql.sock

# Verify bind address
sudo grep bind-address /etc/my.cnf.d/server.cnf

# Test connection
mysql -u root -p
```

### Issue: Performance degradation

**Symptoms**: Slow queries, high memory usage

**Solutions**:
```bash
# Check current settings
mysql -u root -p -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size';"
mysql -u root -p -e "SHOW VARIABLES LIKE 'max_connections';"

# Monitor active connections
mysql -u root -p -e "SHOW PROCESSLIST;"

# Check slow query log
sudo tail -f /var/log/mariadb/mariadb-slow.log
```

### Issue: Backup fails

**Symptoms**: Cron backup doesn't execute or completes with errors

**Solutions**:
```bash
# Test backup script manually
sudo /usr/local/bin/mysql-backup.sh

# Check backup directory permissions
sudo ls -la /var/backups/mysql

# Verify cron configuration
sudo crontab -l

# Check backup logs
sudo journalctl | grep mysql-backup
```

### Issue: User authentication fails

**Symptoms**: "Access denied for user 'webclient'@'localhost'"

**Solutions**:
```bash
# Verify user exists
mysql -u root -p -e "SELECT User, Host FROM mysql.user;"

# Check user privileges
mysql -u root -p -e "SHOW GRANTS FOR 'webclient'@'localhost';"

# Reset user password
mysql -u root -p -e "ALTER USER 'webclient'@'localhost' IDENTIFIED BY 'NewPassword';"
mysql -u root -p -e "FLUSH PRIVILEGES;"
```

## Security Considerations

### Password Management
- **Always use Ansible Vault** for production passwords
- Never commit plaintext passwords to version control
- Rotate passwords regularly (quarterly recommended)
- Use strong passwords (16+ characters, mixed case, numbers, symbols)

### Network Security
- Default `bind_address: 127.0.0.1` (localhost only)
- For remote access, use firewalls to restrict source IPs
- Consider SSL/TLS for remote connections
- Disable remote root login (enforced by role)

### File Permissions
- Configuration files: `0644` (root:root)
- Root credentials: `0600` (root:root)
- Data directory: `0755` (mysql:mysql)
- Socket file: `0777` (mysql:mysql)

### Backup Security
- Encrypt backups for offsite storage
- Restrict backup directory access (0700 recommended)
- Test restore procedures regularly
- Implement backup retention policies

### Audit Logging
```sql
-- Enable audit plugin (manual configuration)
INSTALL PLUGIN server_audit SONAME 'server_audit.so';
SET GLOBAL server_audit_events = 'CONNECT,QUERY_DDL,QUERY_DML';
SET GLOBAL server_audit_logging = ON;
```

## File Structure

```
roles/mariadb/
├── README.md                      # This documentation
├── defaults/
│   └── main.yml                   # Default variables (36 lines)
├── handlers/
│   └── main.yml                   # Service restart handler
├── meta/
│   └── main.yml                   # Role metadata and dependencies
├── molecule/
│   └── default/
│       ├── converge.yml          # Test playbook
│       ├── molecule.yml          # Molecule configuration
│       ├── prepare.yml           # Test preparation tasks
│       └── verify.yml            # Verification tests
├── tasks/
│   ├── main.yml                  # Primary tasks (162 lines)
│   └── performance.yml           # Performance tuning tasks
└── templates/
    ├── client.cnf.j2             # Client configuration template
    ├── root.my.cnf.j2            # Root credentials template
    └── server.cnf.j2             # Server configuration template
```

## License

MIT

## Author Information

Created and maintained as part of the VPS automation project.

**Repository**: https://github.com/yourusername/vps  
**Role Path**: `roles/mariadb`  
**Last Updated**: January 2026  
**Tested On**: AlmaLinux 9.5

## Example Playbook

```yaml
- hosts: database_servers
  roles:
    - role: mariadb
      vars:
        db_optimize_for_server: true
```

## Password Management

Passwords are managed securely using Ansible Vault. To use vault passwords:

1. Create/edit the vault file:
   ```
   ansible-vault edit vars/secrets.yml
   ```

2. Add the MariaDB passwords:
   ```yaml
   vault_db_root_password: "secure-password-here"
   vault_db_standard_password: "another-secure-password"
   ```

3. Run playbooks with:
   ```
   ansible-playbook playbooks/setup.yml --ask-vault-pass
   ```

## Custom Configuration

Advanced database settings are split across multiple configuration files:

- `server.cnf.j2` - Main server configuration
- `client.cnf.j2` - Client configuration 
- `performance.cnf.j2` - Performance tuning
- `innodb.cnf.j2` - InnoDB storage engine settings

## License

MIT
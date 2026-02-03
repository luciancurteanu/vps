# VPS Setup Templates

This directory contains global templates used across the VPS setup project for virtual hosts, PHP configuration, and starter website files.

## Directory Structure

- `nginx/` - Nginx server configuration templates
- `php/` - PHP-FPM pool configuration templates
- `website/` - Default website files for new virtual hosts

## Nginx Templates

### vhost.conf.j2

The main virtual host template for Nginx server blocks. This template is used when creating new virtual hosts with the `create_vhost.yml` playbook.

Key features:
- Server name configuration with domain and www subdomain
- Document root configuration
- PHP processing via Unix socket
- Static file handling with proper caching headers
- Security headers and restrictions
- Custom error pages
- Log file configuration

## PHP Templates

### pool.conf.j2

PHP-FPM pool configuration template. A dedicated PHP-FPM pool is created for each virtual host to provide isolation between sites.

Key features:
- Per-domain PHP process management
- User-specific ownership and permissions
- Resource limits for PHP processes
- Custom PHP settings per domain
- Unix socket configuration for Nginx integration

## Website Templates

### index.html.j2

Default homepage template for new virtual hosts. This provides a professional-looking starter page with:
- Responsive design
- Placeholder content that can be easily customized
- Information about the domain and hosting environment
- Basic styling

### Additional Files

The website directory also contains:
- `favicon.png` - Default favicon
- `style.css` - CSS styles for the default homepage
- Images and other static assets

## Using the Templates

These templates are used automatically by the VPS setup playbooks. When you create a new virtual host, the appropriate templates are processed with the domain-specific variables and deployed to the server.

To customize the default website appearance or server configurations, you can modify these templates before running the playbooks.

## Variables Used in Templates

The templates use variables from:
- Command line parameters passed to `vps.sh`
- `inventory/group_vars/all.yml`
- Role-specific variables
- Host-specific variables

## Example Template Usage

When you run:

```bash
./vps.sh create host --domain=yourdomain.com
```

The system:
1. Processes `vhost.conf.j2` with domain=yourdomain.com
2. Creates `/etc/nginx/sites-available/yourdomain.com.conf` and symlinks it into `/etc/nginx/sites-enabled/`
3. Processes `pool.conf.j2` with domain=yourdomain.com
4. Creates `/etc/php-fpm.d/yourdomain.com.conf`
5. Copies website templates to `/home/yourdomain.com/public_html/`
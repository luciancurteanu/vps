# Development Role

This role installs common development tools for web application development, focusing on PHP/Laravel and JavaScript ecosystems.

## Features

- Composer PHP dependency manager with signature verification
- Laravel installer with version constraints
- Node.js and npm (latest LTS version)
- Common development utilities
- Version control tools
- Latest stable releases of all components
- Secure installation procedures

## Requirements

- Ansible 2.9 or higher
- AlmaLinux 9 or compatible distribution
- PHP role should be installed first

## Role Variables

See `defaults/main.yml` for all available variables.

### Important variables:

```yaml
# Component versions
nodejs_version: "22"  # Latest LTS as of April 2025
composer_version: "latest"  # Always installs Composer 2.x

# Installation flags
install_composer: true
install_laravel: true
install_nodejs: true

# Paths
composer_install_dir: "/usr/local/bin"
```

## Components

### Composer

Installs the latest version of Composer 2.x globally with:
- Signature verification for downloaded installer
- System-wide availability
- Proper PATH configuration
- Global dependencies management
- Authentication setup for private repositories (if configured)

### Laravel

Sets up Laravel installer (version 5.x) with:
- Version-constrained global installation via Composer
- Automatic PATH configuration using Composer's bin directory
- Laravel new project command availability
- Version verification

### Node.js

Installs Node.js with:
- Official Node.js repository
- Latest LTS version (22.x as of April 2025)
- npm package manager
- Global npm packages (if configured)

## Example Usage

After installing this role, you can:

1. **Create a Laravel project**:
   ```bash
   cd /home/domain.com
   laravel new application
   ```

2. **Manage PHP dependencies**:
   ```bash
   cd /home/domain.com/application
   composer require vendor/package
   ```

3. **Work with Node.js**:
   ```bash
   cd /home/domain.com/application
   npm install
   npm run dev
   ```

## Example Playbook

```yaml
- hosts: servers
  roles:
    - role: php
    - role: development
      vars:
        nodejs_version: "22"
```

## License

MIT
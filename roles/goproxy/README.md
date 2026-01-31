# GoProxy Role

This role installs and configures GoProxy with Tor integration for anonymous proxy services.

## Features

- Go language installation from official repository
- Dedicated GoProxy user creation and management
- Private repository cloning with access token
- Installation of specific Go dependencies with version control
- Tor configuration and installation
- GoProxy setup using Python installer
- Systemd service configuration

## Requirements

- Ansible 2.9 or higher
- AlmaLinux 9 or compatible distribution

## Role Variables

See `defaults/main.yml` for all available variables.

### Important variables:

```yaml
# Go version - sourced from environment variable with fallback
go_version: "{{ GO_VERSION | default('1.21.0') }}"

# Repository credentials are handled securely with access tokens

# Installation paths
# - Go is installed to /usr/lib/go
# - GoProxy is installed to /usr/lib/goproxy
# - User home is created at /home/goproxy

# Services
# - Both tor and goproxy services are enabled and started
```
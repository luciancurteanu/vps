````markdown
# VPS Shell Script

This script serves as the command-line interface for the VPS project, providing a convenient wrapper around Ansible playbooks.

## Features

- Simple command-line interface for all VPS management operations
- Consistent argument parsing and validation
- Integration with Ansible Vault for secure password management
- Automatic username derivation from domain names
- Performance timing for operations
- Colorized output for better readability
- Support for all major VPS management tasks

## Usage

The script follows a consistent command structure:

```bash
./vps.sh <command> <module> [options]
```

## Examples

### Basic Server Setup
```bash
./vps.sh install core --domain=vps.test
```

### Adding a New Domain
```bash
./vps.sh create host --domain=newsite.com
```

### Removing a Domain
```bash
./vps.sh remove host --domain=oldsite.com
```

### Installing SSL Certificates
```bash
./vps.sh install ssl --domain=vps.test
```

## Ansible Integration

The script automatically validates required arguments, maps commands and modules to playbooks, and executes Ansible with the appropriate extra vars and vault options.

## Vault Integration

For secure operations with passwords:

```bash
./vps.sh install core --domain=vps.test --ask-vault-pass
```

Or using a vault password file:

```bash
./vps.sh install core --domain=vps.test --vault-password-file=~/.vault_pass
```

## Dependencies

- Bash 4+
- Ansible 2.9+
- Access to the target server with SSH

````

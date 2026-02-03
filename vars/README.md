# VPS Setup Vault and Variables

This directory contains sensitive vault-encrypted variables and other global variable files used across the project.

## Key Files

- `secrets.yml` - Ansible Vault encrypted file containing sensitive credentials

## Ansible Vault for Secure Password Management

The `secrets.yml` file is designed to be encrypted with Ansible Vault, making it safe to store sensitive credentials like database passwords, API keys, and user credentials.

### Recommended Password Variables

The following password variables should be defined in your vault file:

```yaml
# MariaDB passwords
vault_db_root_password: "secure-root-password"
vault_db_webclient_password: "secure-webclient-password"
vault_db_remote_password: "secure-remote-password"

# Admin user password
vault_admin_password: "secure-admin-password"
vault_admin_ssh_public_key: "ssh-ed25519 AAAA... your-key-here"

# Domain user password (if master_domain is true)
vault_domain_user_password: "secure-domain-user-password"

# Mail service passwords
vault_mail_db_password: "secure-mail-db-password"
vault_roundcube_db_password: "secure-roundcube-password"
vault_mail_default_password: "secure-mail-default-password"

# Cockpit uses system authentication (no separate password needed)
# Login with admin user and vault_admin_password
```

## Creating and Editing the Vault

### Creating a New Vault

If you haven't created the vault file yet:

```bash
ansible-vault create vars/secrets.yml
```

### Editing an Existing Vault

To update passwords in an existing vault:

```bash
ansible-vault edit vars/secrets.yml
```

### Viewing Vault Contents

To view the contents without editing:

```bash
ansible-vault view vars/secrets.yml
```

## Using the Vault with Playbooks

When running playbooks that reference vault-encrypted variables, you need to provide your vault password:

```bash
# Prompt for vault password
ansible-playbook playbooks/setup.yml --ask-pass --ask-vault-pass

# Use a password file
ansible-playbook playbooks/setup.yml --ask-pass --vault-password-file=~/.vault_pass
```

### With the VPS Script

When using the `vps.sh` script, you can pass vault options:

```bash
./vps.sh install core --domain=vps.test --ask-pass --ask-vault-pass
```

## Vault Password File

For automation purposes, you can create a vault password file:

1. Create a file with your vault password:
   ```bash
   echo "your-vault-password" > ~/.vault_pass
   chmod 600 ~/.vault_pass
   ```

2. Reference it in your commands:
   ```bash
   ./vps.sh install core --domain=vps.test --ask-pass --vault-password-file=~/.vault_pass
   ```

## Security Best Practices

1. Use strong, unique passwords for each service
2. Keep your vault password separate from the vault file
3. Regularly rotate passwords in the vault file
4. Ensure vault files are never committed to version control in unencrypted form
5. Limit access to the vault password to authorized personnel only
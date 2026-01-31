# Mail Role

This role installs and configures a complete mail server stack with Postfix, Dovecot, OpenDKIM, and Roundcube webmail.

## Features

- Complete mail server setup with POP3, IMAP, and SMTP services
- Secure configuration with TLS/SSL encryption
- OpenDKIM for DKIM email signing
- Roundcube webmail interface
- MySQL backend for user and domain management
- Virtual domain and mailbox configuration
- Proper mail directories and permissions
- Integration with Let's Encrypt for SSL certificates

## Requirements

- Ansible 2.9 or higher
- CentOS 9 Stream or compatible distribution
- Valid domain with proper DNS configuration (MX, A, TXT records)
- Nginx and PHP roles should be installed first

## Role Variables

See `defaults/main.yml` for all available variables.

### Important variables:

```yaml
# Mail domain settings
mail_domain: "{{ domain }}"
mail_subdomain: "mail.{{ domain }}"
mail_hostname: "{{ mail_subdomain }}"

# Database settings for mail services
mail_db_name: "mailserver"
mail_db_user: "mailuser"
mail_db_password: "{{ vault_mail_db_password | default(lookup('env', 'MAIL_DB_PASSWORD'), true) }}"

# Webmail settings
webmail_path: "/home/{{ domain }}/roundcube"
webmail_version: "1.6.10"

# Roundcube database settings
roundcube_db_name: "roundcube"
roundcube_db_user: "roundcube"
roundcube_db_password: "{{ vault_roundcube_db_password | default(lookup('env', 'ROUNDCUBE_DB_PASSWORD'), true) }}"
```

## DNS Configuration Requirements

For the mail server to work properly, you need to set up these DNS records:

1. **MX record**: 
   ```
   vps.test. IN MX 10 mail.vps.test.
   ```

2. **SPF record**:
   ```
   vps.test. IN TXT "v=spf1 a mx ip4:YOUR_SERVER_IP ~all"
   ```

3. **DKIM record**: (generated during installation)
   ```
   mail._domainkey.vps.test. IN TXT "v=DKIM1; k=rsa; p=MIIBIjANBgk..."
   ```

4. **DMARC record**:
   ```
   _dmarc.vps.test. IN TXT "v=DMARC1; p=none; rua=mailto:postmaster@vps.test"
   ```

## Included Components

The role sets up and configures:

- **Postfix** - Mail Transfer Agent (MTA)
- **Dovecot** - POP3/IMAP server
- **OpenDKIM** - DKIM email authentication
- **Roundcube** - Webmail interface
- **MySQL Database** - Backend storage for mail accounts

## Password Management

Mail passwords are managed securely using Ansible Vault. To set up:

1. Edit the vault file:
   ```
   ansible-vault edit vars/secrets.yml
   ```

2. Add the mail-related passwords:
   ```yaml
   vault_mail_db_password: "secure-mail-db-password-here"
   vault_roundcube_db_password: "secure-roundcube-password-here"
   ```

## Example Playbook

```yaml
- hosts: mail_servers
  roles:
    - role: nginx
    - role: php
    - role: mail
      vars:
        mail_domain: "vps.test"
```

## License

MIT
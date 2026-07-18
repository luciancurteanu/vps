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

## Effective SSL behavior

This role now distinguishes between **requested SSL mode** and **effective SSL mode** at runtime.

### Mail protocols: Postfix and Dovecot

If `mail_use_letsencrypt: true` is set, the role checks whether these files actually exist:

- `/etc/letsencrypt/live/{{ domain }}/fullchain.pem`
- `/etc/letsencrypt/live/{{ domain }}/privkey.pem`
- `/etc/letsencrypt/live/{{ domain }}/chain.pem`

Behavior:

- **Files exist** → Postfix and Dovecot use the Let's Encrypt certificate paths.
- **Files missing** → the role falls back to local certificate paths under `mail_ssl_dir` instead of rendering broken LE references.

For Postfix, both outbound SMTP TLS (`smtp_*`) and inbound SMTP daemon TLS (`smtpd_*`) are configured with the effective certificate paths so port 25, submission, and SMTPS have server certificates available after reload.

This prevents Dovecot/Postfix from failing just because a variable requested Let's Encrypt before certificates had been issued.

Postfix MySQL map files under `/etc/postfix/mysql-virtual-*.cf` contain database credentials and are installed as `root:postfix` with mode `0640`.

### Webmail vhost: `mail.{{ domain }}`

The nginx webmail vhost also uses an effective SSL check:

- **Web TLS assets exist** → HTTP redirects to HTTPS and a 443 server block is rendered.
- **Web TLS assets missing** → only the HTTP server block is used for that run.

## SSL-related variables

Useful variables for this behavior include:

```yaml
mail_use_letsencrypt: false
mail_ssl_dir: "/etc/ssl/local/{{ domain }}"
mail_ssl_enabled: true
mail_enable_ssl: false
```

- `mail_use_letsencrypt` controls whether LE is preferred for mail services.
- `mail_ssl_enabled` controls whether Dovecot SSL services should be enabled.
- `mail_enable_ssl` controls whether the webmail nginx vhost should redirect/render HTTPS.

Even when these are `true`, the role only enables the SSL path if the required files are present.

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
   yourdomain.com. IN MX 10 mail.yourdomain.com.
   ```

2. **SPF record**:
   ```
   yourdomain.com. IN TXT "v=spf1 a mx ip4:YOUR_SERVER_IP ~all"
   ```

3. **DKIM record**: (generated during installation)
   ```
   default._domainkey.yourdomain.com. IN TXT "v=DKIM1; k=rsa; p=MIIBIjANBgk..."
   ```

4. **DMARC record**:
   ```
   _dmarc.yourdomain.com. IN TXT "v=DMARC1; p=none; rua=mailto:postmaster@yourdomain.com"
   ```

## Included Components

The role sets up and configures:

- **Postfix** - Mail Transfer Agent (MTA)
- **Dovecot** - POP3/IMAP server
- **OpenDKIM** - DKIM email authentication
- **Roundcube** - Webmail interface
- **MySQL Database** - Backend storage for mail accounts

### Roundcube user behavior

Roundcube does **not** create mailbox accounts in `mailserver.users`.

- Mailboxes are created and managed by the mail role / database provisioning.
- Roundcube stores its own webmail preferences and session/user metadata in the `roundcube` database.

So a user appearing in Roundcube is not the same thing as provisioning a new mail account.

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
            mail_domain: "yourdomain.com"
```

## License

MIT
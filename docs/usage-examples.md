# Usage examples — master (full) vs non-master (config-only)

This file shows concrete commands and the expected behavior for a master server (full install) and a non-master virtual host (config-only).

**Assumptions**
- Inventory entry for the master host uses the domain name as the `inventory_hostname` (e.g., `vps.test` in `inventory/hosts`).
- `master_domain` in `inventory/group_vars/all.yml` is configured as:

  ```yaml
  master_domain: "{{ domain | default(inventory_hostname) }}"
  ```

  so passing `--domain=vps.test` makes `vps.test` the master for that run.

---

## 1) Full master install (vps.test)

Command:
```bash
./vps.sh install core --domain=vps.test
```

What this does:
- `vps.sh` passes `domain=vps.test` to Ansible and automatically adds `--tags setup`.
- The `playbooks/setup.yml` roles tagged `setup` are selected.
- On the host matching `vps.test` (master) the playbook will perform the full installation and configuration: `common`, `security`, `nginx`, `php`, `mariadb`, `python`, `mail`, `webmin`, `goproxy` (subject to per-role `install_*` vars, which default to `true`).
- Packages, services, users, DBs and control panel will be installed and configured.

Quick checks (dry-run / syntax-check):
```bash
ansible-inventory --list -i inventory/hosts -e domain=vps.test
ansible-playbook --syntax-check playbooks/setup.yml -i inventory/hosts -e domain=vps.test --tags setup
```

---

## 2) Create a non-master virtual host (lucian.com)

Command:
```bash
./vps.sh create host --domain=lucian.com
# or with explicit user
./vps.sh create host --domain=lucian.com --user=lucian
```

What this does:
- Runs `playbooks/create_vhost.yml` with `domain=lucian.com` (and `user` derived if not provided).
- Tasks performed include: create user, document root, logs, PHP-FPM pool, Nginx vhost, site files, permissions.
- Mail/site-specific config tasks run in the `create_vhost` playbook:
  - For non-master domains (`domain != master_domain`) the playbook will add Postfix virtual entries, configure OpenDKIM keys, and ensure mail-related config files exist — but it does not install or enable system-wide services that are intended only for master (mariadb, full mail server setup, webmin, etc.).
- This gives `lucian.com` the web + mail configuration it needs without performing a full `core` installation.

Quick checks (syntax-check):
```bash
ansible-playbook --syntax-check playbooks/create_vhost.yml -i inventory/hosts -e domain=lucian.com,user=lucian
```

---

## Notes and tips
- If you ever want to *only* run configuration (no package installs) for a host with `setup` tags, make sure role-internal install tasks are guarded with `when: domain == master_domain` or a per-role `install_*` variable (e.g. `install_mariadb: false`).
- Example to disable a role on a run:

```bash
./vps.sh install core --domain=vps.test --extra-vars "install_webmin=false"
```

- If you want `lucian.com` to receive only templates/configs (not package installs) via `install core`, prefer running `./vps.sh create host` for that host — the `create_vhost` playbook is designed for config-level operations for additional domains.

---

## What each domain will install / create

- Master domain (vps.test) — `./vps.sh install core --domain=vps.test`
  - Roles/packages installed and configured (subject to `install_*` flags):
    - `common` (base users, system defaults)
    - `security` (ssh hardening, firewall, fail2ban)
    - `nginx` (web server and global config)
    - `php` / `php-fpm` (PHP runtime and pools)
    - `mariadb` (database server)
    - `python` (python runtime, tooling)
    - `mail` (full mail stack packages and configuration: postfix, dovecot, roundcube, OpenDKIM)
    - `webmin` (control panel)
    - `goproxy` (proxy service)
  - System artefacts created:
    - system users, backups, log directories, SSL directories for master domain
    - master-specific SFTP group and SSH Match rules
    - DNS/subdomain templates (`mail.`, `cpanel.`) and mail service DB entries

- Non-master virtual host (lucian.com) — `./vps.sh create host --domain=lucian.com`
  - Actions performed by `create_vhost.yml` (configuration-only):
    - create site system user and home directory
    - create document root (`/home/lucian.com/public_html`), logs, tmp, ssl, backup folders
    - deploy website template files and `index.html`
    - configure PHP-FPM pool (`/etc/php-fpm.d/lucian.com.conf`)
    - configure nginx vhost (`/etc/nginx/sites-available/lucian.com.conf`)
    - add domain entries to Postfix/OpenDKIM configuration (virtual maps, keys)
    - set file permissions and SFTP user membership only if master-specific tasks are required

These behaviors assume `master_domain: "{{ domain | default(inventory_hostname) }}"` is set so the CLI `--domain` designates the master for that run.

If you want, I can:
- Add example `host_vars/lucian.com.yml` to set non-master-specific flags (e.g., `install_*: false`).
- Modify roles to split `install` vs `config` tasks and tag them `install`/`config` for more granular control.


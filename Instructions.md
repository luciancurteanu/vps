# Production adminment Guide - Fresh AlmaLinux Server

## Prerequisites
- Fresh AlmaLinux installation
- Root access to the server (either direct root login OR a user with sudo privileges)
- Domain name with DNS configured (A record pointing to server IP)

---

## Method 1: Manual Upload (No Git on Server)

### Step 1: Connect to Server
```bash
# Login as admin user (has sudo privileges)
ssh admin@192.168.88.8
# Password: Changeme123!
# OR 
ssh localhost
```

### Step 2: Upload Files to Server

**First, create the directory on the server if it doesn't exist:**
```bash
mkdir -p /home/admin/vps
```

**Upload these files/folders to `/home/admin/vps/` on the server using your SFTP/FTP client:**
**Login as: admin** (password: Changeme123!)
- `ansible.cfg`
- `vps.sh`
- `bootstrap.sh`
- `inventory/` (entire folder)
- `playbooks/` (entire folder)
- `roles/` (entire folder)
- `templates/` (entire folder)
- `vars/` (entire folder)

**Exclude these (not needed):**
- `.git/`, `.venv/`, `.vscode/`, `.github/`, `docs/`, `scripts/`

**Then on the server:**
```bash
# Navigate to the uploaded directory
cd vps

# Make scripts executable
chmod +x vps.sh bootstrap.sh encrypt-vault.sh
```

### Step 3: Install Ansible
```bash
# Install EPEL repository, Ansible and verify installation (as admin user with sudo)
sudo dnf install epel-release -y && sudo dnf install nano -y && sudo dnf update -y && sudo dnf install ansible -y && ansible --version
```

### Step 4: Configure Inventory
```bash
# Copy example hosts file
cp inventory/hosts.example inventory/hosts

# Edit the hosts file
nano inventory/hosts
```

⚠️ **IMPORTANT:** This configuration is for **INITIAL adminMENT ONLY**. After the first successful run, you MUST change `ansible_user=admin` to `ansible_user=admin`.

Ensure it contains:
```
[all:vars]
ansible_connection=ssh
ansible_user=admin       # ⚠️ INITIAL adminMENT - Change to 'admin' after first run!
ansible_port="{{ ssh_port }}"

[primary]
vps.test ansible_host=192.168.88.8

[webservers:children]
primary

[database:children]
primary

[mail:children]
primary
```

### Step 5: Configure Group Variables
```bash
# Copy example all.yml file
cp inventory/group_vars/all.yml.example inventory/group_vars/all.yml

# Edit if you need to customize any settings (optional)
nano inventory/group_vars/all.yml
```

**Note:** `master_domain` is automatically set from `--domain` parameter, no need to edit it.

### Step 6: Create Secrets Vault
```bash
# Copy example secrets file
cp vars/secrets.yml.example vars/secrets.yml

# Edit with your actual passwords
nano vars/secrets.yml
```

**Update with your actual values:**
```yaml
---
# Core system secrets
vault_admin_password: "YourStrongAdminPassword123!"
vault_admin_ssh_public_key: "ssh-ed25519 AAAAC... your-key-here"
vault_domain_user_password: "YourDomainUserPassword456!"

# Database passwords
vault_db_root_password: "YourStrongRootPassword789!"
vault_db_standard_password: "YourStandardDbPassword012!"

# Mail server passwords
vault_mail_db_password: "YourMailDbPassword345!"
vault_roundcube_db_password: "YourRoundcubePassword678!"
vault_smtp_username: "smtp@vps.test"
vault_smtp_password: "YourSmtpPassword901!"

# SSL/Let's Encrypt
vault_letsencrypt_email: "contact@vps.test"
```

**Save the file, then encrypt it:**

```bash
# Simple interactive method (RECOMMENDED for initial adminment)
# NOTE: Do NOT use sudo - ansible-vault should run as admin user
ansible-vault encrypt vars/secrets.yml
```

You'll be prompted to create a vault password. **Remember this password** — you'll need it in Step 7.

<details>
<summary>📋 Alternative Encryption Methods (Click to expand)</summary>

**Using the helper script (ephemeral):**
```bash
sh encrypt-vault.sh
```

**Using the helper script (persistent - creates ~/.vault_pass):**
```bash
sh encrypt-vault.sh persistent
```

**Manual secure method:**
```bash
read -s -p "Vault password: " VAULT_PASS
printf "%s\n" "$VAULT_PASS" > ~/.vault_pass
chmod 600 ~/.vault_pass
unset VAULT_PASS
ansible-vault encrypt --vault-password-file=~/.vault_pass vars/secrets.yml
```

**Security note:** Prefer the ephemeral helper or an encrypted secret store (GPG/secret manager) rather than leaving plaintext password files on disk.

</details>


### Step 7: Run adminment

**For INITIAL adminment (you're here now):**

```bash
# Run this command - you'll be prompted for passwords
./vps.sh install core --domain=vps.test --ask-pass --ask-vault-pass
```

**When prompted:**
- **SSH password**: Enter admin user password (Changeme123!)
- **Vault password**: Enter the vault password you just created in Step 6

⚠️ **IMPORTANT - After successful adminment:**
1. Edit `inventory/hosts` and change `ansible_user=admin` to `ansible_user=admin`
2. For future runs, use: `./vps.sh install core --domain=vps.test --vault-password-file=~/.vault_pass`

<details>
<summary>📋 Detailed Command Explanation (Click to expand)</summary>

**When to use which options:**

- **Initial adminment (first run, no SSH keys set up):**
  - Use `--ask-pass --ask-vault-pass` to prompt for both SSH (admin user) password and vault password interactively.
  - Command: `./vps.sh install core --domain=vps.test --ask-pass --ask-vault-pass`

- **Subsequent runs (after first successful adminment):**
  - Update `inventory/hosts` to change `ansible_user=admin` to `ansible_user=admin` (the `admin` user is created with your SSH key).
  - Use `--vault-password-file=~/.vault_pass` for non-interactive vault access (create `~/.vault_pass` securely first).
  - Command: `./vps.sh install core --domain=vps.test --vault-password-file=~/.vault_pass`
  - No `--ask-pass` needed since `admin` has key-based auth.

- **Vault password handling:**
  - Run `sh encrypt-vault.sh` (ephemeral, recommended) to create a temporary vault password file automatically.
  - Or run `sh encrypt-vault.sh persistent` to create `~/.vault_pass` permanently.
  - Avoid manual creation unless necessary; always `chmod 600` any password file and store only on the control node.

- **Security notes:**
  - Never store vault password files on shared machines.
  - Use `--ask-vault-pass` only if you prefer interactive prompts over files.
  - The `--vault-password-file` path refers to a file on the machine where you run `vps.sh` (the control node), not the remote target server.

</details>

---

## Method 2: Using Git (If Git Available or Installing)

### Step 1: Install Git and Clone Repository
```bash
# Update system and install Git
sudo dnf update -y
sudo dnf install -y git

# Clone repository (if committed to GitHub)
git clone https://github.com/luciancurteanu/vps.git
cd vps
```

### Step 2: Make Scripts Executable
```bash
chmod +x vps.sh bootstrap.sh
```

### Step 3-7: Follow steps 3-7 from Method 1 above

---

## Method 3: Using Bootstrap Script (For Fresh Git Clone)

### If repository is on GitHub and committed:
```bash
# Install curl
sudo dnf install -y curl

# Download and run bootstrap
curl -O https://raw.githubusercontent.com/luciancurteanu/vps/master/bootstrap.sh
chmod +x bootstrap.sh
./bootstrap.sh

# Navigate to cloned directory
cd vps

# Configure inventory and vault (follow steps 3-6 from Method 1)
# Then run adminment
./vps.sh install core --domain=vps.test --ask-pass --ask-vault-pass
```

---

## Important Notes

⚠️ **CRITICAL WARNINGS:**
1. **Initial Login**: Perform installation as **admin** user (with sudo privileges)
2. **SSH Port**: Default is 22 (configured in group_vars/all.yml as `ssh_port`)
3. **Root Login**: Root SSH will be disabled after installation - use `admin` user afterward
4. **Vault Password**: Save your vault password securely - needed for future operations
5. **DNS Required**: Ensure DNS A record points to 192.168.88.8 before SSL setup
6. **Firewall**: Server will configure firewall - ensure you don't lock yourself out
7. **SSH Key**: Add your public SSH key to `vault_admin_ssh_public_key` for passwordless login

**After First Installation:**
- Login as: `admin` (not root)
- SSH: Port 22
- Authentication: SSH key (recommended) or password from vault_admin_password

**What Gets Installed:**
- ✅ System hardening (firewall, fail2ban, SSH security)
- ✅ Nginx web server
- ✅ PHP 8.4
- ✅ MariaDB 11.4 database
- ✅ Python automation tools
- ✅ Mail server (Postfix, Dovecot, Roundcube)
- ✅ Cockpit control panel (port 9090)
- ✅ GoProxy with Tor support
- ✅ SSL certificates (Let's Encrypt)

**After Installation:**
- SSH: Port 22 (or custom port from vault)
- Cockpit: https://vps.test:9090
- Mail: https://mail.vps.test
- Website: https://vps.test

---

## Troubleshooting

**If adminment fails:**
```bash
# Check Ansible log
tail -f ansible.log

# Test connectivity
ansible all -m ping -i inventory/hosts

# Run specific role only (use --ask-pass on first run)
./vps.sh install core --domain=vps.test --ask-pass --ask-vault-pass --tags=common
```

**To re-run after fixing issues:**
```bash
# Ansible is idempotent - safe to re-run
# Note: After first run, admin user has SSH key - no --ask-pass needed
./vps.sh install core --domain=vps.test --vault-password-file=~/.vault_pass
```
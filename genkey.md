# SSH Key Generation Guide

SSH keys authenticate Ansible against the server. The public key is stored in
`vars/secrets.yml` under `vault_admin_ssh_public_key` and deployed to
`~/.ssh/authorized_keys` on the server by `install core`.

---

## Local Dev VM (`.test` domains)

Keys are generated automatically when the VM is created via `run-vm.ps1`.
No manual steps are needed — the script generates an ed25519 keypair at
`~/.ssh/<vmname>` and `~/.ssh/<vmname>.pub`.

```powershell
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -LanIPAddress 192.168.88.8 ...
```

The keypair lands at:
```
~\.ssh\lucasvps_test        ← private key
~\.ssh\lucasvps_test.pub    ← public key
~\.ssh\lucasvps_test.ppk    ← PuTTY format (auto-generated)
```

`ansible.cfg` is pre-configured to use `~/.ssh/ansible_id` by default. If your
VM uses a different key name, update `private_key_file` in `ansible.cfg` or
pass `-SSHKey` to `vps.ps1`.

---

## Live / Production Server

The VPS provider injects the public key at server creation time. You generate
the keypair manually once on your Windows machine.

### Step 1 — Generate the keypair

```powershell
ssh-keygen -t ed25519 -C "your-domain.com" -f "$env:USERPROFILE\.ssh\prod_key"
```

This creates:
```
~\.ssh\prod_key        ← private key  (keep secret, never commit)
~\.ssh\prod_key.pub    ← public key   (safe to share)
```

### Step 2 — Add the public key to your VPS provider

Copy the content of `~\.ssh\prod_key.pub` and paste it into:

- **Hetzner** → Project → Security → SSH Keys → Add SSH Key
- **DigitalOcean** → Settings → Security → SSH Keys → Add SSH Key
- **Vultr / Linode / etc.** — same concept under Settings or SSH Keys

Select the key when creating the server. It will be injected into `root`'s
`authorized_keys` on first boot.

### Step 3 — Update `ansible.cfg`

```ini
private_key_file = ~/.ssh/prod_key
remote_user      = root
```

### Step 4 — Update `inventory/hosts.yml`

```yaml
hosts:
  your-domain.com:
    ansible_host: <live-server-ip>
```

### Step 5 — Sync the public key into secrets.yml

```bash
./vps.sh sync keys
```

This reads `~/.ssh/prod_key.pub` and writes it into `vars/secrets.yml` as
`vault_admin_ssh_public_key`. From this point `install core` will keep the key
in `authorized_keys` on the live server.

### Step 6 — Continue with normal provisioning

```bash
./vps.sh install core --domain=your-domain.com
./vps.sh install ssl  --domain=your-domain.com
```

---

## Updating or Rotating Keys

1. Generate a new keypair (Step 1 above).
2. Run `./vps.sh sync keys` — updates `vault_admin_ssh_public_key` in `secrets.yml`.
3. Run `./vps.sh install core --domain=<domain>` — deploys the new key to the server.
4. Verify SSH works with the new key before removing the old one.

> **Never commit the private key** (`prod_key`, `lucasvps_test`, etc.).
> These files are excluded by `.gitignore`. Only the public key value is stored
> inside the encrypted `vars/secrets.yml`.

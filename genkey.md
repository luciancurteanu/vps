# SSH Key Generation — Production Server

SSH keys authenticate Ansible against the server. The public key is stored in
`vars/secrets.yml` under `vault_admin_ssh_public_key` and deployed to
`~/.ssh/authorized_keys` on the server by `install core`.

---

## Step 1 — Generate the keypair

Run once on your Windows machine:

```powershell
ssh-keygen -t ed25519 -C "your-domain.com" -f "$env:USERPROFILE\.ssh\prod_key"
```

This creates:
```
~\.ssh\prod_key        ← private key  (keep secret, never commit)
~\.ssh\prod_key.pub    ← public key   (safe to share)
```

## Step 2 — Add the public key to your VPS provider

Copy the content of `~\.ssh\prod_key.pub` and paste it into:

- **Hetzner** → Project → Security → SSH Keys → Add SSH Key
- **DigitalOcean** → Settings → Security → SSH Keys → Add SSH Key
- **Vultr / Linode / etc.** — same concept under Settings or SSH Keys

Select the key when creating the server. It will be injected into `root`'s
`authorized_keys` on first boot.

## Step 3 — Update `ansible.cfg`

```ini
private_key_file = ~/.ssh/prod_key
remote_user      = root
```

## Step 4 — Update `inventory/hosts.yml`

```yaml
hosts:
  your-domain.com:
    ansible_host: <live-server-ip>
```

## Step 5 — Sync the public key into secrets.yml

```bash
./vps.sh sync keys
```

This reads `~/.ssh/prod_key.pub` and writes it into `vars/secrets.yml` as
`vault_admin_ssh_public_key`.

## Step 6 — Provision the server

```bash
./vps.sh install core --domain=your-domain.com
./vps.sh install ssl  --domain=your-domain.com
```

---

## Rotating Keys

1. Generate a new keypair (Step 1 above).
2. Run `./vps.sh sync keys` — updates `vault_admin_ssh_public_key` in `secrets.yml`.
3. Run `./vps.sh install core --domain=<domain>` — deploys the new key to the server.
4. Verify SSH works with the new key before removing the old one.

> **Never commit the private key.** Only the public key value is stored inside
> the encrypted `vars/secrets.yml`.


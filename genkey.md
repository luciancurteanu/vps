# SSH Key Generation — Production Server

SSH keys authenticate Ansible against the server. The public key is stored in
`vars/secrets.yml` under `vault_admin_ssh_public_key` and deployed to
`~/.ssh/authorized_keys` on the server by `install core`.

> **Key naming convention:** The key filename must match the inventory hostname
> with dots replaced by underscores. Ansible picks it up automatically — no
> `ansible.cfg` changes needed.
>
> | Hostname | Key file |
> |---|---|
> | `example.com` | `~/.ssh/example_com` |
> | `myserver.net` | `~/.ssh/myserver_net` |

---

## Step 1 — Generate the keypair

Run once on your Windows machine (replace `your-domain.com` and `your_domain_com`):

```powershell
ssh-keygen -t ed25519 -C "your-domain.com" -f "$env:USERPROFILE\.ssh\your_domain_com"
```

This creates:
```
~\.ssh\your_domain_com        ← private key  (keep secret, never commit)
~\.ssh\your_domain_com.pub    ← public key   (safe to share)
```

## Step 2 — Add the public key to your VPS provider

Copy the content of `~\.ssh\your_domain_com.pub` and paste it into:

- **Contabo** → Your Services → VPS → Access & Security → SSH Keys
- **Hetzner** → Project → Security → SSH Keys → Add SSH Key
- **DigitalOcean** → Settings → Security → SSH Keys → Add SSH Key
- **Vultr / Linode / etc.** — same concept under Settings or SSH Keys

Select the key when creating the server. It will be injected into `root`'s
`authorized_keys` on first boot.

> If the server is already running (key not injected at boot), inject manually:
> ```powershell
> $pub = (Get-Content "$env:USERPROFILE\.ssh\your_domain_com.pub" -Raw).Trim()
> & 'C:\Program Files\PuTTY\plink.exe' -ssh -batch -pw "<root-password>" root@<server-ip> "echo '$pub' >> /root/.ssh/authorized_keys"
> ```

## Step 3 — Update `inventory/hosts.yml`

```yaml
hosts:
  your-domain.com:
    ansible_host: <live-server-ip>
```

The SSH key is picked up automatically from `~/.ssh/your_domain_com` based on
the hostname — no `ansible.cfg` edit required.

## Step 4 — Sync the public key into secrets.yml

From Git Bash (Windows):

```bash
./vps.sh sync keys
```

This reads all `~/.ssh/*.pub` files (excluding `ansible_id.pub`) and writes
them into `vars/secrets.yml` as `vault_admin_ssh_public_key`.

## Step 5 — Provision the server

First-time run (before `admin` user exists — connects as `root`):

```bash
./vps.sh install core --domain=your-domain.com --initial
```

Subsequent runs (after `admin` user is created):

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


# Beginner Guide — Start This Project (step-by-step)

This guide shows, step-by-step and in plain language, how to get this project running from scratch. It covers both local testing (recommended for development) and production provisioning. Where automation exists, the exact scripts to run are provided so you can copy/paste commands.

If you prefer a shorter quick-start, use the `scripts/README.md` pointers. This guide is intended for beginners and assumes only basic command-line familiarity.

---

**Quick overview (one-liner):**

1. Install prerequisites (VirtualBox/WSL or a Linux host, Python, Docker).
2. Clone the repo.
3. Use automated scripts for VM or environment setup (`scripts/run-vm.ps1`, `scripts/setup-molecule-env.sh`).
4. Run tests with `scripts/run-test.sh` or run the provisioning scripts for production with `vps.sh`.

---

## 0 — Before you start (choose an environment)

- Option A (recommended for development on Windows): Use the provided VirtualBox VM launcher to create a local AlmaLinux VM and run Molecule inside it.
- Option B (Linux/macOS or cloud VPS): Use WSL (AlmaLinux) or a real VM and run commands natively.

Pick one and follow the relevant section below.

---

## 1 — Clone the repository (all platforms)

Open a terminal and run:

```bash
# from your home or dev folder
git clone https://github.com/luciancurteanu/vps.git
cd vps
```

This creates the project folder you will work from. Most scripts assume you run them from the project root.

---

## 2 — Prerequisites (short checklist)

- If you're on Windows and using the VM launcher:
  - VirtualBox installed
  - PowerShell 5.1+ (or PowerShell 7+)
  - Chocolatey (recommended for full automation): the launcher will attempt to install auxiliary Windows tools via Chocolatey when missing. Chocolatey must be installed from an elevated Administrator PowerShell session for automatic installs to succeed.
    Install Chocolatey (run in Admin PowerShell):

    ```powershell
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    ```
- If you're on Linux (or inside WSL):
  - Python 3.9+ (system Python is fine)
  - Docker (or Podman) installed and running
  - git

Tools used by scripts in this repo:
- `VBoxManage` (VirtualBox)
- `qemu-img` and `mkisofs` (for cloud-init ISO creation) — the launcher downloads these automatically where possible
- `ansible` and `ansible-vault` (for production provisioning)
Note: the VM launcher can attempt to download or auto-install `mkisofs`/`genisoimage` and other helper tools on Windows, but these operations require Chocolatey and Administrator rights. If you prefer to install tools manually, add `mkisofs.exe` under `scripts/Binary` or install the appropriate Chocolatey packages (e.g., `cdrtools`, `qemu`).

Important: The provided helper scripts (including `scripts/setup-molecule-env.sh`) install Python dependencies but do NOT install the Docker engine on the host. You must install Docker (or Podman) yourself on the host or inside the VM before running Molecule scenarios that require container runtimes.

Note: The repo includes helper scripts that automate many manual steps — the guide below shows those scripts and the few manual commands you may still need.

---

## 3 — Option A: Local VM (Windows + VirtualBox) — fastest dev loop

This option is recommended if you use Windows and want a reproducible dev/test environment.

1) From PowerShell (run as Administrator the first time):

```powershell
# creates or recreates an AlmaLinux VM with cloud-init applied
powershell -ExecutionPolicy Bypass -File .\scripts\run-vm.ps1
# or to force a clean rebuild
powershell -ExecutionPolicy Bypass -File .\scripts\run-vm.ps1 -Delete:$true
```

2) Wait for the script to report SSH readiness, then connect:

```powershell
ssh -p 2222 admin@localhost
# default password if key wasn't injected: ChangeMe123!
```

Notes about the launcher:
- If you have a local SSH public key (e.g., `~/.ssh/id_ed25519.pub`), the launcher injects it into the VM and disables password login — you can then `ssh -p 2222 admin@localhost` without a password.
- The launcher maintains a stable VM disk name to speed up repeated runs; use `-Delete:$true` to force a full rebuild.

3) Inside the VM: create project folder and/or copy repo (optional):

```bash
# if you cloned on Windows and shared the folder, skip this
git clone https://github.com/luciancurteanu/vps.git
sudo chown -R admin:admin ~/vps
cd ~/vps
```

4) Set up the Python/Molecule test environment (automated):

```bash
bash scripts/setup-molecule-env.sh
# This creates ~/molecule-env and installs pinned dependencies
```

5) Run Molecule role tests (example):

```bash
bash scripts/run-test.sh common
# or run a specific action, e.g.:
bash scripts/run-test.sh common converge
```

If you need to remove the Molecule environment, use:

```bash
bash scripts/reset-molecule-environment.sh
```

---

## 4 — Option B: Linux/WLS/Cloud host (native execution)

If you're on Linux or inside WSL (AlmaLinux recommended), follow these steps.

1) Install Docker (example for AlmaLinux/CentOS):

```bash
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
# log out and back in (or run: newgrp docker)
```

2) Create and activate Python venv, install Molecule stack (automated script available):

```bash
bash scripts/setup-molecule-env.sh
# or manual:
python3 -m venv ~/molecule-env
source ~/molecule-env/bin/activate
pip install --upgrade pip
pip install 'docker<=6.1.3' ansible molecule molecule-docker ansible-lint yamllint 'requests<2.32'

```

3) Run tests

```bash
bash scripts/run-test.sh common
```

Notes: `run-test.sh` will activate `~/molecule-env` for you; you don't need to `source` it manually if you use the script.

---

## 5 — Production provisioning (brief)

This project includes a provisioning CLI script (`vps.sh`) and Ansible playbooks.

1) Prepare inventory and secrets (from project root):

```bash
cp inventory/hosts.example inventory/hosts
cp inventory/group_vars/all.yml.example inventory/group_vars/all.yml
cp vars/secrets.yml.example vars/secrets.yml
# edit inventory/hosts, inventory/group_vars/all.yml, and vars/secrets.yml
ansible-vault encrypt vars/secrets.yml
```

2) Run core install (example):

```bash
./vps.sh install core --domain=vps.test --ask-pass --ask-vault-pass
```

Read `README.md` and `playbooks/README.md` for details about production roles and flags.

---

## 6 — Common commands & troubleshooting (copy/paste)

- Start VM (PowerShell):
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-vm.ps1
```
- SSH into local VM:
```bash
ssh -p 2222 admin@localhost
```
- Setup Molecule env (inside VM or Linux host):
```bash
bash scripts/setup-molecule-env.sh
```
- Run role tests:
```bash
bash scripts/run-test.sh <role> [action]
# e.g. bash scripts/run-test.sh nginx test
```
- Destroy Molecule instances (manual):
```bash
#molecule destroy -s default --all
```
- Reset local dev environment (automated):
```bash
bash scripts/reset-molecule-environment.sh
```

Troubleshooting tips:
- SSH connection refused on 2222: run the VM launcher again or check `VBoxManage list runningvms`.
- Permission denied when installing packages: run commands with `sudo` or use the admin user as instructed.
- Docker issues: ensure the current user is in the `docker` group and restart the session.

---

## 7 — Where to find things in this repo

- `scripts/run-vm.ps1` — creates and configures a local AlmaLinux VM (Windows PowerShell).
- `scripts/run-test.sh` — wrapper to run Molecule tests for a role.
- `scripts/setup-molecule-env.sh` — creates `~/molecule-env` and installs test dependencies.
- `scripts/reset-molecule-environment.sh` — removes `~/molecule-env` and caches for a fresh start.
- `vps.sh` — top-level provisioning CLI for production installs.
- `docs/molecule-admin-setup.md` — detailed Molecule & VM setup manual (advanced options).

---

If you'd like, I can now:
- update `docs/molecule-admin-setup.md` cross-references to this beginner guide,
- or open a PR with the changes. Which would you prefer?

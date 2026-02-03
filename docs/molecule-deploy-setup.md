# VPS Setup - Molecule Testing Guide

## Choose Your Environment

**Are you using WSL locally or SSH to a remote VM?**

- **WSL (Local Development)**: Skip to [WSL Setup](#wsl-setup)
- **SSH (Remote VM)**: Skip to [SSH Setup](#ssh-setup)

---

## WSL Setup

Follow these steps in order for local WSL development.

### Step 1: Install AlmaLinux 9 in WSL
```bash
wsl --install -d AlmaLinux-9
wsl -d AlmaLinux-9
```

### Step 2: Verify Environment
```bash
whoami && groups && sudo whoami
# Should show your username, wheel group, and root access

# If admin user doesn't exist, create it:
sudo adduser admin
sudo passwd admin  # You will be prompted to enter a password
sudo usermod -aG wheel admin
# Then switch to admin user: su - admin
```

### Step 3: Install Docker & Tools
```bash
# Add Docker repo
sudo dnf config-manager --add-repo=https://download.docker.com/linux/rhel/docker-ce.repo

# Install packages
sudo dnf install -y docker-ce docker-ce-cli containerd.io python3 python3-pip git rsync sshpass

# Start Docker
sudo systemctl enable --now docker
# Add user to docker group
sudo usermod -aG docker $USER
# Exit to apply docker group membership changes (required for new login session)
exit
# Restart WSL (run this from Windows PowerShell, NOT from WSL terminal)
# Open PowerShell as Administrator and run:
wsl -t AlmaLinux-9; wsl -d AlmaLinux-9
```

Note: The scripts and launcher in this repository do not install the Docker engine on the host automatically. `scripts/setup-molecule-env.sh` installs Python packages required by Molecule (including the Docker SDK), but you must install and start the Docker daemon (or Podman) separately. For Windows users using the VM launcher, the launcher attempts to auto-install helper tools (like `qemu`, `cdrtools`/`genisoimage`) via Chocolatey where possible — these operations require Chocolatey to be present and PowerShell started with Administrator privileges. As a fallback, the launcher may download `mkisofs` into `scripts/Binary`, but a network download or manual placement may be required.

### Step 4: Verify Installation
```bash
docker --version
python3 --version
git --version
docker run hello-world
```

### Step 5: Setup Python Environment
```bash
python3 -m venv ~/molecule-env
source ~/molecule-env/bin/activate
pip install --upgrade pip
pip install 'docker<=6.1.3' ansible molecule molecule-docker ansible-lint yamllint 'requests<2.32'
deactivate
```

### Step 6: Clone & Test
```bash
git clone https://github.com/luciancurteanu/vps.git
sudo chown -R $USER:$USER ~/vps
cd ~/vps
bash scripts/run-test.sh common
```

---

## SSH Setup

Follow these steps in order for remote VM testing via SSH.

### Step 1: Create VM

**Automated VM Launcher**

**Option A: Quick Setup (Manual Steps 2-6)**
```powershell
# See scripts/vm-launcher/README.md for more details
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -UseLocalSSHKey -autoSSH
```

**Option B: Full Automated Setup (One Command - Recommended)**
```powershell
# Creates VM, installs Docker, sets up Molecule, clones project, runs first test
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -UseLocalSSHKey -FullSetup
```

**If you used Option B (-FullSetup), skip to Step 7. Steps 2-6 are automated for you.**

---

### Step 2: Connect & Verify
```bash
# For automated launcher:
ssh localhost
# OR
ssh admin@192.168.88.8

# Verify setup:
whoami && groups && sudo whoami
# Should show: admin, admin wheel, root
```

### Step 3: Install Docker & Tools
```bash
# Add Docker repo
sudo dnf config-manager --add-repo=https://download.docker.com/linux/rhel/docker-ce.repo

# Install packages
sudo dnf install -y docker-ce docker-ce-cli containerd.io python3 python3-pip git rsync sshpass

# Start Docker
sudo systemctl enable --now docker

# Add user to docker group
sudo usermod -aG docker admin
# Exit to apply docker group membership changes (required for new login session)
exit
```

### Step 4: Reconnect & Verify
```bash
# Reconnect to apply group changes
ssh localhost  # or ssh -p <port> admin@<ip>

# Verify:
docker --version
python3 --version
git --version
docker run hello-world
```

### Step 5: Setup Python Environment
```bash
python3 -m venv ~/molecule-env
source ~/molecule-env/bin/activate
pip install --upgrade pip
pip install 'docker<=6.1.3' ansible molecule molecule-docker ansible-lint yamllint 'requests<2.32'
deactivate
```

### Step 6: Clone & Test
```bash
git clone https://github.com/luciancurteanu/vps.git
sudo chown -R admin:admin ~/vps
cd ~/vps
```
Or upload your existing `vps` project directory to the remote VM via `rsync` or `scp`.
---

- **Docker not working**: Make sure you're in the docker group (`groups` command)
    - **Windows launcher: Chocolatey/admin required**: If you use the `scripts/vm-launcher/run-vm.ps1` launcher on Windows, it will attempt to use Chocolatey to install missing helper tools. Chocolatey installs require an elevated Administrator PowerShell session; without it the launcher will throw errors requesting manual installation. Install Chocolatey in Admin PowerShell with the command shown in `docs/BEGINNER-GUIDE.md`.
- **Permission denied**: Check sudo access and user groups
- **WSL restart**: Use `wsl -t AlmaLinux-9; wsl -d AlmaLinux-9` from Windows PowerShell (not from WSL terminal)
- **SSH connection fails**: Verify VM IP, port, and credentials

**"wsl: command not found"**: The `wsl` command must be run from Windows PowerShell, not from within WSL

---

## Step 7: Advanced Molecule Configuration


Usage: bash scripts/run-test.sh <role> [action]

### 7.1. Managing Role Dependencies with `requirements.yml`
If your Ansible role depends on other roles or collections (e.g., from Ansible Galaxy), you can manage these dependencies using a `requirements.yml` file within your role's Molecule scenario directory (e.g., `roles/your-role-name/molecule/default/requirements.yml`).

**Purpose:**
- Explicitly defines external roles or collections needed for your role to function or be tested.
- Allows Molecule's `dependency` step (and `ansible-galaxy`) to automatically download and install these dependencies.

**Example:**
```yaml
# roles/your-role-name/molecule/default/requirements.yml
collections:
  - community.general
roles:
  - src: geerlingguy.ntp
    version: "2.0.0"
```

**Usage:**
- Molecule will automatically process this file during the `dependency` phase of its test sequence.
- If this file is not present, Molecule will show a warning like `WARNING Skipping, missing the requirements file.`, which is generally safe to ignore if your role has no external Galaxy dependencies for its tests.

### 7.2. Custom Cleanup with `cleanup.yml`
Molecule allows you to define a custom cleanup playbook that runs *before* the `destroy` phase. This is useful for tasks that go beyond simply terminating the test instance.

**Purpose:**
- Perform specific actions to clean the test instance before it's destroyed (e.g., unregistering from a service, deleting specific test data, gracefully shutting down applications).

**Configuration:**
1.  Create a playbook, for example, `cleanup.yml`, in your Molecule scenario directory (e.g., `roles/your-role-name/molecule/default/cleanup.yml`).
2.  Reference this playbook in your `molecule.yml` under the provisioner settings:

    ```yaml
    # roles/your-role-name/molecule/default/molecule.yml
    provisioner:
      name: ansible
      playbooks:
        # ... other playbooks like create, prepare, converge ...
        cleanup: cleanup.yml
        # ... destroy ...
    ```

**Usage:**
- Molecule will execute this playbook during the `cleanup` phase.
- If no cleanup playbook is configured, Molecule will show a warning like `WARNING Skipping, cleanup playbook not configured.`, which is normal if no custom cleanup actions are needed.

---

## Step 8: Resetting the Test Environment

If you need to start your tests from scratch, you can reset your environment. This involves destroying existing Molecule-managed infrastructure and cleaning up project and cache directories.

**Run these commands as the `admin` user inside your AlmaLinux 9 VM/WSL instance:**

1.  **Destroy active Molecule instances (if any):**
    If you have active Molecule-managed instances (e.g., Docker containers), destroy them first. Navigate into each role directory that might have an active instance and run `molecule destroy`.
    ```bash
    # Example for one role:
    # cd ~/vps/roles/your-role-name 
    # molecule destroy
    ```
    *Note: Repeat for any role where you might have run `molecule converge` or `molecule create` without a subsequent `molecule destroy`.*

2.  **Run the automated cleanup script:**
    The `reset-molecule-environment.sh` script will remove the Python virtual environment (`~/molecule-env`), Ansible cache (`~/.ansible`), the general cache directory (`~/.cache`), and Ansible async data (`~/.ansible_async`).
    ```bash
    # Navigate to your project root if not already there
    cd ~/vps 
    bash scripts/reset-molecule-environment.sh
    ```

3.  **Manually remove the project directory (optional, for a full re-clone):**
    The cleanup script does **not** remove the `~/vps` project directory itself. If you want to completely reset by re-cloning the project, you must remove this directory manually.
    ```bash
    # Navigate to your home directory (or any directory outside of ~/vps)
    cd ~
    # WARNING: This command deletes the entire 'vps' project directory.
    # Ensure you want to do this, as you will need to re-clone it.
    rm -rf ~/vps 
    ```

4.  **Re-setup your environment:**
    After resetting (and optionally re-cloning), you will need to:
    *   If you removed `~/vps`, re-clone your project and set permissions (as described in Step 6).
    *   The `bash scripts/setup-molecule-env.sh` script (run via `bash scripts/run-test.sh` or manually) will recreate the Python virtual environment and install dependencies.
    *   Navigate to the project root (`~/vps`) and use the `bash scripts/run-test.sh` script to run tests for a specific role (as described in Step 6).
    *   The `bash run-test.sh` script will handle the virtual environment activation.

---

## Step 9: Capturing Playbook Output to a Log File

When debugging Ansible playbook runs, especially when not using Molecule (e.g., direct `ansible-playbook` commands against a staging or production-like environment), it's useful to capture the full output to a log file. This allows you to review all messages, including errors and verbose output, at your leisure.

You can use the `tee` command in your Ansible control environment (e.g., your AlmaLinux 9 VM/WSL) to display the output on your terminal and simultaneously save it to a file.

**Command:**

```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --ask-vault-pass --ask-pass --check --diff 2>&1 | tee ansible_playbook_debug.log
```

**Explanation:**
-   `ansible-playbook -i inventory/hosts.yml playbooks/setup.yml`: The standard command to run your playbook.
-   `--ask-vault-pass`: Prompts for your Ansible Vault password.
-   `--ask-pass`: Prompts for the SSH password for connecting to the managed hosts (if you're not using SSH keys or an agent).
-   `--check`: Runs the playbook in check mode (dry run), so no actual changes will be made to the target host.
-   `--diff`: Shows the differences in files that would be changed if the playbook were run without `--check`.
-   `2>&1`: This redirects the standard error output (`stderr`, channel 2) to the standard output (`stdout`, channel 1). This is crucial for capturing both regular output and error messages in the log file.
-   `| tee ansible_playbook_debug.log`: This pipes the combined standard output and standard error to the `tee` command.
    -   `tee`: Displays the output on your terminal as it's received.
    -   `ansible_playbook_debug.log`: Simultaneously writes the output to a file named `ansible_playbook_debug.log` in your current working directory.

After running this command, you will be prompted for any necessary passwords (vault, SSH). The entire execution log will be saved in `ansible_playbook_debug.log`. You can then review this file to diagnose issues.

---

## Step 10: Script Usage Quick Reference

See [../scripts/README.md](../scripts/README.md) for details on available scripts:
- `vm-launcher/run-vm.ps1` — Create AlmaLinux 9 VM for testing (automated with SSH key injection)
- `setup-molecule-env.sh` — Set up Python venv for Molecule
- `run-test.sh` — Run Molecule tests for a specified role (e.g., `bash scripts/run-test.sh nginx test`)

### VM Launcher Features:
- **Automated Setup**: Downloads AlmaLinux images, creates VMs, configures SSH
- **SSH Key Management**: Generates and injects SSH keys automatically
- **Cloud-init Support**: Automated VM provisioning
- **Flexible Configuration**: Customizable memory, CPU, ports, and more
- **Cleanup Options**: Standard cleanup, force cleanup, and recreate modes
- **Logging**: Comprehensive logging with automatic cleanup

---

## Next Steps

- Run tests for other roles: `bash scripts/run-test.sh <role-name>`
- Reset environment: `bash scripts/reset-molecule-environment.sh`
- View test status: See `docs/testing-completion-summary.md`
<parameter name="filePath">c:\Users\Lucian\Documents\Github\Repositories\vps\docs\molecule-admin-setup-simple.md
# Scripts Directory

> New here? For a short, ordered path (Windows VM quick start + production), see [../docs/BEGINNER-GUIDE.md](../docs/BEGINNER-GUIDE.md).

This folder contains helper scripts for automation, testing, and environment setup for the VPS project.

## Scripts

### VM Launcher (`vm-launcher/` subdirectory)
- `vm-launcher/run-vm.ps1` — Main VM launcher script. Minimal, dependable AlmaLinux 9 VirtualBox provisioner (recommended). Reuses qcow2, builds NoCloud ISO, creates/updates VM, ensures NAT port forwarding, waits for SSH.
    - Default login: `admin / Changeme123!`
    - If a local public key exists, it will be injected and password SSH will be disabled
- `vm-launcher/VMConfig.ps1` — Configuration class for VM settings (paths, credentials, network)
- `vm-launcher/VMBootstrap.ps1` — VM bootstrap operations (cloud-init, SSH setup)
- `vm-launcher/VMCleanup.ps1` — VM cleanup operations (deletion, orphan removal)
- `vm-launcher/VBoxUtils.ps1` — VirtualBox utility functions

### Testing Scripts
- `run-test.sh` — Run Molecule tests for a role. **Defaults to `test` action** (full test with container recreation). Use `converge` action for faster iterations without re-downloading packages.
    - Usage: `bash scripts/run-test.sh <role> [action]`
    - Actions: `test` (default, full), `converge` (fast), `verify`, `destroy`, `create`
    - **No password prompts** — automatically handles docker permissions
- `run-test.ps1` — PowerShell version of test runner
- `run-molecule-test.sh` — Molecule test wrapper
- `setup-molecule-env.sh` — Set up Python virtual environment for Molecule testing
- `reset-molecule-environment.sh` — Reset Molecule environment (removes `~/molecule-env`, `~/.ansible`, caches)

### CI/CD and Automation
- `ci-setup.sh` — CI environment setup script (installs Docker, Python, Molecule dependencies)
- `resume-deployment.sh` — Resume interrupted deployments

### Utilities
- `create-iso.bat` — Create ISO images using mkisofs on Windows (auto-downloads mkisofs)
- `fix-theme-metal.sh` — Fix Metal theme issues

## Usage Examples

### Quick start (Recommended)
```powershell
# Minimal, dependable provisioning (Windows PowerShell 5.1+)
powershell -ExecutionPolicy Bypass -File .\scripts\vm-launcher\run-vm.ps1

# Then connect:
ssh admin@localhost   # password: Changeme123! (or use your SSH key)
```

Requirements (lite):
- VirtualBox installed (VBoxManage in default path)
- qemu-img available (auto-installed via Chocolatey if missing)
- mkisofs available (auto-downloaded if missing)

### Launch an AlmaLinux 9 VM (PowerShell)
```powershell
# Full reset: clean everything and rebuild VM (default behavior)
powershell -ExecutionPolicy Bypass -File .\scripts\vm-launcher\run-vm.ps1

# With parameters:
.\scripts\vm-launcher\run-vm.ps1 -VMName 'AlmaLinux-9' -UseLocalSSHKey -Recreate -FullSetup
```

### VM Launcher Parameters

- `-VMName` — Name of the VM (default: AlmaLinux-9)
- `-UseLocalSSHKey` — Inject your existing SSH key
- `-Recreate` — Delete and recreate the VM
- `-FullSetup` — Run full automated setup (Docker, Molecule, clone project, run first test)

### Reset behavior

The script preserves only the base qcow2 cloud image inside `C:\VMData\<VMName>` to avoid re-downloading:

**Default behavior (clean state):**
- Unregisters VM from VirtualBox and powers it off
- Cleans VirtualBox media registry for the VM path
- Deletes all files in VMData folder EXCEPT the qcow2 image
- Recreates VM, VDI, cloud-init ISO from scratch
- Provides guaranteed clean state for testing

**Reuse mode (faster iterations):**
- Keeps existing VDI/ISO/VM when possible
- May reuse previous VM state if it exists

Requirements:
- VirtualBox installed (VBoxManage in default path)
- qemu-img available (auto-installed via Chocolatey if missing)
- mkisofs available (auto-downloaded if missing)

Notes:
- Output is intentionally quiet and production-friendly. A transcript log is written next to this script (in `scripts/`) at start; its path is printed as `Log: ...`. On success, the log is deleted automatically.
- The VDI name is stable (no timestamp) to avoid unnecessary re-conversion between runs. If you need a brand-new disk, use `-Delete:$true` for a clean rebuild.
- The script waits up to 180 seconds for SSH to become reachable on `localhost:2222` and prints a ready-to-copy SSH command on success.

### What cleanup deletes (and what it doesn't)

When run in full reset mode (`-Delete:$true` or `--delete`), the script only removes artifacts it created:
- VirtualBox VM registration for the given name (and any media attachments to paths under `C:\VMData\<VMName>`)
- Files inside `C:\VMData\<VMName>` such as `disk.vdi`, `cloud-init.iso`, and the `cidata/` folder
- It preserves the original cloud image (`*.qcow2`) to avoid re-downloading
- It clears `known_hosts` entries for `[localhost]:<port>` and `[127.0.0.1]:<port>` to prevent SSH host key prompts for the NAT rule

It does NOT delete your personal SSH keys (e.g., `~/.ssh/id_ed25519`, `~/.ssh/id_rsa`) or other unrelated files.

### SSH keys: creation and selective cleanup

- If a public key already exists at `~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub`, it will be injected into the VM and password SSH will be disabled.
- If only a private key exists (no `.pub`), the script will derive the corresponding public key file non-destructively.
    - If no keypair is available, the script will generate a temporary ed25519 keypair and record a marker file at `~/.ssh/vps-<VMName>-keys.mark` listing the created files.
- When you run with `--delete`, the script will remove only the key files listed in that marker (if present) and then remove the marker. Pre-existing user keys are never touched.

## Windows: Manual Installation of mkisofs

If you see an error about `mkisofs.exe` not being found or installed, the script will first search for mkisofs.exe anywhere under `scripts\Binary`. If not found, it will attempt to download and extract it automatically. Manual installation is only required if the automated download fails:

- **mkisofs for Windows:**
  - The script will attempt to download and extract mkisofs from:
    https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/mkisofs-md5/mkisofs-md5-2.01-Binary.zip
  - If you need to do it manually, download and extract the zip, then copy mkisofs.exe to any subfolder under `scripts\Binary` or update the script to point to your mkisofs.exe location.

After installation, restart your terminal or VS Code for the changes to take effect.

For more details, see the error messages in `launch-vm.ps1`.

### Create an ISO on Windows (Batch Script)

A helper script is provided to create ISO images using mkisofs on Windows:

- Script: `scripts/create-iso.bat`
- Requirements: The script will automatically download and extract mkisofs if not present, searching all extracted folders for mkisofs.exe.
- The ISO will be created in your Downloads folder as `output.iso`.

**Usage:**
1. Run `scripts/create-iso.bat` from a Command Prompt.
2. If mkisofs is not present, it will be downloaded and extracted automatically.
3. Enter the folder name (relative to the script) when prompted, or `.` for the current directory.
4. The ISO will be created in your Downloads folder as `output.iso`.

> Note: This script is for manual ISO creation. For automated VM setup, see `launch-vm.ps1`.

### Run Molecule Tests (Linux/macOS)

To set up the environment and run Molecule tests:

1.  **Navigate to your project root directory (e.g., `~/vps`):**
    ```sh
    cd ~/vps
    ```

2.  **Run the environment setup script:**
    This script creates the Python virtual environment and installs dependencies.
    ```sh
    bash scripts/setup-molecule-env.sh
    ```

3.  **Run tests for a specific role:**
    The `run-test.sh` script will automatically activate the virtual environment and handle docker permissions (no password prompts).

    **⚠️ Important: Default action is `test` which destroys and recreates containers (downloads packages every time)**
    
    ```sh
    # Full test (slow - downloads packages, destroys container)
    bash scripts/run-test.sh webmin          # defaults to 'test' action
    bash scripts/run-test.sh webmin test     # explicit
    
    # Fast iteration (recommended for development - reuses container)
    bash scripts/run-test.sh webmin converge # much faster, no re-downloads
    
    # Other actions
    bash scripts/run-test.sh webmin verify   # just run verification tests
    bash scripts/run-test.sh webmin destroy  # destroy container
    ```

    **Development workflow:**
    1. First run: `bash scripts/run-test.sh webmin test` (full test)
    2. Iterations: `bash scripts/run-test.sh webmin converge` (fast, reuses container)
    3. Before commit: `bash scripts/run-test.sh webmin test` (ensure clean state)

### Running Manual Molecule Commands

If you need to run Molecule commands manually outside of `run-test.sh`:

1.  **Activate the virtual environment:**
    ```sh
    cd ~/vps
    source ~/molecule-env/bin/activate
    ```

2.  **Ensure docker permissions (no password prompts):**
    ```sh
    # If docker group not active in session:
    sudo chmod 666 /var/run/docker.sock
    ```

3.  **Navigate to role directory and run commands:**
    ```sh
    cd roles/webmin
    
    # Full sequence
    molecule destroy
    molecule create
    molecule converge
    molecule verify
    
    # Or shorthand
    molecule test
    
    # Login to container
    molecule login --host almalinux9
    ```
    
    Inside the container:
    ```sh
    systemctl status webmin
    journalctl -xeu webmin -n 100 --no-pager
    ```

4.  **Deactivate when done:**
    ```sh
    deactivate
    ```

## Prerequisites
- PowerShell 7+ (for Windows scripts)
- Python 3.9+ and virtualenv (for Molecule testing)
- Docker or Podman (for Molecule testing)

## Notes
- No secrets or credentials should be hardcoded in any script.
- Update this README.md whenever you add, remove, or change scripts in this folder.
- Docker permissions are automatically handled by `run-test.sh` (no password prompts).
- Use `converge` action for fast development iterations; use `test` for clean CI/CD validation.
- For more details on testing, see `docs/molecule-deploy-setup.md`.

---

**Author:** Lucian Curteanu  
Website: [https://luciancurteanu.com](https://luciancurteanu.com)


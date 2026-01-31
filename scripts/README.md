# Scripts Directory

> New here? For a short, ordered path (Windows VM quick start + production), see [../docs/BEGINNER-GUIDE.md](../docs/BEGINNER-GUIDE.md).

This folder contains helper scripts for automation, testing, and environment setup for the VPS project.

## Scripts

- `run-vm.ps1` — Minimal, dependable AlmaLinux 9 VirtualBox provisioner (recommended). Reuses qcow2, builds NoCloud ISO, creates/updates VM, ensures NAT 2222→22, waits for SSH.
    - Default login: `admin / Changeme123!`
    - If a local public key exists at `~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub`, it will be injected and password SSH will be disabled; connect with your key instead.
- `run-test.sh` — Shell script to run Molecule tests for a specified role and action (e.g., test, converge). Requires Molecule and Docker/Podman installed. Run from the project root (e.g., `bash scripts/run-test.sh nginx test`).
- `setup-molecule-env.sh` — Shell script to set up a Python virtual environment for Molecule testing. Run before running Molecule tests.
- `reset-molecule-environment.sh` — Shell script to partially reset the Molecule testing environment by removing `~/molecule-env`, `~/.ansible`, `~/.cache`, and `~/.ansible_async`. Does NOT remove the project directory itself.
- `create-iso.bat` — Batch script to create ISO images using mkisofs on Windows. Automatically downloads mkisofs if not present.

## Usage Examples

### Quick start (Recommended)
```powershell
# Minimal, dependable provisioning (Windows PowerShell 5.1+)
powershell -ExecutionPolicy Bypass -File .\scripts\launch-vm.ps1

# Then connect:
ssh -p 2222 admin@localhost   # password: Changeme123!
```

Requirements (lite):
- VirtualBox installed (VBoxManage in default path)
- qemu-img available (auto-installed via Chocolatey if missing)
- mkisofs available (auto-downloaded if missing)

### Launch an AlmaLinux 9 VM (PowerShell)
```powershell
# Full reset: clean everything and rebuild VM (default behavior)
powershell -ExecutionPolicy Bypass -File .\scripts\run-vm.ps1

# Reuse mode: skip cleanup, faster incremental runs
powershell -ExecutionPolicy Bypass -File .\scripts\run-vm.ps1 -Delete:$false
```

### Reset behavior and the -Delete flag

The script preserves only the base qcow2 cloud image inside `C:\VMData\<VMName>` to avoid re-downloading. Use the `-Delete` flag to control cleanup:

**Default behavior (-Delete:$true):**
- Unregisters VM from VirtualBox and powers it off
- Cleans VirtualBox media registry for the VM path
- Deletes all files in VMData folder EXCEPT the qcow2 image
- Recreates VM, VDI, cloud-init ISO from scratch
- Provides guaranteed clean state for testing

**Reuse mode (-Delete:$false):**
- Keeps existing VDI/ISO/VM when possible
- Faster for development iterations
- May reuse previous VM state if it exists

### Clean, quiet operation

The script is designed for production use:
- **Quiet output:** No unnecessary warnings or verbose messages
- **Transcript logging:** Creates a log next to this script (in `scripts/`) and prints its path at start
- **Auto-cleanup:** Log is deleted automatically on successful completion
- **SSH verification:** Waits up to 180 seconds for SSH connectivity
- **Ready command:** Prints exact SSH command to connect when ready

### Why no timestamp in VDI path?

The VDI filename is deliberately stable (`AlmaLinux9-Testing.vdi`) rather than timestamped because:
- **Avoids unnecessary work:** No need to re-convert qcow→vdi on every run
- **Simpler cleanup:** Predictable filenames make reset logic reliable  
- **Performance:** Reusing converted VDI saves ~30-60 seconds per run
- **VirtualBox registry:** Stable paths prevent orphaned media references

The timestamp remains only in the log filename to prevent collisions across concurrent runs.

Requirements (lite):
- VirtualBox installed (VBoxManage in default path)
- qemu-img available
- mkisofs available (place mkisofs.exe anywhere under scripts\Binary or in PATH)

### Launch an AlmaLinux 9 VM (PowerShell)
```powershell
# Recommended entrypoint
powershell -ExecutionPolicy Bypass -File .\scripts\run-vm.ps1
```

### Full reset vs reuse

The script preserves only the base qcow2 cloud image inside `C:\VMData\<VMName>` to avoid re-downloading. Use the `-Delete` flag to control cleanup:

```powershell
# Full reset: delete VM + all files in VMData except the qcow2; recreate VM from scratch (default behavior)
powershell -ExecutionPolicy Bypass -File .\scripts\launch-vm.ps1 -Delete:$true

# Reuse mode: keep existing VDI/ISO/VM when possible (faster incremental runs)
powershell -ExecutionPolicy Bypass -File .\scripts\launch-vm.ps1 -Delete:$false
```

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

3.  **Run tests for a specific role (e.g., `common`):**
    The `run-test.sh` script will automatically activate the virtual environment created in the previous step (or set it up if `setup-molecule-env.sh` wasn't run manually first). You do not need to run `source ~/molecule-env/bin/activate` yourself before this command. And to quit the virtual environment type `deactivate`.
    ```sh
    bash scripts/run-test.sh common
    ```

    To run a different action (e.g., `converge`) for the `common` role:
    ```sh
    bash scripts/run-test.sh common converge
    ```

### Running Manual Molecule Commands

If you need to run Molecule commands manually (e.g., `molecule login`, `molecule converge <scenario_name>`, `molecule verify <scenario_name>`) outside of the `run-test.sh` script, ensure you first navigate to the specific role's directory. For example, to work with the `cockpit` role:

1.  **Activate the virtual environment (if not already active):**
    ```sh
    cd ~/vps # Ensure you are in the project root
    source ~/molecule-env/bin/activate 
    ```
    *(Note: `run-test.sh` handles activation automatically, but you'll need to do it manually here if starting a new session.)*

2.  **Navigate to the role directory:**
    ```sh
    cd roles/<role>
    ```

3.  **Run your Molecule command:**
    ```sh
    molecule destroy -s default --all && molecule converge -s default
    # or
    molecule converge --scenario-name default
    # login 
    molecule login --host almalinux9 --scenario-name default
    ```
    Then you can run commands like:
    Systemd service status: `systemctl status php-fpm.service`.
    Journal logs for the Cockpit service: `journalctl -xeu cockpit.socket -n 100 --no-pager`

## Prerequisites
- PowerShell 7+ (for Windows scripts)
- Python 3.9+ and virtualenv (for Molecule testing)
- Docker or Podman (for Molecule testing)

## Notes
- No secrets or credentials should be hardcoded in any script.
- Update this README.md whenever you add, remove, or change scripts in this folder.
what - For more details on testing, see `docs/molecule-admin-setup.md`.

---

**Author:** Lucian Curteanu  
Website: [https://luciancurteanu.com](https://luciancurteanu.com)


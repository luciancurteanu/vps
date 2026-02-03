# VPS Setup VM Launcher (Clean Architecture)

A modular, clean, and optimized PowerShell script for automated AlmaLinux VM creation and management using VirtualBox.

## Architecture Overview

This refactored version follows clean architecture principles with separation of concerns:

```
scripts/
└── vm-launcher/
    ├── VMConfig.ps1              # Configuration class with defaults and path management
    ├── VMUtils.ps1               # Static utilities for logging, tool detection, and SSH operations
    ├── SSHManager.ps1            # SSH key generation, config management, and session handling
    ├── VMManager.ps1             # VirtualBox VM lifecycle management and cleanup
    ├── CloudInitManager.ps1      # Cloud-init configuration, NM static profile, and ISO creation
    ├── run-vm.ps1                # Main orchestration script with parameter handling
    ├── Binary/                   # Directory for binary tools (e.g., mkisofs alternatives)
    ├── logs/                     # Directory for execution logs
    └── README.md                 # Comprehensive documentation
```

### Module Descriptions

- **VMConfig.ps1**: Configuration management class that handles parameter defaults, path initialization, and configuration serialization. Uses intelligent default-setting to avoid hardcoded duplication. Derives LAN IP (from inventory), gateway, DNS, and interface name (image-aware) automatically.

- **VMUtils.ps1**: Static utility class providing logging infrastructure, automatic tool detection and installation via Chocolatey, SSH known_hosts management, and connection testing utilities.

- **SSHManager.ps1**: Manages SSH key generation (ed25519/RSA fallback), SSH config updates for easy access, and cleanup of SSH artifacts. Uses dependency injection for better testability.

- **VMManager.ps1**: Handles VirtualBox VM operations including creation, configuration, storage attachment, NAT port forwarding, bridged NIC2 auto-selection, and comprehensive cleanup of VM artifacts and registry entries.

- **CloudInitManager.ps1**: Creates cloud-init user-data and meta-data files for automated VM provisioning, writes a NetworkManager static connection profile (based on inventory) via write_files and activates it via runcmd, and generates seed ISOs using mkisofs or alternatives.

- **run-vm.ps1**: Main entry point that orchestrates the entire VM creation process, handles command-line parameters, and coordinates between all manager classes.

- **Binary/**: Contains alternative binary tools like mkisofs from Cygwin/MinGW for ISO creation when standard tools aren't available.

- **logs/**: Stores timestamped execution logs for debugging and troubleshooting. Old logs are automatically cleaned up to prevent disk space issues.

## Key Improvements

### ✅ Clean & Modular
- **Separation of Concerns**: Each module has a single responsibility
- **Dependency Injection**: Clean interfaces between modules
- **Testable Code**: Isolated functions for easy testing

### ✅ Optimized & Dynamic
- **Smart Tool Detection**: Automatic installation via Chocolatey
- **Efficient Resource Management**: Proper cleanup and UUID alignment
- **Dynamic Configuration**: Flexible parameter handling
- **Inventory‑Driven Networking**: LAN IP, gateway, DNS, and interface are derived from `inventory/hosts.yml`; bridged adapter is auto‑selected

### ✅ Well Documented
- **Comprehensive Help**: Full PowerShell help system
- **Inline Comments**: Clear code documentation
- **Usage Examples**: Practical examples for common scenarios

### ✅ Minimal & Maintainable
- **Reduced Complexity**: ~70% reduction in main script size
- **DRY Principle**: Eliminated code duplication
- **Error Handling**: Robust error handling with meaningful messages

## Quick Start

### Basic Usage

Inventory‑driven networking (no hardcoding):

```ini
# inventory/hosts.yml
all:
  children:
    primary:
      hosts:
      yourdomain.com:
          ansible_host: 192.168.88.8
```

Then run:

```powershell
# Create a new AlmaLinux VM with default settings
.\scripts\vm-launcher\run-vm.ps1

# Create VM with custom configuration
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -MemoryMB 4096 -CPUs 2

### Advanced Usage

```powershell
# Uses custom SSH user "admin"
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -SSHUser "admin"
# -UseLocalSSHKey injects your local SSH public key and disables password authentication
# Create VM with SSH key injection and auto-connect, Enter passphrase (empty for no passphrase)
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -UseLocalSSHKey 
# -AutoSSH opens SSH session in new window and script exits 
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -AutoSSH
# Create VM with custom SSH user and password
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -SSHUser "admin" -SSHPassword "Changeme123!"
# Create VM with custom SSH user, password, and custom  SSH port
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -SSHUser "admin" -SSHPassword "Changeme123!" -HostSSHPort 2223

# FULL AUTOMATED SETUP - One command does everything:
# Recreates VM (cleanup existing), installs Docker, sets up Molecule, clones project, runs first test
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -UseLocalSSHKey -Recreate -FullSetup

# Or for first-time setup (no existing VM to cleanup):
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -UseLocalSSHKey -FullSetup
```

## Configuration Options

| Parameter          | Default                      | Description                                                                 |
|-------------------:|:----------------------------:|:----------------------------------------------------------------------------|
| `VMName`           | "AlmaLinux-9"                | VirtualBox VM display name                                                  |
| `VMDataRoot`       | "C:\VMData"                  | Root directory for VM storage                                               |
| `MemoryMB`         | 4096                         | RAM allocation in MB                                                        |
| `CPUs`             | 2                            | Number of CPU cores                                                         |
| `HostSSHPort`      | 22                           | Host port for SSH forwarding                                                |
| `WaitSSHSeconds`   | 180                          | Seconds to wait for SSH availability                                        |
| `SSHUser`          | "admin"                      | SSH username                                                                |
| `SSHPassword`      | "Changeme123!"               | SSH password                                                                |
| `UseLocalSSHKey`   | false                        | Inject local SSH public key (only when `-UseLocalSSHKey` is provided)       |
| `AutoSSH`          | false                        | Auto-open SSH session (only when `-AutoSSH` is provided)                    |
| `FullSetup`        | false                        | Complete automated setup: Docker, Molecule, project clone. Best used with `-Recreate` for cleanup before setup. Tests run separately on demand. Venv NOT auto-activated on SSH (use test scripts). |
| `BridgeAdapterName`| -                            | Network adapter name for bridged networking                                 |
| `LanIPAddress`     | -                            | Static LAN IP address for the VM                                            |
| `LanPrefixLength`  | 24                           | CIDR prefix length for LAN IP                                               |
| `LanGateway`       | -                            | LAN gateway IP address                                                      |
| `LanDnsServers`    | 8.8.8.8, 1.1.1.1             | DNS servers for LAN (array)                                                 |
| `LanInterfaceName` | -                            | Network interface name in VM                                                |
| `LanNicType`       | "virtio"                     | VirtualBox NIC model for bridged adapter                                    |
| `Remove`           | -                            | Switch parameter: Cleanup mode                                              |
| `Force`            | -                            | Switch parameter: Complete cleanup including QCOW2 image (use with -Remove) |
| `Recreate`         | -                            | Switch parameter: Recreate VM with fresh installation                       |

### Networking (auto when omitted)

| Parameter           | Default        | Description                                                                 |
|:-------------------:|:--------------:|:----------------------------------------------------------------------------|
| `BridgeAdapterName` | Auto‑detect    | Chooses a bridged adapter by LAN subnet; falls back to first Up adapter, then first available. Override via param or `$env:VPSSETUP_BRIDGE_ADAPTER`. |
| `LanIPAddress`      | From inventory | Uses `ansible_host` from `primary` group in `inventory/hosts.yml`.           |
| `LanPrefixLength`   | 24             | CIDR prefix length for LAN IP.                                               |
| `LanGateway`        | Derived        | Inferred as `x.x.x.1` from `LanIPAddress` unless overridden.                 |
| `LanDnsServers`     | 8.8.8.8, 1.1.1.1 | DNS servers; can be customized.                                             |
| `LanInterfaceName`  | Auto by image  | `eth0` on RHEL-like (AlmaLinux/Rocky/RHEL/CentOS) images; `enp0s8` otherwise. Can be overridden. |

## Prerequisites

### Required Software
- **PowerShell 5.1+**: Core scripting environment
- **VirtualBox 7.x**: Virtualization platform
- **QEMU 8.x**: Disk image conversion
- **OpenSSH**: Secure shell client/server
- **Chocolatey**: Package manager (auto-installed if missing)
- **WSL (Windows Subsystem for Linux)**: Required for running Ansible playbooks

### Automatic Installation
The script automatically detects and installs missing tools via Chocolatey:
- `qemu` - For QCOW2 to VDI conversion
- `virtualbox` - Virtualization platform
- `openssh` - SSH client and utilities
- `cdrtools` or `genisoimage` - ISO creation tools

WSL is installed automatically if missing (requires Administrator privileges and system reboot). AlmaLinux 9 is installed as the default distribution for CentOS compatibility.

## How It Works

### 1. Configuration Phase
- Parse command-line parameters
- Initialize configuration object
- Set up logging and error handling

### 2. Tool Verification
- Check for required executables in PATH
- Auto-install missing tools via Chocolatey
- Resolve full paths to executables

### 3. VM Creation Process
1. **Download Cloud Image**: Fetch AlmaLinux cloud image (cached)
2. **Convert Disk**: QCOW2 → VDI format
3. **SSH Key Management**: Generate or load SSH keys
4. **Cloud-Init Setup**: Create user-data, meta-data, and network-config
5. **ISO Creation**: Build cloud-init seed ISO
6. **VM Configuration**: Create and configure VirtualBox VM
7. **Network Setup**: Configure NAT port forwarding; attach a bridged NIC (auto‑selected) and apply static LAN settings
8. **Boot & Wait**: Start VM and wait for SSH availability

### 3.1 Networking Automation
- The LAN IP is read from `inventory/hosts.yml` (`primary` group → `ansible_host`).
- The bridged adapter is auto‑detected to match the LAN subnet, with robust fallbacks.
- A NetworkManager static profile is written via cloud‑init (write_files) and brought up via runcmd, enforcing the static IP, gateway, and DNS on first boot.
- Interface name is chosen automatically by image type (`eth0` for RHEL‑like images). You can override with `-LanInterfaceName` if needed.

### 4. SSH Configuration
- Auto-populate `~/.ssh/config` for easy access
- Clear known_hosts entries to prevent conflicts
- Support for both password and key-based authentication

### 5. Full Automated Setup (Optional)
When `-FullSetup` is enabled, the launcher performs complete environment setup after VM creation:

1. **Install Dependencies**: Uploads and executes `ci-setup.sh` to install:
   - Docker CE, containerd, and Docker CLI
   - Python 3, pip, git, rsync, sshpass
   - Python virtual environment with Ansible, Molecule, ansible-lint, yamllint
   - Adds user to docker group

2. **Clone Project**: Automatically clones VPS repository to `~/vps`

3. **Verify Installation**: Tests Docker accessibility and version

4. **Ready to Use**: VM is fully configured and ready for Molecule testing
   - Virtual environment is NOT auto-activated on SSH login (for flexibility)
   - To activate manually: `source ~/molecule-env/bin/activate`
   - Or use test scripts which auto-activate: `bash ~/vps/scripts/run-test.sh <role>`

**Important Notes:**
- `-FullSetup` does NOT cleanup existing VMs. Use `-Recreate -FullSetup` for automatic cleanup + full setup.
- For first-time setup (no existing VM), `-FullSetup` alone is sufficient.
- For re-running setup on existing VM, combine with `-Recreate` flag.
- **Tests run separately**: Use `bash scripts/run-test.sh <role>` or `.\scripts\run-test.ps1 -Role <role>` from Windows
- **Auto-install on first test**: Running `run-test.sh` on a clean server automatically installs the environment

This eliminates all manual setup steps from the SSH Setup guide.

## File Structure

After successful execution, the following structure is created:

```
C:\VMData\
└── AlmaLinux-9\
    ├── disk.vdi              # Converted VM disk
    ├── cloud-init.iso        # Cloud-init configuration
    ├── cidata\               # Cloud-init source files
   │   ├── meta-data
   │   ├── user-data         # Includes embedded network v1 + write_files + runcmd
   │   └── network-config    # Standalone network-config (v1) for compatible images
    └── AlmaLinux-9-GenericCloud-latest.x86_64.qcow2
```

## SSH Access

Once the VM is ready, you can connect using:

```bash
# Using the configured SSH config
ssh localhost

# Or directly
ssh -p 2222 admin@192.168.88.8
# With custom port
ssh -p 2223 admin@localhost
```

To become root on the VM: use `sudo` from the configured user (no password required when SSH key auth is used):

```bash
sudo -i
# or
sudo su -
```

To enable `su root` with a password, set a root password inside the VM:

```bash
sudo passwd root
# enter the new root password twice
```

## Cleanup Operations

The script provides comprehensive cleanup with different modes:

### Cleanup Modes
 Can be combined with `-FullSetup` for complete automation.
- **`-Remove`**: Standard cleanup - unregisters VM, removes media registry entries, deletes VM files (preserves QCOW2 image), clears SSH known_hosts entries, cleans up SSH config, removes orphaned SSH keys, and removes the VM directory if empty.

- **`-Remove -Force`**: Complete cleanup - removes everything including the QCOW2 image file and VM directory for complete removal.

- **`-Recreate`**: Recreate mode - performs cleanup (preserving QCOW2) then immediately starts fresh VM installation.

### Automatic Cleanup Examples

```powershell
# Standard cleanup (preserves QCOW2 image)
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -Remove

# Complete cleanup (removes everything including QCOW2 image)
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -Remove -Force

# Recreate VM with fresh installation
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -Recreate

# Recreate VM with full automated setup (recommended for re-deployment)
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux-9" -UseLocalSSHKey -Recreate -FullSetup
```

### Manual Cleanup
```powershell
# Remove everything including QCOW2
Remove-Item -Recurse -Force C:\VMData\AlmaLinux-9

# Clear SSH config
Clear-Content ~/.ssh/config
```

## Troubleshooting

### VM Management Commands
```bash
# Check VM status
VBoxManage list vms
VBoxManage list runningvms

# Start VM headless (background)
VBoxManage startvm "AlmaLinux-9" --type headless

# Stop VM (graceful shutdown)
VBoxManage controlvm "AlmaLinux-9" acpipowerbutton

# Force stop VM (immediate)
VBoxManage controlvm "AlmaLinux-9" poweroff

# Restart VM
VBoxManage controlvm "AlmaLinux-9" reset

# Get VM info
VBoxManage showvminfo "AlmaLinux-9"
```

## Error Handling

The script includes robust error handling:

- **Tool Detection**: Clear messages for missing dependencies
- **VM Operations**: Retry logic for transient failures
- **Network Issues**: Timeout handling for SSH connectivity
- **File Operations**: Safe cleanup with error recovery
- **Logging**: Comprehensive logging to timestamped files

## Troubleshooting

### Common Issues

1. **"Tool not found" errors**
   - Ensure Chocolatey is installed and accessible
   - Check PATH environment variable
   - Run as Administrator for installations

2. **VM fails to start**
   - Check VirtualBox installation
   - Verify sufficient RAM/CPU resources
   - Review VirtualBox logs

3. **SSH connection fails**
   - Verify firewall settings
   - Check port availability
   - Review cloud-init logs in VM

5. **LAN IP didn’t apply (still DHCP)**
    - Verify the interface name the image uses (e.g., `ip addr` shows `eth0` with `altname enp0s8`). If different, pass `-LanInterfaceName`.
    - Check that the NetworkManager profile exists and is up:
       ```bash
       nmcli -t -f NAME,UUID,DEVICE con show
       sudo cat /etc/NetworkManager/system-connections/static-<iface>.nmconnection
       ```
    - Ensure the bridged adapter is correct. You can override with:
       ```powershell
       $env:VPSSETUP_BRIDGE_ADAPTER = 'Your Adapter Name'
       .\scripts\vm-launcher\run-vm.ps1 -Recreate
       ```
    - Confirm inventory has the desired IP under `[primary]` as `ansible_host`.

4. **Disk conversion errors**
   - Ensure QEMU tools are properly installed
   - Check disk space availability
   - Verify source QCOW2 integrity

### Debug Mode

Enable verbose output for troubleshooting:

```powershell
$VerbosePreference = 'Continue'
.\scripts\vm-launcher\run-vm.ps1 -Verbose
```

## Security Considerations

- **SSH Keys**: Generated keys are shared across VMs for convenience.
- **Passwords**: Change default passwords in production; when a public key is provided, the launcher disables SSH password auth by default (cloud-init `ssh_pwauth: false`).
- **Network**: VMs run with NAT networking (isolated) plus an optional bridged NIC for LAN access.
- **File Permissions**: SSH keys and NM profiles are written with restrictive permissions.
- **Cleanup**: Comprehensive cleanup prevents key and config leakage.

## Performance Optimization

- **Image Caching**: QCOW2 images are preserved between runs
- **Smart Cleanup**: Only removes necessary files during cleanup
- **Parallel Operations**: Efficient tool detection and installation
- **Memory Management**: Proper disposal of resources

## Contributing

### Code Style
- Use PowerShell classes for encapsulation
- Follow consistent naming conventions
- Include comprehensive error handling
- Add inline documentation
- Write testable functions

### Testing
- Test each module independently
- Verify cleanup operations
- Test error scenarios
- Validate SSH connectivity
- Check file system operations

## Migration from Original Script

The refactored version maintains full compatibility:

1. **Same Parameters**: All original parameters supported
2. **Same Behavior**: Identical VM creation and cleanup
3. **Same Output**: Compatible logging and console output
4. **Same Files**: Identical file structure and naming

### Migration Steps
1. Backup your original `launch-vm.ps1`
2. Copy the new modular files to your scripts directory
3. Test with a new VM name first
4. Gradually migrate your configurations

## Version History

### v2.0 - Clean Architecture
- Complete modular refactor
- Improved error handling
- Enhanced documentation
- Better tool detection
- Optimized performance

### v1.0 - Original Script
- Monolithic architecture
- Basic functionality
- Limited error handling
- Minimal documentation

## Changelog

### v2.3 - Test Workflow Improvements (2026-02-03)
- **Removed automatic test execution from FullSetup** - tests now run separately on demand
- **Added auto-install to run-test.sh** - automatically installs Molecule environment if missing
- **Updated run-test.ps1** - now SSHs to VM instead of running locally on Windows
- **Fixed .bashrc auto-activation** - uses heredoc for proper newline handling
- **Improved SSH stability** - added delays and retry logic to prevent connection reset errors
- Tests are now explicitly separate from environment setup for cleaner workflows

### v2.2 - Full Automation (2026-01-31)
- Added `-FullSetup` parameter for complete automated environment setup
- Automated Docker installation, Python environment setup, and Molecule dependencies
- Automated project cloning
- Eliminates all manual setup steps from SSH Setup workflow
- Single command creates VM with complete testing environment

### v2.1 - Minor Updates (2026-01-20)
- Changed default HostSSHPort from 2222 to 22 for standard SSH port usage
- Modified AutoSSH to open SSH session asynchronously in new window (script exits immediately)
- Clarified SSH key injection behavior for -UseLocalSSHKey parameter
- Updated cleanup descriptions to reflect VM directory removal when empty
- Improved documentation for AutoSSH functionality

### v2.0 - Clean Architecture
- Complete modular refactor
- Improved error handling
- Enhanced documentation
- Better tool detection
- Optimized performance

### v1.0 - Original Script
- Monolithic architecture
- Basic functionality
- Limited error handling
- Minimal documentation

---

**Author**: VPS Setup Script Team
**Version**: 2.2
**License**: MIT
**Repository**: [vps](https://github.com/luciancurteanu/vps)
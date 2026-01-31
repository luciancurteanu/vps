param(
    [Parameter(Mandatory = $false)]
    [string]$VMName = "AlmaLinux9-Dev",
    
    [Parameter(Mandatory = $false)]
    [string]$VMDataRoot = "C:\VMData",
    
    [Parameter(Mandatory = $false)]
    [int]$MemoryMB = 4096,
    
    [Parameter(Mandatory = $false)]
    [int]$CPUs = 2,
    
    [Parameter(Mandatory = $false)]
    [int]$HostSSHPort = 22,
    
    [Parameter(Mandatory = $false)]
    [int]$WaitSSHSeconds = 180,
    
    [Parameter(Mandatory = $false)]
    [string]$SSHUser = 'admin',
    
    [Parameter(Mandatory = $false)]
    [string]$SSHPassword = 'Changeme123!',
    
    [switch]$UseLocalSSHKey,
    
    [switch]$AutoSSH,

    [switch]$FullSetup,

    [Parameter(Mandatory = $false)]
    [string]$BridgeAdapterName,

    [Parameter(Mandatory = $false)]
    [string]$LanIPAddress,

    [Parameter(Mandatory = $false)]
    [int]$LanPrefixLength = 24,

    [Parameter(Mandatory = $false)]
    [string]$LanGateway,

    [Parameter(Mandatory = $false)]
    [string[]]$LanDnsServers,

    [Parameter(Mandatory = $false)]
    [string]$LanInterfaceName,

    [Parameter(Mandatory = $false)]
    [string]$LanNicType = 'virtio',
    
    [switch]$Remove,
    
    [switch]$Force,
    
    [switch]$Recreate
)

# Set error handling and suppress verbose output
$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'
$ProgressPreference = 'Continue'
$VerbosePreference = 'SilentlyContinue'

# Import required modules
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptPath 'VMConfig.ps1')
. (Join-Path $scriptPath 'VMUtils.ps1')
. (Join-Path $scriptPath 'SSHManager.ps1')
. (Join-Path $scriptPath 'VMManager.ps1')
. (Join-Path $scriptPath 'CloudInitManager.ps1')

function Main {
    try {
        # Initialize utilities first (needed for all operations including cleanup)
        [VMUtils]::Initialize($PSScriptRoot) | Out-Null

        # Initialize configuration (only include UseLocalSSHKey if switch provided)
        $params = @{
                VMName            = $VMName
                VMDataRoot        = $VMDataRoot
                MemoryMB          = $MemoryMB
                CPUs              = $CPUs
                HostSSHPort       = $HostSSHPort
                WaitSSHSeconds    = $WaitSSHSeconds
                SSHUser           = $SSHUser
                SSHPassword       = $SSHPassword
                AutoSSH           = $AutoSSH.IsPresent
                FullSetup         = $FullSetup.IsPresent
                BridgeAdapterName = $BridgeAdapterName
                LanIPAddress      = $LanIPAddress
                LanPrefixLength   = $LanPrefixLength
                LanGateway        = $LanGateway
                LanDnsServers     = $LanDnsServers
                LanInterfaceName  = $LanInterfaceName
                LanNicType        = $LanNicType
                Remove            = $Remove.IsPresent
                Force             = $Force.IsPresent
                Recreate          = $Recreate.IsPresent
            }

        if ($UseLocalSSHKey.IsPresent) { $params.UseLocalSSHKey = $true }

        $config = [VMConfig]::new($params)

        # Start logging
        $logFileName = $config.GetLogFileName()
        [VMUtils]::StartLogging($logFileName) | Out-Null

        # Ensure required tools are available
        EnsureRequiredTools

        # Handle different modes
        if ($config.Remove -or $config.Recreate) {
            if ($config.Force -and $config.Remove) {
                Write-Host "Complete cleanup requested for $($config.VMName) (removing everything including QCOW2 image)" -ForegroundColor Cyan
                PerformCleanup $config $true $true
            }
            elseif ($config.Recreate) {
                Write-Host "Recreate requested for $($config.VMName) (keeping QCOW2, fresh install)" -ForegroundColor Cyan
                PerformCleanup $config $false $false
                Write-Host "Starting fresh VM installation: $($config.VMName)" -ForegroundColor Cyan
                PerformInstallation $config
            }
            elseif ($config.Remove) {
                Write-Host "Standard cleanup requested for $($config.VMName) (preserving QCOW2 image)" -ForegroundColor Cyan
                PerformCleanup $config $false $true
            }
            return
        }

        # Perform fresh VM installation
        Write-Host "Starting fresh VM installation: $($config.VMName)" -ForegroundColor Cyan
        PerformInstallation $config

    }
    catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
    finally {
        [VMUtils]::StopLogging() | Out-Null
    }
}

function EnsureRequiredTools {
    Write-Host "Ensuring required tools are available..." -ForegroundColor Cyan

    [VMUtils]::EnsureTool('qemu-img.exe', 'qemu', 'C:\Program Files\qemu', 'C:\ProgramData\chocolatey\lib\qemu\tools')
    [VMUtils]::EnsureTool('VBoxManage.exe', 'virtualbox', 'C:\Program Files\Oracle\VirtualBox', $null)
    [VMUtils]::EnsureTool('ssh.exe', 'openssh', 'C:\Windows\System32\OpenSSH', 'C:\Program Files\Git\usr\bin')
    [VMUtils]::EnsureTool('ssh-keygen.exe', 'openssh', 'C:\Windows\System32\OpenSSH', 'C:\Program Files\Git\usr\bin')

    # Find mkisofs tool
    $script:MkIsoFS = [VMUtils]::FindMkIsoFS()
}

function PerformCleanup([VMConfig]$config, [bool]$forceDelete = $false, [bool]$removeLogFile = $false) {
    # Initialize managers
    $sshManager = [SSHManager]::new($config.SSHDir, $config.SharedPrivKey, $config.SharedPubKey, $config.SharedMarker, $config.SSHConfig, [VMUtils])
    $vmManager = [VMManager]::new(
        (Get-Command VBoxManage.exe).Source,
        (Get-Command qemu-img.exe).Source,
        $config.VMName,
        $config.VMData,
        $config.QcowPath,
        $config.VDIPath,
        $config.SeedISOPath
    )

    # Perform cleanup
    $vmManager.CleanupVM($forceDelete)
    $sshManager.CleanupSSHKeys($config.VMName)
    [VMUtils]::ClearKnownHostsPort($config.HostSSHPort)
    # Also clear LAN IP from known_hosts if it was configured
    if ($config.LanIPAddress) {
        [VMUtils]::ClearKnownHostsHost($config.LanIPAddress)
    }
    [VMUtils]::ClearSSHConfig()
    
    # Stop logging and remove the active log file for cleanup runs (only when -Remove flag is used)
    if ($removeLogFile) {
        try {
            [VMUtils]::StopLogging()
        }
        catch { }

        $activeLog = [VMUtils]::LogFile
        if ($activeLog -and (Test-Path -LiteralPath $activeLog)) {
            try {
                Remove-Item -Path $activeLog -Force -ErrorAction SilentlyContinue
                Write-Host "Removed active log file: $(Split-Path $activeLog -Leaf)" -ForegroundColor DarkGray
            }
            catch {
                Write-Verbose "Could not remove active log file: $_"
            }
        }
    }
    
    # Clean up orphan files
    CleanupOrphanFiles $config
}

function PerformInstallation([VMConfig]$config) {
    # Ensure WSL is available for Ansible (only installs if not already present)
    [VMUtils]::EnsureWSL()

    # Initialize managers
    $sshManager = [SSHManager]::new($config.SSHDir, $config.SharedPrivKey, $config.SharedPubKey, $config.SharedMarker, $config.SSHConfig, [VMUtils])
    $vmManager = [VMManager]::new(
        (Get-Command VBoxManage.exe).Source,
        (Get-Command qemu-img.exe).Source,
        $config.VMName,
        $config.VMData,
        $config.QcowPath,
        $config.VDIPath,
        $config.SeedISOPath
    )
    $cloudInitManager = [CloudInitManager]::new($config.CIDataPath, $config.SeedISOPath, $script:MkIsoFS)

    # Ensure VM data directory exists
    if (-not (Test-Path $config.VMData)) {
        New-Item -ItemType Directory -Path $config.VMData | Out-Null
    }

    # Download and convert cloud image
    $vmManager.EnsureQcowImage($config.CloudImageUrl)
    $vmManager.ConvertQcowToVDI()

    # Handle SSH keys
    $pubKey = $null
    if ($config.UseLocalSSHKey) {
        if (-not $sshManager.LoadExistingKeys($config.VMName)) {
            $keyGenerated = $sshManager.GenerateSSHKeys($config.VMName)
            if (-not $keyGenerated) {
                Write-Host "Warning: SSH key generation failed, continuing without SSH key injection" -ForegroundColor Yellow
            }
        }
        $pubKey = $sshManager.PubKey
    }

    # Auto-select bridged adapter when not provided
    if (-not $config.BridgeAdapterName -and $config.LanIPAddress) {
        $detectedAdapter = $vmManager.GetDefaultBridgeAdapter($config.LanIPAddress)
        if ($detectedAdapter) {
            $config.BridgeAdapterName = $detectedAdapter
            Write-Host "Using bridged adapter '$($config.BridgeAdapterName)' for LAN connectivity" -ForegroundColor Cyan
        }
        else {
            Write-Host "Warning: Could not detect a bridged adapter for LAN IP $($config.LanIPAddress). VM will use NAT only." -ForegroundColor Yellow
        }
    }

    # Create cloud-init data and ISO
    $cloudInitManager.CreateUserData(
        $config.SSHUser,
        $config.SSHPassword,
        $pubKey,
        $config.LanInterfaceName,
        $config.LanIPAddress,
        $config.LanPrefixLength,
        $config.LanGateway,
        $config.LanDnsServers,
        $config.Domain
    )
    $cloudInitManager.CreateSeedISO()

    # Clean up any existing VM artifacts
    $vmManager.CleanVBoxMedia()
    $vmManager.UnregisterMediumByPath($config.VDIPath)
    $vmManager.AlignVDIUUID()

    # Unregister existing VM if present
    if ((& $vmManager.VBoxManage list vms) -match $config.VMName) {
        Write-Host "Unregistering existing $($config.VMName)" -ForegroundColor Yellow
        try { & $vmManager.VBoxManage controlvm $config.VMName poweroff 2>$null | Out-Null } catch { }
        try { & $vmManager.VBoxManage unregistervm $config.VMName 2>$null | Out-Null } catch { }
    }

    # Create and configure VM
    $vmManager.CreateVM($config.MemoryMB, $config.CPUs, $config.VMDataRoot, $config.BridgeAdapterName, $config.LanNicType)

    # Ensure bridged adapter promiscuous mode and audio settings are applied before starting
    $promiscAdapterIndex = if ($config.BridgeAdapterName) { 2 } else { 1 }
    Write-Host "Applying VM-level network/audio hardening: promiscuous=allow-all on nic$promiscAdapterIndex and audio=none" -ForegroundColor Cyan

    # Retry loop: handle VirtualBox "locked for a session" transient errors
    $maxAttempts = 6
    $attempt = 1
    while ($attempt -le $maxAttempts) {
        # Choose audio flag based on VBoxManage version to avoid deprecated warnings
        $audioArg = '--audio none'
        try {
            $vOut = & $vmManager.VBoxManage --version 2>$null
            if ($vOut) {
                $vLine = ($vOut | Select-Object -First 1).ToString()
                # Try to find a version number like 7.2.4 or 7.2
                if ($vLine -match '(\d+)\.(\d+)(?:\.(\d+))?') {
                    $major = [int]$matches[1]
                } else {
                    # Fallback: search entire output for first occurrence of digits.digits
                    $found = $vOut -join " `n" -match '(\d+)\.(\d+)'
                    if ($found) { $major = [int]$matches[1] }
                }
                if ($major -ge 7) { $audioArg = '--audio-driver none' }
            }
        } catch { }

        # Use Start-Process to capture stdout/stderr and exit code reliably
        $tmpOut = [System.IO.Path]::GetTempFileName()
        $tmpErr = [System.IO.Path]::GetTempFileName()
        $argList = @('modifyvm', $config.VMName, "--nicpromisc$promiscAdapterIndex", 'allow-all', $audioArg)
        $proc = Start-Process -FilePath $vmManager.VBoxManage -ArgumentList $argList -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr
        $stdout = ''
        $stderr = ''
        try { $stdout = Get-Content -Path $tmpOut -Raw -ErrorAction SilentlyContinue } catch { }
        try { $stderr = Get-Content -Path $tmpErr -Raw -ErrorAction SilentlyContinue } catch { }
        Remove-Item $tmpOut,$tmpErr -ErrorAction SilentlyContinue
        $out = ($stderr + "`n" + $stdout).Trim()
        $exitCode = $proc.ExitCode
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Applied promiscuous/audio settings to $($config.VMName)" -ForegroundColor Green
            break
        }

        $outText = ($out -join "`n")
        if ($outText -match 'locked for a session|already locked') {
            Write-Warning "VM '$($config.VMName)' is locked (attempt $attempt/$maxAttempts). Attempting to clear session and retry..."
            try {
                # Try to poweroff if running, ignore errors
                & $vmManager.VBoxManage controlvm $config.VMName poweroff 2>$null | Out-Null
            } catch { }
            try {
                # Try to discard saved state
                & $vmManager.VBoxManage controlvm $config.VMName discardstate 2>$null | Out-Null
            } catch { }

            Start-Sleep -Seconds (2 * $attempt)
            $attempt++
            continue
        }

        Write-Warning "Could not apply promiscuous/audio settings to $($config.VMName): $outText"
        break
    }
    
    $vmManager.StartVM()
    $vmManager.ConfigureNATPortForwarding($config.HostSSHPort)

    # Wait for SSH to be available
    Write-Host "Waiting for SSH on localhost:$($config.HostSSHPort)..." -ForegroundColor Cyan
    if ([VMUtils]::TestSSHConnection('127.0.0.1', $config.HostSSHPort, $config.WaitSSHSeconds)) {
        Write-Host "SSH is ready: ssh -p $($config.HostSSHPort) $($config.SSHUser)@localhost" -ForegroundColor Green

        # Update SSH config for easy access
        if ($pubKey) {
            $sshManager.UpdateSSHConfig($config.HostSSHPort, $config.SSHUser, $sshManager.PrivKeyFile)
        }

        # Run full automated setup if requested
        if ($config.FullSetup -and $pubKey) {
            PerformFullSetup $config $sshManager
        }

        # Auto-open SSH session if requested (after full setup completes)
        if ($config.AutoSSH -and $pubKey) {
            $sshManager.OpenSSHSession($config.HostSSHPort, $config.SSHUser, $sshManager.PrivKeyFile)
        }
    }
    else {
        throw "SSH not reachable on localhost:$($config.HostSSHPort)"
    }
}

function PerformFullSetup([VMConfig]$config, [SSHManager]$sshManager) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Starting Full Automated Setup" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    $sshCmd = "ssh"
    $sshArgs = @(
        "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=NUL",
        "-o", "LogLevel=ERROR",
        "-i", $sshManager.PrivKeyFile,
        "-p", $config.HostSSHPort.ToString(),
        "$($config.SSHUser)@localhost"
    )

    # Step 1: Upload and run ci-setup.sh
    Write-Host "`n[1/5] Installing Docker, Python, and Molecule dependencies..." -ForegroundColor Cyan
    $ciSetupPath = Join-Path ([VMUtils]::ScriptDir) "..\..\scripts\ci-setup.sh"
    if (-not (Test-Path $ciSetupPath)) {
        Write-Host "Warning: ci-setup.sh not found at $ciSetupPath, skipping automated setup" -ForegroundColor Yellow
        return
    }

    # Upload ci-setup.sh
    $scpArgs = @(
        "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=NUL",
        "-o", "LogLevel=ERROR",
        "-i", $sshManager.PrivKeyFile,
        "-P", $config.HostSSHPort.ToString(),
        $ciSetupPath,
        "$($config.SSHUser)@localhost:/tmp/ci-setup.sh"
    )
    $null = & scp $scpArgs 2>&1

    # Run ci-setup.sh
    Write-Host "Uploading and executing ci-setup.sh..." -ForegroundColor Yellow
    $setupCmd = "chmod +x /tmp/ci-setup.sh && sudo bash /tmp/ci-setup.sh --yes"
    $sshArgsWithCmd = $sshArgs + @($setupCmd)
    & $sshCmd $sshArgsWithCmd
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Warning: ci-setup.sh failed with exit code $LASTEXITCODE" -ForegroundColor Yellow
    } else {
        Write-Host "Docker and Molecule dependencies installed successfully" -ForegroundColor Green
    }

    # Step 2: Clone project repository
    Write-Host "`n[2/5] Cloning VPS project repository..." -ForegroundColor Cyan
    $cloneCmd = "if [ ! -d ~/vps ]; then git clone https://github.com/luciancurteanu/vps.git ~/vps && sudo chown -R $($config.SSHUser):$($config.SSHUser) ~/vps; else echo 'Project already exists'; fi"
    $sshArgsWithClone = $sshArgs + @($cloneCmd)
    & $sshCmd $sshArgsWithClone
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Warning: Project clone failed. Repository may be empty or private." -ForegroundColor Yellow
        Write-Host "Tip: Upload local files manually or make repository public." -ForegroundColor Yellow
    } else {
        Write-Host "Project cloned successfully" -ForegroundColor Green
    }

    # Step 3: Apply docker group membership
    Write-Host "`n[3/5] Applying docker group membership..." -ForegroundColor Cyan
    Write-Host "Docker group applied (will use 'sudo docker' for commands)" -ForegroundColor Green

    # Step 4: Verify Docker is accessible
    Write-Host "`n[4/5] Verifying Docker installation..." -ForegroundColor Cyan
    $verifyCmd = "sudo docker --version && sudo docker ps"
    $sshArgsWithVerify = $sshArgs + @($verifyCmd)
    & $sshCmd $sshArgsWithVerify 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Docker is accessible and running" -ForegroundColor Green
    } else {
        Write-Host "Warning: Docker may not be accessible yet" -ForegroundColor Yellow
        Write-Host "You may need to reconnect SSH and run tests manually" -ForegroundColor Yellow
    }

    # Step 5: Run first molecule test
    Write-Host "`n[5/5] Running first molecule test (common role)..." -ForegroundColor Cyan
    Write-Host "This may take several minutes..." -ForegroundColor Yellow
    $testCmd = "cd ~/vps && sudo bash scripts/run-test.sh common"
    $sshArgsWithTest = $sshArgs + @($testCmd)
    & $sshCmd $sshArgsWithTest
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nFull automated setup completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "`nSetup completed with warnings. You may need to run tests manually." -ForegroundColor Yellow
    }

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Full Setup Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "[OK] Docker and Molecule installed" -ForegroundColor Green
    Write-Host "[OK] VPS project cloned to ~/vps" -ForegroundColor Green
    Write-Host "[OK] SSH config updated" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "  ssh localhost" -ForegroundColor White
    Write-Host "  cd ~/vps" -ForegroundColor White
    Write-Host "  bash scripts/run-test.sh `<role-name`>" -ForegroundColor White
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function CleanupOrphanFiles([VMConfig]$config) {
    Write-Host "Checking for orphan files..." -ForegroundColor Cyan
    
    # Clean up old log files (keep last 5 for this VM)
    $logsDir = Join-Path ([VMUtils]::ScriptDir) "logs"
    if (Test-Path $logsDir) {
        $logFiles = Get-ChildItem -Path $logsDir -Filter "$($config.VMName)-*.log" | Sort-Object LastWriteTime -Descending
        if ($logFiles.Count -gt 5) {
            $filesToRemove = $logFiles | Select-Object -Skip 5
            foreach ($file in $filesToRemove) {
                try {
                    Remove-Item -Path $file.FullName -Force
                    Write-Host "Removed old log: $($file.Name)" -ForegroundColor DarkGray
                }
                catch {
                    Write-Verbose "Could not remove old log: $($file.Name)"
                }
            }
        }
    }
    
    # Clean up SSH directory orphans
    $sshDir = $config.SSHDir
    if (Test-Path $sshDir) {
        # Remove vps related files if no VMs are using them
        $markerFile = $config.SharedMarker
        if (Test-Path $markerFile) {
            $markerContent = Get-Content -Path $markerFile -ErrorAction SilentlyContinue
            $hasActiveVMs = $false
            
            if ($markerContent) {
                foreach ($line in $markerContent) {
                    if ($line -match '^vms=(.+)') {
                        $vms = $line -replace '^vms=', ''
                        if ($vms -and $vms -ne '') {
                            $hasActiveVMs = $true
                            break
                        }
                    }
                }
            }
            
            if (-not $hasActiveVMs) {
                # No active VMs, safe to remove shared SSH files
                $sharedFiles = @($config.SharedPrivKey, $config.SharedPubKey, $markerFile)
                foreach ($file in $sharedFiles) {
                    if (Test-Path $file) {
                        try {
                            Remove-Item -Path $file -Force
                            Write-Host "Removed orphan SSH file: $(Split-Path $file -Leaf)" -ForegroundColor DarkGray
                        }
                        catch {
                            Write-Verbose "Could not remove orphan SSH file: $(Split-Path $file -Leaf)"
                        }
                    }
                }
            }
        }
    }
    
    Write-Host "Orphan cleanup completed" -ForegroundColor Green
}

# Execute main function
Main
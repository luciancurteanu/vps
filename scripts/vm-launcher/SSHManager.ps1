class SSHManager {
    [string]$SSHDir
    [string]$SharedPrivKey
    [string]$SharedPubKey
    [string]$SharedMarker
    [string]$SSHConfig
    [string]$PrivKeyFile
    [string]$PubKeyFile
    [string]$PubKey
    [object]$VMUtilsInstance

    SSHManager([string]$sshDir, [string]$sharedPrivKey, [string]$sharedPubKey, [string]$sharedMarker, [string]$sshConfig, [object]$vmUtilsInstance) {
        $this.SSHDir = $sshDir
        $this.SharedPrivKey = $sharedPrivKey
        $this.SharedPubKey = $sharedPubKey
        $this.SharedMarker = $sharedMarker
        $this.SSHConfig = $sshConfig
        $this.VMUtilsInstance = $vmUtilsInstance
    }

    [void] EnsureSSHDirectory() {
        Write-Host "Ensuring SSH directory exists: $($this.SSHDir)" -ForegroundColor Cyan
        if (-not (Test-Path -LiteralPath $this.SSHDir)) {
            Write-Host "Creating SSH directory: $($this.SSHDir)" -ForegroundColor Yellow
            try {
                New-Item -ItemType Directory -Path $this.SSHDir -Force | Out-Null
                Write-Host "SSH directory created successfully" -ForegroundColor Green
            } catch {
                Write-Host "Failed to create SSH directory: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "SSH directory already exists" -ForegroundColor Green
        }
    }

    [bool] GenerateSSHKeys([string]$vmName) {
        Write-Host "Starting SSH key generation for VM: $vmName" -ForegroundColor Cyan
        Write-Host "SSH Directory: $($this.SSHDir)" -ForegroundColor Cyan
        Write-Host "Shared Private Key: $($this.SharedPrivKey)" -ForegroundColor Cyan
        Write-Host "Shared Public Key: $($this.SharedPubKey)" -ForegroundColor Cyan
        
        $this.EnsureSSHDirectory()

        # Try ed25519 first, then RSA as fallback
        $keyTypes = @(
            @{ Type = 'ed25519'; Args = @('-t', 'ed25519', '-C', "vps-$vmName") },
            @{ Type = 'rsa'; Args = @('-t', 'rsa', '-b', '4096', '-C', "vps-$vmName") }
        )

        $sshKeygen = Get-Command ssh-keygen.exe -ErrorAction SilentlyContinue
        if (-not $sshKeygen) {
            Write-Host "ssh-keygen.exe not found" -ForegroundColor Red
            return $false
        }

        foreach ($keyType in $keyTypes) {
            try {
                Write-Host "Attempting to generate $($keyType.Type) keypair..." -ForegroundColor Cyan
                
                $keygenArgs = $keyType.Args + @('-f', $this.SharedPrivKey)
                Write-Host "Running: ssh-keygen $($keygenArgs -join ' ')" -ForegroundColor DarkGray
                
                & $sshKeygen @keygenArgs 2>$null 1>$null

                if (Test-Path -LiteralPath $this.SharedPubKey) {
                    Write-Host "Generated shared SSH $($keyType.Type) keypair" -ForegroundColor Green
                    $this.PrivKeyFile = $this.SharedPrivKey
                    $this.PubKeyFile = $this.SharedPubKey
                    $this.PubKey = (Get-Content -Raw -LiteralPath $this.SharedPubKey).Trim()
                    $this.UpdateSharedMarker($vmName, $true)
                    return $true
                } else {
                    Write-Host "Key file not found after generation attempt" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "Failed to generate $($keyType.Type) key: $_" -ForegroundColor Yellow
            }
        }

        Write-Host "Failed to generate SSH keypair" -ForegroundColor Red
        return $false
    }

    [bool] LoadExistingKeys([string]$vmName) {
        # Try to load shared keys first
        if ((Test-Path -LiteralPath $this.SharedPubKey) -and (Test-Path -LiteralPath $this.SharedPrivKey)) {
            try {
                $this.PubKey = (Get-Content -Raw -LiteralPath $this.SharedPubKey).Trim()
                $this.PrivKeyFile = $this.SharedPrivKey
                $this.PubKeyFile = $this.SharedPubKey
                $this.UpdateSharedMarker($vmName, $false)
                return $true
            } catch {
                Write-Verbose "Could not load shared keys: $_"
            }
        }

        # Try to derive public key from private key
        if (-not $this.PubKey -and (Test-Path -LiteralPath $this.SharedPrivKey)) {
            try {
                $derived = (& ssh-keygen -y -f $this.SharedPrivKey 2>$null)
                if ($derived) {
                    $derived | Set-Content -LiteralPath $this.SharedPubKey -Encoding ascii
                    $this.PubKey = $derived.Trim()
                    $this.PrivKeyFile = $this.SharedPrivKey
                    $this.PubKeyFile = $this.SharedPubKey
                    $this.UpdateSharedMarker($vmName, $false)
                    return $true
                }
            } catch {
                Write-Verbose "Could not derive public key: $_"
            }
        }

        return $false
    }

    [void] UpdateSharedMarker([string]$vmName, [bool]$createdByScript) {
        if (-not (Test-Path -LiteralPath $this.SharedMarker)) {
            @(
                '# Shared marker for vps keypair',
                "createdByScript=$createdByScript",
                'vms='
            ) | Set-Content -LiteralPath $this.SharedMarker -Encoding ascii
        }

        $markerContent = Get-Content -LiteralPath $this.SharedMarker -ErrorAction SilentlyContinue
        if (-not ($markerContent | Where-Object { $_ -match '^createdByScript=' })) {
            Add-Content -LiteralPath $this.SharedMarker -Value "createdByScript=$createdByScript" -Encoding ascii
            $markerContent = Get-Content -LiteralPath $this.SharedMarker
        }

        $vmsLineIdx = ($markerContent | Select-String -Pattern '^vms=').LineNumber
        if ($vmsLineIdx) {
            $vms = (($markerContent[$vmsLineIdx-1] -replace '^vms=','').Split(',') | Where-Object { $_ -ne '' })
            if (-not ($vms -contains $vmName)) {
                $vms += $vmName
            }
            $markerContent[$vmsLineIdx-1] = 'vms=' + ($vms -join ',')
            $markerContent | Set-Content -LiteralPath $this.SharedMarker -Encoding ascii
        }
    }

    [void] UpdateSSHConfig([int]$port, [string]$user, [string]$privKeyFile) {
        try {
            # Read existing config if it exists
            $existingConfig = @()
            if (Test-Path -LiteralPath $this.SSHConfig) {
                $existingConfig = Get-Content -Path $this.SSHConfig -ErrorAction SilentlyContinue
            }

            # Build the SSH config as an array of lines
            $configLines = @()

            # Filter out only the specific VM config block (not all localhost entries)
            $skipBlock = $false
            foreach ($line in $existingConfig) {
                # Check if this is the start of a VM config block
                if ($line -match '^Host localhost$') {
                    $skipBlock = $true
                    continue
                }

                # If we're in a VM config block, skip indented lines
                if ($skipBlock -and ($line -match '^\s+')) {
                    continue
                }

                # End of VM config block
                if ($skipBlock -and ($line -notmatch '^\s+') -and ($line -ne '')) {
                    $skipBlock = $false
                }

                # Add non-VM lines
                if (-not $skipBlock) {
                    $configLines += $line
                }
            }

            # Add separator if needed
            if ($configLines.Count -gt 0 -and $configLines[-1] -ne '') {
                $configLines += ""
            }

            # Add VM config lines
            $configLines += "Host localhost"
            $configLines += "    HostName localhost"
            $configLines += "    Port $port"
            $configLines += "    User $user"
            $configLines += "    IdentityFile $privKeyFile"
            $configLines += "    IdentitiesOnly yes"

            # Write using PowerShell's Out-File with proper encoding
            $configLines | Out-File -FilePath $this.SSHConfig -Encoding ASCII -Force
            Write-Host "SSH config updated: you can now use 'ssh localhost'" -ForegroundColor Green
        } catch {
            Write-Host "Could not update SSH config file: $_" -ForegroundColor Yellow
        }
    }

    [void] OpenSSHSession([int]$port, [string]$user, [string]$privKeyFile) {
        # Use the VMUtils instance to clear known hosts
        if ($this.VMUtilsInstance) {
            $this.VMUtilsInstance::ClearKnownHostsPort($port)
        }

        $sshExe = Get-Command ssh.exe -ErrorAction SilentlyContinue
        if (-not $sshExe) {
            Write-Host "SSH executable not found in PATH" -ForegroundColor Yellow
            return
        }

        $sshArgs = @(
            '-o', 'StrictHostKeyChecking=accept-new',
            '-o', 'LogLevel=ERROR',
            '-p', "$port"
        )

        if ($privKeyFile -and (Test-Path -LiteralPath $privKeyFile)) {
            $sshArgs += @('-i', $privKeyFile)
        }

        $sshArgs += @("$user@localhost")

        Write-Host "Opening SSH session... (you can open additional sessions manually)" -ForegroundColor Green
        try {
            # Run SSH asynchronously in a new console window
            Start-Process -FilePath $sshExe.Source -ArgumentList $sshArgs
        } catch {
            Write-Host "Auto SSH session failed, but VM is ready for manual connections" -ForegroundColor Yellow
        }
    }

    [void] CleanupSSHKeys([string]$vmName) {
        if (-not (Test-Path -LiteralPath $this.SharedMarker)) {
            return
        }

        $markerContent = Get-Content -LiteralPath $this.SharedMarker -ErrorAction SilentlyContinue
        $createdByScript = $null -ne ($markerContent | Where-Object { $_ -match '^createdByScript=true' })

        $vmsLineIdx = ($markerContent | Select-String -Pattern '^vms=').LineNumber
        $vms = @()
        if ($vmsLineIdx) {
            $vms = (($markerContent[$vmsLineIdx-1] -replace '^vms=','').Split(',') | Where-Object { $_ -ne '' })
        }

        if ($vms.Count -gt 0) {
            $vms = $vms | Where-Object { $_ -ne $vmName }
        }

        if ($vms.Count -eq 0 -and $createdByScript) {
            Write-Host "No remaining VMs reference shared key; removing shared vps keys" -ForegroundColor Yellow
            foreach ($keyFile in @($this.SharedPrivKey, $this.SharedPubKey)) {
                try {
                    if (Test-Path -LiteralPath $keyFile) {
                        Remove-Item -LiteralPath $keyFile -Force -ErrorAction Stop
                        Write-Host ("Removed key file: {0}" -f $keyFile) -ForegroundColor Cyan
                    }
                } catch { }
            }
            try {
                Remove-Item -LiteralPath $this.SharedMarker -Force -ErrorAction Stop
            } catch { }
        } else {
            if ($vmsLineIdx) {
                $markerContent[$vmsLineIdx-1] = 'vms=' + ($vms -join ',')
                $markerContent | Set-Content -LiteralPath $this.SharedMarker -Encoding ascii
            }
        }
    }
}
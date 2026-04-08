class SSHManager {
    [string]$SSHDir
    [string]$SharedPrivKey
    [string]$SharedPubKey
    [string]$SharedPpkKey
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
        $this.SharedPpkKey = [System.IO.Path]::ChangeExtension($sharedPrivKey, '.ppk')
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
            @{ Type = 'ed25519'; Args = @('-t', 'ed25519', '-C', $vmName) },
            @{ Type = 'rsa'; Args = @('-t', 'rsa', '-b', '4096', '-C', $vmName) }
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
                    $this.GeneratePpkKey()
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

    [void] UpdateSSHConfig([int]$port, [string]$user, [string]$privKeyFile, [string]$vmName) {
        try {
            # Read existing config if it exists
            $existingConfig = @()
            if (Test-Path -LiteralPath $this.SSHConfig) {
                $existingConfig = Get-Content -Path $this.SSHConfig -ErrorAction SilentlyContinue
            }

            # Build the SSH config as an array of lines
            $configLines = @()

            # Use VMName as alias (dots are valid in SSH Host entries)
            $vmAlias = $vmName
            $skipBlock = $false
            foreach ($line in $existingConfig) {
                # Check if this is the start of a VM config block
                if ($line -match "^Host $vmAlias$") {
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
            $configLines += "Host $vmAlias"
            $configLines += "    HostName localhost"
            $configLines += "    Port $port"
            $configLines += "    User $user"
            $configLines += "    IdentityFile $privKeyFile"
            $configLines += "    IdentitiesOnly yes"

            # Write using PowerShell's Out-File with proper encoding
            $configLines | Out-File -FilePath $this.SSHConfig -Encoding ASCII -Force
            Write-Host "SSH config updated: you can now use 'ssh $vmAlias'" -ForegroundColor Green
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
        # Force createdByScript to true to ensure shared keys are treated as created by this tool
        $createdByScript = $true

        $vmsLineIdx = ($markerContent | Select-String -Pattern '^vms=').LineNumber
        $vms = @()
        if ($vmsLineIdx) {
            $vms = (($markerContent[$vmsLineIdx-1] -replace '^vms=','').Split(',') | Where-Object { $_ -ne '' })
        }

        if (@($vms).Count -gt 0) {
            $vms = $vms | Where-Object { $_ -ne $vmName }
        }

        if (@($vms).Count -eq 0 -or $createdByScript) {
            Write-Host "No remaining VMs reference shared key; removing shared keys" -ForegroundColor Yellow
            foreach ($keyFile in @($this.SharedPrivKey, $this.SharedPubKey, $this.SharedPpkKey)) {
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

    [void] GeneratePpkKey() {
        $python = Get-Command python -ErrorAction SilentlyContinue
        if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
        if (-not $python) {
            Write-Host "PPK generation skipped: python not found in PATH" -ForegroundColor Yellow
            return
        }

        $privPath = $this.SharedPrivKey -replace '\\', '/'
        $pubPath  = $this.SharedPubKey  -replace '\\', '/'
        $ppkPath  = $this.SharedPpkKey  -replace '\\', '/'

        $pyScript = @"
import base64, hashlib, hmac as _hmac, struct, sys, warnings
warnings.filterwarnings('ignore')
try:
    from cryptography.hazmat.primitives.serialization import (
        load_ssh_private_key, Encoding, PrivateFormat, PublicFormat, NoEncryption)
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
except ImportError:
    sys.exit('cryptography module not available')

priv_path = r'$privPath'
pub_path  = r'$pubPath'
ppk_path  = r'$ppkPath'

with open(priv_path, 'rb') as f:
    priv_pem = f.read()
with open(pub_path, 'r') as f:
    pub_line = f.read().strip()

key  = load_ssh_private_key(priv_pem, password=None)
if not isinstance(key, Ed25519PrivateKey):
    sys.exit('only Ed25519 keys are supported for PPK generation')
seed = key.private_bytes(Encoding.Raw, PrivateFormat.Raw, NoEncryption())
pub_bytes = key.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)

parts   = pub_line.split(' ', 2)
comment = parts[2] if len(parts) >= 3 else 'imported-key'

def ssh_str(data):
    if isinstance(data, str): data = data.encode()
    return struct.pack('>I', len(data)) + data

pub_blob  = ssh_str('ssh-ed25519') + ssh_str(pub_bytes)
priv_blob = ssh_str(seed)

key_type   = 'ssh-ed25519'
encryption = 'none'

# PPK3 MAC: HMAC-SHA256 with empty key for unencrypted keys
mac_key  = b''
mac_data = (ssh_str(key_type) + ssh_str(encryption) + ssh_str(comment)
            + ssh_str(pub_blob) + ssh_str(priv_blob))
mac = _hmac.new(mac_key, mac_data, hashlib.sha256).hexdigest()

pub_b64  = base64.b64encode(pub_blob).decode()
priv_b64 = base64.b64encode(priv_blob).decode()

def split64(s): return [s[i:i+64] for i in range(0, len(s), 64)]

lines  = ['PuTTY-User-Key-File-3: ' + key_type]
lines += ['Encryption: ' + encryption]
lines += ['Comment: ' + comment]
pub_chunks = split64(pub_b64)
lines += ['Public-Lines: ' + str(len(pub_chunks))]
lines += pub_chunks
priv_chunks = split64(priv_b64)
lines += ['Private-Lines: ' + str(len(priv_chunks))]
lines += priv_chunks
lines += ['Private-MAC: ' + mac]

with open(ppk_path, 'w', newline='\n') as f:
    f.write('\n'.join(lines) + '\n')

print('OK')
"@

        try {
            $result = & $python.Source -c $pyScript 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "PPK generation failed: $($result -join ' ')" -ForegroundColor Yellow
            } else {
                Write-Host "PPK key generated: $($this.SharedPpkKey)" -ForegroundColor Green
            }
        } catch {
            Write-Host "PPK generation error: $_" -ForegroundColor Yellow
        }
    }
}
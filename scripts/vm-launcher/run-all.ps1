<#
One-shot script to create the VM, bootstrap the repository, and run the core
installer as described in README "Fresh Server Bootstrap".

Usage (from repo root):
  cd .\scripts\vm-launcher
  .\run-all.ps1 -VMName "AlmaLinux-9" -UseLocalSSHKey -Recreate -Domain "yourdomain.com" -VaultPassword "vault-pass" -RunInstaller

Parameters:
  -VMName (string) - VM name (default: AlmaLinux-9)
  -UseLocalSSHKey (switch) - use local SSH key for VM access
  -SSHPassword (string) - optional SSH password (used with plink)
  -Recreate (switch) - recreate the VM
  -FullSetup (switch) - pass FullSetup to run-vm.ps1
  -Domain (string) - domain to pass to installer (required if -RunInstaller)
  -VaultPassword (string) - optional vault password to write to ~/.vault_pass
  -VaultMode (persistent|ephemeral) - how to store vault password on VM (default: persistent)
  -RunInstaller (switch) - after bootstrap, run `./vps.sh install core --domain=...`

Notes:
  - For non-interactive password automation, install PuTTY (plink.exe). If
    plink isn't available, the script falls back to OpenSSH `ssh` which will
    prompt for a password if needed.
  - The script assumes the VM exposes SSH on localhost (default VM launcher
    behavior). Adjust $RemoteHost if different.
#>

param(
    [string]$VMName = "AlmaLinux-9",
    [switch]$UseLocalSSHKey,
    [string]$SSHPassword = $null,
    [switch]$Recreate,
    [switch]$FullSetup,
    [string]$Domain = $null,
    [string]$VaultPassword = $null,
    [ValidateSet('persistent','ephemeral')][string]$VaultMode = 'persistent',
    [switch]$RunInstaller
)

Set-StrictMode -Version Latest

$ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
if (-not $ScriptRoot) { $ScriptRoot = Get-Location }

$RunVm = Join-Path $ScriptRoot 'run-vm.ps1'
if (-not (Test-Path $RunVm)) {
    Write-Error "Cannot find run-vm.ps1 in $ScriptRoot. Ensure you run this from scripts\vm-launcher or the repository is present."; exit 1
}

# Embedded defaults (edit these values directly in this file to change defaults)
# WARNING: do not commit sensitive passwords to a public repository.
$DefaultVMName = "AlmaLinux-9"
$DefaultRemoteHost = "192.168.88.8"    # can be an IP if VM exposes SSH on host IP
$DefaultDomain = "goapi.cloud"
$DefaultSSHPassword = "Password@"  # optional; leave empty to prompt
$DefaultVaultPassword = "Password@"         # optional; leave empty to prompt for vault
$DefaultUseLocalSSHKey = $true

# Apply defaults for any parameters not provided on the command line
if (-not $VMName -or $VMName -eq '') { $VMName = $DefaultVMName }
if (-not $Domain -or $Domain -eq '') { $Domain = $DefaultDomain }
if (-not $SSHPassword -and $DefaultSSHPassword) { $SSHPassword = $DefaultSSHPassword }
if (-not $VaultPassword -and $DefaultVaultPassword) { $VaultPassword = $DefaultVaultPassword }

# Remote host (user@host will be admin@<RemoteHost>) - default set above
$RemoteHost = $DefaultRemoteHost
if ($DefaultUseLocalSSHKey) { $UseLocalSSHKey = $true }

# Build run-vm params
$runParams = @{ VMName = $VMName }
if ($UseLocalSSHKey) { $runParams.UseLocalSSHKey = $true }
if ($Recreate) { $runParams.Recreate = $true }
if ($FullSetup) { $runParams.FullSetup = $true }
if ($SSHPassword) { $runParams.SSHPassword = $SSHPassword }

Write-Host "==> Creating VM (this may take a few minutes)..." -ForegroundColor Cyan
& $RunVm @runParams
if ($LASTEXITCODE -ne 0) { Write-Error "VM creation failed (exit $LASTEXITCODE)"; exit $LASTEXITCODE }

if ($FullSetup) {
    Write-Host "FullSetup requested; run-vm should have performed bootstrap. Exiting." -ForegroundColor Green
    exit 0
}

# Wait for SSH on localhost:22 to be ready
function Wait-ForSsh($targetHost='localhost', $port=22, $timeoutSec=300) {
    $start = Get-Date
    while ((Get-Date) - $start -lt [TimeSpan]::FromSeconds($timeoutSec)) {
        try {
            $res = Test-NetConnection -ComputerName $targetHost -Port $port -WarningAction SilentlyContinue
            if ($res.TcpTestSucceeded) { Write-Host "SSH is reachable on ${targetHost}:${port}" -ForegroundColor Green; return $true }
        } catch { }
        Write-Host "Waiting for SSH on ${targetHost}:${port}..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
    return $false
}

if (-not (Wait-ForSsh -targetHost $RemoteHost -port 22 -timeoutSec 300)) { Write-Error "SSH did not become available on $RemoteHost:22 within timeout"; exit 2 }

# Build bootstrap shell script to run on the VM
function Get-BootstrapScript {
    @'
set -e
echo "Installing curl (if missing)..."
sudo dnf install -y curl || true

echo "Running repository bootstrap script..."
curl -fsSL https://raw.githubusercontent.com/luciancurteanu/vps/main/bootstrap.sh | bash

cd ~/vps || exit 0

# Copy example configs if missing
[ -f inventory/group_vars/all.yml ] || cp inventory/group_vars/all.yml.example inventory/group_vars/all.yml || true
[ -f inventory/hosts.yml ] || cp inventory/hosts.yml.example inventory/hosts.yml || true
[ -f vars/secrets.yml ] || cp vars/secrets.yml.example vars/secrets.yml || true

echo "Bootstrap completed. Repository available at ~/vps"
'@
}

$bootstrap = Get-BootstrapScript

# Helper: invoke remote script via plink or ssh
function Invoke-Remote($scriptText) {
    $plink = Get-Command plink -ErrorAction SilentlyContinue
    $localKeyPath = Join-Path $env:USERPROFILE ".ssh\vps"
    $userAtHost = "admin@$RemoteHost"
    # If key-based auth requested and local private key exists, prefer OpenSSH with -i
    if ($UseLocalSSHKey -and (Test-Path $localKeyPath)) {
        Write-Host "Using OpenSSH with key $localKeyPath to run script on admin@$RemoteHost..." -ForegroundColor Cyan
        try {
            $out = $scriptText | & ssh -i $localKeyPath -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR -p 22 $userAtHost bash -s 2>&1
            $exit = $LASTEXITCODE
            Write-Host $out
            if ($exit -ne 0) { throw "Remote command failed (ssh) with exit $exit`n$out" }
            return
        } catch {
            Write-Warning "Key-based OpenSSH invocation failed, falling back to plink/ssh: $_"
        }
    }
    if ($plink) {
        Write-Host "Using plink to run bootstrap script on admin@$RemoteHost..." -ForegroundColor Cyan
        # Try to fetch host key fingerprint (ssh-keyscan + ssh-keygen) and pass to plink via -hostkey
        $hostkey = $null
        try {
            $raw = & ssh-keyscan -p 22 $RemoteHost 2>$null
            if ($raw) {
                $first = ($raw -split "`n" | Where-Object { $_ -ne '' })[0]
                $parts = $first -split ' '
                $kt = $parts[1]
                $keyscanBitsAndFp = (& ssh-keyscan -p 22 $RemoteHost 2>$null | ssh-keygen -lf - 2>$null).Trim()
                # keyscanBitsAndFp looks like: "256 SHA256:... (ED25519)"
                if ($keyscanBitsAndFp -match '^(\d+)\s+(SHA256:[A-Za-z0-9+/=]+)') {
                    $bits = $matches[1]
                    $fp = $matches[2]
                    $hostkey = "$kt $bits $fp"
                }
            }
        } catch { }

        if ($SSHPassword) { $args = @('-ssh',$userAtHost,'-batch','-pw',$SSHPassword) } else { $args = @('-ssh',$userAtHost,'-batch') }
        if ($hostkey) { $args += @('-hostkey',$hostkey) }
        try {
            # Pipe the script text into plink's stdin (more compatible across PS versions)
            $out = $scriptText | & $plink @args 2>&1
            $exit = $LASTEXITCODE
            Write-Host $out
            if ($exit -ne 0) { throw "Remote command failed (plink) with exit $exit`n$out" }
        } catch {
            throw $_
        }
    } else {
        Write-Host "Plink not found; falling back to OpenSSH client (ssh)." -ForegroundColor Yellow
        if ($SSHPassword) { Write-Warning "Password provided but plink is not installed; OpenSSH will likely prompt for a password interactively." }
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'ssh'
        $psi.Arguments = "admin@$RemoteHost bash -s"
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $p = [System.Diagnostics.Process]::Start($psi)
        $p.StandardInput.Write($scriptText)
        $p.StandardInput.Close()
        $out = $p.StandardOutput.ReadToEnd()
        $err = $p.StandardError.ReadToEnd()
        $p.WaitForExit()
        Write-Host $out
        if ($p.ExitCode -ne 0) { Write-Error $err; throw "Remote command failed (ssh) with exit $($p.ExitCode)" }
    }
}

Write-Host "==> Running bootstrap on VM..." -ForegroundColor Cyan
Invoke-Remote -scriptText $bootstrap

# Populate inventory and vault secrets on the VM so installer can run non-interactively
Write-Host "==> Populating inventory and secrets on VM..." -ForegroundColor Cyan
$populateCmd = @'
mkdir -p ~/vps/inventory ~/vps/vars ~/vps/inventory/group_vars
cat > ~/vps/inventory/hosts.yml <<'YML'
all:
    vars:
        ansible_connection: ssh
        ansible_user: "{{ admin_user }}"
        ansible_port: "{{ ssh_port }}"

    children:
        primary:
            hosts:
                __DOMAIN__:
                    ansible_host: __REMOTE__
YML

cat > ~/vps/vars/secrets.yml <<'YML'
vault_admin_password: "__VAULT__"
vault_db_webclient_password: "__VAULT__"
vault_db_remote_password: "__VAULT__"
vault_mail_db_password: "__VAULT__"
vault_roundcube_db_password: "__VAULT__"
vault_admin_ssh_public_key: ""
YML
'@

# Replace placeholders with actual values (safe from parser-time interpolation)
$populateCmd = $populateCmd -replace '__DOMAIN__', $Domain -replace '__REMOTE__', $RemoteHost -replace '__VAULT__', ($DefaultVaultPassword -replace '"','\"')
Invoke-Remote -scriptText $populateCmd

# Optional: write vault password and encrypt secrets on VM
if ($VaultPassword) {
    $vaultCmd = @"
echo -n '$VaultPassword' > ~/.vault_pass
chmod 600 ~/.vault_pass
cd ~/vps || exit 0
if [ -f vars/secrets.yml ]; then
  ansible-vault encrypt vars/secrets.yml --vault-password-file=~/.vault_pass || true
fi
"@
    Write-Host "==> Writing vault password and encrypting vars/secrets.yml on VM..." -ForegroundColor Cyan
    Invoke-Remote -scriptText $vaultCmd
}

# Run installer on VM if requested
if ($RunInstaller) {
    if (-not $Domain) { Write-Error "-Domain is required when using -RunInstaller"; exit 3 }
    $installCmd = @"
cd ~/vps || exit 0
echo "Running installer: ./vps.sh install core --domain=$Domain"
if [ -f ~/.vault_pass ]; then
  ./vps.sh install core --domain=$Domain --vault-password-file=~/.vault_pass --ask-pass || exit $?
else
  ./vps.sh install core --domain=$Domain --ask-vault-pass --ask-pass || exit $?
fi
"@
    Write-Host "==> Running core installer on VM (this may take many minutes)..." -ForegroundColor Cyan
    Invoke-Remote -scriptText $installCmd
}

Write-Host "All done." -ForegroundColor Green

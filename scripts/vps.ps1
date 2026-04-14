<#
.SYNOPSIS
PowerShell wrapper for vps.sh. Runs commands on the VPS server and
auto-imports the local CA certificate into the Windows trust store for
.test dev domains so HTTPS is green immediately.

All SSH connection details are read dynamically from:
  - ansible.cfg          : private_key_file, remote_user
  - inventory/hosts.yml  : ansible_host (server IP)
  - group_vars/all.yml   : admin_user, ssh_port

Overrides (all optional, auto-detected from config):
  -SSHHost   Force a specific IP/hostname
  -SSHUser   Force a specific SSH user
  -SSHKey    Force a specific private key path
  -VpsDir    Remote vps directory (default: /home/<user>/vps)

.EXAMPLE
  .\scripts\vps.ps1 install core --domain=lucasvps.test
  .\scripts\vps.ps1 create host --domain=luciancurteanu.test
  .\scripts\vps.ps1 install ssl  --domain=lucasvps.test
  .\scripts\vps.ps1 remove host  --domain=luciancurteanu.test
#>

[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$SSHHost = '',
    [string]$SSHUser = '',
    [string]$SSHKey  = '',
    [string]$VpsDir  = '',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$VpsArgs
)

# --- helpers -----------------------------------------------------------------
function Write-Step { param($msg) Write-Host "  >> $msg" -ForegroundColor Cyan }
function Write-Ok   { param($msg) Write-Host "  OK $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  !! $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "  XX $msg" -ForegroundColor Red }
function Invoke-Tilde { param($p) $p -replace '^~', $env:USERPROFILE }

# --- project root (parent of scripts/) --------------------------------------
$ProjectRoot = Split-Path $PSScriptRoot -Parent

# --- parse ansible.cfg -------------------------------------------------------
function Read-AnsibleCfg {
    param([string]$Root)
    $cfg = @{}
    $cfgFile = Join-Path $Root 'ansible.cfg'
    if (-not (Test-Path $cfgFile)) { return $cfg }
    $inDefaults = $false
    foreach ($line in Get-Content $cfgFile) {
        if ($line -match '^\[defaults\]') { $inDefaults = $true;  continue }
        if ($line -match '^\[')           { $inDefaults = $false; continue }
        if ($inDefaults -and $line -match '^\s*(\w+)\s*=\s*(.+)$') {
            $cfg[$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }
    return $cfg
}

# --- first ansible_host from inventory/hosts.yml ----------------------------
function Read-InventoryHost {
    param([string]$Root)
    $hostsFile = Join-Path (Join-Path $Root 'inventory') 'hosts.yml'
    if (-not (Test-Path $hostsFile)) { return $null }
    foreach ($line in Get-Content $hostsFile) {
        if ($line -match 'ansible_host\s*:\s*([0-9a-zA-Z._-]+)') { return $Matches[1] }
    }
    return $null
}

# --- read a scalar from group_vars/all.yml ----------------------------------
function Read-GroupVar {
    param([string]$Root, [string]$Key)
    $allFile = Join-Path (Join-Path (Join-Path $Root 'inventory') 'group_vars') 'all.yml'
    if (-not (Test-Path $allFile)) { return $null }
    foreach ($line in Get-Content $allFile) {
        if ($line -match "^\s*${Key}\s*:\s*[`"']?([^`"'#{}\s]+)[`"']?") { return $Matches[1] }
    }
    return $null
}

# --- auto-detect connection settings ----------------------------------------
$cfg = Read-AnsibleCfg $ProjectRoot

if (-not $SSHHost) {
    $SSHHost = Read-InventoryHost $ProjectRoot
    if (-not $SSHHost) { Write-Fail "Cannot detect SSH host from inventory/hosts.yml"; exit 1 }
}

if (-not $SSHUser) {
    $adminUser = Read-GroupVar $ProjectRoot 'admin_user'
    $SSHUser = if ($adminUser -and $adminUser -notmatch '\{\{') { $adminUser } else { 'admin' }
}

if (-not $SSHKey) {
    $hostKey = Join-Path (Join-Path $env:USERPROFILE '.ssh') 'lucasvps_test'
    $cfgKey  = if ($cfg['private_key_file']) { Invoke-Tilde $cfg['private_key_file'] } else { $null }
    if     (Test-Path $hostKey)               { $SSHKey = $hostKey }
    elseif ($cfgKey -and (Test-Path $cfgKey)) { $SSHKey = $cfgKey  }
    else {
        $found = Get-ChildItem "$env:USERPROFILE\.ssh\" -File -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -notmatch '\.(pub|known_hosts|config)$' } |
                 Select-Object -First 1
        $SSHKey = if ($found) { $found.FullName } else { "$env:USERPROFILE\.ssh\id_rsa" }
    }
}
$SSHKey = Invoke-Tilde $SSHKey

$SSHPort = Read-GroupVar $ProjectRoot 'ssh_port'
if (-not $SSHPort -or $SSHPort -notmatch '^\d+$') { $SSHPort = '22' }

if (-not $VpsDir) { $VpsDir = "/home/${SSHUser}/vps" }

# --- extract --domain= from args --------------------------------------------
$Domain = $null
foreach ($arg in $VpsArgs) {
    if ($arg -match '^--domain=(.+)$') { $Domain = $Matches[1]; break }
}
# --- build command string ----------------------------------------------------
$ArgsStr   = ($VpsArgs | ForEach-Object { "'$_'" }) -join ' '
$RemoteCmd = "cd $VpsDir && git pull --quiet && bash vps.sh $ArgsStr"

# --- banner ------------------------------------------------------------------
Write-Host ""
Write-Host "=====================================================" -ForegroundColor DarkGray
Write-Host " VPS : ${SSHUser}@${SSHHost}:${SSHPort}" -ForegroundColor White
Write-Host " KEY : $SSHKey" -ForegroundColor DarkGray
Write-Host " CMD : vps.sh $ArgsStr" -ForegroundColor White
Write-Host "=====================================================" -ForegroundColor DarkGray
Write-Host ""

# --- run vps.sh over SSH -----------------------------------------------------
$sshPortArgs = if ($SSHPort -ne '22') { @('-p', $SSHPort) } else { @() }
& ssh -o StrictHostKeyChecking=no -i $SSHKey @sshPortArgs "${SSHUser}@${SSHHost}" $RemoteCmd
$ExitCode = $LASTEXITCODE

if ($ExitCode -ne 0) {
    Write-Fail "vps.sh exited with code $ExitCode"
    exit $ExitCode
}

Write-Host ""
Write-Ok "Remote command finished successfully."

# --- sync ALL dev CA certs from the server -----------------------------------
# Discovers every *-local-ca.crt in the server's temp/ folder and ensures the
# Windows trust store is up to date (removes stale, imports if thumbprint changed).
function Sync-AllDevCerts {
    param(
        [string]$SSHUser, [string]$SSHHost, [string]$SSHKey,
        [string[]]$SshPortArgs, [string[]]$ScpPortArgs,
        [string]$VpsDir, [string]$LocalTemp
    )

    # List CA cert filenames on the server
    $remoteList = & ssh -o StrictHostKeyChecking=no -i $SSHKey @SshPortArgs `
        "${SSHUser}@${SSHHost}" "ls ${VpsDir}/temp/*-local-ca.crt 2>/dev/null" 2>$null
    if (-not $remoteList) { return }

    $null = New-Item -ItemType Directory -Force $LocalTemp

    $anyChanged = $false

    foreach ($remotePath in $remoteList) {
        $remotePath = $remotePath.Trim()
        $certName   = Split-Path $remotePath -Leaf            # e.g. lucasvps.test-local-ca.crt
        $domain     = $certName -replace '-local-ca\.crt$','' # e.g. lucasvps.test
        $localFile  = Join-Path $LocalTemp $certName

        # Download cert
        & scp -o StrictHostKeyChecking=no -i $SSHKey @ScpPortArgs `
            "${SSHUser}@${SSHHost}:${remotePath}" $localFile 2>$null

        if (-not (Test-Path $localFile)) { continue }

        try {
            $newCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $localFile

            # Check CurrentUser store — skip import if thumbprint already present
            $cuStore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
                'Root', [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
            $cuStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

            $alreadyTrusted = $cuStore.Certificates | Where-Object { $_.Thumbprint -eq $newCert.Thumbprint }
            if ($alreadyTrusted) {
                $cuStore.Close()
                $newCert.Dispose()
                continue   # cert is already correct — nothing to do
            }

            # Remove stale certs for this domain (wrong thumbprint)
            $stale = @($cuStore.Certificates | Where-Object {
                $_.Subject -eq $newCert.Subject -and $_.Thumbprint -ne $newCert.Thumbprint
            })
            foreach ($old in $stale) {
                $cuStore.Remove($old)
                Write-Warn "Removed stale CA cert for ${domain}: $($old.Thumbprint)"
            }
            $cuStore.Close()

            # Also clean LocalMachine store (stale only)
            try {
                $lmStore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
                    'Root', [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
                $lmStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
                $staleLocal = @($lmStore.Certificates | Where-Object {
                    $_.Subject -eq $newCert.Subject -and $_.Thumbprint -ne $newCert.Thumbprint
                })
                foreach ($old in $staleLocal) { $lmStore.Remove($old) }
                $lmStore.Close()
            } catch { }   # needs elevation — best-effort

            $newCert.Dispose()

            # Import fresh cert into CurrentUser\Root
            $null = certutil -addstore -user Root $localFile 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "CA cert updated for ${domain} (Chrome/Edge will show green HTTPS)"
                $anyChanged = $true
            } else {
                Write-Warn "certutil failed for ${domain} - trying elevated import..."
                $abs = (Resolve-Path $localFile).Path
                $cmd = "Import-Certificate -FilePath `"$abs`" -CertStoreLocation Cert:\LocalMachine\Root | Out-Null"
                Start-Process powershell -Verb RunAs -Wait -ArgumentList "-NoProfile", "-Command", $cmd
                if ($LASTEXITCODE -eq 0) {
                    Write-Ok "CA cert updated for ${domain} (LocalMachine, elevated)"
                    $anyChanged = $true
                } else {
                    Write-Fail "Auto-import failed for ${domain}. Import manually:"
                    Write-Host "  File   : $abs" -ForegroundColor Yellow
                    Write-Host "  Action : Double-click > Install Certificate > Local Machine > Trusted Root CA"
                }
            }
        } catch {
            Write-Warn "Could not process cert for ${domain}: $_"
        }
    }

    if (-not $anyChanged) {
        Write-Ok "All dev CA certs are already up to date."
    }
}

Write-Host ""
Write-Step "Syncing dev CA certs from server..."
$scpPortArgs = if ($SSHPort -ne '22') { @('-P', $SSHPort) } else { @() }
Sync-AllDevCerts `
    -SSHUser $SSHUser -SSHHost $SSHHost -SSHKey $SSHKey `
    -SshPortArgs $sshPortArgs -ScpPortArgs $scpPortArgs `
    -VpsDir $VpsDir -LocalTemp (Join-Path $ProjectRoot 'temp')

Write-Host ""
exit 0
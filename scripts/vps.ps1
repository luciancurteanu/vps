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
$IsDevDomain = $Domain -and ($Domain -split '\.')[-1] -eq 'test'

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

# --- auto-import CA cert for .test domains -----------------------------------
if ($IsDevDomain) {
    $LocalTemp  = Join-Path $ProjectRoot 'temp'
    $null       = New-Item -ItemType Directory -Force $LocalTemp
    $CertFile   = Join-Path $LocalTemp "${Domain}-local-ca.crt"
    $RemoteCert = "${VpsDir}/temp/${Domain}-local-ca.crt"

    Write-Host ""
    Write-Step "Dev domain - fetching CA cert for $Domain..."

    $scpPortArgs = if ($SSHPort -ne '22') { @('-P', $SSHPort) } else { @() }
    & scp -o StrictHostKeyChecking=no -i $SSHKey @scpPortArgs "${SSHUser}@${SSHHost}:${RemoteCert}" $CertFile 2>$null

    if (-not (Test-Path $CertFile)) {
        Write-Warn "CA cert not found on server - skipping auto-import."
        Write-Warn "Run ssl.yml first, then re-run this script."
    } else {
        # Try CurrentUser (no elevation, works for Chrome/Edge)
        $null = certutil -addstore -user Root $CertFile 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "CA cert imported into CurrentUser\Root."
            Write-Ok "Chrome/Edge will show green HTTPS for https://${Domain} immediately."
            Write-Warn "Firefox: Settings > Privacy & Security > View Certificates > Authorities > Import"
            Write-Warn "  File: $CertFile"
        } else {
            Write-Warn "certutil failed - trying elevated LocalMachine import..."
            $AbsoluteCert = (Resolve-Path $CertFile).Path
            $importScript = "Import-Certificate -FilePath `"$AbsoluteCert`" -CertStoreLocation Cert:\LocalMachine\Root | Out-Null"
            Start-Process powershell -Verb RunAs -Wait -ArgumentList "-NoProfile", "-Command", $importScript
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "CA cert imported into LocalMachine\Root (elevated)."
            } else {
                Write-Fail "Auto-import failed. Import manually:"
                Write-Host "  File   : $AbsoluteCert" -ForegroundColor Yellow
                Write-Host "  Action : Double-click > Install Certificate > Local Machine > Trusted Root CA"
            }
        }
    }
}

Write-Host ""
exit 0
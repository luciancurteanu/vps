<#
.SYNOPSIS
Runs Molecule tests for a specified Ansible role via SSH to the VM.

.PARAMETER Role
Name of the role (e.g., php, nginx, common, security).

.PARAMETER Action
Molecule action to perform: test, converge, verify, destroy, create, lint (default: test).

.PARAMETER SSHHost
SSH host to connect to (default: localhost - configured in ~/.ssh/config).

.EXAMPLE
.\scripts\run-test.ps1 -Role common
.\scripts\run-test.ps1 -Role nginx -Action converge
.\scripts\run-test.ps1 -Role security -Action verify -SSHHost 192.168.88.8
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Role,
    [string]$Action = 'test',
    [string]$SSHHost = 'localhost'
)

Write-Host "Running Molecule $Action for role '$Role' on $SSHHost..." -ForegroundColor Cyan

# Execute run-test.sh on the remote VM
$remoteCmd = "cd ~/vps && bash scripts/run-test.sh $Role $Action"
$sshArgs = @($SSHHost, $remoteCmd)

& ssh @sshArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Molecule $Action failed for role: $Role (exit code $LASTEXITCODE)" -ErrorAction Stop
}

Write-Host "Molecule $Action completed successfully for role: $Role" -ForegroundColor Green
exit 0

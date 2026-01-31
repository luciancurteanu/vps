<#
.SYNOPSIS
Runs Molecule tests for a specified Ansible role on Windows PowerShell.

.PARAMETER Role
Name of the role (e.g., php, nginx).
.PARAMETER Action
Molecule action to perform: test, converge, verify, lint (default: test).
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Role,
    [string]$Action = 'test'
)

# Determine project root (one level up from this script)
$projectRoot = Split-Path -Parent $PSScriptRoot
$roleDir     = Join-Path $projectRoot "roles\$Role"

if (-not (Test-Path $roleDir)) {
    Write-Error "Role directory not found: $roleDir"
    exit 1
}

# Change to role folder and run Molecule
Push-Location $roleDir
try {
    Write-Host "Running 'molecule $Action' in $roleDir..."
    $exitCode = & molecule $Action
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Molecule $Action failed for role: $Role (exit code $LASTEXITCODE)."
    }
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}

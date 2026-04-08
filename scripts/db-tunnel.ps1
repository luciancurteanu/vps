#!/usr/bin/env pwsh
# DB Tunnel — Opens an SSH tunnel to the remote MariaDB server
# Usage: .\scripts\db-tunnel.ps1 [-Host 192.168.88.8] [-LocalPort 3307]
# Then connect your DB client to 127.0.0.1:<LocalPort>

param(
    [string]$RemoteHost   = "192.168.88.8",
    [string]$SSHUser      = "admin",
    [string]$SSHKey       = "$env:USERPROFILE\.ssh\lucasvps-test",
    [int]   $LocalPort    = 3307,
    [int]   $RemotePort   = 3307,
    [int]   $SSHPort      = 22
)

Write-Host "Starting SSH tunnel: localhost:$LocalPort -> ${RemoteHost}:$RemotePort"
Write-Host "Connect your DB client to: 127.0.0.1:$LocalPort"
Write-Host "Press Ctrl+C to close the tunnel."
Write-Host ""

ssh -N -L "${LocalPort}:127.0.0.1:${RemotePort}" `
    -i $SSHKey `
    -p $SSHPort `
    -o StrictHostKeyChecking=no `
    -o ExitOnForwardFailure=yes `
    -o ServerAliveInterval=30 `
    "${SSHUser}@${RemoteHost}"

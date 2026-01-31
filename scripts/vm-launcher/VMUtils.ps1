class VMUtils {
    static [string]$ScriptDir
    static [string]$LogFile

    static [void] Initialize([string]$scriptPath) {
        [VMUtils]::ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($scriptPath) { Split-Path -Parent $scriptPath } else { (Get-Location).Path }
    }

    static [void] StartLogging([string]$logFileName) {
        $logsDir = Join-Path ([VMUtils]::ScriptDir) "logs"
        if (-not (Test-Path $logsDir)) {
            New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
        }
        [VMUtils]::LogFile = Join-Path $logsDir $logFileName
        try {
            Start-Transcript -Path ([VMUtils]::LogFile) -Force | Out-Null
        } catch {
            Write-Warning "Could not start transcript logging: $_"
        }
    }

    static [void] StopLogging() {
        try {
            Stop-Transcript | Out-Null
        } catch {
            # Ignore errors during cleanup
        }

        # Keep log files for debugging (don't auto-delete)
        # Log cleanup is handled by CleanupOrphanFiles
    }

    static [void] EnsureTool([string]$toolName, [string]$chocoPkg, [string]$defaultPath, [string]$altPath) {
        # Check if tool is already in PATH
        if (Get-Command $toolName -ErrorAction SilentlyContinue) {
            Write-Host "$toolName found in PATH" -ForegroundColor Green
            return
        }

        # Check alternative locations
        $candidates = @()
        if ($defaultPath) { $candidates += Join-Path $defaultPath $toolName }
        if ($altPath) { $candidates += Join-Path $altPath $toolName }

        foreach ($path in $candidates) {
            if (Test-Path $path) {
                $dir = Split-Path -Parent $path
                if (-not (($env:Path).Split(';') -contains $dir)) {
                    $env:Path += ";$dir"
                }
                Write-Host "$toolName found at $path" -ForegroundColor Green
                return
            }
        }

        # Try to install via Chocolatey
        if ($chocoPkg) {
            Write-Host "$toolName not found. Attempting choco install $chocoPkg..." -ForegroundColor Yellow

            if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
                throw "Chocolatey missing. Please install it or install $toolName manually."
            }

            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if (-not $isAdmin) {
                throw "Administrator required to install packages via Chocolatey. Restart PowerShell as Administrator."
            }

            & choco install $chocoPkg -y

            # Refresh PATH to include newly installed tools (only if not already up-to-date)
            $refreshedPath = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            if ($env:Path -ne $refreshedPath) {
                $env:Path = $refreshedPath
            }

            if (Get-Command $toolName -ErrorAction SilentlyContinue) {
                Write-Host "$toolName installed" -ForegroundColor Green
                return
            }
        }

        throw "Could not find or install $toolName. Please install it and ensure it's in PATH."
    }

    static [void] EnsureWSL() {
        # Check if WSL is installed and has distributions
        $wslInstalled = $false
        try {
            $wslOutput = & wsl --list --quiet 2>$null
            if ($LASTEXITCODE -eq 0 -and $wslOutput) {
                # More robust filtering to handle various output formats
                $distros = @()
                foreach ($line in $wslOutput) {
                    $trimmed = $line.Trim()
                    # Remove null characters and check if anything remains
                    $cleaned = $trimmed -replace "`0", ""
                    if ($cleaned -and $cleaned.Length -gt 0 -and -not [string]::IsNullOrWhiteSpace($cleaned)) {
                        $distros += $cleaned
                    }
                }
                if ($distros.Count -gt 0) {
                    $wslInstalled = $true
                    Write-Host "WSL found with distributions: $($distros -join ', ')" -ForegroundColor Green
                }
            }
        } catch { }

        if (-not $wslInstalled) {
            Write-Host "WSL not found or no distributions installed. Installing WSL with AlmaLinux 9..." -ForegroundColor Yellow

            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if (-not $isAdmin) {
                throw "Administrator privileges required to install WSL. Restart PowerShell as Administrator."
            }

            # Install WSL and AlmaLinux 9 (CentOS-compatible)
            & wsl --install -d AlmaLinux-9

            if ($LASTEXITCODE -eq 0) {
                Write-Host "WSL installed successfully. Please reboot your system and rerun this script to continue." -ForegroundColor Yellow
                throw "Reboot required after WSL installation. Please reboot and rerun the script."
            } else {
                throw "Failed to install WSL. Please install it manually with 'wsl --install -d Ubuntu' and reboot."
            }
        }
    }

    static [string] FindMkIsoFS() {
        # Try PATH first
        $mkisofs = Get-Command mkisofs.exe -ErrorAction SilentlyContinue
        if ($mkisofs) { return $mkisofs.Source }

        $geniso = Get-Command genisoimage.exe -ErrorAction SilentlyContinue
        if ($geniso) { return $geniso.Source }

        # Try scripts\Binary folder
        $binaryPath = Join-Path ([VMUtils]::ScriptDir) 'Binary'
        $mkisofs = (Get-ChildItem -Path $binaryPath -Recurse -Filter 'mkisofs.exe' -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
        if ($mkisofs) { return $mkisofs }

        # Try Chocolatey packages
        try {
            [VMUtils]::EnsureTool('mkisofs.exe', 'cdrtools', 'C:\Program Files\cdrtools', 'C:\ProgramData\chocolatey\lib\cdrtools\tools')
            $mkisofs = Get-Command mkisofs.exe -ErrorAction SilentlyContinue
            if ($mkisofs) { return $mkisofs.Source }
        } catch { }

        try {
            [VMUtils]::EnsureTool('genisoimage.exe', 'genisoimage', 'C:\Program Files\genisoimage', 'C:\ProgramData\chocolatey\lib\genisoimage\tools')
            $geniso = Get-Command genisoimage.exe -ErrorAction SilentlyContinue
            if ($geniso) { return $geniso.Source }
        } catch { }

        # Last resort: download
        $mkisofsZipUrl = 'https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/mkisofs-md5/mkisofs-md5-2.01-Binary.zip'
        $mkisofsZip = Join-Path $env:TEMP 'mkisofs-md5-2.01-Binary.zip'

        Write-Host "mkisofs.exe not found; attempting to download and extract..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $mkisofsZipUrl -OutFile $mkisofsZip -UseBasicParsing -ErrorAction Stop
            Expand-Archive -Path $mkisofsZip -DestinationPath ([VMUtils]::ScriptDir) -Force
            Remove-Item $mkisofsZip -Force
            $mkisofs = (Get-ChildItem -Path $binaryPath -Recurse -Filter 'mkisofs.exe' -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
            if ($mkisofs) { return $mkisofs }
        } catch {
            Write-Host "Automatic mkisofs download failed. Please add mkisofs.exe under scripts\Binary or install it manually." -ForegroundColor Red
            throw
        }

        throw "Could not find or install mkisofs.exe"
    }

    static [void] ClearKnownHostsPort([int]$port) {
        $kh = Join-Path $env:USERPROFILE '.ssh\known_hosts'
        if (-not (Test-Path -LiteralPath $kh)) { return }

        try {
            # Read the current content with UTF-8 encoding (SSH standard)
            $content = Get-Content -Path $kh -Encoding UTF8 -ErrorAction SilentlyContinue

            if ($content) {
                # Filter out lines that contain [localhost]:port followed by key type
                $filteredContent = $content | Where-Object {
                    $_ -notmatch "^\[localhost\]:$port\s+" -and $_ -notmatch "^localhost\s+"
                }

                # Only write back if content changed
                if ($filteredContent.Count -ne $content.Count) {
                    # Use .NET method for reliable file writing with UTF-8 encoding
                    if ($filteredContent.Count -eq 0) {
                        [System.IO.File]::WriteAllText($kh, "", [System.Text.Encoding]::UTF8)
                    } else {
                        [System.IO.File]::WriteAllLines($kh, $filteredContent, [System.Text.Encoding]::UTF8)
                    }
                    Write-Host "Cleared known_hosts entries for localhost (removed $($content.Count - $filteredContent.Count) entries)" -ForegroundColor DarkYellow
                } else {
                    Write-Host "No localhost entries found in known_hosts to clear" -ForegroundColor DarkGray
                }
            }
        } catch {
            Write-Verbose "Could not clear known_hosts entries for localhost"
        }
    }

    static [void] ClearKnownHostsHost([string]$hostname) {
        $kh = Join-Path $env:USERPROFILE '.ssh\known_hosts'
        if (-not (Test-Path -LiteralPath $kh)) { return }

        try {
            # Read the current content with UTF-8 encoding (SSH standard)
            $content = Get-Content -Path $kh -Encoding UTF8 -ErrorAction SilentlyContinue

            if ($content) {
                # Filter out lines that contain the hostname
                $escapedHostname = [regex]::Escape($hostname)
                $filteredContent = $content | Where-Object {
                    $_ -notmatch "^$escapedHostname\s+"
                }

                # Only write back if content changed
                if ($filteredContent.Count -ne $content.Count) {
                    # Use .NET method for reliable file writing with UTF-8 encoding
                    if ($filteredContent.Count -eq 0) {
                        [System.IO.File]::WriteAllText($kh, "", [System.Text.Encoding]::UTF8)
                    } else {
                        [System.IO.File]::WriteAllLines($kh, $filteredContent, [System.Text.Encoding]::UTF8)
                    }
                    Write-Host "Cleared known_hosts entries for $hostname (removed $($content.Count - $filteredContent.Count) entries)" -ForegroundColor DarkYellow
                }
            }
        } catch {
            Write-Verbose "Could not clear known_hosts entries for $hostname"
        }
    }

    static [void] ClearSSHConfig() {
        $sshConfig = Join-Path $env:USERPROFILE '.ssh\config'
        if (Test-Path -LiteralPath $sshConfig) {
            try {
                $existingConfig = Get-Content -Path $sshConfig -ErrorAction SilentlyContinue

                if ($existingConfig) {
                    # Check if file contains any localhost entries
                    $hasLocalhost = $existingConfig | Where-Object { $_ -match '(?i)localhost' }

                    if ($hasLocalhost) {
                        # If file contains localhost entries, clear it completely since these are VM entries
                        Clear-Content -Path $sshConfig -ErrorAction SilentlyContinue
                        Write-Host "Cleared VM SSH config entries (preserved user configurations)" -ForegroundColor DarkYellow
                    } else {
                        Write-Host "No VM SSH config entries found to clear" -ForegroundColor DarkGray
                    }
                }
            } catch {
                Write-Verbose "Could not clear SSH config file"
            }
        }
    }

    static [bool] TestSSHConnection([string]$hostname, [int]$port, [int]$timeoutSeconds = 180) {
        $deadline = (Get-Date).AddSeconds($timeoutSeconds)
        while ((Get-Date) -lt $deadline) {
            try {
                # Suppress verbose output from Test-NetConnection
                $result = Test-NetConnection -ComputerName $hostname -Port $port -Verbose:$false -WarningAction SilentlyContinue
                if ($result.TcpTestSucceeded) {
                    return $true
                }
            } catch { }
            Start-Sleep 2
        }
        return $false
    }
}
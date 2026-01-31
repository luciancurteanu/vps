class VMManager {
    [string]$VBoxManage
    [string]$QemuImg
    [string]$VMName
    [string]$VMData
    [string]$VMDataRoot
    [string]$QcowPath
    [string]$VDIPath
    [string]$SeedISOPath

    VMManager([string]$vboxManage, [string]$qemuImg, [string]$vmName, [string]$vmData, [string]$qcowPath, [string]$vdiPath, [string]$seedIsoPath) {
        $this.VBoxManage = $vboxManage
        $this.QemuImg = $qemuImg
        $this.VMName = $vmName
        $this.VMData = $vmData
        $this.VMDataRoot = Split-Path -Parent $vmData
        $this.QcowPath = $qcowPath
        $this.VDIPath = $vdiPath
        $this.SeedISOPath = $seedIsoPath
    }

    [void] EnsureQcowImage([string]$cloudImageUrl) {
        Write-Host "Checking for QCOW2 image at: $($this.QcowPath)" -ForegroundColor Cyan

        # Check if file already exists in VM directory
        if (Test-Path -LiteralPath $this.QcowPath) {
            Write-Host "QCOW2 image already exists: $($this.QcowPath)" -ForegroundColor Green
            return
        }

        # Check if file exists anywhere in VMDataRoot
        Write-Host "Searching for existing QCOW2 files in $($this.VMDataRoot)..." -ForegroundColor Cyan
        $existingFile = Get-ChildItem -Path $this.VMDataRoot -Filter "*.qcow2" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq (Split-Path $this.QcowPath -Leaf) } | Select-Object -First 1

        if ($existingFile) {
            Write-Host "Found existing QCOW2 image at: $($existingFile.FullName)" -ForegroundColor Yellow
            Write-Host "Copying to VM directory..." -ForegroundColor Yellow
            # Ensure VM directory exists
            $vmDir = Split-Path $this.QcowPath -Parent
            if (-not (Test-Path $vmDir)) {
                New-Item -ItemType Directory -Path $vmDir -Force | Out-Null
            }
            Copy-Item -Path $existingFile.FullName -Destination $this.QcowPath -Force
            Write-Host "QCOW2 image copied successfully" -ForegroundColor Green
            return
        }

        # Download if file doesn't exist anywhere
        Write-Host "No existing QCOW2 image found, downloading from $cloudImageUrl" -ForegroundColor Yellow
        Write-Host "This is a large file (~600MB), please wait..." -ForegroundColor Yellow
        
        # Ensure VM directory exists
        $vmDir = Split-Path $this.QcowPath -Parent
        if (-not (Test-Path $vmDir)) {
            New-Item -ItemType Directory -Path $vmDir -Force | Out-Null
        }
        
        # Try BITS transfer first (faster, supports resume, better for large files)
        $startTime = Get-Date
        $downloadSuccess = $false
        
        try {
            Write-Host "Starting download using BITS (Background Intelligent Transfer Service)..." -ForegroundColor Cyan
            Write-Host "Progress bar should appear..." -ForegroundColor Yellow
            
            # Temporarily enable progress for BITS
            $oldProgressPref = $global:ProgressPreference
            $global:ProgressPreference = 'Continue'
            
            # Use synchronous BITS transfer with built-in progress bar
            Start-BitsTransfer -Source $cloudImageUrl -Destination $this.QcowPath -DisplayName "AlmaLinux Cloud Image" -Description "Downloading AlmaLinux 9 GenericCloud image"
            
            $global:ProgressPreference = $oldProgressPref
            $downloadSuccess = $true
            $duration = (Get-Date) - $startTime
            Write-Host "Download completed in $([math]::Round($duration.TotalSeconds, 1)) seconds" -ForegroundColor Green
        } catch {
            Write-Host "BITS transfer failed: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "Falling back to direct HTTP download..." -ForegroundColor Yellow
            
            # Fallback to WebClient with manual progress bar
            try {
                $webClient = New-Object System.Net.WebClient
                
                # Track progress manually
                $lastUpdate = Get-Date
                Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -SourceIdentifier WebClient.DownloadProgressChanged -Action {
                    $percent = $EventArgs.ProgressPercentage
                    $received = [math]::Round($EventArgs.BytesReceived / 1MB, 2)
                    $total = [math]::Round($EventArgs.TotalBytesToReceive / 1MB, 2)
                    Write-Progress -Activity "Downloading AlmaLinux Cloud Image" -Status "$received MB / $total MB" -PercentComplete $percent
                } | Out-Null
                
                try {
                    $webClient.DownloadFile($cloudImageUrl, $this.QcowPath)
                    Write-Progress -Activity "Downloading AlmaLinux Cloud Image" -Completed
                    $downloadSuccess = $true
                    $duration = (Get-Date) - $startTime
                    Write-Host "Download completed in $([math]::Round($duration.TotalSeconds, 1)) seconds" -ForegroundColor Green
                } finally {
                    Unregister-Event -SourceIdentifier WebClient.DownloadProgressChanged -ErrorAction SilentlyContinue
                    $webClient.Dispose()
                }
            } catch {
                Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
                throw
            }
        }
        
        if (-not $downloadSuccess) {
            throw "Failed to download cloud image"
        }
    }

    [void] ConvertQcowToVDI() {
        if (-not (Test-Path -LiteralPath $this.VDIPath)) {
            Write-Host "Converting QCOW -> VDI" -ForegroundColor Yellow
            & $this.QemuImg convert -O vdi $this.QcowPath $this.VDIPath 2>$null | Out-Null
        }
    }

    [void] AlignVDIUUID() {
        if (-not (Test-Path -LiteralPath $this.VDIPath)) { return }

        try {
            $hdds = & $this.VBoxManage list hdds 2>$null
            if (-not $hdds) { return }

            $blocks = ($hdds -split "\r?\n\r?\n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
            foreach ($block in $blocks) {
                $locLine = ($block -split "\r?\n") | Where-Object { $_ -match '^Location:' } | Select-Object -First 1
                if (-not $locLine) { continue }

                $loc = ($locLine -replace '^Location:\s*', '').Trim()
                if ($loc -and ($loc -ieq $this.VDIPath)) {
                    $uuidLine = ($block -split "\r?\n") | Where-Object { $_ -match '^UUID:' } | Select-Object -First 1
                    $regUuid = if ($uuidLine) { ($uuidLine -replace '^UUID:\s*', '').Trim() } else { $null }

                    if ($regUuid) {
                        try {
                            & $this.VBoxManage internalcommands sethduuid "$($this.VDIPath)" $regUuid 2>$null | Out-Null
                        }
                        catch { }
                    }
                }
            }
        }
        catch { }
    }

    [void] UnregisterMediumByPath([string]$path) {
        if (-not $path) { return }

        foreach ($type in @('hdds', 'dvds')) {
            try {
                $output = & $this.VBoxManage list $type 2>$null
                if (-not $output) { continue }

                $blocks = ($output -split "\r?\n\r?\n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                foreach ($block in $blocks) {
                    $loc = (($block -split "\r?\n") | Where-Object { $_ -match '^Location:' } | Select-Object -First 1) -replace '^Location:\s*', ''
                    if ($loc -and ($loc -ieq $path)) {
                        $uuid = (($block -split "\r?\n") | Where-Object { $_ -match '^UUID:' } | Select-Object -First 1) -replace '^UUID:\s*', ''
                        try {
                            & $this.VBoxManage closemedium disk $uuid 2>$null | Out-Null
                        }
                        catch {
                            try {
                                & $this.VBoxManage closemedium dvd $uuid 2>$null | Out-Null
                            }
                            catch { }
                        }
                    }
                }
            }
            catch { }
        }
    }

    [void] CleanVBoxMedia() {
        $tries = 5
        for ($attempt = 1; $attempt -le $tries; $attempt++) {
            $found = $false
            $hdds = & $this.VBoxManage list hdds 2>$null
            $dvds = & $this.VBoxManage list dvds 2>$null

            if (-not $hdds -and -not $dvds) { return }

            $blocks = @()
            if ($hdds) { $blocks += ($hdds -split "\r?\n\r?\n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' } }
            if ($dvds) { $blocks += ($dvds -split "\r?\n\r?\n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' } }

            foreach ($block in $blocks) {
                $locLine = ($block -split "\r?\n") | Where-Object { $_ -match '^Location:' } | Select-Object -First 1
                if (-not $locLine) { continue }

                $loc = $locLine -replace '^Location:\s*', ''
                if ($loc -and ($loc -like "$($this.VMData)*" -or $loc.StartsWith($this.VMData))) {
                    $found = $true
                    $uuidLine = ($block -split "\r?\n") | Where-Object { $_ -match '^UUID:' } | Select-Object -First 1
                    $regUuid = if ($uuidLine) { ($uuidLine -replace '^UUID:\s*', '').Trim() } else { $null }
                    $mid = if ($regUuid) { $regUuid } else { $loc }

                    Write-Verbose "Found registered medium: $loc (id: $mid)"

                    # Power off and detach from any referencing VMs
                    $this.DetachMediumFromVMs($mid, $loc)

                    # Try to close/delete the medium
                    try {
                        try {
                            & $this.VBoxManage closemedium disk "$mid" 2>$null | Out-Null
                            Write-Verbose "Closed medium (disk) $mid"
                        }
                        catch {
                            try {
                                & $this.VBoxManage closemedium dvd "$mid" 2>$null | Out-Null
                                Write-Verbose "Closed medium (dvd) $mid"
                            }
                            catch { throw }
                        }
                    }
                    catch {
                        if ($regUuid -and (Test-Path $loc)) {
                            try {
                                Write-Verbose "Attempting to set file UUID to registry UUID $regUuid"
                                & $this.VBoxManage internalcommands sethduuid "$loc" $regUuid 2>$null | Out-Null
                                try {
                                    & $this.VBoxManage closemedium disk $regUuid 2>$null | Out-Null
                                }
                                catch {
                                    try {
                                        & $this.VBoxManage closemedium dvd $regUuid 2>$null | Out-Null
                                    }
                                    catch { }
                                }
                                Write-Verbose "Closed $regUuid after sethduuid"
                            }
                            catch {
                                Write-Host "Could not close/delete $mid (attempt $attempt)" -ForegroundColor Yellow
                            }
                        }
                        else {
                            try {
                                if ($regUuid) {
                                    try {
                                        & $this.VBoxManage closemedium disk $regUuid 2>$null | Out-Null
                                    }
                                    catch {
                                        & $this.VBoxManage closemedium dvd $regUuid 2>$null | Out-Null
                                    }
                                }
                                else {
                                    try {
                                        & $this.VBoxManage closemedium disk "$loc" 2>$null | Out-Null
                                    }
                                    catch {
                                        & $this.VBoxManage closemedium dvd "$loc" 2>$null | Out-Null
                                    }
                                }
                            }
                            catch {
                                Write-Verbose "Could not close/unregister $mid (attempt $attempt)"
                            }
                        }
                    }
                }
            }

            if (-not $found) { return }
            else { Start-Sleep -Seconds (2 * $attempt) }
        }

        Write-Verbose "Warning: some VirtualBox registry entries under $($this.VMData) could not be removed after retries."
    }

    [void] DetachMediumFromVMs([string]$mediumId, [string]$mediumPath) {
        $vms = & $this.VBoxManage list vms 2>$null
        foreach ($vm in $vms) {
            if ($vm -match '"(?<name>.*?)"') {
                $currentVMName = $matches['name']
                $info = & $this.VBoxManage showvminfo $currentVMName --machinereadable 2>$null

                if ($info -and ($info -like "*${mediumId}*" -or $info -like "*${mediumPath}*")) {
                    $vmStateLine = ($info -split "\r?\n") | Where-Object { $_ -match '^VMState=' } | Select-Object -First 1
                    $vmState = if ($vmStateLine) { $vmStateLine -replace '^VMState=', '' -replace '"', '' } else { '' }

                    Write-Verbose "Powering off / clearing saved state for $currentVMName (state: $vmState)"
                    try {
                        if ($vmState -eq 'running') {
                            & $this.VBoxManage controlvm $currentVMName poweroff 2>$null | Out-Null
                        }
                        elseif ($vmState -eq 'paused') {
                            & $this.VBoxManage controlvm $currentVMName resume 2>$null | Out-Null
                            & $this.VBoxManage controlvm $currentVMName poweroff 2>$null | Out-Null
                        }
                        elseif ($vmState -eq 'saved') {
                            try {
                                & $this.VBoxManage controlvm $currentVMName discardstate 2>$null | Out-Null
                            }
                            catch { }
                        }
                        else {
                            & $this.VBoxManage controlvm $currentVMName poweroff 2>$null | Out-Null
                        }
                    }
                    catch { }

                    # Build storage controller map and detach
                    $controllerMap = @{}
                    foreach ($line in ($info -split "\r?\n")) {
                        if ($line -match '^storagecontrollername(?<i>\d+)="(?<n>.+)"') {
                            $controllerMap[$matches['i']] = $matches['n']
                        }
                    }

                    foreach ($line in ($info -split "\r?\n")) {
                        if ($line -match '^(?<ctrl>[A-Za-z]+)-(?<bus>\d+)-(?<port>\d+)=(?<val>.+)$') {
                            $val = $matches['val'].Trim().Trim('"')
                            if ($val -and ($val -eq $mediumPath -or $val -eq $mediumId -or $val -like "$($this.VMData)*")) {
                                $busIdx = $matches['bus']
                                $port = $matches['port']
                                $cname = if ($controllerMap.ContainsKey($busIdx)) { $controllerMap[$busIdx] } else { 'SATA Controller' }
                                Write-Verbose "Detaching $currentVMName -> $cname port $port (val: $val)"
                                try {
                                    & $this.VBoxManage storageattach $currentVMName --storagectl $cname --port $port --device 0 --type hdd --medium none 2>$null | Out-Null
                                }
                                catch { }
                            }
                        }
                    }

                    # Check if VM still references the medium
                    $infoAfter = & $this.VBoxManage showvminfo $currentVMName --machinereadable 2>$null
                    if ($infoAfter -and ($infoAfter -like "*${mediumId}*" -or $infoAfter -like "*${mediumPath}*")) {
                        Write-Verbose "VM $currentVMName still references medium; force-unregistering $currentVMName to remove registry entries"
                        try {
                            & $this.VBoxManage controlvm $currentVMName poweroff 2>$null | Out-Null
                        }
                        catch { }
                        try {
                            & $this.VBoxManage unregistervm $currentVMName --delete 2>$null | Out-Null
                            Write-Verbose "Unregistered $currentVMName"
                        }
                        catch {
                            Write-Verbose "Could not unregister $currentVMName"
                        }
                    }
                }
            }
        }
    }

    [void] CreateVM([int]$memoryMB, [int]$cpus, [string]$vmDataRoot, [string]$bridgeAdapterName = $null, [string]$lanNicType = 'virtio') {
        $this.RemoveStaleVMFolder()

        $bridgeRequested = -not [string]::IsNullOrWhiteSpace($bridgeAdapterName)

        if (-not ((& $this.VBoxManage list vms 2>$null) -match $this.VMName)) {
            Write-Host "Creating VM $($this.VMName)" -ForegroundColor Cyan
            & $this.VBoxManage createvm --name $this.VMName --ostype RedHat_64 --basefolder $vmDataRoot --register 2>$null 1>$null
            & $this.VBoxManage modifyvm $this.VMName --memory $memoryMB --cpus $cpus --nic1 nat 2>$null 1>$null
            if ($bridgeRequested) {
                $this.ConfigureBridgedAdapter($bridgeAdapterName, $lanNicType)
            }
            & $this.VBoxManage storagectl $this.VMName --name "SATA Controller" --add sata --controller IntelAHCI 2>$null 1>$null
        }
        else {
            if ($bridgeRequested) {
                $this.ConfigureBridgedAdapter($bridgeAdapterName, $lanNicType)
            }
            & $this.VBoxManage modifyvm $this.VMName --memory $memoryMB --cpus $cpus --nic1 nat 2>$null 1>$null
        }

        try {
            & $this.VBoxManage storageattach $this.VMName --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium $this.VDIPath 2>$null 1>$null
        }
        catch { }

        try {
            & $this.VBoxManage storageattach $this.VMName --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium $this.SeedISOPath 2>$null 1>$null
        }
        catch { }

        $this.AlignVDIUUID()

        if (-not (Test-Path $this.VMData)) {
            New-Item -ItemType Directory -Path $this.VMData -Force | Out-Null
        }

        & $this.VBoxManage modifyvm $this.VMName --boot1 disk 2>$null 1>$null
    }

    [void] RemoveStaleVMFolder() {
        try {
            $sysprops = & $this.VBoxManage list systemproperties 2>$null
            $defaultFolderLine = ($sysprops -split "\r?\n") | Where-Object { $_ -match '^Default machine folder:' } | Select-Object -First 1
            $defaultVMMachineFolder = if ($defaultFolderLine) { ($defaultFolderLine -replace '^Default machine folder:\s*', '').Trim() } else { $null }
        }
        catch {
            $defaultVMMachineFolder = $null
        }

        if (-not $defaultVMMachineFolder) { return }

        $registered = $false
        try {
            $registered = ((& $this.VBoxManage list vms 2>$null) -match ('"' + [regex]::Escape($this.VMName) + '"'))
        }
        catch {
            $registered = $false
        }

        if (-not $registered) {
            $stalePath = Join-Path $defaultVMMachineFolder $this.VMName
            if (Test-Path $stalePath) {
                Write-Host "Removing stale VM folder: $stalePath" -ForegroundColor Yellow
                try {
                    Remove-Item -Path $stalePath -Recurse -Force -ErrorAction Stop
                }
                catch {
                    Write-Verbose "Could not remove stale folder $stalePath"
                }
            }
        }
    }

    hidden [void] ConfigureBridgedAdapter([string]$bridgeAdapterName, [string]$lanNicType) {
        if ([string]::IsNullOrWhiteSpace($bridgeAdapterName)) { return }

        $nicTypeToUse = if ([string]::IsNullOrWhiteSpace($lanNicType)) { 'virtio' } else { $lanNicType }

        try {
            & $this.VBoxManage modifyvm $this.VMName --nic2 bridged --bridgeadapter2 "$bridgeAdapterName" --nictype2 $nicTypeToUse --cableconnected2 on 2>$null 1>$null
            Write-Host "Configured bridged adapter (nic2) using '$bridgeAdapterName' with type '$nicTypeToUse'" -ForegroundColor Cyan
        }
        catch {
            Write-Host "Warning: Could not configure bridged adapter '$bridgeAdapterName' for $($this.VMName)." -ForegroundColor Yellow
        }
    }

    [string] GetDefaultBridgeAdapter([string]$lanIpAddress) {
        if ([string]::IsNullOrWhiteSpace($lanIpAddress)) {
            return $null
        }

        $lanPrefixMatch = [regex]::Match($lanIpAddress, '^(\d+\.\d+\.\d+)')
        if (-not $lanPrefixMatch.Success) {
            return $null
        }

        $lanPrefix = $lanPrefixMatch.Groups[1].Value

        try {
            $bridgedInfo = & $this.VBoxManage list bridgedifs 2>$null
        }
        catch {
            return $null
        }

        if (-not $bridgedInfo) { return $null }

        $blocks = ($bridgedInfo -split "\r?\n\r?\n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        $upCandidates = @()
        $anyCandidates = @()
        foreach ($block in $blocks) {
            $nameLine = ($block -split "\r?\n") | Where-Object { $_ -match '^Name:' } | Select-Object -First 1
            $ipLine = ($block -split "\r?\n") | Where-Object { $_ -match '^IPAddress:' } | Select-Object -First 1
            $statusLine = ($block -split "\r?\n") | Where-Object { $_ -match '^Status:' } | Select-Object -First 1

            if (-not $nameLine) { continue }

            $adapterName = ($nameLine -replace '^Name:\s*', '').Trim()
            $candidateIp = if ($ipLine) { ($ipLine -replace '^IPAddress:\s*', '').Trim() } else { '' }
            $status = if ($statusLine) { ($statusLine -replace '^Status:\s*', '').Trim() } else { '' }

            # Track candidates for fallback selection
            if ($adapterName) {
                $anyCandidates += $adapterName
                if ($status -match '^(Up|UP)$') { $upCandidates += $adapterName }
            }

            if ($candidateIp.StartsWith($lanPrefix)) {
                return $adapterName
            }
        }

        # Fallback: pick the first adapter that is Up
        if ($upCandidates.Count -gt 0) { return $upCandidates[0] }
        # Last resort: pick the first bridged adapter listed
        if ($anyCandidates.Count -gt 0) { return $anyCandidates[0] }
        return $null
    }

    [void] StartVM() {
        Write-Host "Starting VM $($this.VMName)" -ForegroundColor Cyan
        $startTries = 6

        for ($i = 1; $i -le $startTries; $i++) {
            try {
                & $this.VBoxManage startvm $this.VMName --type headless 2>$null 1>$null
                break
            }
            catch {
                $msg = "" + $_
                if ($msg -match 'does not match the value \{(?<reg>[0-9a-fA-F\-]+)\} stored in the media registry') {
                    $regUuid = $matches['reg']
                    try {
                        & $this.VBoxManage internalcommands sethduuid "$($this.VDIPath)" $regUuid 2>$null | Out-Null
                    }
                    catch { }
                    Start-Sleep -Milliseconds (150 * $i)
                    continue
                }
                if ($msg -match 'already locked by a session') {
                    Start-Sleep -Milliseconds (250 * $i)
                    continue
                }
                throw
            }
        }
    }

    [void] ConfigureNATPortForwarding([int]$hostPort) {
        for ($i = 1; $i -le 5; $i++) {
            try {
                & $this.VBoxManage controlvm $this.VMName natpf1 delete ssh 2>$null 1>$null
            }
            catch { }

            try {
                & $this.VBoxManage controlvm $this.VMName natpf1 "ssh,tcp,,$hostPort,,22" 2>$null 1>$null
                break
            }
            catch {
                Start-Sleep -Milliseconds (200 * $i)
            }
        }
    }

    [void] CleanupVM([bool]$forceDelete = $false) {
        if ($forceDelete) {
            Write-Host "Force cleanup mode: removing VM, media, files (including cloud image), and SSH known_hosts entries" -ForegroundColor Yellow
        }
        else {
            Write-Host "Cleanup-only mode: removing VM, media, files (preserving cloud image), and SSH known_hosts entries" -ForegroundColor Yellow
        }

        # Unregister VM if present
        try {
            $vmList = & $this.VBoxManage list vms 2>$null
            if ($vmList -match ('"' + [regex]::Escape($this.VMName) + '"')) {
                try {
                    & $this.VBoxManage controlvm $this.VMName poweroff 2>$null | Out-Null
                }
                catch { }
                try {
                    & $this.VBoxManage unregistervm $this.VMName 2>$null | Out-Null
                }
                catch { }
            }
        }
        catch { }

        # Clean VirtualBox media
        $this.CleanVBoxMedia()

        # Unregister specific media
        $this.UnregisterMediumByPath($this.VDIPath)
        $this.UnregisterMediumByPath($this.SeedISOPath)

        # Remove stale default machine folder
        $this.RemoveStaleVMFolder()

        # Remove all files under VM path except QCOW (unless force delete)
        $this.CleanupVMFiles($forceDelete)

        Write-Host "Cleanup completed for $($this.VMName)" -ForegroundColor Green
    }

    [void] CleanupVMFiles([bool]$forceDelete = $false) {
        try {
            if (Test-Path -LiteralPath $this.VMData) {
                $preserve = @()
                
                # Only preserve QCOW if not force delete
                if (-not $forceDelete -and (Test-Path -LiteralPath $this.QcowPath)) {
                    try {
                        $preserve += (Get-Item -LiteralPath $this.QcowPath).FullName
                        Write-Host "Preserving QCOW2 image: $(Split-Path $this.QcowPath -Leaf)" -ForegroundColor Green
                    }
                    catch { }
                }

                Get-ChildItem -Force -LiteralPath $this.VMData | ForEach-Object {
                    if ($preserve -contains $_.FullName) {
                        Write-Host ("Preserve: {0}" -f $_.Name) -ForegroundColor Green
                    }
                    else {
                        try {
                            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
                            Write-Host ("Removed: {0}" -f $_.Name) -ForegroundColor Cyan
                        }
                        catch {
                            Write-Verbose ("Could not remove: {0}" -f $_.FullName)
                        }
                    }
                }
                
                # If force delete and no files left, remove the entire VM directory
                if ($forceDelete -and (Test-Path -LiteralPath $this.VMData)) {
                    $remainingItems = Get-ChildItem -Force -LiteralPath $this.VMData
                    if ($remainingItems.Count -eq 0) {
                        try {
                            Remove-Item -LiteralPath $this.VMData -Force
                            Write-Host "Removed empty VM directory: $(Split-Path $this.VMData -Leaf)" -ForegroundColor Cyan
                        }
                        catch {
                            Write-Verbose "Could not remove empty VM directory: $($this.VMData)"
                        }
                    }
                }
            }
        }
        catch {
            Write-Verbose "Cleanup under $($this.VMData) failed"
        }
    }
}
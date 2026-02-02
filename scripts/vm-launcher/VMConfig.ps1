try {
    $script:VmLauncherDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
catch {
    $script:VmLauncherDir = (Get-Location).Path
}

try {
    $resolvedRepoRoot = Resolve-Path (Join-Path $script:VmLauncherDir '..\..') -ErrorAction Stop
    $script:RepoRootPath = $resolvedRepoRoot.Path
}
catch {
    $script:RepoRootPath = $null
}

if ($script:RepoRootPath) {
    $script:InventoryHostsPath = Join-Path $script:RepoRootPath 'inventory\hosts.yml'
}
else {
    $script:InventoryHostsPath = $null
}

class VMConfig {
    # VM Configuration
    [string]$VMName
    [string]$VMDataRoot
    [int]$MemoryMB
    [int]$CPUs
    [int]$HostSSHPort
    [int]$WaitSSHSeconds

    # SSH Configuration
    [string]$SSHUser
    [string]$SSHPassword
    [bool]$UseLocalSSHKey
    [bool]$AutoSSH
    [bool]$FullSetup

    # Cloud Image Configuration
    [string]$CloudImageUrl

    # LAN Networking
    [string]$BridgeAdapterName
    [string]$LanIPAddress
    [int]$LanPrefixLength
    [string]$LanGateway
    [string[]]$LanDnsServers
    [string]$LanInterfaceName
    [string]$LanNicType
    [string]$Domain

    # Script behavior
    [bool]$Remove
    [bool]$Force
    [bool]$Recreate

    # Derived paths
    [string]$VMData
    [string]$QcowPath
    [string]$VDIPath
    [string]$SeedISOPath
    [string]$CIDataPath
    [string]$SSHDir
    [string]$SharedPrivKey
    [string]$SharedPubKey
    [string]$SharedMarker
    [string]$SSHConfig

    VMConfig() {
        $this.SetDefaults()
        $this.InitializePaths()
    }

    VMConfig([hashtable]$params) {
        # Apply any provided parameters
        foreach ($key in $params.Keys) {
            if ($this.PSObject.Properties.Name -contains $key) {
                $this.$key = $params[$key]
            }
        }
        $this.SetDefaults()
        $this.InitializePaths()
    }

    [void] SetDefaults() {
        # Set defaults only for properties that aren't already set
        if (-not $this.VMName) { $this.VMName = "AlmaLinux9-Testing" }
        if (-not $this.VMDataRoot) { $this.VMDataRoot = "C:\VMData" }
        if ($this.MemoryMB -eq 0) { $this.MemoryMB = 4096 }
        if ($this.CPUs -eq 0) { $this.CPUs = 2 }
        if ($this.HostSSHPort -eq 0) { $this.HostSSHPort = 22 }
        if ($this.WaitSSHSeconds -eq 0) { $this.WaitSSHSeconds = 180 }
        if (-not $this.SSHUser) { $this.SSHUser = 'admin' }
        if (-not $this.SSHPassword) { $this.SSHPassword = 'ChangeMe123!' }
        if (-not $this.AutoSSH) { $this.AutoSSH = $false }
        if (-not $this.FullSetup) { $this.FullSetup = $false }
        if (-not $this.CloudImageUrl) { $this.CloudImageUrl = "https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2" }
        if (-not $this.Remove) { $this.Remove = $false }
        if (-not $this.Force) { $this.Force = $false }
        if (-not $this.Recreate) { $this.Recreate = $false }

        if (-not $this.LanIPAddress) {
            $inventoryIp = [VMConfig]::GetPrimaryHostAddress($script:InventoryHostsPath)
            if ($inventoryIp) { $this.LanIPAddress = $inventoryIp }
        }

        if (-not $this.Domain) {
            $inventoryDomain = [VMConfig]::GetPrimaryHostName($script:InventoryHostsPath)
            if ($inventoryDomain) { $this.Domain = $inventoryDomain }
        }

        if ($this.LanPrefixLength -eq 0) { $this.LanPrefixLength = 24 }
        if (-not $this.LanInterfaceName) {
            # Prefer eth0 for RHEL-like cloud images where predictable names may be mapped as altnames
            $isRhelLike = $false
            if ($this.CloudImageUrl -match '(?i)centos|rocky|rhel|almalinux') { $isRhelLike = $true }
            $this.LanInterfaceName = if ($isRhelLike) { 'eth0' } else { 'enp0s8' }
        }
        if (-not $this.LanNicType) { $this.LanNicType = 'virtio' }

        if (-not $this.LanDnsServers -or $this.LanDnsServers.Count -eq 0) {
            $this.LanDnsServers = @('8.8.8.8', '1.1.1.1')
        }

        if (-not $this.LanGateway -and $this.LanIPAddress) {
            $defaultGateway = [VMConfig]::GetDefaultGatewayFromIp($this.LanIPAddress)
            if ($defaultGateway) { $this.LanGateway = $defaultGateway }
        }

        if (-not $this.BridgeAdapterName -and $env:VPSSETUP_BRIDGE_ADAPTER) {
            $this.BridgeAdapterName = $env:VPSSETUP_BRIDGE_ADAPTER
        }
    }

    [void] InitializePaths() {
        $this.VMData = Join-Path $this.VMDataRoot $this.VMName
        $qcowFile = Split-Path -Leaf $this.CloudImageUrl
        $this.QcowPath = Join-Path $this.VMData $qcowFile
        $this.VDIPath = Join-Path $this.VMData "disk.vdi"
        $this.SeedISOPath = Join-Path $this.VMData "cloud-init.iso"
        $this.CIDataPath = Join-Path $this.VMData "cidata"

        $this.SSHDir = Join-Path $env:USERPROFILE '.ssh'
        $this.SharedPrivKey = Join-Path $this.SSHDir 'vps'
        $this.SharedPubKey = Join-Path $this.SSHDir 'vps.pub'
        $this.SharedMarker = Join-Path $this.SSHDir 'vps.keys.mark'
        $this.SSHConfig = Join-Path $this.SSHDir 'config'
    }

    [void] ParseArgs([string[]]$scriptArgs) {
        # Handle --remove flag
        if ($scriptArgs -contains '--remove') {
            $this.Remove = $true
        }

        # Handle case where --remove was bound to VMName instead
        if ($this.VMName -eq '--remove') {
            $this.Remove = $true
            $this.VMName = "AlmaLinux9-Testing"
        }
    }

    [string] GetLogFileName() {
        $timestamp = Get-Date -Format "yyyy-MM-dd"
        return "$($this.VMName)-$timestamp.log"
    }

    [hashtable] ToHashTable() {
        return @{
            VMName            = $this.VMName
            VMDataRoot        = $this.VMDataRoot
            MemoryMB          = $this.MemoryMB
            CPUs              = $this.CPUs
            HostSSHPort       = $this.HostSSHPort
            WaitSSHSeconds    = $this.WaitSSHSeconds
            SSHUser           = $this.SSHUser
            SSHPassword       = $this.SSHPassword
            UseLocalSSHKey    = $this.UseLocalSSHKey
            AutoSSH           = $this.AutoSSH
            FullSetup         = $this.FullSetup
            CloudImageUrl     = $this.CloudImageUrl
            BridgeAdapterName = $this.BridgeAdapterName
            LanIPAddress      = $this.LanIPAddress
            LanPrefixLength   = $this.LanPrefixLength
            LanGateway        = $this.LanGateway
            LanDnsServers     = $this.LanDnsServers
            LanInterfaceName  = $this.LanInterfaceName
            LanNicType        = $this.LanNicType
            Remove            = $this.Remove
            Force             = $this.Force
            Recreate          = $this.Recreate
        }
    }

    hidden static [string] GetPrimaryHostAddress([string]$inventoryPath) {
        if (-not $inventoryPath -or -not (Test-Path -LiteralPath $inventoryPath)) {
            return $null
        }

        try {
            $lines = Get-Content -Path $inventoryPath -ErrorAction Stop
        }
        catch {
            return $null
        }

        $inPrimaryGroup = $false
        foreach ($rawLine in $lines) {
            if ([string]::IsNullOrWhiteSpace($rawLine)) { continue }

            $trimmed = $rawLine.Trim()
            if ($trimmed.StartsWith('#')) { continue }

            if ($trimmed -match '^\[(.+)\]$') {
                $inPrimaryGroup = ($matches[1] -eq 'primary')
                continue
            }

            if (-not $inPrimaryGroup) { continue }

            $lineNoComment = $trimmed
            $commentIndex = $lineNoComment.IndexOf('#')
            if ($commentIndex -ge 0) {
                $lineNoComment = $lineNoComment.Substring(0, $commentIndex).Trim()
            }

            if ([string]::IsNullOrWhiteSpace($lineNoComment)) { continue }

            $ansibleMatch = [regex]::Match($lineNoComment, 'ansible_host\s*=\s*([^\s]+)')
            if ($ansibleMatch.Success) {
                return $ansibleMatch.Groups[1].Value
            }

            $tokens = $lineNoComment -split '\s+'
            foreach ($token in $tokens) {
                if ($token -match '^(\d{1,3}\.){3}\d{1,3}$') {
                    return $token
                }
            }
        }

        return $null
    }

    hidden static [string] GetPrimaryHostName([string]$inventoryPath) {
        if (-not $inventoryPath -or -not (Test-Path -LiteralPath $inventoryPath)) {
            return $null
        }

        try {
            $lines = Get-Content -Path $inventoryPath -ErrorAction Stop
        }
        catch {
            return $null
        }

        $inPrimaryGroup = $false
        foreach ($rawLine in $lines) {
            if ([string]::IsNullOrWhiteSpace($rawLine)) { continue }

            $trimmed = $rawLine.Trim()
            if ($trimmed.StartsWith('#')) { continue }

            if ($trimmed -match '^\[(.+)\]$') {
                $inPrimaryGroup = ($matches[1] -eq 'primary')
                continue
            }

            if (-not $inPrimaryGroup) { continue }

            $lineNoComment = $trimmed
            $commentIndex = $lineNoComment.IndexOf('#')
            if ($commentIndex -ge 0) {
                $lineNoComment = $lineNoComment.Substring(0, $commentIndex).Trim()
            }

            if ([string]::IsNullOrWhiteSpace($lineNoComment)) { continue }

            # Extract hostname (first token before ansible_host)
            $tokens = $lineNoComment -split '\s+'
            if ($tokens.Length -gt 0) {
                $hostname = $tokens[0]
                # Ensure it looks like a domain (not an IP)
                if ($hostname -notmatch '^(\d{1,3}\.){3}\d{1,3}$' -and $hostname -match '^[a-zA-Z0-9][a-zA-Z0-9.-]+[a-zA-Z0-9]$') {
                    return $hostname
                }
            }
        }

        return $null
    }

    hidden static [string] GetDefaultGatewayFromIp([string]$ipAddress) {
        if ([string]::IsNullOrWhiteSpace($ipAddress)) {
            return $null
        }

        $match = [regex]::Match($ipAddress, '^(\d+\.\d+\.\d+)\.\d+$')
        if ($match.Success) {
            return "{0}.1" -f $match.Groups[1].Value
        }

        return $null
    }
}
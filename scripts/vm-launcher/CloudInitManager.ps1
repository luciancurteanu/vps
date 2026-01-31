class CloudInitManager {
  [string]$CIDataPath
  [string]$SeedISOPath
  [string]$MkIsoFS

  CloudInitManager([string]$cidataPath, [string]$seedIsoPath, [string]$mkIsoFS) {
    $this.CIDataPath = $cidataPath
    $this.SeedISOPath = $seedIsoPath
    $this.MkIsoFS = $mkIsoFS
  }

  [void] CreateUserData(
    [string]$sshUser,
    [string]$sshPassword,
    [string]$pubKey,
    [string]$lanInterfaceName = $null,
    [string]$lanIpAddress = $null,
    [int]$lanPrefixLength = 24,
    [string]$lanGateway = $null,
    [string[]]$lanDnsServers = $null,
    [string]$domain = $null
  ) {
    if (Test-Path $this.CIDataPath) {
      Remove-Item -Recurse -Force $this.CIDataPath
    }
    New-Item -ItemType Directory -Path $this.CIDataPath | Out-Null

    # Generate instance ID
    $instanceId = "iid-$([guid]::NewGuid())"

    # Create meta-data
    $metaData = "instance-id: $instanceId`nlocal-hostname: $($this.GetVMNameFromPath())"
    [System.IO.File]::WriteAllText((Join-Path $this.CIDataPath 'meta-data'), $metaData, (New-Object System.Text.UTF8Encoding $false))

    # Create user-data
    # NOTE: We use runcmd with echo | chpasswd instead of the chpasswd module
    # because chpasswd module has issues with special characters in passwords
    $userData = if ($pubKey) {
      @"
#cloud-config
users:
  - name: $sshUser
    lock_passwd: false
    groups: wheel
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - "$pubKey"
ssh_pwauth: true
ssh_deletekeys: false
disable_root: false
"@
    }
    else {
      @"
#cloud-config
users:
  - name: $sshUser
    lock_passwd: false
    groups: wheel
    sudo: ALL=(ALL) NOPASSWD:ALL
ssh_pwauth: true
ssh_deletekeys: false
disable_root: false
"@
    }

    # Optionally append network configuration (v1) directly into user-data for better compatibility on RHEL-like images
    if (-not [string]::IsNullOrWhiteSpace($lanInterfaceName) -and -not [string]::IsNullOrWhiteSpace($lanIpAddress)) {
      $netLines = @()
      $netLines += "network:"
      $netLines += "  version: 1"
      $netLines += "  config:"
      $netLines += "    - type: physical"
      $netLines += "      name: ${lanInterfaceName}"
      $netLines += "      subnets:"
      $netLines += "        - type: static"
      $netLines += "          address: $lanIpAddress/$lanPrefixLength"
      if (-not [string]::IsNullOrWhiteSpace($lanGateway)) {
        $netLines += "          gateway: $lanGateway"
      }
      if ($lanDnsServers -and $lanDnsServers.Count -gt 0) {
        $netLines += "          dns_nameservers:"
        foreach ($dns in ($lanDnsServers | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
          $netLines += "            - $dns"
        }
      }

      $userData += "`n" + ($netLines -join "`n") + "`n"

      # Add a NetworkManager connection profile via write_files and bring it up via runcmd (argv form)
      $dnsList = @()
      if ($lanDnsServers -and $lanDnsServers.Count -gt 0) {
        $dnsList = ($lanDnsServers | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
      }

      $nmConnName = "static-${lanInterfaceName}"
      $nmPath = "/etc/NetworkManager/system-connections/${nmConnName}.nmconnection"
      $nmLines = @()
      $nmLines += "[connection]"
      $nmLines += "id=${nmConnName}"
      $nmLines += "type=ethernet"
      $nmLines += "interface-name=${lanInterfaceName}"
      $nmLines += "autoconnect=true"
      $nmLines += ""
      $nmLines += "[ipv4]"
      if (-not [string]::IsNullOrWhiteSpace($lanGateway)) {
        $nmLines += "address1=${lanIpAddress}/${lanPrefixLength},${lanGateway}"
      }
      else {
        $nmLines += "address1=${lanIpAddress}/${lanPrefixLength}"
      }
      if ($dnsList.Count -gt 0) {
        $nmLines += ("dns=" + (($dnsList -join ';') + ';'))
      }
      $nmLines += "method=manual"
      $nmLines += ""
      $nmLines += "[ipv6]"
      $nmLines += "method=ignore"

      $wf = @()
      $wf += "write_files:"
      $wf += "  - path: ${nmPath}"
      $wf += "    permissions: '0600'"
      $wf += "    content: |"
      foreach ($l in $nmLines) { $wf += ("      " + $l) }

      $rc = @()
      $rc += "runcmd:"
      # Set passwords using echo | chpasswd (handles special characters properly)
      $rc += "  - echo 'root:${sshPassword}' | chpasswd"
      $rc += "  - echo '${sshUser}:${sshPassword}' | chpasswd"
      # SSH configuration for root login
      $rc += "  - sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config"
      $rc += "  - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config"
      $rc += "  - systemctl restart sshd"
      # Network configuration
      $rc += "  - [ nmcli, con, reload ]"
      # Attempt to deactivate default DHCP connections, ignoring if they don't exist
      $rc += "  - [ nmcli, con, down, `"System eth0`" ]"
      $rc += "  - [ nmcli, con, down, `"System enp0s8`" ]"
      # Bring up the static profile
      $rc += "  - [ nmcli, con, up, ${nmConnName} ]"
      # Add /etc/hosts entries for domain if provided
      if (-not [string]::IsNullOrWhiteSpace($domain)) {
        $rc += "  - echo '127.0.0.1 ${domain} www.${domain}' >> /etc/hosts"
        $rc += "  - echo '127.0.0.1 mail.${domain}' >> /etc/hosts"
        $rc += "  - echo '127.0.0.1 cpanel.${domain}' >> /etc/hosts"
      }

      $userData += ($wf -join "`n") + "`n" + ($rc -join "`n") + "`n"
    }
    else {
      # No network config, add standalone runcmd with password setting
      $rc = @()
      $rc += "runcmd:"
      # Set passwords using echo | chpasswd (handles special characters properly)
      $rc += "  - echo 'root:${sshPassword}' | chpasswd"
      $rc += "  - echo '${sshUser}:${sshPassword}' | chpasswd"
      # SSH configuration for root login
      $rc += "  - sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config"
      $rc += "  - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config"
      $rc += "  - systemctl restart sshd"
      # Add /etc/hosts entries for domain if provided
      if (-not [string]::IsNullOrWhiteSpace($domain) -and -not [string]::IsNullOrWhiteSpace($lanIpAddress)) {
        $rc += "  - echo '127.0.0.1 ${domain} www.${domain}' >> /etc/hosts"
        $rc += "  - echo '127.0.0.1 mail.${domain}' >> /etc/hosts"
        $rc += "  - echo '127.0.0.1 cpanel.${domain}' >> /etc/hosts"
      }
      $userData += "`n" + ($rc -join "`n") + "`n"
    }

    [System.IO.File]::WriteAllText((Join-Path $this.CIDataPath 'user-data'), $userData, (New-Object System.Text.UTF8Encoding $false))

    # Also write a standalone network-config for images that honor it from the seed ISO
    $this.CreateNetworkConfig($lanInterfaceName, $lanIpAddress, $lanPrefixLength, $lanGateway, $lanDnsServers)
  }

  [string] GetVMNameFromPath() {
    # Extract VM name from CIDataPath
    $pathParts = $this.CIDataPath -split '\\'
    if ($pathParts.Length -ge 2) {
      return $pathParts[$pathParts.Length - 2]
    }
    return "localhost"
  }

  [void] CreateSeedISO() {
    Push-Location $this.CIDataPath
    try {
      Write-Host "Building cloud-init ISO" -ForegroundColor Cyan

      # Use cmd to suppress stderr/stdout from mkisofs
      $mkCmd = '"' + $this.MkIsoFS + '" -V cidata -J -iso-level 4 -o ' + '"' + $this.SeedISOPath + '"' + ' . >NUL 2>&1'
      & cmd /c $mkCmd | Out-Null
    }
    finally {
      Pop-Location | Out-Null
    }
  }

  hidden [void] CreateNetworkConfig(
    [string]$lanInterfaceName,
    [string]$lanIpAddress,
    [int]$lanPrefixLength,
    [string]$lanGateway,
    [string[]]$lanDnsServers
  ) {
    # Build a cloud-init "network-config" file using version 1 (distro-agnostic) format.
    # AlmaLinux/Rocky/RHEL cloud images do not consume netplan (v2); they expect v1 which cloud-init
    # renders into NetworkManager configuration on first boot.
    # IMPORTANT: YAML is indentation-sensitive. We use 2 spaces per level here.
    # Target structure (example):
    #
    # network:
    #   version: 1
    #   config:
    #     - type: physical
    #       name: enp0s8
    #       subnets:
    #         - type: static
    #           address: 192.168.0.242/24
    #           gateway: 192.168.0.1
    #           dns_nameservers:
    #             - 8.8.8.8
    #             - 1.1.1.1
    #
    # Notes:
    # - v1 format is broadly supported (including RHEL-like images) and preferred here.
    # - The LAN interface name (default enp0s8) can differ by distro; pass -LanInterfaceName to override.
    # - Only emit gateway and dns_nameservers when values are provided.

    if ([string]::IsNullOrWhiteSpace($lanInterfaceName) -or [string]::IsNullOrWhiteSpace($lanIpAddress)) {
      return
    }

    if ($lanPrefixLength -le 0) {
      $lanPrefixLength = 24
    }

    if ([string]::IsNullOrWhiteSpace($lanGateway)) {
      $lanGateway = $null
    }

    $dnsEntries = @()
    if ($lanDnsServers) {
      $dnsEntries = $lanDnsServers | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }

    # StringBuilder collects the YAML content in the correct order/indentation
    $builder = New-Object System.Text.StringBuilder
    # cloud-init expects a top-level 'network:' key
    $null = $builder.AppendLine("network:")
    $null = $builder.AppendLine("  version: 1")
    $null = $builder.AppendLine("  config:")
    $null = $builder.AppendLine("    - type: physical")
    $null = $builder.AppendLine("      name: ${lanInterfaceName}")
    $null = $builder.AppendLine("      subnets:")
    $null = $builder.AppendLine("        - type: static")
    $null = $builder.AppendLine("          address: $lanIpAddress/$lanPrefixLength")
    if ($lanGateway) {
      $null = $builder.AppendLine("          gateway: $lanGateway")
    }
    if ($dnsEntries.Count -gt 0) {
      $null = $builder.AppendLine("          dns_nameservers:")
      foreach ($dns in $dnsEntries) {
        $null = $builder.AppendLine("            - $dns")
      }
    }

    # Write network-config alongside meta-data and user-data under the cidata folder
    [System.IO.File]::WriteAllText((Join-Path $this.CIDataPath 'network-config'), $builder.ToString(), (New-Object System.Text.UTF8Encoding $false))
  }
}
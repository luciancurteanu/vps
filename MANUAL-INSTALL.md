# Manual Service Installation Guide
## Purpose: Install services one-by-one to identify which triggers Webmin memory leak

**Testing Procedure:**
1. Install Webmin FIRST (on clean system)
2. Test dashboard - should work perfectly
3. Install each service one-by-one
4. After each service, refresh Webmin dashboard and check memory
5. When memory leak appears, you've found the culprit

---

## Prerequisites (Fresh AlmaLinux 9)

# Create VM with custom configuration
.\scripts\vm-launcher\run-vm.ps1 -VMName "AlmaLinux" -UseLocalSSHKey -MemoryMB 4096 -CPUs 2 -Recreate

```bash
# Update system
sudo dnf update -y

# Install basic tools
sudo dnf install -y epel-release
sudo dnf install -y curl wget tar gzip nano net-tools htop iotop lsof sysstat bind-utils telnet nc
```

---

## Step 1: Install Webmin (FIRST - on clean system)

```bash
# Add Webmin repository
cat <<'EOF' | sudo tee /etc/yum.repos.d/webmin.repo
[Webmin]
name=Webmin Distribution Neutral
baseurl=https://download.webmin.com/download/yum
enabled=1
gpgcheck=1
gpgkey=https://download.webmin.com/jcameron-key.asc
EOF

# Install Webmin
sudo dnf install -y webmin

# Start and enable Webmin
sudo systemctl enable --now webmin

# Check status
sudo systemctl status webmin
free -h
ps aux | grep -E 'sysinfo|xhr' | grep -v grep

echo "✅ Access Webmin at http://$(hostname -I | awk '{print $1}'):10000"

## Step 2: Install Monitoring Tools (Optional)

<!-- ```bash
# Install monitoring tools (optional - useful for debugging)
sudo dnf install -y htop lsof

# Configure system limits (prevents issues with high file descriptor usage)
sudo tee -a /etc/sysctl.conf > /dev/null <<'EOF'
fs.file-max = 1048576
kernel.pid_max = 4194303
EOF
sudo sysctl -p

echo "✅ Monitoring tools installed"
echo "✅ Refresh Webmin dashboard and check memory"
echo "Press Enter when ready to continue..."
read
```

--- -->

## Step 3: Install Security Tools (iptables, fail2ban)

```bash
# Disable firewalld (if installed), install iptables
sudo systemctl stop firewalld 2>/dev/null || true
sudo systemctl disable firewalld 2>/dev/null || true
sudo dnf install -y iptables iptables-services

# Create iptables rules (ACCEPT policy first to avoid lockout)
sudo iptables -F
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT

# Add rules (allowlist approach)
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 10000 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -j DROP

# Save rules and start service
sudo iptables-save | sudo tee /etc/sysconfig/iptables
sudo systemctl restart iptables
sudo systemctl enable iptables

# NOTE: On minimal systems Webmin may call the legacy `service` helper
# which is not present. If you see "service: command not found" when
# applying firewall changes from Webmin, either install a small
# compatibility wrapper that maps `service` to `systemctl`, or configure
# the Webmin Linux Firewall module to use these commands directly.
# Recommended Webmin module settings (Linux Firewall → Configuration):
# - IPv4 configuration: File to save/edit IPv4 rules = /etc/sysconfig/iptables
# - Command to run after applying configuration:
#   /usr/sbin/iptables-save | /usr/bin/tee /etc/sysconfig/iptables >/dev/null && /usr/bin/systemctl restart iptables
# (For IPv6, use /etc/sysconfig/ip6tables and ip6tables-save / systemctl restart ip6tables)

# Install fail2ban
sudo dnf install -y fail2ban fail2ban-systemd
sudo systemctl enable --now fail2ban

echo "✅ Security tools installed (iptables, fail2ban)"
echo "✅ Refresh Webmin dashboard and check memory"
echo "Press Enter when ready to continue..."
read
```

---

## Step 4: Install Nginx

```bash
# Install nginx
sudo dnf install -y nginx

# Start and enable nginx
sudo systemctl enable --now nginx

echo "✅ Nginx installed"
echo "✅ Refresh Webmin dashboard and check memory - LIKELY TRIGGER POINT"
echo "Press Enter when ready to continue..."
read
```

---

## Step 5: Install Python (Optional - skip if not needed)

```bash
# Install Python 3.13
sudo dnf install -y python3.13 python3.13-pip

echo "✅ Python installed"
echo "✅ Refresh Webmin dashboard and check memory"
echo "Press Enter when ready to continue..."
read
```

---

## Step 6: Install PHP-FPM

```bash
# Enable Remi repository for PHP 8.4
sudo dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm
sudo dnf module reset php -y
sudo dnf module enable php:remi-8.4 -y

# Install PHP-FPM and extensions
sudo dnf install -y php php-fpm php-cli php-mysqlnd php-gd php-xml php-mbstring php-zip php-curl php-opcache php-json php-intl php-bcmath

# Start and enable PHP-FPM
sudo systemctl enable --now php-fpm
sudo php -v

echo "✅ PHP-FPM 8.4 installed"
echo "✅ Refresh Webmin dashboard and check memory - ANOTHER LIKELY TRIGGER"
echo "Press Enter when ready to continue..."
read
```

---

## Step 7: Install MariaDB

```bash
# Add MariaDB repository for 11.4
sudo tee /etc/yum.repos.d/mariadb.repo > /dev/null <<'EOF'
[mariadb]
name = MariaDB
baseurl = https://rpm.mariadb.org/11.8/rhel/9/x86_64
gpgkey = https://rpm.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck = 1
EOF

# Install MariaDB
sudo dnf install -y MariaDB-server MariaDB-client

# Start and enable MariaDB
sudo systemctl enable --now mariadb

# Secure installation (manual)
```bash
# Note: `mysql_secure_installation` may not be provided with MariaDB 11.8.
# Use the `mariadb` client to perform the equivalent secure steps (replace
# StrongRootPass with a strong password):
sudo mariadb -u root <<'SQL'
ALTER USER 'root'@'localhost' IDENTIFIED BY 'StrongRootPass';
DELETE FROM mysql.user WHERE user='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db LIKE 'test\\_%';
FLUSH PRIVILEGES;
SQL

# Verify login interactively:
sudo mariadb -u root -p
```

echo "✅ MariaDB 11.8 installed"
echo "✅ Refresh Webmin dashboard and check memory"
echo "Press Enter when ready to continue..."
read
```

---

## Step 8: Install Mail Services (Postfix, Dovecot)

```bash
# Install Postfix and Dovecot
sudo dnf install -y postfix dovecot dovecot-mysql

# Start and enable services
sudo systemctl enable --now postfix
sudo systemctl enable --now dovecot

# Open mail ports
sudo iptables -A INPUT -p tcp --dport 25 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 587 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 993 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 995 -j ACCEPT
sudo iptables-save | sudo tee /etc/sysconfig/iptables
sudo systemctl restart iptables

echo "✅ Mail services installed (Postfix, Dovecot)"
echo "✅ Refresh Webmin dashboard and check memory"
echo "Press Enter when ready to continue..."
read
```

---

## Step 9: Install Tor (Optional - skip if not needed)

```bash
# Install Tor
sudo dnf install -y tor

# Start and enable Tor
sudo systemctl enable --now tor

echo "✅ Tor installed"
echo "✅ Refresh Webmin dashboard and check memory"
echo "Press Enter when ready to continue..."
read
```

---

## Step 10: Install Go (Optional - skip if not needed)

```bash
# Install Go
sudo dnf install -y golang

echo "✅ Go installed"
echo "✅ Refresh Webmin dashboard and check memory"
echo "Press Enter when ready to continue..."
read
```

---

## Memory Leak Detection Commands

```bash
# Monitor memory in real-time (run in separate terminal)
watch -n 2 'free -h; echo "---"; ps aux --sort=-%mem | head -10'

# Check for Webmin CGI processes
ps aux | grep -E 'sysinfo.cgi|xhr.cgi|index.cgi' | grep -v grep

# Check Webmin modules
ls -1 /etc/webmin/ | wc -l

# Check which Webmin modules are enabled for root
cat /etc/webmin/webmin.acl | head -1
```

---

## Quick Service Installation (All at once)

**⚠️ WARNING: This defeats the purpose of identifying the culprit service!**
**Only use this after you've tested individually.**

```bash
# Install everything (CORE SERVICES ONLY)
sudo dnf install -y nginx php php-fpm MariaDB-server MariaDB-client \
    postfix dovecot iptables-services fail2ban fail2ban-systemd

# Enable all services
sudo systemctl enable --now nginx php-fpm mariadb postfix dovecot fail2ban

echo "✅ All services installed"
echo "✅ Now test Webmin dashboard memory usage"
```

---

## Rollback Commands

```bash
# If you need to start over

# Remove Webmin
sudo dnf remove -y webmin
sudo rm -rf /etc/webmin /usr/libexec/webmin

# Remove all services
sudo dnf remove -y nginx php* MariaDB* postfix dovecot iptables-services fail2ban

# Clean DNF cache
sudo dnf clean all

# Reboot
sudo reboot
```

---

## Expected Results

Based on your issue, the memory leak likely appears when:

1. **Nginx is installed** - Webmin detects nginx module → adds to dashboard monitoring
2. **PHP-FPM is installed** - Webmin detects PHP → adds phpini module
3. **MariaDB is installed** - Webmin detects MySQL → adds mysql module
4. **Postfix/Dovecot** - Adds mail-related modules

Each service adds Webmin modules, and authentic-theme dashboard tries to monitor all of them, causing the memory leak.

**The real fix:** Keep dashboard disabled (delete index.cgi, sysinfo.cgi, xhr.cgi) and use Webmin via sidebar navigation only.

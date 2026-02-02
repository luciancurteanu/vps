#!/usr/bin/env bash
# CI helper: install Docker + Python venv + Molecule deps non-interactively
# Usage: sudo bash scripts/ci-setup.sh [--yes]

set -euo pipefail

ASSUME_YES=""
ASSUME_YES_DNF=""
if [[ "${1:-}" == "--yes" || "${1:-}" == "--assume-yes" ]]; then
  ASSUME_YES="--yes"
  ASSUME_YES_DNF="-y"
fi

echoinfo(){ echo "[INFO] $*"; }
echoerr(){ echo "[ERROR] $*" >&2; }

if command -v dnf &> /dev/null; then
  echoinfo "Detected DNF-based system (RHEL/CentOS/AlmaLinux)."

  echoinfo "Installing prerequisites..."
  sudo dnf install -y $ASSUME_YES_DNF yum-utils

  echoinfo "Configuring Docker repository..."
  sudo dnf config-manager --add-repo=https://download.docker.com/linux/rhel/docker-ce.repo

  echoinfo "Installing Docker engine and utilities..."
  sudo dnf install -y $ASSUME_YES_DNF docker-ce docker-ce-cli containerd.io
  sudo systemctl enable --now docker || true

  echoinfo "Installing python3, pip and sshpass..."
  sudo dnf install -y $ASSUME_YES_DNF python3 python3-pip git rsync sshpass

elif command -v apt &> /dev/null; then
  echoinfo "Detected APT-based system (Debian/Ubuntu)."
  echoinfo "Installing prerequisites..."
  sudo apt update
  sudo apt install -y $ASSUME_YES apt-transport-https ca-certificates curl gnupg lsb-release

  echoinfo "Configuring Docker repository..."
  curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg | sudo gpg --dearmour -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  echoinfo "Installing Docker engine and utilities..."
  sudo apt install -y $ASSUME_YES docker-ce docker-ce-cli containerd.io
  sudo systemctl enable --now docker || true

  echoinfo "Installing python3, pip and sshpass..."
  sudo apt install -y $ASSUME_YES python3 python3-venv python3-pip git rsync sshpass

else
  echoerr "Unsupported distribution: please install Docker, Python and git manually."
  exit 2
fi

echoinfo "Creating Python virtual environment and installing Molecule dependencies..."
python3 -m venv ~/molecule-env
source ~/molecule-env/bin/activate
pip install --upgrade pip
# ansible-core 2.15.x supports Python 3.9+ and works with community.docker collection
pip install 'requests<2.32' 'docker<=6.1.3' 'ansible-core>=2.15,<2.16' ansible molecule molecule-docker ansible-lint yamllint passlib

echoinfo "Upgrading community.docker collection to latest version..."
ansible-galaxy collection install community.docker --force

deactivate

echoinfo "Adding current user to docker group (requires logout/login to take effect)..."
sudo usermod -aG docker $USER || true

echoinfo "CI setup complete. If running in CI, ensure the runner user has access to Docker or configure DOCKER_HOST accordingly."

exit 0

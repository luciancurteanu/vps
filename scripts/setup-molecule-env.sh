#!/bin/bash
# Minimal Molecule Environment Setup Script for AlmaLinux 9 VM/WSL
# Usage: Run as the 'admin' user inside your AlmaLinux 9 VM/WSL (or other test environment).
# This script sets up a Python virtual environment and installs necessary dependencies for Molecule.
#
# Author: Lucian Curteanu
# Website: https://luciancurteanu.com
# Date: May 7, 2025

set -e

# Install sshpass for Ansible --ask-pass
echo "[INFO] Installing sshpass..."
sudo dnf install -y sshpass

python3 -m venv ~/molecule-env
source ~/molecule-env/bin/activate
pip install --upgrade pip

# Install requests separately to ensure version pinning
echo "[INFO] Installing 'requests<2.32' to ensure compatibility..."
pip install 'requests<2.32'

echo "[INFO] Installing other dependencies..."
# ansible-core 2.15.x supports Python 3.9+; community.docker 4.x and community.general 9.x support ansible-core 2.15+ (5.x and 10.x require 2.17+)
pip install 'requests<2.32' 'docker<=6.1.3' 'ansible-core>=2.15,<2.16' ansible molecule molecule-docker ansible-lint yamllint passlib

echoinfo "Installing community.docker 4.x and community.general 9.x (compatible with ansible-core 2.15)..."
ansible-galaxy collection install 'community.docker:>=4.0,<5.0' 'community.general:>=9.0,<10.0' --force

# Clean up potential duplicate Ansible collection path in lib64
# This addresses warnings if collections are found in both lib/ and lib64/ site-packages.
# Ansible typically defaults to the lib/ path, so lib64/ can be removed if it's a duplicate.
LIB64_COLLECTIONS_PATH="$HOME/molecule-env/lib64/python3.9/site-packages/ansible_collections"
LIB_COLLECTIONS_PATH="$HOME/molecule-env/lib/python3.9/site-packages/ansible_collections"

if [ -d "$LIB64_COLLECTIONS_PATH" ] && [ -d "$LIB_COLLECTIONS_PATH" ]; then
    echo "[INFO] Removing duplicate Ansible collections from $LIB64_COLLECTIONS_PATH to prevent warnings."
    rm -rf "$LIB64_COLLECTIONS_PATH"
fi

echo "Molecule environment setup complete."
echo "If you ran this script manually and want to use the environment in your current terminal, activate it with: source ~/molecule-env/bin/activate"
echo "(Note: bash scripts/run-test.sh handles activation automatically when you use it to run tests.)"
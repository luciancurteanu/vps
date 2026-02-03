#!/bin/bash
# reset-molecule-environment.sh
# Resets parts of the Molecule testing environment by removing the Python virtual
# environment, Ansible cache, general cache, and Ansible async task directories.
# This script DOES NOT remove the '~/vps' project directory itself.
# Author: Lucian Curteanu
# Website: https://luciancurteanu.com
# Date: May 7, 2025

echo "[INFO] Starting Molecule testing environment partial reset."
echo ""
echo "[WARNING] This script will attempt to REMOVE the following directories:"
echo "  1. ~/molecule-env (Python virtual environment)"
echo "  2. ~/.ansible (Ansible cache and configuration)"
echo "  3. ~/.cache (General application cache, including Molecule's)"
echo "  4. ~/.ansible_async (Ansible asynchronous task data)"
echo ""
echo "[IMPORTANT] This script DOES NOT remove the '~/vps' project directory."
echo "If you need to reset the project files (e.g., for a fresh clone), you must"
echo "remove '~/vps' manually AFTER this script, if desired."
echo ""

read -p "Are you sure you want to remove the listed directories? (yes/no): " confirmation

if [[ "$confirmation" != "yes" ]]; then
  echo "[INFO] Reset cancelled by user."
  exit 0
fi

echo ""
echo "[INFO] Proceeding with environment reset..."

# Remove Python virtual environment
if [ -d "$HOME/molecule-env" ]; then
  echo "[INFO] Removing Python virtual environment: $HOME/molecule-env"
  rm -rf "$HOME/molecule-env"
  echo "[INFO] $HOME/molecule-env removed."
else
  echo "[INFO] Python virtual environment $HOME/molecule-env not found. Skipping."
fi

# Remove Ansible cache
if [ -d "$HOME/.ansible" ]; then
  echo "[INFO] Removing Ansible cache: $HOME/.ansible"
  rm -rf "$HOME/.ansible"
  echo "[INFO] $HOME/.ansible removed."
else
  echo "[INFO] Ansible cache $HOME/.ansible not found. Skipping."
fi

# Remove General cache
if [ -d "$HOME/.cache" ]; then
  echo "[INFO] Removing general cache directory: $HOME/.cache"
  rm -rf "$HOME/.cache"
  echo "[INFO] $HOME/.cache removed."
else
  echo "[INFO] General cache directory $HOME/.cache not found. Skipping."
fi

# Remove Ansible async task data
if [ -d "$HOME/.ansible_async" ]; then
  echo "[INFO] Removing Ansible async task data: $HOME/.ansible_async"
  rm -rf "$HOME/.ansible_async"
  echo "[INFO] $HOME/.ansible_async removed."
else
  echo "[INFO] Ansible async task data $HOME/.ansible_async not found. Skipping."
fi

echo ""
echo "[INFO] Partial environment reset complete."
echo "[INFO] If you also need to reset the project files, manually remove '~/vps' and re-clone."
echo "[INFO] Then, re-run the environment setup (e.g., 'bash scripts/ci-setup.sh')."

exit 0

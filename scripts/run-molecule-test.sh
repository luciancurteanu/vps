#!/bin/bash
# run-molecule-test.sh
# Runs Molecule for a specified role and action (default: test) in this project.
# Usage: bash scripts/run-molecule-test.sh <role> [action]
# Author: Lucian Curteanu | Updated: 2025-05-04

set -e

ROLE="$1"
ACTION="${2:-test}"

if [[ -z "$ROLE" ]]; then
  echo "[ERROR] Usage: bash scripts/run-molecule-test.sh <role> [action]"
  exit 1
fi

VENV_PATH=~/molecule-env
SETUP_SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/setup-molecule-env.sh"

# Ensure virtualenv exists and activate it
if [[ ! -f "$VENV_PATH/bin/activate" ]]; then
  if [[ -f "$SETUP_SCRIPT_PATH" ]]; then
    echo "[INFO] Virtualenv not found; running $SETUP_SCRIPT_PATH to create it..."
    bash "$SETUP_SCRIPT_PATH"
  fi
fi

if [[ -f "$VENV_PATH/bin/activate" ]]; then
  # shellcheck disable=SC1091
  source "$VENV_PATH/bin/activate"
  echo "[INFO] Activated Python virtual environment from $VENV_PATH"
fi

ROLE_DIR="$(pwd)/roles/$ROLE"
if [[ ! -d "$ROLE_DIR" ]]; then
  echo "[ERROR] Role directory not found: $ROLE_DIR"
  exit 2
fi

cd "$ROLE_DIR"

if [[ ! -d molecule/default ]]; then
  echo "[ERROR] No molecule scenario found for role: $ROLE"
  exit 3
fi

# Run molecule
echo "[INFO] Running: molecule $ACTION"
molecule $ACTION

if [[ $? -eq 0 ]]; then
  echo "[OK] Molecule $ACTION completed for role: $ROLE"
else
  echo "[ERROR] Molecule $ACTION failed for role: $ROLE"
  exit 4
fi

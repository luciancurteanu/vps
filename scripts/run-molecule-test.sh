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

# Activate virtualenv if available
if [[ -d ~/molecule-env/venv ]]; then
  source ~/molecule-env/venv/bin/activate
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

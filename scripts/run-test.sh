#!/bin/bash
# run-test.sh
# Runs Molecule for a specified role and action (default: test) in this project,
# with comprehensive logging.
# Usage: bash scripts/run-test.sh <role> [action]
# ssh localhost "cd ~/vps && source ~/molecule-env/bin/activate && bash scripts/run-test.sh security test"
# Author: Lucian Curteanu | Website: https://luciancurteanu.com | Adapted: 2025-05-07

set -e # Exit immediately if a command exits with a non-zero status.

ROLE="$1"
ACTION="${2:-test}" # Default to 'test' if no action is provided

if [[ -z "$ROLE" ]]; then
  echo "[ERROR] Usage: bash scripts/run-test.sh <role> [action]"
  echo "  <role>: The name of the Ansible role to test (e.g., nginx)."
  echo "  [action]: The Molecule action to perform (e.g., test, converge, verify, lint). Defaults to 'test'."
  exit 1
fi

# Determine the project root dynamically, assuming this script is in a 'scripts' subdirectory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PATH=~/molecule-env
SETUP_SCRIPT_NAME="ci-setup.sh"
SETUP_SCRIPT_PATH="$PROJECT_ROOT/scripts/$SETUP_SCRIPT_NAME"

# Check if virtualenv activation script exists, if not, auto-install
if [[ ! -f "$VENV_PATH/bin/activate" ]]; then
  echo "[WARNING] Python virtual environment not found at $VENV_PATH/bin/activate"
  
  if [[ -f "$PROJECT_ROOT/scripts/ci-setup.sh" ]]; then
    echo "[INFO] Attempting to install Molecule environment automatically..."
    echo "[INFO] Running: sudo bash $PROJECT_ROOT/scripts/ci-setup.sh"
    
    if sudo bash "$PROJECT_ROOT/scripts/ci-setup.sh"; then
      echo "[INFO] Molecule environment installation completed successfully"
      
      # Verify installation
      if [[ ! -f "$VENV_PATH/bin/activate" ]]; then
        echo "[ERROR] Installation completed but virtualenv still not found at $VENV_PATH/bin/activate" >&2
        exit 1
      fi
    else
      echo "[ERROR] Molecule environment installation failed" >&2
      echo "[ADVICE] Try running manually: sudo bash $PROJECT_ROOT/scripts/ci-setup.sh" >&2
      exit 1
    fi
  else
    echo "[ERROR] ci-setup.sh not found at $PROJECT_ROOT/scripts/ci-setup.sh" >&2
    echo "[ADVICE] Ensure you have the vps repository cloned completely" >&2
    exit 1
  fi
fi

# Activate virtualenv
if [[ -f "$VENV_PATH/bin/activate" ]]; then
  source "$VENV_PATH/bin/activate"
  echo "[INFO] Activated Python virtual environment from $VENV_PATH"
  
  # Unset DOCKER_HOST to prevent potential issues with Docker SDK
  unset DOCKER_HOST
  echo "[INFO] Unset DOCKER_HOST environment variable."
else
  # This case should ideally be caught by the setup logic above, but as a fallback:
  echo "[ERROR] Virtual environment activation script $VENV_PATH/bin/activate not found, even after setup attempt." >&2
  exit 1
fi

# Check for molecule command
if ! command -v molecule &> /dev/null; then
    echo "[ERROR] 'molecule' command not found in PATH" >&2
    echo "[ADVICE] Install Molecule environment: sudo bash $PROJECT_ROOT/scripts/ci-setup.sh" >&2
    exit 127 # Standard exit code for command not found
fi

ROLE_DIR="$PROJECT_ROOT/roles/$ROLE"

if [[ ! -d "$ROLE_DIR" ]]; then
  echo "[ERROR] Role directory not found: $ROLE_DIR"
  echo "Please ensure the role '$ROLE' exists under $PROJECT_ROOT/roles/"
  exit 2
fi

echo "[INFO] Changing working directory to: $ROLE_DIR"
cd "$ROLE_DIR"

# Define log paths relative to the role's molecule/default directory
MOLECULE_SCENARIO_DIR="molecule/default" # Assuming 'default' scenario
LOG_DIR="$MOLECULE_SCENARIO_DIR" # Logs will be inside the scenario directory
VM_TERMINAL_LOG_FILE="$LOG_DIR/molecule_vm_terminal_output.log"
ANSIBLE_RUN_LOG_FILE="$LOG_DIR/ansible_molecule_output.log" # Changed filename

# Ensure the log directory exists within the role's molecule scenario
if [[ ! -d "$MOLECULE_SCENARIO_DIR" ]]; then
  echo "[WARNING] Molecule scenario directory not found: $ROLE_DIR/$MOLECULE_SCENARIO_DIR"
  mkdir -p "$LOG_DIR" # Create if it doesn't exist
fi

# Clear previous ansible_molecule_output.log
if [ -f "$ANSIBLE_RUN_LOG_FILE" ]; then
  rm "$ANSIBLE_RUN_LOG_FILE"
fi

echo "[INFO] Starting Molecule $ACTION for role: $ROLE"

# Ensure user has docker group access for molecule to work
if ! docker ps &>/dev/null 2>&1; then
  echo "[INFO] Docker group not active in current session. Setting socket permissions..."
  # Temporarily allow docker socket access (requires NOPASSWD sudo for docker)
  sudo chmod 666 /var/run/docker.sock
fi

echo "[INFO] Running molecule $ACTION"
molecule "$ACTION" 2>&1 | tee "$VM_TERMINAL_LOG_FILE"
exit_status=${PIPESTATUS[0]}

if [[ $exit_status -eq 0 ]]; then
  echo "[OK] Molecule $ACTION completed successfully for role: $ROLE"
  echo "[INFO] Full terminal output saved to: $ROLE_DIR/$VM_TERMINAL_LOG_FILE"
else
  echo "[ERROR] Molecule $ACTION failed for role: $ROLE with exit code $exit_status"
  echo "[INFO] Full terminal output saved to: $ROLE_DIR/$VM_TERMINAL_LOG_FILE"
fi

exit $exit_status

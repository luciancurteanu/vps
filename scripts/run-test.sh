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
SETUP_SCRIPT_NAME="setup-molecule-env.sh"
SETUP_SCRIPT_PATH="$PROJECT_ROOT/scripts/$SETUP_SCRIPT_NAME"

# Check if virtualenv activation script exists, if not, try to set it up
if [[ ! -f "$VENV_PATH/bin/activate" ]]; then
  echo "[WARNING] Python virtual environment activation script not found at $VENV_PATH/bin/activate."
  if [[ -f "$SETUP_SCRIPT_PATH" ]]; then
    echo "[INFO] Attempting to set up the environment by running 'bash $SETUP_SCRIPT_PATH'..."
    if bash "$SETUP_SCRIPT_PATH"; then
      echo "[INFO] Environment setup script completed."
      # Check again if activation script exists
      if [[ ! -f "$VENV_PATH/bin/activate" ]]; then
        echo "[ERROR] Environment setup script ran, but activation script $VENV_PATH/bin/activate is still missing." >&2
        echo "[ADVICE] Please check the output of '$SETUP_SCRIPT_NAME' and ensure it created the environment correctly." >&2
        exit 1
      fi
    else
      echo "[ERROR] Environment setup script '$SETUP_SCRIPT_PATH' failed." >&2
      echo "[ADVICE] Please check the output above for errors from the setup script." >&2
      exit 1
    fi
  else
    echo "[ERROR] Python virtual environment not found, and setup script '$SETUP_SCRIPT_PATH' is also missing." >&2
    echo "[ADVICE] Please ensure your 'vps' project directory is up-to-date (e.g., run 'git pull')." >&2
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
    echo "[ERROR] 'molecule' command not found after attempting to activate virtual environment." >&2
    echo "[ERROR] This means the 'molecule' executable is not in your PATH." >&2
    echo "[ERROR] Possible reasons:" >&2
    echo "[ERROR]   1. The Python virtual environment at '$VENV_PATH' was not found or not activated correctly." >&2
    echo "[ERROR]   2. 'molecule' was not installed correctly within the virtual environment." >&2
    echo "[ERROR]   3. The 'vps' project files (especially '$SETUP_SCRIPT_PATH') are outdated on this machine." >&2
    echo "[ADVICE] Please ensure on this machine ('$(pwd)'):" >&2
    echo "[ADVICE]   a. Your 'vps' project directory is up-to-date (e.g., run 'git pull')." >&2
    echo "[ADVICE]   b. You have successfully run 'bash $SETUP_SCRIPT_PATH' from the project root if issues persist." >&2
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
# Check if we need to activate docker group privileges
if ! docker ps &>/dev/null 2>&1; then
  # Docker socket not accessible directly, check if sudo works
  if sudo docker ps &>/dev/null 2>&1; then
    echo "[INFO] Docker requires elevated privileges. Using sudo for docker commands."
    echo "[INFO] (To avoid this, reconnect your SSH session to activate docker group)"
    # Export DOCKER_HOST to use sudo for docker commands via Molecule
    export DOCKER_HOST="unix:///var/run/docker.sock"
    # Set up sudo wrapper for docker by creating a temporary script
    DOCKER_WRAPPER="/tmp/docker_sudo_wrapper_$$.sh"
    cat > "$DOCKER_WRAPPER" <<'EOF'
#!/bin/bash
sudo /usr/bin/docker "$@"
EOF
    chmod +x "$DOCKER_WRAPPER"
    export PATH="/tmp:$PATH"
    mv "$DOCKER_WRAPPER" /tmp/docker
    
    molecule "$ACTION" 2>&1 | tee "$VM_TERMINAL_LOG_FILE"
    exit_status=${PIPESTATUS[0]}
    
    # Cleanup
    rm -f /tmp/docker
  else
    echo "[ERROR] Cannot access Docker. Please check Docker installation."
    exit 1
  fi
else
  echo "[INFO] Docker access confirmed, running molecule directly"
  molecule "$ACTION" 2>&1 | tee "$VM_TERMINAL_LOG_FILE"
  exit_status=${PIPESTATUS[0]}
fi

if [[ $exit_status -eq 0 ]]; then
  echo "[OK] Molecule $ACTION completed successfully for role: $ROLE"
  echo "[INFO] Full terminal output saved to: $ROLE_DIR/$VM_TERMINAL_LOG_FILE"
else
  echo "[ERROR] Molecule $ACTION failed for role: $ROLE with exit code $exit_status"
  echo "[INFO] Full terminal output saved to: $ROLE_DIR/$VM_TERMINAL_LOG_FILE"
fi

exit $exit_status

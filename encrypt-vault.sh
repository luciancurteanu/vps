#!/bin/sh
set -euo pipefail

# Usage:
#   sh encrypt-vault.sh            # ephemeral (default)
#   sh encrypt-vault.sh persistent # saves ~/.vault_pass (less secure)
#
# Small helper to encrypt `vars/secrets.yml` with Ansible Vault.
# Provides two modes:
#  - ephemeral  : prompts securely for the vault password, uses a temporary
#                 file (removed after encrypt), and does not leave a
#                 persistent plaintext password on disk (recommended).
#  - persistent : prompts securely and saves the vault password to
#                 ~/.vault_pass for reuse; file is created with mode 600.
#
# Notes:
#  - Run this from the repository root so `vars/secrets.yml` is found.
#  - Requires `ansible-vault` in PATH.
#  - For `persistent` mode the file `~/.vault_pass` is created; keep it
#    permissioned `600` and located only on your control machine.

MODE=${1:-ephemeral}
SECRETS_FILE="vars/secrets.yml"

if [ ! -f "$SECRETS_FILE" ]; then
    echo "Error: $SECRETS_FILE not found" >&2
    exit 2
fi

# prompt for password without echoing
read -r -s -p "Vault password: " VAULT_PASS
printf "\n"

# If the file is already encrypted, perform a silent rekey using the
# provided password (persistent or ephemeral) and exit quietly.
HEAD=$(head -n 1 "$SECRETS_FILE" 2>/dev/null || true)
if printf '%s' "$HEAD" | grep -q '^\$ANSIBLE_VAULT'; then
    if [ "$MODE" = "persistent" ]; then
        PASSFILE="${HOME}/.vault_pass"
        printf '%s\n' "$VAULT_PASS" > "$PASSFILE"
        chmod 600 "$PASSFILE"
        unset VAULT_PASS
        ansible-vault rekey --vault-password-file="$PASSFILE" --new-vault-password-file="$PASSFILE" "$SECRETS_FILE" >/dev/null 2>&1 || true
        exit 0
    else
        TMPREKEY=$(mktemp)
        chmod 600 "$TMPREKEY"
        printf '%s\n' "$VAULT_PASS" > "$TMPREKEY"
        unset VAULT_PASS
        ansible-vault rekey --vault-password-file="$TMPREKEY" --new-vault-password-file="$TMPREKEY" "$SECRETS_FILE" >/dev/null 2>&1 || true
        rm -f "$TMPREKEY"
        # remove any existing persistent password file left from earlier runs
        PASSFILE="${HOME}/.vault_pass"
        if [ -f "$PASSFILE" ]; then
            rm -f "$PASSFILE"
        fi
        exit 0
    fi
fi

if [ "$MODE" = "persistent" ]; then
    PASSFILE="${HOME}/.vault_pass"
    printf '%s\n' "$VAULT_PASS" > "$PASSFILE"
    chmod 600 "$PASSFILE"
    unset VAULT_PASS
    ansible-vault encrypt --vault-password-file="$PASSFILE" "$SECRETS_FILE"
    echo "Encrypted $SECRETS_FILE using $PASSFILE"
else
    # If a persistent password file exists from a previous run, remove it
    PASSFILE="${HOME}/.vault_pass"
    if [ -f "$PASSFILE" ]; then
        rm -f "$PASSFILE"
    fi

    TMPFILE=$(mktemp)
    chmod 600 "$TMPFILE"
    printf '%s\n' "$VAULT_PASS" > "$TMPFILE"
    unset VAULT_PASS
    ansible-vault encrypt --vault-password-file="$TMPFILE" "$SECRETS_FILE"
    rm -f "$TMPFILE"
    echo "Encrypted $SECRETS_FILE (temporary password file removed)"
fi

# Ansible Role Test Expansion Plan (AlmaLinux 9 VM/WSL + Docker + Molecule)

This document tracks planned test expansions for Ansible roles using the minimal AlmaLinux 9 VM/WSL + Docker + Molecule workflow. All examples and references use the username `admin`.

## Guidelines
- All tests must be runnable via `bash scripts/run-test.sh <role_name>` from the project root.
- Use only the supported workflow: AlmaLinux 9 VM/WSL, Docker, Molecule, and user `admin`.
- Refer to `docs/molecule-admin-setup.md` for the standard testing environment.

## General Test Coverage Goals
- [ ] All roles have a `molecule/default/converge.yml` that successfully applies the role.
- [ ] All roles have a `molecule/default/verify.yml` that checks critical aspects of the role's functionality.
- [ ] All tests run as the `admin` user in the VM/WSL.
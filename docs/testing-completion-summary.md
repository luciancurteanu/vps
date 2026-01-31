# Testing Completion Summary (AlmaLinux 9 VM/WSL + Docker + Molecule)

This summary tracks the completion status of Molecule testing for all Ansible roles using the minimal AlmaLinux 9 VM/WSL + Docker + Molecule workflow. All references use the username `admin`.

Last updated: 2026-01-20

## Role Test Status

| Role         | Molecule Config | Tests Passing | Test User | Status   | Notes                   |
|--------------|-----------------|---------------|-----------|----------|-------------------------|
| common       | Yes             | No            | admin    | Pending  | Reset for fresh testing |
| security     | Yes             | No            | admin    | Pending  | Reset for fresh testing |
| nginx        | Yes             | No            | admin    | Pending  | Reset for fresh testing |
| python       | Yes             | No            | admin    | Pending  | Reset for fresh testing |
| php          | Yes             | No            | admin    | Pending  | Reset for fresh testing |
| mariadb      | Yes             | No            | admin    | Pending  | Reset for fresh testing |
| mail         | Yes             | No            | admin    | Pending  | Reset for fresh testing |
| webmin       | Yes             | No            | admin    | Pending  | Reset for fresh testing |
| development  | Yes             | No            | admin    | Pending  | Reset for fresh testing |
| goproxy      | Yes             | No            | admin    | Pending  | Reset for fresh testing |

## Notes
- Tests use the minimal workflow: AlmaLinux 9 VM/WSL, Docker, Molecule, and user `admin`.
- Run with: `bash scripts/run-test.sh <role_name> [action]` from the project root inside the VM.
- You may see a benign warning: "Collection community.general does not support Ansible version 2.15.13" — current runs are unaffected; we can pin versions later if needed.
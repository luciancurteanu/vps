# Testing Completion Summary (AlmaLinux 9 VM/WSL + Docker + Molecule)

This summary tracks the completion status of Molecule testing for all Ansible roles using the minimal AlmaLinux 9 VM/WSL + Docker + Molecule workflow. All references use the username `admin`.

Last updated: 2026-02-03

## Role Test Status

| Role         | Molecule Config | Tests Passing | Test User | Status   | Notes                   |
|--------------|-----------------|---------------|-----------|----------|-------------------------|
| common       | Yes             | Yes           | admin     | Passed   | Molecule passed on 2026-02-03 |
| webmin       | Yes             | Yes           | admin     | Passed   | Molecule passed on 2026-02-03 |
| cockpit      | Yes             | Yes           | admin     | Passed   | Molecule passed on 2026-02-03 |
| nginx        | Yes             | Yes           | admin     | Passed   | Molecule passed on 2026-02-03 |
| php          | Yes             | Yes           | admin     | Passed   | Molecule passed on 2026-02-03 |
| mariadb      | Yes             | Yes           | admin     | Passed   | Molecule passed on 2026-02-03 |
| mail         | Yes             | Yes           | admin     | Passed   | Molecule passed on 2026-02-03 |
| python       | Yes             | Yes           | admin     | Passed   | Molecule passed on 2026-02-03 |
| goproxy      | Yes             | Yes           | admin     | Passed   | Molecule passed on 2026-02-03 |
| development  | Yes             | Yes           | admin     | Passed   | Molecule passed on 2026-02-03 |
| security     | Yes             | Yes           | admin     | Passed   | Molecule passed on 2026-02-03 |

## Notes
- Tests use the minimal workflow: AlmaLinux 9 VM/WSL, Docker, Molecule, and user `admin`.
- Run with: `bash scripts/run-test.sh <role_name> [action]` from the project root inside the VM.
- You may see a benign warning: "Collection community.general does not support Ansible version 2.15.13" — current runs are unaffected; we can pin versions later if needed.
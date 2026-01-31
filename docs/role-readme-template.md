# Ansible Role README Template

## Role: <role_name>

### Description
Briefly describe the purpose of this role.

### Requirements
Prerequisites for local testing:
- AlmaLinux 9 VM/WSL environment
- Docker installed and running
- Python virtual environment with Molecule and dependencies (see `docs/molecule-admin-setup.md`)
- User: `admin` (must be in the `docker` group)

### Role Variables
List and describe all variables that can be set for this role.

### Dependencies
List any role dependencies. If the role uses external collections or roles from Ansible Galaxy for its own execution (not just for testing), list them here. For Molecule-specific dependencies, see the Testing section.

### Example Playbook
```yaml
- hosts: all
  become: true
  vars:
    example_var: value
  roles:
    - role: <role_name>
```

### Molecule Testing
- Ensure you are using the `admin` user and the minimal AlmaLinux 9 + Docker + Molecule workflow as described in `docs/molecule-admin-setup.md`.
- Run tests from the project root using: `bash scripts/run-test.sh <role_name>`
- **Test Dependencies**: If this role requires specific external Ansible Galaxy roles or collections for its Molecule tests, they will be defined in `roles/<role_name>/molecule/default/requirements.yml`. These are automatically handled by Molecule during the `dependency` phase.
- **Custom Cleanup**: If this role utilizes a custom `cleanup.yml` playbook for its Molecule tests (for actions beyond standard instance destruction), it will be located at `roles/<role_name>/molecule/default/cleanup.yml` and configured in the scenario's `molecule.yml`.

**Author:** Lucian Curteanu  
Website: [https://luciancurteanu.com](https://luciancurteanu.com)
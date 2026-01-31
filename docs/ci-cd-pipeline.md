# CI/CD Pipeline for AlmaLinux 9 VM/WSL + Docker + Molecule

This document describes a minimal, modern CI/CD pipeline for testing Ansible roles with Molecule and Docker on AlmaLinux 9 VMs or WSL. All examples use the username `admin`.

## Base Environment Setup for CI

The CI environment should be set up following the core principles and steps outlined in the [Testing/Development Workflow (AlmaLinux 9 VM/WSL + Docker + Molecule)](molecule-admin-setup.md) guide. Key aspects for the CI server include:

1.  **Provision a AlmaLinux 9 VM or WSL environment.**
2.  **Ensure the user `admin` exists and has necessary permissions (including being in the `docker` group).**
    ```bash
    # If using VM launcher: admin user is created automatically
    # If starting from clean AlmaLinux image, create manually:
    # sudo adduser admin
    # sudo passwd admin
    # sudo usermod -aG wheel admin
    # sudo usermod -aG docker admin
    ```
3.  **Install Docker, Python (matching version in `molecule-admin-setup.md`), and Git.**
    ```bash
    # Refer to molecule-admin-setup.md for specific installation commands
    # Example:
    # sudo dnf config-manager --add-repo=https://download.docker.com/linux/rhel/docker-ce.repo
    # sudo dnf install -y docker-ce docker-ce-cli containerd.io python3 python3-pip git rsync sshpass
    # sudo systemctl enable --now docker
    ```
Alternatively, use the included CI helper script which automates these steps non-interactively on AlmaLinux 9 (DNF-based) systems:

```bash
sudo bash scripts/ci-setup.sh --yes
```
This script installs Docker engine, Python, creates `~/molecule-env` and installs pinned Molecule dependencies.
4.  **Set up the Python virtual environment and install dependencies (as `admin` user).**
    ```bash
    # su - admin
    # python3 -m venv ~/molecule-env
    # source ~/molecule-env/bin/activate
    # pip install --upgrade pip
    # pip install docker ansible molecule molecule-docker ansible-lint yamllint 'requests<2.32' # Match versions from molecule-admin-setup.md
    ```
5.  **Clone the repository.**
    ```bash
    # git clone https://github.com/yourusername/vps.git
    # sudo chown -R admin:admin ~/vps # Ensure correct ownership
    # cd ~/vps
    ```

## Pipeline Steps Specific to CI Execution

Once the base environment is ready on the CI runner:

1.  **Ensure the correct Python virtual environment is activated.**
    ```bash
    # source ~/molecule-env/bin/activate 
    ```
2.  **Navigate to the project root.**
    ```bash
    # cd ~/vps 
    ```
3.  **Run Molecule tests using the `run-test.sh` script.**
    ```bash
    # For a specific role, e.g., nginx:
    # bash scripts/run-test.sh nginx
    #
    # Your CI script would iterate through all roles or changed roles.
    ```

Example GitHub Actions workflow is provided at `.github/workflows/molecule-ci.yml` which
uses `scripts/ci-setup.sh` and runs a smoke Molecule test for the `common` role.

## Notes
- Ensure `$DOCKER_HOST` is unset: `echo $DOCKER_HOST` should return nothing.
- Pin dependencies like Docker SDK as specified in `molecule-admin-setup.md` for compatibility.
- Update this pipeline as needed for your CI/CD provider (GitHub Actions, GitLab CI, etc.), focusing on how it orchestrates the above steps.

# CI/CD Pipeline Documentation

This document provides an overview of the Continuous Integration and Continuous Delivery (CI/CD) pipeline for the VPS setup project.

## Pipeline Overview

Our CI/CD pipeline uses GitHub Actions to automatically test changes to the codebase, ensuring that all roles and integrations work correctly before adminment.

### Workflow Triggers

The pipeline is triggered on:

- **Push** to `main`, `master`, or `develop` branches that change files in `roles/` or `playbooks/` directories
- **Pull Requests** to these branches with changes to `roles/` or `playbooks/`
- **Manual Trigger** through GitHub Actions interface for on-demand testing

## Testing Stages

The CI/CD pipeline consists of two main stages:

### 1. Individual Role Testing

Each Ansible role is tested independently to validate:
- Role installation works correctly
- Role configuration is properly applied
- Role functionally performs as expected

These tests run in parallel to speed up the testing process.

### 2. Integration Testing

After individual roles pass testing, integration tests verify that multiple roles work together:
- **LEMP Stack** - Tests Nginx, PHP, and MariaDB integration
- **Virtual Host Management** - Tests virtual host creation and configuration
- **Mail Server** - Tests mail services and webmail integration

## Running Tests Locally

To run the same tests locally before committing code, follow the instructions in [docs/molecule-admin-setup.md](molecule-admin-setup.md) and use the `run-test.sh` script from the project root:

```bash
# Ensure you are in the project root directory (e.g., ~/vps)
# Activate your Python virtual environment: source ~/molecule-env/bin/activate

# Run tests for a specific role (e.g., nginx)
bash scripts/run-test.sh nginx

# Run a specific action (e.g., converge) for the nginx role
bash scripts/run-test.sh nginx converge
```

## Test Environment

Tests run in isolated environments using either:
- GitHub Actions runners with Docker (CI/CD)
- Local WSL with AlmaLinux (development)
- Docker for Windows (alternative)
- AlmaLinux VM (alternative)

## Optimization Techniques

To keep tests fast and reliable:

1. **Parallel Execution** - Individual role tests run simultaneously
2. **Dependency Management** - Integration tests only run after role tests pass
3. **Caching** - GitHub Actions caches dependencies to speed up builds
4. **Focused Testing** - Each test focuses on specific functionality

## Test Reports

Test results are visible in GitHub Actions interface:
- Failed tests provide detailed error information
- Successful tests show verification steps passed

## Contributing Changes

When contributing changes:

1. Ensure all existing tests pass with your changes
2. Add or modify tests to cover new functionality
3. Run tests locally before submitting pull requests
4. Update documentation if tests are modified

## Future Enhancements

Planned enhancements to the CI/CD pipeline:

1. Test coverage reporting
2. Performance benchmarking
3. Automatic adminment to staging environments
4. Security scanning integration

## Self-hosted Runner (AlmaLinux) — Recommended

For full parity with development and production, use a self-hosted GitHub Actions runner on AlmaLinux (recommended). Self-hosted runners let you install Docker, systemd, and required host packages without the limitations of GitHub-hosted runners.

Quick setup (on the target AlmaLinux machine):

```bash
# Create a 'runner' user (or use an existing service account):
sudo adduser actions-runner
sudo usermod -aG docker actions-runner

# Download and install the GitHub Actions runner (replace OWNER/REPO and RUNNER_VERSION):
sudo -u actions-runner bash -c '\
    mkdir -p ~/actions-runner && cd ~/actions-runner && \
    curl -fsSL -o actions-runner.tar.gz https://github.com/actions/runner/releases/download/v2.308.0/actions-runner-linux-x64-2.308.0.tar.gz && \
    tar xzf actions-runner.tar.gz'

# Configure the runner (you will obtain the token from your GitHub repo settings -> Actions -> Runners -> New self-hosted runner):
sudo -u actions-runner ~/actions-runner/config.sh --url https://github.com/<owner>/<repo> --token <RUNNER_TOKEN> --labels "almalinux,self-hosted"

# Install as a service so it starts automatically:
sudo -u actions-runner ~/actions-runner/svc.sh install
sudo systemctl enable --now actions.runner.<owner>.<repo>.service
```

Notes:
- Ensure the runner user can `sudo` or has necessary permissions for Docker/system setup as your CI jobs expect.
- The workflow `runs-on: [self-hosted, almalinux]` will target this runner (the labels must match).
- Keep the runner updated and secure; consider running it inside a VM you control.

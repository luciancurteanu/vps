# Contributing to VPS Setup

Thank you for your interest in contributing to the VPS Setup project! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please be respectful and considerate of others when contributing to this project. We aim to foster an inclusive and welcoming community.

## How to Contribute

### Reporting Bugs

If you find a bug, please create an issue with the following information:
- A clear, descriptive title
- A detailed description of the issue
- Steps to reproduce the bug
- Expected behavior
- Actual behavior
- Screenshots (if applicable)
- Your environment details (OS, Ansible version, etc.)

### Suggesting Enhancements

For feature requests:
- Use a clear, descriptive title
- Provide a detailed description of the proposed feature
- Explain why this feature would be useful to the project
- Provide examples of how the feature would work

### Pull Requests

1. Fork the repository
2. Create a new branch (`git checkout -b feature/your-feature-name`)
3. Make your changes
4. Run tests if applicable
5. Commit your changes (`git commit -m 'Add some feature'`)
6. Push to the branch (`git push origin feature/your-feature-name`)
7. Open a Pull Request

#### Pull Request Guidelines

- Update documentation as needed
- Keep each PR focused on a single feature or bugfix
- Maintain the coding style of the project
- Write clear commit messages
- Include tests when adding new features
- Ensure all tests pass before submitting

## Development Setup

1. Clone the repository:
   ```
   git clone https://github.com/luciancurteanu/vps.git
   cd vps
   ```

2. Set up a test environment with VirtualBox or a cloud provider

## Configuration Files and Sensitive Data

This project uses a convention for handling configuration files that might contain sensitive information:

### Example Files Convention

- Configuration templates have `.example` extensions (e.g., `hosts.ini.example`)
- These example files show the structure and format without containing actual sensitive data
- Users copy these files (removing the `.example` extension) and add their own values
- The `.gitignore` file prevents committing the actual configuration files with sensitive data

When contributing:
- **NEVER** commit actual configuration files containing sensitive information
- **ALWAYS** update the corresponding `.example` file when changing configuration structures
- **AVOID** hardcoding sensitive values, use vault variables instead

### Ansible Vault

- Sensitive data should be stored in files encrypted with Ansible Vault
- The example structure is provided in `vars/secrets.yml.example`
- For development purposes, you can create a test vault with dummy values

## Testing

- Test your changes in a clean environment
- Verify that your changes work with different OS distributions
- Ensure backwards compatibility

## Style Guide

- Follow Ansible best practices
- Use 2-space indentation for YAML files
- Use descriptive variable names
- Include comments for complex sections
- Structure your code logically

Thank you for contributing to VPS Setup!
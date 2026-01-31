# Notes

Recommended hardening tasks (from ansible-lint review):

1. Fix site_management recursion/schema issues.
2. Harden top-level playbooks (FQCN, truthy values, file permissions).
3. Replace ignore_errors with failed_when where flagged.
4. Add changed_when/handlers for remaining custom commands.
5. Re-run Molecule for impacted roles (nginx, security, mail, common).
6. Fix var naming to role prefixes across roles.
7. Full FQCN sweep in roles/handlers.
8. YAML hygiene sweep (trailing spaces, EOF newlines, truthy values).

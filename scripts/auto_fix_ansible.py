#!/usr/bin/env python3
"""Conservative automatic fixer for common Ansible/YAML issues.

Rules applied (safe heuristics):
- Replace lines like `ansible.builtin.group: <value>` -> `group: <value>` (only when value is on same line).
- Replace lines like `ansible.builtin.user: <value>` -> `user: <value>` (only when value is on same line).
- Replace lines like `ansible.builtin.shell: <value>` -> `shell: <value>` (only when value is on same line).
- Normalize a few capitalized service names in `name:` lines: `Nginx` -> `nginx`, `Php-fpm.service` -> `php-fpm.service`, `Cockpit.socket` -> `cockpit.socket`.

This script is conservative and only edits YAML files under the repository root. It writes a .bak backup for each modified file.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

YAML_EXTS = {'.yml', '.yaml'}

PATTERNS = [
    (re.compile(r"^(?P<indent>\s*)ansible\.builtin\.group:\s+(?P<val>.+)$"), r"\g<indent>group: \g<val>"),
    (re.compile(r"^(?P<indent>\s*)ansible\.builtin\.user:\s+(?P<val>.+)$"), r"\g<indent>user: \g<val>"),
    (re.compile(r"^(?P<indent>\s*)ansible\.builtin\.shell:\s+(?P<val>.+)$"), r"\g<indent>shell: \g<val>"),
    # service name normalizations (only if the RHS looks like a bare service identifier)
    (re.compile(r"^(?P<indent>\s*)name:\s+Nginx\s*$"), r"\g<indent>name: nginx"),
    (re.compile(r"^(?P<indent>\s*)name:\s+Php-fpm(?:\.service)?\s*$", re.I), r"\g<indent>name: php-fpm.service"),
    (re.compile(r"^(?P<indent>\s*)name:\s+Cockpit(?:\.socket)?\s*$", re.I), r"\g<indent>name: cockpit.socket"),
]


def fix_file(path: Path) -> bool:
    text = path.read_text(encoding='utf-8')
    lines = text.splitlines()
    changed = False
    out_lines = []
    for ln in lines:
        new_ln = ln
        for pattern, repl in PATTERNS:
            m = pattern.match(new_ln)
            if m:
                new_ln = pattern.sub(repl, new_ln)
                changed = True
                break
        out_lines.append(new_ln)

    if changed:
        bak = path.with_suffix(path.suffix + '.bak')
        path.rename(bak)
        path.write_text("\n".join(out_lines) + "\n", encoding='utf-8')
        print(f"Patched: {path}  (backup saved as {bak.name})")
    return changed


def main():
    files = list(ROOT.rglob('*'))
    modified = 0
    for f in files:
        if f.is_file() and f.suffix in YAML_EXTS:
            # skip some folders (molecule state, .git)
            if any(p in f.parts for p in ('.git', 'molecule')):
                continue
            try:
                if fix_file(f):
                    modified += 1
            except Exception as e:
                print(f"Error processing {f}: {e}")

    print(f"Done. Modified {modified} file(s).")


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Fix Wave 3 ansible-lint violations: FQCN, key ordering, missing names"""

import os
import sys
import re
from pathlib import Path
import yaml

# Common ansible.builtin modules that need FQCN
BUILTIN_MODULES = {
    'command': 'ansible.builtin.command',
    'shell': 'ansible.builtin.shell',
    'copy': 'ansible.builtin.copy',
    'file': 'ansible.builtin.file',
    'template': 'ansible.builtin.template',
    'service': 'ansible.builtin.service',
    'systemd': 'ansible.builtin.systemd',
    'user': 'ansible.builtin.user',
    'group': 'ansible.builtin.group',
    'package': 'ansible.builtin.package',
    'yum': 'ansible.builtin.yum',
    'apt': 'ansible.builtin.apt',
    'dnf': 'ansible.builtin.dnf',
    'get_url': 'ansible.builtin.get_url',
    'unarchive': 'ansible.builtin.unarchive',
    'stat': 'ansible.builtin.stat',
    'find': 'ansible.builtin.find',
    'lineinfile': 'ansible.builtin.lineinfile',
    'replace': 'ansible.builtin.replace',
    'blockinfile': 'ansible.builtin.blockinfile',
    'set_fact': 'ansible.builtin.set_fact',
    'debug': 'ansible.builtin.debug',
    'fail': 'ansible.builtin.fail',
    'assert': 'ansible.builtin.assert',
    'wait_for': 'ansible.builtin.wait_for',
    'meta': 'ansible.builtin.meta',
    'include_vars': 'ansible.builtin.include_vars',
    'include_tasks': 'ansible.builtin.include_tasks',
    'import_tasks': 'ansible.builtin.import_tasks',
    'include_role': 'ansible.builtin.include_role',
    'import_role': 'ansible.builtin.import_role',
    'pause': 'ansible.builtin.pause',
    'uri': 'ansible.builtin.uri',
}

def fix_fqcn_in_task(content):
    """Add FQCN to builtin modules"""
    lines = content.split('\n')
    fixed_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        # Check if this is a module call (starts with module name followed by :)
        for short_name, fqcn in BUILTIN_MODULES.items():
            # Match lines like "  command:" or "- command:" but not "  # command:"
            pattern = rf'^(\s*-?\s*)({short_name}):\s*(.*)$'
            match = re.match(pattern, line)
            if match and not line.strip().startswith('#'):
                indent = match.group(1)
                module = match.group(2)
                rest = match.group(3)
                # Only replace if it's not already FQCN
                if '.' not in module:
                    fixed_lines.append(f"{indent}{fqcn}:{' ' + rest if rest else ''}")
                    i += 1
                    continue
        
        fixed_lines.append(line)
        i += 1
    
    return '\n'.join(fixed_lines)

def add_missing_names(content):
    """Add placeholder names to tasks missing them"""
    lines = content.split('\n')
    fixed_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        # Check if this is a task start (- with a module name)
        if re.match(r'^\s*-\s+\w+:', line) and not re.match(r'^\s*-\s+name:', line):
            # This is a task without a name
            indent_match = re.match(r'^(\s*)-\s+', line)
            if indent_match:
                indent = indent_match.group(1)
                # Extract module name
                module_match = re.search(r'-\s+([\w.]+):', line)
                if module_match:
                    module = module_match.group(1).split('.')[-1]  # Get last part of FQCN
                    # Add a name line before the task
                    fixed_lines.append(f"{indent}- name: Execute {module}")
                    # Adjust the current line to proper indentation
                    fixed_line = line.replace('- ', '  ', 1)
                    fixed_lines.append(fixed_line)
                    i += 1
                    continue
        
        fixed_lines.append(line)
        i += 1
    
    return '\n'.join(fixed_lines)

def fix_yaml_file(filepath):
    """Apply Wave 3 fixes to a YAML file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            original = f.read()
        
        if not original:
            return False
        
        # Apply fixes
        fixed = original
        fixed = fix_fqcn_in_task(fixed)
        # Note: add_missing_names can be complex, skipping for now
        
        # Only write if changed
        if fixed != original:
            with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
                f.write(fixed)
            return True
        return False
    except Exception as e:
        print(f"  Error fixing {filepath}: {e}", file=sys.stderr)
        return None

def main():
    repo_root = Path(__file__).parent.parent
    exclude_dirs = {'.git', 'temp', '.cache', '__pycache__'}
    
    fixed_count = 0
    error_count = 0
    total_count = 0
    
    print("Fixing Wave 3 issues (FQCN for builtin modules)...")
    
    # Find all YAML files
    for root, dirs, files in os.walk(repo_root):
        dirs[:] = [d for d in dirs if d not in exclude_dirs]
        
        for file in files:
            if file.endswith(('.yml', '.yaml')):
                filepath = Path(root) / file
                total_count += 1
                
                result = fix_yaml_file(filepath)
                if result is True:
                    print(f"  Fixed: {filepath.relative_to(repo_root)}")
                    fixed_count += 1
                elif result is None:
                    error_count += 1
    
    print(f"\nSummary:")
    print(f"  Files fixed: {fixed_count}")
    print(f"  Errors: {error_count}")
    print(f"  Total processed: {total_count}")
    
    return 0 if error_count == 0 else 1

if __name__ == '__main__':
    sys.exit(main())

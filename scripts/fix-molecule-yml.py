#!/usr/bin/env python3
"""Fix molecule.yml files - remove duplicate ansible.builtin.command line"""

import os
import sys
from pathlib import Path

def fix_molecule_file(filepath):
    """Remove the erroneous ansible.builtin.command line from molecule.yml"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        fixed_lines = []
        for line in lines:
            # Skip the problematic line
            if 'ansible.builtin.command:' in line:
                continue
            fixed_lines.append(line)
        
        # Only write if changed
        if len(fixed_lines) != len(lines):
            with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
                f.writelines(fixed_lines)
            return True
        return False
    except Exception as e:
        print(f"  Error fixing {filepath}: {e}", file=sys.stderr)
        return None

def main():
    repo_root = Path(__file__).parent.parent
    fixed_count = 0
    
    print("Fixing molecule.yml files...")
    
    # Find all molecule.yml files
    for molecule_file in repo_root.glob('roles/*/molecule/*/molecule.yml'):
        result = fix_molecule_file(molecule_file)
        if result is True:
            print(f"  Fixed: {molecule_file.relative_to(repo_root)}")
            fixed_count += 1
    
    print(f"\nFixed {fixed_count} molecule.yml files")
    return 0

if __name__ == '__main__':
    sys.exit(main())

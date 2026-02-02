#!/usr/bin/env python3
"""Fix Wave 1 ansible-lint violations: trailing spaces, EOF newlines"""

import os
import sys
from pathlib import Path

def fix_yaml_file(filepath):
    """Fix trailing spaces and EOF newline in a YAML file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if not content:
            return False
        
        # Split into lines and remove trailing spaces
        lines = content.splitlines()
        fixed_lines = [line.rstrip() for line in lines]
        
        # Join with newlines and ensure single EOF newline
        new_content = '\n'.join(fixed_lines) + '\n'
        
        # Only write if changed
        if new_content != content:
            with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
                f.write(new_content)
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
    
    print("Fixing YAML formatting issues...")
    
    # Find all YAML files
    for root, dirs, files in os.walk(repo_root):
        # Remove excluded directories from search
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

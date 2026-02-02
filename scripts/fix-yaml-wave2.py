#!/usr/bin/env python3
"""Fix Wave 2 ansible-lint violations: truthy values, name casing, comma spacing"""

import os
import sys
import re
from pathlib import Path

def fix_truthy_values(content):
    """Replace yes/no/on/off with true/false in YAML"""
    # Match yes/no/on/off as standalone values (not in strings)
    patterns = [
        (r':\s+yes\s*$', ': true'),
        (r':\s+no\s*$', ': false'),
        (r':\s+Yes\s*$', ': true'),
        (r':\s+No\s*$', ': false'),
        (r':\s+YES\s*$', ': true'),
        (r':\s+NO\s*$', ': false'),
        (r':\s+on\s*$', ': true'),
        (r':\s+off\s*$', ': false'),
        (r':\s+On\s*$', ': true'),
        (r':\s+Off\s*$', ': false'),
    ]
    
    lines = content.split('\n')
    fixed_lines = []
    
    for line in lines:
        fixed_line = line
        for pattern, replacement in patterns:
            fixed_line = re.sub(pattern, replacement, fixed_line)
        fixed_lines.append(fixed_line)
    
    return '\n'.join(fixed_lines)

def fix_comma_spacing(content):
    """Fix comma spacing in YAML (add space after comma)"""
    # Fix commas without space after them (but not in strings)
    # Target: key:value,key2:value2 -> key:value, key2:value2
    lines = content.split('\n')
    fixed_lines = []
    
    for line in lines:
        # Only fix in list contexts like [item1,item2] or dict contexts
        if '[' in line or '{' in line or 'tags:' in line or 'loop:' in line:
            # Add space after comma if not already present
            fixed_line = re.sub(r',(?!\s)', ', ', line)
            fixed_lines.append(fixed_line)
        else:
            fixed_lines.append(line)
    
    return '\n'.join(fixed_lines)

def fix_name_casing(content):
    """Ensure task names start with capital letter"""
    lines = content.split('\n')
    fixed_lines = []
    
    i = 0
    while i < len(lines):
        line = lines[i]
        # Match "- name: " or "  name: " at start of line
        name_match = re.match(r'^(\s*-?\s*name:\s+)(.+)$', line)
        if name_match:
            indent = name_match.group(1)
            name_text = name_match.group(2)
            
            # Only capitalize if it starts with lowercase letter
            if name_text and name_text[0].islower():
                fixed_name = name_text[0].upper() + name_text[1:]
                fixed_lines.append(f"{indent}{fixed_name}")
            else:
                fixed_lines.append(line)
        else:
            fixed_lines.append(line)
        i += 1
    
    return '\n'.join(fixed_lines)

def fix_yaml_file(filepath):
    """Apply Wave 2 fixes to a YAML file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            original = f.read()
        
        if not original:
            return False
        
        # Apply all fixes
        fixed = original
        fixed = fix_truthy_values(fixed)
        fixed = fix_comma_spacing(fixed)
        fixed = fix_name_casing(fixed)
        
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
    
    print("Fixing Wave 2 issues (truthy, casing, commas)...")
    
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

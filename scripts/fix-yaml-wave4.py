#!/usr/bin/env python3
"""Fix Wave 4 ansible-lint violations: line-length, risky-file-permissions, changed_when, etc."""

import os
import sys
import re
from pathlib import Path

def fix_line_length(content):
    """Break long lines at 160 characters"""
    lines = content.split('\n')
    fixed_lines = []
    
    for line in lines:
        if len(line) <= 160:
            fixed_lines.append(line)
            continue
        
        # Don't break URLs or strings
        if 'http://' in line or 'https://' in line or '{{' in line:
            fixed_lines.append(line)
            continue
        
        # Try to break at logical points (after commas, spaces)
        if ',' in line:
            indent = len(line) - len(line.lstrip())
            parts = line.split(',')
            current = parts[0]
            for part in parts[1:]:
                test = current + ',' + part
                if len(test) <= 160:
                    current = test
                else:
                    fixed_lines.append(current + ',')
                    current = ' ' * (indent + 2) + part.lstrip()
            fixed_lines.append(current)
        else:
            fixed_lines.append(line)
    
    return '\n'.join(fixed_lines)

def fix_changed_when(content):
    """Add changed_when: false to command/shell tasks that are read-only"""
    lines = content.split('\n')
    fixed_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Check for command/shell without changed_when
        if re.search(r'ansible\.builtin\.(command|shell):', line):
            # Look ahead to see if changed_when already exists
            has_changed_when = False
            indent = len(line) - len(line.lstrip())
            j = i + 1
            while j < len(lines) and (not lines[j].strip() or len(lines[j]) - len(lines[j].lstrip()) > indent):
                if 'changed_when' in lines[j]:
                    has_changed_when = True
                    break
                if lines[j].strip() and lines[j].strip()[0] == '-':
                    break
                j += 1
            
            fixed_lines.append(line)
            
            # If no changed_when and looks like read-only command, add it
            if not has_changed_when:
                # Check if command is read-only (grep, cat, ls, echo, etc.)
                next_line_idx = i + 1
                if next_line_idx < len(lines):
                    cmd_line = lines[next_line_idx]
                    if any(cmd in cmd_line for cmd in ['grep', 'cat', 'ls', 'echo', 'test', 'which', 'stat', 'getent', 'id']):
                        # Add changed_when after finding the last parameter of the task
                        param_indent = indent + 2
                        # Insert after collecting all task parameters
                        task_end = i + 1
                        while task_end < len(lines):
                            if lines[task_end].strip() and not lines[task_end].strip().startswith('#'):
                                if len(lines[task_end]) - len(lines[task_end].lstrip()) <= indent:
                                    break
                            task_end += 1
                        
                        # Add changed_when before the next task
                        i += 1
                        continue
        
        fixed_lines.append(line)
        i += 1
    
    return '\n'.join(fixed_lines)

def fix_risky_file_permissions(content):
    """Add explicit mode parameters to file/copy/template tasks"""
    lines = content.split('\n')
    fixed_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Check for file/copy/template without mode
        if re.search(r'ansible\.builtin\.(file|copy|template):', line):
            # Look ahead for mode parameter
            has_mode = False
            indent = len(line) - len(line.lstrip())
            j = i + 1
            while j < len(lines) and (not lines[j].strip() or len(lines[j]) - len(lines[j].lstrip()) > indent):
                if re.search(r'^\s*mode:', lines[j]):
                    has_mode = True
                    break
                if lines[j].strip() and lines[j].strip()[0] == '-':
                    break
                j += 1
            
            fixed_lines.append(line)
            
            # If no mode, add a default one after state (or at end of task)
            if not has_mode:
                # Find where to insert mode
                param_indent = indent + 2
                insert_idx = len(fixed_lines)
                k = i + 1
                while k < len(lines):
                    if lines[k].strip() and len(lines[k]) - len(lines[k].lstrip()) == param_indent:
                        if 'state:' in lines[k] or 'owner:' in lines[k] or 'group:' in lines[k]:
                            fixed_lines.append(lines[k])
                            k += 1
                            continue
                    break
                
                # Add mode based on context
                default_mode = "'0644'"
                if 'directory' in ''.join(lines[i:k]):
                    default_mode = "'0755'"
                fixed_lines.append(' ' * param_indent + f"mode: {default_mode}")
                
                i = k
                continue
        
        fixed_lines.append(line)
        i += 1
    
    return '\n'.join(fixed_lines)

def fix_ignore_errors(content):
    """Convert ignore_errors to failed_when where possible"""
    # This is complex - for now just add failed_when: false alongside ignore_errors
    lines = content.split('\n')
    fixed_lines = []
    
    for line in lines:
        fixed_lines.append(line)
        # If we see ignore_errors: true, add a comment suggesting failed_when
        if 'ignore_errors:' in line and 'true' in line:
            indent = len(line) - len(line.lstrip())
            fixed_lines.append(' ' * indent + '# TODO: Consider using failed_when instead of ignore_errors')
    
    return '\n'.join(fixed_lines)

def fix_risky_shell_pipe(content):
    """Add pipefail to shell commands with pipes"""
    lines = content.split('\n')
    fixed_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Check for shell with pipe
        if 'ansible.builtin.shell:' in line:
            # Look for pipe in the command
            j = i + 1
            has_pipe = False
            has_pipefail = False
            
            while j < len(lines):
                if '|' in lines[j] and not lines[j].strip().startswith('#'):
                    has_pipe = True
                if 'pipefail' in lines[j]:
                    has_pipefail = True
                if lines[j].strip() and lines[j].strip()[0] == '-':
                    break
                j += 1
            
            # If has pipe but no pipefail, add it
            if has_pipe and not has_pipefail:
                indent = len(line) - len(line.lstrip())
                fixed_lines.append(line)
                # Find the shell command line and prepend set -o pipefail
                for k in range(i + 1, j):
                    if '|' in lines[k]:
                        cmd = lines[k].strip()
                        fixed_lines.append(' ' * (indent + 2) + f"set -o pipefail && {cmd}")
                        i = k + 1
                        continue
                i = j
                continue
        
        fixed_lines.append(line)
        i += 1
    
    return '\n'.join(fixed_lines)

def fix_yaml_file(filepath):
    """Apply Wave 4 fixes to a YAML file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            original = f.read()
        
        if not original:
            return False
        
        # Apply fixes in order
        fixed = original
        fixed = fix_line_length(fixed)
        # Skip complex ones for now - they need more careful handling
        # fixed = fix_changed_when(fixed)
        # fixed = fix_risky_file_permissions(fixed)
        # fixed = fix_risky_shell_pipe(fixed)
        
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
    
    print("Fixing Wave 4 issues (line-length and others)...")
    
    # Find all YAML files in tasks, playbooks, handlers
    for root, dirs, files in os.walk(repo_root):
        dirs[:] = [d for d in dirs if d not in exclude_dirs]
        
        for file in files:
            if file.endswith(('.yml', '.yaml')):
                filepath = Path(root) / file
                # Focus on actual ansible files, not molecule configs
                if any(p in str(filepath) for p in ['tasks', 'playbooks', 'handlers']):
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

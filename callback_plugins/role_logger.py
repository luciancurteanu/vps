#!/usr/bin/env python3
"""
Ansible callback plugin to log role execution details.
Logs role start, completion, and duration to both stdout and a log file.
"""

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from datetime import datetime
from ansible.plugins.callback import CallbackBase
import os

DOCUMENTATION = '''
    callback: role_logger
    type: notification
    short_description: Logs role execution details
    description:
        - Logs when roles start and complete
        - Records role duration
        - Writes to both stdout and log file
    requirements:
        - Enable in ansible.cfg with callback_whitelist
'''


class CallbackModule(CallbackBase):
    """
    Callback plugin to log role execution.
    """
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'role_logger'

    def __init__(self):
        super(CallbackModule, self).__init__()
        self.role_start_times = {}
        self.log_file = None
        self._setup_log_file()

    def _setup_log_file(self):
        """Setup the log file for role execution tracking."""
        log_dir = os.path.join(os.getcwd(), 'logs')
        if not os.path.exists(log_dir):
            os.makedirs(log_dir)
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        log_filename = f'vps-roles-{timestamp}.log'
        self.log_file = os.path.join(log_dir, log_filename)
        
        # Create a symlink to the latest log
        latest_link = os.path.join(log_dir, 'latest-roles.log')
        if os.path.exists(latest_link):
            os.remove(latest_link)
        try:
            os.symlink(log_filename, latest_link)
        except (OSError, AttributeError):
            # Windows or symlink not supported, just skip
            pass

    def _log(self, message):
        """Write message to both stdout and log file."""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        log_message = f"[{timestamp}] {message}"
        
        # Write to stdout
        self._display.display(log_message, color='cyan')
        
        # Write to file
        try:
            with open(self.log_file, 'a') as f:
                f.write(log_message + '\n')
        except Exception as e:
            self._display.warning(f"Failed to write to log file: {e}")

    def v2_playbook_on_role_start(self, role_name, role_path):
        """Called when a role starts."""
        self.role_start_times[role_name] = datetime.now()
        self._log(f"▶ ROLE START: {role_name}")

    def v2_playbook_on_task_start(self, task, is_conditional):
        """Track role completion via task metadata."""
        # Check if this is the last task in a role
        role_name = task._role.get_name() if task._role else None
        if role_name and role_name in self.role_start_times:
            # We can't detect exact role end, but we log task progress
            pass

    def v2_runner_on_ok(self, result):
        """Track successful task completion."""
        task_name = result._task.get_name()
        role_name = result._task._role.get_name() if result._task._role else None
        
        # Log important role tasks
        if role_name and 'include_role' not in task_name:
            # Check if this looks like a role completion task
            if any(keyword in task_name.lower() for keyword in ['complete', 'finish', 'installed', 'configured']):
                if role_name in self.role_start_times:
                    start_time = self.role_start_times[role_name]
                    duration = (datetime.now() - start_time).total_seconds()
                    self._log(f"✓ ROLE COMPLETE: {role_name} (duration: {duration:.2f}s)")
                    del self.role_start_times[role_name]

    def v2_playbook_on_stats(self, stats):
        """Called when playbook finishes - log any uncompleted roles."""
        self._log("=" * 60)
        self._log("PLAYBOOK EXECUTION SUMMARY")
        self._log("=" * 60)
        
        # Log any roles that started but didn't explicitly complete
        for role_name, start_time in self.role_start_times.items():
            duration = (datetime.now() - start_time).total_seconds()
            self._log(f"✓ ROLE COMPLETE: {role_name} (duration: {duration:.2f}s)")
        
        self._log(f"Log file: {self.log_file}")

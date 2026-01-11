# Combined History Logging - User Guide

**Version:** 2.0.0
**Script:** `combined.history.sh`
**Author:** Adam Compton
**Last Updated:** 2025-12-29

---

## Table of Contents

1. [Overview](#overview)
2. [Features](#features)
3. [Platform Compatibility](#platform-compatibility)
4. [Requirements](#requirements)
5. [Installation](#installation)
6. [Configuration](#configuration)
7. [Usage](#usage)
8. [Functions Reference](#functions-reference)
9. [Troubleshooting](#troubleshooting)
10. [Security Considerations](#security-considerations)
11. [Performance Tuning](#performance-tuning)
12. [Examples](#examples)
13. [FAQ](#faq)

---

## Overview

`combined.history.sh` is a comprehensive command logging solution for Bash and Zsh shells. It automatically logs all interactive shell commands to a centralized log file with timestamps, session information, and optional syslog integration. The script also provides `trace_run()` functionality for tracing entire script executions.

### Key Benefits

- **Unified logging** across Bash and Zsh
- **Security hardened** against command injection
- **Cross-platform** support (Linux, macOS, WSL2)
- **Session tracking** (tmux, screen, tty)
- **Audit trail** for compliance and debugging
- **Script tracing** with detailed execution logs

---

## Features

### Core Features

- ✅ **Automatic Command Logging**: Every command executed in interactive shells is logged
- ✅ **Timestamp Recording**: Precise timestamps for all commands
- ✅ **Session Detection**: Tracks tmux, screen, and tty sessions
- ✅ **Duplicate Suppression**: Optional filtering of repeated commands
- ✅ **Syslog Integration**: Optional logging to system syslog
- ✅ **Log Rotation**: Optional logrotate integration
- ✅ **File Locking**: Safe concurrent access with flock or fallback mechanism
- ✅ **Script Tracing**: `trace_run()` function for detailed script execution logs

### Security Features

- 🔒 **Command Sanitization**: Prevents command injection in log files
- 🔒 **Secure File Permissions**: Logs created with 0600 permissions
- 🔒 **Input Validation**: All dangerous characters escaped
- 🔒 **Lock File Cleanup**: Automatic cleanup on exit, interrupt, or termination

### Performance Features

- ⚡ **Optimized tmux Calls**: Single call instead of three
- ⚡ **Efficient String Operations**: Parameter expansion over external commands
- ⚡ **Smart Locking**: Uses flock on Linux, efficient fallback on macOS

---

## Platform Compatibility

### Supported Platforms

| Platform | Bash 4.2+ | Zsh 5.0+ | Notes |
|----------|-----------|----------|-------|
| **Linux** | ✅ | ✅ | All features supported natively |
| **macOS** | ✅ | ✅ | flock not available (fallback works) |
| **WSL2** | ✅ | ✅ | May need SYSLOG_ENABLED=false |

### Platform-Specific Notes

#### macOS
- **flock not available by default**
  - Script automatically falls back to `basic_lock()` mechanism
  - For better performance: `brew install flock`
- All other functionality works natively
- Uses BSD versions of `mktemp`, `logger`, `date`, etc. (fully compatible)

#### WSL2
- Behaves identically to Linux
- Syslog daemon may not be running by default
- If syslog errors occur: `export SYSLOG_ENABLED=false` before sourcing

#### Linux
- All features work optimally
- Uses `flock` for efficient file locking
- Native syslog support

---

## Requirements

### Minimum Requirements

- **Bash:** Version 4.2 or newer
- **Zsh:** Version 5.0 or newer
- **Disk Space:** ~10-50MB for log files (depending on usage)

### Optional Dependencies

- `flock` - For efficient file locking (Linux/WSL2 have it; macOS: `brew install flock`)
- `logger` - For syslog integration (usually pre-installed)
- `tmux` or `screen` - For session tracking (optional)
- `logrotate` - For automatic log rotation (optional)

### Checking Your Shell Version

```bash
# Bash version
bash --version | head -n1

# Zsh version
zsh --version
```

---

## Installation

### Quick Start

1. **Download the script:**
   ```bash
   cd ~/
   wget https://example.com/combined.history.sh
   # or
   curl -O https://example.com/combined.history.sh
   ```

2. **Make it executable:**
   ```bash
   chmod +x combined.history.sh
   ```

3. **Source it in your shell configuration:**

   **For Bash** (add to `~/.bashrc` or `~/.bash_profile`):
   ```bash
   source ~/combined.history.sh
   ```

   **For Zsh** (add to `~/.zshrc`):
   ```bash
   source ~/combined.history.sh
   ```

4. **Reload your shell:**
   ```bash
   # For Bash
   source ~/.bashrc

   # For Zsh
   source ~/.zshrc
   ```

### Verification

After installation, verify it's working:

```bash
# Run a test command
echo "test command"

# Check the log file
tail ~/.combined.history.log
```

You should see an entry like:
```
[2025-12-29 10:30:45] (bash) tty(pid):pts/0(12345) # echo "test command"
```

---

## Configuration

### Environment Variables

Set these **before** sourcing the script:

#### Log File Location

```bash
# Custom log directory
export LOG_HISTORY_DIR="/var/log/myapp"
source ~/combined.history.sh

# Default: ~/.combined.history.log
```

#### Feature Toggles

```bash
# Disable syslog (useful for WSL2 or systems without syslog)
export SYSLOG_ENABLED=false

# Enable self-test on startup
export RUN_LOGGING_SELFTEST=true
```

### In-Script Configuration

Edit these variables in the script (lines 155-189):

#### Basic Configuration

```bash
# Enable duplicate command suppression
SUPPRESS_DUPLICATES=true

# Enable syslog integration
SYSLOG_ENABLED=true

# Syslog facility
SYSLOG_FACILITY="local1"

# Syslog severity
SYSLOG_SEVERITY="notice"
```

#### Logrotate Configuration

```bash
# Enable logrotate integration
USE_LOGROTATE=false

# Auto-create logrotate config
AUTO_SETUP_LOGROTATE=false

# Logrotate directory
LOGROTATE_DIR="/etc/logrotate.d"

# Max log size before rotation
LOGROTATE_ROTATE_SIZE="10M"

# Number of rotated logs to keep
LOGROTATE_ROTATE_COUNT=10
```

---

## Usage

### Automatic Command Logging

Once sourced, all commands are logged automatically:

```bash
$ ls -la
$ cd /tmp
$ cat file.txt
```

Log entries:
```
[2025-12-29 10:35:12] (bash) tmux:session1(0:1) # ls -la
[2025-12-29 10:35:15] (bash) tmux:session1(0:1) # cd /tmp
[2025-12-29 10:35:18] (bash) tmux:session1(0:1) # cat file.txt
```

### Manual Script Tracing with trace_run()

Trace entire script execution with detailed logging:

```bash
# Trace a script
trace_run ./my_script.sh arg1 arg2

# Output
Tracing ./my_script.sh → ~/.combined.history.log.20251229_103520.my_script.sh.12345.trace
```

This creates two logs:
1. **Main log** (`~/.combined.history.log`) - Summary entries
2. **Trace log** (`~/.combined.history.log.20251229_103520.my_script.sh.12345.trace`) - Detailed execution

### Viewing Logs

```bash
# View recent commands
tail -f ~/.combined.history.log

# View last 50 commands
tail -n 50 ~/.combined.history.log

# Search for specific commands
grep "git commit" ~/.combined.history.log

# View commands from a specific date
grep "2025-12-29" ~/.combined.history.log

# View commands from a specific session
grep "tmux:session1" ~/.combined.history.log
```

### Testing the Setup

```bash
# Run self-test
export RUN_LOGGING_SELFTEST=true
source ~/combined.history.sh

# Manual test
test_logging_setup
```

---

## Functions Reference

### Public Functions

#### `trace_run <script> [args...]`

Runs a script under tracing, logging each command execution.

**Usage:**
```bash
trace_run ./deploy.sh production
trace_run /path/to/script.sh --flag value
```

**Return Values:**
- `0` - Success (returns script's exit code)
- `1` - Invalid arguments
- `2` - Script not found/readable
- `3` - Failed to create trace file

**Example:**
```bash
$ trace_run ./backup.sh /data
Tracing ./backup.sh → ~/.combined.history.log.20251229_103520.backup.sh.12345.trace

$ echo $?
0
```

#### `test_logging_setup`

Validates the logging configuration.

**Usage:**
```bash
test_logging_setup
```

**Checks:**
- ✓ Log file exists and is writable
- ✓ flock availability
- ✓ Syslog functionality
- ✓ Logrotate configuration
- ✓ Ability to write log entries

**Example:**
```bash
$ test_logging_setup
========== Testing Logging Setup ==========
[+ PASS  ] Log file exists and is writable: /home/user/.combined.history.log
[+ PASS  ] flock is available on this system.
[* INFO  ] Syslog integration is disabled.
[* INFO  ] Logrotate integration is disabled.
[+ PASS  ] Successfully wrote test log entry to /home/user/.combined.history.log
========== Logging Setup Test Completed ==========
```

### Internal Functions

These are used internally but documented for reference:

- `get_session_info()` - Detects current session (tmux/screen/tty)
- `get_shell()` - Returns current shell type (bash/zsh)
- `get_command()` - Retrieves last executed command
- `sanitize_log_string()` - Escapes dangerous characters
- `write_log_entry()` - Writes to log file with locking
- `write_to_syslog()` - Sends entry to syslog
- `ensure_history_file()` - Creates log file with correct permissions

---

## Troubleshooting

### Common Issues

#### 1. Log File Not Created

**Symptom:** No `~/.combined.history.log` file appears

**Solutions:**
```bash
# Check permissions
ls -la ~/

# Manually test
ensure_history_file

# Check error messages
tail -n 50 ~/.bashrc  # or ~/.zshrc
```

#### 2. Permission Denied Errors

**Symptom:** `Failed to create log directory` or `Failed to set permissions`

**Solutions:**
```bash
# Use custom log directory
export LOG_HISTORY_DIR="${HOME}/logs"
mkdir -p "${HOME}/logs"
source ~/combined.history.sh

# Check ownership
ls -la ~/.combined.history.log
```

#### 3. flock Warning on macOS

**Symptom:** `flock not found. Script will fallback to basic lock logic.`

**Solution (optional - improves performance):**
```bash
brew install flock
```

**Note:** The script works fine without flock; this is just for optimization.

#### 4. Syslog Errors on WSL2

**Symptom:** `Failed to write to syslog`

**Solution:**
```bash
# Disable syslog before sourcing
export SYSLOG_ENABLED=false
source ~/combined.history.sh
```

#### 5. Commands Not Being Logged

**Symptoms:**
- Log file exists but is empty
- Recent commands don't appear

**Diagnostics:**
```bash
# Check if script is loaded
declare -f log_command_unified

# For Bash - check trap
trap -p DEBUG

# For Zsh - check precmd_functions
echo "${precmd_functions[@]}"

# Run self-test
test_logging_setup

# Check for errors
grep -i error ~/.combined.history.log
```

#### 6. Duplicate Commands Being Logged

**Symptom:** Same command appears multiple times

**Solution:**
```bash
# Edit the script and ensure:
SUPPRESS_DUPLICATES=true
```

#### 7. Lock File Issues

**Symptom:** `Could not acquire lock. Skipping log entry.`

**Solutions:**
```bash
# Check for stale lock files
ls -la ~/.combined.history.log.lock

# Remove stale lock (if shell crashed)
rm -f ~/.combined.history.log.lock

# Verify cleanup trap is working
trap -p EXIT INT TERM  # Bash
```

---

## Security Considerations

### Log File Protection

The script automatically sets restrictive permissions:

```bash
# Log files created with 0600 (owner read/write only)
ls -la ~/.combined.history.log
# Output: -rw------- 1 user user 12345 Dec 29 10:30 .combined.history.log
```

### Sensitive Commands

**⚠️ WARNING:** This script logs ALL commands, including those containing:
- Passwords
- API keys
- Tokens
- Secrets

### Best Practices

1. **Never type secrets in commands:**
   ```bash
   # BAD - Password logged!
   mysql -u root -pSECRETPASSWORD

   # GOOD - Password not in command
   mysql -u root -p
   # (enter password when prompted)
   ```

2. **Use environment variables or files for secrets:**
   ```bash
   # Good practices
   export DB_PASS=$(cat ~/.db_password)
   mysql -u root -p"${DB_PASS}"

   # Or use a config file
   mysql --defaults-file=~/.my.cnf
   ```

3. **Regular log rotation:**
   ```bash
   # Enable logrotate to limit log retention
   USE_LOGROTATE=true
   AUTO_SETUP_LOGROTATE=true
   ```

4. **Restrict log file access:**
   ```bash
   # Logs are already 0600, but verify
   chmod 600 ~/.combined.history.log
   ```

5. **Consider excluding sensitive patterns:**

   You can modify `log_command_unified()` to skip certain patterns:
   ```bash
   # Add to log_command_unified() after line 428
   case "${command}" in
       *password*|*secret*|*token*|*api_key*)
           return  # Don't log sensitive commands
           ;;
   esac
   ```

---

## Performance Tuning

### Log File Size Management

```bash
# Check current log size
ls -lh ~/.combined.history.log

# Enable logrotate for automatic management
USE_LOGROTATE=true
LOGROTATE_ROTATE_SIZE="10M"
LOGROTATE_ROTATE_COUNT=10
```

### Manual Log Cleanup

```bash
# Archive old logs
gzip ~/.combined.history.log
mv ~/.combined.history.log.gz ~/archive/

# Or truncate
> ~/.combined.history.log

# Keep only recent entries
tail -n 10000 ~/.combined.history.log > /tmp/recent.log
mv /tmp/recent.log ~/.combined.history.log
```

### Optimizing for High-Volume Environments

```bash
# Disable syslog for better performance
SYSLOG_ENABLED=false

# Enable duplicate suppression
SUPPRESS_DUPLICATES=true

# Install flock on macOS for better locking
brew install flock
```

### Monitoring Performance Impact

```bash
# Time a command with logging
time ls -la

# Disable logging temporarily
unset -f log_command_unified  # Bash
# or
precmd_functions=("${precmd_functions[@]:#log_command_unified}")  # Zsh

# Re-enable by re-sourcing
source ~/combined.history.sh
```

---

## Examples

### Example 1: Basic Daily Usage

```bash
# Your .bashrc
source ~/combined.history.sh

# Your commands are automatically logged
$ cd /var/www
$ git pull origin main
$ sudo systemctl restart nginx

# View your command history
$ tail ~/.combined.history.log
[2025-12-29 14:23:10] (bash) tmux:work(0:0) # cd /var/www
[2025-12-29 14:23:15] (bash) tmux:work(0:0) # git pull origin main
[2025-12-29 14:23:22] (bash) tmux:work(0:0) # sudo systemctl restart nginx
```

### Example 2: Tracing a Deployment Script

```bash
# Create a deployment script
$ cat > deploy.sh << 'EOF'
#!/bin/bash
set -e

echo "Starting deployment..."
git pull origin main
npm install
npm run build
pm2 restart app
echo "Deployment complete!"
EOF

$ chmod +x deploy.sh

# Trace the deployment
$ trace_run ./deploy.sh
Tracing ./deploy.sh → ~/.combined.history.log.20251229_142530.deploy.sh.12345.23456.trace

# View detailed trace log
$ cat ~/.combined.history.log.20251229_142530.deploy.sh.12345.23456.trace
[2025-12-29 14:25:30] (bash) tmux:work(0:0) # echo 'Starting deployment...'
Starting deployment...
[2025-12-29 14:25:30] (bash) tmux:work(0:0) # git pull origin main
Already up to date.
[2025-12-29 14:25:31] (bash) tmux:work(0:0) # npm install
...
[2025-12-29 14:25:35] (bash) tmux:work(0:0) # trace_run exit code: 0
```

### Example 3: Security Audit

```bash
# Find all sudo commands in the last week
grep "sudo" ~/.combined.history.log | grep "$(date +%Y-%m-%d)"

# Find who accessed a specific file
grep "/etc/passwd" ~/.combined.history.log

# Find commands run during specific time range
grep "2025-12-29 14:" ~/.combined.history.log
```

### Example 4: Custom Configuration for Different Environments

```bash
# Development environment (.bashrc on dev machine)
export LOG_HISTORY_DIR="${HOME}/dev-logs"
export SYSLOG_ENABLED=false
source ~/combined.history.sh

# Production environment (.bashrc on production)
export LOG_HISTORY_DIR="/var/log/production-history"
export SYSLOG_ENABLED=true
export SYSLOG_FACILITY="local1"
source ~/combined.history.sh
```

### Example 5: Log Analysis

```bash
# Most used commands
awk -F'#' '{print $2}' ~/.combined.history.log | awk '{print $1}' | sort | uniq -c | sort -rn | head -20

# Commands by hour of day
awk -F'[][]' '{print $2}' ~/.combined.history.log | awk '{print $2}' | cut -d: -f1 | sort | uniq -c

# Find long-running commands (if you're also logging durations)
# This requires custom modifications to the script

# Export to CSV for analysis
awk -F'[][]|#' '{print $2","$3","$4}' ~/.combined.history.log > history.csv
```

---

## FAQ

### General Questions

**Q: Does this slow down my shell?**
A: Minimal impact. Commands execute normally; logging happens asynchronously after execution.

**Q: Can I disable logging temporarily?**
A: Yes, for Bash: `trap - DEBUG`. For Zsh: remove from `precmd_functions`. Re-source to re-enable.

**Q: Does it work in non-interactive shells (scripts)?**
A: No, only interactive shells log automatically. Use `trace_run()` for scripts.

**Q: Can I use this with existing shell history?**
A: Yes, this supplements (doesn't replace) native history (`~/.bash_history`, `~/.zsh_history`).

### Technical Questions

**Q: Why use file descriptor 200?**
A: Chosen to avoid conflicts with common descriptors (0-9). Supported in both Bash 4.2+ and Zsh 5.0+.

**Q: How does locking work?**
A: Uses `flock` on Linux/WSL2 for atomic locking. Falls back to PID-based locking on macOS.

**Q: What happens if the log file is deleted?**
A: It's automatically recreated on the next command with proper permissions.

**Q: Can multiple shells write to the same log?**
A: Yes, file locking ensures safe concurrent writes.

### Platform-Specific Questions

**Q: Do I need flock on macOS?**
A: No, the fallback mechanism works fine. flock just improves performance slightly.

**Q: Why doesn't syslog work on WSL2?**
A: WSL2 may not have a syslog daemon running by default. Disable with `SYSLOG_ENABLED=false`.

**Q: Does this work in Git Bash on Windows?**
A: Not tested. Designed for native Bash/Zsh on Unix-like systems.

### Security Questions

**Q: Are passwords in commands visible in logs?**
A: Yes! Never put passwords in command-line arguments. Use prompts or config files.

**Q: Can other users read my logs?**
A: No, logs are created with 0600 permissions (owner-only read/write).

**Q: What if I accidentally logged a secret?**
A: Edit the log file immediately and remove the entry. Consider rotating the secret.

### Customization Questions

**Q: Can I change the log format?**
A: Yes, modify the `log_line` format in `log_command_unified()` (line 438).

**Q: Can I filter which commands get logged?**
A: Yes, add filtering logic in `log_command_unified()` before calling `write_log_entry()`.

**Q: Can I send logs to a remote server?**
A: Yes, configure syslog to forward to a remote syslog server, or modify `write_log_entry()`.

---

## Additional Resources

### Log Analysis Tools

```bash
# Install common log analysis tools
sudo apt install goaccess  # Web log analyzer
sudo apt install lnav      # Advanced log viewer

# Use with combined history
lnav ~/.combined.history.log
```

### Integration with Existing Tools

```bash
# Send to Elasticsearch
tail -f ~/.combined.history.log | while read line; do
    curl -X POST "localhost:9200/shell-history/_doc" -H 'Content-Type: application/json' -d"{\"log\":\"${line}\"}"
done

# Send to Splunk
# Configure Splunk universal forwarder to monitor ~/.combined.history.log
```

### Backup Strategies

```bash
# Daily backup script
#!/bin/bash
DATE=$(date +%Y%m%d)
cp ~/.combined.history.log ~/backups/history-${DATE}.log
gzip ~/backups/history-${DATE}.log

# Keep only last 30 days
find ~/backups -name "history-*.log.gz" -mtime +30 -delete
```

---

## Support and Contributing

### Getting Help

1. Check this documentation
2. Run `test_logging_setup` for diagnostics
3. Review script comments for implementation details

### Reporting Issues

When reporting issues, include:
- Shell type and version (`bash --version` or `zsh --version`)
- Operating system (`uname -a`)
- Output of `test_logging_setup`
- Relevant error messages
- Steps to reproduce

### Version History

- **v2.0.0** (2025-12-29) - Security hardening, cross-platform compatibility
- **v1.0.0** (2025-07-04) - Initial unified Bash/Zsh version

---

## License

Refer to the script header for license information.

---

## Changelog

### Version 2.0.0 (2025-12-29)

**Security Improvements:**
- Enhanced command sanitization (prevents command injection)
- Fixed command injection vulnerability in write_log_entry
- Eliminated TOCTOU vulnerability in logrotate config creation
- Added cleanup traps for SIGINT/SIGTERM

**Cross-Platform Compatibility:**
- Fixed PIPESTATUS bug for Zsh compatibility
- Fixed mktemp for macOS compatibility
- Optimized tmux session detection (67% fewer process spawns)
- Documented platform-specific behaviors

**Performance Optimizations:**
- Single tmux call instead of three separate calls
- Parameter expansion instead of sed for string operations
- Extracted duplicate grep logic into helper function

**Code Quality:**
- Added version tracking
- Comprehensive function documentation
- Removed dead code
- Consistent error handling
- All variables properly quoted

---

**End of Documentation**

For the latest version and updates, check the script header and version information.

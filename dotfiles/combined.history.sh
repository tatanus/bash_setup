#!/usr/bin/env bash
# shellcheck disable=SC2154 # pipestatus is zsh-specific, set by the shell
# shellcheck disable=SC2034 # Test function variables used for validation patterns
# =============================================================================
# NAME        : combined.history.sh
# DESCRIPTION : Logs commands in Bash and Zsh interactive shells.
#               Also includes trace_run for logging entire script executions.
#               Version 2 - Security hardened and performance optimized
# AUTHOR      : Adam Compton
# DATE CREATED: 2025-07-04
# VERSION     : 2.0.0
# =============================================================================
# PLATFORM COMPATIBILITY:
#   - Bash 4.2+ on Linux, macOS, WSL2
#   - Zsh 5.0+ on Linux, macOS, WSL2
#
# PLATFORM-SPECIFIC NOTES:
#   macOS:
#     - flock is NOT available by default (falls back to basic_lock)
#     - For better performance: brew install flock
#     - All other functionality works natively
#
#   WSL2:
#     - Behaves like Linux
#     - May need SYSLOG_ENABLED=false if syslog daemon not running
#     - Set in environment before sourcing: export SYSLOG_ENABLED=false
#
#   Linux:
#     - All features supported natively
#     - flock available for efficient file locking
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2025-07-04           | Adam Compton | Unified Bash/Zsh version with trace_run
# 2025-12-29           | Adam Compton | Security hardening, performance optimization,
#                      |              | cross-platform compatibility fixes
# =============================================================================

# =============================================================================
# Version Information
# =============================================================================
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="combined.history.sh"

# =============================================================================
# Magic Constants
# =============================================================================
readonly TRACE_PREFIX="+TRACE+ "
readonly MIN_BASH_VERSION=4
readonly MIN_BASH_MINOR=2
readonly MIN_ZSH_VERSION=5

# =============================================================================
# Determine how to exit this script
#
# We set EXIT_OR_RETURN to either:
# - "exit"   → if the script is run directly
# - "return" → if the script is sourced
#
# This way, error checks can safely terminate the script in both contexts.
# =============================================================================

EXIT_OR_RETURN="exit"

if [[ -n "${BASH_VERSION:-}" ]]; then
    # Bash provides BASH_SOURCE, which differs when sourced
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
        EXIT_OR_RETURN="return"
    fi
elif [[ -n "${ZSH_VERSION:-}" ]]; then
    # In Zsh, ZSH_EVAL_CONTEXT indicates how the code is being run.
    # Examples:
    #   file:toplevel → script executed directly
    #   file:function → script sourced
    #
    # In Zsh, if ZSH_EVAL_CONTEXT is unset or contains ":file",
    # the script is sourced rather than executed directly.
    if [[ -z "${ZSH_EVAL_CONTEXT:-}" || "${ZSH_EVAL_CONTEXT}" == *:file* ]]; then
        EXIT_OR_RETURN="return"
    fi
else
    # Unknown shell — safest to default to exit
    EXIT_OR_RETURN="exit"
fi

# =============================================================================
# Check minimum shell versions
# =============================================================================

if [[ -n "${BASH_VERSION:-}" ]]; then
    # Check for minimum Bash version (4.2+ required)
    if ((BASH_VERSINFO[0] < MIN_BASH_VERSION || (BASH_VERSINFO[0] == MIN_BASH_VERSION && BASH_VERSINFO[1] < MIN_BASH_MINOR))); then
        printf '[! FAIL  ] Bash %d.%d or newer is required.\n' "${MIN_BASH_VERSION}" "${MIN_BASH_MINOR}" >&2
        "${EXIT_OR_RETURN}" 1
    fi

elif [[ -n "${ZSH_VERSION:-}" ]]; then
    # Extract the major version safely
    zsh_major="${ZSH_VERSION%%.*}"
    if [[ -z "${zsh_major}" ]] || ((zsh_major < MIN_ZSH_VERSION)); then
        printf '[! FAIL  ] Zsh %d.0 or newer is required.\n' "${MIN_ZSH_VERSION}" >&2
        "${EXIT_OR_RETURN}" 1
    fi

else
    printf '[! FAIL  ] Unknown shell. This script supports Bash or Zsh only.\n' >&2
    "${EXIT_OR_RETURN}" 1
fi

# =============================================================================
# Fallback logging if logger not provided
# =============================================================================
if ! declare -f info  > /dev/null; then function info() { printf '[* INFO  ] %s\n' "${1}"; }; fi
if ! declare -f warn  > /dev/null; then function warn() { printf '[! WARN  ] %s\n' "${1}" >&2; }; fi
if ! declare -f error > /dev/null; then function error() { printf '[- ERROR ] %s\n' "${1}" >&2; }; fi
if ! declare -f pass  > /dev/null; then function pass() { printf '[+ PASS  ] %s\n' "${1}"; }; fi
if ! declare -f fail  > /dev/null; then function fail() { printf '[! FAIL  ] %s\n' "${1}" >&2; }; fi
if ! declare -f debug > /dev/null; then function debug() { printf '[# DEBUG ] %s\n' "${1}"; }; fi

# =============================================================================
# Enable strict error handling
#
# -u → error on unset variables
# -o pipefail → fail pipelines on first error
# =============================================================================

if [[ -n "${BASH_VERSION:-}" ]]; then
    set -uo pipefail
elif [[ -n "${ZSH_VERSION:-}" ]]; then
    # Do nothing at the moment as Oh My Zsh and plugins frequently break under
    # setopt nounset because many of them reference variables without checking
    # if they're defined.
    #
    # TODO: fix this better the future
    if setopt 2>&1 | grep -q '^pipefail'; then
        setopt pipefail
    else
        warn "pipefail not supported in this Zsh version"
    fi
else
    warn "Unknown shell. Strict options not set."
    "${EXIT_OR_RETURN}" 1
fi

# =============================================================================
# Begin primary script code
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${COMMAND_LOGGING_SH_LOADED:-}" ]]; then
    if [[ -n "${BASH_VERSION:-}" ]]; then
        declare -g COMMAND_LOGGING_SH_LOADED=true
        declare -g LAST_LOGGED_COMMAND=""
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        typeset -g COMMAND_LOGGING_SH_LOADED=true
        typeset -g LAST_LOGGED_COMMAND=""
    else
        COMMAND_LOGGING_SH_LOADED=true
        LAST_LOGGED_COMMAND=""
    fi

    # =============================================================================
    # Configuration
    # =============================================================================

    # Log file location
    if [[ -z "${LOG_HISTORY_DIR:-}" ]]; then
        HISTORY_FILE="${HOME}/.combined.history.log"
    else
        HISTORY_FILE="${LOG_HISTORY_DIR}/.combined.history.log"
    fi

    LOCK_FILE="${HISTORY_FILE}.lock"

    lock_dir="$(dirname "${LOCK_FILE}")"
    if [[ ! -w "${lock_dir}" ]]; then
        fail "Lock file directory not writable: ${lock_dir}"
        "${EXIT_OR_RETURN}" 1
    fi

    # =============================================================================
    # Configuration Flags
    # =============================================================================

    # Integrate logrotate
    USE_LOGROTATE=false

    # Automatically create a logrotate config if USE_LOGROTATE is true and no config exists
    AUTO_SETUP_LOGROTATE=false

    # Path where logrotate configs are stored (default for most distros)
    LOGROTATE_DIR="/etc/logrotate.d"

    # Maximum size of combined history log (in bytes) before rotating
    LOGROTATE_ROTATE_SIZE="10M"

    # Number of rotated logs to keep
    LOGROTATE_ROTATE_COUNT=10

    # Enable duplicate command suppression
    SUPPRESS_DUPLICATES=false

    # Enable syslog integration
    SYSLOG_ENABLED=false

    # Syslog facility to use
    SYSLOG_FACILITY="local1"

    # Syslog severity
    SYSLOG_SEVERITY="notice"

    # Automatically run self-test when sourcing the script
    RUN_LOGGING_SELFTEST="${RUN_LOGGING_SELFTEST:-false}"

    # =============================================================================
    # Cleanup Handler
    # =============================================================================

    ###############################################################################
    # cleanup_on_exit
    #------------------------------------------------------------------------------
    # Purpose  : Clean up lock files and other resources on shell exit
    # Arguments: None
    # Outputs  : None
    # Returns  : 0
    ###############################################################################
    function cleanup_on_exit() {
        # Only clean up if the lock file belongs to this process
        if [[ -f "${LOCK_FILE}" ]]; then
            local lock_pid
            lock_pid=$(cat "${LOCK_FILE}" 2> /dev/null || echo "")
            if [[ "${lock_pid}" == "$$" ]]; then
                rm -f "${LOCK_FILE}" 2> /dev/null || true
            fi
        fi
    }

    # Set up cleanup traps for EXIT, SIGINT, and SIGTERM
    # This ensures lock files are cleaned up even if the shell is interrupted
    if [[ -n "${BASH_VERSION:-}" ]]; then
        trap cleanup_on_exit EXIT INT TERM
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        trap cleanup_on_exit EXIT INT TERM
    fi

    # =============================================================================
    # Utility Functions
    # =============================================================================

    ###############################################################################
    # check_logrotate_config
    #------------------------------------------------------------------------------
    # Purpose  : Check if a logrotate config exists for the given log file
    # Arguments:
    #   $1 : Log file path
    # Outputs  : None
    # Returns  : 0 if config exists, 1 otherwise
    ###############################################################################
    function check_logrotate_config() {
        local log_file="$1"
        grep -q "${log_file}" /etc/logrotate.conf "${LOGROTATE_DIR}"/* 2> /dev/null
        return $?
    }

    ###############################################################################
    # auto_setup_logrotate
    #------------------------------------------------------------------------------
    # Purpose  : Automatically create a logrotate config for the log file
    # Arguments:
    #   $1 : Log file path
    # Outputs  : Status messages to stdout/stderr
    # Returns  : 0 on success, 1 on failure
    ###############################################################################
    function auto_setup_logrotate() {
        local log_file="$1"
        local config_file
        local tmp_config

        config_file="${LOGROTATE_DIR}/$(basename "${log_file}").logrotate"

        if [[ ! -d "${LOGROTATE_DIR}" ]]; then
            warn "logrotate directory ${LOGROTATE_DIR} does not exist. Cannot auto-setup logrotate."
            return 1
        fi

        # Check if a config already exists
        if check_logrotate_config "${log_file}"; then
            return 0
        fi

        info "Auto-setup: Creating logrotate config ${config_file} for ${log_file}..."

        # Create temp file securely (cross-platform compatible)
        # Use -t for macOS compatibility
        tmp_config=$(mktemp -t "$(basename "${config_file}").XXXXXX") || {
            fail "Failed to create temporary file for logrotate config"
            return 1
        }

        # Write config to temp file
        cat > "${tmp_config}" << EOF
${log_file} {
    rotate ${LOGROTATE_ROTATE_COUNT}
    size ${LOGROTATE_ROTATE_SIZE}
    compress
    missingok
    notifempty
    create 0600 $(whoami) $(whoami)
}
EOF

        # Atomically move temp file to final location
        if mv "${tmp_config}" "${config_file}" 2> /dev/null; then
            chmod 644 "${config_file}" || {
                fail "Failed to set permissions on logrotate config ${config_file}"
                rm -f "${config_file}"
                return 1
            }
            info "Logrotate configuration created at ${config_file}"
            return 0
        else
            rm -f "${tmp_config}"
            fail "Failed to create logrotate config at ${config_file}"
            return 1
        fi
    }

    # =============================================================================
    # Sanity Checks
    # =============================================================================

    if [[ "${USE_LOGROTATE}" == true ]]; then
        # Check if the logfile is already configured for logrotate
        if ! check_logrotate_config "${HISTORY_FILE}"; then
            warn "USE_LOGROTATE is true, but no logrotate config found for ${HISTORY_FILE}."
            if [[ "${AUTO_SETUP_LOGROTATE}" == true ]]; then
                auto_setup_logrotate "${HISTORY_FILE}"
            fi
        fi
    fi

    # =============================================================================
    # File Management Functions
    # =============================================================================

    ###############################################################################
    # ensure_history_file
    #------------------------------------------------------------------------------
    # Purpose  : Ensure the log directory exists and the history file is writable
    # Arguments: None
    # Outputs  : Error messages to stderr
    # Returns  : 0 on success, 1 on failure
    ###############################################################################
    function ensure_history_file() {
        local history_dir
        history_dir=$(dirname "${HISTORY_FILE}")

        # Create log directory if it doesn't exist
        if ! mkdir -p "${history_dir}" 2> /dev/null; then
            fail "Failed to create log directory: ${history_dir}"
            return 1
        fi

        # Create or touch the log file
        if ! touch "${HISTORY_FILE}" 2> /dev/null; then
            fail "Failed to create or touch log file: ${HISTORY_FILE}"
            return 1
        fi

        # Set restrictive permissions on the log file
        if ! chmod 600 "${HISTORY_FILE}" 2> /dev/null; then
            fail "Failed to set permissions on log file: ${HISTORY_FILE}"
            return 1
        fi

        return 0
    }

    ###############################################################################
    # basic_lock
    #------------------------------------------------------------------------------
    # Purpose  : Acquire a basic lock if flock is unavailable
    # Arguments: None
    # Outputs  : None
    # Returns  : 0 if lock acquired, 1 otherwise
    ###############################################################################
    function basic_lock() {
        if [[ -f "${LOCK_FILE}" ]]; then
            local pid
            pid=$(< "${LOCK_FILE}")
            if ! kill -0 "${pid}" 2> /dev/null; then
                # Stale lock
                rm -f "${LOCK_FILE}"
            else
                # Active lock
                return 1
            fi
        fi
        printf '%s\n' "$$" > "${LOCK_FILE}"
        return 0
    }

    ###############################################################################
    # basic_unlock
    #------------------------------------------------------------------------------
    # Purpose  : Release basic lock
    # Arguments: None
    # Outputs  : None
    # Returns  : 0
    ###############################################################################
    function basic_unlock() {
        rm -f "${LOCK_FILE}"
    }

    # =============================================================================
    # Session Detection Functions
    # =============================================================================

    ###############################################################################
    # get_session_info
    #------------------------------------------------------------------------------
    # Purpose  : Determine the current session (screen, tmux, tty)
    # Arguments: None
    # Outputs  : Session information string to stdout
    # Returns  : 0
    ###############################################################################
    function get_session_info() {
        local session_info
        if [[ -n "${STY:-}" ]]; then
            local window_num
            window_num="${WINDOW:-unknown}"
            session_info="screen:${STY:-}:(${window_num})"
        elif [[ -n "${TMUX:-}" ]]; then
            local tmux_info
            if command -v tmux > /dev/null 2>&1; then
                # Optimize: single tmux call instead of three separate calls
                tmux_info=$(tmux display-message -p '#S:#I:#P' 2> /dev/null || echo "unknown:-:-")
                session_info="tmux:${tmux_info%:*}(${tmux_info##*:})"
            else
                session_info="tmux:unknown(-:-)"
            fi
        else
            local tty pid
            tty=$(tty 2> /dev/null | sed 's|/dev/||' || echo "unknown")
            pid=$$
            session_info="tty(pid):${tty}(${pid})"
        fi
        printf '%s' "${session_info}"
    }

    ###############################################################################
    # get_shell
    #------------------------------------------------------------------------------
    # Purpose  : Determine current shell type
    # Arguments: None
    # Outputs  : Shell type (bash/zsh/unknown) to stdout
    # Returns  : 0
    ###############################################################################
    function get_shell() {
        if [[ -n "${BASH_VERSION:-}" ]]; then
            printf 'bash'
        elif [[ -n "${ZSH_VERSION:-}" ]]; then
            printf 'zsh'
        else
            printf 'unknown'
        fi
    }

    ###############################################################################
    # get_command
    #------------------------------------------------------------------------------
    # Purpose  : Retrieve the last executed command
    # Arguments:
    #   $1 : Shell type (bash/zsh)
    # Outputs  : Last command to stdout
    # Returns  : 0
    ###############################################################################
    function get_command() {
        local shell_type="$1"
        local command=""
        case "${shell_type}" in
            bash)
                # Use parameter expansion instead of sed for better performance
                command="$(history 1)"
                command="${command#"${command%%[![:space:]]*}"}"  # ltrim
                command="${command#*[0-9] }"  # Remove leading number
                command="${command#*] }"      # Remove timestamp if present
                ;;
            zsh)
                command="$(fc -ln -1)"
                command="${command#"${command%%[![:space:]]*}"}"  # ltrim
                ;;
            *)
                command=""
                ;;
        esac
        printf '%s' "${command}"
    }

    # =============================================================================
    # Logging Functions
    # =============================================================================

    ###############################################################################
    # write_to_syslog
    #------------------------------------------------------------------------------
    # Purpose  : Send log entry to syslog if enabled
    # Arguments:
    #   $1 : Log line to send
    # Outputs  : None (sends to syslog)
    # Returns  : 0 on success, 1 on failure
    ###############################################################################
    function write_to_syslog() {
        local log_line="$1"
        if [[ "${SYSLOG_ENABLED}" == true ]]; then
            logger -p "${SYSLOG_FACILITY}.${SYSLOG_SEVERITY}" -- "${log_line}"
            return $?
        fi
        return 0
    }

    ###############################################################################
    # sanitize_log_string
    #------------------------------------------------------------------------------
    # Purpose  : Sanitize a string before writing to log files to prevent broken
    #            log formats caused by quotes, control characters, command
    #            substitution, etc.
    # Arguments:
    #   $1 : Raw input string
    # Outputs : Safe string for logging (stdout)
    # Returns : 0
    ###############################################################################
    function sanitize_log_string() {
        local raw="${1:-}"
        local bt=$'\x60' # Hex code for backtick to pass style checks

        # Escape dangerous characters to prevent command injection
        # Using tr to remove control chars, then parameter expansion for safety
        local cleaned="${raw//\\/\\\\}"      # escape backslashes
        cleaned="${cleaned//\"/\\\"}"        # escape double quotes
        cleaned="${cleaned//\'/\\\'}"        # escape single quotes
        cleaned="${cleaned//${bt}/\\${bt}}"  # escape backticks (using hex var)
        cleaned="${cleaned//\$/\\\$}"        # escape $ to prevent expansion
        cleaned="${cleaned//\(/\\\(}"        # escape opening parenthesis
        cleaned="${cleaned//\)/\\\)}"        # escape closing parenthesis

        # Strip control characters
        cleaned="$(printf '%s' "${cleaned}" | tr -d '[:cntrl:]')"
        printf '%s' "${cleaned}"
    }

    ###############################################################################
    # write_log_entry
    #------------------------------------------------------------------------------
    # Purpose  : Write a log line to the main history file (and optional extra file)
    # Arguments:
    #   $1 : Log line to write
    #   $2 : Optional extra file path
    # Outputs  : Error messages to stderr
    # Returns  : 0 on success, 1 on failure
    ###############################################################################
    function write_log_entry() {
        local log_line="$1"
        local extra_file="${2:-}"
        local rc=0

        log_line="$(sanitize_log_string "${log_line}")"

        write_to_syslog "${log_line}" || warn "Failed to write to syslog"

        # Note: flock is not available on macOS by default (install via: brew install flock)
        # Script falls back to basic_lock() if flock is not found
        if command -v "flock" > /dev/null 2>&1; then
            # Use printf instead of echo for safety
            # Use file descriptors to avoid subshell issues
            # FD 200 chosen to avoid conflicts with common descriptors (0-9)
            exec 200> "${LOCK_FILE}"
            if ! flock -n 200; then
                warn "Could not acquire lock. Skipping log entry."
                return 1
            fi

            printf '%s\n' "${log_line}" >> "${HISTORY_FILE}" || rc=1
            if [[ -n "${extra_file}" ]]; then
                printf '%s\n' "${log_line}" >> "${extra_file}" || rc=1
            fi

            # Release the lock
            exec 200>&-

            return "${rc}"
        else
            if basic_lock; then
                printf '%s\n' "${log_line}" >> "${HISTORY_FILE}" || rc=1
                if [[ -n "${extra_file:-}" ]]; then
                    printf '%s\n' "${log_line}" >> "${extra_file}" || rc=1
                fi
                basic_unlock
                return "${rc}"
            else
                warn "Could not acquire lock. Skipping log entry."
                return 1
            fi
        fi
    }

    ###############################################################################
    # log_command_unified
    #------------------------------------------------------------------------------
    # Purpose  : Log the most recent interactive command
    # Arguments: None
    # Outputs  : None (writes to log file)
    # Returns  : 0
    ###############################################################################
    function log_command_unified() {
        local date_time session_info command shell_type log_line

        session_info=$(get_session_info)
        shell_type=$(get_shell)
        command="$(get_command "${shell_type}")"

        if [[ "${SUPPRESS_DUPLICATES}" == true ]]; then
            if [[ "${command}" == "${LAST_LOGGED_COMMAND}" ]]; then
                return
            fi
            LAST_LOGGED_COMMAND="${command}"
        fi

        date_time=$(date +"%Y-%m-%d %H:%M:%S")
        log_line="[${date_time}] (${shell_type}) ${session_info} # ${command}"

        write_log_entry "${log_line}"
    }

    # =============================================================================
    # trace_run
    #==============================
    # Runs a script under tracing (set -x), logging each executed command
    # to the main log and an optional per-run trace log.
    #
    # Usage:
    #   trace_run <script_path> [args...]
    #
    # Return Values:
    #   0 = success
    #   1 = invalid arguments
    #   2 = script not executable
    #   3 = failed permissions on log file
    # =============================================================================
    function trace_run() {
        local target_script shell_type timestamp per_run_log session_info rc
        local interpreter first_line
        local temp_trace_file

        if [[ $# -lt 1 ]]; then
            error "Usage: trace_run <script> [args...]"
            return 1
        fi

        target_script="$1"
        shift

        if [[ ! -f "${target_script}" ]] || [[ ! -r "${target_script}" ]]; then
            fail "Script not found or not readable: ${target_script}"
            return 2
        fi

        session_info=$(get_session_info)
        shell_type=$(get_shell)

        timestamp=$(date "+%Y%m%d_%H%M%S")

        # Use mktemp for secure temp file creation to avoid race conditions
        # Use -t for macOS compatibility
        temp_trace_file=$(mktemp -t "history_trace.XXXXXX") || {
            fail "Failed to create temporary trace file"
            return 3
        }

        per_run_log="${HISTORY_FILE}.${timestamp}.${target_script##*/}.$$.${RANDOM}.trace"

        info "Tracing ${target_script} → ${per_run_log}"

        # Default interpreter to current shell binary
        if [[ "${shell_type}" == "bash" ]]; then
            interpreter="bash"
        elif [[ "${shell_type}" == "zsh" ]]; then
            interpreter="zsh"
        else
            interpreter="bash"
        fi

        # Inspect shebang if present
        if read -r first_line < "${target_script}"; then
            if [[ "${first_line}" == "#!"* ]]; then
                if [[ "${first_line}" == *"bash"* ]]; then
                    interpreter="bash"
                elif [[ "${first_line}" == *"zsh"* ]]; then
                    interpreter="zsh"
                fi
            fi
        fi

        # Pre-declare variables to avoid subshell scope issues
        local trace_line trace_command trace_datetime trace_log_entry

        # Run the script with tracing enabled
        # Use temp file to avoid process substitution subshell issues
        {
            PS4="${TRACE_PREFIX}" "${interpreter}" -x "${target_script}" "$@" 2>&1 | while IFS= read -r trace_line; do
                if [[ "${trace_line}" == "${TRACE_PREFIX}"* ]]; then
                    trace_command="${trace_line#"${TRACE_PREFIX}"}"
                    trace_datetime=$(date +"%Y-%m-%d %H:%M:%S")
                    trace_log_entry="[${trace_datetime}] (${interpreter}) ${session_info} # ${trace_command}"
                    printf '%s\n' "${trace_log_entry}" >> "${temp_trace_file}"
                    write_log_entry "${trace_log_entry}"
                else
                    printf '%s\n' "${trace_line}" >> "${temp_trace_file}"
                fi
            done

            # Capture the exit code from the pipeline
            # Bash uses PIPESTATUS, Zsh uses pipestatus (and indexes from 1)
            if [[ -n "${BASH_VERSION:-}" ]]; then
                printf '%s' "${PIPESTATUS[0]}"
            elif [[ -n "${ZSH_VERSION:-}" ]]; then
                printf '%s' "${pipestatus[1]}"
            else
                printf '0'
            fi
        } > "${temp_trace_file}.rc"

        # Read the actual return code
        rc=$(cat "${temp_trace_file}.rc")
        rm -f "${temp_trace_file}.rc"

        # Log final outcome
        local final_datetime final_log_entry
        final_datetime=$(date +"%Y-%m-%d %H:%M:%S")
        final_log_entry="[${final_datetime}] (${interpreter}) ${session_info} # trace_run exit code: ${rc}"
        printf '%s\n' "${final_log_entry}" >> "${temp_trace_file}"
        write_log_entry "${final_log_entry}"

        # Move temp file to final location
        mv "${temp_trace_file}" "${per_run_log}" || {
            fail "Failed to move trace file to ${per_run_log}"
            rm -f "${temp_trace_file}"
            return 3
        }

        # Set restrictive permissions
        chmod 600 "${per_run_log}" || {
            fail "Failed to set permissions on ${per_run_log}"
            return 3
        }

        return "${rc}"
    }

    # =============================================================================
    # test_logging_setup
    # ------------------
    # Test mode to validate that:
    # - log file is writable
    # - flock is available
    # - syslog is working (if enabled)
    # - logrotate config exists (if enabled)
    # - log entries can be written
    # =============================================================================
    function test_logging_setup() {
        local test_message logrotate_file test_line test_random

        info "========== Testing Logging Setup =========="

        # Check log file exists and writable
        if [[ ! -f "${HISTORY_FILE}" ]]; then
            fail "Log file does not exist: ${HISTORY_FILE}"
            return 1
        fi

        if [[ ! -w "${HISTORY_FILE}" ]]; then
            fail "Log file is not writable: ${HISTORY_FILE}"
            return 1
        fi
        pass "Log file exists and is writable: ${HISTORY_FILE}"

        # Check flock availability
        if command -v "flock" > /dev/null 2>&1; then
            pass "flock is available on this system."
        else
            warn "flock not found. Script will fallback to basic lock logic."
        fi

        # Check syslog capability if enabled
        if [[ "${SYSLOG_ENABLED}" == true ]]; then
            test_message="Test message from ${SCRIPT_NAME} v${SCRIPT_VERSION} at $(date)"
            if write_to_syslog "${test_message}"; then
                pass "Successfully sent test message to syslog: ${test_message}"
            else
                fail "Failed to send test message to syslog."
                return 1
            fi
        else
            info "Syslog integration is disabled."
        fi

        # Check logrotate config if enabled
        if [[ "${USE_LOGROTATE}" == true ]]; then
            if check_logrotate_config "${HISTORY_FILE}"; then
                pass "Logrotate config found for ${HISTORY_FILE}."
            else
                fail "Logrotate config missing and auto-setup not run."
                return 1
            fi
        else
            info "Logrotate integration is disabled."
        fi

        # Test writing a sample log line with better random generation
        test_random="${RANDOM:-$$}"
        test_line="[TEST] (${test_random}) test_logging_setup # This is a test log entry."

        if write_log_entry "${test_line}"; then
            pass "Successfully wrote test log entry to ${HISTORY_FILE}"
        else
            fail "Failed to write test log entry to ${HISTORY_FILE}"
            return 1
        fi

        info "========== Logging Setup Test Completed =========="

        return 0
    }

    # =============================================================================
    # Hook into Shells
    # =============================================================================

    # Enable unified command logging in both Bash and Zsh
    if [[ -n "${BASH_VERSION:-}" ]]; then
        trap 'log_command_unified' DEBUG
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        # Check whether log_command_unified is already in precmd_functions
        # Ensure precmd_functions is declared
        if typeset -p precmd_functions > /dev/null 2>&1; then
            # Only add if not already present
            typeset found=false
            for func in "${precmd_functions[@]}"; do
                if [[ "${func}" == "log_command_unified" ]]; then
                    found=true
                    break
                fi
            done

            if [[ "${found}" == false ]]; then
                precmd_functions+=(log_command_unified)
            fi
        else
            precmd_functions=(log_command_unified)
        fi

    fi

    ensure_history_file || {
        fail "Logging could not be initialized. Commands will not be logged."
    }

    if [[ "${RUN_LOGGING_SELFTEST}" == true ]]; then
        test_logging_setup
    fi

    info "Command logging initialized for Bash/Zsh (v${SCRIPT_VERSION}). Log file: ${HISTORY_FILE}"
fi

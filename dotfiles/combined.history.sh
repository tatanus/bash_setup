#!/usr/bin/env bash

# =============================================================================
# NAME        : combined.history.sh
# DESCRIPTION : Logs commands in Bash and Zsh interactive shells.
#               Also includes trace_run for logging entire script executions.
# AUTHOR      : Adam Compton
# DATE CREATED: 2025-07-04
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2025-07-04           | Adam Compton | Unified Bash/Zsh version with trace_run
# =============================================================================

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
    if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 2))); then
        fail "Bash 4.2 or newer is required." >&2
        "${EXIT_OR_RETURN}" 1
    fi

elif [[ -n "${ZSH_VERSION:-}" ]]; then
    # Extract the major version safely
    zsh_major="${ZSH_VERSION%%.*}"
    if [[ -z "${zsh_major}" ]] || ((zsh_major < 5)); then
        fail "Zsh 5.0 or newer is required." >&2
        "${EXIT_OR_RETURN}" 1
    fi

else
    fail "Unknown shell. This script supports Bash or Zsh only." >&2
    "${EXIT_OR_RETURN}" 1
fi

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
    # if they’re defined.
    #
    # TODO: fix this better the future
    if setopt | grep -q '^pipefail'; then
        setopt pipefail
    else
        warn "pipefail not supported in this Zsh version" >&2
    fi

    # # Check whether Zsh supports pipefail
    # if setopt | grep -q '^pipefail'; then
    #     setopt nounset pipefail
    # else
    #     setopt nounset
    # fi
else
    warn "Unknown shell. Strict options not set." >&2
    "${EXIT_OR_RETURN}" 1
fi

# =============================================================================
# Begin primary script code
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${COMMAND_LOGGING_SH_LOADED:-}" ]]; then
    if [[ -n "${BASH_VERSION:-}" ]]; then
        declare -g COMMAND_LOGGING_SH_LOADED=true
        # Initialize LAST_LOGGED_COMMAND to avoid duplicates
        declare -g LAST_LOGGED_COMMAND=""
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        typeset -g COMMAND_LOGGING_SH_LOADED=true
        # Initialize LAST_LOGGED_COMMAND to avoid duplicates
        typeset -g LAST_LOGGED_COMMAND=""
    else
        COMMAND_LOGGING_SH_LOADED=true
        # Initialize LAST_LOGGED_COMMAND to avoid duplicates
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
        fail "Lock file directory not writable: ${lock_dir}" >&2
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
    # /etc/logrotate.d/combined_history.log {
    #     rotate 10
    #     weekly
    #     size 10M
    #     compress
    #     missingok
    #     notifempty
    #     create 0600 root root
    # }

    # Maximum size of combined history log (in bytes) before rotating
    LOGROTATE_ROTATE_SIZE="10M"

    # Number of rotated logs to keep
    LOGROTATE_ROTATE_COUNT=10

    # Enable duplicate command suppression
    SUPPRESS_DUPLICATES=true

    # Enable syslog integration
    SYSLOG_ENABLED=true

    # Syslog facility to use
    SYSLOG_FACILITY="local1"

    # Syslog severity
    SYSLOG_SEVERITY="notice"

    # Automatically run self-test when sourcing the script
    RUN_LOGGING_SELFTEST="${RUN_LOGGING_SELFTEST:-false}"

    # =============================================================================
    # Sanity Checks
    # =============================================================================

    # Automatically create a logrotate config
    function auto_setup_logrotate() {
        local log_file="$1"
        local config_file
        config_file="${LOGROTATE_DIR}/$(basename "${log_file}").logrotate"

        if [[ ! -d "${LOGROTATE_DIR}" ]]; then
            warn "logrotate directory ${LOGROTATE_DIR} does not exist. Cannot auto-setup logrotate." >&2
            return 1
        fi

        # Check if a config already exists
        if grep -q "${log_file}" /etc/logrotate.conf "${LOGROTATE_DIR}"/* 2> /dev/null; then
            return 0
        fi

        echo "Auto-setup: Creating logrotate config ${config_file} for ${log_file}..."

        cat << EOF > "${config_file}"
${log_file} {
    rotate ${LOGROTATE_ROTATE_COUNT}
    size ${LOGROTATE_ROTATE_SIZE}
    compress
    missingok
    notifempty
    create 0600 $(whoami) $(whoami)
}
EOF

        chmod 644 "${config_file}" || {
            fail "Failed to set permissions on logrotate config ${config_file}" >&2
            return 1
        }

        echo "Logrotate configuration created at ${config_file}"
    }

    if [[ "${USE_LOGROTATE}" == true ]]; then
        # Check if the logfile is already configured for logrotate
        if ! grep -q "${HISTORY_FILE}" /etc/logrotate.conf "${LOGROTATE_DIR}"/* 2> /dev/null; then
            warn "USE_LOGROTATE is true, but no logrotate config found for ${HISTORY_FILE}." >&2
            if [[ "${AUTO_SETUP_LOGROTATE}" == true ]]; then
                auto_setup_logrotate "${HISTORY_FILE}"
            fi
        fi
    fi

    # =============================================================================
    # Utility Functions
    # =============================================================================

    # Ensure the log directory exists and the history file is writable
    function ensure_history_file() {
        local history_dir
        history_dir=$(dirname "${HISTORY_FILE}")

        # Create log directory if it doesn't exist
        if ! mkdir -p "${history_dir}" 2> /dev/null; then
            fail "Failed to create log directory: ${history_dir}" >&2
            return 1
        fi

        # Create or touch the log file
        if ! touch "${HISTORY_FILE}" 2> /dev/null; then
            fail "Failed to create or touch log file: ${HISTORY_FILE}" >&2
            return 1
        fi

        # Set restrictive permissions on the log file
        if ! chmod 600 "${HISTORY_FILE}" 2> /dev/null; then
            fail "Failed to set permissions on log file: ${HISTORY_FILE}" >&2
            return 1
        fi

        return 0
    }

    # Acquire a basic lock if flock is unavailable
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
        echo "$$" > "${LOCK_FILE}"
        return 0
    }

    # Release basic lock
    function basic_unlock() {
        rm -f "${LOCK_FILE}"
    }

    # =============================================================================
    # Session Detection Functions
    # =============================================================================

    # Determine the current session (screen, tmux, tty)
    function get_session_info() {
        local session_info
        if [[ -n "${STY:-}" ]]; then
            local window_num
            window_num="${WINDOW:-unknown}"
            session_info="screen:${STY:-}:(${window_num})"
        elif [[ -n "${TMUX:-}" ]]; then
            local session_name window_name pane_name
            session_name="unknown"
            window_name="unknown"
            pane_name="unknown"
            if command -v tmux > /dev/null 2>&1; then
                session_name=$(tmux display-message -p '#S' 2> /dev/null || echo "unknown")
                window_name=$(tmux display-message -p '#I' 2> /dev/null || echo "-")
                pane_name=$(tmux display-message -p '#P' 2> /dev/null || echo "-")
            fi
            session_info="tmux:${session_name}(${window_name}:${pane_name})"
        else
            local tty pid
            tty=$(tty 2> /dev/null | sed 's|/dev/||' || echo "unknown")
            pid=$$
            session_info="tty(pid):${tty}(${pid})"
        fi
        echo "${session_info}"
    }

    # Determine current shell type
    function get_shell() {
        if [[ -n "${BASH_VERSION:-}" ]]; then
            echo "bash"
        elif [[ -n "${ZSH_VERSION:-}" ]]; then
            echo "zsh"
        else
            echo "unknown"
        fi
    }

    # Retrieve the last executed command
    function get_command() {
        local shell_type="$1"
        local command=""
        case "${shell_type}" in
            bash)
                command="$(history 1 | sed -E 's/^ *[0-9]+ *(\[[^]]*\] *)?//')"
                ;;
            zsh)
                command="$(fc -ln -1 | sed 's/^[[:space:]]*//')"
                ;;
            *)
                command=""
                ;;
        esac
        echo "${command}"
    }

    # =============================================================================
    # Logging Functions
    # =============================================================================

    # Send log entry to syslog if enabled
    function write_to_syslog() {
        local log_line="$1"
        if [[ "${SYSLOG_ENABLED}" == true ]]; then
            logger -p "${SYSLOG_FACILITY}.${SYSLOG_SEVERITY}" -- "${log_line}"
        fi
    }

    ###############################################################################
    # sanitize_log_string
    #------------------------------------------------------------------------------
    # Purpose  : Sanitize a string before writing to log files to prevent broken
    #            log formats caused by quotes, control characters, etc.
    # Arguments:
    #   $1 : Raw input string
    # Outputs : Safe string for logging (stdout)
    # Returns : 0
    ###############################################################################
    function sanitize_log_string() {
        local raw="${1:-}"
        # Escape backslashes first, then double quotes
        # Remove control characters (non-printable except tab/newline)
        printf '%s' "${raw}" \
            | sed -E 's/\\/\\\\/g; s/"/\\"/g; s/[\x00-\x1F\x7F]//g'
    }

    # Write a log line to the main history file (and optional extra file)
    function write_log_entry() {
        local log_line="$1"
        local extra_file="${2:-}"

        log_line="$(sanitize_log_string "${log_line}")"

        write_to_syslog "${log_line}"

        if command -v "flock" > /dev/null 2>&1; then
            flock -n "${LOCK_FILE}" -c "
                echo \"${log_line}\" >> \"${HISTORY_FILE}\"
                if [[ -n \"${extra_file}\" ]]; then
                    echo \"${log_line}\" >> \"${extra_file}\"
                fi
            "
        else
            if basic_lock; then
                echo "${log_line}" >> "${HISTORY_FILE}"
                if [[ -n "${extra_file:-}" ]]; then
                    echo "${log_line}" >> "${extra_file}"
                fi
                basic_unlock
            else
                fail "Could not acquire lock. Skipping log entry." >&2
            fi
        fi
    }

    # Log the most recent interactive command
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
        local interpreter first_line trace_cmd

        if [[ $# -lt 1 ]]; then
            echo "Usage: trace_run <script> [args...]" >&2
            return 1
        fi

        target_script="$1"
        shift

        if [[ ! -f "${target_script}" ]] || [[ ! -r "${target_script}" ]]; then
            fail "Script not found or not readable: ${target_script}" >&2
            return 2
        fi

        session_info=$(get_session_info)
        shell_type=$(get_shell)

        timestamp=$(date "+%Y%m%d_%H%M%S")
        per_run_log="${HISTORY_FILE}.${timestamp}.${target_script##*/}.trace"

        echo "Tracing ${target_script} → ${per_run_log}"

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

        # Construct trace command
        trace_cmd=("${interpreter}" -x "${target_script}" "$@")

        {
            export PS4='+TRACE+ '
            "${trace_cmd[@]}"
        } 2> >(
            while IFS= read -r line; do
                if [[ "${line}" == +TRACE+* ]]; then
                    local command date_time log_entry
                    command="${line#'+TRACE+ '}"
                    date_time=$(date +"%Y-%m-%d %H:%M:%S")
                    log_entry="[${date_time}] (${interpreter}) ${session_info} # ${command}"
                    write_log_entry "${log_entry}" "${per_run_log}"
                else
                    echo "${line}" >> "${per_run_log}"
                fi
            done
        ) > >(
            tee -a "${per_run_log}"
        )

        rc=$?

        # log final outcome
        local date_time log_entry
        date_time=$(date +"%Y-%m-%d %H:%M:%S")
        log_entry="[${date_time}] (${interpreter}) ${session_info} # trace_run exit code: ${rc}"
        write_log_entry "${log_entry}" "${per_run_log}"

        chmod 600 "${per_run_log}" || {
            fail "Failed to set permissions on ${per_run_log}" >&2
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
        local test_message logrotate_file test_line

        echo "========== Testing Logging Setup =========="

        # Check log file exists and writable
        if [[ ! -f "${HISTORY_FILE}" ]]; then
            fail "Log file does not exist: ${HISTORY_FILE}" >&2
            return 1
        fi

        if [[ ! -w "${HISTORY_FILE}" ]]; then
            fail "Log file is not writable: ${HISTORY_FILE}" >&2
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
            test_message="Test message from bash.history.sh at $(date)"
            if logger -p "${SYSLOG_FACILITY}.${SYSLOG_SEVERITY}" -- "${test_message}"; then
                pass "Successfully sent test message to syslog: ${test_message}"
            else
                fail "Failed to send test message to syslog." >&2
                return 1
            fi
        else
            info "Syslog integration is disabled."
        fi

        # Check logrotate config if enabled
        if [[ "${USE_LOGROTATE}" == true ]]; then
            logrotate_file="${LOGROTATE_DIR}/$(basename "${HISTORY_FILE}").logrotate"

            if grep -q "${HISTORY_FILE}" /etc/logrotate.conf "${LOGROTATE_DIR}"/* 2> /dev/null; then
                pass "Logrotate config found for ${HISTORY_FILE}."
            elif [[ -f "${logrotate_file}" ]]; then
                pass "Auto-created logrotate config exists: ${logrotate_file}"
            else
                fail "Logrotate config missing and auto-setup not run." >&2
                return 1
            fi
        else
            info "Logrotate integration is disabled."
        fi

        # Test writing a sample log line
        if [[ -z "${RANDOM:-}" ]]; then
            RANDOM_SEED="${RANDOM_SEED:-12345}"
            RANDOM=$(((RANDOM_SEED + $$ + SECONDS) % 32768))
        fi

        test_line="[TEST] (${RANDOM}) test_logging_setup # This is a test log entry."
        write_log_entry "${test_line}" || {
            fail "Failed to write test log entry to ${HISTORY_FILE}" >&2
            return 1
        }

        pass "Successfully wrote test log entry to ${HISTORY_FILE}"
        echo "========== Logging Setup Test Completed =========="

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
            found=false
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
        fail "Logging could not be initialized. Commands will not be logged." >&2
    }

    if [[ "${RUN_LOGGING_SELFTEST}" == true ]]; then
        test_logging_setup
    fi

    echo "Command logging initialized for Bash/Zsh. Log file: ${HISTORY_FILE}"
fi

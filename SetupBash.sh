#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : SetupBash.sh
# DESCRIPTION :
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-16 16:51:35
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-16 16:51:35  | Adam Compton | Initial creation.
# =============================================================================

# Minimal placeholders (until more robust functions can be defined later)
function fail() {
    local timestamp
    timestamp=$(date +"[%Y-%m-%d %H:%M:%S]")
    echo "${timestamp} [- FAIL  ] $*" >&2
}
function pass() {
    local timestamp
    timestamp=$(date +"[%Y-%m-%d %H:%M:%S]")
    echo "${timestamp} [+ PASS  ] $*"
}
function info() {
    local timestamp
    timestamp=$(date +"[%Y-%m-%d %H:%M:%S]")
    echo "${timestamp} [* INFO  ] $*"
}
function warn() {
    local timestamp
    timestamp=$(date +"[%Y-%m-%d %H:%M:%S]")
    echo "${timestamp} [! WARN  ] $*"
}
function debug() {
    local timestamp
    timestamp=$(date +"[%Y-%m-%d %H:%M:%S]")
    echo "${timestamp} [! DEBUG ] $*"
}

# Initialize the error flag
ERROR_FLAG=false

# Ensure the script is being run under Bash
if [[ -z "${BASH_VERSION:-}" ]]; then
    fail "Error: This script must be run under Bash."
    ERROR_FLAG=true
fi

# Ensure Bash version is 4.0 or higher
if [[ -n "${BASH_VERSION:-}" && "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    fail "Error: This script requires Bash version 4.0 or higher. Current version: ${BASH_VERSION}"
    ERROR_FLAG=true
else
    info "Detected bash version: ${BASH_VERSION}"
fi

function _Pause() {
    if [[ -t 0 ]]; then  # check if running interactively
        echo
        echo "-----------------------------------"
        read -n 1 -s -r -p "Press any key to continue..."
        echo  # Move to the next line after key press

        # Use ANSI escape codes to move the cursor up and clear lines
        tput cuu 3   # Move the cursor up 3 lines
        tput el      # Clear the current line
        tput el      # Clear the next line
        tput el      # Clear the third line
    fi
}

# If any errors occurred, display a summary and exit
if ${ERROR_FLAG}; then
    echo
    fail "--------------------------------------------------"
    fail "One or more errors occurred:"
    fail "  - Ensure you are using Bash version 4.0 or higher."
    fail
    fail "-----------------------------------"
    _Pause
    #exit 1  # Exit with a failure status code
fi

# Success message if no errors
pass "All checks passed. Continuing script execution."

# -----------------------------------------------------------------------------
# ---------------------------------- IMPORTS/SOURCES --------------------------
# -----------------------------------------------------------------------------

# Check if the HOME environment variable is set
if [[ -n "${HOME}" ]]; then
    # If HOME is set, use it
    info "HOME environment variable is set. Using HOME: ${HOME}"
elif command -v getent > /dev/null 2>&1; then
    # If getent is available, use it to retrieve the home directory
    HOME_TEMP=$(getent passwd "$(whoami)" | cut -d: -f6)
    export HOME="${HOME_TEMP}"
    if [[ -n "${HOME}" ]]; then
        info "Using getent to determine HOME: ${HOME}"
    else
        fail "Failed to determine HOME using getent."
        exit 1
    fi
else
    # Fallback: Use eval to get the home directory
    HOME_TEMP=$(eval echo ~)
    export HOME="${HOME_TEMP}"
    if [[ -n "${HOME}" ]]; then
        warn "HOME and getent are unavailable. Using fallback with eval: HOME=${HOME}"
    else
        fail "Failed to determine HOME. Unable to proceed."
        exit 1
    fi
fi

# Determine the script's root directory
# The SCRIPT_DIR variable points to the directory containing the script.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${SCRIPT_DIR}" && -d "${SCRIPT_DIR}" ]]; then
    export SCRIPT_DIR
    info "Script directory determined: ${SCRIPT_DIR}"
else
    fail "Failed to determine the script directory. Exiting."
    exit 1
fi

# Define required files in an array
# These files must exist and be sourced for the script to work correctly.
declare -a REQUIRED_FILES=(
    "${SCRIPT_DIR}/config/config.sh"
    "${SCRIPT_DIR}/config/lists.sh"
    "${SCRIPT_DIR}/lib/common_core/logger.sh"
    "${SCRIPT_DIR}/lib/common_core/utils.sh"
    "${SCRIPT_DIR}/lib/common_core/menu.sh"
    "${SCRIPT_DIR}/lib/common_core/safe_source.sh"
    "${SCRIPT_DIR}/menu/menu_tasks.sh"
)

# -----------------------------------------------------------------------------
# ---------------------------------- MAIN -------------------------------------
# -----------------------------------------------------------------------------

function main() {
    # Check if any arguments are passed
    if [[ $# -eq 0 ]]; then
        # No arguments, display the menu
        _Display_Menu "BASH SETUP" "_Process_Start_Menu" false "${SETUP_MENU_ITEMS[@]}"
        return
    fi

    # Process arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -bash)
                # Bypass menu and run Setup_Dot_Files directly
                Setup_Dot_Files
                return
                ;;
            *)
                # Handle invalid arguments
                echo "[ERROR] Invalid argument: $1" >&2
                echo "Usage: $0 [-bash]" >&2
                return 1
                ;;
        esac
    done
}

# Run ensure_command to check if required commands are present
ensure_command "fzf"
ensure_command "eza"
ensure_command "ncat"
ensure_command "bat"
ensure_command "proxychains"
ensure_command "proxychains4"

# Call the main function, passing all script arguments
main "$@"

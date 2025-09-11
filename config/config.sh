#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : config.sh
# DESCRIPTION : Configuration file for Bash scripts and environment.
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-08 19:57:22
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-08 19:57:22  | Adam Compton | Initial creation.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${CONFIG_SH_LOADED:-}" ]]; then
    declare -g CONFIG_SH_LOADED=true

    # =============================================================================
    # GLOBAL SETTINGS
    # =============================================================================

    export DEBUG=false                  # Enable debug mode (true/false)
    export NO_DISPLAY=false             # Suppress display outputs (true/false)
    export _PASS=0                      # Success return code
    export _FAIL=1                      # Failure return code

    export INTERACTIVE_MENU=false       # Enable interactive menus (true/false)

    # =============================================================================
    # BASH CONFIGURATION DIRECTORIES
    # =============================================================================

    export BASH_DIR="${HOME}/.config/bash"
    export BASH_LOG_DIR="${BASH_DIR}/log"

    # Ensure directories exist
    for dir in "${BASH_DIR}" "${BASH_LOG_DIR}"; do
        if [[ ! -d "${dir}" ]]; then
            mkdir -p "${dir}" || {
                echo "Failed to create directory: ${dir}" >&2
                exit "${_FAIL}"
            }
            printf "[* INFO  ] Created directory: %s\n" "${dir}"
        fi
    done

    # =============================================================================
    # SCRIPT FILES
    # =============================================================================

    export CONFIG_FILE="${SCRIPT_DIR}/config/config.sh"
    export MENU_FILE="${SCRIPT_DIR}/menu/menu.sh"
    export LOG_FILE="${SCRIPT_DIR}/bash_setup.log"
    export MENU_TIMESTAMP_FILE="${SCRIPT_DIR}/menu_timestamps"

    # Ensure required files exist
    # shellcheck disable=SC2066
    for file in "${MENU_TIMESTAMP_FILE}"; do
        if [[ ! -f "${file}" ]]; then
            touch "${file}" || {
                echo "Failed to create file: ${file}" >&2
                exit "${_FAIL}"
            }
        fi
    done

    # =============================================================================
    # DATA AND OUTPUT DIRECTORIES
    # =============================================================================

    export DATA_DIR="${HOME}/DATA"
    export LOGS_DIR="${DATA_DIR}/LOGS"

    # =============================================================================
    # LOGGING CONFIGURATION
    # =============================================================================

    export BASH_LOG_FILE="${BASH_DIR}/bash_setup.log"

    # =============================================================================
    # END CONFIGURATION
    # =============================================================================
fi

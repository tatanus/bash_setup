#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : path.env.sh
# DESCRIPTION :
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-08 19:57:22
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-08 19:57:22  | Adam Compton | Initial creation.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${PATH_ENV_LOADED:-}" ]]; then
    declare -g PATH_ENV_LOADED=true

    # BASH Directory
    export BASH_DIR="${HOME}/.config/bash"
    export BASH_LOG_DIR="${BASH_DIR}/log"

    # Ensure the BASH directory exists
    if [[ ! -d "${BASH_DIR}" ]]; then
        mkdir -p "${BASH_DIR}" || {
            echo "Failed to create directory: ${BASH_DIR}"
            exit 1
        }
        info "Created directory: ${BASH_DIR}"
    fi

    # Ensure the BASH directory exists
    if [[ ! -d "${BASH_LOG_DIR}" ]]; then
        mkdir -p "${BASH_LOG_DIR}" || {
            echo "Failed to create directory: ${BASH_LOG_DIR}"
            exit 1
        }
        info "Created directory: ${BASH_LOG_DIR}"
    fi
fi

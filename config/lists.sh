#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : lists.sh
# DESCRIPTION : Contains predefined lists and mappings used in the Bash
#               automation framework.
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-10 12:29:41
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-10 12:29:41  | Adam Compton | Initial creation.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${LISTS_SH_LOADED:-}" ]]; then
    declare -g LISTS_SH_LOADED=true

    # =============================================================================
    # VALIDATION
    # =============================================================================
    # Validate essential environment variables
    : "${DATA_DIR:?Environment variable DATA_DIR is not set or empty.}"
    : "${BASH_DIR:?Environment variable BASH_DIR is not set or empty.}"

    # =============================================================================
    # REQUIRED DIRECTORIES
    # =============================================================================

    # Directories used for pentest workflows
    REQUIRED_BASH_DIRECTORIES=(
        "${DATA_DIR}/LOGS"
        "${HOME}/.config/bash"
        "${HOME}/.config/bash/log"
    )

    # =============================================================================
    # DOT FILES
    # =============================================================================

    COMMON_DOT_FILES=(
        "bashrc"
        "profile"
        "bash_profile"
        "tmux.conf"
        "screenrc_v4"
        "screenrc_v5"
        "inputrc"
        "vimrc"
        "wgetrc"
        "curlrc"
    )

    BASH_DOT_FILES=(
        "bash.path.sh"
        "bash.env.sh"
        "path.env.sh"
        "bash.funcs.sh"
        "bash.aliases.sh"
        "screen.aliases.sh"
        "tmux.aliases.sh"
        "bash.prompt.sh"
        "bash.prompt_funcs.sh"
        "bash-preexec.sh"
        "combined.history.sh"
        "ssh.aliases.sh"
        "bash.visuals.sh"
    )

    # =============================================================================
    # MENU ITEMS
    # =============================================================================

    # Array for Setup_Environment functions
    BASH_ENVIRONMENT_MENU_ITEMS=(
        "Undo_Setup_Dot_Files"
        "Setup_Dot_Files"
    )
fi

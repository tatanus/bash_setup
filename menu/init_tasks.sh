#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : init_tasks.sh
# DESCRIPTION :
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-10 12:29:41
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-10 12:29:41  | Adam Compton | Initial creation.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${BASH_SETUP_INIT_TASKS_SH_LOADED:-}" ]]; then
    declare -g BASH_SETUP_INIT_TASKS_LOADED=true

    # -----------------------------------------------------------------------------
    # ---------------------------------- INIT SETUP -------------------------------
    # -----------------------------------------------------------------------------

    # Function to configure dotfiles
    # This function backs up existing dotfiles and replaces them with new ones from a designated directory.
    function Setup_Dot_Files() {
        # Ensure the source directory exists
        local src_dir="${SCRIPT_DIR}/dot"
        if [[ ! -d "${src_dir}" ]]; then
            fail "Directory [${src_dir}] does not exist."
            return "${_FAIL}"
        fi

        for file in "${COMMON_DOT_FILES[@]}"; do
            local target="${HOME}/.${file}"
            local source="dot/${file}"

            # Copy the new file from the dot directory
            if copy_file "${source}" "${target}"; then
                pass "Copied ${source} to ${target}."
            else
                fail "Failed to copy ${source} to ${target}."
            fi
        done

        for file in "${BASH_DOT_FILES[@]}"; do
            local target="${BASH_DIR}/${file}"
            local source="dot/${file}"

            # Copy the new file from the dot directory
            if copy_file "${source}" "${target}"; then
                pass "Copied ${source} to ${target}."
            else
                fail "Failed to copy ${source} to ${target}."
            fi
        done

        # Source the new bashrc
        if source "${HOME}/.bashrc"; then
            pass "Sourced new ${HOME}/.bashrc."
            return "${_PASS}"
        else
            fail "Failed to source ${HOME}/.bashrc."
            return "${_FAIL}"
        fi
    }

    # Function to undo the setup of dotfiles
    function Undo_Setup_Dot_Files() {
        # Revert dotfiles in the home directory
        for file in "${COMMON_DOT_FILES[@]}"; do
            local target="${HOME}/.${file}"

            if [[ -f "${target}" ]]; then
                if ! restore_file "${target}"; then
                    info "No backup for ${target}. Leaving it untouched."
                else
                    pass "Restored ${target} from backup."
                fi
            fi
        done

        # Revert dotfiles in the bash directory
        for file in "${BASH_DOT_FILES[@]}"; do
            local target="${BASH_DIR}/${file}"

            if [[ -f "${target}" ]]; then
                if ! restore_file "${target}"; then
                    info "No backup for ${target}. Leaving it untouched."
                else
                    pass "Restored ${target} from backup."
                fi
            fi
        done

        # Reload the bashrc if it was restored
        if source "${HOME}/.bashrc"; then
            pass "Reloaded ${HOME}/.bashrc after undoing dotfile setup."
        else
            warn "Failed to reload ${HOME}/.bashrc after undoing dotfile setup."
        fi
    }

    # This function ensures that all directories listed in the REQUIRED_BASH_DIRECTORIES array are created.
    function Setup_Bash_Directories() {
        # Ensure the directories array is defined
        if [[ -z "${REQUIRED_BASH_DIRECTORIES+x}" ]]; then
            fail "Directories array is not defined."
            return "${_FAIL}"
        fi

        # Create directories
        for directory in "${REQUIRED_BASH_DIRECTORIES[@]}"; do
            if mkdir -p "${directory}"; then
                pass "Created directory ${directory}."
            else
                fail "Failed to create directory ${directory}."
            fi
        done
    }
fi

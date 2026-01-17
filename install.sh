#!/usr/bin/env bash
###############################################################################
# NAME         : install.sh
# DESCRIPTION  : Bash environment dotfiles installer with install/update/uninstall
#                modes. Requires common_core library at system location.
# AUTHOR       : Adam Compton
# DATE CREATED : 2024-12-16
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|------------------------------------------------
# 2024-12-16  | Adam Compton   | Initial creation
# 2025-01-09  | Adam Compton   | Consolidated from SetupBash.sh and menu_tasks.sh
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Minimal Logging (until common_core is loaded)
#===============================================================================
function _log_fail() { printf '[%s] [- FAIL  ] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }
function _log_pass() { printf '[%s] [+ PASS  ] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }
function _log_info() { printf '[%s] [* INFO  ] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }
function _log_warn() { printf '[%s] [! WARN  ] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2; }

#===============================================================================
# Constants
#===============================================================================
readonly SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Read version from project VERSION file
if [[ -f "${SCRIPT_DIR}/VERSION" ]]; then
    VERSION="$(< "${SCRIPT_DIR}/VERSION")"
else
    VERSION="unknown"
fi
readonly VERSION

# System paths
readonly COMMON_CORE_DIR="${HOME}/.config/bash/lib/common_core"
readonly COMMON_CORE_UTIL="${COMMON_CORE_DIR}/util.sh"
readonly BASH_DIR="${HOME}/.config/bash"
readonly BASH_LOG_DIR="${BASH_DIR}/log"
readonly DATA_DIR="${HOME}/DATA"

#===============================================================================
# Dotfile Lists
#===============================================================================
readonly -a COMMON_DOT_FILES=(
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

readonly -a BASH_DOT_FILES=(
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

readonly -a REQUIRED_DIRECTORIES=(
    "${DATA_DIR}/LOGS"
    "${BASH_DIR}"
    "${BASH_LOG_DIR}"
)

readonly -a RECOMMENDED_TOOLS=(
    "eza"
    "fzf"
    "ncat"
    "freeze"
    "bat"
    "duf"
    "btop"
)

###############################################################################
# usage
#------------------------------------------------------------------------------
# Purpose  : Display help message with usage information
# Usage    : usage
# Returns  : Always returns 0
###############################################################################
function usage() {
    cat << EOF
${SCRIPT_NAME} v${VERSION} - Bash environment dotfiles manager

USAGE:
    ${SCRIPT_NAME} [COMMAND] [OPTIONS]

COMMANDS:
    install     Install dotfiles and create directories (default)
    update      Update only changed dotfiles (checksum comparison)
    uninstall   Restore original dotfiles from backups

OPTIONS:
    -h, --help      Show this help message
    -v, --version   Show version
    -q, --quiet     Suppress non-error output
    -f, --force     Force overwrite without backup comparison
    --skip-tools    Skip recommended tool checks during install

EXAMPLES:
    ${SCRIPT_NAME}              # Install (default)
    ${SCRIPT_NAME} install      # Install dotfiles
    ${SCRIPT_NAME} update       # Update changed files only
    ${SCRIPT_NAME} uninstall    # Restore backups

REQUIREMENTS:
    - Bash 4.0+
    - common_core library at: ${COMMON_CORE_DIR}

EOF
}

###############################################################################
# preflight_checks
#------------------------------------------------------------------------------
# Purpose  : Verify system requirements before installation
# Usage    : preflight_checks
# Returns  : Number of errors found (0 = all checks passed)
# Checks   : Bash version, HOME variable, common_core installation
###############################################################################
function preflight_checks() {
    local errors=0

    # Check Bash version
    if [[ -z "${BASH_VERSION:-}" ]]; then
        _log_fail "This script must be run under Bash."
        ((errors++))
    elif [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        _log_fail "Bash 4.0+ required. Current: ${BASH_VERSION}"
        ((errors++))
    fi

    # Check HOME
    if [[ -z "${HOME:-}" ]]; then
        _log_fail "HOME environment variable not set."
        ((errors++))
    fi

    # Check common_core
    if [[ ! -d "${COMMON_CORE_DIR}" ]]; then
        _log_fail "common_core library not found at: ${COMMON_CORE_DIR}"
        _log_fail ""
        _log_fail "Please install common_core first:"
        _log_fail "  1. Clone: git clone https://github.com/tatanus/common_core.git"
        _log_fail "  2. Run its installer or copy to: ${COMMON_CORE_DIR}"
        ((errors++))
    elif [[ ! -f "${COMMON_CORE_UTIL}" ]]; then
        _log_fail "common_core util.sh not found at: ${COMMON_CORE_UTIL}"
        ((errors++))
    fi

    return "${errors}"
}

###############################################################################
# load_common_core
#------------------------------------------------------------------------------
# Purpose  : Source the common_core utility library
# Usage    : load_common_core
# Returns  : 0 on success, 1 on failure
# Requires : COMMON_CORE_UTIL variable set
###############################################################################
function load_common_core() {
    # shellcheck source=/dev/null
    if source "${COMMON_CORE_UTIL}"; then
        pass "Loaded common_core utilities"
        return 0
    else
        _log_fail "Failed to source common_core"
        return 1
    fi
}

###############################################################################
# setup_directories
#------------------------------------------------------------------------------
# Purpose  : Create required directories for bash configuration
# Usage    : setup_directories
# Returns  : Number of directories that failed to create
# Requires : REQUIRED_DIRECTORIES array, common_core logging functions
###############################################################################
function setup_directories() {
    info "Creating required directories..."
    local failed=0

    for dir in "${REQUIRED_DIRECTORIES[@]}"; do
        if [[ -d "${dir}" ]]; then
            debug "Directory exists: ${dir}"
        elif mkdir -p "${dir}"; then
            pass "Created: ${dir}"
        else
            fail "Failed to create: ${dir}"
            ((failed++))
        fi
    done

    return "${failed}"
}

###############################################################################
# check_recommended_tools
#------------------------------------------------------------------------------
# Purpose  : Check if recommended CLI tools are installed
# Usage    : check_recommended_tools
# Returns  : Always returns 0 (tools are optional)
# Requires : RECOMMENDED_TOOLS array, cmd::exists from common_core
###############################################################################
function check_recommended_tools() {
    info "Checking recommended tools..."

    for tool in "${RECOMMENDED_TOOLS[@]}"; do
        if cmd::exists "${tool}"; then
            pass "Found: ${tool}"
        else
            warn "Missing: ${tool} (optional)"
        fi
    done
}

###############################################################################
# files_differ
#------------------------------------------------------------------------------
# Purpose  : Compare two files using SHA-256 checksums
# Usage    : files_differ <source_file> <dest_file>
# Arguments:
#   $1 : Source file path
#   $2 : Destination file path
# Returns  : 0 if files differ (or dest missing), 1 if identical
# Requires : sha256sum or shasum command
###############################################################################
function files_differ() {
    local src="$1"
    local dest="$2"

    [[ ! -f "${dest}" ]] && return 0 # Dest doesn't exist = different

    local src_sum dest_sum
    if cmd::exists "sha256sum"; then
        src_sum=$(sha256sum "${src}" 2> /dev/null | cut -d' ' -f1)
        dest_sum=$(sha256sum "${dest}" 2> /dev/null | cut -d' ' -f1)
    elif cmd::exists "shasum"; then
        src_sum=$(shasum -a 256 "${src}" 2> /dev/null | cut -d' ' -f1)
        dest_sum=$(shasum -a 256 "${dest}" 2> /dev/null | cut -d' ' -f1)
    else
        # Fallback: always consider different if no checksum tool
        return 0
    fi

    [[ "${src_sum}" != "${dest_sum}" ]]
}

###############################################################################
# cmd_install
#------------------------------------------------------------------------------
# Purpose  : Install dotfiles and create required directories
# Usage    : cmd_install [skip_tools]
# Arguments:
#   $1 : "true" to skip tool checks (optional, default: "false")
# Returns  : 0 on success, 1 on failure
# Requires : common_core file::copy function
###############################################################################
function cmd_install() {
    local skip_tools="${1:-false}"

    info "Starting installation..."

    # Create directories
    setup_directories || return 1

    # Check source directory
    local src_dir="${SCRIPT_DIR}/dotfiles"
    if [[ ! -d "${src_dir}" ]]; then
        fail "Dotfiles directory not found: ${src_dir}"
        return 1
    fi

    # Install common dotfiles to HOME
    info "Installing common dotfiles to ${HOME}..."
    for file in "${COMMON_DOT_FILES[@]}"; do
        local src="${src_dir}/${file}"
        local dest="${HOME}/.${file}"

        if [[ ! -f "${src}" ]]; then
            warn "Source not found: ${src}"
            continue
        fi

        file::copy "${src}" "${dest}"
    done

    # Install bash dotfiles to BASH_DIR
    info "Installing bash dotfiles to ${BASH_DIR}..."
    for file in "${BASH_DOT_FILES[@]}"; do
        local src="${src_dir}/${file}"
        local dest="${BASH_DIR}/${file}"

        if [[ ! -f "${src}" ]]; then
            warn "Source not found: ${src}"
            continue
        fi

        file::copy "${src}" "${dest}"
    done

    # Check recommended tools
    if [[ "${skip_tools}" != "true" ]]; then
        check_recommended_tools
    fi

    # Source new bashrc
    if [[ -f "${HOME}/.bashrc" ]]; then
        info "To apply changes, run: source ~/.bashrc"
    fi

    pass "Installation complete!"
    return 0
}

###############################################################################
# cmd_update
#------------------------------------------------------------------------------
# Purpose  : Update only changed dotfiles (checksum comparison)
# Usage    : cmd_update
# Returns  : 0 on success, 1 on failure
# Requires : common_core file::copy function, files_differ function
###############################################################################
function cmd_update() {
    info "Checking for updates..."

    local src_dir="${SCRIPT_DIR}/dotfiles"
    if [[ ! -d "${src_dir}" ]]; then
        fail "Dotfiles directory not found: ${src_dir}"
        return 1
    fi

    local updated=0

    # Update common dotfiles
    for file in "${COMMON_DOT_FILES[@]}"; do
        local src="${src_dir}/${file}"
        local dest="${HOME}/.${file}"

        [[ ! -f "${src}" ]] && continue

        if files_differ "${src}" "${dest}"; then
            info "Updating: ${dest}"
            file::copy "${src}" "${dest}"
            ((updated++))
        else
            debug "Unchanged: ${dest}"
        fi
    done

    # Update bash dotfiles
    for file in "${BASH_DOT_FILES[@]}"; do
        local src="${src_dir}/${file}"
        local dest="${BASH_DIR}/${file}"

        [[ ! -f "${src}" ]] && continue

        if files_differ "${src}" "${dest}"; then
            info "Updating: ${dest}"
            file::copy "${src}" "${dest}"
            ((updated++))
        else
            debug "Unchanged: ${dest}"
        fi
    done

    if [[ "${updated}" -eq 0 ]]; then
        info "All dotfiles are up to date."
    else
        pass "Updated ${updated} file(s)."
        info "To apply changes, run: source ~/.bashrc"
    fi

    return 0
}

###############################################################################
# cmd_uninstall
#------------------------------------------------------------------------------
# Purpose  : Restore original dotfiles from backups
# Usage    : cmd_uninstall
# Returns  : 0 always
# Requires : common_core file::restore_old_backup function
###############################################################################
function cmd_uninstall() {
    info "Restoring original dotfiles..."

    local restored=0

    # Restore common dotfiles
    for file in "${COMMON_DOT_FILES[@]}"; do
        local target="${HOME}/.${file}"
        if [[ -f "${target}" ]]; then
            file::restore_old_backup "${target}" && ((restored++))
        fi
    done

    # Restore bash dotfiles
    for file in "${BASH_DOT_FILES[@]}"; do
        local target="${BASH_DIR}/${file}"
        if [[ -f "${target}" ]]; then
            file::restore_old_backup "${target}" && ((restored++))
        fi
    done

    if [[ "${restored}" -eq 0 ]]; then
        info "No backups found to restore."
    else
        pass "Restored ${restored} file(s) from backups."
    fi

    info "To apply changes, run: source ~/.bashrc"
    return 0
}

###############################################################################
# main
#------------------------------------------------------------------------------
# Purpose  : Main entry point - parse arguments and execute commands
# Usage    : main "$@"
# Returns  : 0 on success, 1 on failure
###############################################################################
function main() {
    local command="install"
    local skip_tools=false
    # shellcheck disable=SC2034 # TODO: quiet mode not yet implemented
    local quiet=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            install | update | uninstall)
                command="$1"
                shift
                ;;
            -h | --help)
                usage
                return 0
                ;;
            -v | --version)
                echo "${SCRIPT_NAME} v${VERSION}"
                return 0
                ;;
            -q | --quiet)
                # shellcheck disable=SC2034 # TODO: quiet mode not yet implemented
                quiet=true
                shift
                ;;
            -f | --force)
                # Force mode - currently same as install
                shift
                ;;
            --skip-tools)
                skip_tools=true
                shift
                ;;
            *)
                _log_fail "Unknown option: $1"
                usage >&2
                return 1
                ;;
        esac
    done

    # Preflight checks
    if ! preflight_checks; then
        return 1
    fi

    # Load common_core
    if ! load_common_core; then
        return 1
    fi

    # Execute command
    case "${command}" in
        install)
            cmd_install "${skip_tools}"
            ;;
        update)
            cmd_update
            ;;
        uninstall)
            cmd_uninstall
            ;;
        *)
            fail "Unknown command: ${command}"
            return 1
            ;;
    esac
}

main "$@"

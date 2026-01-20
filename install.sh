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
# 2026-01-19  | Adam Compton   | Hardened contracts, fixed preflight logic,
#                              | logging fallbacks, and common_core API checks
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Globals
#===============================================================================
: "${QUIET:=false}"
: "${PASS:=0}"
: "${FAIL:=1}"

#===============================================================================
# Logging Fallbacks
#===============================================================================
if ! declare -F info > /dev/null 2>&1; then
    function info()  { [[ "${QUIET}" == "true" ]] && return 0; printf '[INFO ] %s\n' "${*}" >&2; }
fi
if ! declare -F warn > /dev/null 2>&1; then
    function warn()  { printf '[WARN ] %s\n' "${*}" >&2; }
fi
if ! declare -F error > /dev/null 2>&1; then
    function error() { printf '[ERROR] %s\n' "${*}" >&2; }
fi
if ! declare -F debug > /dev/null 2>&1; then
    function debug() { [[ "${QUIET}" == "true" ]] && return 0; printf '[DEBUG] %s\n' "${*}" >&2; }
fi
if ! declare -F pass > /dev/null 2>&1; then
    function pass()  { [[ "${QUIET}" == "true" ]] && return 0; printf '[PASS ] %s\n' "${*}" >&2; }
fi
if ! declare -F fail > /dev/null 2>&1; then
    function fail()  { printf '[FAIL ] %s\n' "${*}" >&2; }
fi

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
readonly DOTFILES_DIR="${SCRIPT_DIR}/dotfiles"

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

#===============================================================================
# Capability flags (populated in preflight)
#===============================================================================
HAS_SHA256_TOOL="false"
SHA256_TOOL="" # "sha256sum" or "shasum"

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

NOTES:
    - If neither sha256sum nor shasum exists, update mode will treat all files as "different"
      and overwrite targets (a warning will be emitted).
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

    # Bash version
    if [[ -z "${BASH_VERSION:-}" ]]; then
        fail "This script must be run under Bash."
        ((errors++))
    elif [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        fail "Bash 4.0+ required. Current: ${BASH_VERSION}"
        ((errors++))
    fi

    # HOME sanity
    if [[ -z "${HOME:-}" ]]; then
        fail "HOME environment variable not set."
        ((errors++))
    elif [[ ! -d "${HOME}" ]]; then
        fail "HOME does not exist or is not a directory: ${HOME}"
        ((errors++))
    fi

    # common_core presence
    if [[ ! -d "${COMMON_CORE_DIR}" ]]; then
        fail "common_core library not found at: ${COMMON_CORE_DIR}"
        fail "Install common_core first (example):"
        fail "  git clone https://github.com/tatanus/common_core.git"
        fail "  then run its installer / copy into: ${COMMON_CORE_DIR}"
        ((errors++))
    elif [[ ! -f "${COMMON_CORE_UTIL}" ]]; then
        fail "common_core util.sh not found at: ${COMMON_CORE_UTIL}"
        ((errors++))
    fi

    # Repo layout
    if [[ ! -d "${DOTFILES_DIR}" ]]; then
        fail "Dotfiles directory not found: ${DOTFILES_DIR}"
        ((errors++))
    fi

    # Capability detection: SHA-256
    if command -v sha256sum >/dev/null 2>&1; then
        HAS_SHA256_TOOL="true"
        SHA256_TOOL="sha256sum"
    elif command -v shasum >/dev/null 2>&1; then
        HAS_SHA256_TOOL="true"
        SHA256_TOOL="shasum"
    else
        HAS_SHA256_TOOL="false"
        SHA256_TOOL=""
        warn "No sha256sum or shasum found; update mode will overwrite without checksum equality checks."
    fi

    [[ "${errors}" -eq 0 ]]
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
    # Force clean bootstrap even if already sourced in this shell
    unset COMMON_CORE_INITIALIZED 2>/dev/null || true

    # shellcheck source=/dev/null
    if ! source "${COMMON_CORE_UTIL}"; then
        fail "Failed to source common_core: ${COMMON_CORE_UTIL}"
        return 1
    fi

    # Verify required symbols exist (older common_core versions can differ)
    local required_funcs=(
        cmd::exists
        file::copy
        file::restore_old_backup
        info warn debug pass fail
    )

    local f
    for f in "${required_funcs[@]}"; do
        if ! declare -F "${f}" >/dev/null 2>&1; then
            fail "common_core is missing required function: ${f}"
            return 1
        fi
    done

    pass "Loaded common_core utilities"
    return 0
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
    local dir=""

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

    [[ "${failed}" -eq 0 ]]
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
    local tool=""

    for tool in "${RECOMMENDED_TOOLS[@]}"; do
        if cmd::exists "${tool}"; then
            pass "Found: ${tool}"
        else
            warn "Missing: ${tool} (optional)"
        fi
    done

    return 0
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

    [[ ! -f "${dest}" ]] && return 0

    # If no SHA tool, treat as different (caller may overwrite)
    if [[ "${HAS_SHA256_TOOL}" != "true" ]]; then
        return 0
    fi

    local src_sum="" dest_sum=""

    if [[ "${SHA256_TOOL}" == "sha256sum" ]]; then
        src_sum="$(sha256sum "${src}" 2>/dev/null | cut -d' ' -f1)"
        dest_sum="$(sha256sum "${dest}" 2>/dev/null | cut -d' ' -f1)"
    elif [[ "${SHA256_TOOL}" == "shasum" ]]; then
        src_sum="$(shasum -a 256 "${src}" 2>/dev/null | cut -d' ' -f1)"
        dest_sum="$(shasum -a 256 "${dest}" 2>/dev/null | cut -d' ' -f1)"
    else
        # Defensive fallback
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

    setup_directories || return 1

    info "Installing common dotfiles to ${HOME}..."
    local file="" src="" dest=""
    for file in "${COMMON_DOT_FILES[@]}"; do
        src="${DOTFILES_DIR}/${file}"
        dest="${HOME}/.${file}"

        if [[ ! -f "${src}" ]]; then
            warn "Source not found: ${src}"
            continue
        fi

        file::copy "${src}" "${dest}"
    done

    info "Installing bash dotfiles to ${BASH_DIR}..."
    for file in "${BASH_DOT_FILES[@]}"; do
        src="${DOTFILES_DIR}/${file}"
        dest="${BASH_DIR}/${file}"

        if [[ ! -f "${src}" ]]; then
            warn "Source not found: ${src}"
            continue
        fi

        file::copy "${src}" "${dest}"
    done

    # Configure screen based on version
    setup_screenrc || return 1

    if [[ "${skip_tools}" != "true" ]]; then
        check_recommended_tools
    fi

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

    local updated=0
    local file="" src="" dest=""

    for file in "${COMMON_DOT_FILES[@]}"; do
        src="${DOTFILES_DIR}/${file}"
        dest="${HOME}/.${file}"
        [[ ! -f "${src}" ]] && continue

        if files_differ "${src}" "${dest}"; then
            info "Updating: ${dest}"
            file::copy "${src}" "${dest}"
            ((updated++))
        else
            debug "Unchanged: ${dest}"
        fi
    done

    for file in "${BASH_DOT_FILES[@]}"; do
        src="${DOTFILES_DIR}/${file}"
        dest="${BASH_DIR}/${file}"
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

    # Configure screen based on version
    setup_screenrc || return 1

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
    local file="" target=""

    for file in "${COMMON_DOT_FILES[@]}"; do
        target="${HOME}/.${file}"
        if [[ -f "${target}" ]]; then
            file::restore_old_backup "${target}" && ((restored++))
        fi
    done

    for file in "${BASH_DOT_FILES[@]}"; do
        target="${BASH_DIR}/${file}"
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
# setup_screenrc
#------------------------------------------------------------------------------
# Purpose  : Install correct ~/.screenrc based on installed screen major version
# Usage    : setup_screenrc
# Returns  : 0 on success or if screen not installed, 1 on error
###############################################################################
function setup_screenrc() {
    if ! cmd::exists screen; then
        warn "GNU screen not found; skipping ~/.screenrc setup."
        return 0
    fi

    local version major src dest
    version="$(screen --version 2>/dev/null | awk '{print $NF}')"
    major="${version%%.*}"
    dest="${HOME}/.screenrc"

    case "${major}" in
        4)
            src="${HOME}/.screenrc_v4"
            ;;
        5)
            src="${HOME}/.screenrc_v5"
            ;;
        *)
            warn "Unsupported screen version: ${version}; skipping ~/.screenrc setup."
            return 0
            ;;
    esac

    if [[ ! -f "${src}" ]]; then
        fail "Expected screen config not found: ${src}"
        return 1
    fi

    info "Installing screen config for screen ${version} -> ${dest}"
    file::copy "${src}" "${dest}"
    pass "Configured ~/.screenrc for screen ${major}.x"

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
    local skip_tools="false"
    local force="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            install|update|uninstall)
                command="$1"
                shift
                ;;
            -h|--help)
                usage
                return 0
                ;;
            -v|--version)
                echo "${SCRIPT_NAME} v${VERSION}"
                return 0
                ;;
            -q|--quiet)
                QUIET="true"
                shift
                ;;
            -f|--force)
                force="true"
                shift
                ;;
            --skip-tools)
                skip_tools="true"
                shift
                ;;
            *)
                fail "Unknown option: $1"
                usage >&2
                return 1
                ;;
        esac
    done

    # Preflight checks (fixed: correct boolean handling)
    preflight_checks || return 1

    # Load common_core and validate API
    load_common_core || return 1

    # NOTE: If your common_core file::copy supports a force flag, you can
    # standardize that via an env var or wrapper. This script does not assume it.
    if [[ "${force}" == "true" ]]; then
        warn "--force was requested. If common_core honors a force mode via env/flags, ensure it is enabled there."
    fi

    case "${command}" in
        install)   cmd_install "${skip_tools}" ;;
        update)    cmd_update ;;
        uninstall) cmd_uninstall ;;
        *)
            fail "Unknown command: ${command}"
            return 1
            ;;
    esac
}

main "$@"

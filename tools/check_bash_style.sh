#!/usr/bin/env bash
###############################################################################
# NAME         : check_bash_style.sh
# DESCRIPTION  : Comprehensive Bash style checker using ShellCheck, shfmt,
#                and custom regex checks for prohibited patterns.
# AUTHOR       : Adam Compton
# DATE CREATED : 2024-12-16
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|------------------------------------------------
# 2024-12-16  | Adam Compton   | Initial creation
# 2025-01-09  | Adam Compton   | Moved to tools/, updated to style guide
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Constants
#===============================================================================
PASS=0
FAIL=1
readonly PASS FAIL

SHELLCHECK_RC=".shellcheckrc"
STYLE_FAIL=0

#===============================================================================
# Logging Functions
#===============================================================================
info()  { printf '[INFO ] %s\n' "$*"; }
warn()  { printf '[WARN ] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

###############################################################################
# run_shellcheck
#------------------------------------------------------------------------------
# Purpose  : Run ShellCheck on all .sh files in current directory
# Usage    : run_shellcheck
# Returns  : Sets STYLE_FAIL=1 if ShellCheck reports errors
###############################################################################
run_shellcheck() {
    info "Running ShellCheck..."
    if ! find . -type f -name "*.sh" -print0 \
        | xargs -0 shellcheck --shell=bash --rcfile="${SHELLCHECK_RC}"; then
        error "ShellCheck failed"
        STYLE_FAIL=1
    fi
}

###############################################################################
# run_shfmt
#------------------------------------------------------------------------------
# Purpose  : Check formatting of all .sh files using shfmt
# Usage    : run_shfmt
# Returns  : Sets STYLE_FAIL=1 if formatting issues found
###############################################################################
run_shfmt() {
    info "Checking formatting with shfmt..."
    if ! find . -type f -name "*.sh" -print0 \
        | xargs -0 shfmt -d -i 4 -ci -bn -kp -sr -ln bash; then
        error "shfmt reported formatting issues"
        STYLE_FAIL=1
    fi
}

###############################################################################
# run_custom_checks
#------------------------------------------------------------------------------
# Purpose  : Run custom regex-based style checks for prohibited patterns
# Usage    : run_custom_checks
# Returns  : Sets STYLE_FAIL=1 if prohibited patterns found
# Checks   : set -e, echo -e, backticks, for f in $(ls)
###############################################################################
run_custom_checks() {
    info "Running custom regex style checks..."

    # Helper: filter out comment lines while keeping filename:line prefix
    local awk_filter="{ code=\$0; sub(/^[^:]+:[0-9]+:/,\"\",code); if (code !~ /^[[:space:]]*#/) print \$0 }"

    # Ban set -e / errexit
    if grep -rn --include="*.sh" -E "set[[:space:]]+-?(e|eu)|set -o errexit" . \
        | awk "${awk_filter}" | grep -v "check_bash_style.sh"; then
        error "Found disallowed use of 'set -e'"
        STYLE_FAIL=1
    fi

    # Ban echo -e
    if grep -rn --include="*.sh" -E "echo[[:space:]]+-e" . \
        | awk "${awk_filter}" | grep -v "check_bash_style.sh"; then
        error "Found disallowed 'echo -e'"
        STYLE_FAIL=1
    fi

    # Ban backticks
    if grep -rn --include="*.sh" '`' . \
        | awk "${awk_filter}" | grep -v "check_bash_style.sh"; then
        error "Found disallowed backticks (use \$(...) instead)"
        STYLE_FAIL=1
    fi

    # Ban for f in $(ls)
    if grep -rn --include="*.sh" -E "for[[:space:]]+f[[:space:]]+in[[:space:]]+\$\\(ls" . \
        | awk "${awk_filter}" | grep -v "check_bash_style.sh"; then
        error "Found disallowed 'for f in \$(ls)'"
        STYLE_FAIL=1
    fi
}

###############################################################################
# main
#------------------------------------------------------------------------------
# Purpose  : Main entry point - runs all style checks
# Usage    : main "$@"
# Returns  : PASS (0) if all checks pass, FAIL (1) otherwise
###############################################################################
main() {
    run_shellcheck
    run_shfmt
    run_custom_checks

    if [[ "${STYLE_FAIL}" -eq 1 ]]; then
        error "Style guide violations found."
        exit "${FAIL}"
    fi

    info "All Bash scripts passed style checks."
    exit "${PASS}"
}

main "$@"

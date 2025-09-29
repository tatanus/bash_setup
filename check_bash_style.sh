#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

PASS=0
FAIL=1
readonly PASS FAIL

SHELLCHECK_RC=".shellcheckrc"
STYLE_FAIL=0

function info()  { printf '[INFO ] %s\n' "${1}"; }
# shellcheck disable=SC2317
function warn()  { printf '[WARN ] %s\n' "${1}"; }
function error() { printf '[ERROR] %s\n' "${1}" >&2; }

###############################################################################
# run_shellcheck
###############################################################################
function run_shellcheck() {
    info "Running ShellCheck..."
    if ! find . -type f -name "*.sh" -print0 | xargs -0 shellcheck --shell=bash --rcfile="${SHELLCHECK_RC}"; then
        error "ShellCheck failed"
        STYLE_FAIL=1
    fi
}

###############################################################################
# run_shfmt
###############################################################################
function run_shfmt() {
    info "Checking formatting with shfmt..."
    if ! find . -type f -name "*.sh" -print0 | xargs -0 shfmt -d -i 4 -ci -bn -kp -sr -ln bash; then
        error "shfmt reported formatting issues"
        STYLE_FAIL=1
    fi
}

###############################################################################
# run_custom_checks
###############################################################################
function run_custom_checks() {
    info "Running custom regex style checks..."

    # Ban set -e / errexit (skip comments and this script)
    if grep -rn --include="*.sh" -E "set[[:space:]]+-?(e|eu)|set -o errexit" . \
        | grep -vE '^\s*#' | grep -v "check_bash_style.sh"; then
        error "Found disallowed use of 'set -e'"
        STYLE_FAIL=1
    fi

    # Ban echo -e (skip comments and this script)
    if grep -rn --include="*.sh" -E "^\s*echo -e" . \
        | grep -vE '^\s*#' | grep -v "check_bash_style.sh"; then
        error "Found disallowed 'echo -e'"
        STYLE_FAIL=1
    fi

    # Ban backticks (skip comments and this script)
    if grep -rn --include="*.sh" '`' . \
        | grep -vE '^\s*#' | grep -v "check_bash_style.sh"; then
        error "Found disallowed backticks (use \$(...) instead)"
        STYLE_FAIL=1
    fi

    # Ban for f in $(ls) (skip comments and this script)
    if grep -rn --include="*.sh" -E "for[[:space:]]+f[[:space:]]+in[[:space:]]+\$\\(ls" . \
        | grep -vE '^\s*#' | grep -v "check_bash_style.sh"; then
        error "Found disallowed 'for f in $(ls)'"
        STYLE_FAIL=1
    fi
}

###############################################################################
# main
###############################################################################
function main() {
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

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
# shellcheck disable=SC2329
function warn()  { printf '[WARN ] %s\n' "${1}"; }
function error() { printf '[ERROR] %s\n' "${1}" >&2; }

###############################################################################
# run_shellcheck
###############################################################################
function run_shellcheck() {
    info "Running ShellCheck..."
    if ! find . -type f -name "*.sh" -print0 \
        | xargs -0 shellcheck --shell=bash --rcfile="${SHELLCHECK_RC}"; then
        error "ShellCheck failed"
        STYLE_FAIL=1
    fi
}

###############################################################################
# run_shfmt
###############################################################################
function run_shfmt() {
    info "Checking formatting with shfmt..."
    if ! find . -type f -name "*.sh" -print0 \
        | xargs -0 shfmt -d -i 4 -ci -bn -kp -sr -ln bash; then
        error "shfmt reported formatting issues"
        STYLE_FAIL=1
    fi
}

###############################################################################
# run_custom_checks
###############################################################################
###############################################################################
# run_custom_checks
###############################################################################
function run_custom_checks() {
    info "Running custom regex style checks..."

    # Helper: filter out comment lines while keeping filename:line prefix
    # Example grep output: ./file.sh:123:    # comment
    # awk splits on ":", checks $3 (the code), and skips if it starts with "#"
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

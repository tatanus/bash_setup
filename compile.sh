#!/usr/bin/env bash
###############################################################################
# NAME         : compile.sh
# DESCRIPTION  : Safe wrapper for CI/test/commit workflow.
#                Subcommands:
#                  - test   : update submodules, run CI, run tests
#                  - commit : update submodules, run CI, run tests,
#                             refresh README submodules section,
#                             auto-increment VERSION (patch), commit & push
###############################################################################

set -Eeuo pipefail
IFS=$'\n\t'

# ----------------------------- Logging helpers ------------------------------ #
readonly blue='\033[34m'
readonly green='\033[92m'
readonly yellow='\033[33m'
readonly red='\033[91m'
readonly reset='\033[0m'

log_info() { printf '%b[* INFO  ]%b %s\n' "${blue}" "${reset}" "$*"; }
log_pass() { printf '%b[+ PASS  ]%b %s\n' "${green}" "${reset}" "$*"; }
log_warn() { printf '%b[! WARN  ]%b %s\n' "${yellow}" "${reset}" "$*"; }
log_fail() { printf '%b[- FAIL  ]%b %s\n' "${red}" "${reset}" "$*"; }

trap 'log_fail "Unexpected error at ${BASH_SOURCE[0]##*/}:${LINENO}"; exit 1' ERR

# ------------------------------ Util checks --------------------------------- #
require_bin() {
    if ! command -v "${1}" > /dev/null 2>&1; then
        log_fail "Missing required command: ${1}"
        exit 1
    fi
}

ensure_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_fail "Not inside a Git repository."
        exit 1
    fi
}

# ------------------------- README submodules update ------------------------- #
update_readme_submodules() {
    local -r readme='README.md'
    local -r mark_start='<!-- SUBMODULES-LIST:START -->'
    local -r mark_end='<!-- SUBMODULES-LIST:END -->'

    # helper: normalize SSH -> HTTPS for common forms
    _normalize_url() {
        local url
        url=${1:-}
        if [[ ${url} =~ ^git@([^:]+):(.+)$ ]]; then
            printf 'https://%s/%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
            return 0
        fi
        if [[ ${url} =~ ^ssh://git@([^/]+)/(.+)$ ]]; then
            printf 'https://%s/%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
            return 0
        fi
        printf '%s' "${url}"
    }

    if [[ ! -f .gitmodules ]]; then
        log_info 'No .gitmodules found; skipping README submodules section.'
        return 0
    fi

    # Collect submodule paths (unique & sorted for stable output)
    local -a paths=()
    # shellcheck disable=SC2016
    while IFS= read -r line; do
        paths+=("${line}")
    done < <(git config --file .gitmodules --get-regexp 'submodule\..*\.path' | awk '{print $2}' | sort -u)

    local list_content=''
    if ((${#paths[@]} == 0)); then
        list_content='* _No submodules configured_\n'
    else
        local path url norm
        for path in "${paths[@]}"; do
            url=$(git config --file .gitmodules --get "submodule.${path}.url" || true)
            norm=$(_normalize_url "${url}")
            list_content+="* [${path}](${norm})\n"
        done
    fi

    # Ensure README exists
    if [[ ! -f ${readme} ]]; then
        log_warn 'README.md not found; creating one.'
        printf '# Project\n\n' > "${readme}"
    fi

    # Build replacement block and write to a temp file (avoid awk -v multiline)
    local block tmpblock
    printf -v block '## Submodules\n%s\n\n%b\n%s\n' "${mark_start}" "${list_content}" "${mark_end}"
    tmpblock=$(mktemp)
    printf '%s\n' "${block}" > "${tmpblock}"

    # Replace or append block atomically, reading content from tmp file
    if grep -qF "${mark_start}" "${readme}"; then
        awk -v start="${mark_start}" -v end="${mark_end}" -v newfile="${tmpblock}" '
            BEGIN { in_block=0 }
            {
                if ($0 ~ start) {
                    # print replacement block from file
                    while ((getline line < newfile) > 0) print line
                    close(newfile)
                    in_block=1
                    next
                }
                if ($0 ~ end) { in_block=0; next }
                if (in_block==0) print $0
            }
        ' "${readme}" > "${readme}.tmp"
        mv "${readme}.tmp" "${readme}"
        log_info 'Updated README submodules section.'
    else
        {
            printf '\n'
            cat "${tmpblock}"
        } >> "${readme}"
        log_info 'Appended README submodules section.'
    fi

    rm -f "${tmpblock}"
    log_pass 'README submodules refreshed.'
}

# ------------------------------- Core steps --------------------------------- #
update_submodules() {
    log_info 'Updating submodules (init + sync + recursive update)...'
    make submodules-init
    make submodules-update
    log_pass 'Submodules updated.'
}

run_ci() {
    log_info 'Running CI (format + lint + tests)...'
    make ci
    log_pass 'CI passed.'
}

run_tests() {
    log_info 'Running test suite...'
    make test
    log_pass 'Tests completed (or skipped if none present).'
}

prompt_commit_msg() {
    local msg
    printf '\n'
    read -r -p 'Enter git commit message: ' msg
    if [[ -z ${msg} ]]; then
        log_fail 'Commit message cannot be empty.'
        exit 1
    fi
    printf '%s' "${msg}"
}

bump_version() {
    local -r version_file='VERSION'
    local current
    local next
    local major
    local minor
    local patch

    if [[ ! -f ${version_file} ]]; then
        next='0.1.0'
        printf '%s' "${next}" > "${version_file}"
        log_info "VERSION file created with initial version ${next}"
    else
        current="$(< "${version_file}")"
        if [[ ${current} =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
            major="${BASH_REMATCH[1]}"
            minor="${BASH_REMATCH[2]}"
            patch="${BASH_REMATCH[3]}"
            patch=$((patch + 1))
            next="${major}.${minor}.${patch}"
            printf '%s' "${next}" > "${version_file}"
            log_info "VERSION bumped: ${current} -> ${next}"
        else
            log_warn "VERSION malformed (${current}), resetting to 0.1.0"
            next='0.1.0'
            printf '%s' "${next}" > "${version_file}"
        fi
    fi

    git add "${version_file}"
    printf '%s' "${next}"
}

do_commit_and_push() {
    ensure_git_repo

    # Keep README submodules section fresh BEFORE staging
    update_readme_submodules

    # Stage everything
    log_info 'Staging changes...'
    git add -A

    # Prompt for message up front
    local msg
    msg="$(prompt_commit_msg)"

    # Always bump VERSION (ensures a commit occurs when only metadata changed)
    local new_ver
    new_ver="$(bump_version)"

    # Re-stage (captures VERSION + README changes)
    git add -A

    # If still nothing to commit, exit gracefully
    if git diff --cached --quiet; then
        log_warn 'No staged changes to commit (working tree clean).'
        return 0
    fi

    log_info 'Committing changes...'
    git commit -m "${msg}" -m "Version: ${new_ver}"

    log_info 'Pushing to current upstream...'
    git push
    log_pass "Push complete (version ${new_ver})."
}

main() {
    require_bin git
    require_bin make
    require_bin awk
    require_bin mktemp

    local cmd
    cmd=${1:-}
    case "${cmd}" in
        test)
            update_submodules
            run_ci
            run_tests
            log_pass "Workflow 'test' completed successfully."
            ;;
        commit)
            update_submodules
            run_ci
            run_tests
            do_commit_and_push
            log_pass "Workflow 'commit' completed successfully."
            ;;
        '' | help | -h | --help)
            cat << 'USAGE'
Usage:
  ./compile.sh test
      - Update submodules
      - Run CI (format + lint + tests)
      - Run tests (explicit)

  ./compile.sh commit
      - Update submodules
      - Run CI (format + lint + tests)
      - Run tests (explicit)
      - Refresh README Submodules block (idempotent)
      - Prompt for commit message
      - Auto-increment VERSION (patch)
      - Git commit & push
USAGE
            ;;
        *)
            log_fail "Unknown subcommand: ${cmd}"
            printf 'Try: ./compile.sh test | commit\n'
            exit 2
            ;;
    esac
}

main "$@"

#!/usr/bin/env bash
###############################################################################
# NAME         : compile.sh
# DESCRIPTION  : Safe wrapper for CI/test/commit workflow.
#                Subcommands:
#                  - test   : update submodules, run CI, run tests
#                  - commit : update submodules, run CI, run tests,
#                             auto-increment VERSION, git commit & push
# AUTHOR       : Your Name
# DATE CREATED : 2025-09-11
###############################################################################
# USAGE:
#   ./compile.sh test
#   ./compile.sh commit
###############################################################################

set -Eeuo pipefail
IFS=$'\n\t'

#------------------------------#
# Logging helpers
#------------------------------#
blue='\033[34m'; green='\033[92m'; yellow='\033[33m'; red='\033[91m'; reset='\033[0m'
log_info()  { printf "${blue}[* INFO  ]${reset} %s\n"   "$*"; }
log_pass()  { printf "${green}[+ PASS  ]${reset} %s\n"  "$*"; }
log_warn()  { printf "${yellow}[! WARN  ]${reset} %s\n" "$*"; }
log_fail()  { printf "${red}[- FAIL  ]${reset} %s\n"    "$*"; }

trap 'log_fail "Unexpected error at ${BASH_SOURCE[0]##*/}:${LINENO}"; exit 1' ERR

#------------------------------#
# Utility checks
#------------------------------#
require_bin() {
    command -v "$1" >/dev/null 2>&1 || { log_fail "Missing required command: $1"; exit 1; }
}
ensure_git_repo() {
    git rev-parse --git-dir >/dev/null 2>&1 || { log_fail "Not inside a Git repository."; exit 1; }
}

#------------------------------#
# Core steps
#------------------------------#
update_submodules() {
    log_info "Updating submodules (init + sync + recursive update)…"
    make submodules-init
    make submodules-update
    log_pass "Submodules updated."
}

run_ci() {
    log_info "Running CI (format + lint + tests)…"
    make ci
    log_pass "CI passed."
}

run_tests() {
    log_info "Running test suite…"
    make test
    log_pass "All tests passed."
}

prompt_commit_msg() {
    local msg
    echo
    read -rp "Enter git commit message: " msg
    if [[ -z "${msg}" ]]; then
        log_fail "Commit message cannot be empty."
        exit 1
    fi
    printf "%s" "$msg"
}

bump_version() {
    local version_file="VERSION"
    local current next major minor patch
    if [[ ! -f $version_file ]]; then
        next="0.1.0"
        echo "$next" > "$version_file"
        log_info "VERSION file created with initial version $next"
    else
        current="$(<"$version_file")"
        if [[ $current =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
            major="${BASH_REMATCH[1]}"
            minor="${BASH_REMATCH[2]}"
            patch="${BASH_REMATCH[3]}"
            patch=$((patch + 1))
            next="${major}.${minor}.${patch}"
            echo "$next" > "$version_file"
            log_info "VERSION bumped: $current → $next"
        else
            log_warn "VERSION file malformed ($current), resetting to 0.1.0"
            echo "0.1.0" > "$version_file"
            next="0.1.0"
        fi
    fi
    git add "$version_file"
    echo "$next"
}

do_commit_and_push() {
    ensure_git_repo

    # Stage everything (including VERSION bump later)
    git add -A

    if git diff --cached --quiet; then
        log_warn "No staged changes to commit (working tree clean)."
        return 0
    fi

    # Commit message prompt
    local msg
    msg="$(prompt_commit_msg)"

    # Auto bump VERSION before commit
    local new_ver
    new_ver="$(bump_version)"

    log_info "Committing changes…"
    git commit -m "$msg" -m "Version: $new_ver"

    log_info "Pushing to current upstream…"
    git push
    log_pass "Push complete (version $new_ver)."
}

#------------------------------#
# Main
#------------------------------#
main() {
    require_bin git
    require_bin make

    local cmd="${1:-}"
    case "$cmd" in
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
        ""|help|-h|--help)
            cat <<'USAGE'
Usage:
  ./compile.sh test
      - Update submodules
      - Run CI (format + lint + tests)
      - Run tests (explicit)

  ./compile.sh commit
      - Update submodules
      - Run CI (format + lint + tests)
      - Run tests (explicit)
      - Prompt for commit message
      - Auto-increment VERSION (patch)
      - Git commit & push
USAGE
            ;;
        *)
            log_fail "Unknown subcommand: $cmd"
            echo "Try: ./compile.sh test | commit"
            exit 2
            ;;
    esac
}

main "$@"

#!/usr/bin/env bash
###############################################################################
# NAME         : compile.sh
# DESCRIPTION  : Safe wrapper for CI/test/commit/release workflow.
#                Subcommands:
#                  - test     : update submodules, run CI, run tests
#                  - commit   : update submodules, run CI, run tests,
#                               refresh README submodules section,
#                               auto-increment VERSION (patch), commit & push
#                  - release  : update submodules, run CI, run tests,
#                               refresh README submodules section,
#                               set VERSION to X.Y.Z (or auto-bump patch),
#                               update CITATION.cff + docs/CHANGELOG.md,
#                               commit, tag vX.Y.Z, and push (with tags)
###############################################################################
# Strict mode
set -Eeuo pipefail
IFS=$'\n\t'

#================================= Colors ====================================#
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

#=============================== Prerequisites ================================#
###############################################################################
# require_bin
#==============================
# Ensure a required executable exists in PATH.
#————————————————————
# Usage:
#   require_bin <bin>
###############################################################################
require_bin() {
    if ! command -v "${1}" > /dev/null 2>&1; then
        log_fail "Missing required command: ${1}"
        exit 1
    fi
}

###############################################################################
# ensure_git_repo
#==============================
# Ensure we are inside a Git repository.
###############################################################################
ensure_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_fail "Not inside a Git repository."
        exit 1
    fi
}

#========================== README submodules block ===========================#
###############################################################################
# update_readme_submodules
#==============================
# Renders a stable "Submodules" list block in README.md between markers:
# <!-- SUBMODULES-LIST:START --> ... <!-- SUBMODULES-LIST:END -->
###############################################################################
update_readme_submodules() {
    local -r readme='README.md'
    local -r mark_start='<!-- SUBMODULES-LIST:START -->'
    local -r mark_end='<!-- SUBMODULES-LIST:END -->'

    _normalize_url() {
        # Normalize common SSH forms to HTTPS for consistent links
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

#=============================== CI/Test steps ================================#
###############################################################################
# update_submodules
#==============================
# Initialize/sync/update submodules using Makefile targets.
###############################################################################
update_submodules() {
    log_info 'Updating submodules (init + sync + recursive update)...'
    make submodules-init
    make submodules-update
    log_pass 'Submodules updated.'
}

###############################################################################
# run_ci
#==============================
# Run project CI via Makefile (format + lint + tests hooks as defined).
###############################################################################
run_ci() {
    log_info 'Running CI (format + lint + tests)...'
    make ci
    log_pass 'CI completed.'
}

###############################################################################
# run_tests
#==============================
# Run explicit test suite (BATS, etc.) via Makefile.
###############################################################################
run_tests() {
    log_info 'Running test suite...'
    make test
    log_pass 'Tests completed (or skipped if none present).'
}

#=========================== Versioning & releasing ===========================#
###############################################################################
# read_version
#==============================
# Read current version from VERSION (first non-empty line).
# Returns via stdout.
###############################################################################
read_version() {
    if [[ -f VERSION ]]; then
        sed -n '1{s/^[[:space:]]*//;p;q}' VERSION
    fi
}

###############################################################################
# write_version
#==============================
# Overwrite VERSION with provided SemVer string.
###############################################################################
write_version() {
    local ver="${1:?missing version}"
    printf '%s\n' "${ver}" > VERSION
    git add VERSION
}

###############################################################################
# bump_patch_version
#==============================
# If VERSION exists and is SemVer, bump patch; else initialize to 0.1.0.
# Returns new version via stdout and stages VERSION.
###############################################################################
bump_patch_version() {
    local current next major minor patch
    if [[ -f VERSION ]]; then
        current="$(< VERSION)"
        if [[ ${current} =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
            major="${BASH_REMATCH[1]}"
            minor="${BASH_REMATCH[2]}"
            patch="${BASH_REMATCH[3]}"
            patch=$((patch + 1))
            next="${major}.${minor}.${patch}"
        else
            log_warn "VERSION malformed (${current}), resetting to 0.1.0"
            next='0.1.0'
        fi
    else
        next='0.1.0'
    fi
    write_version "${next}"
    log_info "VERSION set to ${next}"
    printf '%s' "${next}"
}

###############################################################################
# validate_semver
#==============================
# Validate X.Y.Z format; returns 0 if valid, 1 otherwise.
###############################################################################
validate_semver() {
    [[ "${1-}" =~ ^[0-9]+(\.[0-9]+){2}$ ]]
}

###############################################################################
# update_citation_for_release
#==============================
# Update CITATION.cff's version and date-released to match provided version.
###############################################################################
update_citation_for_release() {
    local ver="${1:?missing version}" d tmp
    d="$(date +%F)"
    [[ -f CITATION.cff ]] || {
        log_warn "CITATION.cff not found; skipping."
        return 0
    }
    tmp="$(mktemp)"
    awk -v ver="${ver}" -v d="${d}" '
      BEGIN{vc=0; dc=0}
      /^version:[[:space:]]*/{
        gsub(/".*"/, "\"" ver "\"")
        if ($0 !~ /"/) $0="version: \"" ver "\""
        vc=1
      }
      /^date-released:[[:space:]]*/{
        gsub(/".*"/, "\"" d "\"")
        if ($0 !~ /"/) $0="date-released: \"" d "\""
        dc=1
      }
      {print}
      END{
        if (vc==0) print "version: \"" ver "\""
        if (dc==0) print "date-released: \"" d "\""
      }
    ' CITATION.cff > "${tmp}"
    mv "${tmp}" CITATION.cff
    git add CITATION.cff
    log_info "CITATION.cff updated to ${ver} (${d})."
}

###############################################################################
# update_changelog_for_release
#==============================
# Ensure docs/CHANGELOG.md has a section for the provided version under
# "Unreleased". If missing, insert "## [X.Y.Z] - YYYY-MM-DD" with a stub.
###############################################################################
update_changelog_for_release() {
    local ver="${1:?missing version}" d chlog tmp
    d="$(date +%F)"
    chlog="docs/CHANGELOG.md"

    if [[ ! -f "${chlog}" ]]; then
        log_warn "Missing ${chlog}; creating a fresh changelog."
        cat > "${chlog}" << EOF
# Changelog
All notable changes to this project will be documented in this file.

## [Unreleased]

## [${ver}] - ${d}
### Added
- Initial notes for this release.
EOF
        git add "${chlog}"
        log_info "Created ${chlog} with ${ver} section."
        return 0
    fi

    if grep -qE "^## \\[${ver}\\]" "${chlog}"; then
        log_info "Changelog already contains section for ${ver}."
        return 0
    fi

    tmp="$(mktemp)"
    if grep -qE '^## \[Unreleased\]' "${chlog}"; then
        # Insert new version block right after Unreleased
        awk -v ver="${ver}" -v d="${d}" '
          BEGIN{done=0}
          {
            print $0
            if (!done && $0 ~ /^## \[Unreleased\]/) {
              print ""
              print "## [" ver "] - " d
              print "### Added"
              print "- (migrate relevant items from Unreleased)"
              print ""
              done=1
            }
          }
        ' "${chlog}" > "${tmp}" && mv "${tmp}" "${chlog}"
    else
        # No Unreleased section; prepend new section
        {
            echo "## [${ver}] - ${d}"
            echo "### Added"
            echo "- Release notes placeholder."
            echo
            cat "${chlog}"
        } > "${tmp}" && mv "${tmp}" "${chlog}"
    fi

    git add "${chlog}"
    log_info "Updated ${chlog} with ${ver} section."
}

#=============================== Commit & Push ================================#
###############################################################################
# prompt_commit_msg
#==============================
# Interactive prompt for a commit message (non-empty).
###############################################################################
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

###############################################################################
# do_commit_and_push
#==============================
# Shared "commit" flow (interactive message; auto patch bump).
###############################################################################
do_commit_and_push() {
    ensure_git_repo
    update_readme_submodules

    log_info 'Staging changes...'
    git add -A

    local msg new_ver
    msg="$(prompt_commit_msg)"
    new_ver="$(bump_patch_version)"

    git add -A

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

###############################################################################
# do_release
#==============================
# Non-interactive release flow:
# - update submodules, CI, tests
# - refresh README submodules
# - set version to X.Y.Z (arg) or auto patch bump
# - update CITATION.cff + docs/CHANGELOG.md
# - commit "chore(release): vX.Y.Z"
# - create annotated tag vX.Y.Z and push (with tags)
#
# Usage:
#   ./compile.sh release                # auto-bump patch
#   ./compile.sh release 1.2.3          # set exact version
###############################################################################
do_release() {
    ensure_git_repo

    # Refresh README submodules BEFORE staging
    update_readme_submodules
    git add -A

    local new_ver
    if [[ $# -ge 1 ]]; then
        local req_ver="$1"
        # Run validation outside of the conditional to keep set -e behavior intact (SC2310)
        validate_semver "${req_ver}"
        if [[ $? -ne 0 ]]; then
            log_fail "Invalid SemVer: ${req_ver} (expected X.Y.Z)"
            exit 2
        fi
        write_version "${req_ver}"
        new_ver="${req_ver}"
        log_info "VERSION set to ${new_ver} (explicit)."
    else
        new_ver="$(bump_patch_version)"
        log_info "VERSION auto-bumped to ${new_ver}."
    fi

    # Update citation + changelog for this release
    update_citation_for_release "${new_ver}"
    update_changelog_for_release "${new_ver}"

    # Stage everything (README/VERSION/CITATION/CHANGELOG/etc.)
    git add -A

    if git diff --cached --quiet; then
        log_warn 'No changes to commit for release (already up-to-date).'
    else
        git commit -m "chore(release): v${new_ver}" -m "Version: ${new_ver}"
        log_info "Committed release v${new_ver}."
    fi

    # Tag (idempotent if tag exists we warn and skip)
    if git rev-parse "v${new_ver}" > /dev/null 2>&1; then
        log_warn "Tag v${new_ver} already exists; skipping tag creation."
    else
        git tag -a "v${new_ver}" -m "Release v${new_ver}"
        log_info "Created tag v${new_ver}."
    fi

    # Push code + tags
    log_info 'Pushing branch and tags...'
    git push
    git push --tags
    log_pass "Release v${new_ver} pushed."
}

#=================================== Main ====================================#
main() {
    require_bin git
    require_bin make
    require_bin awk
    require_bin sed
    require_bin mktemp
    require_bin date

    local cmd arg_ver
    cmd="${1:-}"

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
        release)
            update_submodules
            run_ci
            run_tests
            shift || true
            arg_ver="${1-}"
            if [[ -n "${arg_ver}" ]]; then
                do_release "${arg_ver}"
            else
                do_release
            fi
            log_pass "Workflow 'release' completed successfully."
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

  ./compile.sh release [X.Y.Z]
      - Update submodules
      - Run CI (format + lint + tests)
      - Run tests (explicit)
      - Refresh README Submodules block (idempotent)
      - Set VERSION to X.Y.Z (or auto-bump patch if omitted)
      - Update CITATION.cff (version/date-released)
      - Update docs/CHANGELOG.md (new section for X.Y.Z)
      - Git commit "chore(release): vX.Y.Z"
      - Create annotated tag vX.Y.Z
      - Push branch and tags
USAGE
            ;;
        *)
            log_fail "Unknown subcommand: ${cmd}"
            printf 'Try: ./compile.sh test | commit | release [X.Y.Z]\n'
            exit 2
            ;;
    esac
}

main "$@"

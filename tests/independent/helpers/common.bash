# tests/independent/helpers/common.bash
# Shared helpers for bats tests in tests/independent/

# Simple predicate
function function_exists() {
  local fn="${1:-}"
  if [[ -z "${fn}" ]]; then
    return 1
  fi
  declare -F "${fn}" >/dev/null 2>&1
}

# Stub logging functions if missing (so sourcing repo files won't fail)
if ! declare -f info > /dev/null; then function info() { printf '[* INFO  ] %s\n' "$*"; }; fi
if ! declare -f warn > /dev/null; then function warn() { printf '[! WARN  ] %s\n' "$*" >&2; }; fi
if ! declare -f error > /dev/null; then function error() { printf '[- ERROR ] %s\n' "$*" >&2; }; fi
if ! declare -f pass > /dev/null; then function pass() { printf '[+ PASS  ] %s\n' "$*"; }; fi
if ! declare -f fail > /dev/null; then function fail() { printf '[- FAIL  ] %s\n' "$*" >&2; }; fi

# Repo root from the test file location (independent tests are 2 levels deep)
repo_root="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
export REPO_ROOT="${repo_root}"

# temp HOME helpers
function setup_temp_home() {
  export TEST_HOME="$(mktemp -d)"
  export HOME="${TEST_HOME}"
  mkdir -p "${HOME}/.config/bash/log" >/dev/null 2>&1 || true
}

function teardown_temp_home() {
  rm -rf "${TEST_HOME}"
}

# Write a complete mock common_core to ${HOME}/.config/bash/lib/common_core/
# providing every function install.sh's load_common_core preflight requires:
#   * logging: info / warn / error / fail / pass / debug
#   * cmd::exists
#   * file::copy            (with timestamped backup of pre-existing dest)
#   * file::restore_old_backup
#
# Call this from every per-file setup() instead of duplicating the same
# heredoc. Historical drift between inline copies of this mock caused 12
# bats failures in 60_files_differ_function.bats and 70_validation_errors.bats
# (per-file mocks omitted file::restore_old_backup, which install.sh's
# preflight requires).
function create_mock_common_core() {
  local cc_dir="${HOME}/.config/bash/lib/common_core"
  mkdir -p "${cc_dir}"

  cat > "${cc_dir}/util.sh" << 'MOCK_CC_EOF'
#!/usr/bin/env bash
info()  { printf '[* INFO  ] %s\n' "$*"; }
warn()  { printf '[! WARN  ] %s\n' "$*" >&2; }
error() { printf '[- ERROR ] %s\n' "$*" >&2; }
fail()  { printf '[- FAIL  ] %s\n' "$*" >&2; }
pass()  { printf '[+ PASS  ] %s\n' "$*"; }
debug() { printf '[. DEBUG ] %s\n' "$*"; }

cmd::exists() {
  command -v "$1" >/dev/null 2>&1
}

file::copy() {
  local src="$1"
  local dest="$2"

  # Timestamped backup of any pre-existing destination.
  if [[ -f "${dest}" ]]; then
    cp "${dest}" "${dest}.old.$(date +%Y%m%d_%H%M%S)"
  fi

  cp "${src}" "${dest}"
  pass "Copied: ${src} -> ${dest}"
}

file::restore_old_backup() {
  local target="$1"
  local backup

  # Most recent backup; lexicographic sort works because the suffix is
  # YYYYmmdd_HHMMSS.
  backup=$(find "$(dirname "${target}")" \
    -maxdepth 1 \
    -name "$(basename "${target}").old.*" \
    2>/dev/null | sort -r | head -n1)

  if [[ -n "${backup}" && -f "${backup}" ]]; then
    mv "${backup}" "${target}"
    pass "Restored: ${target} from backup"
    return 0
  fi

  warn "No backup found for: ${target}"
  return 1
}
MOCK_CC_EOF
}

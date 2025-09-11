# tests/helpers/common.bash
# Shared helpers for bats tests

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

# Repo root from the test file location
repo_root="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
export REPO_ROOT="${repo_root}"

# temp HOME helpers
setup_temp_home() {
  export TEST_HOME="$(mktemp -d)"
  export HOME="${TEST_HOME}"
  mkdir -p "${HOME}/.config/bash/log" >/dev/null 2>&1 || true
}

teardown_temp_home() {
  rm -rf "${TEST_HOME}"
}

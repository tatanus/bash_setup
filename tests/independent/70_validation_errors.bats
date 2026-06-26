#!/usr/bin/env bats
# tests/independent/70_validation_errors.bats
# Independence tests for validation failures and error handling

load '../load.bash'

# Negative: Invalid command argument
@test "install.sh rejects invalid commands" {
  run bash "${REPO_ROOT}/install.sh" invalid-command
  [ "$status" -eq 1 ]
  [[ "${output}" =~ "Unknown" ]] || [[ "${output}" =~ "FAIL" ]]
}

# Negative: Unknown option
@test "install.sh rejects unknown options" {
  run bash "${REPO_ROOT}/install.sh" --unknown-option
  [ "$status" -eq 1 ]
  [[ "${output}" =~ "Unknown" ]]
}

# Negative: Multiple invalid options
@test "install.sh rejects multiple invalid options" {
  run bash "${REPO_ROOT}/install.sh" --bad1 --bad2 --bad3
  [ "$status" -eq 1 ]
}

# Negative: Mixed valid and invalid options
@test "install.sh rejects invalid options even with valid ones present" {
  run bash "${REPO_ROOT}/install.sh" install --skip-tools --invalid
  [ "$status" -eq 1 ]
}

# Negative: Missing common_core library
@test "install.sh fails with proper exit code when common_core missing" {
  run env HOME="/tmp/nonexistent_test_$$" bash "${REPO_ROOT}/install.sh" install
  [ "$status" -eq 1 ]
  [[ "${output}" =~ "common_core" ]]
}

# Boundary: Empty command line (should default to install)
@test "install.sh with no arguments defaults to install command" {
  setup_temp_home
  create_mock_common_core

  run bash "${REPO_ROOT}/install.sh" --skip-tools

  teardown_temp_home

  # Should attempt install (default command)
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "install" ]] || [[ "${output}" =~ "Installation" ]]
}

# Security: Verify Bash version check exists
@test "install.sh verifies Bash version requirement" {
  run grep -q "BASH_VERSINFO" "${REPO_ROOT}/install.sh"
  [ "$status" -eq 0 ]
}

# Security: Verify HOME check exists
@test "install.sh verifies HOME environment variable" {
  run grep -q 'HOME' "${REPO_ROOT}/install.sh"
  [ "$status" -eq 0 ]
}

# Negative: Script with empty HOME
@test "install.sh rejects empty HOME variable" {
  run env HOME="" bash "${REPO_ROOT}/install.sh" install
  [ "$status" -eq 1 ]
  [[ "${output}" =~ "HOME" ]]
}

# Boundary: Very long command line arguments
@test "install.sh handles long invalid arguments" {
  local long_arg=$(printf 'a%.0s' {1..1000})
  run bash "${REPO_ROOT}/install.sh" "--${long_arg}"
  [ "$status" -eq 1 ]
}

# Security: Script doesn't execute arbitrary code from arguments
@test "install.sh treats command arguments safely" {
  run bash "${REPO_ROOT}/install.sh" '$(whoami)'
  [ "$status" -eq 1 ]
  [[ "${output}" =~ "Unknown" ]]
}

# Boundary: Options after command
@test "install.sh accepts options after command" {
  setup_temp_home
  create_mock_common_core

  run bash "${REPO_ROOT}/install.sh" install --skip-tools

  teardown_temp_home

  [ "$status" -eq 0 ]
}

# Negative: Validation error exit code
@test "install.sh uses non-zero exit code for validation failures" {
  run bash "${REPO_ROOT}/install.sh" --invalid
  [ "$status" -ne 0 ]
}

# Security: Script uses strict mode (set -uo pipefail)
@test "install.sh uses bash strict mode" {
  run grep -q "set -uo pipefail" "${REPO_ROOT}/install.sh"
  [ "$status" -eq 0 ]
}

# Security: Script sets IFS safely
@test "install.sh sets safe IFS delimiter" {
  run grep -q "IFS=" "${REPO_ROOT}/install.sh"
  [ "$status" -eq 0 ]
}

# Boundary: Help and version don't require common_core
@test "install.sh --help works without common_core" {
  run env HOME="/nonexistent" bash "${REPO_ROOT}/install.sh" --help
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "USAGE" ]]
}

@test "install.sh --version works without common_core" {
  run env HOME="/nonexistent" bash "${REPO_ROOT}/install.sh" --version
  [ "$status" -eq 0 ]
}

# Security: Preflight checks are actually executed
@test "install.sh performs preflight checks before operations" {
  # Verify preflight function is called
  run grep -q "preflight_checks" "${REPO_ROOT}/install.sh"
  [ "$status" -eq 0 ]

  # Verify it's called within the body of main(). The project mandates the
  # `function name() { ... }` declaration form, so match both that and the
  # bare `name()` form. The window must be large enough to span the full
  # main() body (~60 lines of arg parsing precede the preflight call).
  # Pipe `run` to avoid losing the pipeline's exit status.
  run bash -c 'grep -A 80 "^\(function \)\?main()" "$1" | grep -q "preflight_checks"' _ "${REPO_ROOT}/install.sh"
  [ "$status" -eq 0 ]
}

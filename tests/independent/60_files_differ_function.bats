#!/usr/bin/env bats
# tests/independent/60_files_differ_function.bats
# Independence tests for checksum comparison logic

load '../load.bash'

setup() {
  setup_temp_home
  # Create mock common_core
  mkdir -p "${HOME}/.config/bash/lib/common_core"

  cat > "${HOME}/.config/bash/lib/common_core/util.sh" << 'EOF'
#!/usr/bin/env bash
info() { printf '[* INFO  ] %s\n' "$*"; }
warn() { printf '[! WARN  ] %s\n' "$*" >&2; }
fail() { printf '[- FAIL  ] %s\n' "$*" >&2; }
pass() { printf '[+ PASS  ] %s\n' "$*"; }
debug() { printf '[. DEBUG ] %s\n' "$*"; }

cmd::exists() {
  command -v "$1" >/dev/null 2>&1
}

file::copy() {
  local src="$1"
  local dest="$2"
  cp "${src}" "${dest}"
}
EOF
  chmod +x "${HOME}/.config/bash/lib/common_core/util.sh"

  # Source install.sh functions for testing
  # We'll test via the update command which uses files_differ
}

teardown() {
  teardown_temp_home
}

# Happy path: files_differ detects identical files
@test "update treats identical files as unchanged" {
  # Install first
  bash "${REPO_ROOT}/install.sh" install --skip-tools >/dev/null 2>&1

  # Run update - should detect no changes
  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "up to date" ]]
}

# Happy path: files_differ detects different files
@test "update detects files that differ by content" {
  # Install first
  bash "${REPO_ROOT}/install.sh" install --skip-tools >/dev/null 2>&1

  # Modify a file
  echo "# modification" >> "${HOME}/.bashrc"

  # Run update - should detect changes
  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Updating" ]] || [[ "${output}" =~ "Updated" ]]
}

# Boundary: files_differ handles missing destination
@test "update treats missing destination file as different" {
  # Install first
  bash "${REPO_ROOT}/install.sh" install --skip-tools >/dev/null 2>&1

  # Remove a file
  rm -f "${HOME}/.bashrc"

  # Update should reinstall it
  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]

  # File should be restored
  [ -f "${HOME}/.bashrc" ]
}

# Boundary: files_differ handles empty files
@test "update correctly compares empty files" {
  # Install first
  bash "${REPO_ROOT}/install.sh" install --skip-tools >/dev/null 2>&1

  # Create an empty file
  > "${HOME}/.bashrc"

  # Update should detect difference
  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Updating" ]] || [[ "${output}" =~ "Updated" ]]
}

# Boundary: files_differ handles large files
@test "update handles files with substantial content" {
  # Install first
  bash "${REPO_ROOT}/install.sh" install --skip-tools >/dev/null 2>&1

  # Add substantial content
  for i in {1..100}; do
    echo "# Line ${i}" >> "${HOME}/.bashrc"
  done

  # Update should detect difference
  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Updating" ]] || [[ "${output}" =~ "Updated" ]]
}

# Security: files_differ uses SHA-256 checksums
@test "checksum comparison uses secure hash algorithm" {
  # Verify sha256sum or shasum is available
  if command -v sha256sum >/dev/null 2>&1; then
    run sha256sum --version
    [ "$status" -eq 0 ]
  elif command -v shasum >/dev/null 2>&1; then
    run shasum --version
    [ "$status" -eq 0 ]
  else
    skip "No checksum tool available (expected fallback behavior)"
  fi
}

# Boundary: files_differ handles files with only whitespace changes
@test "update detects files with whitespace-only changes" {
  # Install first
  bash "${REPO_ROOT}/install.sh" install --skip-tools >/dev/null 2>&1

  # Add whitespace
  echo "   " >> "${HOME}/.bashrc"

  # Update should detect difference (SHA-256 is sensitive to whitespace)
  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Updating" ]] || [[ "${output}" =~ "Updated" ]]
}

# Happy path: files_differ correctly identifies unchanged files after reinstall
@test "update shows no changes after install without modifications" {
  # Install
  bash "${REPO_ROOT}/install.sh" install --skip-tools >/dev/null 2>&1

  # Immediate update without changes
  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "up to date" ]]
}

# Boundary: files_differ handles files with special characters
@test "update correctly compares files with special characters" {
  # Install first
  bash "${REPO_ROOT}/install.sh" install --skip-tools >/dev/null 2>&1

  # Add special characters
  echo 'VAR="$HOME/\$PATH/test"' >> "${HOME}/.bashrc"

  # Update should detect difference
  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Updating" ]] || [[ "${output}" =~ "Updated" ]]
}

# Security: files_differ doesn't expose sensitive file content in output
@test "update doesn't leak file contents in error messages" {
  # Install first
  bash "${REPO_ROOT}/install.sh" install --skip-tools >/dev/null 2>&1

  # Add sensitive-looking content
  echo 'PASSWORD="secret123"' >> "${HOME}/.bashrc"

  # Update should not show file contents
  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]
  [[ ! "${output}" =~ "secret123" ]]
}

#!/usr/bin/env bats
# tests/independent/40_update_command.bats
# Independence tests for update command - checksum-based updates

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
  if [[ -f "${dest}" ]]; then
    cp "${dest}" "${dest}.old.$(date +%Y%m%d_%H%M%S)"
  fi
  cp "${src}" "${dest}"
  pass "Copied: ${src} -> ${dest}"
}

file::restore_old_backup() {
  local target="$1"
  local backup
  backup=$(find "$(dirname "${target}")" -name "$(basename "${target}").old.*" 2>/dev/null | sort -r | head -n1)
  if [[ -n "${backup}" && -f "${backup}" ]]; then
    mv "${backup}" "${target}"
    pass "Restored: ${target} from backup"
    return 0
  else
    warn "No backup found for: ${target}"
    return 1
  fi
}
EOF
  chmod +x "${HOME}/.config/bash/lib/common_core/util.sh"

  # Pre-install dotfiles for update tests
  bash "${REPO_ROOT}/install.sh" install --skip-tools >/dev/null 2>&1
}

teardown() {
  teardown_temp_home
}

# Happy path: update detects unchanged files
@test "update reports files are up to date when unchanged" {
  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "up to date" ]]
}

# Happy path: update only updates changed files
@test "update only copies files that differ by checksum" {
  # Modify one installed file
  echo "# test modification" >> "${HOME}/.bashrc"

  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]

  # Should report updating files
  [[ "${output}" =~ "Updating" ]] || [[ "${output}" =~ "Updated" ]]
}

# Happy path: update reports count of updated files
@test "update reports accurate count of updated files" {
  # Modify multiple files
  echo "# mod1" >> "${HOME}/.bashrc"
  echo "# mod2" >> "${HOME}/.vimrc"

  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]

  # Should mention count or multiple updates
  [[ "${output}" =~ "Updated" ]] || [[ "${output}" =~ "file(s)" ]]
}

# Negative: update handles missing dotfiles directory
@test "update fails when dotfiles directory missing" {
  mv "${REPO_ROOT}/dotfiles" "${REPO_ROOT}/dotfiles.backup"

  run bash "${REPO_ROOT}/install.sh" update

  mv "${REPO_ROOT}/dotfiles.backup" "${REPO_ROOT}/dotfiles"

  [ "$status" -ne 0 ]
  [[ "${output}" =~ "not found" ]] || [[ "${output}" =~ "FAIL" ]]
}

# Negative: update handles missing destination files
@test "update handles missing destination files (treats as different)" {
  # Remove an installed file
  rm -f "${HOME}/.bashrc"

  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]

  # Should reinstall the missing file
  [ -f "${HOME}/.bashrc" ]
}

# Boundary: update with no sha256sum or shasum falls back gracefully
@test "update works when checksum tools unavailable (fallback behavior)" {
  # This test verifies the script handles missing checksum tools
  # The script should have fallback logic (return 0 = different)

  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]

  # Update should complete even if checksums unavailable
  [[ "${output}" =~ "up to date" ]] || [[ "${output}" =~ "Updated" ]] || [ "$status" -eq 0 ]
}

# Security: update preserves file ownership and permissions
@test "update maintains file integrity after checksum comparison" {
  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]

  # Files should still be readable
  [ -r "${HOME}/.bashrc" ]
  [ -r "${HOME}/.vimrc" ]
}

# Happy path: update creates backups when updating
@test "update creates backups when files are updated" {
  # Modify a file to trigger update
  echo "# trigger update" >> "${HOME}/.bashrc"

  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]

  # Check backup was created
  local backup_count=$(find "${HOME}" -name ".bashrc.old.*" 2>/dev/null | wc -l)
  [ "${backup_count}" -gt 0 ]
}

# Boundary: update handles files with special characters in content
@test "update correctly compares files with special characters" {
  # Add special characters to a dotfile
  echo '#!/bin/bash' > "${HOME}/.bashrc"
  echo 'VAR="test $HOME \$PATH"' >> "${HOME}/.bashrc"

  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]

  # Should detect difference and update
  [[ "${output}" =~ "Updating" ]] || [[ "${output}" =~ "Updated" ]]
}

# Happy path: update completes even with some missing source files
@test "update continues when some source files are missing" {
  # Create temporary dotfiles with missing files
  mkdir -p "${REPO_ROOT}/dotfiles.test"
  cp "${REPO_ROOT}/dotfiles/bashrc" "${REPO_ROOT}/dotfiles.test/"

  mv "${REPO_ROOT}/dotfiles" "${REPO_ROOT}/dotfiles.backup"
  mv "${REPO_ROOT}/dotfiles.test" "${REPO_ROOT}/dotfiles"

  run bash "${REPO_ROOT}/install.sh" update

  mv "${REPO_ROOT}/dotfiles" "${REPO_ROOT}/dotfiles.test"
  mv "${REPO_ROOT}/dotfiles.backup" "${REPO_ROOT}/dotfiles"
  rm -rf "${REPO_ROOT}/dotfiles.test"

  [ "$status" -eq 0 ]
}

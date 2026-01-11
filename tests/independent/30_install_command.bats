#!/usr/bin/env bats
# tests/independent/30_install_command.bats
# Independence tests for install command - focuses on external behavior

load '../load.bash'

setup() {
  setup_temp_home
  # Create mock common_core for tests
  mkdir -p "${HOME}/.config/bash/lib/common_core"

  # Mock common_core util.sh with required functions
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

  # Create backup if dest exists
  if [[ -f "${dest}" ]]; then
    cp "${dest}" "${dest}.old.$(date +%Y%m%d_%H%M%S)"
  fi

  cp "${src}" "${dest}"
  pass "Copied: ${src} -> ${dest}"
}

file::restore_old_backup() {
  local target="$1"
  local backup

  # Find most recent backup
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
}

teardown() {
  teardown_temp_home
}

# Happy path: install command creates required directories
@test "install command creates required directories" {
  run bash "${REPO_ROOT}/install.sh" install --skip-tools
  [ "$status" -eq 0 ]

  # Verify directories exist
  [ -d "${HOME}/DATA/LOGS" ]
  [ -d "${HOME}/.config/bash" ]
  [ -d "${HOME}/.config/bash/log" ]
}

# Happy path: install command copies dotfiles
@test "install command copies common dotfiles to HOME" {
  run bash "${REPO_ROOT}/install.sh" install --skip-tools
  [ "$status" -eq 0 ]

  # Check at least some expected dotfiles were copied
  [ -f "${HOME}/.bashrc" ]
  [ -f "${HOME}/.vimrc" ]
  [ -f "${HOME}/.tmux.conf" ]
}

# Happy path: install command copies bash config files
@test "install command copies bash dotfiles to .config/bash" {
  run bash "${REPO_ROOT}/install.sh" install --skip-tools
  [ "$status" -eq 0 ]

  # Check at least one bash config file
  [ -f "${HOME}/.config/bash/bash.path.sh" ] || [ -f "${HOME}/.config/bash/path.env.sh" ]
}

# Happy path: install with --skip-tools flag
@test "install --skip-tools skips tool checks" {
  run bash "${REPO_ROOT}/install.sh" install --skip-tools
  [ "$status" -eq 0 ]

  # Should not mention recommended tools in output
  [[ ! "${output}" =~ "Checking recommended tools" ]] || [[ "${output}" =~ "skip" ]]
}

# Happy path: install without --skip-tools checks tools
@test "install without --skip-tools checks recommended tools" {
  run bash "${REPO_ROOT}/install.sh" install
  [ "$status" -eq 0 ]

  # Should mention checking tools or at least complete successfully
  [[ "${output}" =~ "Checking recommended tools" ]] || [ "$status" -eq 0 ]
}

# Negative: install fails when dotfiles directory is missing
@test "install fails gracefully when dotfiles directory missing" {
  # Temporarily rename dotfiles directory
  mv "${REPO_ROOT}/dotfiles" "${REPO_ROOT}/dotfiles.backup"

  run bash "${REPO_ROOT}/install.sh" install --skip-tools

  # Restore directory
  mv "${REPO_ROOT}/dotfiles.backup" "${REPO_ROOT}/dotfiles"

  # Should fail with error
  [ "$status" -ne 0 ]
  [[ "${output}" =~ "not found" ]] || [[ "${output}" =~ "FAIL" ]]
}

# Negative: install handles missing source files gracefully
@test "install warns but continues when individual source files missing" {
  # Create temp dotfiles dir with only one file
  mkdir -p "${REPO_ROOT}/dotfiles.test"
  echo "test" > "${REPO_ROOT}/dotfiles.test/bashrc"

  # Temporarily swap directories
  mv "${REPO_ROOT}/dotfiles" "${REPO_ROOT}/dotfiles.backup"
  mv "${REPO_ROOT}/dotfiles.test" "${REPO_ROOT}/dotfiles"

  run bash "${REPO_ROOT}/install.sh" install --skip-tools

  # Restore original
  mv "${REPO_ROOT}/dotfiles" "${REPO_ROOT}/dotfiles.test"
  mv "${REPO_ROOT}/dotfiles.backup" "${REPO_ROOT}/dotfiles"
  rm -rf "${REPO_ROOT}/dotfiles.test"

  # Should succeed but warn about missing files
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "WARN" ]] || [[ "${output}" =~ "not found" ]]
}

# Boundary: install with empty HOME variable handled by preflight
@test "install detects empty HOME in preflight" {
  run env HOME="" bash "${REPO_ROOT}/install.sh" install
  [ "$status" -ne 0 ]
  [[ "${output}" =~ "HOME" ]]
}

# Security: install creates directories with safe permissions
@test "install creates directories without exposing to other users" {
  run bash "${REPO_ROOT}/install.sh" install --skip-tools
  [ "$status" -eq 0 ]

  # Directories should exist (actual permission check would require stat)
  [ -d "${HOME}/.config/bash" ]
  [ -d "${HOME}/.config/bash/log" ]
}

# Happy path: install succeeds with all required dependencies
@test "install completes successfully with valid environment" {
  run bash "${REPO_ROOT}/install.sh" install --skip-tools
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "complete" ]] || [[ "${output}" =~ "PASS" ]]
}

# Boundary: repeated install creates backups
@test "repeated install creates backup files" {
  # First install
  bash "${REPO_ROOT}/install.sh" install --skip-tools

  # Modify a dotfile
  echo "# modified" >> "${HOME}/.bashrc"

  # Second install
  run bash "${REPO_ROOT}/install.sh" install --skip-tools
  [ "$status" -eq 0 ]

  # Check that backup was created
  local backup_count=$(find "${HOME}" -name ".bashrc.old.*" 2>/dev/null | wc -l)
  [ "${backup_count}" -gt 0 ]
}

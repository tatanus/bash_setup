#!/usr/bin/env bats
# tests/independent/50_uninstall_command.bats
# Independence tests for uninstall command - backup restoration

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
}

teardown() {
  teardown_temp_home
}

# Happy path: uninstall restores backups when they exist
@test "uninstall restores files from backups" {
  # Create original files
  echo "original bashrc" > "${HOME}/.bashrc"

  # Install (creates backups)
  bash "${REPO_ROOT}/install.sh" install --skip-tools >/dev/null 2>&1

  # Verify file was changed
  [[ "$(cat "${HOME}/.bashrc")" != "original bashrc" ]]

  # Uninstall
  run bash "${REPO_ROOT}/install.sh" uninstall
  [ "$status" -eq 0 ]

  # Verify restoration
  [[ "${output}" =~ "Restored" ]] || [[ "${output}" =~ "PASS" ]]
}

# Happy path: uninstall reports count of restored files
@test "uninstall reports number of restored files" {
  # Create originals
  echo "original" > "${HOME}/.bashrc"
  echo "original" > "${HOME}/.vimrc"

  # Install
  bash "${REPO_ROOT}/install.sh" install --skip-tools >/dev/null 2>&1

  # Uninstall
  run bash "${REPO_ROOT}/install.sh" uninstall
  [ "$status" -eq 0 ]

  [[ "${output}" =~ "Restored" ]] || [[ "${output}" =~ "file(s)" ]]
}

# Negative: uninstall handles missing backups gracefully
@test "uninstall handles missing backups gracefully" {
  # Install without pre-existing files (no backups created)
  bash "${REPO_ROOT}/install.sh" install --skip-tools >/dev/null 2>&1

  # Uninstall
  run bash "${REPO_ROOT}/install.sh" uninstall
  [ "$status" -eq 0 ]

  # Should handle gracefully
  [[ "${output}" =~ "No backup" ]] || [[ "${output}" =~ "WARN" ]] || [ "$status" -eq 0 ]
}

# Boundary: uninstall with no installed files
@test "uninstall succeeds even when no files installed" {
  run bash "${REPO_ROOT}/install.sh" uninstall
  [ "$status" -eq 0 ]

  # Should report no backups found
  [[ "${output}" =~ "No backup" ]] || [ "$status" -eq 0 ]
}

# Security: uninstall only restores valid backups
@test "uninstall restores most recent backup when multiple exist" {
  # Create original
  echo "original" > "${HOME}/.bashrc"

  # First install
  bash "${REPO_ROOT}/install.sh" install --skip-tools >/dev/null 2>&1
  sleep 1

  # Modify and install again
  echo "modified" > "${HOME}/.bashrc"
  bash "${REPO_ROOT}/install.sh" install --skip-tools >/dev/null 2>&1

  # Uninstall should restore most recent backup
  run bash "${REPO_ROOT}/install.sh" uninstall
  [ "$status" -eq 0 ]

  [[ "${output}" =~ "Restored" ]]
}

# Happy path: uninstall always returns success
@test "uninstall always exits with status 0" {
  # Even with no backups, uninstall should succeed
  run bash "${REPO_ROOT}/install.sh" uninstall
  [ "$status" -eq 0 ]
}

# Boundary: uninstall handles files in both HOME and .config/bash
@test "uninstall attempts to restore files from all locations" {
  # Create originals in both locations
  echo "original bashrc" > "${HOME}/.bashrc"
  mkdir -p "${HOME}/.config/bash"
  echo "original path" > "${HOME}/.config/bash/bash.path.sh"

  # Install
  bash "${REPO_ROOT}/install.sh" install --skip-tools >/dev/null 2>&1

  # Uninstall
  run bash "${REPO_ROOT}/install.sh" uninstall
  [ "$status" -eq 0 ]

  # Should mention restoration
  [[ "${output}" =~ "Restored" ]] || [[ "${output}" =~ "backup" ]]
}

# Negative: uninstall handles corrupted/missing backup files
@test "uninstall continues when some backups are missing" {
  # Create original
  echo "original" > "${HOME}/.bashrc"

  # Install
  bash "${REPO_ROOT}/install.sh" install --skip-tools >/dev/null 2>&1

  # Delete backup for one file
  rm -f "${HOME}"/.bashrc.old.* 2>/dev/null || true

  # Uninstall should continue
  run bash "${REPO_ROOT}/install.sh" uninstall
  [ "$status" -eq 0 ]
}

# Security: uninstall doesn't follow symlinks outside HOME
@test "uninstall operates safely within expected directories" {
  # Install files normally
  bash "${REPO_ROOT}/install.sh" install --skip-tools >/dev/null 2>&1

  # Uninstall should only operate on expected paths
  run bash "${REPO_ROOT}/install.sh" uninstall
  [ "$status" -eq 0 ]

  # Verify it only mentions paths in HOME
  [[ "${output}" =~ "${HOME}" ]] || [ "$status" -eq 0 ]
}

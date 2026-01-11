#!/usr/bin/env bats
load './load.bash'

@test "install.sh detects missing common_core" {
  # Run with a fake HOME that doesn't have common_core installed
  run env HOME="/tmp/nonexistent_$$" bash "${REPO_ROOT}/install.sh" install
  [ "$status" -ne 0 ]
  [[ "${output}" =~ "common_core" ]]
}

@test "install.sh requires bash 4+" {
  # This test verifies the check exists in the script
  run grep -q "BASH_VERSINFO" "${REPO_ROOT}/install.sh"
  [ "$status" -eq 0 ]
}

@test "dotfiles directory contains expected files" {
  [ -f "${REPO_ROOT}/dotfiles/bashrc" ]
  [ -f "${REPO_ROOT}/dotfiles/vimrc" ]
  [ -f "${REPO_ROOT}/dotfiles/tmux.conf" ]
}

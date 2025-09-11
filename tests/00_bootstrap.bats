#!/usr/bin/env bats
load './load.bash'

@test "repo root exists" {
  [ -d "${REPO_ROOT}" ]
}

@test "dotfiles directory exists and is not empty" {
  [ -d "${REPO_ROOT}/dotfiles" ]
  [ -n "$(ls -A "${REPO_ROOT}/dotfiles")" ]
}

@test "config files exist" {
  [ -f "${REPO_ROOT}/config/config.sh" ]
  [ -f "${REPO_ROOT}/config/lists.sh" ]
}

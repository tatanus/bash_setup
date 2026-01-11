#!/usr/bin/env bats
load './load.bash'

@test "repo root exists" {
  [ -d "${REPO_ROOT}" ]
}

@test "dotfiles directory exists and is not empty" {
  [ -d "${REPO_ROOT}/dotfiles" ]
  [ -n "$(ls -A "${REPO_ROOT}/dotfiles")" ]
}

@test "install.sh exists and is executable" {
  [ -f "${REPO_ROOT}/install.sh" ]
  [ -x "${REPO_ROOT}/install.sh" ]
}

@test "VERSION file exists" {
  [ -f "${REPO_ROOT}/VERSION" ]
}

@test "tools directory exists" {
  [ -d "${REPO_ROOT}/tools" ]
}

#!/usr/bin/env bats
load './load.bash'

@test "install.sh --help shows usage" {
  run bash "${REPO_ROOT}/install.sh" --help
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "USAGE" ]]
  [[ "${output}" =~ "install" ]]
  [[ "${output}" =~ "update" ]]
  [[ "${output}" =~ "uninstall" ]]
}

@test "install.sh --version shows version from VERSION file" {
  run bash "${REPO_ROOT}/install.sh" --version
  [ "$status" -eq 0 ]
  version=$(cat "${REPO_ROOT}/VERSION")
  [[ "${output}" =~ "${version}" ]]
}

@test "install.sh rejects unknown options" {
  run bash "${REPO_ROOT}/install.sh" --invalid-option
  [ "$status" -ne 0 ]
}

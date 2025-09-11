#!/usr/bin/env bats
load './load.bash'

@test "config scripts source without error" {
  run bash -c 'source "${REPO_ROOT}/tests/helpers/common.bash"; export SCRIPT_DIR="${REPO_ROOT}"; source "${REPO_ROOT}/config/config.sh"; source "${REPO_ROOT}/config/lists.sh"'
  [ "$status" -eq 0 ]
}

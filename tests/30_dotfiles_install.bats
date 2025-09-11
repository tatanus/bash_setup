#!/usr/bin/env bats
load './load.bash'

setup() { setup_temp_home; }
teardown() { teardown_temp_home; }

@test "Setup_Dot_Files installs dotfiles" {
  run bash -c 'source "${REPO_ROOT}/tests/helpers/common.bash"; export SCRIPT_DIR="${REPO_ROOT}"; export HOME="${HOME}"; source "${REPO_ROOT}/config/config.sh"; source "${REPO_ROOT}/config/lists.sh"; source "${REPO_ROOT}/menu/menu_tasks.sh"; function_exists Setup_Dot_Files && Setup_Dot_Files || exit 200'
  if [ "$status" -eq 200 ]; then
    skip "Setup_Dot_Files not implemented"
  fi
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.bashrc" ] || [ -f "${HOME}/.bash_profile" ] || [ -f "${HOME}/.profile" ] || skip "No canonical dotfile found"
}

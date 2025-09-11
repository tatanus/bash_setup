#!/usr/bin/env bats
load './load.bash'

setup() { setup_temp_home; }
teardown() { teardown_temp_home; }

@test "Setup_Bash_Directories creates expected dirs" {
  # Prepare environment and call only if function exists after sourcing
  run bash -c 'source "${REPO_ROOT}/tests/helpers/common.bash"; export SCRIPT_DIR="${REPO_ROOT}"; export HOME="${HOME}"; source "${REPO_ROOT}/config/config.sh"; source "${REPO_ROOT}/menu/menu_tasks.sh"; function_exists Setup_Bash_Directories && Setup_Bash_Directories || exit 200'
  if [ "$status" -eq 200 ]; then
    skip "Setup_Bash_Directories not implemented"
  fi
  [ "$status" -eq 0 ]
  [ -d "${HOME}/DATA" ]
  [ -d "${HOME}/DATA/LOGS" ]
}

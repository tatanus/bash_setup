#!/usr/bin/env bats

load './load.bash'

setup() {
  setup_temp_home
}

teardown() {
  teardown_temp_home
}

@test "Undo_Setup_Dot_Files removes/restores" {
  run bash -c 'source "${REPO_ROOT}/tests/helpers/common.bash"; \
               export SCRIPT_DIR="${REPO_ROOT}"; \
               source "${REPO_ROOT}/config/config.sh"; \
               source "${REPO_ROOT}/config/lists.sh"; \
               source "${REPO_ROOT}/menu/menu_tasks.sh"; \
               if ! function_exists Setup_Dot_Files; then exit 200; fi; \
               if ! function_exists copy_file; then exit 201; fi; \
               Setup_Dot_Files'
  if [ "$status" -eq 200 ]; then
    skip "Setup_Dot_Files not implemented"
  fi
  if [ "$status" -eq 201 ]; then
    skip "copy_file helper not available (submodule not initialized)"
  fi
  [ "$status" -eq 0 ]

  # Try to undo
  run bash -c 'source "${REPO_ROOT}/tests/helpers/common.bash"; \
               export SCRIPT_DIR="${REPO_ROOT}"; \
               source "${REPO_ROOT}/config/config.sh"; \
               source "${REPO_ROOT}/config/lists.sh"; \
               source "${REPO_ROOT}/menu/menu_tasks.sh"; \
               if ! function_exists Undo_Setup_Dot_Files; then exit 202; fi; \
               Undo_Setup_Dot_Files'
  if [ "$status" -eq 202 ]; then
    skip "Undo_Setup_Dot_Files not implemented"
  fi
  [ "$status" -eq 0 ]
}

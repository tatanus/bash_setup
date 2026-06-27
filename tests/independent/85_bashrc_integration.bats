#!/usr/bin/env bats
# tests/independent/85_bashrc_integration.bats
# Verify the deployed bashrc actually sources what its secondary_bash_files
# array claims to. This catches the same drift class that Pass 1 fixed
# (files deployed but never sourced, or referenced but not deployed).
#
# All tests source bashrc with PS1 set so the non-interactive guard at
# the top of bashrc does not bail out early.

load '../load.bash'

setup() {
  setup_temp_home
  create_mock_common_core
  bash "${REPO_ROOT}/install.sh" install --skip-tools > /dev/null 2>&1
  [ -f "${HOME}/.bashrc" ]
}

teardown() {
  teardown_temp_home
}

# Helper: source the deployed bashrc with PS1 set so the non-interactive
# guard inside bashrc does not bail out, and scrub any inherited dotfile
# source-guards / ENGAGEMENT_DIR from the parent env so each test sees a
# clean load. The host shell where this test runs may have these set
# from a previous pentest_setup session; without the unset, the source
# guards short-circuit and the functions never get defined.
source_bashrc_then() {
  HOME="${HOME}" bash -c "
    unset PS1 \
      BASH_FUNCS_SH_LOADED BASH_PROMPT_FUNCS_SH_LOADED \
      BASH_PROMPT_SH_LOADED BASH_ALIAS_SH_LOADED \
      BASH_VISUALS_SH_LOADED BASH_ENV_SH_LOADED \
      BASH_PATH_SH_LOADED PATH_ENV_LOADED \
      TGT_ALIAS_SH_LOADED SCREEN_ALIAS_AH_LOADED \
      TMUX_ALIAS_SH_LOADED SSH_ALIASES_SH_LOADED \
      CAPTURETRAFFIC_SH_LOADED COMMAND_LOGGING_SH_LOADED \
      bash_preexec_imported __bp_imported \
      ENGAGEMENT_DIR TGT_DIR
    PS1='\$ '
    source \"\${HOME}/.bashrc\" 2>/dev/null
    $1
  "
}

@test "integration: sourcing deployed bashrc sets all three new guards" {
  run source_bashrc_then '
    echo "BASH_FUNCS_SH_LOADED=${BASH_FUNCS_SH_LOADED:-unset}"
    echo "BASH_PROMPT_FUNCS_SH_LOADED=${BASH_PROMPT_FUNCS_SH_LOADED:-unset}"
    echo "bash_preexec_imported=${bash_preexec_imported:-unset}"
  '
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "BASH_FUNCS_SH_LOADED=true" ]]
  [[ "${output}" =~ "BASH_PROMPT_FUNCS_SH_LOADED=true" ]]
  [[ "${output}" =~ "bash_preexec_imported=defined" ]]
}

@test "integration: check_command (from bash.funcs.sh) is defined" {
  run source_bashrc_then 'declare -F check_command >/dev/null && echo ok'
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "ok" ]]
}

@test "integration: precmd_functions / preexec_functions arrays declared by bash-preexec" {
  run source_bashrc_then 'declare -p precmd_functions preexec_functions 2>/dev/null'
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "declare -a precmd_functions" ]]
  [[ "${output}" =~ "declare -a preexec_functions" ]]
}

# Removed: "renewTGT (from tgt.aliases.sh) is defined". tgt.aliases.sh
# moved to pentest_setup ownership; bash_setup no longer ships or sources
# it. The equivalent assertion belongs in pentest_setup's test suite.

@test "integration: every file referenced in secondary_bash_files is present on disk" {
  # Extract the list of "${BASH_DIR}/x" entries from the deployed bashrc and
  # confirm each resolves to a real file under ${HOME}/.config/bash/. The
  # pentest.sh hook is intentionally optional (deployed by pentest_setup
  # downstream, not by bash_setup) so skip it.
  local f
  for f in $(grep -oE '\${BASH_DIR}/[a-zA-Z._-]+' "${HOME}/.bashrc" \
             | sed 's|${BASH_DIR}|.|g' | sort -u); do
    [[ "${f}" == "./pentest.sh" ]] && continue
    [ -f "${HOME}/.config/bash/${f#./}" ]
  done
}

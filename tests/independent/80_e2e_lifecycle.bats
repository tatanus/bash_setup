#!/usr/bin/env bats
# tests/independent/80_e2e_lifecycle.bats
# End-to-end behavioral tests for the install -> update -> uninstall
# lifecycle. Each test drives the real install.sh in a sandbox HOME with
# the shared mock common_core (see create_mock_common_core in
# tests/independent/helpers/common.bash).

load '../load.bash'

setup() {
  setup_temp_home
  create_mock_common_core
}

teardown() {
  teardown_temp_home
}

@test "lifecycle: install then update with no changes reports up to date" {
  run bash "${REPO_ROOT}/install.sh" install --skip-tools
  [ "$status" -eq 0 ]

  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "up to date" ]] || [[ "${output}" =~ "No files" ]] \
    || [[ "${output}" =~ "0 file" ]] || [[ "${output}" =~ "unchanged" ]]
}

@test "lifecycle: install -> mutate -> update copies the changed source back" {
  bash "${REPO_ROOT}/install.sh" install --skip-tools > /dev/null 2>&1
  [ -f "${HOME}/.bashrc" ]

  # Mutate the deployed file and confirm it differs from the source.
  echo "# user-modification-${RANDOM}" >> "${HOME}/.bashrc"
  ! cmp -s "${HOME}/.bashrc" "${REPO_ROOT}/dotfiles/bashrc"

  # update should detect the drift and bring the deployed file back in line.
  run bash "${REPO_ROOT}/install.sh" update
  [ "$status" -eq 0 ]
  cmp -s "${HOME}/.bashrc" "${REPO_ROOT}/dotfiles/bashrc"
}

@test "lifecycle: install -> mutate -> uninstall restores the user's original" {
  # Place a user-owned bashrc before install so install will back it up.
  echo "# user-original-content" > "${HOME}/.bashrc"
  local before_install
  before_install=$(cat "${HOME}/.bashrc")

  bash "${REPO_ROOT}/install.sh" install --skip-tools > /dev/null 2>&1
  # install should have copied the repo bashrc over the top.
  ! cmp -s "${HOME}/.bashrc" <(echo "${before_install}")

  # uninstall restores from the timestamped backup that install created.
  run bash "${REPO_ROOT}/install.sh" uninstall
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.bashrc" ]
  diff <(cat "${HOME}/.bashrc") <(echo "${before_install}")
}

@test "lifecycle: install creates the documented directory layout" {
  bash "${REPO_ROOT}/install.sh" install --skip-tools > /dev/null 2>&1
  [ -d "${HOME}/DATA/LOGS" ]
  [ -d "${HOME}/.config/bash" ]
  [ -d "${HOME}/.config/bash/log" ]
}

@test "lifecycle: install deploys both common and BASH_DIR dotfiles" {
  bash "${REPO_ROOT}/install.sh" install --skip-tools > /dev/null 2>&1

  # COMMON_DOT_FILES go to ${HOME} with a leading dot.
  for f in bashrc profile bash_profile inputrc vimrc; do
    [ -f "${HOME}/.${f}" ]
  done

  # BASH_DOT_FILES go to ${HOME}/.config/bash/ verbatim.
  for f in bash.path.sh bash.env.sh path.env.sh bash.funcs.sh \
           bash.aliases.sh bash.prompt.sh bash.prompt_funcs.sh \
           bash-preexec.sh bash.visuals.sh combined.history.sh \
           tgt.aliases.sh capture_traffic.sh; do
    [ -f "${HOME}/.config/bash/${f}" ]
  done
}

@test "lifecycle: repeated install creates timestamped backups, not duplicates" {
  bash "${REPO_ROOT}/install.sh" install --skip-tools > /dev/null 2>&1

  # Mutate so the second install sees a different on-disk file and backs it up.
  echo "# second-install-marker" >> "${HOME}/.bashrc"

  # Sleep at least 1 s so the timestamp suffix changes between cycles.
  sleep 1
  bash "${REPO_ROOT}/install.sh" install --skip-tools > /dev/null 2>&1

  # At least one .old. backup should exist for bashrc.
  local backups
  backups=$(find "${HOME}" -maxdepth 1 -name ".bashrc.old.*" | wc -l)
  [ "${backups}" -ge 1 ]
}

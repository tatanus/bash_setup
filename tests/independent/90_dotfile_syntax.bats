#!/usr/bin/env bats
# tests/independent/90_dotfile_syntax.bats
# Trivial-but-valuable: every shipped .sh dotfile must parse cleanly with
# `bash -n`. Catches any change that breaks parse without exercising the
# semantics. Pairs well with shellcheck (which catches style/correctness)
# and the lifecycle tests (which catch behavioral regressions).

load '../load.bash'

@test "syntax: all dotfiles/*.sh parse with bash -n" {
  local f
  local -a broken=()
  for f in "${REPO_ROOT}/dotfiles"/*.sh; do
    if ! bash -n "${f}" 2>&1; then
      broken+=("${f}")
    fi
  done

  if [[ "${#broken[@]}" -gt 0 ]]; then
    printf '  Broken files (%d):\n' "${#broken[@]}" >&3
    printf '    - %s\n' "${broken[@]}" >&3
    return 1
  fi
}

@test "syntax: bashrc (no .sh extension) parses with bash -n" {
  bash -n "${REPO_ROOT}/dotfiles/bashrc"
}

@test "syntax: profile and bash_profile parse with bash -n" {
  bash -n "${REPO_ROOT}/dotfiles/profile"
  bash -n "${REPO_ROOT}/dotfiles/bash_profile"
}

@test "syntax: install.sh parses with bash -n" {
  bash -n "${REPO_ROOT}/install.sh"
}

@test "guard: every dotfiles/*.sh has a duplicate-source guard" {
  # We rely on each helper's `if [[ -z "${X_LOADED:-}" ]]; then ... fi`
  # idiom to make explicit sourcing (Pass 2 work) idempotent with the
  # legacy implicit sourcing inside bash.aliases.sh / bash.prompt.sh.
  # bash-preexec.sh uses its own `bash_preexec_imported` guard.
  local f base
  local -a unguarded=()
  for f in "${REPO_ROOT}/dotfiles"/*.sh; do
    base=$(basename "${f}")
    if ! grep -qE "_LOADED:-|bash_preexec_imported" "${f}"; then
      unguarded+=("${base}")
    fi
  done

  if [[ "${#unguarded[@]}" -gt 0 ]]; then
    printf '  Unguarded files (%d):\n' "${#unguarded[@]}" >&3
    printf '    - %s\n' "${unguarded[@]}" >&3
    return 1
  fi
}

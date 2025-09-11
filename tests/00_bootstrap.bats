#!/usr/bin/env bats

@test "dotfiles directory exists" {
  [ -d "dotfiles" ]
}

@test "common_core submodule directory exists" {
  [ -d "lib/common_core" ]
}

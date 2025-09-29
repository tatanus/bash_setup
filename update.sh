#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

echo "[*] Pulling latest changes from main repo..."
git pull --recurse-submodules

echo "[*] Updating submodules to latest..."
git submodule update --init --remote --merge --recursive

echo "[+] Repo and submodules are now up to date."

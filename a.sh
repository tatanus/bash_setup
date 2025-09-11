#!/usr/bin/env bash
###############################################################################
# NAME         : update_readme_submodules.sh
# DESCRIPTION  : Scans git submodules and updates README.md with a single,
#                replaceable section listing them as clickable links.
# USAGE        : ./update_readme_submodules.sh
# NOTES        : Replaces content strictly between START/END markers.
###############################################################################

set -euo pipefail
IFS=$'\n\t'

README="README.md"
MARK_START="<!-- SUBMODULES-LIST:START -->"
MARK_END="<!-- SUBMODULES-LIST:END -->"

#--- helper: normalize repo URL for display (SSH -> HTTPS for GitHub/SSH URLs) ---
normalize_url() {
  local url="${1:-}"
  # git@github.com:user/repo.git  -> https://github.com/user/repo.git
  if [[ "$url" =~ ^git@([^:]+):(.+)$ ]]; then
    echo "https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    return
  fi
  # ssh://git@host/user/repo.git -> https://host/user/repo.git
  if [[ "$url" =~ ^ssh://git@([^/]+)/(.+)$ ]]; then
    echo "https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    return
  fi
  # Already https/http or something else: leave as-is
  echo "$url"
}

#--- gather submodules (path + url) ---
if [[ ! -f .gitmodules ]]; then
  echo "[-] No .gitmodules found. Nothing to update."
  exit 0
fi

# Extract paths
mapfile -t paths < <(git config --file .gitmodules --get-regexp 'submodule\..*\.path' | awk '{print $2}' | sort -u)

if (( ${#paths[@]} == 0 )); then
  echo "[-] No submodules configured in .gitmodules."
  list_content="* _No submodules configured_\n"
else
  list_content=""
  for path in "${paths[@]}"; do
    # The ".gitmodules" keys are named like submodule.<name>.<key>. Use the path to read its url.
    url="$(git config --file .gitmodules --get "submodule.${path}.url" || true)"
    url="$(normalize_url "${url}")"
    list_content+="* [${path}](${url})\n"
  done
fi

#--- ensure README exists ---
if [[ ! -f "$README" ]]; then
  echo "[*] $README not found. Creating it."
  printf "# Project\n\n" > "$README"
fi

#--- build replacement block ---
block=$(
  printf "## Submodules\n%s\n" "$MARK_START"
  printf "\n"
  printf "%b" "$list_content"
  printf "\n%s\n" "$MARK_END"
)

#--- replace block between markers (or append if markers not present) ---
if grep -qF "$MARK_START" "$README"; then
  # Replace everything between START and END (inclusive) with new block
  awk -v start="$MARK_START" -v end="$MARK_END" -v new="$block" '
    BEGIN { in_block=0 }
    {
      if ($0 ~ start) {
        print new
        in_block=1
        next
      }
      if ($0 ~ end) {
        in_block=0
        next
      }
      if (in_block==0) print $0
    }
  ' "$README" > "${README}.tmp" && mv "${README}.tmp" "$README"
else
  # Append a fresh section at the end
  {
    printf "\n%s\n" "$block"
  } >> "$README"
fi

echo "[+] README.md updated: submodule list replaced."

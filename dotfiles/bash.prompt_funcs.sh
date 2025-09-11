#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : bash.prompt_funcs.sh
# DESCRIPTION :
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-08 19:57:22
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-08 19:57:22  | Adam Compton | Initial creation.
# 2025-04-24           | Adam Compton | Unified all function comment blocks.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${BASH_PROMPT_FUNCS_SH_LOADED:-}" ]]; then
    declare -g BASH_PROMPT_FUNCS_SH_LOADED=true

    # shellcheck shell=bash
    # Variables provided externally
    : "${white:=}" "${light_blue:=}" "${blue:=}" "${light_red:=}" "${yellow:=}" "${light_green:=}" "${orange:=}" "${reset:=}"

    ###############################################################################
    # Name: check_venv
    # Short Description: Checks if the user is in a Python virtual environment.
    #
    # Long Description:
    #   Determines if the VIRTUAL_ENV environment variable is set, indicating an
    #   active Python virtual environment. If active, prints the environment path
    #   formatted with color codes for inclusion in the Bash prompt.
    #
    # Parameters:
    #   None
    #
    # Requirements:
    #   - Color variables (e.g., ${white}, ${light_blue}) must be defined in the
    #     environment where this function is sourced.
    #
    # Usage:
    #   check_venv
    #
    # Returns:
    #   - Prints the virtual environment information if active.
    #   - No output if not in a virtual environment.
    ###############################################################################
    function check_venv() {
        if [[ -n "${VIRTUAL_ENV}" ]]; then
            printf "%s\n" "\[${white}\][\[${light_blue}\]Python VENV = \[${light_blue}\]${VIRTUAL_ENV}\[${white}\]]"
            printf "%s\n" "\[${white}\]┣━"
        fi
    }
    ###############################################################################
    # Name: check_kerb_ccache
    # Short Description: Checks if a Kerberos credential cache is set.
    #
    # Long Description:
    #   Determines if the KRB5CCNAME environment variable is set, indicating an
    #   active Kerberos credential cache. If set, prints the cache name formatted
    #   with color codes for inclusion in the Bash prompt.
    #
    # Parameters:
    #   None
    #
    # Requirements:
    #   - Color variables (e.g., ${white}, ${light_red}) must be defined in the
    #     environment where this function is sourced.
    #
    # Usage:
    #   check_kerb_ccache
    #
    # Returns:
    #   - Prints the Kerberos credential cache information if set.
    #   - No output if not set.
    ###############################################################################
    function check_kerb_ccache() {
        if [[ -n "${KRB5CCNAME}" ]]; then
            printf "%s\n" "\[${white}\][\[${light_red}\]KRB5CCNAME = \[${light_red}\]${KRB5CCNAME}\[${white}\]]"
            printf "%s\n" "\[${white}\]┣━"
        fi
    }

    ###############################################################################
    # Name: check_git
    # Short Description: Displays current Git branch and dirty status for PS1.
    #
    # Long Description:
    #   Checks if the current directory is inside a Git working tree. If so,
    #   retrieves the branch or tag name, parses the remote origin URL into host
    #   and path, and summarizes uncommitted changes. Outputs a color-coded
    #   status string for inclusion in the Bash prompt.
    #
    # Parameters:
    #   None
    #
    # Requirements:
    #   - git must be installed and available in PATH.
    #
    # Usage:
    #   check_git
    #
    # Returns:
    #   - Prints a formatted Git status line if in a repository.
    #   - No output (exit code 0) if not in a Git repository.
    ###############################################################################
    function check_git() {
        # ---------------------------------------------------------------------
        # Confirm we are inside a git repository
        # ---------------------------------------------------------------------
        if ! git rev-parse --is-inside-work-tree &> /dev/null; then
            return 0
        fi

        # ---------------------------------------------------------------------
        # Determine branch and origin
        # ---------------------------------------------------------------------
        local branch origin_url host path origin
        branch=$(git symbolic-ref --quiet --short HEAD 2> /dev/null || git describe --tags --exact-match 2> /dev/null)
        [[ -z "${branch}" ]] && branch="unknown"

        origin_url=$(git config --get remote.origin.url 2> /dev/null || true)
        if [[ "${origin_url}" =~ ^git@([^:]+):([^/]+/[^/]+)(\.git)?$ ]]; then
            host="${BASH_REMATCH[1]}"
            path="${BASH_REMATCH[2]}"
        elif [[ "${origin_url}" =~ ^https?://([^/]+)/([^/]+/[^/.]+)(\.git)?$ ]]; then
            host="${BASH_REMATCH[1]}"
            path="${BASH_REMATCH[2]}"
        else
            host="unknown"
            path="local"
        fi
        origin="${host}/${path}"

        # ---------------------------------------------------------------------
        # Get repository status and format output
        # ---------------------------------------------------------------------
        local git_status
        if git_status=$(git status --porcelain 2> /dev/null); then
            if [[ -n "${git_status}" ]]; then
                local modified_count added_count deleted_count dirty_summary
                modified_count=$(echo "${git_status}" | grep -cE '^[ MARC][MD]')
                added_count=$(echo "${git_status}" | grep -cE '^[ MARC]A')
                deleted_count=$(echo "${git_status}" | grep -cE '^[ MARC]D')
                dirty_summary=""
                [[ ${modified_count} -gt 0 ]] && dirty_summary+=" M${modified_count}"
                [[ ${added_count} -gt 0 ]] && dirty_summary+=" A${added_count}"
                [[ ${deleted_count} -gt 0 ]] && dirty_summary+=" D${deleted_count}"

                printf "%s\n" "\[${white}\][\[${light_blue}\]GIT ${origin}:${branch} \[${light_red}\]✗${dirty_summary}\[${white}\]]"
            else
                printf "%s\n" "\[${white}\][\[${light_blue}\]GIT ${origin}:${branch} \[${light_green}\]✔\[${white}\]]"
            fi
        else
            printf "%s\n" "\[${white}\][\[${light_blue}\]GIT ${origin}:${branch} \[${orange}\]?\[${white}\]]"
        fi

        printf "%s\n" "\[${white}\]┣━"
    }

    ###############################################################################
    # Name: check_session
    # Short Description: Checks for active TMUX or SCREEN sessions.
    #
    # Long Description:
    #   Detects whether the shell is running inside a TMUX or SCREEN session.
    #   Retrieves the session names and prints them, color-coded, for the prompt.
    #
    # Parameters:
    #   None
    #
    # Requirements:
    #   - Color variables (e.g., ${white}, ${yellow}) must be defined.
    #   - A helper function get_session_name (if used) must be sourced.
    #
    # Usage:
    #   check_session
    #
    # Returns:
    #   - Prints session information if inside TMUX or SCREEN.
    #   - No output if not in any session.
    ###############################################################################
    function check_session() {
        local session_status=""

        # ---------------------------------------------------------------------
        # Detect TMUX session
        # ---------------------------------------------------------------------
        if [[ -n "${TMUX:-}" ]]; then
            local tmux_name tmux_win
            tmux_name=$(tmux display-message -p '#S' 2> /dev/null || echo "?")
            tmux_win=$(tmux display-message -p '#I:#W' 2> /dev/null || echo "?")
            session_status+="[\[${yellow}\]TMUX=${tmux_name}:${tmux_win}\[${white}\]]"
        fi

        # ---------------------------------------------------------------------
        # Detect SCREEN session
        # ---------------------------------------------------------------------
        if [[ -n "${STY:-}" ]]; then
            local full_sty="${STY}"
            local screen_name="${full_sty#*.}"
            local screen_win="${WINDOW:-?}"
            session_status+="[\[${yellow}\]SCREEN=${screen_name}:${screen_win}\[${white}\]]"
        fi

        # ---------------------------------------------------------------------
        # Output if any session detected
        # ---------------------------------------------------------------------
        if [[ -n "${session_status}" ]]; then
            session_status+="\[${white}\]\n┣━"
        fi
        printf "%s\n" "${session_status}"
    }

    ###############################################################################
    # Name: is_dhcp_static
    # Short Description: Determines if an interface is DHCP or static.
    #
    # Long Description:
    #   Examines the network configuration of a given interface across Linux
    #   (NetworkManager, systemd-networkd, /etc/network/interfaces) and macOS
    #   (networksetup) to report whether it uses DHCP or a static IP.
    #
    # Parameters:
    #   $1 - Interface name (e.g., "eth0", "en0")
    #
    # Requirements:
    #   - Helper function _get_os must be defined.
    #   - On macOS, the networksetup utility must be available.
    #
    # Usage:
    #   ip_type=$(is_dhcp_static "eth0")
    #
    # Returns:
    #   - Prints "DHCP" or "Static" on success.
    #   - Exits with status 1 and prints an error message on failure.
    ###############################################################################
    function is_dhcp_static() {
        local interface=$1
        if [[ -z "${interface}" ]]; then
            return 1
        fi

        # ---------------------------------------------------------------------
        # Detect OS type
        # ---------------------------------------------------------------------
        local os_type
        os_type=$(_get_os)

        case "${os_type}" in
            linux | ubuntu)
                # -----------------------------------------------------------------
                # LINUX/UBUNTU SECTION
                # -----------------------------------------------------------------

                # Use nmcli (NetworkManager)
                if command -v nmcli &> /dev/null && systemctl is-active NetworkManager &> /dev/null; then
                    local connection_profile
                    connection_profile=$(nmcli -g GENERAL.CONNECTION device show "${interface}" 2> /dev/null || true)
                    if [[ "${connection_profile}" != "--" && -n "${connection_profile}" ]]; then
                        local ip_method
                        ip_method=$(nmcli -g ipv4.method connection show "${connection_profile}" 2> /dev/null || true)
                        case "${ip_method}" in
                            auto)
                                printf "%s\n" "DHCP"
                                return 0
                                ;;
                            manual)
                                printf "%s\n" "Static"
                                return 0
                                ;;
                            *)
                                # No action
                                ;;
                        esac
                    fi
                fi

                # Use systemd-networkd (netplan YAML)
                if systemctl is-active systemd-networkd &> /dev/null; then
                    local config_file
                    config_file=$(find /etc/netplan/ -name "*.yaml" -print -quit)
                    if [[ -n "${config_file}" ]]; then
                        local config
                        config=$(grep -A3 "${interface}:" "${config_file}" 2> /dev/null || true)
                        if echo "${config}" | grep -q "dhcp4: true"; then
                            printf "%s\n" "DHCP"
                                                  return 0
                        elif echo "${config}" | grep -q "addresses:"; then
                            printf "%s\n" "Static"
                                                    return 0
                        fi
                    fi
                fi

                # Use legacy /etc/network/interfaces
                if [[ -f /etc/network/interfaces ]]; then
                    local config
                    config=$(grep -A3 "iface ${interface}" /etc/network/interfaces 2> /dev/null || true)
                    if echo "${config}" | grep -q "dhcp"; then
                        printf "%s\n" "DHCP"
                                              return 0
                    elif echo "${config}" | grep -q "static"; then
                        printf "%s\n" "Static"
                                                return 0
                    fi
                fi

                return 1
                ;;
            macos)
                # -----------------------------------------------------------------
                # MACOS SECTION
                # -----------------------------------------------------------------
                if ! command -v networksetup &> /dev/null; then
                    return 1
                fi

                local resulting_list
                resulting_list=$(networksetup -listallhardwareports | awk '
                    /^Hardware Port:/ { port_name = substr($0, index($0, $3)) }
                    /^Device:/ { device_name = $2; print device_name "," port_name }
                ')
                [[ -z "${resulting_list}" ]] && return 1

                while IFS= read -r line; do
                    local device="${line%%,*}"
                    local port_name="${line#*,}"
                    if [[ "${interface}" == "${device}" ]]; then
                        local config
                        config=$(networksetup -getinfo "${port_name}" 2> /dev/null || true)
                        [[ -z "${config}" ]] && return 1
                        if echo "${config}" | grep -q "DHCP Configuration"; then
                            printf "%s\n" "DHCP"
                                                  return 0
                        elif echo "${config}" | grep -q "Manually configured"; then
                            printf "%s\n" "Static"
                                                    return 0
                        else
                            printf "%s\n" "Unknown"
                                                     return 1
                        fi
                    fi
                done <<< "${resulting_list}"

                printf "%s\n" "Unknown"
                                         return 1
                ;;
            *)
                return 1
                ;;
        esac
    }

    ###############################################################################
    # Name: get_local_ip
    # Short Description: Retrieves and formats local IP addresses.
    #
    # Long Description:
    #   Enumerates network interfaces (excluding lo*, docker*, etc.), fetches their
    #   IP addresses, determines DHCP vs. static via is_dhcp_static, and builds a
    #   color-coded string for the Bash prompt. Exports PROMPT_LOCAL_IP.
    #
    # Parameters:
    #   None
    #
    # Requirements:
    #   - ip or ifconfig must be available.
    #   - is_dhcp_static must be defined and available.
    #
    # Usage:
    #   get_local_ip
    #
    # Returns:
    #   - Prints and exports PROMPT_LOCAL_IP on success.
    #   - Returns 1 if no valid interfaces are found or an error occurs.
    ###############################################################################
    function get_local_ip() {
        local os_type
        os_type="$(_get_os)"

        # ---------------------------------------------------------------------
        # Get interfaces differently depending on OS
        # ---------------------------------------------------------------------
        local interfaces=""
        case "${os_type}" in
            linux | ubuntu)
                if command -v ip &> /dev/null; then
                    interfaces=$(ip -o addr show | awk '$3 == "inet" && $4 != "127.0.0.1/8" {print $2,$4}')
                elif command -v ifconfig &> /dev/null; then
                    interfaces=$(ifconfig | awk '/^[a-zA-Z0-9]+:/ { iface=$1; next } /inet / && $2 != "127.0.0.1" { print iface,$2 }' | sed 's/://')
                else
                    return 1
                fi
                ;;
            macos)
                if command -v ifconfig &> /dev/null; then
                    interfaces=$(ifconfig | awk '/^[a-zA-Z0-9]+:/ { iface=$1; next } /inet / && $2 != "127.0.0.1" { print iface,$2 }' | sed 's/://')
                else
                    return 1
                fi
                ;;
            *)
                return 1
                ;;
        esac

        [[ -z "${interfaces}" ]] && return 1

        # ---------------------------------------------------------------------
        # Filter interfaces and format output
        # ---------------------------------------------------------------------
        local result="" iface ip dhcp
        while IFS= read -r line; do
            iface=$(echo "${line}" | awk '{print $1}')
            ip=$(echo "${line}" | awk '{print $2}' | cut -d'/' -f1)
            case "${iface}" in
                lo* | docker* | virbr* | vnet* | tun* | tap* | br-* | ip6tnl* | sit*)
                    continue
                    ;;
                *)
                    # No action
                    ;;
            esac
            if command -v is_dhcp_static &> /dev/null; then
                dhcp=$(is_dhcp_static "${iface}")
            else
                dhcp="unknown"
            fi
            result+="\[${light_blue}\]${iface}\[${yellow}\](${dhcp})\[${white}\]:\[${blue}\]${ip}\[${white}\], "
        done <<< "${interfaces}"

        export PROMPT_LOCAL_IP="${result%, }"
        [[ -z "${PROMPT_LOCAL_IP}" ]] && return 1
        printf "%s\n" "${PROMPT_LOCAL_IP}"
    }

    ###############################################################################
    # Name: get_external_ip
    # Short Description: Fetches and caches the external IPv4 address.
    #
    # Long Description:
    #   Checks a cache file (/tmp/external_ip.cache) for a recent IP (<10m). If
    #   stale or missing, retrieves a fresh IP via ifconfig.me using curl or wget,
    #   validates, caches, exports PROMPT_EXTERNAL_IP, and prints it.
    #
    # Parameters:
    #   None
    #
    # Requirements:
    #   - curl or wget must be installed.
    #
    # Usage:
    #   get_external_ip
    #
    # Returns:
    #   - Prints and exports PROMPT_EXTERNAL_IP on success.
    #   - Returns non-zero on any failure, printing an error message.
    ###############################################################################
    function get_external_ip() {
        # -------------------------------------------------------------------------
        # Variable declarations (explicit to avoid unbound errors under set -u)
        # -------------------------------------------------------------------------
        local cache_file="/tmp/external_ip.cache"
        local external_ip=""
        local now=""
        local last_modified=""
        local age_sec=0
        local stat_cmd=""
        local os_type=""
        local fetch_success=0
        local url=""

        # -------------------------------------------------------------------------
        # Use cached value if still valid (<10min)
        # -------------------------------------------------------------------------
        if [[ -f "${cache_file}" ]]; then
            now="$(date +%s)"
            if [[ "${os_type}" == "macos" ]]; then
                if ! last_modified="$(stat -f %m "${cache_file}" 2> /dev/null)"; then
                    last_modified=0
                fi
            else
                if ! last_modified="$(stat -c %Y "${cache_file}" 2> /dev/null)"; then
                    last_modified=0
                fi
            fi

            age_sec=$((now - last_modified))
            if ((age_sec < 600)); then
                external_ip="$(< "${cache_file}")"
                if [[ "${external_ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    export PROMPT_EXTERNAL_IP="${external_ip}"
                    printf "%s\n" "${PROMPT_EXTERNAL_IP}"
                    return 0
                else
                    rm -f "${cache_file}"
                fi
            fi
        fi

        # -------------------------------------------------------------------------
        # Connectivity check (1 ping)
        # -------------------------------------------------------------------------
        if [[ "${os_type}" == "macos" ]]; then
            # macOS has no ping timeout option; -t sets TTL not timeout
            if ! ping -c 1 1.1.1.1 > /dev/null 2>&1; then
                return 1
            fi
        else
            if ! ping -c 1 -W 2 1.1.1.1 > /dev/null 2>&1; then
                return 1
            fi
        fi

        # -------------------------------------------------------------------------
        # Attempt to fetch external IP from multiple services
        # -------------------------------------------------------------------------
        local services=(
            "https://ifconfig.me/ip"
            "https://api.ipify.org"
            "https://ipecho.net/plain"
        )

        for url in "${services[@]}"; do
            if command -v curl &> /dev/null; then
                external_ip="$(curl -4 -s --max-time 5 --connect-timeout 3 "${url}")"
            elif command -v wget &> /dev/null; then
                external_ip="$(wget -4 -qO- --timeout=5 --tries=1 "${url}")"
            else
                return 1
            fi

            # Validate external_ip
            if [[ "${external_ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                fetch_success=1
                break
            fi
        done

        if [[ "${fetch_success}" -ne 1 ]]; then
            return 1
        fi

        # -------------------------------------------------------------------------
        # Cache the new IP and output
        # -------------------------------------------------------------------------
        echo "${external_ip}" > "${cache_file}"
        export PROMPT_EXTERNAL_IP="${external_ip}"
        printf "%s\n" "${PROMPT_EXTERNAL_IP}"
        return 0
    }
fi

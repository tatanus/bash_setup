#!/usr/bin/env bash
# shellcheck disable=SC2154 # ENGAGEMENT_DIR is set by user's pen-testing environment
# shellcheck disable=SC2034 # Variables defined for future use in pen-testing workflow
set -uo pipefail
IFS=$'\n\t'

# =============================================================================
# NAME        : tgt.aliases.sh
# DESCRIPTION : Helper functions for managing Kerberos Ticket Granting Tickets (TGTs)
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-08 19:57:22
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-08 19:57:22  | Adam Compton | Initial creation.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${TGT_ALIAS_SH_LOADED:-}" ]]; then
    declare -g TGT_ALIAS_SH_LOADED=true

    # Default directory for TGT files
    TGT_DIR="${ENGAGEMENT_DIR}/LOOT/CREDENTIALS/CCACHE"

    # Ensure the TGT directory exists
    if [[ ! -d "${TGT_DIR}" ]]; then
        echo "Creating TGT directory: ${TGT_DIR}"
        mkdir -p "${TGT_DIR}" || {
            fail "Unable to create TGT directory."
            return 1
        }
    fi

    ###############################################################################
    # getTGT
    #------------------------------------------------------------------------------
    # Purpose  : Obtain a Ticket Granting Ticket (TGT) using getTGT.py
    # Usage    : getTGT <domain>/<user>:<pass> -dc-ip <dc>
    # Arguments:
    #   $@ : Arguments passed to getTGT.py
    # Returns  : 0 on success, 1 on failure
    ###############################################################################
    function getTGT() {
        if [[ $# -lt 3 ]]; then
            info "Usage: getTGT <domain>/<username>:<password> -dc-ip <dc> -or- <domain>/<username> -hashes <ntlm> -dc-ip <dc>"
            return 1
        fi

        local output
        # Pass all arguments as-is without word splitting
        if ! output=$(getTGT.py "$@" 2>&1); then
            fail "Failed to obtain TGT. Details:"
            echo "${output}"
            return 1
        fi

        local filename
        filename=$(echo "${output}" | grep "Saving ticket in" | awk '{print $NF}')

        if [[ -z "${filename}" ]]; then
            fail "TGT file was not created or path could not be determined."
            return 1
        fi

        saveTGT "${filename}"
    }

    ###############################################################################
    # saveTGT
    #------------------------------------------------------------------------------
    # Purpose  : Save a TGT (ccache) file to the TGT directory
    # Usage    : saveTGT <file>
    # Arguments:
    #   $1 : file - Path to the TGT file to save
    # Returns  : 0 on success, 1 on failure
    ###############################################################################
    function saveTGT() {
        if [[ $# -ne 1 ]]; then
            info "Usage: saveTGT <file>"
            return 1
        fi

        local tgt_file="$1"
        local tgt_filename
        tgt_filename=$(basename "${tgt_file}")

        if [[ ! -f "${tgt_file}" ]]; then
            fail "TGT file '${tgt_file}' does not exist."
            return 1
        fi

        if [[ ! -f "${TGT_DIR}/${tgt_filename}" ]]; then
            cp "${tgt_file}" "${TGT_DIR}/${tgt_filename}"
        else
            local i=1
            while [[ -f "${TGT_DIR}/${tgt_filename%.*}-${i}.${tgt_filename##*.}" ]]; do
                ((i++))
            done
            cp "${tgt_file}" "${TGT_DIR}/${tgt_filename%.*}-${i}.${tgt_filename##*.}"
        fi

        info "TGT file saved to ${TGT_DIR}."
    }

    ###############################################################################
    # listTGT
    #------------------------------------------------------------------------------
    # Purpose  : List TGT files and allow interactive selection via fzf
    # Usage    : listTGT
    # Returns  : 0 on success, 1 on failure
    ###############################################################################
    function listTGT() {
        if [[ ! -d "${TGT_DIR}" ]]; then
            fail "TGT directory does not exist."
            return 1
        fi

        local ccache_files=("${TGT_DIR}"/*.ccache)
        if [[ ${#ccache_files[@]} -eq 0 ]]; then
            warn "No TGT files found in ${TGT_DIR}."
            return 1
        fi

        local tgt_choices=()
        for tgt_file in "${ccache_files[@]}"; do
            local filename
            filename=$(basename "${tgt_file}")
            local validity
            validity=$(validateTGT "${tgt_file}" | cut -d ' ' -f 2-)
            tgt_choices+=("$(printf "%-40s - %-40s" "${filename}" "${validity}")")
        done

        echo -ne "\033]0;Choose a TGT file\007"
        local selected_tgt
        selected_tgt=$(printf "%s\n" "${tgt_choices[@]}" | fzf --prompt="Choose a TGT file: " --no-clear)
        echo -ne "\033]0;\007"

        local selected_filename
        selected_filename=$(echo "${selected_tgt}" | awk '{print $1}')

        for tgt_file in "${ccache_files[@]}"; do
            if [[ "${tgt_file}" == *"${selected_filename}"* ]]; then
                exportTGT "${tgt_file}"
                info "${tgt_file} exported to KRB5CCNAME"
                return 0
            fi
        done

        warn "Invalid choice."
        return 1
    }

    ###############################################################################
    # validateTGT
    #------------------------------------------------------------------------------
    # Purpose  : Validate a TGT file and check its expiration time
    # Usage    : validateTGT <file>
    # Arguments:
    #   $1 : file - Path to the TGT file to validate
    # Returns  : 0 if valid, 1 if expired or error
    ###############################################################################
    function validateTGT() {
        if [[ $# -ne 1 ]]; then
            info "Usage: validateTGT <file>"
            return 1
        fi

        local tgt_file="$1"

        if [[ ! -f "${tgt_file}" ]]; then
            fail "File '${tgt_file}' does not exist."
            return 1
        fi

        local end_time
        end_time=$(KRB5CCNAME="${tgt_file}" klist -A 2> /dev/null | grep "krbtgt" | awk '{print $3, $4}')
        if [[ -z "${end_time}" ]]; then
            echo "${tgt_file}: Expired"
            return 1
        fi

        echo "${tgt_file}: Valid (Expires: ${end_time})"
    }

    ###############################################################################
    # exportTGT
    #------------------------------------------------------------------------------
    # Purpose  : Export a TGT file by setting KRB5CCNAME
    # Usage    : exportTGT <full_path>
    # Arguments:
    #   $1 : full_path - Full path to the TGT file
    # Returns  : 0 on success, 1 on error
    ###############################################################################
    function exportTGT() {
        # Check the number of arguments
        # Usage: exportTGT <full_path_and_filename>
        if [[ $# -ne 1 ]]; then
            info "Usage: exportTGT <full_path_and_filename>"
            return 1
        fi

        export KRB5CCNAME="$1"
    }

    ###############################################################################
    # renewTGT
    #------------------------------------------------------------------------------
    # Purpose  : Renew a Kerberos TGT using kinit or renewTGT.py
    # Usage    : renewTGT <ccache>
    # Arguments:
    #   $1 : ccache - Path to the credential cache file
    # Returns  : 0 on success
    ###############################################################################
    function renewTGT() {
        # Check the number of arguments
        # Usage: renewTGT <ccache>
        if [[ $# -ne 1 ]]; then
            info "Usage: renewTGT <ccache>"
            return 1
        fi

        local ccache="$1"

        if [[ -x "/usr/local/bin/renewTGT.py" ]]; then
            KRB5CCNAME="${ccache}" /usr/local/bin/renewTGT.py -k
        elif [[ -x "/root/.local/bin/renewTGT.py" ]]; then
            KRB5CCNAME="${ccache}" /root/.local/bin/renewTGT.py -k
        else
            KRB5CCNAME="${ccache}" kinit -R -r7d
        fi
    }

    ###############################################################################
    # renewAllTGT
    #------------------------------------------------------------------------------
    # Purpose  : Renew all TGT files in the TGT directory
    # Usage    : renewAllTGT
    # Returns  : 0 on success, 1 if no TGTs found
    ###############################################################################
    function renewAllTGT() {
        # Check if directory exists
        if [[ ! -d "${TGT_DIR}" ]]; then
            warn "No TGT files found."
            return 1
        fi

        # List .ccache files in the directory
        local ccache_files=("${TGT_DIR}"/*.ccache)
        if [[ ${#ccache_files[@]} -eq 0 ]]; then
            warn "No TGT files found in ${TGT_DIR}."
            return 1
        fi

        # renew each TGT file
        for tgt_file in "${ccache_files[@]}"; do
            if [[ $# -ne 1 ]]; then
                renewTGT "${tgt_file}"
            else
                renewTGT "${tgt_file}" "$1"
            fi
        done
    }

    ###############################################################################
    # testTGTs
    #------------------------------------------------------------------------------
    # Purpose  : Test TGT files against a domain controller
    # Usage    : testTGTs <dc-ip>
    # Arguments:
    #   $1 : dc-ip - IP address of the domain controller
    # Returns  : 0 on success, 1 on failure
    ###############################################################################
    function testTGTs() {
        # Check the number of arguments
        # Usage: textTGTs <dc-ip>
        if [[ $# -ne 1 ]]; then
            info "Usage: textTGTs <dc-ip>"
            return 1
        fi

        local dc_ip="$1"

        # Check if directory exists
        if [[ ! -d "${TGT_DIR}" ]]; then
            warn "No TGT files found."
            return 1
        fi

        # List .ccache files in the directory
        local ccache_files=("${TGT_DIR}"/*.ccache)
        if [[ ${#ccache_files[@]} -eq 0 ]]; then
            warn "No TGT files found in ${TGT_DIR}."
            return 1
        fi

        # Validate each TGT file
        for tgt_file in "${ccache_files[@]}"; do
            echo "${tgt_file}"
            export KRB5CCNAME="${tgt_file}"
            #nxc smb $dc_ip --use-kcache
        done
    }

    ###############################################################################
    # validateAllTGT
    #------------------------------------------------------------------------------
    # Purpose  : Validate all TGT files in the TGT directory
    # Usage    : validateAllTGT
    # Returns  : 0 on completion
    ###############################################################################
    function validateAllTGT() {
        # Check if directory exists
        if [[ ! -d "${TGT_DIR}" ]]; then
            warn "No TGT files found."
            return 1
        fi

        # List .ccache files in the directory
        local ccache_files=("${TGT_DIR}"/*.ccache)
        if [[ ${#ccache_files[@]} -eq 0 ]]; then
            warn "No TGT files found in ${TGT_DIR}."
            return 1
        fi

        # Validate each TGT file
        for tgt_file in "${ccache_files[@]}"; do
            validateTGT "${tgt_file}"
        done
    }
fi

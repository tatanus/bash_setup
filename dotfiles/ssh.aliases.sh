#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : ssh.aliases.sh
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
if [[ -z "${SSH_ALIASES_SH_LOADED:-}" ]]; then
    declare -g SSH_ALIASES_SH_LOADED=true

    # Function to check if the target is mounted
    function _ssh_is_mounted() {
        mount | grep -q "on ${FULL_MOUNT_POINT_PATH} " > /dev/null
        return $?
    }

    function sshfs_mount() {
        local TARGET_SYSTEM="$1"

        # Ensure TARGET_SYSTEM is provided
        if [[ -z "${TARGET_SYSTEM}" ]]; then
            fail "No target system specified."
            return 1
        fi

        local MOUNT_POINT="${HOME}/mnt/${TARGET_SYSTEM}"

        # Ensure MOUNT_POINT directory exists to avoid `realpath` errors
        mkdir -p "${MOUNT_POINT}"

        local FULL_MOUNT_POINT_PATH
        FULL_MOUNT_POINT_PATH=$(realpath "${MOUNT_POINT}")

        # Check if sshfs has already mounted the remote filesystem
        if _ssh_is_mounted; then
            info "${FULL_MOUNT_POINT_PATH} is already mounted."
            return 0
        fi

        # Ensure the mount point directory exists
        if [[ ! -d "${MOUNT_POINT}" ]]; then
            info "Creating mount point: ${MOUNT_POINT}"
            mkdir -p "${MOUNT_POINT}"
        fi

        # Mount using sshfs
        info "Mounting ${TARGET_SYSTEM}:/root to ${MOUNT_POINT}"
        sshfs "${TARGET_SYSTEM}:/root" "${MOUNT_POINT}"

        sleep 2

        # Verify if the mount was successful
        if _ssh_is_mounted; then
            pass "Mounted ${TARGET_SYSTEM} successfully."
            return 0
        else
            fail "Failed to mount ${TARGET_SYSTEM}."
            return 1
        fi
    }

    function sshfs_unmount() {
        local TARGET_SYSTEM="$1"

        # Ensure TARGET_SYSTEM is provided
        if [[ -z "${TARGET_SYSTEM}" ]]; then
            fail "No target system specified."
            return 1
        fi

        local MOUNT_POINT="${HOME}/mnt/${TARGET_SYSTEM}"

        # Ensure the mount point exists
        if [[ ! -d "${MOUNT_POINT}" ]]; then
            info "Mount point ${MOUNT_POINT} does not exist. Nothing to unmount."
            return 0
        fi

        local FULL_MOUNT_POINT_PATH
        FULL_MOUNT_POINT_PATH=$(realpath "${MOUNT_POINT}")

        # Check if the mount exists
        if _ssh_is_mounted; then
            info "Unmounting ${FULL_MOUNT_POINT_PATH}..."
            umount "${FULL_MOUNT_POINT_PATH}"

            sleep 2

            # Verify if the unmount was successful
            if _ssh_is_mounted; then
                fail "Failed to unmount ${FULL_MOUNT_POINT_PATH}."
                return 1
            else
                pass "Unmounted ${FULL_MOUNT_POINT_PATH} successfully."
            fi
        else
            info "${FULL_MOUNT_POINT_PATH} is not currently mounted."
        fi

        return 0
    }
fi

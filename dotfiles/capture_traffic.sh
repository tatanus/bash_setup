#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : capture_traffic.sh
# DESCRIPTION : Capture bidirectional communication between two IPs and ports.
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-08 19:57:22
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-08 19:57:22  | Adam Compton | Initial creation.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${CAPTURETRAFFIC_SH_LOADED:-}" ]]; then
    declare -g CAPTURETRAFFIC_SH_LOADED=true

    # =============================================================================
    # Configuration and Defaults
    # =============================================================================

    DEFAULT_CAPTURE_TIME=10       # Default capture time in seconds
    DEFAULT_MAX_MESSAGES=100      # Default maximum number of messages to capture
    DEFAULT_INTERFACE="any"       # Default capture interface
    TSHARK_CMD=$(command -v tshark)

    # =============================================================================
    # Helper Functions
    # =============================================================================

    # Check if tshark is available
    check_tshark() {
        if [[ -z "${TSHARK_CMD}" ]]; then
            fail "tshark is not installed or not in PATH." >&2
            exit 1
        fi
    }

    # Validate and parse arguments
    parse_capture_args() {
        if [[ $# -lt 4 ]]; then
            info "Usage: $0 <src_ip> <dst_ip> <src_port> <dst_port> [-t <seconds>] [-m <messages>] [--interface <iface>]" >&2
            info "Example: $0 192.168.1.1 192.168.1.2 5000 5001 -t 10 --interface eth0" >&2
            exit 1
        fi

        SRC_IP=$1
        DST_IP=$2
        SRC_PORT=$3
        DST_PORT=$4
        CAPTURE_TIME=${DEFAULT_CAPTURE_TIME}
        MAX_MESSAGES=${DEFAULT_MAX_MESSAGES}
        CAPTURE_INTERFACE=${DEFAULT_INTERFACE}

        shift 4
        while [[ $# -gt 0 ]]; do
            case $1 in
                -t | --time)
                    CAPTURE_TIME=$2
                    shift 2
                    ;;
                -m | --messages)
                    MAX_MESSAGES=$2
                    shift 2
                    ;;
                --interface)
                    CAPTURE_INTERFACE=$2
                    shift 2
                    ;;
                --help)
                    info "Usage: $0 <src_ip> <dst_ip> <src_port> <dst_port> [-t <seconds>] [-m <messages>] [--interface <iface>]"
                    info "Options:"
                    info "  -t, --time       Capture time in seconds (default: ${DEFAULT_CAPTURE_TIME})"
                    info "  -m, --messages   Maximum number of messages to capture (default: ${DEFAULT_MAX_MESSAGES})"
                    info "  --interface      Network interface to capture traffic (default: ${DEFAULT_INTERFACE})"
                    info "Example:"
                    info "  $0 192.168.1.1 192.168.1.2 5000 5001 -t 10 --interface eth0"
                    exit 0
                    ;;
                *)
                    warn "Unknown argument: $1" >&2
                    exit 1
                    ;;
            esac
        done
    }

    # =============================================================================
    # Main Function
    # =============================================================================

    capture_traffic() {
        # Parse arguments
        parse_capture_args "$@"

        # Check if tshark is available
        check_tshark

        info "Capturing traffic between ${SRC_IP}:${SRC_PORT} and ${DST_IP}:${DST_PORT} on interface ${CAPTURE_INTERFACE} for ${CAPTURE_TIME} seconds or ${MAX_MESSAGES} messages..."

        # Capture traffic using tshark
        if ! tshark -i "${CAPTURE_INTERFACE}" \
            -a duration:"${CAPTURE_TIME}" \
            -c "${MAX_MESSAGES}" \
            -Y "ip.src==${SRC_IP} && ip.dst==${DST_IP} && tcp.srcport==${SRC_PORT} && tcp.dstport==${DST_PORT} || \
            ip.src==${DST_IP} && ip.dst==${SRC_IP} && tcp.srcport==${DST_PORT} && tcp.dstport==${SRC_PORT}" \
            -T fields -e frame.time -e ip.src -e tcp.srcport -e ip.dst -e tcp.dstport -e text \
            2> /dev/null | awk '
            BEGIN { OFS = ""; print "Timestamp\tSource\t\tDestination\t\tPayload" }
            {
                timestamp = $1 " " $2
                src = $3 ":" $4
                dst = $5 ":" $6
                payload = ($7 == "") ? "[No payload or binary data]" : substr($0, index($0,$7))
                print "[" timestamp "]\t" src " -> " dst ":\t" payload
            }'; then
            fail "Failed to capture traffic or no packets matched the criteria." >&2
            return 1
        fi
    }
fi

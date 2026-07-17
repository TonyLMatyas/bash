#!/usr/bin/env bash
#
# get-vm-network-interfaces.sh
#
# Purpose:
#   For every currently RUNNING VM on this Proxmox node, queries the QEMU
#   guest agent for its network interfaces and saves the output to:
#     /tmp/network-get-interfaces.<VMID>.txt
#
# Safety notes:
#   - Read-only: only calls "qm agent ... network-get-interfaces", never
#     modifies any VM.
#   - Each VM is queried with a timeout so one unresponsive guest agent
#     cannot hang the whole script.
#   - A failure on one VM (agent not installed/running) is logged and
#     skipped; the script continues with the remaining VMs.
#
# Usage:
#   ./get-vm-network-interfaces.sh [-h|--help]

set -uo pipefail
# Note: we intentionally do NOT use 'set -e'. One VM failing must not
# abort the loop for the rest of the VMs.

# ---- Configuration -----------------------------------------------------
OUTPUT_DIR="/tmp"
AGENT_TIMEOUT_SECONDS=10   # max time to wait per VM before giving up

# ---- Help text ----------------------------------------------------------
print_help() {
    cat <<'EOF'
Usage: get-vm-network-interfaces.sh [OPTIONS]

For each currently running Proxmox VM, runs:
  qm agent <VMID> network-get-interfaces
and saves the output to:
  /tmp/network-get-interfaces.<VMID>.txt

Options:
  -h, --help    Show this help message and exit

Notes:
  - Must be run on a Proxmox node with the 'qm' command available.
  - Requires privileges to run 'qm' (typically root, or via sudo).
  - VMs without a running/responsive guest agent are skipped, not fatal.
EOF
}

for arg in "$@"; do
    case "$arg" in
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            print_help
            exit 1
            ;;
    esac
done

# ---- Sanity checks --------------------------------------------------------
# Confirm we're actually on a Proxmox host with the tools we need.
if ! command -v qm &> /dev/null; then
    echo "ERROR: 'qm' command not found. This script must run on a Proxmox VE node." >&2
    exit 1
fi

if [[ ! -d "$OUTPUT_DIR" || ! -w "$OUTPUT_DIR" ]]; then
    echo "ERROR: Output directory '$OUTPUT_DIR' does not exist or is not writable." >&2
    exit 1
fi

# 'qm list' requires sufficient privilege; fail early with a clear message
# rather than partway through the loop.
if ! qm list &> /dev/null; then
    echo "ERROR: Unable to run 'qm list'. Try running this script as root or with sudo." >&2
    exit 1
fi

echo "=== Starting network interface export: $(date '+%Y-%m-%d %H:%M:%S') ==="

# ---- Gather running VMIDs -------------------------------------------------
# 'qm list' columns: VMID NAME STATUS MEM(MB) BOOTDISK(GB) PID
# We filter to status "running" and pull out just the VMID (column 1).
mapfile -t running_vmids < <(qm list | awk '$3 == "running" {print $1}')

if [[ ${#running_vmids[@]} -eq 0 ]]; then
    echo "No running VMs found on this node. Nothing to do."
    exit 0
fi

echo "Found ${#running_vmids[@]} running VM(s): ${running_vmids[*]}"
echo

# ---- Query each VM's guest agent ------------------------------------------
success_count=0
skip_count=0

for vmid in "${running_vmids[@]}"; do
    out_file="${OUTPUT_DIR}/network-get-interfaces.${vmid}.txt"
    echo "[VM ${vmid}] Querying guest agent (timeout ${AGENT_TIMEOUT_SECONDS}s)..."

    # 'timeout' guards against a hung/unresponsive guest agent.
    # Overwrites out_file each run (>) as requested — no history kept.
    if timeout "${AGENT_TIMEOUT_SECONDS}" qm agent "$vmid" network-get-interfaces > "$out_file" 2>/tmp/.qm-agent-err.$$; then
        echo "[VM ${vmid}] OK -> ${out_file}"
        success_count=$((success_count + 1))
    else
        echo "[VM ${vmid}] WARNING: guest agent did not respond (not installed, not running, or timed out). Skipping." >&2
        # Remove the empty/partial output file so stale data isn't left behind.
        rm -f "$out_file"
        skip_count=$((skip_count + 1))
    fi
    rm -f "/tmp/.qm-agent-err.$$"
done

echo
echo "=== Done: $(date '+%Y-%m-%d %H:%M:%S') ==="
echo "Succeeded: ${success_count}  Skipped: ${skip_count}  Total: ${#running_vmids[@]}"

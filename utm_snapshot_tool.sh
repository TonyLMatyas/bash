#!/usr/bin/env bash

set -e

UTM_DIR="$HOME/Library/Containers/com.utmapp.UTM/Data/Documents"

# Defaults
VERBOSE=0
ACTION=""
KEEP_N=0
RESTORE_DISK=""
TARGET_TAG=""
DELETE_TAG=""

# Helper: Verbose log print
log_info() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo "[INFO] $1"
    fi
}

# Helper: Show Usage
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Manage snapshots for UTM Virtual Machines (qcow2 format).

Options:
  -h, --help                          Display this help message
  -v, --verbose                       Enable verbose logging
  -l, --list                          List all snapshots across all UTM VMs
  -c, --create-snapshots              Create a new snapshot for every stopped UTM VM
  -k, --keep N                        Retain latest N snapshots per VM disk, delete older ones
  -r, --restore <qcow_disk> <Tag>     Restore specified qcow2 disk to <Tag>
  -d, --delete <Tag>                  Delete snapshot with specified <Tag> across all disks

Examples:
  $(basename "$0") -c
  $(basename "$0") -l -v
  $(basename "$0") -k 3
  $(basename "$0") -r /path/to/data.qcow2 snap-20260917-120000
  $(basename "$0") -d snap-20260917-120000
EOF
}

# Check if any UTM VM is running via system process check
check_vms_running() {
    log_info "Checking if any UTM virtual machines are currently running..."
    if pgrep -fi "UTM.app/Contents/MacOS/QEMUHelper" > /dev/null || pgrep -fi "qemu-system" > /dev/null; then
        echo "[ERROR] One or more UTM Virtual Machines are currently running!" >&2
        echo "Please shut down all UTM VMs before running this operation." >&2
        exit 1
    fi
}

# Find all qcow2 files inside UTM VM bundles
get_qcow2_disks() {
    if [[ ! -d "$UTM_DIR" ]]; then
        echo "[ERROR] UTM VM directory not found at: $UTM_DIR" >&2
        exit 1
    fi
    find "$UTM_DIR" -type f -name "*.qcow2"
}

# Command Parser
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -l|--list)
            ACTION="list"
            shift
            ;;
        -c|--create-snapshots)
            ACTION="create"
            shift
            ;;
        -k|--keep)
            ACTION="keep"
            KEEP_N="$2"
            if ! [[ "$KEEP_N" =~ ^[0-9]+$ ]] || [[ "$KEEP_N" -eq 0 ]]; then
                echo "[ERROR] Option --keep N requires a positive integer." >&2
                exit 1
            fi
            shift 2
            ;;
        -r|--restore)
            ACTION="restore"
            RESTORE_DISK="$2"
            TARGET_TAG="$3"
            if [[ -z "$RESTORE_DISK" || -z "$TARGET_TAG" ]]; then
                echo "[ERROR] --restore requires both <qcow_disk> path and <SnapshotTag>." >&2
                exit 1
            fi
            shift 3
            ;;
        -d|-delete|--delete)
            ACTION="delete"
            DELETE_TAG="$2"
            if [[ -z "$DELETE_TAG" ]]; then
                echo "[ERROR] --delete requires a <SnapshotTag>." >&2
                exit 1
            fi
            shift 2
            ;;
        *)
            echo "[ERROR] Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

if [[ -z "$ACTION" ]]; then
    echo "[ERROR] No action specified." >&2
    show_help
    exit 1
fi

# Main logic execution
case "$ACTION" in
    list)
        log_info "Listing snapshots for all UTM virtual disks..."
        get_qcow2_disks | while read -r disk; do
            echo "=================================================="
            echo "Disk: $disk"
            echo "=================================================="
            qemu-img snapshot -l "$disk" || echo "  (No snapshots or invalid image)"
            echo ""
        done
        ;;

    create)
        check_vms_running
        TAG="snap-$(date +'%Y%m%d-%H%M%S')"
        log_info "Creating snapshot with tag: $TAG"
        
        get_qcow2_disks | while read -r disk; do
            log_info "Processing disk: $disk"
            qemu-img snapshot -c "$TAG" "$disk"
            echo "[SUCCESS] Created snapshot '$TAG' for: $(basename "$(dirname "$disk")")"
        done
        ;;

    keep)
        check_vms_running
        log_info "Pruning snapshots to retain only the latest $KEEP_N per disk..."
        
        get_qcow2_disks | while read -r disk; do
            log_info "Checking disk: $disk"
            
            # Extract tags ordered from newest to oldest
            tags=($(qemu-img snapshot -l "$disk" | tail -n +3 | awk '{print $2}'))
            total_snaps=${#tags[@]}
            
            if [[ $total_snaps -gt $KEEP_N ]]; then
                log_info "Found $total_snaps snapshots. Retaining $KEEP_N, deleting $((total_snaps - KEEP_N))..."
                
                # Delete older snapshots starting after KEEP_N index
                for ((i=KEEP_N; i<total_snaps; i++)); do
                    tag_to_del="${tags[i]}"
                    log_info "Deleting snapshot '$tag_to_del' from $disk"
                    qemu-img snapshot -d "$tag_to_del" "$disk"
                    echo "[DELETED] $tag_to_del from $(basename "$(dirname "$disk")")"
                done
            else
                log_info "Disk has $total_snaps snapshot(s). No pruning required."
            fi
        done
        ;;

    restore)
        check_vms_running
        if [[ ! -f "$RESTORE_DISK" ]]; then
            echo "[ERROR] Specified qcow2 file does not exist: $RESTORE_DISK" >&2
            exit 1
        fi
        
        log_info "Restoring disk '$RESTORE_DISK' to snapshot '$TARGET_TAG'..."
        qemu-img snapshot -a "$TARGET_TAG" "$RESTORE_DISK"
        echo "[SUCCESS] Restored $RESTORE_DISK to snapshot '$TARGET_TAG'"
        ;;

    delete)
        check_vms_running
        log_info "Searching and deleting snapshot tag '$DELETE_TAG'..."
        
        get_qcow2_disks | while read -r disk; do
            if qemu-img snapshot -l "$disk" | grep -q "$DELETE_TAG"; then
                log_info "Found tag '$DELETE_TAG' on $disk. Deleting..."
                qemu-img snapshot -d "$DELETE_TAG" "$disk"
                echo "[SUCCESS] Deleted snapshot '$DELETE_TAG' from $disk"
            else
                log_info "Tag '$DELETE_TAG' not present on $disk. Skipping."
            fi
        done
        ;;
esac

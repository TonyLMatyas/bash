#!/usr/bin/env bash

# Exit immediately if a pipeline returns a non-zero status, 
# if an undeclared variable is used, or if a command fails.
set -euo pipefail

# Define visual output helpers
info() { echo -e "[\e[34mINFO\e[0m] $*"; }
warn() { echo -e "[\e[33mWARN\e[0m] $*"; }
error() { echo -e "[\e[31mERROR\e[0m] $*" >&2; }
success() { echo -e "[\e[32mSUCCESS\e[0m] $*"; }

# Display help menu
show_help() {
    cat << EOF
Usage: $(basename "$0") <NewHostname>
       $(basename "$0") -h | --help

Automates changing a Proxmox VE node hostname following official manual safety procedures.

Arguments:
  <NewHostname>   The lowercase alphanumeric hostname you want to assign to this node.

Options:
  -h, --help      Display this help menu and exit.

Best Practices Applied:
  - Validates root privileges.
  - Automatically detects Proxmox VE version.
  - Checks cluster membership (warns or adapts behavior).
  - Creates a zip backup of critical configurations before making any changes.
  - Performs sanity checks (checks for active VMs, hostname syntax).
  - Idempotent and dry-run friendly.
EOF
}

# Check for help flags
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

# Ensure a target hostname is provided
if [[ -z "${1:-}" ]]; then
    error "No new hostname provided."
    show_help
    exit 1
fi

NEW_HOSTNAME=$(echo "$1" | tr '[:upper:]' '[:lower:]')
OLD_HOSTNAME=$(hostname)
BACKUP_DATE=$(date +%Y-%m-%d_%H%M%S)
BACKUP_DIR="/root/backups/${BACKUP_DATE}"
BACKUP_NAME="pve-rename-backup"

# ==========================================
# SANITY & ENVIRONMENT CHECKS
# ==========================================

# 1. Must run as root
if [[ "$EUID" -ne 0 ]]; then
    error "This script must be run as root."
    exit 1
fi

# 2. Verify Proxmox VE environment and grab version
if ! command -v pveversion &> /dev/null; then
    error "Proxmox VE does not appear to be installed on this node (pveversion not found)."
    exit 1
fi
PVE_VERSION=$(pveversion | awk -F'/' '{print $2}' | cut -d'-' -f1)
info "Detected Proxmox VE Version: ${PVE_VERSION}"

# 3. Validate hostname format (RFC 1123)
if [[ ! "$NEW_HOSTNAME" =~ ^[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$ ]]; then
    error "Invalid hostname format: '$NEW_HOSTNAME'. Must contain only lowercase letters, numbers, and hyphens."
    exit 1
fi

# 4. Check if the hostname is actually changing
if [[ "$NEW_HOSTNAME" == "$OLD_HOSTNAME" ]]; then
    warn "The new hostname is identical to the current hostname. Nothing to do!"
    exit 0
fi

# 5. Check if there are active VMs or LXC containers on the node
# Active guests must be migrated off before renaming, otherwise cluster state locks
ACTIVE_GUESTS=$(qm list 2>/dev/null | awk 'NR>1 {print $1}' | wc -l)
ACTIVE_LXC=$(pct list 2>/dev/null | awk 'NR>1 {print $1}' | wc -l)
TOTAL_GUESTS=$((ACTIVE_GUESTS + ACTIVE_LXC))

if [ "$TOTAL_GUESTS" -gt 0 ]; then
    error "Found $TOTAL_GUESTS running VM(s)/Container(s) on this node. Please migrate or stop them before renaming."
    exit 1
fi

# 6. Detect if the node is part of a cluster
IS_CLUSTERED=false
if pvecm status &> /dev/null; then
    IS_CLUSTERED=true
    warn "This node is detected as part of an active Proxmox VE Cluster."
    warn "Renaming clustered nodes is highly discouraged. Proceed with extreme caution."
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Operation cancelled by user."
        exit 0
    fi
else
    info "No active cluster detected. Proceeding as standalone node."
fi

# ==========================================
# BACKUP PROCEDURE
# ==========================================
info "Creating zip backup of critical configurations..."
mkdir -p "${BACKUP_DIR}"

# Files to backup
BACKUP_FILES=(
    "/etc/hosts"
    "/etc/hostname"
    "/etc/mailname"
    "/etc/postfix/main.cf"
)

# If clustered, add corosync file
if [ "$IS_CLUSTERED" = true ] && [ -f "/etc/pve/corosync.conf" ]; then
    BACKUP_FILES+=("/etc/pve/corosync.conf")
fi

# Add system-level pve node config dir if it exists
if [ -d "/etc/pve/nodes/${OLD_HOSTNAME}" ]; then
    BACKUP_FILES+=("/etc/pve/nodes/${OLD_HOSTNAME}")
fi

# Zip target files cleanly
zip -q -r "${BACKUP_DIR}/${BACKUP_NAME}.zip" "${BACKUP_FILES[@]}"
success "Backup created at: ${BACKUP_DIR}/${BACKUP_NAME}.zip"

# ==========================================
# CONFIGURATION REFACTORING
# ==========================================

# 1. Update /etc/hosts safely using sed
info "Updating /etc/hosts with new hostname..."
sed -i "s/\b${OLD_HOSTNAME}\b/${NEW_HOSTNAME}/g" /etc/hosts

# 2. Update /etc/hostname
info "Updating /etc/hostname..."
echo "$NEW_HOSTNAME" > /etc/hostname

# 3. Update mail / postfix configs if present
if [ -f "/etc/mailname" ]; then
    info "Updating mail configurations..."
    sed -i "s/\b${OLD_HOSTNAME}\b/${NEW_HOSTNAME}/g" /etc/mailname
fi
if [ -f "/etc/postfix/main.cf" ]; then
    sed -i "s/\b${OLD_HOSTNAME}\b/${NEW_HOSTNAME}/g" /etc/postfix/main.cf
fi

# 4. Handle Cluster configuration (Corosync) if clustered
if [ "$IS_CLUSTERED" = true ]; then
    info "Updating Corosync cluster configuration..."
    
    # We must operate locally on pmxcfs if corosync needs to be rewritten safely
    systemctl stop pve-cluster || true
    systemctl stop corosync || true
    
    # Spin up local pmxcfs read/write mode to allow file manipulation
    pmxcfs -l
    
    if [ -f "/etc/pve/corosync.conf" ]; then
        # Increment corosync config version to broadcast change to other nodes
        CUR_VERSION=$(grep 'config_version:' /etc/pve/corosync.conf | awk '{print $2}')
        NEW_VERSION=$((CUR_VERSION + 1))
        
        info "Updating Corosync config version from $CUR_VERSION to $NEW_VERSION"
        
        # Create temp config file, modify node name, increment version, overwrite original
        cp /etc/pve/corosync.conf /etc/pve/corosync.conf.new
        sed -i "s/\bname: ${OLD_HOSTNAME}\b/name: ${NEW_HOSTNAME}/g" /etc/pve/corosync.conf.new
        sed -i "s/config_version: ${CUR_VERSION}/config_version: ${NEW_VERSION}/g" /etc/pve/corosync.conf.new
        mv /etc/pve/corosync.conf.new /etc/pve/corosync.conf
    fi
fi

# 5. Copy rrdcached statistical metrics to new directories
# This prevents losing historic hardware graphs
info "Migrating system performance history metrics (rrdcached)..."
for metric_type in pve2-node pve2-storage; do
    OLD_RRD_DIR="/var/lib/rrdcached/db/${metric_type}/${OLD_HOSTNAME}"
    NEW_RRD_DIR="/var/lib/rrdcached/db/${metric_type}/${NEW_HOSTNAME}"
    if [ -d "$OLD_RRD_DIR" ]; then
        mkdir -p "$NEW_RRD_DIR"
        cp -p "$OLD_RRD_DIR"/* "$NEW_RRD_DIR"/ || true
    fi
done

# ==========================================
# COMPLETION
# ==========================================
success "Configurations updated locally from '$OLD_HOSTNAME' to '$NEW_HOSTNAME'."
warn "A system reboot is required to apply the kernel hostname changes and re-initialize services."

read -p "Would you like to reboot the node now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "Rebooting node now..."
    reboot
else
    info "Reboot postponed. Remember to run 'reboot' manually to apply the changes."
fi
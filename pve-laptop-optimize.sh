#!/usr/bin/env bash
#
# pve-laptop-optimize - Optimize Proxmox VE running on laptops
# Low Power & High Endurance Configuration Script
#

set -euo pipefail

# --- CONFIGURATION VARIABLES & PATHS ---
LOGIND_CONF="/etc/systemd/logind.conf"
GRUB_CONF="/etc/default/grub"
CMDLINE_CONF="/etc/kernel/cmdline"
RRD_CONF="/etc/default/rrdcached"
FSTAB="/etc/fstab"
SYSCTL_CONF="/etc/sysctl.conf"
POWER_SERVICE="/etc/systemd/system/powertop.service"

# --- HELPER FUNCTIONS ---

# Print a formatted informational message
log_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

# Print a formatted success message
log_success() {
    echo -e "\e[32m[OK]\e[0m $1"
}

# Print a formatted warning message
log_warn() {
    echo -e "\e[33m[WARN]\e[0m $1"
}

# Print a formatted error message and exit
log_error() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
    exit 1
}

# Show usage / help menu
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Optimize Proxmox VE for running on old laptops by lowering energy consumption
and reducing consumer SSD/NVMe wear.

Options:
  -l, --lid          Prevent laptop from suspending/sleeping when the lid is closed.
  -b, --blank        Blank the built-in screen backlight after 60s of console inactivity.
  -c, --cpu          Switch CPU governor to powersave, cap Intel P-states, auto-tune Powertop.
  -e, --endurance    Minimize disk writes (disable cluster services, rrdcached journal, route logs to tmpfs).
  -s, --swappiness   Reduce kernel vm.swappiness to 10 to protect disk from aggressive page swaps.
  -a, --all          Apply ALL of the above optimizations at once.
  -r, --revert       Modify behavior to REVERT/RESTORE defaults for specified flags.
                     (e.g., "$0 -r -l" reverts only the lid settings).
  -h, --help         Show this help message.

Examples:
  # Apply everything
  sudo $0 --all

  # Revert only CPU and display blanking
  sudo $0 --revert --cpu --blank
EOF
}

# --- SANITY CHECKS ---

# Ensure the script is run with superuser privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (sudo)."
    fi
}

# Verify the host is actually running Proxmox VE
check_proxmox() {
    if [[ ! -f /etc/pve/local/pve-ssl.key ]] && [[ ! -d /etc/pve ]]; then
        log_warn "This host does not appear to be a Proxmox VE node. Proceed with caution."
    fi
}

# --- OPTIMIZATION / REVERT LOGIC ---

# 1. Lid Close Behavior
manage_lid() {
    local revert=$1
    if [ "$revert" = "false" ]; then
        log_info "Configuring lid close actions to 'ignore'..."
        
        # Ensure target directories/files exist before substituting
        mkdir -p "$(dirname "$LOGIND_CONF")"
        touch "$LOGIND_CONF"

        # Backup current configuration
        cp "$LOGIND_CONF" "${LOGIND_CONF}.bak"

        # Explicitly strip matching lines and rewrite the desired settings
        sed -i '/^[#]*HandleLidSwitch=/d' "$LOGIND_CONF"
        sed -i '/^[#]*HandleLidSwitchDocked=/d' "$LOGIND_CONF"
        sed -i '/^[#]*HandleLidSwitchExternalPower=/d' "$LOGIND_CONF"
        
        # Insert inside [Login] section or append to end
        if grep -q "^\[Login\]" "$LOGIND_CONF"; then
            sed -i '/^\[Login\]/a HandleLidSwitch=ignore\nHandleLidSwitchDocked=ignore\nHandleLidSwitchExternalPower=ignore' "$LOGIND_CONF"
        else
            printf "\n[Login]\nHandleLidSwitch=ignore\nHandleLidSwitchDocked=ignore\nHandleLidSwitchExternalPower=ignore\n" >> "$LOGIND_CONF"
        fi

        systemctl restart systemd-logind
        log_success "Lid close optimizations applied. Laptop will not suspend when lid is shut."
    else
        log_info "Reverting lid close settings to Debian/Proxmox defaults..."
        if [ -f "${LOGIND_CONF}.bak" ]; then
            mv "${LOGIND_CONF}.bak" "$LOGIND_CONF"
        else
            # Delete our customized lines if no backup is found
            sed -i '/^HandleLidSwitch=/d' "$LOGIND_CONF"
            sed -i '/^HandleLidSwitchDocked=/d' "$LOGIND_CONF"
            sed -i '/^HandleLidSwitchExternalPower=/d' "$LOGIND_CONF"
        fi
        systemctl restart systemd-logind
        log_success "Lid close settings restored to defaults."
    fi
}

# 2. Console Screen Blanking
manage_blanking() {
    local revert=$1
    
    # Proxmox can boot via systemd-boot (typical for ZFS) or traditional GRUB
    local is_efi_systemd_boot=false
    if [ -d /sys/firmware/efi/efivars/ ] && [ -f "$CMDLINE_CONF" ]; then
        is_efi_systemd_boot=true
    fi

    if [ "$revert" = "false" ]; then
        log_info "Configuring screen blanking (consoleblank=60)..."
        
        if [ "$is_efi_systemd_boot" = "true" ]; then
            log_info "Detected systemd-boot environment."
            if ! grep -q "consoleblank=60" "$CMDLINE_CONF"; then
                # Keep everything on a single line for systemd-boot compat
                cp "$CMDLINE_CONF" "${CMDLINE_CONF}.bak"
                sed -i 's/$/ consoleblank=60/' "$CMDLINE_CONF"
                proxmox-boot-tool refresh
            fi
        else
            log_info "Detected GRUB bootloader environment."
            if [ -f "$GRUB_CONF" ]; then
                cp "$GRUB_CONF" "${GRUB_CONF}.bak"
                # Safely append consoleblank without duplicating
                if ! grep -q "consoleblank=60" "$GRUB_CONF"; then
                    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="consoleblank=60 /' "$GRUB_CONF"
                    update-grub
                fi
            fi
        fi
        log_success "Screen blanking set. Console screen will power down after 1 minute of inactivity."
    else
        log_info "Reverting screen blanking parameters..."
        if [ "$is_efi_systemd_boot" = "true" ]; then
            if [ -f "${CMDLINE_CONF}.bak" ]; then
                mv "${CMDLINE_CONF}.bak" "$CMDLINE_CONF"
            else
                sed -i 's/ consoleblank=60//g' "$CMDLINE_CONF"
            fi
            proxmox-boot-tool refresh
        else
            if [ -f "${GRUB_CONF}.bak" ]; then
                mv "${GRUB_CONF}.bak" "$GRUB_CONF"
            else
                sed -i 's/consoleblank=60 //g' "$GRUB_CONF"
            fi
            update-grub
        fi
        log_success "Boot loader options reverted."
    fi
}

# 3. CPU Power and Powertop
manage_cpu() {
    local revert=$1
    if [ "$revert" = "false" ]; then
        log_info "Installing cpufrequtils, cpupower and powertop..."
        apt-get update -qq && apt-get install -y -qq cpufrequtils linux-cpupower powertop > /dev/null

        log_info "Setting CPU scale governor to 'powersave'..."
        if command -v cpupower &> /dev/null; then
            cpupower frequency-set -g powersave > /dev/null || log_warn "Could not switch CPU governor. Hardware may lock governor."
        fi

        # Check for modern Intel P-State scaling capabilities
        if [ -d "/sys/devices/system/cpu/intel_pstate" ]; then
            log_info "Optimizing Intel P-States for balance and thermals..."
            echo "70" > /sys/devices/system/cpu/intel_pstate/max_perf_pct || true
            for epp in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
                [ -f "$epp" ] && echo "balance_power" > "$epp" || true
            done
        fi

        # Setup persistent systemd service for Powertop autotune
        log_info "Setting up auto-tuning Powertop systemd service..."
        cat << EOF > "$POWER_SERVICE"
[Unit]
Description=PowerTOP auto-tuning on boot
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/powertop --auto-tune
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable --now powertop.service
        log_success "CPU Scaling configured to powersave and Powertop tuner activated."
    else
        log_info "Reverting CPU settings & removing Powertop service..."
        
        # Stop and remove the service
        if [ -f "$POWER_SERVICE" ]; then
            systemctl disable --now powertop.service || true
            rm -f "$POWER_SERVICE"
            systemctl daemon-reload
        fi

        # Re-set scaling driver to performance default
        if command -v cpupower &> /dev/null; then
            cpupower frequency-set -g performance > /dev/null || true
        fi

        if [ -d "/sys/devices/system/cpu/intel_pstate" ]; then
            echo "100" > /sys/devices/system/cpu/intel_pstate/max_perf_pct || true
            for epp in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
                [ -f "$epp" ] && echo "balance_performance" > "$epp" || true
            done
        fi
        log_success "CPU scaling restored to maximum performance targets."
    fi
}

# 4. Minimizing Disk Endurance Wear
manage_endurance() {
    local revert=$1
    if [ "$revert" = "false" ]; then
        log_info "Disabling high-write frequency Proxmox services (Clustering & HA)..."
        # Stop high IOPS clustering elements on standalone laptop setups
        systemctl stop pve-ha-lrm pve-ha-crm corosync pvesr.timer || true
        systemctl disable pve-ha-lrm pve-ha-crm corosync pvesr.timer || true

        # Tame metric-logging intervals on rrdcached
        if [ -f "$RRD_CONF" ]; then
            log_info "Configuring rrdcached metrics to load into volatile RAM..."
            cp "$RRD_CONF" "${RRD_CONF}.bak"
            sed -i 's/^JOURNAL_PATH=/#JOURNAL_PATH=/g' "$RRD_CONF"
            systemctl restart rrdcached || true
        fi

        # Map heavy log directories to dynamic RAM
        log_info "Relocating active logs to RAM via tmpfs (/etc/fstab)..."
        cp "$FSTAB" "${FSTAB}.bak"
        
        # Add tmpfs mappings safely without writing duplicate entries
        local added_entries=false
        for mount in "/tmp" "/var/log/pveproxy" "/var/lib/rrdcached"; do
            if ! grep -q "$mount" "$FSTAB"; then
                if [ "$mount" = "/tmp" ]; then
                    echo "tmpfs /tmp tmpfs defaults 0 0" >> "$FSTAB"
                elif [ "$mount" = "/var/log/pveproxy" ]; then
                    echo "tmpfs /var/log/pveproxy tmpfs mode=1775,uid=33,gid=33 0 0" >> "$FSTAB"
                elif [ "$mount" = "/var/lib/rrdcached" ]; then
                    echo "tmpfs /var/lib/rrdcached tmpfs mode=1775 0 0" >> "$FSTAB"
                fi
                added_entries=true
            fi
        done

        if [ "$added_entries" = "true" ]; then
            # Remount fstab to load the temporary file paths
            mount -a || log_warn "Some RAM disks could not be mounted immediately. Reboot recommended."
        fi
        log_success "SSD endurance mitigations applied (RAM log filesystems active)."
    else
        log_info "Restoring standard system services and disk journaling..."
        
        # Enable metrics caching and local service daemons
        systemctl enable pve-ha-lrm pve-ha-crm corosync pvesr.timer || true
        systemctl start pve-ha-lrm pve-ha-crm corosync pvesr.timer || true

        if [ -f "${RRD_CONF}.bak" ]; then
            mv "${RRD_CONF}.bak" "$RRD_CONF"
            systemctl restart rrdcached || true
        fi

        if [ -f "${FSTAB}.bak" ]; then
            mv "${FSTAB}.bak" "$FSTAB"
            log_info "Fstab configuration restored. Reboot required to safely dismount RAM disks."
        fi
        log_success "Disk optimizations reverted to PVE standards."
    fi
}

# 5. Linux Kernel Swappiness Configuration
manage_swappiness() {
    local revert=$1
    if [ "$revert" = "false" ]; then
        log_info "Limiting Linux swap aggressiveness (swappiness = 10)..."
        cp "$SYSCTL_CONF" "${SYSCTL_CONF}.bak"
        
        # Delete pre-existing settings to avoid conflicts
        sed -i '/^vm.swappiness/d' "$SYSCTL_CONF"
        echo "vm.swappiness = 10" >> "$SYSCTL_CONF"
        sysctl -p "$SYSCTL_CONF" > /dev/null
        log_success "Swappiness value configured successfully."
    else
        log_info "Reverting swappiness setting to kernel defaults..."
        if [ -f "${SYSCTL_CONF}.bak" ]; then
            mv "${SYSCTL_CONF}.bak" "$SYSCTL_CONF"
        else
            sed -i '/^vm.swappiness/d' "$SYSCTL_CONF"
        fi
        sysctl -p "$SYSCTL_CONF" > /dev/null
        log_success "Swappiness reverted."
    fi
}

# --- MAIN EXECUTION PIPELINE ---

# Parse command line inputs
REVERT_MODE="false"
LID_FLAG=false
BLANK_FLAG=false
CPU_FLAG=false
ENDURANCE_FLAG=false
SWAP_FLAG=false

# If no parameters passed, present the help screen
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

# Parsing argument tags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -r|--revert)
            REVERT_MODE="true"
            shift
            ;;
        -l|--lid)
            LID_FLAG=true
            shift
            ;;
        -b|--blank)
            BLANK_FLAG=true
            shift
            ;;
        -c|--cpu)
            CPU_FLAG=true
            shift
            ;;
        -e|--endurance)
            ENDURANCE_FLAG=true
            shift
            ;;
        -s|--swappiness)
            SWAP_FLAG=true
            shift
            ;;
        -a|--all)
            LID_FLAG=true
            BLANK_FLAG=true
            CPU_FLAG=true
            ENDURANCE_FLAG=true
            SWAP_FLAG=true
            shift
            ;;
        *)
            log_error "Unknown option: $1. Run with --help for options."
            ;;
    esac
done

# Run host checks before making changes
check_root
check_proxmox

# Process selected parameters
if [ "$LID_FLAG" = true ]; then
    manage_lid "$REVERT_MODE"
fi

if [ "$BLANK_FLAG" = true ]; then
    manage_blanking "$REVERT_MODE"
fi

if [ "$CPU_FLAG" = true ]; then
    manage_cpu "$REVERT_MODE"
fi

if [ "$ENDURANCE_FLAG" = true ]; then
    manage_endurance "$REVERT_MODE"
fi

if [ "$SWAP_FLAG" = true ]; then
    manage_swappiness "$REVERT_MODE"
fi

log_success "Task execution complete. Reboot your laptop to apply all kernel configurations cleanly."
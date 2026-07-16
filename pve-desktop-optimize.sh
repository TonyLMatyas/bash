#!/usr/bin/env bash
#
# pve-desktop-optimize - Optimize Proxmox VE running on Desktops/Tower PCs
# Low Power & High Endurance Configuration Script for Desktop Hardware
#

set -euo pipefail

# --- CONFIGURATION PATHS ---
GRUB_CONF="/etc/default/grub"
CMDLINE_CONF="/etc/kernel/cmdline"
RRD_CONF="/etc/default/rrdcached"
FSTAB="/etc/fstab"
SYSCTL_CONF="/etc/sysctl.conf"
GPU_BLACKLIST="/etc/modprobe.d/pve-power-gpu-blacklist.conf"
ALPM_CONF="/etc/udev/rules.d/99-sata-alpm.rules"

# --- HELPER FUNCTIONS ---

log_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

log_success() {
    echo -e "\e[32m[OK]\e[0m $1"
}

log_warn() {
    echo -e "\e[33m[WARN]\e[0m $1"
}

log_error() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
    exit 1
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Optimize desktop/tower PC hardware running Proxmox VE for maximum power efficiency
and minimal consumer SSD/NVMe wear.

Options:
  -g, --gpu          Isolate & disable unused discrete GPUs (NVIDIA/AMD) to let them sleep.
  -p, --pcie-aspm    Force PCIe ASPM (Active State Power Management) and SATA ALPM to enable deep C-States.
  -c, --cpu          Tune CPU governor to powersave and balance-power scaling.
  -e, --endurance    Reduce disk writes (disable cluster/HA services, route log files to tmpfs).
  -s, --swappiness   Lower vm.swappiness to 10 to limit excessive drive writes.
  -a, --all          Apply ALL desktop optimizations at once.
  -r, --revert       Revert/Restore defaults for any option flags passed.
                     (e.g., "$0 -r -g" restores your GPU drivers).
  -h, --help         Show this help menu.

Examples:
  # Apply all savings to your desktop node
  sudo $0 --all

  # Revert GPU isolation only
  sudo $0 --revert --gpu
EOF
}

# --- SANITY CHECKS ---

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (sudo)."
    fi
}

check_proxmox() {
    if [[ ! -f /etc/pve/local/pve-ssl.key ]] && [[ ! -d /etc/pve ]]; then
        log_warn "This host does not appear to be a Proxmox VE node. Proceeding anyway..."
    fi
}

# Helper to check which bootloader PVE is running on
detect_bootloader() {
    if [ -d /sys/firmware/efi/efivars/ ] && [ -f "$CMDLINE_CONF" ]; then
        echo "systemd-boot"
    else
        echo "grub"
    fi
}

# --- OPTIMIZATION / REVERT LOGIC ---

# 1. Discrete GPU Sleep Configuration
manage_gpu() {
    local revert=$1
    
    # Check if a dedicated GPU is actually in the system
    local has_gpu=false
    if lspci | grep -qiE 'vga|3d|display' | grep -qiE 'nvidia|amd|ati'; then
        has_gpu=true
    fi

    if [ "$revert" = "false" ]; then
        if [ "$has_gpu" = "false" ]; then
            log_info "No discrete NVIDIA/AMD GPU detected. Skipping GPU power optimization."
            return 0
        fi

        log_info "Dedicated GPU detected. Blacklisting drivers to let GPU transition to low-power D3 state..."
        
        # Blacklist proprietary and open-source drivers so the kernel drops the card into idle/suspended power states
        cat << EOF > "$GPU_BLACKLIST"
# Disabled to allow discrete GPU to drop to lowest power state
blacklist nvidia
blacklist nvidia-drm
blacklist nvidia-modeset
blacklist nvidia-uvm
blacklist nouveau
blacklist radeon
blacklist amdgpu
EOF
        log_success "GPU drivers blacklisted. The GPU will sit uninitialized in a low-power state on next reboot."
    else
        log_info "Reverting GPU driver blacklist..."
        if [ -f "$GPU_BLACKLIST" ]; then
            rm -f "$GPU_BLACKLIST"
            log_success "GPU drivers restored. They will load normally upon next reboot."
        else
            log_info "No custom GPU blacklist found to revert."
        fi
    fi
}

# 2. PCIe ASPM & SATA ALPM link state tuning
manage_pcie_sata() {
    local revert=$1
    local bootloader
    bootloader=$(detect_bootloader)

    if [ "$revert" = "false" ]; then
        log_info "Enabling PCIe ASPM (Active State Power Management) and SATA ALPM..."

        # 2a. Enable PCIe power management via kernel parameters (forces CPU C-States)
        if [ "$bootloader" = "systemd-boot" ]; then
            log_info "Using systemd-boot. Amending $CMDLINE_CONF..."
            if ! grep -q "pcie_aspm=force" "$CMDLINE_CONF"; then
                cp "$CMDLINE_CONF" "${CMDLINE_CONF}.bak"
                sed -i 's/$/ pcie_aspm=force pcie_aspm.policy=powersupersave/' "$CMDLINE_CONF"
                proxmox-boot-tool refresh
            fi
        else
            log_info "Using GRUB. Amending $GRUB_CONF..."
            if [ -f "$GRUB_CONF" ]; then
                cp "$GRUB_CONF" "${GRUB_CONF}.bak"
                if ! grep -q "pcie_aspm=force" "$GRUB_CONF"; then
                    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="pcie_aspm=force pcie_aspm.policy=powersupersave /' "$GRUB_CONF"
                    update-grub
                fi
            fi
        fi

        # 2b. Enable Aggressive Link Power Management (ALPM) for SATA controllers
        log_info "Creating udev rule for SATA ALPM (min_power)..."
        cat << 'EOF' > "$ALPM_CONF"
# Force SATA controllers to use Aggressive Link Power Management
ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}="min_power"
EOF
        # Apply udev immediately
        udevadm control --reload-rules && udevadm trigger || true
        log_success "PCIe ASPM and SATA ALPM have been configured."
    else
        log_info "Reverting PCIe ASPM and SATA ALPM optimizations..."
        
        # Revert Kernel commands
        if [ "$bootloader" = "systemd-boot" ]; then
            if [ -f "${CMDLINE_CONF}.bak" ]; then
                mv "${CMDLINE_CONF}.bak" "$CMDLINE_CONF"
            else
                sed -i 's/ pcie_aspm=force pcie_aspm.policy=powersupersave//g' "$CMDLINE_CONF"
            fi
            proxmox-boot-tool refresh
        else
            if [ -f "${GRUB_CONF}.bak" ]; then
                mv "${GRUB_CONF}.bak" "$GRUB_CONF"
            else
                sed -i 's/pcie_aspm=force pcie_aspm.policy=powersupersave //g' "$GRUB_CONF"
            fi
            update-grub
        fi

        # Remove SATA ALPM Udev config
        if [ -f "$ALPM_CONF" ]; then
            rm -f "$ALPM_CONF"
            udevadm control --reload-rules && udevadm trigger || true
        fi
        log_success "PCIe and SATA link management reverted to system defaults."
    fi
}

# 3. CPU Power Settings
manage_cpu() {
    local revert=$1
    if [ "$revert" = "false" ]; then
        log_info "Installing CPU core utilities..."
        apt-get update -qq && apt-get install -y -qq cpufrequtils linux-cpupower > /dev/null

        log_info "Setting active CPU scale governor to 'powersave'..."
        if command -v cpupower &> /dev/null; then
            cpupower frequency-set -g powersave > /dev/null || log_warn "CPU governor lock experienced."
        fi

        # Limit maximum performance scaling state slightly to prevent excessive thermal bursts on old desktop fans
        if [ -d "/sys/devices/system/cpu/intel_pstate" ]; then
            log_info "Configuring Intel P-State scaling ceilings (80% Cap)..."
            echo "80" > /sys/devices/system/cpu/intel_pstate/max_perf_pct || true
            for epp in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
                [ -f "$epp" ] && echo "balance_power" > "$epp" || true
            done
        fi
        log_success "CPU governors set to balance-power levels."
    else
        log_info "Reverting CPU settings..."
        if command -v cpupower &> /dev/null; then
            cpupower frequency-set -g performance > /dev/null || true
        fi

        if [ -d "/sys/devices/system/cpu/intel_pstate" ]; then
            echo "100" > /sys/devices/system/cpu/intel_pstate/max_perf_pct || true
            for epp in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
                [ -f "$epp" ] && echo "balance_performance" > "$epp" || true
            done
        fi
        log_success "CPU scaling profiles restored to native performance profiles."
    fi
}

# 4. Storage Wear Mitigations
manage_endurance() {
    local revert=$1
    if [ "$revert" = "false" ]; then
        log_info "Disabling cluster/HA synchronization components..."
        systemctl stop pve-ha-lrm pve-ha-crm corosync pvesr.timer || true
        systemctl disable pve-ha-lrm pve-ha-crm corosync pvesr.timer || true

        # Restructure graph metric-logging frequency
        if [ -f "$RRD_CONF" ]; then
            log_info "Configuring rrdcached to write metric journals directly to RAM..."
            cp "$RRD_CONF" "${RRD_CONF}.bak"
            sed -i 's/^JOURNAL_PATH=/#JOURNAL_PATH=/g' "$RRD_CONF"
            systemctl restart rrdcached || true
        fi

        # Mount ephemeral logs to RAM
        log_info "Configuring tmpfs RAM disks in /etc/fstab..."
        cp "$FSTAB" "${FSTAB}.bak"
        
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
            mount -a || log_warn "Unmounted RAM disks may require a reboot to finalize."
        fi
        log_success "Storage write mitigations applied successfully."
    else
        log_info "Reinstating classic storage logging paths..."
        
        systemctl enable pve-ha-lrm pve-ha-crm corosync pvesr.timer || true
        systemctl start pve-ha-lrm pve-ha-crm corosync pvesr.timer || true

        if [ -f "${RRD_CONF}.bak" ]; then
            mv "${RRD_CONF}.bak" "$RRD_CONF"
            systemctl restart rrdcached || true
        fi

        if [ -f "${FSTAB}.bak" ]; then
            mv "${FSTAB}.bak" "$FSTAB"
            log_info "Fstab original state restored. Please reboot to unmount any remaining RAM-disks."
        fi
        log_success "Metric systems and default drive logging profiles restored."
    fi
}

# 5. Swappiness Tuning
manage_swappiness() {
    local revert=$1
    if [ "$revert" = "false" ]; then
        log_info "Limiting Linux swappiness behavior (swappiness = 10)..."
        cp "$SYSCTL_CONF" "${SYSCTL_CONF}.bak"
        
        sed -i '/^vm.swappiness/d' "$SYSCTL_CONF"
        echo "vm.swappiness = 10" >> "$SYSCTL_CONF"
        sysctl -p "$SYSCTL_CONF" > /dev/null
        log_success "Swappiness value configured."
    else
        log_info "Reverting swappiness setting..."
        if [ -f "${SYSCTL_CONF}.bak" ]; then
            mv "${SYSCTL_CONF}.bak" "$SYSCTL_CONF"
        else
            sed -i '/^vm.swappiness/d' "$SYSCTL_CONF"
        fi
        sysctl -p "$SYSCTL_CONF" > /dev/null
        log_success "Swappiness reverted."
    fi
}

# --- MAIN ENGINE ---

REVERT_MODE="false"
GPU_FLAG=false
PCIE_FLAG=false
CPU_FLAG=false
ENDURANCE_FLAG=false
SWAP_FLAG=false

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

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
        -g|--gpu)
            GPU_FLAG=true
            shift
            ;;
        -p|--pcie-aspm)
            PCIE_FLAG=true
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
            GPU_FLAG=true
            PCIE_FLAG=true
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

check_root
check_proxmox

if [ "$GPU_FLAG" = true ]; then
    manage_gpu "$REVERT_MODE"
fi

if [ "$PCIE_FLAG" = true ]; then
    manage_pcie_sata "$REVERT_MODE"
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

log_success "Desktop optimization pass completed. A reboot is recommended to initialize the modified kernel configurations cleanly."
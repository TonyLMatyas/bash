#!/usr/bin/env bash

LOG_FILE="/root/logs/nvidiacount.log"

# Ensure the target directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Temporary file to capture lspci section output
TEMP_OUT=$(mktemp)

# Filter lspci output for NVIDIA VGA/3D/Display controllers and extract serial numbers
lspci -vnn | awk '
    # Detect NVIDIA controller headers (VGA, 3D, Display)
    /^[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9a-fA-F] (VGA compatible controller|3D controller|Display controller).*NVIDIA/ {
        in_nvidia=1
        header=$0
        serial=""
        next
    }
    # If in an NVIDIA block and a new PCI device begins, print previous buffered data
    /^[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9a-fA-F] / {
        if (in_nvidia) {
            print header
            if (serial != "") print serial
            in_nvidia=0
        }
    }
    # Capture Device Serial Number capability line if present
    in_nvidia && /Capabilities:.*Device Serial Number/ {
        serial=$0
    }
    # Handle case where the last device in lspci is an NVIDIA GPU
    END {
        if (in_nvidia) {
            print header
            if (serial != "") print serial
        }
    }
' > "$TEMP_OUT"

# Count the detected GPUs (matching initial PCI address lines)
GPU_COUNT=$(grep -c '^[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}\.[0-9a-fA-F]' "$TEMP_OUT")

# Append output to log file matching specified format
{
    echo ""
    date
    echo "GPU COUNT: ${GPU_COUNT}"
    if [ "${GPU_COUNT}" -gt 0 ]; then
        cat "$TEMP_OUT"
    fi
} >> "$LOG_FILE"

# Clean up
rm -f "$TEMP_OUT"

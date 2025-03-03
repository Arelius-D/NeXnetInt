#!/bin/bash

SCRIPT_NAME="dependencies.sh"
VERSION="0.13"
CALLING_SCRIPT="$SCRIPT_NAME"
SCRIPT_VERSION="$VERSION"
LOG_DIR="/var/log/nexnetint"

log_message() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME v$VERSION] $message" | sudo tee -a "$LOG_DIR/nexnetint.log" >/dev/null
    echo "$message"
}

TOOLS=("ip" "nmcli" "rfkill" "ethtool" "ifconfig")

log_message "🏷️  Dependency check..."
for tool in "${TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        log_message "[✓] $tool $(which "$tool")"
    else
        log_message "[✗] $tool Missing... Installing ↻"
        sudo apt update -qq >/dev/null 2>&1
        sudo apt install -y "$tool" >/dev/null 2>&1
        if command -v "$tool" >/dev/null 2>&1; then
            log_message "[✓] $tool $(which "$tool")"
        fi
    fi
done
#!/bin/bash

SCRIPT_NAME="management.sh"
VERSION="0.10"
CALLING_SCRIPT="$SCRIPT_NAME"
SCRIPT_VERSION="$VERSION"
SYSTEM_DIR="/usr/local/lib/nexnetint"
DATA_DIR="$SYSTEM_DIR/data"
LOG_DIR="/var/log/nexnetint"

log_message() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME v$VERSION] $message" | sudo tee -a "$LOG_DIR/nexnetint.log" >/dev/null
    echo "$message"
}

TOOLS=("nmcli" "networkctl" "ifup" "netplan")

check_main_manager() {
    local tool="$1"
    case "$tool" in
        nmcli)
            if sudo nmcli -t -f RUNNING general | grep -q "running"; then
                if sudo nmcli dev status | grep -q "connected"; then
                    echo "active"
                else
                    echo "running"
                fi
            else
                echo "stopped"
            fi
            ;;
        networkctl)
            if sudo systemctl is-active systemd-networkd 2>/dev/null | grep -q "active"; then
                if sudo networkctl status 2>/dev/null | grep -q "State:.*\(routable\|configured\)"; then
                    echo "active"
                else
                    echo "running"
                fi
            else
                echo "stopped"
            fi
            ;;
        ifup)
            if [ -f "/etc/network/interfaces" ] && grep -q "^auto" /etc/network/interfaces; then
                if ip link show | grep -q "UP" && grep -q "$(ip link show | grep 'UP' | awk '{print $2}' | tr -d ':')" /etc/network/interfaces; then
                    echo "active"
                else
                    echo "running"
                fi
            else
                echo "stopped"
            fi
            ;;
        netplan)
            if [ -d "/etc/netplan" ] && ls /etc/netplan/*.yaml >/dev/null 2>&1; then
                if grep -r "renderer: NetworkManager" /etc/netplan/*.yaml >/dev/null 2>&1 && sudo nmcli -t -f RUNNING general | grep -q "running"; then
                    echo "active"
                elif grep -r "renderer: networkd" /etc/netplan/*.yaml >/dev/null 2>&1 && sudo systemctl is-active systemd-networkd 2>/dev/null | grep -q "active"; then
                    echo "active"
                else
                    echo "running"
                fi
            else
                echo "stopped"
            fi
            ;;
    esac
}

main_manager=""
for tool in "${TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        state=$(check_main_manager "$tool")
        if [ "$state" = "active" ] && [ -z "$main_manager" ]; then
            main_manager="$tool"
        fi
    fi
done

if [ -n "$main_manager" ]; then
    case "$main_manager" in
        nmcli) export MAIN_MANAGER="NetworkManager" ;;
        networkctl) export MAIN_MANAGER="systemd-networkd" ;;
        ifup) export MAIN_MANAGER="ifupdown" ;;
        netplan) export MAIN_MANAGER="netplan" ;;
    esac
else
    export MAIN_MANAGER="none"
fi

echo "$MAIN_MANAGER" | sudo tee "$DATA_DIR/main_network_manager.txt" >/dev/null

log_message "🛰️  Network Management check..."
for tool in "${TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        state=$(check_main_manager "$tool")
        tool_name=""
        symbol=""
        case "$tool" in
            nmcli) tool_name="NetworkManager" ;;
            networkctl) tool_name="systemd-networkd" ;;
            ifup) tool_name="ifupdown" ;;
            netplan) tool_name="netplan" ;;
        esac
        if [ "$tool" = "$main_manager" ]; then
            symbol="[✓]"
        elif [ "$state" = "running" ]; then
            symbol="[↻]"
        else
            symbol="[✗]"
        fi
        log_message "$symbol $tool_name $(which "$tool")"
    fi
done
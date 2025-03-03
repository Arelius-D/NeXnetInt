#!/bin/bash

SCRIPT_NAME="interface.sh"
VERSION="0.46"
CALLING_SCRIPT="$SCRIPT_NAME"
SCRIPT_VERSION="$VERSION"
SYSTEM_DIR="/usr/local/lib/nexnetint"
DATA_DIR="$SYSTEM_DIR/data"
ASSETS_DIR="$SYSTEM_DIR/assets"
LOG_DIR="/var/log/nexnetint"

log_message() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME v$VERSION] $message" | sudo tee -a "$LOG_DIR/nexnetint.log" >/dev/null
    echo "$message"
}

VIEW_ONLY=false
if [ "$1" = "--view" ]; then
    VIEW_ONLY=true
fi

interfaces=$(ls /sys/class/net/ | grep -vE 'lo|veth|docker|br-|tun|tap|virbr|ovs|vnet|wg')
if [ -z "$interfaces" ]; then
    log_message "[✗] No physical interfaces detected."
    exit 1
fi

main_iface=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')
if [ -z "$main_iface" ]; then
    main_iface=$(echo "$interfaces" | head -n 1)
fi

if [ -z "$main_iface" ]; then
    log_message "[✗] No main interface detected."
    exit 1
fi

export CURRENT_INTERFACE="$main_iface"
echo "$CURRENT_INTERFACE" | sudo tee "$DATA_DIR/current_network_interface.txt" >/dev/null

log_message "📡  Interface detection..."
MAIN_MANAGER=$(sudo cat "$DATA_DIR/main_network_manager.txt" 2>/dev/null || echo "none")

for iface in $interfaces; do
    if [ -d "/sys/class/net/$iface/device" ]; then
        symbol=$([ "$iface" = "$main_iface" ] && echo " 🌐" || echo "")
        state=$(ip -br link show "$iface" 2>/dev/null | awk '{print $2}' || echo "DOWN")
        state=$([ "$state" = "UP" ] && echo "Up" || echo "Down")
        mac_addr=$(sudo cat "/sys/class/net/$iface/address" 2>/dev/null || echo "N/A")
        status=$([ "$state" = "Up" ] && echo "Initiated" || echo "Not Initiated")
        ip_addr=$(ip -br addr show "$iface" 2>/dev/null | awk '{print $3}' | grep -vE "^fe80" | head -n 1 || echo "N/A")
        # ipv6_addr=$(ip -br addr show "$iface" 2>/dev/null | awk '{print $3}' | grep "^fe80" | head -n 1 || echo "N/A")
        speed=$(ethtool "$iface" 2>/dev/null | grep -E "^[[:space:]]*Speed:" | awk '{print $2}' || echo "N/A")
        if [ "$state" = "Down" ]; then
            carrier_status="Down"
        else
            if [[ "$iface" =~ ^wlan.* ]]; then
                carrier_status="Active"
            else
                carrier_status=$(ip -br link show "$iface" 2>/dev/null | grep -q "UP" && echo "Active" || echo "Inactive")
            fi
        fi
        # mtu=$(cat "/sys/class/net/$iface/mtu" 2>/dev/null || echo "N/A")
        # bus=$(ls -l /sys/class/net/"$iface"/device 2>/dev/null | awk '/pci/ {print "PCIe"; exit} /usb/ {print "USB"; exit} {print "Unknown"}')
        # driver=$(ethtool -i "$iface" 2>/dev/null | grep "^driver:" | awk '{print $2}' || echo "N/A")
        # ... (other commented lines remain as-is)

        log_message "$iface /sys/class/net/$iface$symbol"
        log_message "  IPv4 Address: $ip_addr"
        # log_message "  IPv6 Address: $ipv6_addr"
        log_message "  MAC Address: $mac_addr"
        log_message "  State: $state"
        log_message "  Speed: $speed"
        log_message "  Status: $status"
        log_message "  Link: $carrier_status"
        # log_message "    MTU: $mtu"
        # log_message "    Bus: $bus"
        # log_message "    Driver: $driver"
    fi
done

if [ "$VIEW_ONLY" = true ]; then
    exit 0
fi

log_message "Choose an option:"
log_message "P - Set Interface Priority"
log_message "Q - Quit"
echo -n "Enter your choice: "
read choice

case "$choice" in
    [Pp])
        index=1
        declare -A iface_map
        for iface in $interfaces; do
            if [ -d "/sys/class/net/$iface/device" ]; then
                symbol=$([ "$iface" = "$main_iface" ] && echo " 🌐 (default)" || echo "")
                log_message "$index. $iface$symbol"
                iface_map[$index]="$iface"
                ((index++))
            fi
        done
        printf "Select Primary Interface (1-%d, C to cancel): " "$((index-1))"
        read primary_choice
        if [ "$primary_choice" = "c" ] || [ "$primary_choice" = "C" ]; then
            log_message "Operation cancelled."
            exit 0
        fi
        if ! [[ "$primary_choice" =~ ^[0-9]+$ ]] || [ "$primary_choice" -lt 1 ] || [ "$primary_choice" -ge "$index" ]; then
            log_message "[✗] Invalid choice for Primary Interface."
            exit 1
        fi
        primary_iface="${iface_map[$primary_choice]}"
        primary_mac=$(sudo cat "/sys/class/net/$primary_iface/address" 2>/dev/null || echo "N/A")
        index=1
        declare -A iface_map_secondary
        for iface in $interfaces; do
            if [ -d "/sys/class/net/$iface/device" ] && [ "$iface" != "$primary_iface" ]; then
                log_message "$index. $iface"
                iface_map_secondary[$index]="$iface"
                ((index++))
            fi
        done
        if [ $index -eq 1 ]; then
            log_message "[✗] No secondary interfaces available."
            secondary_iface="none"
            secondary_mac="none"
        else
            printf "Select Secondary Interface (1-%d, C to cancel): " "$((index-1))"
            read secondary_choice
            if [ "$secondary_choice" = "c" ] || [ "$secondary_choice" = "C" ]; then
                log_message "Operation cancelled."
                exit 0
            fi
            if ! [[ "$secondary_choice" =~ ^[0-9]+$ ]] || [ "$secondary_choice" -lt 1 ] || [ "$secondary_choice" -ge "$index" ]; then
                log_message "[✗] Invalid choice for Secondary Interface."
                exit 1
            fi
            secondary_iface="${iface_map_secondary[$secondary_choice]}"
            secondary_mac=$(sudo cat "/sys/class/net/$secondary_iface/address" 2>/dev/null || echo "none")
        fi
        {
            if [ -n "$primary_mac" ] && [ "$primary_mac" != "N/A" ]; then
                echo "PRIMARY_MAC=$primary_mac"
                echo "PRIMARY_NAME=$primary_iface"
            else
                echo "PRIMARY_MAC=N/A"
                echo "PRIMARY_NAME=N/A"
            fi
            if [ -n "$secondary_mac" ] && [ "$secondary_mac" != "none" ]; then
                echo "SECONDARY_MAC=$secondary_mac"
                echo "SECONDARY_NAME=$secondary_iface"
            else
                echo "SECONDARY_MAC=none"
                echo "SECONDARY_NAME=none"
            fi
        } | sudo tee "$ASSETS_DIR/selected_interfaces.txt" >/dev/null
        sudo chmod 644 "$ASSETS_DIR/selected_interfaces.txt"
        log_message "Primary Interface set to $primary_iface (MAC: $primary_mac)"
        log_message "Secondary Interface set to $secondary_iface (MAC: $secondary_mac)"
        ;;
    [Qq]) log_message "Exiting without changes." ; exit 0 ;;
    *) log_message "[✗] Invalid choice. Please select P or Q." ; exit 1 ;;
esac
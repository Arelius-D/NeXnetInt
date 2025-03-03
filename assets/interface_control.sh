#!/bin/bash

SCRIPT_NAME="interface_control.sh"
VERSION="0.06"
CALLING_SCRIPT="$SCRIPT_NAME"
SCRIPT_VERSION="$VERSION"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME v$VERSION] $1" | sudo tee -a "/var/log/nexnetint/nexnetint.log" >/dev/null
    echo "$1"
}

SELECTED_INTERFACES="/usr/local/lib/nexnetint/selected_interfaces.txt"

bring_up_interface() {
    local iface="$1"
    local connection_name="$2"
    log_message "🆙 Attempting to bring up $iface..."
    ip link set "$iface" up 2>/dev/null || log_message "Warning: Failed to set $iface up"
    [ -n "$connection_name" ] && nmcli device connect "$iface" 2>/dev/null || log_message "Warning: Failed to connect $iface"
}

wait_for_carrier() {
    local iface="$1"
    local timeout=10
    local interval=1
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        carrier=$(sudo cat "/sys/class/net/$iface/carrier" 2>/dev/null || echo "0")
        [ "$carrier" = "1" ] && log_message "✅ Carrier detected for $iface after $elapsed seconds." && return 0
        log_message "⏳ Waiting for carrier on $iface ($elapsed/$timeout seconds)..."
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    log_message "⚠️ No carrier detected for $iface after $timeout seconds."
    return 1
}

disconnect_interface() {
    local iface="$1"
    local timeout=5
    local interval=1
    local elapsed=0
    nmcli device set "$iface" managed no 2>/dev/null || log_message "Warning: Failed to set managed no for $iface"
    nmcli device set "$iface" autoconnect no 2>/dev/null || log_message "Warning: Failed to set autoconnect no for $iface"
    while [ $elapsed -lt $timeout ]; do
        output=$(nmcli device disconnect "$iface" 2>&1)
        [ $? -eq 0 ] && log_message "✅ Successfully disconnected $iface." && return 0
        log_message "⚠️ Failed to disconnect $iface ($elapsed/$timeout seconds): $output"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    log_message "❌ Failed to disconnect $iface via nmcli - forcibly setting down..."
    ip link set "$iface" down 2>/dev/null || log_message "❌ Failed to forcibly set $iface down."
    return 1
}

[ "$1" != "--default" ] && log_message "❌ Invalid mode: $1. Use --default." && exit 1

[ ! -f "$SELECTED_INTERFACES" ] && log_message "❌ No interface selections found in $SELECTED_INTERFACES." && exit 1

PRIMARY_MAC=$(grep "^PRIMARY_MAC=" "$SELECTED_INTERFACES" | cut -d'=' -f2)
PRIMARY_NAME=$(grep "^PRIMARY_NAME=" "$SELECTED_INTERFACES" | cut -d'=' -f2)
SECONDARY_MAC=$(grep "^SECONDARY_MAC=" "$SELECTED_INTERFACES" | cut -d'=' -f2)
SECONDARY_NAME=$(grep "^SECONDARY_NAME=" "$SELECTED_INTERFACES" | cut -d'=' -f2)

[ -z "$PRIMARY_MAC" ] || [ "$PRIMARY_MAC" = "N/A" ] && log_message "❌ Primary interface MAC not defined in $SELECTED_INTERFACES." && exit 1

primary_iface=""
secondary_iface=""
primary_connection=""
secondary_connection=""
for iface in $(ls /sys/class/net/); do
    mac_addr=$(sudo cat "/sys/class/net/$iface/address" 2>/dev/null || echo "N/A")
    if [ "$mac_addr" = "$PRIMARY_MAC" ]; then
        primary_iface="$iface"
        primary_connection=$(nmcli -t -f NAME,DEVICE connection show | grep ":$iface$" | cut -d':' -f1)
    elif [ "$mac_addr" = "$SECONDARY_MAC" ]; then
        secondary_iface="$iface"
        secondary_connection=$(nmcli -t -f NAME,DEVICE connection show | grep ":$iface$" | cut -d':' -f1)
    fi
done

[ -z "$primary_iface" ] && log_message "❌ Primary interface (MAC: $PRIMARY_MAC) not found on the system." && primary_iface="none"
[ -z "$secondary_iface" ] || [ "$SECONDARY_MAC" = "none" ] && log_message "⚠️ Secondary interface (MAC: $SECONDARY_MAC) not found or not defined." && secondary_iface="none"

log_message "🔍 Prioritizing primary interface (MAC: $PRIMARY_MAC)..."
chosen_iface=""
if [ "$primary_iface" != "none" ]; then
    bring_up_interface "$primary_iface" "$primary_connection"
    if wait_for_carrier "$primary_iface"; then
        log_message "✅ $PRIMARY_NAME (MAC: $PRIMARY_MAC) has carrier - using it."
        chosen_iface="$primary_iface"
    fi
fi

if [ -z "$chosen_iface" ] && [ "$secondary_iface" != "none" ]; then
    log_message "🔍 Falling back to secondary interface (MAC: $SECONDARY_MAC)..."
    bring_up_interface "$secondary_iface" "$secondary_connection"
    if wait_for_carrier "$secondary_iface"; then
        log_message "✅ $SECONDARY_NAME (MAC: $SECONDARY_MAC) has carrier - using it as fallback."
        chosen_iface="$secondary_iface"
    fi
fi

[ -z "$chosen_iface" ] && log_message "❌ Neither interface has carrier - system will use default network behavior." && exit 0

if [ "$chosen_iface" = "$primary_iface" ] && [ "$secondary_iface" != "none" ]; then
    nmcli device connect "$primary_iface" 2>/dev/null || log_message "Warning: Failed to connect $primary_iface"
    nmcli device set "$primary_iface" managed yes 2>/dev/null || log_message "Warning: Failed to set managed yes for $primary_iface"
    nmcli device set "$primary_iface" autoconnect yes 2>/dev/null || log_message "Warning: Failed to set autoconnect yes for $primary_iface"
    disconnect_interface "$secondary_iface"
elif [ "$chosen_iface" = "$secondary_iface" ] && [ "$primary_iface" != "none" ]; then
    nmcli device connect "$secondary_iface" 2>/dev/null || log_message "Warning: Failed to connect $secondary_iface"
    nmcli device set "$secondary_iface" managed yes 2>/dev/null || log_message "Warning: Failed to set managed yes for $secondary_iface"
    nmcli device set "$secondary_iface" autoconnect yes 2>/dev/null || log_message "Warning: Failed to set autoconnect yes for $secondary_iface"
    disconnect_interface "$primary_iface"
fi

log_message "🔧 Setting up routing table for $chosen_iface..."
gateway=$(ip route | grep "default via" | grep "$chosen_iface" | awk '{print $3}' || echo "N/A")
[ "$gateway" = "N/A" ] && gateway=$(ip route get 8.8.8.8 2>/dev/null | grep "via" | awk '{print $3}')
[ -z "$gateway" ] || [ "$gateway" = "N/A" ] && log_message "⚠️ Could not determine gateway for $chosen_iface - system will use default network behavior." && exit 0

log_message "🗑️ Removing existing default routes..."
ip route | grep "^default" | while IFS= read -r line; do
    iface=$(echo "$line" | awk '{print $5}')
    gateway=$(echo "$line" | awk '{print $3}')
    metric=$(echo "$line" | awk '/metric/ {for (i=1; i<=NF; i++) if ($i == "metric") print $(i+1)}')
    ip route del default via "$gateway" dev "$iface" metric "$metric" 2>/dev/null || log_message "Warning: Failed to remove route for $iface"
done

log_message "➕ Adding default route for $chosen_iface (gateway: $gateway, metric: 10)..."
ip route add default via "$gateway" dev "$chosen_iface" metric 10 2>/dev/null || log_message "Warning: Failed to add route for $chosen_iface"

if ip route | grep -q "default via $gateway dev $chosen_iface metric 10"; then
    log_message "✅ Successfully set $chosen_iface as the default interface (gateway: $gateway, metric: 10)."
else
    log_message "❌ Failed to set $chosen_iface as the default interface - route not found in routing table."
    exit 1
fi

log_message "🧹 Cleaning up any remaining default routes..."
ip route | grep "^default" | while IFS= read -r line; do
    iface=$(echo "$line" | awk '{print $5}')
    gateway=$(echo "$line" | awk '{print $3}')
    metric=$(echo "$line" | awk '/metric/ {for (i=1; i<=NF; i++) if ($i == "metric") print $(i+1)}')
    [ "$iface" != "$chosen_iface" ] && ip route del default via "$gateway" dev "$iface" metric "$metric" 2>/dev/null || log_message "Warning: Failed to remove leftover route for $iface"
done

log_message "✅ Routing table cleanup complete."
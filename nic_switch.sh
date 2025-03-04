#!/bin/bash

SCRIPT_NAME="nic_switch.sh"
VERSION="0.55"
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

log_message "🪢  Switch Interface (Temporary Session Change)..."
sudo "$SYSTEM_DIR/management.sh" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    log_message "❌ management.sh failed to execute (exit code $?)."
    exit 1
fi
sleep 1
if ! sudo [ -f "$DATA_DIR/main_network_manager.txt" ] || ! sudo [ -s "$DATA_DIR/main_network_manager.txt" ]; then
    log_message "❌ management.sh output file not found or empty at $DATA_DIR/main_network_manager.txt."
    exit 1
fi

if ! sudo [ -f "$DATA_DIR/current_network_interface.txt" ] || ! sudo [ -s "$DATA_DIR/current_network_interface.txt" ]; then
    sudo "$SYSTEM_DIR/interface.sh" --view > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_message "❌ interface.sh --view failed to execute (exit code $?)."
        exit 1
    fi
    sleep 1
    if ! sudo [ -f "$DATA_DIR/current_network_interface.txt" ] || ! sudo [ -s "$DATA_DIR/current_network_interface.txt" ]; then
        log_message "❌ interface.sh --view output file not found or empty at $DATA_DIR/current_network_interface.txt."
        exit 1
    fi
fi

NETWORK_MANAGER=$(sudo cat "$DATA_DIR/main_network_manager.txt" 2>/dev/null || echo "none")
CURRENT_MAIN=$(sudo cat "$DATA_DIR/current_network_interface.txt" 2>/dev/null || echo "none")
NET_MONITOR_OUTPUT="$DATA_DIR/net_monitor_output.txt"

sudo "$SYSTEM_DIR/net_monitor.sh" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    log_message "❌ net_monitor.sh failed to execute (exit code $?)."
    exit 1
fi
sleep 1
if ! sudo [ -f "$NET_MONITOR_OUTPUT" ] || ! sudo [ -s "$NET_MONITOR_OUTPUT" ]; then
    log_message "❌ net_monitor.sh output file not found or empty at $NET_MONITOR_OUTPUT."
    exit 1
fi

previous_switch_exists=false
current_session_nic=""
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
if ! sudo [ -f "$DATA_DIR/switch_state.inf" ]; then
    declare -A interface_routes
    mapfile -t routes < <(ip route | grep "^default")
    for line in "${routes[@]}"; do
        iface=$(echo "$line" | awk '{print $5}')
        gateway=$(echo "$line" | awk '{print $3}')
        metric=$(echo "$line" | awk '/metric/ {print $(NF)}' || echo "100")
        interface_routes["$iface"]="gateway:$gateway,metric:$metric"
    done
    {
        echo "$TIMESTAMP info:start"
        for iface in "${!interface_routes[@]}"; do
            IFS=',' read -r gateway_part metric_part <<< "${interface_routes[$iface]}"
            gateway=${gateway_part#gateway:}
            metric=${metric_part#metric:}
            mac=$(sudo cat "/sys/class/net/$iface/address" 2>/dev/null || echo "unknown")
            echo "$TIMESTAMP original:$iface:gateway:$gateway:metric:$metric:mac:$mac"
        done
        echo "$TIMESTAMP info:end"
    } | sudo tee -a "$DATA_DIR/switch_state.inf" >/dev/null
fi

if sudo [ -f "$DATA_DIR/switch_state.inf" ]; then
    CURRENT_MAIN=$(sudo grep "original:" "$DATA_DIR/switch_state.inf" | head -n 1 | cut -d: -f4)
    if sudo grep -q "switched:" "$DATA_DIR/switch_state.inf"; then
        previous_switch_exists=true
        current_session_nic=$(sudo grep "switched:" "$DATA_DIR/switch_state.inf" | tail -n 1 | cut -d: -f4)
    fi
fi

interfaces=$(ls /sys/class/net/ | grep -vE 'lo|veth|docker|br-|tun|tap|virbr|ovs|vnet|wg')
if [ -z "$interfaces" ]; then
    log_message "❌ No physical interfaces detected."
    exit 1
fi

index=1
declare -a valid_interfaces
for iface in $interfaces; do
    if [ -d "/sys/class/net/$iface/device" ]; then
        state=$(ip -br link show "$iface" 2>/dev/null | awk '{print $2}' || echo "DOWN")
        ip_addr=$(ip -br addr show "$iface" 2>/dev/null | awk '{print $3}' | grep -vE "^fe80" | head -n 1 || echo "")
        carrier=$(sudo cat "/sys/class/net/$iface/carrier" 2>/dev/null || echo "0")
        if [[ "$iface" =~ ^wlan ]]; then
            if [ -n "$ip_addr" ]; then
                symbol=""
                [ "$iface" = "$CURRENT_MAIN" ] && symbol=" 🌐"
                [ "$iface" = "$current_session_nic" ] && symbol="$symbol ⚡"
                printf "%d. %s /sys/class/net/%s%s\n" "$index" "$iface" "$iface" "$symbol"
                valid_interfaces[$index]="$iface"
                ((index++))
            fi
        else
            if { [ "$state" = "UP" ] && [ -n "$ip_addr" ]; } || { [ "$state" = "DOWN" ] && [ "$carrier" = "1" ]; }; then
                if [ "$state" = "DOWN" ] && [ "$carrier" = "1" ]; then
                    sudo ip link set "$iface" up 2>/dev/null
                    state=$(ip -br link show "$iface" 2>/dev/null | awk '{print $2}' || echo "DOWN")
                    ip_addr=$(ip -br addr show "$iface" 2>/dev/null | awk '{print $3}' | grep -vE "^fe80" | head -n 1 || echo "")
                    [ -z "$ip_addr" ] && continue
                fi
                status=$([ "$state" = "UP" ] && echo "" || echo " [Pending: DOWN]")
                symbol=""
                [ "$iface" = "$CURRENT_MAIN" ] && symbol=" 🌐"
                [ "$iface" = "$current_session_nic" ] && symbol="$symbol ⚡"
                printf "%d. %s /sys/class/net/%s%s%s\n" "$index" "$iface" "$iface" "$symbol" "$status"
                valid_interfaces[$index]="$iface"
                ((index++))
            fi
        fi
    fi
done

if [ $index -eq 1 ]; then
    log_message "❌ No interfaces are up and configured with an IP address to switch to."
    exit 1
fi

if [ "$previous_switch_exists" = true ]; then
    ORIGINAL_INTERFACE=$(sudo grep "original:" "$DATA_DIR/switch_state.inf" | head -n 1 | cut -d: -f4)
    printf "Choose 1-%d to switch, R to revert to %s, or C (cancel): " "$((index-1))" "$ORIGINAL_INTERFACE"
else
    printf "Choose 1-%d to switch, or C (cancel): " "$((index-1))"
fi
read choice

if [ "$choice" = "c" ] || [ "$choice" = "C" ]; then
    log_message "Operation cancelled."
    exit 0
fi

if [ "$choice" = "r" ] || [ "$choice" = "R" ]; then
    if [ "$previous_switch_exists" != true ]; then
        log_message "❌ No previous switch detected to revert."
        exit 1
    fi
    declare -A processes_to_stop
    declare -A process_details
    declare -A seen_pids
    while IFS=':' read -r _ pid _ process _ iface _ state _ local_ip _ local_port _ remote_ip _ remote_port; do
        if [ "$pid" = "Unknown" ] || [ -z "$pid" ]; then continue; fi
        if [[ -n "${seen_pids[$pid]}" ]]; then continue; fi
        seen_pids["$pid"]="1"
        if [[ "$iface" == "lo" ]] && [[ "$local_ip" =~ ^(127\.0\.0\.1|[::1])$ ]]; then continue; fi
        if [ "$process" = "sshd" ] || [ "$process" = "NetworkManager" ]; then continue; fi
        if [[ "$iface" =~ $CURRENT_MAIN ]] || [[ "$local_ip" =~ ^(ANY|ANYv6)$ ]]; then
            processes_to_stop["$pid"]="$process"
            process_details["$pid"]="interface:$iface:state:$state:local_addr:$local_ip:$local_port:remote_addr:$remote_ip:$remote_port"
            log_message "Identified process to stop/restart: $process (PID $pid) using $iface"
        fi
    done < <(sudo cat "$NET_MONITOR_OUTPUT")
    log_message "Stopping network-dependent processes..."
    for pid in "${!processes_to_stop[@]}"; do
        process="${processes_to_stop[$pid]}"
        case "$process" in
            avahi-daemon)
                sudo systemctl stop avahi-daemon 2>/dev/null
                if [ $? -eq 0 ]; then
                    log_message "Stopped service: avahi-daemon (PID $pid)"
                    processes_to_stop["$pid"]="avahi-daemon:service"
                else
                    sudo kill -TERM "$pid" 2>/dev/null
                    processes_to_stop["$pid"]="avahi-daemon:kill"
                fi
                ;;
            *)
                sudo kill -TERM "$pid" 2>/dev/null
                if [ $? -eq 0 ]; then
                    log_message "Stopped process: $process (PID $pid)"
                    processes_to_stop["$pid"]="$process:kill"
                else
                    unset processes_to_stop["$pid"]
                fi
                ;;
        esac
    done

    ip route | grep "^default" | while IFS= read -r line; do
        iface=$(echo "$line" | awk '{print $5}')
        gateway=$(echo "$line" | awk '{print $3}')
        metric=$(echo "$line" | awk '/metric/ {for (i=1;i<=NF;i++) if($i=="metric") print $(i+1)}')
        sudo ip route del default via "$gateway" dev "$iface" metric "$metric" 2>/dev/null || log_message "Warning: Failed to remove route for $iface"
    done

    ORIGINAL_INTERFACE=$(sudo grep "original:" "$DATA_DIR/switch_state.inf" | head -n 1 | cut -d: -f4)
    original_line=$(sudo grep "original:.*$ORIGINAL_INTERFACE" "$DATA_DIR/switch_state.inf" | head -n 1)
    new_gateway=$(echo "$original_line" | cut -d: -f6)
    new_metric=$(echo "$original_line" | cut -d: -f8 | grep -o '[0-9]*')
    
    sudo ip route add default via "$new_gateway" dev "$ORIGINAL_INTERFACE" metric "$new_metric" 2>/dev/null || log_message "Warning: Failed to restore default route for $ORIGINAL_INTERFACE"
    log_message "Reverted to $ORIGINAL_INTERFACE with full routing state restored."
 
    {
        echo "$TIMESTAMP info:start"
        echo "$TIMESTAMP revert:$ORIGINAL_INTERFACE:restored-routing-state"
        echo "$TIMESTAMP info:end"
    } | sudo tee -a "$DATA_DIR/switch_state.inf" >/dev/null

    sudo sed -i '/switched:/d' "$DATA_DIR/switch_state.inf"

    log_message "Restarting network-dependent processes..."
    for pid in "${!processes_to_stop[@]}"; do
        process_info="${processes_to_stop[$pid]}"
        IFS=':' read -r process method <<< "$process_info"
        case "$method" in
            service) sudo systemctl start "$process" 2>/dev/null && log_message "Restarted service: $process" || log_message "Failed to restart service: $process" ;;
            kill) log_message "Cannot automatically restart process: $process (PID $pid). Please restart manually." ;;
        esac
    done
    exit 0
fi

if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge "$index" ]; then
    log_message "❌ Invalid choice."
    exit 1
fi

selected_iface="${valid_interfaces[$choice]}"
if [ -z "$selected_iface" ]; then
    log_message "❌ Failed to select interface."
    exit 1
fi
if [ "$selected_iface" = "$CURRENT_MAIN" ]; then
    log_message "❌ $selected_iface is already the active interface."
    exit 1
fi

declare -A processes_to_stop
declare -A process_details
declare -A seen_pids
while IFS=':' read -r _ pid _ process _ iface _ state _ local_ip _ local_port _ remote_ip _ remote_port; do
    if [ "$pid" = "Unknown" ] || [ -z "$pid" ]; then continue; fi
    if [[ -n "${seen_pids[$pid]}" ]]; then continue; fi
    seen_pids["$pid"]="1"
    if [[ "$iface" == "lo" ]] && [[ "$local_ip" =~ ^(127\.0\.0\.1|[::1])$ ]]; then continue; fi
    if [ "$process" = "sshd" ] || [ "$process" = "NetworkManager" ]; then continue; fi
    if [[ "$iface" =~ $CURRENT_MAIN ]] || [[ "$local_ip" =~ ^(ANY|ANYv6)$ ]]; then
        processes_to_stop["$pid"]="$process"
        process_details["$pid"]="interface:$iface:state:$state:local_addr:$local_ip:$local_port:remote_addr:$remote_ip:$remote_port"
        log_message "Identified process to stop/restart: $process (PID $pid) using $iface"
    fi
done < <(sudo cat "$NET_MONITOR_OUTPUT")

log_message "Stopping network-dependent processes..."
for pid in "${!processes_to_stop[@]}"; do
    process="${processes_to_stop[$pid]}"
    case "$process" in
        avahi-daemon)
            sudo systemctl stop avahi-daemon 2>/dev/null
            if [ $? -eq 0 ]; then
                log_message "Stopped service: avahi-daemon (PID $pid)"
                processes_to_stop["$pid"]="avahi-daemon:service"
            else
                sudo kill -TERM "$pid" 2>/dev/null
                processes_to_stop["$pid"]="avahi-daemon:kill"
            fi
            ;;
        *)
            sudo kill -TERM "$pid" 2>/dev/null
            if [ $? -eq 0 ]; then
                log_message "Stopped process: $process (PID $pid)"
                processes_to_stop["$pid"]="$process:kill"
            else
                unset processes_to_stop["$pid"]
            fi
            ;;
    esac
done

new_metric=$(( $(sudo grep "original:.*$CURRENT_MAIN" "$DATA_DIR/switch_state.inf" | head -n 1 | cut -d: -f8 | grep -o '[0-9]*') - 10 ))
[ "$new_metric" -lt 0 ] && new_metric=10
new_gateway=$(sudo grep "original:.*$CURRENT_MAIN" "$DATA_DIR/switch_state.inf" | head -n 1 | cut -d: -f6)

ip route | grep "^default" | while IFS= read -r line; do
    iface=$(echo "$line" | awk '{print $5}')
    gateway=$(echo "$line" | awk '{print $3}')
    metric=$(echo "$line" | awk '/metric/ {for (i=1; i<=NF; i++) if ($i == "metric") print $(i+1)}')
    sudo ip route del default via "$gateway" dev "$iface" metric "$metric" 2>/dev/null || log_message "Warning: Failed to remove route for $iface"
done

sudo ip route add default via "$new_gateway" dev "$selected_iface" metric "$new_metric" 2>/dev/null || log_message "Warning: Failed to add route for $selected_iface"
while IFS=':' read -r timestamp tag iface _ gateway _ metric; do
    if [ "$tag" = "original" ] && [ "$iface" != "$selected_iface" ]; then
        sudo ip route add default via "$gateway" dev "$iface" metric "$metric" 2>/dev/null || log_message "Warning: Failed to restore route for $iface"
    fi
done < <(sudo cat "$DATA_DIR/switch_state.inf")

log_message "Restarting network-dependent processes..."
for pid in "${!processes_to_stop[@]}"; do
    process_info="${processes_to_stop[$pid]}"
    IFS=':' read -r process method <<< "$process_info"
    case "$method" in
        service) sudo systemctl start "$process" 2>/dev/null && log_message "Restarted service: $process" || log_message "Failed to restart service: $process" ;;
        kill) log_message "Cannot automatically restart process: $process (PID $pid). Please restart manually." ;;
    esac
done

{
    echo "$TIMESTAMP info:start"
    echo "$TIMESTAMP switched:$selected_iface:gateway:$new_gateway:metric:$new_metric:mac:$(sudo cat \"/sys/class/net/$selected_iface/address\" 2>/dev/null || echo \"unknown\")"
    echo "$TIMESTAMP info:end"
} | sudo tee -a "$DATA_DIR/switch_state.inf" >/dev/null

log_message "Switched to $selected_iface (persists until reboot)."

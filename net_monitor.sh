#!/bin/bash

SCRIPT_NAME="net_monitor.sh"
VERSION="0.20"
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

declare -A ip_to_iface
declare -A iface_ports
declare -A iface_v6
while read -r iface ip; do
    ip="${ip%/*}"
    ip_to_iface["$ip"]=$iface
    iface_ports["$iface"]+="$ip "
    [[ "$ip" =~ .*:.* ]] && iface_v6["$iface"]+="$ip "
done < <(ip -o addr show | awk '{print $2, $4}' | sed 's/\/.*//')

NET_MONITOR_OUTPUT=""
while read -r protocol state local remote process; do
    if [[ $process =~ pid=([0-9]+) ]]; then
        pid="${BASH_REMATCH[1]}"
        pname=$(ps -p "$pid" -o comm=)
    else
        pid="Unknown"
        pname="Unknown"
    fi
    local_ip="${local%:*}"
    local_port="${local##*:}"
    remote_ip="${remote%:*}"
    remote_port="${remote##*:}"
    [[ "$local_ip" == "0.0.0.0" || "$local_ip" == "*" ]] && local_ip="ANY"
    [[ "$remote_ip" == "0.0.0.0" || "$remote_ip" == "*" ]] && remote_ip="ANY"
    [[ "$local_ip" == "[::]" ]] && local_ip="ANYv6"
    [[ "$remote_ip" == "[::]" ]] && remote_ip="ANYv6"
    interface="Unknown"
    if [[ "$local_ip" != "ANY" && "$local_ip" != "ANYv6" && -n "${ip_to_iface[$local_ip]}" ]]; then
        interface="${ip_to_iface[$local_ip]}"
    elif [[ "$local_ip" == "ANY" || "$local_ip" == "ANYv6" ]]; then
        interfaces=""
        for iface in "${!iface_ports[@]}"; do
            interfaces="$interfaces$iface "
        done
        interface="$interfaces"
    fi
    NET_MONITOR_OUTPUT="$NET_MONITOR_OUTPUT\nPID:$pid:process:$pname:interface:$interface:state:$state:local_addr:$local_ip:$local_port:remote_addr:$remote_ip:$remote_port"
done < <(sudo ss -tunap 2>/dev/null | awk 'NR>1 {print $1, $2, $5, $6, $7}' || ss -tunap 2>/dev/null | awk 'NR>1 {print $1, $2, $5, $6, $7}')

echo -e "$NET_MONITOR_OUTPUT" | sudo tee "$DATA_DIR/net_monitor_output.txt" >/dev/null

log_message "🛰️ Network Monitoring..."
while read -r protocol state local remote process; do
    if [[ $process =~ pid=([0-9]+) ]]; then
        pid="${BASH_REMATCH[1]}"
        pname=$(ps -p "$pid" -o comm=)
    else
        pid="Unknown"
        pname="Unknown"
    fi
    local_ip="${local%:*}"
    local_port="${local##*:}"
    remote_ip="${remote%:*}"
    remote_port="${remote##*:}"
    [[ "$local_ip" == "0.0.0.0" || "$local_ip" == "*" ]] && local_ip="ANY"
    [[ "$remote_ip" == "0.0.0.0" || "$remote_ip" == "*" ]] && remote_ip="ANY"
    [[ "$local_ip" == "[::]" ]] && local_ip="ANYv6"
    [[ "$remote_ip" == "[::]" ]] && remote_ip="ANYv6"
    interface="Unknown"
    if [[ "$local_ip" != "ANY" && "$local_ip" != "ANYv6" && -n "${ip_to_iface[$local_ip]}" ]]; then
        interface="${ip_to_iface[$local_ip]}"
    elif [[ "$local_ip" == "ANY" || "$local_ip" == "ANYv6" ]]; then
        interfaces=""
        for iface in "${!iface_ports[@]}"; do
            interfaces="$interfaces$iface "
        done
        interface="$interfaces"
    fi
    log_message "Connection:"
    log_message "    PID:        $pid ($pname)"
    log_message "    Protocol:   $protocol"
    log_message "    Local Addr: $local_ip:$local_port"
    log_message "    Remote Addr: $remote_ip:$remote_port"
    log_message "    State:      $state"
    log_message "    Interface:  $interface"
done < <(sudo ss -tunap 2>/dev/null | awk 'NR>1 {print $1, $2, $5, $6, $7}' || ss -tunap 2>/dev/null | awk 'NR>1 {print $1, $2, $5, $6, $7}')
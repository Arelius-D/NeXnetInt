#!/bin/bash

UTILITY_NAME="nexnetint"
VERSION="1.0.0"
SYSTEM_DIR="/usr/local/lib/nexnetint"
ASSETS_DIR="$SYSTEM_DIR/assets"
DATA_DIR="$SYSTEM_DIR/data"
LOG_DIR="/var/log/$UTILITY_NAME"

log_message() {
    local message="$1"
    local script="${CALLING_SCRIPT:-$UTILITY_NAME}"
    local version="${SCRIPT_VERSION:-$VERSION}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$script v$version] $message" | sudo tee -a "$LOG_DIR/nexnetint.log" >/dev/null
    echo "$message"
}

setup_dirs() {
    sudo mkdir -p "$SYSTEM_DIR" "$ASSETS_DIR" "$DATA_DIR" "$LOG_DIR"
    sudo chmod 755 "$SYSTEM_DIR" "$ASSETS_DIR"
    sudo chmod 644 "$DATA_DIR" "$LOG_DIR"
    sudo chown root:root "$SYSTEM_DIR" "$ASSETS_DIR" "$DATA_DIR" "$LOG_DIR"
}

install_utility() {
    setup_dirs
    for script in dependencies.sh interface.sh management.sh net_monitor.sh nic_switch.sh service_management.sh; do
        if [ -f "$script" ]; then
            sudo cp "$script" "$SYSTEM_DIR/"
            sudo chmod +x "$SYSTEM_DIR/$script"
            log_message "Copied $script to $SYSTEM_DIR/$script"
        else
            log_message "Warning: $script not found in current directory"
        fi
    done
    sudo cp -v "$(pwd)/nexnetint.sh" "/usr/local/bin/nexnetint"
    if [ $? -eq 0 ]; then
        log_message "Copy succeeded: $(pwd)/nexnetint.sh to /usr/local/bin/nexnetint"
    else
        log_message "Copy failed: $(pwd)/nexnetint.sh to /usr/local/bin/nexnetint"
        exit 1
    fi
    sudo chmod +x "/usr/local/bin/nexnetint"
    log_message "Set executable permissions on /usr/local/bin/nexnetint"
    sudo cp assets/interface_control.sh "$ASSETS_DIR/"
    sudo cp assets/nexnetint.service "$ASSETS_DIR/"
    sudo chmod +x "$ASSETS_DIR/interface_control.sh"
    log_message "Copied assets to $ASSETS_DIR"
    if [ -f "/usr/local/bin/nexnetint" ] && [ -x "/usr/local/bin/nexnetint" ]; then
        log_message "Verified: /usr/local/bin/nexnetint exists and is executable"
    else
        log_message "ERROR: /usr/local/bin/nexnetint does not exist or is not executable"
        exit 1
    fi
    log_message "Utility installed to /usr/local/bin/nexnetint. Run 'nexnetint' to start."
}

show_versions() {
    echo "$UTILITY_NAME v$VERSION"
    for script in "$SYSTEM_DIR"/*.sh "$ASSETS_DIR/interface_control.sh"; do
        version=$(grep "^VERSION=" "$script" | cut -d'"' -f2)
        echo "$(basename "$script") v$version"
    done
}

if sudo [ -f "$DATA_DIR/switch_state.inf" ]; then
    TIMESTAMP=$(sudo head -n 1 "$DATA_DIR/switch_state.inf" | cut -d' ' -f1-2)
    if sudo grep -q "^$TIMESTAMP switched:" "$DATA_DIR/switch_state.inf"; then
        SWITCHED_MAC=$(sudo grep "^$TIMESTAMP switched:" "$DATA_DIR/switch_state.inf" | cut -d: -f6)
        CURRENT_ACTIVE=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}' || echo "unknown")
        CURRENT_ACTIVE_MAC=$(sudo cat "/sys/class/net/$CURRENT_ACTIVE/address" 2>/dev/null || echo "unknown")
        if [ "$SWITCHED_MAC" != "$CURRENT_ACTIVE_MAC" ]; then
            sudo rm -f "$DATA_DIR/switch_state.inf"
            log_message "🧹 Cleared stale switch state (reboot detected: switched MAC $SWITCHED_MAC != active MAC $CURRENT_ACTIVE_MAC)."
        fi
    fi
fi

validate_switch_state() {
    if sudo [ -f "$DATA_DIR/switch_state.inf" ]; then
        local stale=0
        while IFS= read -r line; do
            if echo "$line" | grep -q "original:"; then
                iface=$(echo "$line" | cut -d: -f4)
                stored_mac=$(echo "$line" | sed 's/.*mac://')
                current_mac=$(sudo cat "/sys/class/net/$iface/address" 2>/dev/null || echo "unknown")
                if [ "$stored_mac" != "$current_mac" ]; then
                    log_message "MAC mismatch for $iface: stored=$stored_mac, current=$current_mac"
                    stale=1
                fi
            fi
        done < <(sudo grep "original:" "$DATA_DIR/switch_state.inf")
        if [ "$stale" -eq 1 ]; then
            log_message "Stale switch state detected. Clearing switch state file."
            sudo rm -f "$DATA_DIR/switch_state.inf"
        fi
    fi
}

validate_switch_state

show_tui() {
    "$SYSTEM_DIR/dependencies.sh" >/dev/null 2>&1
    while true; do
        clear
        echo "🐧 NeXnetInt - Network Interface Utility (v$VERSION)"
        echo "-------------------------------------------------"
        echo "1. View Management"
        echo "2. View Interfaces"
        echo "3. Switch NIC (Session change only)"
        echo "4. Install Service"
        echo "5. Purge Service"
        echo "6. Check Service Status"
        echo "0. Exit"
        echo -n "Choose an option (1-6, 0): "
        read choice
        case "$choice" in
            1) "$SYSTEM_DIR/management.sh" ;;
            2) "$SYSTEM_DIR/interface.sh" --view ;;
            3) "$SYSTEM_DIR/nic_switch.sh" ;;
            4) handle_install ;;
            5) "$SYSTEM_DIR/service_management.sh" --purge ;;
            6) check_service_status ;;
            0) sudo rm "$DATA_DIR/"*.txt 2>/dev/null ; exit 0 ;;
            *) log_message "Invalid choice." ;;
        esac
        read -p "Press Enter to continue..."
    done
}

handle_install() {
    if [ -f "/etc/systemd/system/nexnetint.service" ]; then
        status="installed"
        systemctl is-active --quiet nexnetint.service && status="$status and running" || status="$status but not running"
        log_message "Service is $status."
        log_message "If you want to reinstall, purge first. Use main menu (option 5) or run 'nexnetint --purge' from the shell."
        return
    fi
    "$SYSTEM_DIR/interface.sh"
    echo -n "Continue with service installation? (y/N): "
    read choice
    if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
        "$SYSTEM_DIR/service_management.sh" --install
    else
        log_message "Installation aborted."
    fi
}

check_service_status() {
    if [ -f "/etc/systemd/system/nexnetint.service" ]; then
        status="installed"
        systemctl is-active --quiet nexnetint.service && status="$status and running" || status="$status but not running"
        log_message "Service is $status."
    else
        log_message "Service is not installed."
    fi
}

case "$1" in
    --initiate) install_utility ;;
    --install) handle_install ;;
    --purge) "$SYSTEM_DIR/service_management.sh" --purge ;;
    -v) show_versions ;;
    -h) echo "Usage: $UTILITY_NAME [--initiate|--install|--purge|-v|-h]" ;;
    *) [ -f "/usr/local/bin/nexnetint" ] && show_tui || log_message "Run with --initiate first." ;;
esac
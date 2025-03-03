#!/bin/bash

SCRIPT_NAME="service_management.sh"
VERSION="0.08"
CALLING_SCRIPT="$SCRIPT_NAME"
SCRIPT_VERSION="$VERSION"
SYSTEM_DIR="/usr/local/lib/nexnetint"
ASSETS_DIR="$SYSTEM_DIR/assets"
LOG_DIR="/var/log/nexnetint"

log_message() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME v$VERSION] $message" | sudo tee -a "$LOG_DIR/nexnetint.log" >/dev/null
    echo "$message"
}

SERVICE_SRC="$ASSETS_DIR/nexnetint.service"
SERVICE_DEST="/etc/systemd/system/nexnetint.service"
INT_CONTROL_SRC="$ASSETS_DIR/interface_control.sh"
INT_CONTROL_DEST="$SYSTEM_DIR/interface_control.sh"
SELECTED_INTERFACES_SRC="$ASSETS_DIR/selected_interfaces.txt"
SELECTED_INTERFACES_DEST="$SYSTEM_DIR/selected_interfaces.txt"

case "$1" in
    --install)
        if [ -f "$SERVICE_DEST" ]; then
            status="installed"
            systemctl is-active --quiet nexnetint.service && status="$status and running" || status="$status but not running"
            log_message "⚠️ NeXnetInt service is $status."
            log_message "Use --purge to remove it first if you want to reinstall."
            exit 1
        fi
        if [ ! -f "$INT_CONTROL_SRC" ]; then
            log_message "❌ interface_control.sh not found at $INT_CONTROL_SRC."
            exit 1
        fi
        if [ ! -f "$SELECTED_INTERFACES_SRC" ]; then
            log_message "❌ selected_interfaces.txt not found at $SELECTED_INTERFACES_SRC. Run interface.sh first."
            exit 1
        fi
        if [ ! -f "$SERVICE_SRC" ]; then
            log_message "❌ Service file not found at $SERVICE_SRC."
            exit 1
        fi
        sudo mkdir -p "$SYSTEM_DIR"
        sudo cp "$INT_CONTROL_SRC" "$INT_CONTROL_DEST"
        sudo chmod 755 "$INT_CONTROL_DEST"
        sudo cp "$SELECTED_INTERFACES_SRC" "$SELECTED_INTERFACES_DEST"
        sudo chmod 644 "$SELECTED_INTERFACES_DEST"
        sudo cp "$SERVICE_SRC" "$SERVICE_DEST"
        sudo chmod 644 "$SERVICE_DEST"
        sudo systemctl daemon-reload
        sudo systemctl enable nexnetint.service
        log_message "✅ NeXnetInt service installed and enabled."
        echo -n "Reboot now? (y/N): "
        read reboot_choice
        [ "$reboot_choice" = "y" ] || [ "$reboot_choice" = "Y" ] && sudo reboot || log_message "⚠️ Reboot skipped."
        ;;
    --purge)
        needs_reboot=0
        if systemctl is-active --quiet nexnetint.service; then
            sudo systemctl stop nexnetint.service
            log_message "✅ Stopped nexnetint.service."
            needs_reboot=1
        else
            log_message "⚠️ Service was not running."
        fi
        if systemctl is-enabled --quiet nexnetint.service; then
            sudo systemctl disable nexnetint.service
            log_message "✅ Disabled nexnetint.service."
            needs_reboot=1
        else
            log_message "⚠️ Service was not enabled."
        fi
        [ -f "$SERVICE_DEST" ] && sudo rm -f "$SERVICE_DEST" && log_message "✅ Removed $SERVICE_DEST." && needs_reboot=1 || log_message "⚠️ $SERVICE_DEST not found."
        sudo systemctl daemon-reload
        log_message "✅ Reloaded systemd daemon."
        [ -f "$INT_CONTROL_DEST" ] && sudo rm -f "$INT_CONTROL_DEST" && log_message "✅ Removed $INT_CONTROL_DEST." && needs_reboot=1 || log_message "⚠️ $INT_CONTROL_DEST not found."
        [ -f "$SELECTED_INTERFACES_DEST" ] && sudo rm -f "$SELECTED_INTERFACES_DEST" && log_message "✅ Removed $SELECTED_INTERFACES_DEST." && needs_reboot=1 || log_message "⚠️ $SELECTED_INTERFACES_DEST not found."
        rmdir --ignore-fail-on-non-empty "$SYSTEM_DIR" 2>/dev/null && log_message "✅ Removed $SYSTEM_DIR." || log_message "⚠️ $SYSTEM_DIR not removed."
        log_message "✅ NeXnetInt service purged."
        if [ "$needs_reboot" = "1" ]; then
            echo -n "Reboot now? (y/N): "
            read reboot_choice
            [ "$reboot_choice" = "y" ] || [ "$reboot_choice" = "Y" ] && sudo reboot || log_message "⚠️ Reboot skipped."
        fi
        ;;
    *) log_message "Use --install or --purge" ;;
esac
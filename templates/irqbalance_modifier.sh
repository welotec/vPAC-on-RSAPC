#!/bin/bash
# Tuned script to modify and restore /etc/sysconfig/irqbalance

CONFIG_FILE="/etc/sysconfig/irqbalance"
BACKUP_FILE="/etc/sysconfig/irqbalance.tuned.bak"

case "$1" in
    start)
        # Backup original if not already saved
        if [ ! -f "$BACKUP_FILE" ]; then
            cp "$CONFIG_FILE" "$BACKUP_FILE"
        fi

        # Update IRQBALANCE_ARGS line
        if grep -q '^IRQBALANCE_ARGS=' "$CONFIG_FILE"; then
            sed -i 's/^IRQBALANCE_ARGS=.*/IRQBALANCE_ARGS=--banmod=igb/' "$CONFIG_FILE"
        else
            echo 'IRQBALANCE_ARGS=--banmod=igb' >> "$CONFIG_FILE"
        fi
        ;;
    stop)
        # Restore backup if it exists
        if [ -f "$BACKUP_FILE" ]; then
            mv "$BACKUP_FILE" "$CONFIG_FILE"
        fi
        ;;
esac

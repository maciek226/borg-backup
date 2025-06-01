#!/bin/bash
break_lock() {
    local REMOTE_USER=$1
    local REMOTE_IP=$2
    local REMOTE_BACKUP_PATH=$3

    if borg break-lock $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH; then
        echo "Lock broken successfully"
        return 0
    else
        echo "Failed to break lock"
        return 1
    fi
}
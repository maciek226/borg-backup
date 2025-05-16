#!/bin/bash
# Ensure required environment variables are set
: "${REMOTE_USER:?Error: REMOTE_USER is not set}"
: "${REMOTE_IP:?Error: REMOTE_IP is not set}"
: "${REMOTE_BACKUP_PATH:?Error: REMOTE_BACKUP_PATH is not set}"

USER="${1:-$REMOTE_USER}"
IP="${2:-$REMOTE_IP}"
DIR="${3:-$REMOTE_BACKUP_PATH}"

break_lock() {
    borg break-lock $USER@$IP:$DIR
    if [ $? -eq 0 ]; then
        echo "Lock broken successfully."
    else
        echo "Failed to break lock."
    fi
}
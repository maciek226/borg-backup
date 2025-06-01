#!/bin/bash

check_repo() {
    local REMOTE_USER=$1
    local REMOTE_IP=$2
    local REMOTE_BACKUP_PATH=$3
    
    if borg check --repository-only --max-duration 10 --show-rc "$REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH"; then
        echo "Repository exists and is healthy"
        return 0
    else
        echo "Repository does not exist or is unhealthy"
        return 1
    fi
}
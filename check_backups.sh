#!/bin/bash

if ! borg --show-rc break-lock $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH; then
    echo "Failed to break lock"
    exit 1
fi

if borg --show-rc list --consider-checkpoints $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH; then
    echo "Backup repository is healthy"
else
    echo "Backup repository is not healthy"
    exit 1
fi

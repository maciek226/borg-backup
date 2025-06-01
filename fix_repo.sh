#!/bin/bash

if ! borg break-lock $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH; then
    echo "Failed to break lock"
    exit 1
fi

if ! borg check --repair $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH; then
    echo "Failed to repair repository"
    exit 1
fi
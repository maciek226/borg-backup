#!/bin/bash
source /scripts/break_lock.sh

if ! break_lock $REMOTE_USER $REMOTE_IP $REMOTE_BACKUP_PATH; then
    exit 1
fi
# Issues with fuse 
if ! borg --show-rc mount $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH /mountpoint; then
    echo "Failed to mount backup"
    exit 1
fi
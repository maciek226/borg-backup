#!/bin/bash

source /scripts/env_variables.txt

echo "Starting backup script..."
CURRENT_TIME=$(date +%Y-%m-%d_%H-%M-%S)
echo "Current time: $CURRENT_TIME"

check_remote_server() {
    local REMOTE_IP=$1
    ping -c 5 -W 2 "$REMOTE_IP"
    
    if [ $? -eq 0 ]; then
        echo "Remote server is reachable"
    else
        echo "Remote server is not reachable"
        return 1
    fi
}

check_remote_server $REMOTE_IP || exit 1

BACKUP_LOG_FILE="/config/last_backup.txt"

if [ -e "$BACKUP_LOG_FILE" ]; then
    echo "backup log found"
    PREVIOUS_BACKUP_NAME=$(<"$BACKUP_LOG_FILE")
else
    echo "backup log not found"
    PREVIOUS_BACKUP_NAME=""
fi

if [ -z "$PREVIOUS_BACKUP_NAME" ]; then
    echo "No previous backup found"
    CREATE_NEW_BACKUP=true
else
    echo "Previous backup: $PREVIOUS_BACKUP_NAME"
    # Check if the previous backup is complete 
    borg break-lock $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH
    borg list --consider-checkpoints --show-rc $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH::"$PREVIOUS_BACKUP_NAME" >> /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Previous backup is complete"
        CREATE_NEW_BACKUP=true
    else
        echo "Previous backup is not complete"
        borg list --consider-checkpoints --show-rc $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH | grep -q "Checkpoint"
        if [ $? -eq 0 ]; then
            echo "Previous backup does not have a checkpoint - creating new backup"
            CREATE_NEW_BACKUP=true
        else
            echo "Previous backup has a checkpoint, continuing backup"
            CREATE_NEW_BACKUP=false
        fi
        CREATE_NEW_BACKUP=false
    fi
fi

# Prepare the flags
EXCLUDE_FLAGS=""
IFS=',' read -ra PATHS <<< "$EXCLUDE_PATHS"
for path in "${PATHS[@]}"; do
    EXCLUDE_FLAGS+="--exclude $path "
done
echo "Exclude flags: $EXCLUDE_FLAGS"

IFS=',' read -ra PATHS <<< "$BACKUP_PATHS"
INCLUDE_FLAGS="${PATHS[@]}"
echo "Include flags: $INCLUDE_FLAGS"

if [ "$CREATE_NEW_BACKUP" = true ]; then
    NEW_NAME=$(date +%Y-%m-%d_%H-%M-%S)
    echo "Creating new backup"
    # Replace the log file with the new backup name
    echo "$NEW_NAME" > "$BACKUP_LOG_FILE"
    while true; do
        borg break-lock $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH
        borg create --progress --stats --show-rc  $EXCLUDE_FLAGS --checkpoint-interval 60 $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH::$NEW_NAME $INCLUDE_FLAGS
        echo $?
        if [ $? -eq 0 ]; then
            echo "Backup successful"
            break
        else
            echo "Backup failed, retrying..."
        fi
        # Check connection
        check_remote_server $REMOTE_IP || exit 1
    done
else
    echo "Continuing previous backup"
    while true; do
        borg break-lock $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH
        borg create --show-rc --stats --progress $EXCLUDE_FLAGS --checkpoint-interval 60 $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH::$PREVIOUS_BACKUP_NAME $INCLUDE_FLAGS
        if [ $? -eq 0 ]; then
            echo "Backup successful"
            break
        else
            echo "Backup failed, retrying..."
        fi

        # Check connection
        check_remote_server $REMOTE_IP || exit 1
    done
fi

borg prune --show-rc --progress $BORG_PRUNE_CMD $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH
if [ $? -eq 0 ]; then
    echo "Pruning successful"
else
    echo "Pruning failed"
fi

borg compact --progress --show-rc --threshold $COMPACT_THRESHOLD $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH
if [ $? -eq 0 ]; then
    echo "Compacting successful"
else
    echo "Compacting failed"
fi

CURRENT_TIME=$(date +%Y-%m-%d_%H-%M-%S)
echo "Finished at: $CURRENT_TIME"

echo "Trimming the log files"
logrotate /etc/logrotate.d/backup
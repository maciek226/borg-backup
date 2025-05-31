#!/bin/bash

echo "Starting container..."

# 0. Set timezone
ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime

# 1. Check if the SSH key exists 
echo "Checking provided SSH key"
if [ -e $PATH_TO_SSH ]; then
    echo "Provided SSH key exists"
else
    echo "Provided SSH key does not exist"
    exit 1
fi

# 2. Check if the SSH dir exists
echo "Checking local SSH directory"
if [ -d ~/.ssh ]; then
    echo "SSH directory exists"
else
    mkdir ~/.ssh
    echo "SSH directory created"
fi

# 2. Check if the SSH key exists
echo "Coping SSH key"
if [ -e ~/.ssh/id_rsa ]; then
    echo "SSH key already exists"
else
    echo "Coping SSH key into local dir"
    cp $REMOTE_SSH_FILE ~/.ssh/id_rsa
fi

# 3. Edit SSH configuration
# This part modifies the SSH configuration to make it easier to notice
# when the connection is lost

SSH_CONFIG="/etc/ssh/ssh_config"
touch "$SSH_CONFIG"

CONFIG="Host $REMOTE_IP
    ServerAliveInterval 10
    ServerAliveCountMax 30"

# Check if the configuration already exists (allow variations in spacing)
if grep -Eq "^\s*Host\s+$REMOTE_IP\b" "$SSH_CONFIG"; then
    echo "SSH configuration for $REMOTE_IP already exists. Updating..."

    # Remove old configuration block related to the same IP
    sed -i -r "/^\s*Host\s+$REMOTE_IP\b/,/^$/d" "$SSH_CONFIG"
fi

# Append new configuration at the end
echo -e "\n$CONFIG" >> "$SSH_CONFIG"
echo "SSH configuration for $REMOTE_IP added successfully."

# 4. Check SSH connection 
ssh -o StrictHostKeyChecking=no $REMOTE_USER@$REMOTE_IP exit

if [ $? -eq 0 ]; then
    echo "SSH connection successful"
else
    echo "SSH connection failed"
    exit 1
fi

# 5. update/create rate_limit.sh
echo '#!/bin/bash' > "/scripts/rate_limit.sh"
echo "pv -q -L $RATE_LIMIT | \"\$@\"" >> "/scripts/rate_limit.sh"

if [ -e /scripts/rate_limit.sh ]; then
    echo "Found rate_limit.sh"
else
    echo "rate_limit.sh not found"
    exit 1
fi

# 6. Check if the repo exists
if [ -n "$BORG_PASSPHRASE" ]; then
    echo "BORG_PASSPHRASE is set."
else
    echo "BORG_PASSPHRASE is not set or is empty."
    exit 1
fi

# To avoid issues where a drive where the borg repo is stored is not mounted yet
if [ -e /config/repo_exists ]; then
    echo "Found repo_exists file"
    SAVED_REMOTE_BACKUP_PATH=$(cat /config/repo_exists)
    if [ "$SAVED_REMOTE_BACKUP_PATH" == "$REMOTE_BACKUP_PATH" ]; then
        echo "Remote backup path matches saved path"
    else
        echo "Remote backup path does not match saved path, updating..."
        echo $REMOTE_BACKUP_PATH > /config/repo_exists
    fi
else
    echo "repo_exists file not found"
fi

if borg check --repository-only --max-duration 10 --show-rc $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH; then
    echo "Repository exists and is healthy"
    if [ -z "$SAVED_REMOTE_BACKUP_PATH" ]; then
        echo $REMOTE_BACKUP_PATH > /config/repo_exists
    fi
else
    echo "Repository does not exist"
    # Avoid creating a new repository if the old one is not available
    if [ -n "$SAVED_REMOTE_BACKUP_PATH" ]; then
        echo "The previously used repository is not available. Check the remote path or create a new repository."
        exit 1
    fi
    borg init --encryption=repokey $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH
    borg key export $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH --passphrase $BORG_PASSPHRASE --output /keys/repo_key
    echo $REMOTE_BACKUP_PATH > /config/repo_exists
fi


# 8. Save enviromental variables 
export -p  > /scripts/env_variables.txt

# 9. Setup log rotation 
cat <<EOF > /etc/logrotate.d/backup
/config/backup.log {
    size 300M
    rotate 2
    copytruncate
    compress
    missingok
    notifempty
}
EOF


# 7. Schedule the backup
# TODO: make a separate script that can lock up the command in case the backup is not complete 
echo "Scheduling backup"
echo "$CRON_SCHEDULE /bin/bash -c '/scripts/backup.sh 2>&1 | tee /config/backup.log | cat > /proc/1/fd/1'" > /etc/crontabs/root
# 8. Check if the cron service is running
if pgrep crond > /dev/null; then
    echo "crond is running"
else
    echo "crond is NOT running"
    crond -f -s 
    echo "crond started"
fi
#!/bin/bash

echo "Starting container..."

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

if borg check --repository-only --max-duration --show-rc 10 $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH; then
    echo "Repository exists and is healthy"
else
    echo "Repository does not exist"
    borg init --encryption=repokey $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH
    borg key export $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH --passphrase $BORG_PASSPHRASE --output /keys/repo_key
fi

# 7. Schedule the backup
# TODO: make a separate script that can lock up the command in case the backup is not complete 
echo "Scheduling backup"
echo "$CRON_SCHEDULE /scripts/backup.sh" > /etc/crontabs/root

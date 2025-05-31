#!/bin/bash

borg break-lock $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH
borg list --consider-checkpoints $REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_PATH

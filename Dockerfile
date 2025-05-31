FROM alpine:latest 

WORKDIR /
RUN mkdir -p /scripts
ADD entrypoint.sh /scripts/entrypoint.sh
ADD backup.sh /scripts/backup.sh
ADD check_backups.sh /scripts/check_backups.sh

ENV BORG_PASSPHRASE=pass_phrase
ENV REMOTE_IP=0.0.0.0
ENV REMOTE_USER=user
ENV REMOTE_BACKUP_PATH=/path/to/backup
ENV REMOTE_SSH_FILE=/path/to/ssh
ENV RATE_LIMIT=3000000
ENV BACKUP_PATHS=/backup_targets/data_1,/backup_targets/data_2
ENV EXCLUDE_PATHS=/path/to/exclude1/*,/path/to/exclude2/*
ENV CRON_SCHEDULE='0 0 * * *'
ENV BORG_PRUNE_CMD=--keep-within=10d --keep-weekly=4
ENV COMPACT_THRESHOLD=10
ENV TZ=Etc/UTC

RUN apk add --no-cache bash borgbackup openssh cronie nano grep pv tzdata coreutils logrotate 
RUN chmod +x /scripts/entrypoint.sh /scripts/backup.sh /scripts/check_backups.sh

ENTRYPOINT ["/bin/sh", "-c", ". /scripts/entrypoint.sh 2>&1 | tee /proc/1/fd/1 && tail -f /dev/null"]

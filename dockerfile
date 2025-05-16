FROM alpine:latest 
ADD entrypoint.sh /scripts/entrypoint.sh
ADD backup.sh /scripts/backup.sh

ENV BORG_PASSPHRASE=pass_phrase
ENV REMOTE_IP=0.0.0.0
ENV REMOTE_USER=user
ENV REMOTE_BACKUP_PATH=/path/to/backup
ENV REMOTE_SSH_FILE=/path/to/ssh
ENV RATE_LIMIT=3000000
ENV BACKUP_PATHS=/backup_targets/data_1,/backup_targets/data_2
ENV EXCLUDE_PATHS=/path/to/exclude1/*,/path/to/exclude2/*
ENV CRON_SCHEDULE="0 0 * * *"

RUN apk add --no-cache bash borgbackup openssh cronie nano grep pv
RUN chmod +x /start_script.sh

ENTRYPOINT ["/scripts/entrypoint.sh"]
CMD ["/bin/sh", "-c", "exec /bin/bash -l"] 
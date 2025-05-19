# borg-backup
A docker based solution to securely backing up nas/servers by connecting to a remote server through a VPN container like Wireguard. The goal is to not have to expose the backup server to the wider web. 

## Prerequisite  
`TODO: This might be incomplete`
- Create an SSH key pair 
    ```bash
    sh-keygen -t rsa -b 4096 -C "my@email.com"
    ```
    and place the output in an accessible location on the local machine. 
- Setup Wireguard server on the remote machine. 
    ```yaml
    services:
    wireguard:
        image: lscr.io/linuxserver/wireguard:latest
        container_name: wireguard
        cap_add:
        - NET_ADMIN
        - SYS_MODULE # optional
        environment:
        PUID: 1000
        PGID: 1000
        TZ: Etc/UTC
        SERVERURL: sample.duckdns.org # optional
        SERVERPORT: 51820 # optional
        PEERS: 1 # One of the peers needs to be reserved for container 
        LOG_CONFS: 'true' # optional
        ports:
        - "51820:51820/udp"
        volumes:
        - ./path/to/config:/config
        sysctls:
        net.ipv4.conf.all.src_valid_mark: "1"
        restart: unless-stopped
    ```
    - Make sure to adjust the `SERVERURL` and `PEERS`. One connection will be occupied by connection

## Setup
On the local machine deploy the wireguard and the backup container

```yaml
services:
  wireguard_backup:
    image: lscr.io/linuxserver/wireguard
    container_name: wireguard_backup
    dns:
      - 8.8.8.8
      - 8.8.4.4
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
    volumes:
      - /path/to/config/:/config/wg_confs/
      - /lib/modules:/lib/modules
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    restart: unless-stopped
    labels:
      - com.centurylinklabs.watchtower.monitor-only="true"

  borg:
    image: borg_backups:latest
    container_name: borg_backup
    depends_on:
      - wireguard_backup
    network_mode: service:wireguard_backup
    environment:
      - TZ=Etc/UTC
      - BORG_PASSPHRASE=
      - REMOTE_IP=
      - REMOTE_USER=
      - REMOTE_BACKUP_PATH=
      - REMOTE_SSH_FILE= # Should be in the /keys volume
      - RATE_LIMIT=3000000 # 30 Mbps
      - BACKUP_PATHS=/backup_targets/data_1,/backup_targets/data_2
      - EXCLUDE_PATHS=/path/to/exclude1/*,/path/to/exclude2/*
      - CRON_SCHEDULE= '0 2 * * *'
      - BORG_PRUNE_CMD='--keep-within=10d --keep-weekly=4'
      - COMPACT_THRESHOLD=10
    volumes:
      - /Config/backup:/config
      - /Config/backup/cache:~/.cache/borg # Keep this in a persistent volume 
      - /Config/backup:/keys
      - /path/to/data_1:/backup_targets/data_1
      - /path/to/data_2:/backup_targets/data_2
    command: ["/bin/sh", "-c", "tail -f /dev/null"] 
    labels:
     - com.centurylinklabs.watchtower.monitor-only="true" # Recommended if using watchtower to not interrupt the backups
    restart: unless-stopped
```

| Variable | Description | 
|-------|-----|
| `TZ` | time zone |
| `/path/to/config/:/config/wg_confs/` | Path to the wireguard confirmation file created on the remote server | 
| `BORG_PASSPHRASE` | Password to pass to borg|
| `REMOTE_IP` | Local IP of the remote server |
| `REMOTE_USER` | User name to use on the remote machine |
| `REMOTE_BACKUP_PATH` | Path to the borg backup drive |
| `RATE_LIMIT` | Bandwidth limit for the backup in b/s|
| `BACKUP_PATHS` | Local machine paths to backup |
| `EXCLUDE_PATHS` | Local machine exclude [paths/patterns](https://borgbackup.readthedocs.io/en/stable/usage/create.html)|
| `CRON_SCHEDULE` | `cron` schedule for running the backup|
| `BORG_PRUNE_CMD` | [prune command](https://borgbackup.readthedocs.io/en/stable/usage/prune.html) to be used at the end of the backup |
| `COMPACT_THRESHOLD` | [see here](https://borgbackup.readthedocs.io/en/stable/usage/compact.html) |

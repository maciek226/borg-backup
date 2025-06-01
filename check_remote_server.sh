#!/bin/bash

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
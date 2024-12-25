#!/bin/bash

# autostart_dev.sh

on_folder_close() {
    
    # This is run when the folder / VSCode closes
    # Use -v to remove volumes
    make stop-devenv
    
    trap - SIGINT
    kill -- -$$
}

trap on_folder_close SIGINT SIGTERM EXIT

# This is run when the folder is opened
# -d to run in detached mode
make start-devenv

sleep infinity
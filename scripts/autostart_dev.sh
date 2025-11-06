#!/bin/bash

# autostart_dev.sh

on_folder_close() {
    
    # This is run when the folder / VSCode closes
    # Use -v to remove volumes
    mise run devenv stop
    
    trap - SIGINT
    kill -- -$$
}

trap on_folder_close SIGINT SIGTERM EXIT

# This is run when the folder is opened
# -d to run in detached mode
mise run devenv start

sleep infinity
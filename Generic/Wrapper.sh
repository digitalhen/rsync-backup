#!/bin/sh
set -eu

# The host or IP address of the remote system
sourcehost=10.0.0.99

# Path on local system that is the source (from the perspective of the remote system)
backup="/Volumes/Archive/Childrens"

# Path on the local system that is the destination (here, the source would be backed up to /storage/Backup/Documents)
target="/storage/Backup/Documents/"

# Executes the master script
me="$(dirname "$0")"
"$me/SSHBackup.sh" "$sourcehost" "$backup" "$target"

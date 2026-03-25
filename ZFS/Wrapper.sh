#!/bin/sh
set -eu

# Path on local system that is the source (here, a mounted SMB file system)
backup="/media/Software"

# Path on the local system that is the destination (here, the source would be backed up to /storage/Backup/Software)
target="/storage/Backup/"

# Executes the master script
me="$(dirname "$0")"
"$me/SyncBackup.sh" "$backup" "$target"

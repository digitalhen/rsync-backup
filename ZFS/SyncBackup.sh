#!/bin/sh
set -eu

# Check argument count
if [ $# -ne 2 ]; then
    echo "Usage: $0 <source path> <target path>"
    exit 2
fi

# Capture the variables
backup="$1"
target="$2"
scriptdir="$(dirname "$0")"
excludefile="${scriptdir}/excludes.txt"
logfile="${target}backup.log"
rsync_timeout=3600

# Logging — tee output to both console and logfile
exec > >(tee -a "$logfile") 2>&1
echo "=== Sync started at $(date) ==="

# Check excludes file exists
if [ ! -f "$excludefile" ]; then
    echo "Exclude file not found: $excludefile"
    exit 1
fi

# Check the file system is valid by checking for a last backup timestamp
# (this would need to be created manually the first time on the source)
echo "Checking data is available at $backup"
if [ -f "${backup}/lastbackup.txt" ]; then
    echo "lastbackup.txt found, continuing"
else
    echo "Can't find lastbackup.txt in $backup, so will quit."
    exit 1
fi

# Get the date for this backup
date=$(date "+%Y-%m-%dT%H_%M_%S")

# Stamp the backup on the source filesystem
date > "${backup}/lastbackup.txt"

# Rsync with timeout and exclude file
rsync \
    -avP \
    --exclude-from="$excludefile" \
    --delete-after \
    --delete-excluded \
    --timeout="$rsync_timeout" \
    "$backup" \
    "$target"

echo "=== Sync finished at $(date) ==="

#!/bin/sh
set -eu

# check argument count
if [ $# -ne 3 ]; then
    echo "Usage: $0 <source host> <source path> <target path>"
    exit 2
fi

# settings
sourcehost="$1"
backup="$2"
target="$3"
scriptdir="$(dirname "$0")"
excludefile="${scriptdir}/excludes.txt"
lockfile="${target}lockfile"
logfile="${target}backup.log"
rsync_timeout=3600

# logging — tee output to both console and logfile
exec > >(tee -a "$logfile") 2>&1
echo "=== Backup started at $(date) ==="

# cleanup lockfile on exit (success or failure)
cleanup() {
    rm -f "$lockfile"
}

# PID-based lockfile — detect and handle stale locks
if [ -f "$lockfile" ]; then
    old_pid=$(cat "$lockfile")
    if kill -0 "$old_pid" 2>/dev/null; then
        echo "Another backup is running (PID $old_pid), stopping."
        exit 1
    else
        echo "Removing stale lockfile from PID $old_pid."
        rm -f "$lockfile"
    fi
fi
echo $$ > "$lockfile"
trap cleanup EXIT

# check excludes file exists
if [ ! -f "$excludefile" ]; then
    echo "Exclude file not found: $excludefile"
    exit 1
fi

# check sourcehost is available
echo "Checking $sourcehost is available"
if ssh "$sourcehost" whoami > /dev/null 2>&1; then
    echo "$sourcehost is available, continuing."
else
    echo "Can't connect to $sourcehost, so will quit."
    exit 1
fi

# date for this backup
date=$(date "+%Y-%m-%dT%H_%M_%S")

# create folders if necessary
mkdir -p "${target}current" "${target}weekly" "${target}daily" "${target}hourly"

# mark the backup time on the remote filesystem
ssh "$sourcehost" "date > '$backup/lastbackup.txt'"

# rsync with timeout and exclude file
rsync \
    -av \
    --exclude-from="$excludefile" \
    --delete \
    --timeout="$rsync_timeout" \
    --link-dest="${target}current" \
    -e ssh \
    "${sourcehost}:${backup}" \
    "${target}${date}-incomplete"

# backup complete — atomic symlink update
mv "${target}${date}-incomplete" "${target}hourly/${date}"
ln -sfn "${target}hourly/${date}" "${target}current"
touch "${target}hourly/${date}"

# keep daily backup — promote oldest hourly if no recent daily exists
daily_recent=$(find "${target}daily" -maxdepth 1 -type d -mtime -2 -name "20*" | wc -l)
hourly_count=$(find "${target}hourly" -maxdepth 1 -name "20*" | wc -l)
if [ "$daily_recent" -eq 0 ] && [ "$hourly_count" -gt 1 ]; then
    oldest=$(find "${target}hourly" -maxdepth 1 -type d -name "20*" -printf '%T+ %f\n' 2>/dev/null | sort | head -1 | cut -d' ' -f2)
    if [ -n "$oldest" ]; then
        mv "${target}hourly/${oldest}" "${target}daily/"
    fi
fi

# keep weekly backup — promote oldest daily if no recent weekly exists
weekly_recent=$(find "${target}weekly" -maxdepth 1 -type d -mtime -14 -name "20*" | wc -l)
daily_count=$(find "${target}daily" -maxdepth 1 -name "20*" | wc -l)
if [ "$weekly_recent" -eq 0 ] && [ "$daily_count" -gt 1 ]; then
    oldest=$(find "${target}daily" -maxdepth 1 -type d -name "20*" -printf '%T+ %f\n' 2>/dev/null | sort | head -1 | cut -d' ' -f2)
    if [ -n "$oldest" ]; then
        mv "${target}daily/${oldest}" "${target}weekly/"
    fi
fi

# delete old backups, and 2 hour old incomplete backups
find "${target}" -maxdepth 1 -name "*incomplete" -type d -mmin +120 -exec rm -rvf {} +
find "${target}hourly" -maxdepth 1 -type d -mtime +0 -exec rm -rvf {} +
find "${target}daily" -maxdepth 1 -type d -mtime +7 -exec rm -rvf {} +

echo "=== Backup finished at $(date) ==="
# lockfile removed automatically by cleanup trap

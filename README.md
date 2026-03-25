Backup
======

Rsync-based multi-platform backup scripts with rotation support.

## Overview

Two backup strategies are provided:

- **Generic** — SSH-based remote backup with automatic hourly/daily/weekly rotation
- **ZFS** — Local or mounted filesystem sync (designed for use with ZFS snapshots)

## Generic (SSH Remote Backup)

Pulls data from a remote host over SSH using rsync with hard-link-based deduplication. Backups are automatically rotated into hourly, daily, and weekly tiers.

### Usage

```sh
Generic/SSHBackup.sh <source host> <source path> <target path>
```

- **source host** — hostname or IP of the remote machine (must have SSH key auth configured)
- **source path** — path on the remote machine to back up
- **target path** — local directory to store backups (must end with `/`)

### How It Works

1. Acquires a PID-based lockfile (stale locks from crashed processes are detected and removed)
2. Verifies SSH connectivity to the remote host
3. Runs `rsync` with `--link-dest` to deduplicate unchanged files against the previous backup
4. Moves the completed backup into `hourly/` and atomically updates the `current` symlink
5. Promotes the oldest hourly backup to `daily/` if no recent daily exists
6. Promotes the oldest daily backup to `weekly/` if no recent weekly exists
7. Cleans up old backups (hourly: >1 day, daily: >7 days, incomplete: >2 hours)

All output is logged to `<target>/backup.log`.

### Retention Policy

| Tier   | Kept For |
|--------|----------|
| Hourly | 1 day    |
| Daily  | 7 days   |
| Weekly | No automatic deletion |

### Directory Structure

```
<target>/
  current        -> symlink to latest backup
  lockfile       -> PID-based lock to prevent concurrent runs
  backup.log     -> append-only log of all backup runs
  hourly/
    2024-01-15T10_00_00/
    2024-01-15T11_00_00/
  daily/
    2024-01-14T10_00_00/
  weekly/
    2024-01-07T10_00_00/
```

### Wrapper

Edit `Generic/Wrapper.sh` to set your source host, source path, and target path, then schedule it with cron:

```sh
# Run every hour
0 * * * * /path/to/Generic/Wrapper.sh
```

## ZFS (Local Sync Backup)

Syncs a local or mounted filesystem to a target directory using rsync. Designed for use with ZFS, where snapshots provide the versioning layer.

### Usage

```sh
ZFS/SyncBackup.sh <source path> <target path>
```

- **source path** — local directory to back up (must contain a `lastbackup.txt` file)
- **target path** — local directory to sync to

### How It Works

1. Checks for `lastbackup.txt` in the source to verify the filesystem is mounted and valid
2. Timestamps the source with the current date
3. Runs `rsync` with `--delete-after` and `--delete-excluded` for a clean mirror

All output is logged to `<target>/backup.log`.

### Wrapper

Edit `ZFS/Wrapper.sh` to set your source and target paths, then schedule it with cron:

```sh
# Run every hour
0 * * * * /path/to/ZFS/Wrapper.sh
```

## Excluded Directories

Exclusions are managed via `excludes.txt` files alongside each script — one pattern per line. Edit these to add or remove exclusions without modifying the scripts.

Default exclusions:

- `DoNotBackup` — user-designated exclusion marker
- `BBC iPlayer`, `Final Cut Events`, `Final Cut Projects`, `iMovie Events.localized` — large media caches
- `$RECYCLE.BIN`, `System Volume Information` — Windows system directories (ZFS only)

## Configuration

Each script has configurable variables at the top:

| Variable | Default | Description |
|----------|---------|-------------|
| `rsync_timeout` | `3600` | Seconds before rsync aborts a stalled transfer |

## Requirements

- `rsync`
- `ssh` with key-based authentication (Generic only)
- POSIX-compatible shell (`/bin/sh`)
- `find` with `-printf` support (GNU findutils)

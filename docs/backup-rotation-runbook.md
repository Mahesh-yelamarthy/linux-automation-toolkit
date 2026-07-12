# Backup Rotation Runbook

This runbook supports `backups/backup-rotation.sh`, a production-safe backup retention script for Linux hosts.

The script removes old backup archives from one directory while protecting a minimum number of matching files. It runs in dry-run mode by default and requires `--delete` before it removes anything.

## When to Use

Use this runbook when:

- Backup directories are approaching disk capacity.
- Old archives need to be rotated on a schedule.
- A host is generating repeated disk usage alerts from backup growth.
- A backup retention job fails or removes fewer files than expected.

Do not use this script for database backups, object storage buckets, or multi-directory backup systems without adapting and reviewing the policy.

## Script Location

```text
backups/backup-rotation.sh
```

## Safe Dry Run

Always run a dry-run before deletion:

```bash
./backups/backup-rotation.sh \
  --backup-dir /var/backups/app \
  --retention-days 14 \
  --min-keep 3 \
  --pattern '*.tar.gz' \
  --dry-run
```

Expected dry-run behavior:

- Prints backup directory, pattern, retention, and minimum keep policy.
- Counts matching files.
- Lists files older than the retention period that are eligible for deletion.
- Prints estimated reclaimable bytes.
- Does not delete files.

## Delete Mode

After reviewing dry-run output, run:

```bash
./backups/backup-rotation.sh \
  --backup-dir /var/backups/app \
  --retention-days 14 \
  --min-keep 3 \
  --pattern '*.tar.gz' \
  --delete
```

Deletion mode requires write access to the backup directory.

## Policy Controls

| Option | Purpose | Production guidance |
| --- | --- | --- |
| `--backup-dir` | Directory containing backup archives. | Use a specific application backup directory, not a broad system path. |
| `--retention-days` | Age threshold for deletion. | Align with recovery point and compliance requirements. |
| `--min-keep` | Minimum number of matching files to retain. | Keep enough restore points to cover failed backup cycles. |
| `--pattern` | File glob to match backup archives. | Use a narrow pattern such as `app-*.tar.gz`. |
| `--dry-run` | Preview candidate files. | Use before every new schedule or policy change. |
| `--delete` | Remove selected files. | Use only after validating dry-run output. |

## Exit Codes

| Exit code | Meaning | Operator action |
| --- | --- | --- |
| `0` | Rotation completed, skipped safely, or dry-run completed. | No immediate action required. |
| `1` | No matching backup files were found. | Confirm backup job output path and filename pattern. |
| `2` | Invalid configuration, dependency, permissions, or unsafe path. | Fix arguments, directory permissions, or scheduling context. |

## Triage Steps

1. Confirm the backup directory exists.
2. Confirm the filename pattern matches real backup files.
3. Run a dry-run with the same arguments used by cron or the scheduler.
4. Confirm `--min-keep` is not protecting all matching files.
5. Confirm the retention period is older than the files being inspected.
6. Confirm the execution user has write access when `--delete` is used.
7. Check disk usage before and after deletion.

Useful commands:

```bash
df -h /var/backups/app
find /var/backups/app -maxdepth 1 -type f -name '*.tar.gz' -ls
du -sh /var/backups/app
```

## Safety Checks

The script refuses to rotate directly from broad system directories such as `/`, `/etc`, `/usr`, `/var`, and `/home`.

It also protects the configured minimum keep count. If the directory contains only the minimum number of matching backups, rotation is skipped even when files are older than the retention threshold.

## Escalation

Escalate to the service owner or backup owner when:

- Backup files are missing.
- Backup growth exceeds expected capacity planning.
- Rotation would violate retention or compliance policy.
- A restore test has not been performed recently.
- The host remains under disk pressure after rotation.

## Post-Change Review

After changing backup retention policy:

- Confirm at least one restore test is scheduled.
- Confirm monitoring reflects expected disk growth.
- Confirm the schedule captures script output in an operational log.
- Update this runbook if a new failure mode is discovered.

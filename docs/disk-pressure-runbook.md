# Disk Pressure Runbook

This runbook supports Linux disk usage alerts, manual disk investigations, and the baseline `monitoring/disk-monitor.sh` script. It is written for SRE, DevOps, and infrastructure operators responding to a host that is approaching or has reached unsafe disk utilization.

## Scope

Use this runbook when:

- `monitoring/disk-monitor.sh` reports root filesystem usage above threshold.
- A host reports disk pressure, full filesystem, or failed writes.
- Logs, backups, or application data are consuming unexpected space.
- Cleanup or backup rotation is being considered during an incident.

This runbook focuses on investigation and safe response. It does not authorize deleting unknown application, database, or system files.

## Signal

Run the baseline disk monitor:

```bash
bash monitoring/disk-monitor.sh
```

Current behavior:

- Checks root filesystem usage.
- Uses a static threshold of `80`.
- Prints current usage and warning status.
- Does not modify the host.

Because this script is intentionally simple, responders should use the manual checks below before taking action.

## First Five Minutes

Capture host and filesystem context:

```bash
hostname -f
date -u
uptime
df -h
df -ih
mount | column -t
```

Identify the full filesystem:

```bash
df -h /
df -h /var
df -h /var/log
df -h /var/backups
```

Check the largest directories on the affected filesystem:

```bash
du -xh / 2>/dev/null | sort -h | tail -30
du -xh /var 2>/dev/null | sort -h | tail -30
du -xh /var/log 2>/dev/null | sort -h | tail -30
du -xh /var/backups 2>/dev/null | sort -h | tail -30
```

If inode exhaustion is suspected:

```bash
df -ih
find /var -xdev -type f 2>/dev/null | sed 's#/[^/]*$##' | sort | uniq -c | sort -n | tail -30
```

## Decision Table

| Symptom | Likely Cause | First Response |
| --- | --- | --- |
| `/var/log` growing quickly | Verbose service logs, crash loop, missing rotation. | Identify noisy service and review log rotation. |
| `/var/backups` full | Retention too long, backup job producing large archives. | Run backup rotation dry-run and confirm policy. |
| Root filesystem full | Logs, package cache, temporary files, application data. | Find largest directories before deleting anything. |
| Inodes exhausted | Many small files, runaway temp files, bad job output. | Identify directory with file explosion. |
| Disk usage rises after deployment | New logs, cache, artifacts, or data path change. | Compare recent changes with growing paths. |
| Cleanup script failure | Permissions, unsafe path, missing files, locked filesystem. | Capture output and run manual checks before retrying. |

## Safe Cleanup Workflow

Follow this sequence:

1. Identify the affected filesystem.
2. Identify the largest directories on that filesystem.
3. Classify files as logs, backups, caches, temp files, application data, database data, or unknown.
4. Use approved cleanup or rotation commands only for known-safe categories.
5. Preserve evidence when customer impact or repeat failure is possible.
6. Record what was removed, why, and by whom.

Do not start with `rm -rf`. Deletion without understanding the owner and file purpose can turn a capacity incident into a data-loss incident.

## Log Cleanup

The current log cleanup script is:

```text
cleanup/log-cleanup.sh
```

Current behavior:

- Targets `/var/log`.
- Deletes files named `*.log`.
- Deletes files older than `7` days.
- Does not currently support dry-run mode.

Before running it on a production host:

```bash
sed -n '1,160p' cleanup/log-cleanup.sh
find /var/log -type f -name "*.log" -mtime +7 -print 2>/dev/null | head -100
```

Run only when the target files are understood:

```bash
bash cleanup/log-cleanup.sh
```

If log volume is growing quickly, identify the writer:

```bash
du -xh /var/log 2>/dev/null | sort -h | tail -30
lsof +L1 2>/dev/null | head -50
journalctl --disk-usage 2>/dev/null
```

Check service logs for a noisy process:

```bash
systemctl --failed --no-pager
journalctl --since "1 hour ago" --no-pager | tail -200
```

## Backup Rotation

Use backup rotation for known backup archive directories, not arbitrary cleanup.

Preview rotation first:

```bash
./backups/backup-rotation.sh \
  --backup-dir /var/backups/app \
  --retention-days 14 \
  --min-keep 3 \
  --pattern '*.tar.gz' \
  --dry-run
```

Only delete after confirming the target path, file pattern, and minimum keep policy:

```bash
./backups/backup-rotation.sh \
  --backup-dir /var/backups/app \
  --retention-days 14 \
  --min-keep 3 \
  --pattern '*.tar.gz' \
  --delete
```

Do not rotate backups during an active restore or data-loss investigation without approval from the service owner.

## Escalation Criteria

Escalate when:

- Disk usage is above `95%`.
- Writes are failing for customer-facing services.
- Database, queue, or storage directories are involved.
- The largest files are unknown.
- Inode exhaustion is present.
- Cleanup requires deleting application or customer data.
- The same filesystem fills repeatedly after cleanup.

Escalation should include host, filesystem, usage percentage, largest directories, suspected owner, actions taken, and remaining risk.

## Evidence to Capture

Record:

- Hostname and timestamp.
- Affected filesystem and usage.
- `df -h` and `df -ih` output.
- Largest directories from `du`.
- Files or directories removed.
- Cleanup or rotation command used.
- Exit code.
- Service impact.
- Follow-up owner.

Example note:

```text
Host: app-01.example.internal
Filesystem: /var
Usage: 92%
Largest path: /var/log/nginx
Action: Rotated known old access logs after service owner approval
Command: find /var/log/nginx -type f -name '*.log' -mtime +14 -print
Impact: No write failures observed
Follow-up: Review nginx log rotation policy
```

## Preventive Follow-Up

After recovery, create follow-up work for:

- Missing log rotation.
- Backup retention too long.
- Application writing excessive logs.
- No alert before critical usage.
- Lack of separate filesystem for high-growth data.
- Missing dry-run support in cleanup automation.
- Missing ownership for large directories.

Disk incidents should result in a clearer retention policy or monitoring signal, not only one-time cleanup.

# Usage Guide

This guide explains how to run and review the Linux automation toolkit safely.

## Prerequisites

Expected environment:

- Linux host or Linux-compatible shell environment
- Bash
- Standard system utilities such as `df`, `ps`, `find`, `tar`, `hostname`, `awk`, and `uptime`
- Appropriate permissions for the target script

Some commands may behave differently on macOS because `/proc/meminfo` and tools such as `free` are Linux-specific.

## Clone the Repository

```bash
git clone git@github.com:Mahesh-yelamarthy/linux-automation-toolkit.git
cd linux-automation-toolkit
```

## Review Scripts Before Running

Before executing any operational automation, inspect the script:

```bash
sed -n '1,200p' monitoring/disk-monitor.sh
```

For scripts that modify files, also review configured paths and retention values.

## Run Monitoring Scripts

Disk usage monitor:

```bash
bash monitoring/disk-monitor.sh
```

Expected behavior:

- Reads root filesystem usage.
- Compares usage against the configured threshold.
- Prints either a warning or an under-control message.

Memory pressure monitor:

```bash
./scripts/memory-monitor.sh --used-threshold 85 --available-threshold 10 --swap-threshold 50
```

Expected behavior:

- Reads `/proc/meminfo`.
- Calculates used memory, available memory, and swap usage.
- Prints the top resident-memory processes.
- Exits with status `1` when memory or swap pressure crosses configured thresholds.

NGINX endpoint health check:

```bash
./scripts/nginx-health-check.sh --url http://127.0.0.1/ --expected-status 200 --timeout 5
```

Expected behavior:

- Sends an HTTP request to the configured endpoint.
- Compares the returned status code with the expected status.
- Prints request timing and remote IP when available.
- Optionally verifies that an NGINX process is running.

## Run Health Checks

System health check:

```bash
bash health-checks/system-health.sh
```

Expected behavior:

- Prints hostname.
- Prints uptime.
- Prints memory usage.
- Prints disk usage.
- Prints top memory-consuming processes.

Use this as a quick first-pass triage command during host investigation.

## Run Maintenance Scripts

Log cleanup:

```bash
bash cleanup/log-cleanup.sh
```

Important production note:

The script targets `/var/log` and removes `.log` files older than the configured retention period. Review the script and test in a safe environment before running it on a production host.

## Run Backup Scripts

Home directory backup:

```bash
bash backups/backup-home-directory.sh
```

Expected behavior:

- Creates a backup directory under the current user's home directory.
- Generates a timestamped `.tar.gz` archive.
- Prints the backup path.

Backup rotation dry-run:

```bash
./backups/backup-rotation.sh \
  --backup-dir /var/backups/app \
  --retention-days 14 \
  --min-keep 3 \
  --pattern '*.tar.gz' \
  --dry-run
```

Expected behavior:

- Counts matching backup files.
- Lists old files that are eligible for rotation.
- Preserves the configured minimum number of backup files.
- Does not delete files unless `--delete` is provided.

## Recommended Validation

Use shell syntax checks before committing changes:

```bash
bash -n monitoring/disk-monitor.sh
bash -n health-checks/system-health.sh
bash -n cleanup/log-cleanup.sh
bash -n backups/backup-home-directory.sh
bash -n backups/backup-rotation.sh
bash -n scripts/process-monitor.sh
bash -n scripts/memory-monitor.sh
bash -n scripts/nginx-health-check.sh
```

Use manual execution only on hosts where the target paths and permissions are understood.

## Operational Logging

When running scripts unattended, redirect output to a log file:

```bash
bash monitoring/disk-monitor.sh >> /var/log/linux-automation-toolkit.log 2>&1
```

For cron-based execution, future examples will include explicit schedules and log redirection.

## Failure Handling

If a script fails:

1. Capture the command, host, user, and timestamp.
2. Re-run with the same arguments manually if safe.
3. Check whether required commands exist on the host.
4. Confirm file permissions and target paths.
5. Review recent system changes.
6. Update the relevant runbook if the failure mode is repeatable.

## Current Scope

This version includes process monitoring, memory pressure monitoring, NGINX endpoint checking, and backup rotation automation with operational runbooks.

Future commits will add cron examples, troubleshooting guides, and script standards.

# Linux Automation Toolkit

Production-oriented Linux operations toolkit for SRE, DevOps, and infrastructure support workflows.

This repository is part of a 30-day SRE / DevOps portfolio build. The project is developed gradually to show how a real operations toolkit grows from small host-level scripts into reusable automation with runbooks, cron examples, troubleshooting guides, logging standards, and maintenance practices.

## Purpose

The goal of this repository is to demonstrate practical Linux automation skills that support production reliability work.

This toolkit will gradually cover:

- Process monitoring
- Memory monitoring
- Disk usage checks
- NGINX health checks
- Backup rotation
- Log cleanup
- System health reporting
- Cron scheduling examples
- Operational runbooks
- Linux troubleshooting guides
- Script safety and logging standards

## Current Status

Day 26 disk pressure runbook is complete.

The toolkit now includes production-oriented process, memory, disk, and NGINX endpoint monitors, safe backup rotation automation, cron scheduling examples, a structured Linux host troubleshooting guide, script logging and safety standards, and dedicated incident response runbooks.

## Repository Structure

```text
linux-automation-toolkit/
├── README.md
├── backups/
│   ├── backup-rotation.sh
│   └── backup-home-directory.sh
├── cleanup/
│   └── log-cleanup.sh
├── cron/
│   └── linux-automation-toolkit.cron
├── docs/
│   ├── cron-scheduling.md
│   ├── disk-pressure-runbook.md
│   ├── kubernetes-notes.md
│   ├── linux-troubleshooting-guide.md
│   ├── backup-rotation-runbook.md
│   ├── memory-monitor-runbook.md
│   ├── nginx-health-check-runbook.md
│   ├── process-monitor-runbook.md
│   ├── script-logging-and-safety-standards.md
│   └── usage.md
├── health-checks/
│   └── system-health.sh
├── monitoring/
│   └── disk-monitor.sh
└── scripts/
    ├── memory-monitor.sh
    ├── nginx-health-check.sh
    ├── process-monitor.sh
    └── README.md
```

## Current Script Inventory

| Script | Category | Purpose |
| --- | --- | --- |
| `monitoring/disk-monitor.sh` | Monitoring | Checks root filesystem usage against a threshold and prints a warning when usage is high. |
| `health-checks/system-health.sh` | Health checks | Prints host, uptime, memory, disk, and top process information for quick triage. |
| `cleanup/log-cleanup.sh` | Maintenance | Removes old `.log` files from `/var/log` based on a retention period. |
| `backups/backup-home-directory.sh` | Backup | Creates a timestamped compressed backup of the current user's home directory. |
| `backups/backup-rotation.sh` | Backup | Rotates old backup archives with dry-run safety and minimum-retention protection. |
| `scripts/process-monitor.sh` | Monitoring | Ranks CPU and memory consumers, detects threshold violations, and verifies required processes. |
| `scripts/memory-monitor.sh` | Monitoring | Reports memory pressure, swap usage, and top resident-memory consumers. |
| `scripts/nginx-health-check.sh` | Health checks | Validates an NGINX endpoint status and optionally checks for an NGINX process. |

## Cron Examples

The cron example file is stored at:

```text
cron/linux-automation-toolkit.cron
```

It includes schedules for process monitoring, memory monitoring, NGINX health checking, backup rotation, and weekly system health snapshots.

Review and customize `TOOLKIT_HOME`, `LOG_FILE`, thresholds, and backup paths before installing it on any host.

## Example Commands

Run the disk monitor:

```bash
bash monitoring/disk-monitor.sh
```

Run the process monitor with production-specific thresholds:

```bash
./scripts/process-monitor.sh \
  --cpu-threshold 85 \
  --memory-threshold 75 \
  --top 10 \
  --require-process nginx
```

Exit status `0` means no violations were detected, `1` indicates an operational alert, and `2` indicates invalid configuration or an unsupported runtime.

Run the memory monitor:

```bash
./scripts/memory-monitor.sh \
  --used-threshold 85 \
  --available-threshold 10 \
  --swap-threshold 50 \
  --top 10
```

Exit status `0` means memory pressure is within thresholds, `1` indicates pressure that needs investigation, and `2` indicates invalid configuration or an unsupported runtime.

Run the NGINX health check:

```bash
./scripts/nginx-health-check.sh \
  --url http://127.0.0.1/ \
  --expected-status 200 \
  --timeout 5 \
  --require-process
```

Exit status `0` means the endpoint and optional process check passed, `1` indicates an operational issue, and `2` indicates invalid configuration or a missing dependency.

Run the system health check:

```bash
bash health-checks/system-health.sh
```

Run log cleanup:

```bash
bash cleanup/log-cleanup.sh
```

Run the home directory backup:

```bash
bash backups/backup-home-directory.sh
```

Preview backup rotation:

```bash
./backups/backup-rotation.sh \
  --backup-dir /var/backups/app \
  --retention-days 14 \
  --min-keep 3 \
  --pattern '*.tar.gz' \
  --dry-run
```

Exit status `0` means rotation completed or no deletion was required, `1` indicates a policy condition that needs review, and `2` indicates invalid configuration, permissions, or an unsafe target.

## Operational Safety

Before running scripts on a production host:

- Read the script and confirm the target paths.
- Run the command manually before scheduling it with cron.
- Prefer non-destructive checks before cleanup or rotation actions.
- Confirm the script has the minimum permissions needed.
- Capture output in a log file when running unattended.
- Test retention, cleanup, and backup behavior in a non-production environment first.

## Production Use Cases

This toolkit is designed around common SRE and Linux operations scenarios:

- Investigating resource pressure on a host
- Checking whether critical system signals look healthy
- Cleaning up old logs to reduce disk pressure
- Creating repeatable backup workflows
- Preparing scripts for scheduled execution
- Documenting operational procedures for handoff
- Running structured Linux host incident triage

## Documentation

- [Script catalog](scripts/README.md)
- [Usage guide](docs/usage.md)
- [Backup rotation runbook](docs/backup-rotation-runbook.md)
- [Cron scheduling guide](docs/cron-scheduling.md)
- [Disk pressure runbook](docs/disk-pressure-runbook.md)
- [Linux troubleshooting guide](docs/linux-troubleshooting-guide.md)
- [Memory monitor runbook](docs/memory-monitor-runbook.md)
- [NGINX health check runbook](docs/nginx-health-check-runbook.md)
- [Process monitor runbook](docs/process-monitor-runbook.md)
- [Script logging and safety standards](docs/script-logging-and-safety-standards.md)
- [Kubernetes notes](docs/kubernetes-notes.md)

## Recruiter Signal

This repository is designed to show practical operations ability:

- Linux command-line fluency
- Shell scripting fundamentals
- Production maintenance awareness
- Safe automation habits
- Documentation that helps another engineer operate the toolkit

## Day 26 Commit

Recommended commit message:

```text
docs: add disk pressure runbook
```

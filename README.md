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

Day 2 foundation is complete.

The repository already includes several starter automation scripts. This commit organizes the project around production operations, documents the current script inventory, and adds usage guidance for safe execution.

## Repository Structure

```text
linux-automation-toolkit/
├── README.md
├── backups/
│   └── backup-home-directory.sh
├── cleanup/
│   └── log-cleanup.sh
├── docs/
│   ├── kubernetes-notes.md
│   └── usage.md
├── health-checks/
│   └── system-health.sh
├── monitoring/
│   └── disk-monitor.sh
└── scripts/
    └── README.md
```

Planned future directories:

```text
cron/
runbooks/
```

## Current Script Inventory

| Script | Category | Purpose |
| --- | --- | --- |
| `monitoring/disk-monitor.sh` | Monitoring | Checks root filesystem usage against a threshold and prints a warning when usage is high. |
| `health-checks/system-health.sh` | Health checks | Prints host, uptime, memory, disk, and top process information for quick triage. |
| `cleanup/log-cleanup.sh` | Maintenance | Removes old `.log` files from `/var/log` based on a retention period. |
| `backups/backup-home-directory.sh` | Backup | Creates a timestamped compressed backup of the current user's home directory. |

## Example Commands

Run the disk monitor:

```bash
bash monitoring/disk-monitor.sh
```

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

## Documentation

- [Script catalog](scripts/README.md)
- [Usage guide](docs/usage.md)
- [Kubernetes notes](docs/kubernetes-notes.md)

## Recruiter Signal

This repository is designed to show practical operations ability:

- Linux command-line fluency
- Shell scripting fundamentals
- Production maintenance awareness
- Safe automation habits
- Documentation that helps another engineer operate the toolkit

## Day 2 Commit

Recommended commit message:

```text
docs: establish linux automation toolkit foundation
```

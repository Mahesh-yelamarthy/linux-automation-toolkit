# Script Catalog

This document catalogs the automation scripts in the toolkit and defines how scripts should be organized as the repository grows.

## Current Scripts

| Script | Type | Primary Operator Question |
| --- | --- | --- |
| `monitoring/disk-monitor.sh` | Monitoring | Is the root filesystem close to a risky usage threshold? |
| `health-checks/system-health.sh` | Health check | What is the current high-level condition of the host? |
| `cleanup/log-cleanup.sh` | Maintenance | Can old log files be removed based on the configured retention period? |
| `backups/backup-home-directory.sh` | Backup | Can the user's home directory be archived with a timestamped filename? |

## Directory Conventions

Scripts are grouped by operational function:

| Directory | Intended Contents |
| --- | --- |
| `monitoring/` | Checks that measure system state and report warnings. |
| `health-checks/` | Scripts that summarize current host condition for triage. |
| `cleanup/` | Maintenance scripts that remove or rotate old files. |
| `backups/` | Backup and retention automation. |
| `scripts/` | Cross-toolkit documentation and future shared helpers. |

## Execution Standard

Every production-ready script should eventually include:

- A clear shebang
- Safe shell options where appropriate
- Configurable thresholds or paths
- Human-readable output
- Non-zero exit codes for failure conditions
- Minimal required permissions
- Comments only where behavior is not obvious
- Documentation that explains when and how to run it

## Safety Notes

Scripts that delete, rotate, or archive data should be reviewed before scheduled execution.

Before adding a script to cron:

1. Run it manually.
2. Confirm target paths.
3. Confirm the expected output.
4. Confirm failure behavior.
5. Redirect output to an operational log.
6. Document the owner and expected response.

## Planned Scripts

Future roadmap additions include:

- `process-monitor.sh`
- `memory-monitor.sh`
- `nginx-health-check.sh`
- `backup-rotation.sh`

These scripts will be added gradually in separate commits so the repository history looks like realistic operational development.

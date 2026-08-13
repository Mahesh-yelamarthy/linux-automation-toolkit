# Script Catalog

This document catalogs the automation scripts in the toolkit and defines how scripts should be organized as the repository grows.

## Current Scripts

| Script | Type | Primary Operator Question |
| --- | --- | --- |
| `monitoring/disk-monitor.sh` | Monitoring | Is the root filesystem close to a risky usage threshold? |
| `health-checks/system-health.sh` | Health check | What is the current high-level condition of the host? |
| `cleanup/log-cleanup.sh` | Maintenance | Can old log files be removed based on the configured retention period? |
| `backups/backup-home-directory.sh` | Backup | Can the user's home directory be archived with a timestamped filename? |
| `backups/backup-rotation.sh` | Backup | Which backup archives are old enough to rotate, and is the minimum keep policy protected? |
| `scripts/process-monitor.sh` | Monitoring | Which processes are consuming resources, and has a required process disappeared? |
| `scripts/memory-monitor.sh` | Monitoring | Is the host under sustained memory or swap pressure? |
| `scripts/nginx-health-check.sh` | Health check | Is the NGINX endpoint returning the expected status? |

## Directory Conventions

Scripts are grouped by operational function:

| Directory | Intended Contents |
| --- | --- |
| `monitoring/` | Checks that measure system state and report warnings. |
| `health-checks/` | Scripts that summarize current host condition for triage. |
| `cleanup/` | Maintenance scripts that remove or rotate old files. |
| `backups/` | Backup and retention automation. |
| `scripts/` | Standalone operational scripts and cross-toolkit documentation. |

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

The detailed repository standard is documented in:

```text
../docs/script-logging-and-safety-standards.md
```

Use that standard when adding scripts, changing exit codes, adding cron schedules, or introducing destructive actions.

## Safety Notes

Scripts that delete, rotate, or archive data should be reviewed before scheduled execution.

Before adding a script to cron:

1. Run it manually.
2. Confirm target paths.
3. Confirm the expected output.
4. Confirm failure behavior.
5. Redirect output to an operational log.
6. Document the owner and expected response.

The current cron example is stored at `../cron/linux-automation-toolkit.cron`. Treat it as a reviewed starting point, not a production drop-in.

## Troubleshooting Workflow

Use the scripts as evidence collectors during host incidents, not as isolated commands. A normal investigation should begin with host context, then move to the script that matches the symptom.

Recommended first pass:

```bash
bash ../health-checks/system-health.sh
./process-monitor.sh --cpu-threshold 85 --memory-threshold 75 --top 10
./memory-monitor.sh --used-threshold 85 --available-threshold 10 --swap-threshold 50 --top 10
./nginx-health-check.sh --url http://127.0.0.1/ --expected-status 200 --timeout 5 --require-process
```

See [the Linux troubleshooting guide](../docs/linux-troubleshooting-guide.md) for the full incident workflow, evidence checklist, and escalation criteria.

## Process Monitor

The process monitor is a read-only triage and alerting command for Linux hosts:

```bash
./scripts/process-monitor.sh --cpu-threshold 80 --memory-threshold 80 --top 10
```

To verify a critical process while checking resource usage:

```bash
./scripts/process-monitor.sh --require-process 'nginx: master'
```

Configuration can also be supplied with `CPU_THRESHOLD`, `MEMORY_THRESHOLD`, `TOP_COUNT`, and `PROCESS_PATTERN` environment variables. Command-line options take precedence.

| Exit Code | Meaning |
| --- | --- |
| `0` | No threshold or required-process violations. |
| `1` | An operational condition needs investigation. |
| `2` | Configuration, dependency, or platform error. |

See [the process monitor runbook](../docs/process-monitor-runbook.md) for triage and escalation procedures.

## Memory Monitor

The memory monitor is a read-only host pressure check for Linux systems:

```bash
./scripts/memory-monitor.sh --used-threshold 85 --available-threshold 10 --swap-threshold 50 --top 10
```

It reports memory totals, available memory, swap usage, and the highest resident-memory processes. It uses `MemAvailable` from `/proc/meminfo` as the primary pressure signal because `MemFree` alone is misleading on Linux hosts that use filesystem cache.

Configuration can also be supplied with `MEMORY_USED_THRESHOLD`, `MEMORY_AVAILABLE_THRESHOLD`, `SWAP_USED_THRESHOLD`, `TOP_COUNT`, and `CHECK_SWAP` environment variables. Command-line options take precedence.

| Exit Code | Meaning |
| --- | --- |
| `0` | No memory pressure thresholds crossed. |
| `1` | Memory or swap pressure needs investigation. |
| `2` | Configuration, dependency, or platform error. |

See [the memory monitor runbook](../docs/memory-monitor-runbook.md) for triage and escalation procedures.

## NGINX Health Check

The NGINX health check validates an HTTP endpoint and can optionally verify that an NGINX process is present:

```bash
./scripts/nginx-health-check.sh --url http://127.0.0.1/ --expected-status 200 --timeout 5 --require-process
```

Configuration can also be supplied with `URL`, `EXPECTED_STATUS`, `TIMEOUT_SECONDS`, `REQUIRE_PROCESS`, `PROCESS_PATTERN`, and `SERVICE_NAME` environment variables. Command-line options take precedence.

| Exit Code | Meaning |
| --- | --- |
| `0` | Endpoint returned the expected status and required process checks passed. |
| `1` | Endpoint or process check failed. |
| `2` | Configuration or dependency error. |

See [the NGINX health check runbook](../docs/nginx-health-check-runbook.md) for triage and escalation procedures.

## Backup Rotation

The backup rotation script is a guarded retention tool for backup archive directories:

```bash
./backups/backup-rotation.sh --backup-dir /var/backups/app --retention-days 14 --min-keep 3 --pattern '*.tar.gz' --dry-run
```

The script runs in dry-run mode by default and requires `--delete` before files are removed. It refuses broad system paths and always preserves the configured minimum number of matching backup files.

| Exit Code | Meaning |
| --- | --- |
| `0` | Rotation completed, skipped safely, or dry-run completed. |
| `1` | No matching backup files were found and operator review is needed. |
| `2` | Invalid configuration, dependency, permission, or unsafe target. |

See [the backup rotation runbook](../docs/backup-rotation-runbook.md) for triage and scheduling guidance.

## Planned Scripts

Future roadmap additions will continue to expand reliability documentation and production maintenance examples in separate commits so the repository history looks like realistic operational development.

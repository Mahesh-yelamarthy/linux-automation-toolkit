# Cron Scheduling Guide

This guide documents production-oriented cron examples for the Linux Automation Toolkit.

The examples are intentionally conservative. They use explicit paths, predictable schedules, and log redirection so an operator can audit unattended runs.

## Example File

```text
cron/linux-automation-toolkit.cron
```

## Installation Pattern

Review the file before installing:

```bash
sed -n '1,200p' cron/linux-automation-toolkit.cron
```

Install for the current user:

```bash
crontab cron/linux-automation-toolkit.cron
```

Verify installation:

```bash
crontab -l
```

For production systems, prefer a dedicated service account with only the permissions required by the scheduled scripts.

## Required Customization

Before installing, update:

| Setting | Purpose |
| --- | --- |
| `TOOLKIT_HOME` | Absolute path to the checked-out toolkit on the host. |
| `LOG_FILE` | Operational log path for cron output. |
| Thresholds | CPU, memory, swap, and endpoint thresholds for the host role. |
| Backup path | Directory and pattern used by backup rotation. |
| Schedule | Frequency aligned with operational urgency and host load. |

Do not install the example unchanged on a production host.

## Schedule Rationale

| Job | Frequency | Reason |
| --- | --- | --- |
| Process monitor | Every 5 minutes | Detect missing critical processes and high CPU or memory consumers quickly. |
| Memory monitor | Every 10 minutes | Catch sustained memory pressure without generating excessive logs. |
| NGINX health check | Every 2 minutes | Detect endpoint failure quickly for a local web service. |
| Backup rotation | Daily | Retention cleanup does not need high frequency. |
| System health snapshot | Weekly | Useful for periodic trend review and manual inspection. |

## Safety Controls

Cron jobs should be treated as production automation.

Before enabling:

1. Run every command manually.
2. Confirm every script exits with expected status codes.
3. Confirm log files are writable by the cron user.
4. Confirm destructive operations are explicitly intended.
5. Confirm runbooks explain what to do when a job fails.
6. Confirm alerts or log forwarding exist if cron failures need immediate response.

The backup rotation example uses `--delete`. Operators should run the same command with `--dry-run` before enabling that schedule.

## Logging

The example appends all output to:

```text
/var/log/linux-automation-toolkit.log
```

For production, configure log rotation:

```text
/etc/logrotate.d/linux-automation-toolkit
```

At minimum, review log growth after the first day of scheduled execution.

## Failure Review

When a cron job fails:

```bash
grep -i -E 'error|warn|failed' /var/log/linux-automation-toolkit.log
tail -100 /var/log/linux-automation-toolkit.log
```

Then check:

- The cron user has the required permissions.
- `TOOLKIT_HOME` points to the correct directory.
- Required commands are available in cron's `PATH`.
- The target process, endpoint, or backup directory exists.
- The host time zone matches scheduling expectations.

Update thresholds or schedules only after confirming the failure mode is understood.

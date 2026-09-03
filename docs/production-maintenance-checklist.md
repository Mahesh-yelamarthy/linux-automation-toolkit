# Production Linux Maintenance Checklist

This checklist defines recurring maintenance practices for Linux hosts supported by the Linux Automation Toolkit. It is written for SRE, DevOps, and infrastructure engineers who need repeatable checks that reduce incident risk without creating unsafe automation.

## Purpose

Production maintenance should confirm that hosts remain observable, recoverable, and operationally safe. The goal is not to run commands mechanically. The goal is to identify drift, stale automation, missing evidence, and capacity risk before they become incidents.

Use this checklist for:

- Weekly host health reviews.
- Monthly automation and runbook reviews.
- Pre-maintenance checks before patching or cleanup.
- Post-incident follow-up when Linux host behavior contributed to impact.
- Handoff between operators or teams.

## Maintenance Principles

- Prefer read-only checks before any destructive action.
- Capture timestamped evidence for review.
- Validate scripts manually before scheduling them.
- Keep cleanup and rotation actions scoped to approved paths.
- Treat repeated warnings as engineering work, not background noise.
- Update runbooks when responders had to discover missing commands or decisions.

## Weekly Host Health Review

Run these checks on representative hosts or hosts with recent alerts.

| Check | Command or Reference | Expected Outcome |
| --- | --- | --- |
| System snapshot | `bash health-checks/system-health.sh` | Host, uptime, memory, disk, and top process data are available. |
| Process pressure | `./scripts/process-monitor.sh --cpu-threshold 85 --memory-threshold 75 --top 10` | No sustained unexpected CPU or memory consumers. |
| Memory pressure | `./scripts/memory-monitor.sh --used-threshold 85 --available-threshold 10 --swap-threshold 50 --top 10` | Available memory and swap usage remain within thresholds. |
| Disk pressure | `bash monitoring/disk-monitor.sh` | Root filesystem usage stays below the configured threshold. |
| Web endpoint | `./scripts/nginx-health-check.sh --url http://127.0.0.1/ --expected-status 200 --timeout 5 --require-process` | Local NGINX process and endpoint respond as expected. |
| Cron schedule | `crontab -l` and `cron/linux-automation-toolkit.cron` | Scheduled commands match reviewed paths and thresholds. |
| Script logs | Configured toolkit log file | Cron output exists and failures are not silently discarded. |

Record warnings with host, command, exit code, timestamp, and owner.

## Monthly Automation Review

Review automation behavior before it drifts from production reality.

| Area | Review Question | Action If Failed |
| --- | --- | --- |
| Thresholds | Do CPU, memory, swap, and disk thresholds match current host behavior? | Tune thresholds with evidence from recent alerts and capacity trends. |
| Required processes | Are required process names still correct after package or service changes? | Update cron arguments and runbooks together. |
| Backup retention | Does `backup-rotation.sh --dry-run` preserve enough restore points? | Adjust retention days, minimum keep count, or backup pattern. |
| Cleanup safety | Are cleanup scripts limited to approved log paths? | Stop scheduling destructive cleanup until path ownership is confirmed. |
| Permissions | Are scripts running with the minimum required privileges? | Remove unnecessary root execution or document the reason. |
| Logging | Are unattended runs captured in a searchable log destination? | Fix redirection or system logging before relying on cron. |
| Runbooks | Do runbook commands still work on supported hosts? | Update the runbook in the same change as script or schedule updates. |

## Pre-Maintenance Checks

Before patching, cleanup, backup rotation, or service restarts:

1. Confirm the host and environment.
2. Confirm recent alerts and active incidents.
3. Capture baseline state.
4. Confirm backup availability if the action can affect data or configuration.
5. Run destructive scripts in dry-run mode when supported.
6. Confirm rollback or recovery steps.
7. Notify the owning team when maintenance can affect service availability.

Recommended baseline commands:

```bash
hostname -f
date -u
uptime
who
df -h
free -m
ps -eo pid,ppid,user,stat,pcpu,pmem,etime,comm --sort=-pcpu | head -20
systemctl list-units --failed --no-pager
```

For backup cleanup, preview rotation before deletion:

```bash
./backups/backup-rotation.sh \
  --backup-dir /var/backups/app \
  --retention-days 14 \
  --min-keep 3 \
  --pattern '*.tar.gz' \
  --dry-run
```

## Post-Maintenance Validation

After maintenance:

| Validation | Command or Reference |
| --- | --- |
| Host remains responsive | `uptime`, `who`, SSH session check. |
| Critical services are running | `systemctl list-units --failed --no-pager`. |
| Endpoint is healthy | `./scripts/nginx-health-check.sh --url http://127.0.0.1/ --expected-status 200 --timeout 5 --require-process`. |
| Disk pressure did not worsen | `df -h` and `bash monitoring/disk-monitor.sh`. |
| Memory pressure did not worsen | `./scripts/memory-monitor.sh --used-threshold 85 --available-threshold 10 --swap-threshold 50 --top 10`. |
| Scheduled automation still works | Manual execution of the cron command with the same arguments. |
| Evidence is captured | Maintenance note includes commands, exit codes, and operator. |

Do not close maintenance until the validation result is recorded.

## Incident Follow-Up Review

After a Linux host incident, use this checklist to identify operational improvements:

- Was detection early enough?
- Did the relevant script produce useful output?
- Was the threshold too sensitive or too slow?
- Did cron capture enough logs for investigation?
- Was a dry-run mode available before destructive action?
- Did the runbook explain safe mitigation and escalation?
- Did the same symptom occur before without follow-up?

Create follow-up work for script improvements, threshold tuning, documentation updates, or service ownership gaps.

## Evidence Template

```text
Date:
Host:
Environment:
Operator:
Maintenance type:
Reason:

Baseline checks:
- Command:
- Exit code:
- Result:

Action taken:
- Command:
- Exit code:
- Result:

Post-maintenance validation:
- Command:
- Exit code:
- Result:

Follow-up:
- Owner:
- Due date:
- Risk if not completed:
```

## Readiness Checklist

The Linux maintenance process is production-ready when:

- Read-only health checks are run before risky actions.
- Backup and cleanup scripts have dry-run review paths.
- Cron output is captured and reviewed.
- Thresholds are reviewed against real host behavior.
- Runbooks are updated after incidents and maintenance findings.
- Destructive actions require explicit operator intent.
- Maintenance notes include enough evidence for another engineer to audit the change.


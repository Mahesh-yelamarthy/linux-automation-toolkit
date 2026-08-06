# Linux Troubleshooting Guide

This guide provides a production-oriented workflow for investigating Linux host incidents. It is written for SRE, DevOps, and infrastructure engineers who need to move from alert to evidence, decision, mitigation, and follow-up without guessing.

## When to Use This Guide

Use this guide when a host shows symptoms such as:

- High CPU usage
- Memory or swap pressure
- Disk pressure
- NGINX endpoint failures
- Missing critical processes
- Failed backup or cleanup automation
- Cron job failures
- Slow or unreachable services

The goal is not to run every command every time. The goal is to capture enough signal to identify the safest next action.

## First Five Minutes

Start with context. Capture host identity, time, load, sessions, process pressure, disk state, and memory state before changing anything.

```bash
hostname -f
date -u
uptime
who
ps -eo pid,ppid,user,stat,pcpu,pmem,comm --sort=-pcpu | head -15
df -h
free -m
```

If the host is degraded but accessible, collect toolkit output:

```bash
bash health-checks/system-health.sh

./scripts/process-monitor.sh \
  --cpu-threshold 85 \
  --memory-threshold 75 \
  --top 10

./scripts/memory-monitor.sh \
  --used-threshold 85 \
  --available-threshold 10 \
  --swap-threshold 50 \
  --top 10
```

For web hosts running NGINX:

```bash
./scripts/nginx-health-check.sh \
  --url http://127.0.0.1/ \
  --expected-status 200 \
  --timeout 5 \
  --require-process
```

Save command output in the incident notes with the timestamp, hostname, command, exit code, and operator name.

## Triage Decision Table

| Symptom | Primary Checks | Likely Next Action |
| --- | --- | --- |
| High CPU | `uptime`, `top`, `ps --sort=-pcpu`, `process-monitor.sh` | Identify runaway process, recent deploy, or traffic spike. |
| High memory | `free -m`, `/proc/meminfo`, `memory-monitor.sh`, `dmesg` | Find high RSS processes and check for OOM activity. |
| Disk pressure | `df -h`, `du -xh`, log locations, backup directories | Remove known safe files or rotate data through approved process. |
| NGINX unhealthy | `nginx-health-check.sh`, `systemctl status nginx`, `journalctl -u nginx` | Confirm process, config validity, backend reachability, and recent changes. |
| Missing process | `process-monitor.sh --require-process`, `systemctl status` | Restart only after checking logs and dependency health. |
| Cron failure | `crontab -l`, cron logs, script logs, manual run | Verify environment, paths, permissions, and command exit code. |
| Backup rotation issue | `backup-rotation.sh --dry-run`, target directory review | Confirm path safety, retention policy, and expected file pattern. |

## CPU Pressure

CPU pressure is risky when load stays high and user-facing latency or background job delays are visible.

Recommended checks:

```bash
uptime
ps -eo pid,ppid,user,stat,pcpu,pmem,etime,comm --sort=-pcpu | head -20
top -o %CPU
```

If `pidstat` is installed, sample CPU by process:

```bash
pidstat 1 5
```

Questions to answer:

- Is one process consuming most of the CPU?
- Is load average high compared with available CPU cores?
- Did the issue begin after a deployment, cron job, backup, or batch job?
- Is the process in a restart loop?
- Is the CPU use expected because of traffic or unexpected because of a bug?

Safe response pattern:

1. Capture process evidence.
2. Check service logs and recent deploy history.
3. Reduce traffic, pause a job, or roll back only if the cause is clear.
4. Escalate before killing critical processes when customer impact or data loss risk is unknown.

## Memory and Swap Pressure

Linux memory investigations should use available memory, not only free memory. Filesystem cache can make free memory look low even when the host is healthy.

Recommended checks:

```bash
free -m
cat /proc/meminfo | sed -n '1,20p'
ps -eo pid,ppid,user,stat,rss,pmem,comm --sort=-rss | head -20
dmesg -T | grep -i 'out of memory\|oom' | tail -20
journalctl -k --since '2 hours ago' | grep -i 'out of memory\|oom' | tail -20
```

Toolkit check:

```bash
./scripts/memory-monitor.sh --used-threshold 85 --available-threshold 10 --swap-threshold 50 --top 10
```

Questions to answer:

- Is memory pressure sustained or temporary?
- Is swap usage increasing?
- Did the kernel kill a process through OOM killer?
- Is the top memory process expected for this host role?
- Did a deploy or configuration change increase memory footprint?

Avoid clearing caches as a first response. It can hide the symptom and create additional disk I/O pressure without fixing the cause.

## Disk Pressure

Disk incidents become urgent when root, application data, logs, or database volumes approach full capacity.

Recommended checks:

```bash
df -h
df -ih
du -xh /var/log 2>/dev/null | sort -h | tail -20
du -xh /var/backups 2>/dev/null | sort -h | tail -20
find /var/log -type f -name '*.log' -mtime +14 -print 2>/dev/null | head -50
```

Safe response pattern:

1. Identify the full filesystem.
2. Identify the largest directories on that filesystem.
3. Confirm whether files are logs, caches, backups, application data, or unknown files.
4. Use approved cleanup or rotation automation when available.
5. Do not delete unknown files from application, database, or system directories during an incident without owner approval.

Toolkit cleanup references:

```bash
bash cleanup/log-cleanup.sh

./backups/backup-rotation.sh \
  --backup-dir /var/backups/app \
  --retention-days 14 \
  --min-keep 3 \
  --pattern '*.tar.gz' \
  --dry-run
```

Run destructive cleanup only after reviewing the target path and retention behavior.

## Service and NGINX Failures

For systemd-managed services:

```bash
systemctl status nginx --no-pager
journalctl -u nginx --since '1 hour ago' --no-pager
systemctl list-units --failed --no-pager
```

For listening ports and local endpoint checks:

```bash
ss -lntp
curl -I --max-time 5 http://127.0.0.1/
```

For NGINX specifically:

```bash
nginx -t
./scripts/nginx-health-check.sh --url http://127.0.0.1/ --expected-status 200 --timeout 5 --require-process
```

Questions to answer:

- Is the service process running?
- Is the service listening on the expected port?
- Is the endpoint failing locally or only through the load balancer?
- Are upstream dependencies healthy?
- Did configuration validation fail?
- Did certificates, DNS, firewall rules, or backend routes change?

Restarting a service can be valid, but capture logs first whenever possible.

## Network Connectivity

Use network checks when services are unreachable, slow, or failing dependency calls.

```bash
ip addr
ip route
ss -tuna
dig example.com
curl -v --max-time 10 https://example.com/
```

Questions to answer:

- Does the host have the expected address and route?
- Is DNS resolving correctly?
- Are connections stuck in a high number of `SYN-SENT`, `TIME-WAIT`, or `CLOSE-WAIT` states?
- Is failure local to one host, one subnet, one region, or one dependency?
- Is a firewall, security group, proxy, or certificate involved?

## Cron Job Failures

Cron failures often come from environment differences rather than script logic.

Checks:

```bash
crontab -l
grep CRON /var/log/syslog 2>/dev/null | tail -50
journalctl -u cron --since '24 hours ago' --no-pager 2>/dev/null
```

Manual validation:

```bash
bash -n scripts/process-monitor.sh
./scripts/process-monitor.sh --cpu-threshold 85 --memory-threshold 75 --top 10
```

Review the scheduled example in:

```text
cron/linux-automation-toolkit.cron
```

Cron troubleshooting checklist:

- Use absolute paths.
- Set expected environment variables inside the cron file.
- Redirect stdout and stderr to a log.
- Confirm the cron user has required permissions.
- Confirm the command succeeds outside cron with the same user.
- Check whether scripts rely on interactive shell configuration.

## Evidence to Capture

For a production incident, record:

- Alert name and timestamp
- Hostname and environment
- Customer or service impact
- Commands executed and exit codes
- Top process, memory, disk, or service evidence
- Mitigation taken
- Rollback or restart details
- Follow-up actions and owner

Example incident note:

```text
Timestamp: 2026-08-06T17:05:00Z
Host: app-01.example.internal
Symptom: NGINX endpoint returned 502 locally
Command: ./scripts/nginx-health-check.sh --url http://127.0.0.1/ --expected-status 200 --timeout 5 --require-process
Exit code: 1
Evidence: NGINX process running, endpoint returned 502, upstream app port not listening
Action: Escalated to application owner before restart
Follow-up: Add app port check to service runbook
```

## Escalation Criteria

Escalate when:

- Customer-facing impact is confirmed.
- Data loss, corruption, or security risk is possible.
- The host is unstable and mitigation may terminate active workloads.
- A database, queue, cache, or storage service is involved.
- The safe rollback path is unclear.
- The incident repeats after initial mitigation.

Escalation should include evidence, not only symptoms.

## Post-Incident Follow-Up

After recovery:

1. Confirm alerts have cleared.
2. Confirm service-level symptoms are resolved.
3. Document the root cause or most likely contributing factor.
4. Add missing checks, dashboards, runbooks, or cron logs.
5. Open a follow-up issue for prevention work.
6. Update this guide when a repeatable troubleshooting path is discovered.

Good troubleshooting leaves the next engineer with a shorter path to the answer.

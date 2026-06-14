# Process Monitor Runbook

## Purpose

Use this runbook when `scripts/process-monitor.sh` reports a process above its CPU or memory threshold, or when a required process is absent.

The monitor is diagnostic and read-only. It does not terminate, renice, or restart processes.

## Alert Conditions

The script returns exit code `1` when:

- A process CPU percentage is greater than or equal to the configured CPU threshold.
- A process memory percentage is greater than or equal to the configured memory threshold.
- `--require-process` is configured and no command line matches the pattern.

Exit code `2` indicates invalid configuration, a missing dependency, or an unsupported operating system.

## Initial Triage

1. Record the hostname, timestamp, thresholds, PID, user, and command from the monitor output.
2. Confirm whether the condition persists for several samples:

   ```bash
   for sample in 1 2 3; do
     ./scripts/process-monitor.sh --cpu-threshold 80 --memory-threshold 80 --top 10
     sleep 30
   done
   ```

3. Inspect the affected process without changing it:

   ```bash
   ps -p <PID> -o pid,ppid,user,stat,lstart,etime,pcpu,pmem,cmd
   ```

4. Check host-wide pressure:

   ```bash
   uptime
   free -m
   vmstat 1 5
   df -h
   ```

5. Review service state and recent logs when the PID belongs to a systemd unit:

   ```bash
   systemctl status <service> --no-pager
   journalctl -u <service> --since "30 minutes ago" --no-pager
   ```

## CPU Investigation

High CPU can be expected during batch work, traffic bursts, deployment warm-up, or scheduled maintenance. Investigate before intervening.

```bash
top -H -p <PID>
pidstat -p <PID> 1 10
ps -L -p <PID> -o pid,tid,psr,stat,pcpu,comm
```

Determine:

- Whether CPU usage is sustained or transient.
- Whether one thread is responsible.
- Whether latency, error rate, or queue depth is also increasing.
- Whether a deployment or configuration change preceded the event.
- Whether the process is constrained by a cgroup or container CPU limit.

## Memory Investigation

`ps` reports resident memory as a percentage of host memory. Validate the process footprint and host memory pressure:

```bash
grep -E 'VmRSS|VmSize|RssAnon|RssFile|Threads' /proc/<PID>/status
cat /proc/meminfo
vmstat 1 5
dmesg --ctime | grep -i -E 'oom|out of memory|killed process'
```

Determine:

- Whether resident memory continues to grow.
- Whether swap activity or reclaim is affecting latency.
- Whether the kernel has invoked the OOM killer.
- Whether application caches are bounded and expected.
- Whether a container or systemd memory limit is close to exhaustion.

## Missing Process Investigation

Confirm that the pattern is specific enough and inspect the service manager:

```bash
pgrep -af -- '<pattern>'
systemctl is-enabled <service>
systemctl status <service> --no-pager
journalctl -u <service> --since "30 minutes ago" --no-pager
```

Check deployment activity, dependency failures, invalid configuration, permission errors, and port conflicts before restarting the service.

## Mitigation

Choose the least disruptive action supported by the service runbook:

1. Remove unexpected load or pause non-critical batch work.
2. Scale traffic-serving capacity when redundancy and orchestration permit it.
3. Roll back a recent release if telemetry links the event to that change.
4. Restart only when the service owner has approved the action and redundancy is healthy.
5. Terminate a process only as a controlled incident action with the PID, impact, and authorization recorded.

Do not issue `kill -9` as a first response. It prevents graceful cleanup and can hide the original failure mode.

## Escalation

Escalate to the service owner or incident commander when:

- Customer-facing latency or errors breach an SLO.
- Memory growth is continuous or an OOM kill occurs.
- A critical process cannot remain running.
- The same process repeatedly crosses thresholds after mitigation.
- Remediation could reduce redundancy or cause data loss.

Include the monitor output, relevant logs, deployment history, duration, business impact, and actions already taken.

## Verification

After mitigation:

```bash
./scripts/process-monitor.sh \
  --cpu-threshold 80 \
  --memory-threshold 80 \
  --top 10 \
  --require-process '<critical-process-pattern>'
```

Verify:

- The command exits with status `0`.
- The critical process is present.
- Resource usage remains stable across multiple samples.
- Service health checks, latency, errors, and saturation have recovered.
- No new OOM, crash-loop, or dependency errors appear in logs.

## Follow-Up

Create a follow-up item when the incident reveals:

- Thresholds that do not reflect normal workload behavior.
- Missing application metrics or alerts.
- Unbounded concurrency, queues, caches, or memory growth.
- A service without documented restart and rollback procedures.
- Repeated manual mitigation that should become controlled automation.

# Memory Monitor Runbook

Use this runbook when `scripts/memory-monitor.sh` reports high used memory, low available memory, or high swap usage.

The monitor is diagnostic and read-only. It does not kill processes, clear caches, restart services, or change kernel settings.

## Alert Conditions

The script returns exit code `1` when:

- Used memory is greater than or equal to `MEMORY_USED_THRESHOLD`.
- Available memory is less than or equal to `MEMORY_AVAILABLE_THRESHOLD`.
- Swap usage is greater than or equal to `SWAP_USED_THRESHOLD` and swap checking is enabled.

Exit code `2` indicates invalid configuration, missing Linux runtime data, or a missing command dependency.

## Initial Triage

Capture the monitor output and confirm whether pressure is sustained:

```bash
for sample in 1 2 3; do
  ./scripts/memory-monitor.sh --used-threshold 85 --available-threshold 10 --swap-threshold 50
  sleep 30
done
```

Check host-wide memory state:

```bash
free -m
cat /proc/meminfo
vmstat 1 5
uptime
```

Review kernel messages for memory exhaustion:

```bash
dmesg --ctime | grep -i -E 'oom|out of memory|killed process'
```

## Identify Top Consumers

Use process-level inspection to confirm whether one workload is responsible:

```bash
ps -eo pid,ppid,user,stat,etimes,%mem,rss,cmd --sort=-rss | head -20
```

For a specific PID:

```bash
ps -p <PID> -o pid,ppid,user,stat,lstart,etime,%cpu,%mem,rss,vsz,cmd
grep -E 'VmRSS|VmSize|RssAnon|RssFile|Threads' /proc/<PID>/status
```

Determine:

- Whether memory growth is continuous.
- Whether memory is owned by one process, many processes, or filesystem cache.
- Whether the process recently changed version or configuration.
- Whether the workload is inside a container, cgroup, or systemd slice with a memory limit.
- Whether the kernel has already killed processes.

## Interpretation

High used memory is not always a problem on Linux. Linux intentionally uses memory for cache. `MemAvailable` is usually a better pressure signal than `MemFree`.

Treat the incident as higher severity when:

- `MemAvailable` remains low across multiple samples.
- Swap usage is increasing.
- `vmstat` shows sustained swap in or swap out activity.
- The OOM killer appears in `dmesg`.
- Application latency, errors, or queue depth are rising.

## Mitigation

Choose the least disruptive mitigation available:

1. Stop or pause non-critical batch work if it is consuming memory.
2. Scale the service horizontally when the platform supports it.
3. Roll back a release when memory growth follows a deployment.
4. Increase memory limits only after confirming expected workload behavior.
5. Restart a leaking service only when redundancy is healthy and the service owner approves.

Do not clear Linux page cache as a routine fix. It can hide the problem and may make performance worse.

## Escalation

Escalate to the service owner, platform owner, or incident commander when:

- User-facing symptoms are present.
- The OOM killer terminates a critical process.
- Available memory keeps falling after initial mitigation.
- Swap usage continues to grow.
- A restart or rollback could cause customer impact.
- The affected process owns stateful data or critical background work.

Include the monitor output, top process list, `vmstat` output, OOM evidence, recent deployments, and any mitigation already attempted.

## Verification

After mitigation:

```bash
./scripts/memory-monitor.sh --used-threshold 85 --available-threshold 10 --swap-threshold 50
```

Verify:

- The command exits with status `0`.
- `MemAvailable` remains stable across several samples.
- Swap activity is not increasing.
- No new OOM events appear.
- Application health, latency, and error rate have recovered.

## Follow-Up

Create a follow-up item when the incident reveals:

- Missing application memory metrics.
- Unbounded caches, queues, request concurrency, or batch size.
- Incorrect container or systemd memory limits.
- Lack of dashboards for memory saturation.
- Missing rollback or restart procedures for the affected service.

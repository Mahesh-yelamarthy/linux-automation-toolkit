# NGINX Health Check Runbook

Use this runbook when `scripts/nginx-health-check.sh` reports an unexpected HTTP status, request failure, timeout, or missing NGINX process.

The health check is diagnostic and read-only. It does not reload, restart, or modify NGINX.

## Alert Conditions

The script returns exit code `1` when:

- The endpoint cannot be reached before the timeout.
- The endpoint returns a status code different from the expected status.
- `--require-process` is enabled and no process matches the configured pattern.

Exit code `2` indicates invalid configuration or a missing dependency.

## Initial Triage

Capture the check output and repeat the request from the host:

```bash
./scripts/nginx-health-check.sh --url http://127.0.0.1/ --expected-status 200 --timeout 5
curl -v --max-time 5 http://127.0.0.1/
```

Check whether NGINX is running:

```bash
pgrep -af nginx
systemctl status nginx --no-pager
```

Review recent logs:

```bash
journalctl -u nginx --since "30 minutes ago" --no-pager
tail -100 /var/log/nginx/error.log
tail -100 /var/log/nginx/access.log
```

## Configuration Validation

Validate NGINX configuration before any reload:

```bash
nginx -t
```

Check common configuration issues:

- Invalid server block syntax.
- Incorrect listen port.
- Missing upstream target.
- Certificate or key path errors.
- File permission problems for static content, logs, or certificates.

## Network and Port Checks

Confirm the service is listening:

```bash
ss -ltnp | grep -E ':80|:443|:8080'
```

If the process is running but requests fail, check:

- Local firewall rules.
- Container or host port mapping.
- Reverse proxy upstream availability.
- DNS resolution when using a hostname.
- TLS handshake failures for HTTPS endpoints.

## HTTP Status Interpretation

| Status | Likely Cause |
| --- | --- |
| `000` | Connection failure, timeout, DNS failure, or TLS failure. |
| `301` / `302` | Redirect expected by config, or wrong URL checked. |
| `403` | Permission issue, denied location block, or missing index file. |
| `404` | Wrong document root, missing file, or wrong location block. |
| `499` / `502` / `503` / `504` | Upstream failure, timeout, or backend unavailable. |

Use the expected status intentionally. A redirect may be healthy for one endpoint and wrong for another.

## Mitigation

Choose the least disruptive action:

1. Restore missing static files or corrected permissions.
2. Fix upstream service availability.
3. Roll back the NGINX configuration change if the failure followed a deployment.
4. Reload NGINX only after `nginx -t` succeeds:

   ```bash
   systemctl reload nginx
   ```

5. Restart NGINX only when reload is insufficient and the service owner accepts the impact.

## Escalation

Escalate when:

- The endpoint is customer-facing.
- Multiple instances are failing.
- Upstream applications are unavailable.
- TLS certificates or keys are invalid or expired.
- Reload or restart could interrupt production traffic.

Include the health-check output, `curl -v` output, `nginx -t`, recent logs, recent deployments, and any mitigation already attempted.

## Verification

After mitigation:

```bash
./scripts/nginx-health-check.sh \
  --url http://127.0.0.1/ \
  --expected-status 200 \
  --timeout 5 \
  --require-process
```

Verify:

- The script exits with status `0`.
- The expected HTTP status is returned.
- NGINX process checks pass when enabled.
- Access and error logs show normal request behavior.
- External load balancer or monitoring checks recover.

## Follow-Up

Create a follow-up item when the incident reveals:

- Missing endpoint monitoring.
- Missing NGINX config validation in CI.
- Unclear ownership of NGINX routes or upstreams.
- Incomplete rollback instructions.
- Repeated manual remediation that should become deployment automation.

# Script Logging and Safety Standards

This document defines production standards for Linux automation scripts in this repository. The goal is to make every script predictable during interactive use, cron execution, incident response, and code review.

## Scope

Use these standards for:

- Monitoring checks
- Health checks
- Backup and rotation scripts
- Cleanup scripts
- Future maintenance automation
- Cron-managed operational jobs

Scripts do not need to be complex. They do need to fail clearly, avoid unsafe defaults, and produce enough evidence for another engineer to understand what happened.

## Required Script Contract

Every production-ready script should define:

| Requirement | Standard |
| --- | --- |
| Interpreter | Use `#!/usr/bin/env bash` unless POSIX shell compatibility is intentional. |
| Shell safety | Use strict mode where practical, usually `set -uo pipefail`. |
| Inputs | Support command-line flags and environment variable overrides for operational settings. |
| Validation | Validate required commands, paths, thresholds, and destructive options before work begins. |
| Logging | Print timestamped, human-readable operational messages. |
| Exit codes | Return stable exit codes documented in the script runbook. |
| Dry-run | Default to dry-run for destructive actions when practical. |
| Ownership | Document when the script should run and who should respond to failures. |

## Exit Code Standard

Use consistent exit codes across the toolkit:

| Exit Code | Meaning | Operator Response |
| --- | --- | --- |
| `0` | Script completed successfully or no alert condition was found. | Record success or continue normal operation. |
| `1` | Operational condition needs investigation. | Review output, run the relevant runbook, and escalate if impact is possible. |
| `2` | Invalid configuration, missing dependency, unsafe input, or unsupported platform. | Fix script invocation or host prerequisites before retrying. |

Do not use random exit codes unless a dependency command requires preserving its exact status for a documented reason.

## Logging Standard

Log lines should include:

- UTC timestamp
- Severity
- Short message
- Key operational values when useful

Recommended Bash helper:

```bash
log() {
  printf '%s [%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" "$2"
}
```

Example output:

```text
2026-08-13T01:42:00Z [INFO] Memory check started
2026-08-13T01:42:00Z [WARN] Memory used threshold exceeded: used=91 threshold=85
2026-08-13T01:42:00Z [INFO] Memory check completed
```

Use these severity labels:

| Severity | Use For |
| --- | --- |
| `INFO` | Normal progress, configuration summary, successful completion. |
| `WARN` | Operational condition that may need review. |
| `ERROR` | Failed command, invalid input, unsafe state, or alert condition that should stop execution. |
| `DEBUG` | Optional detailed output enabled only when requested. |

Avoid noisy logs. A script running every five minutes should not produce pages of output unless there is an alert condition.

## Input Validation

Validate inputs before changing state.

Required checks:

- Numeric thresholds are positive integers.
- Percent thresholds are between `1` and `100`.
- Required paths exist before reading from them.
- Parent directories exist before writing output.
- Required commands are installed.
- Destructive actions require explicit flags.

Example validation pattern:

```bash
is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

if ! is_positive_integer "$RETENTION_DAYS"; then
  log ERROR "RETENTION_DAYS must be a positive integer"
  exit 2
fi
```

## Destructive Action Controls

Scripts that delete, rotate, overwrite, or archive data need additional safeguards.

Required controls:

- Dry-run default or explicit preview mode.
- Explicit destructive flag such as `--delete`.
- Refuse broad system paths such as `/`, `/var`, `/home`, and `/tmp` unless the script is specifically designed for them.
- Preserve a minimum number of known-good files when rotating backups.
- Print target path, retention policy, and match pattern before deleting.
- Refuse to run when the target path is empty or unexpectedly broad.

Destructive scripts should make the safe action easy and the risky action deliberate.

## Cron Execution Standard

Cron jobs run with a minimal environment. Scripts intended for cron should:

- Use absolute paths in the cron file.
- Set required environment variables explicitly.
- Redirect stdout and stderr to an operational log.
- Avoid relying on interactive shell profiles.
- Produce concise output during success.
- Produce actionable output during failure.
- Use stable exit codes so monitoring can detect failures.

Example:

```cron
*/5 * * * * TOOLKIT_HOME=/opt/linux-automation-toolkit /opt/linux-automation-toolkit/scripts/process-monitor.sh --cpu-threshold 85 --memory-threshold 75 >> /var/log/linux-automation-toolkit.log 2>&1
```

See `docs/cron-scheduling.md` for scheduling policy and failure review.

## Runtime Safety

Use these runtime practices:

- Quote variables unless word splitting is intended.
- Prefer arrays for command construction when arguments may contain spaces.
- Use `mktemp` for temporary files.
- Clean up temporary files with `trap` when needed.
- Do not parse human-formatted command output when a structured source exists.
- Avoid hidden network calls in scripts that appear local-only.
- Do not print secrets, tokens, credentials, or private paths.

Recommended temporary file pattern:

```bash
tmp_file="$(mktemp)"
cleanup() {
  rm -f "$tmp_file"
}
trap cleanup EXIT
```

## Configuration Pattern

Prefer this order of precedence:

1. Command-line flag
2. Environment variable
3. Safe default

Document the supported environment variables in the script help text and runbook.

Example:

```bash
CPU_THRESHOLD="${CPU_THRESHOLD:-85}"

while (( $# > 0 )); do
  case "$1" in
    --cpu-threshold)
      CPU_THRESHOLD="$2"
      shift 2
      ;;
  esac
done
```

## Review Checklist

Before committing a new script or changing an existing one:

1. Run `bash -n` on the script.
2. Run the script with `--help` if supported.
3. Test a success path.
4. Test a failure path.
5. Test invalid input.
6. Confirm exit codes match the runbook.
7. Confirm cron usage is documented if the script is scheduled.
8. Confirm destructive behavior requires deliberate operator action.
9. Confirm output contains enough context for incident notes.
10. Update `scripts/README.md` and the relevant runbook.

## Current Toolkit Alignment

| Script | Current Safety Pattern |
| --- | --- |
| `scripts/process-monitor.sh` | Read-only monitoring, threshold validation, required-process checks, documented exit codes. |
| `scripts/memory-monitor.sh` | Read-only pressure check, Linux platform validation, configurable thresholds, documented exit codes. |
| `scripts/nginx-health-check.sh` | Endpoint validation, timeout control, optional process check, dependency validation. |
| `backups/backup-rotation.sh` | Dry-run default, explicit delete flag, target path safeguards, minimum keep policy. |
| `cleanup/log-cleanup.sh` | Simple retention cleanup that should be reviewed before production scheduling. |
| `health-checks/system-health.sh` | Read-only context capture for host triage. |

Future script changes should move older simple scripts toward the same standards used by the newer toolkit commands.

## Incident Response Expectations

When a script reports an operational failure:

1. Capture the full command and output.
2. Record hostname, user, timestamp, and exit code.
3. Re-run manually only if it is safe.
4. Use the relevant runbook or troubleshooting guide.
5. Escalate when customer impact, data loss, or repeated failure is possible.
6. Add a follow-up if the script output was unclear or incomplete.

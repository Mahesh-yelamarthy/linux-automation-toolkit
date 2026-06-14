#!/usr/bin/env bash

set -uo pipefail

CPU_THRESHOLD="${CPU_THRESHOLD:-80}"
MEMORY_THRESHOLD="${MEMORY_THRESHOLD:-80}"
TOP_COUNT="${TOP_COUNT:-10}"
PROCESS_PATTERN="${PROCESS_PATTERN:-}"

usage() {
  cat <<'EOF'
Usage: process-monitor.sh [options]

Inspect Linux processes and return a non-zero status when a threshold is crossed.

Options:
  --cpu-threshold PERCENT     CPU usage threshold (default: 80)
  --memory-threshold PERCENT  Memory usage threshold (default: 80)
  --top COUNT                 Number of processes in each ranking (default: 10)
  --require-process PATTERN   Alert when no process command matches PATTERN
  -h, --help                  Show this help message

Environment variables:
  CPU_THRESHOLD, MEMORY_THRESHOLD, TOP_COUNT, PROCESS_PATTERN

Exit codes:
  0  No threshold or required-process violations
  1  One or more operational violations detected
  2  Invalid configuration or unsupported runtime
EOF
}

log() {
  printf '%s [%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" "$2"
}

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

is_percentage() {
  is_positive_integer "$1" && (( 10#$1 <= 100 ))
}

while (( $# > 0 )); do
  case "$1" in
    --cpu-threshold)
      [[ $# -ge 2 ]] || { log ERROR "--cpu-threshold requires a value"; exit 2; }
      CPU_THRESHOLD="$2"
      shift 2
      ;;
    --memory-threshold)
      [[ $# -ge 2 ]] || { log ERROR "--memory-threshold requires a value"; exit 2; }
      MEMORY_THRESHOLD="$2"
      shift 2
      ;;
    --top)
      [[ $# -ge 2 ]] || { log ERROR "--top requires a value"; exit 2; }
      TOP_COUNT="$2"
      shift 2
      ;;
    --require-process)
      [[ $# -ge 2 ]] || { log ERROR "--require-process requires a value"; exit 2; }
      PROCESS_PATTERN="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log ERROR "Unknown option: $1"
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$(uname -s)" != "Linux" ]]; then
  log ERROR "This monitor requires Linux procps-compatible ps output"
  exit 2
fi

for command_name in ps awk sort head hostname mktemp; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    log ERROR "Required command is unavailable: $command_name"
    exit 2
  fi
done

if ! is_percentage "$CPU_THRESHOLD"; then
  log ERROR "CPU threshold must be an integer from 1 through 100"
  exit 2
fi

if ! is_percentage "$MEMORY_THRESHOLD"; then
  log ERROR "Memory threshold must be an integer from 1 through 100"
  exit 2
fi

if ! is_positive_integer "$TOP_COUNT"; then
  log ERROR "Top process count must be a positive integer"
  exit 2
fi

if ! snapshot_file="$(mktemp)"; then
  log ERROR "Unable to create a temporary process snapshot"
  exit 2
fi
trap 'rm -f "$snapshot_file"' EXIT

if ! ps -eo pid=,ppid=,user=,stat=,etimes=,pcpu=,pmem=,comm=,args= >"$snapshot_file"; then
  log ERROR "Unable to collect the process snapshot"
  exit 2
fi

host_name="$(hostname -f 2>/dev/null || hostname)"
log INFO "Process health check started on ${host_name}"
printf 'Thresholds: CPU >= %s%% | memory >= %s%%\n' "$CPU_THRESHOLD" "$MEMORY_THRESHOLD"

printf '\nTop %s processes by CPU:\n' "$TOP_COUNT"
printf '%-8s %-12s %8s %8s  %s\n' "PID" "USER" "CPU%" "MEM%" "COMMAND"
awk '{ printf "%-8s %-12s %8s %8s  %s\n", $1, $3, $6, $7, $8 }' "$snapshot_file" \
  | sort -k3,3nr \
  | head -n "$TOP_COUNT"

printf '\nTop %s processes by memory:\n' "$TOP_COUNT"
printf '%-8s %-12s %8s %8s  %s\n' "PID" "USER" "CPU%" "MEM%" "COMMAND"
awk '{ printf "%-8s %-12s %8s %8s  %s\n", $1, $3, $6, $7, $8 }' "$snapshot_file" \
  | sort -k4,4nr \
  | head -n "$TOP_COUNT"

if ! violations_file="$(mktemp)"; then
  log ERROR "Unable to create a temporary violations report"
  exit 2
fi
trap 'rm -f "$snapshot_file" "$violations_file"' EXIT

awk -v cpu="$CPU_THRESHOLD" -v memory="$MEMORY_THRESHOLD" '
  ($6 + 0) >= cpu || ($7 + 0) >= memory {
    printf "PID=%s USER=%s CPU=%s%% MEM=%s%% COMMAND=%s\n", $1, $3, $6, $7, $8
  }
' "$snapshot_file" >"$violations_file"

exit_code=0

if [[ -s "$violations_file" ]]; then
  printf '\nThreshold violations:\n'
  cat "$violations_file"
  log WARN "One or more processes crossed a configured threshold"
  exit_code=1
else
  log INFO "No process crossed a configured threshold"
fi

if [[ -n "$PROCESS_PATTERN" ]]; then
  if ! required_matches_file="$(mktemp)"; then
    log ERROR "Unable to create a temporary required-process report"
    exit 2
  fi
  trap 'rm -f "$snapshot_file" "$violations_file" "$required_matches_file"' EXIT

  printf '\nRequired process matches for pattern %q:\n' "$PROCESS_PATTERN"
  awk -v needle="$PROCESS_PATTERN" -v self_pid="$$" '
    $1 != self_pid {
      command_line = ""
      for (field = 8; field <= NF; field++) {
        command_line = command_line (command_line == "" ? "" : " ") $field
      }
      if (index(command_line, needle) > 0) {
        printf "PID=%s USER=%s COMMAND=%s\n", $1, $3, command_line
      }
    }
  ' "$snapshot_file" >"$required_matches_file"

  if [[ -s "$required_matches_file" ]]; then
    cat "$required_matches_file"
    log INFO "Required process pattern is present"
  else
    log WARN "No running process matched the required pattern"
    exit_code=1
  fi
fi

log INFO "Process health check completed with exit code ${exit_code}"
exit "$exit_code"

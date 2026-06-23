#!/usr/bin/env bash

set -uo pipefail

MEMORY_USED_THRESHOLD="${MEMORY_USED_THRESHOLD:-85}"
MEMORY_AVAILABLE_THRESHOLD="${MEMORY_AVAILABLE_THRESHOLD:-10}"
SWAP_USED_THRESHOLD="${SWAP_USED_THRESHOLD:-50}"
TOP_COUNT="${TOP_COUNT:-10}"
CHECK_SWAP="${CHECK_SWAP:-true}"

usage() {
  cat <<'EOF'
Usage: memory-monitor.sh [options]

Inspect Linux memory pressure and return a non-zero status when thresholds are crossed.

Options:
  --used-threshold PERCENT       Alert when used memory is at or above this percent (default: 85)
  --available-threshold PERCENT  Alert when available memory is at or below this percent (default: 10)
  --swap-threshold PERCENT       Alert when used swap is at or above this percent (default: 50)
  --top COUNT                    Number of memory-heavy processes to print (default: 10)
  --no-swap                      Disable swap usage alerting
  -h, --help                     Show this help message

Environment variables:
  MEMORY_USED_THRESHOLD, MEMORY_AVAILABLE_THRESHOLD, SWAP_USED_THRESHOLD, TOP_COUNT, CHECK_SWAP

Exit codes:
  0  No memory pressure thresholds crossed
  1  One or more memory pressure conditions detected
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

to_mib() {
  awk -v kib="$1" 'BEGIN { printf "%.0f", kib / 1024 }'
}

percent_of() {
  awk -v numerator="$1" -v denominator="$2" 'BEGIN {
    if (denominator <= 0) {
      print 0
    } else {
      printf "%.0f", (numerator / denominator) * 100
    }
  }'
}

while (( $# > 0 )); do
  case "$1" in
    --used-threshold)
      [[ $# -ge 2 ]] || { log ERROR "--used-threshold requires a value"; exit 2; }
      MEMORY_USED_THRESHOLD="$2"
      shift 2
      ;;
    --available-threshold)
      [[ $# -ge 2 ]] || { log ERROR "--available-threshold requires a value"; exit 2; }
      MEMORY_AVAILABLE_THRESHOLD="$2"
      shift 2
      ;;
    --swap-threshold)
      [[ $# -ge 2 ]] || { log ERROR "--swap-threshold requires a value"; exit 2; }
      SWAP_USED_THRESHOLD="$2"
      shift 2
      ;;
    --top)
      [[ $# -ge 2 ]] || { log ERROR "--top requires a value"; exit 2; }
      TOP_COUNT="$2"
      shift 2
      ;;
    --no-swap)
      CHECK_SWAP="false"
      shift
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
  log ERROR "This monitor requires Linux /proc/meminfo"
  exit 2
fi

for command_name in awk ps sort head hostname; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    log ERROR "Required command is unavailable: $command_name"
    exit 2
  fi
done

if [[ ! -r /proc/meminfo ]]; then
  log ERROR "/proc/meminfo is not readable"
  exit 2
fi

for threshold in "$MEMORY_USED_THRESHOLD" "$MEMORY_AVAILABLE_THRESHOLD" "$SWAP_USED_THRESHOLD"; do
  if ! is_percentage "$threshold"; then
    log ERROR "Threshold values must be integers from 1 through 100"
    exit 2
  fi
done

if ! is_positive_integer "$TOP_COUNT"; then
  log ERROR "Top process count must be a positive integer"
  exit 2
fi

if [[ "$CHECK_SWAP" != "true" && "$CHECK_SWAP" != "false" ]]; then
  log ERROR "CHECK_SWAP must be true or false"
  exit 2
fi

mem_total_kib="$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)"
mem_available_kib="$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo)"
mem_free_kib="$(awk '/^MemFree:/ { print $2 }' /proc/meminfo)"
buffers_kib="$(awk '/^Buffers:/ { print $2 }' /proc/meminfo)"
cached_kib="$(awk '/^Cached:/ { print $2 }' /proc/meminfo)"
swap_total_kib="$(awk '/^SwapTotal:/ { print $2 }' /proc/meminfo)"
swap_free_kib="$(awk '/^SwapFree:/ { print $2 }' /proc/meminfo)"

if [[ -z "$mem_total_kib" || -z "$mem_available_kib" ]]; then
  log ERROR "Unable to parse MemTotal or MemAvailable from /proc/meminfo"
  exit 2
fi

mem_used_kib=$(( mem_total_kib - mem_available_kib ))
swap_used_kib=$(( swap_total_kib - swap_free_kib ))

mem_used_percent="$(percent_of "$mem_used_kib" "$mem_total_kib")"
mem_available_percent="$(percent_of "$mem_available_kib" "$mem_total_kib")"
swap_used_percent="$(percent_of "$swap_used_kib" "$swap_total_kib")"

host_name="$(hostname -f 2>/dev/null || hostname)"
log INFO "Memory health check started on ${host_name}"
printf 'Thresholds: used >= %s%% | available <= %s%% | swap used >= %s%% | swap check=%s\n' \
  "$MEMORY_USED_THRESHOLD" "$MEMORY_AVAILABLE_THRESHOLD" "$SWAP_USED_THRESHOLD" "$CHECK_SWAP"

printf '\nMemory summary:\n'
printf '%-18s %12s MiB\n' "MemTotal" "$(to_mib "$mem_total_kib")"
printf '%-18s %12s MiB\n' "MemAvailable" "$(to_mib "$mem_available_kib")"
printf '%-18s %12s MiB\n' "MemUsed" "$(to_mib "$mem_used_kib")"
printf '%-18s %12s MiB\n' "MemFree" "$(to_mib "$mem_free_kib")"
printf '%-18s %12s MiB\n' "Buffers" "$(to_mib "$buffers_kib")"
printf '%-18s %12s MiB\n' "Cached" "$(to_mib "$cached_kib")"
printf '%-18s %12s%%\n' "MemUsedPercent" "$mem_used_percent"
printf '%-18s %12s%%\n' "MemAvailablePct" "$mem_available_percent"

printf '\nSwap summary:\n'
printf '%-18s %12s MiB\n' "SwapTotal" "$(to_mib "$swap_total_kib")"
printf '%-18s %12s MiB\n' "SwapUsed" "$(to_mib "$swap_used_kib")"
printf '%-18s %12s%%\n' "SwapUsedPercent" "$swap_used_percent"

printf '\nTop %s processes by resident memory:\n' "$TOP_COUNT"
printf '%-8s %-12s %8s %10s  %s\n' "PID" "USER" "MEM%" "RSS_MiB" "COMMAND"
ps -eo pid=,user=,pmem=,rss=,comm= --sort=-rss \
  | awk '{ printf "%-8s %-12s %8s %10.0f  %s\n", $1, $2, $3, $4 / 1024, $5 }' \
  | head -n "$TOP_COUNT"

exit_code=0

if (( 10#$mem_used_percent >= 10#$MEMORY_USED_THRESHOLD )); then
  log WARN "Used memory is at or above threshold: ${mem_used_percent}% >= ${MEMORY_USED_THRESHOLD}%"
  exit_code=1
fi

if (( 10#$mem_available_percent <= 10#$MEMORY_AVAILABLE_THRESHOLD )); then
  log WARN "Available memory is at or below threshold: ${mem_available_percent}% <= ${MEMORY_AVAILABLE_THRESHOLD}%"
  exit_code=1
fi

if [[ "$CHECK_SWAP" == "true" && "$swap_total_kib" -gt 0 && 10#$swap_used_percent -ge 10#$SWAP_USED_THRESHOLD ]]; then
  log WARN "Swap usage is at or above threshold: ${swap_used_percent}% >= ${SWAP_USED_THRESHOLD}%"
  exit_code=1
fi

if [[ "$CHECK_SWAP" == "true" && "$swap_total_kib" -eq 0 ]]; then
  log INFO "Swap is not configured on this host"
fi

if [[ "$exit_code" -eq 0 ]]; then
  log INFO "No memory pressure threshold was crossed"
else
  log WARN "One or more memory pressure conditions need investigation"
fi

log INFO "Memory health check completed with exit code ${exit_code}"
exit "$exit_code"

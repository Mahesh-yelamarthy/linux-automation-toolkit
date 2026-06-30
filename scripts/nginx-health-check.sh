#!/usr/bin/env bash

set -uo pipefail

URL="${URL:-http://127.0.0.1/}"
EXPECTED_STATUS="${EXPECTED_STATUS:-200}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-5}"
REQUIRE_PROCESS="${REQUIRE_PROCESS:-false}"
PROCESS_PATTERN="${PROCESS_PATTERN:-nginx}"
SERVICE_NAME="${SERVICE_NAME:-nginx}"

usage() {
  cat <<'EOF'
Usage: nginx-health-check.sh [options]

Validate an NGINX HTTP endpoint and optionally confirm that an NGINX process is running.

Options:
  --url URL                  Endpoint to check (default: http://127.0.0.1/)
  --expected-status CODE     Expected HTTP status code (default: 200)
  --timeout SECONDS          HTTP timeout in seconds (default: 5)
  --require-process          Alert if no process matches the configured pattern
  --process-pattern PATTERN  Process pattern used with --require-process (default: nginx)
  --service-name NAME        Service name shown in diagnostic commands (default: nginx)
  -h, --help                 Show this help message

Environment variables:
  URL, EXPECTED_STATUS, TIMEOUT_SECONDS, REQUIRE_PROCESS, PROCESS_PATTERN, SERVICE_NAME

Exit codes:
  0  Endpoint returned the expected status and required process checks passed
  1  Endpoint or process check failed
  2  Invalid configuration or missing dependency
EOF
}

log() {
  printf '%s [%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" "$2"
}

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

while (( $# > 0 )); do
  case "$1" in
    --url)
      [[ $# -ge 2 ]] || { log ERROR "--url requires a value"; exit 2; }
      URL="$2"
      shift 2
      ;;
    --expected-status)
      [[ $# -ge 2 ]] || { log ERROR "--expected-status requires a value"; exit 2; }
      EXPECTED_STATUS="$2"
      shift 2
      ;;
    --timeout)
      [[ $# -ge 2 ]] || { log ERROR "--timeout requires a value"; exit 2; }
      TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --require-process)
      REQUIRE_PROCESS="true"
      shift
      ;;
    --process-pattern)
      [[ $# -ge 2 ]] || { log ERROR "--process-pattern requires a value"; exit 2; }
      PROCESS_PATTERN="$2"
      shift 2
      ;;
    --service-name)
      [[ $# -ge 2 ]] || { log ERROR "--service-name requires a value"; exit 2; }
      SERVICE_NAME="$2"
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

if ! command -v curl >/dev/null 2>&1; then
  log ERROR "Required command is unavailable: curl"
  exit 2
fi

if ! is_positive_integer "$EXPECTED_STATUS"; then
  log ERROR "Expected status must be a positive integer"
  exit 2
fi

if ! is_positive_integer "$TIMEOUT_SECONDS"; then
  log ERROR "Timeout must be a positive integer"
  exit 2
fi

if [[ "$REQUIRE_PROCESS" != "true" && "$REQUIRE_PROCESS" != "false" ]]; then
  log ERROR "REQUIRE_PROCESS must be true or false"
  exit 2
fi

log INFO "NGINX health check started"
printf 'Endpoint: %s\n' "$URL"
printf 'Expected status: %s\n' "$EXPECTED_STATUS"
printf 'Timeout seconds: %s\n' "$TIMEOUT_SECONDS"

curl_output="$(
  curl \
    --silent \
    --show-error \
    --output /dev/null \
    --max-time "$TIMEOUT_SECONDS" \
    --write-out 'status=%{http_code} time_total=%{time_total} remote_ip=%{remote_ip}\n' \
    "$URL" 2>&1
)"
curl_exit=$?

exit_code=0

if [[ "$curl_exit" -ne 0 ]]; then
  log WARN "HTTP request failed: ${curl_output}"
  exit_code=1
else
  printf '%s' "$curl_output"
  actual_status="$(printf '%s' "$curl_output" | awk -F'[ =]' '/status=/ { print $2 }')"

  if [[ "$actual_status" != "$EXPECTED_STATUS" ]]; then
    log WARN "Unexpected HTTP status: ${actual_status}; expected ${EXPECTED_STATUS}"
    exit_code=1
  else
    log INFO "HTTP endpoint returned expected status ${EXPECTED_STATUS}"
  fi
fi

if [[ "$REQUIRE_PROCESS" == "true" ]]; then
  if ! command -v pgrep >/dev/null 2>&1; then
    log ERROR "pgrep is required when --require-process is used"
    exit 2
  fi

  printf '\nProcess matches for pattern %q:\n' "$PROCESS_PATTERN"
  if pgrep -af -- "$PROCESS_PATTERN"; then
    log INFO "Required NGINX process pattern is present"
  else
    log WARN "No process matched required pattern: ${PROCESS_PATTERN}"
    exit_code=1
  fi
fi

if command -v systemctl >/dev/null 2>&1; then
  printf '\nSuggested service diagnostic command:\n'
  printf 'systemctl status %s --no-pager\n' "$SERVICE_NAME"
fi

if [[ "$exit_code" -eq 0 ]]; then
  log INFO "NGINX health check completed successfully"
else
  log WARN "NGINX health check detected a condition needing investigation"
fi

exit "$exit_code"

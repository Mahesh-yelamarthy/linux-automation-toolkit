#!/usr/bin/env bash

set -uo pipefail

BACKUP_DIR="${BACKUP_DIR:-/var/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
MIN_KEEP="${MIN_KEEP:-3}"
FILE_PATTERN="${FILE_PATTERN:-*.tar.gz}"
DRY_RUN="${DRY_RUN:-true}"

usage() {
  cat <<'EOF'
Usage: backup-rotation.sh [options]

Rotate old backup archives from a single backup directory.

Options:
  --backup-dir PATH       Directory containing backup files (default: /var/backups)
  --retention-days DAYS   Delete files older than this many days (default: 14)
  --min-keep COUNT        Always keep at least this many matching files (default: 3)
  --pattern GLOB          File pattern to rotate (default: *.tar.gz)
  --dry-run               Print planned deletions without removing files (default)
  --delete                Remove eligible files
  -h, --help              Show this help message

Environment variables:
  BACKUP_DIR, RETENTION_DAYS, MIN_KEEP, FILE_PATTERN, DRY_RUN

Exit codes:
  0  Rotation completed or dry-run completed successfully
  1  Rotation found a policy condition that requires operator review
  2  Invalid configuration, missing dependency, or unsafe target
EOF
}

log() {
  printf '%s [%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" "$2"
}

is_non_negative_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

while (( $# > 0 )); do
  case "$1" in
    --backup-dir)
      [[ $# -ge 2 ]] || { log ERROR "--backup-dir requires a value"; exit 2; }
      BACKUP_DIR="$2"
      shift 2
      ;;
    --retention-days)
      [[ $# -ge 2 ]] || { log ERROR "--retention-days requires a value"; exit 2; }
      RETENTION_DAYS="$2"
      shift 2
      ;;
    --min-keep)
      [[ $# -ge 2 ]] || { log ERROR "--min-keep requires a value"; exit 2; }
      MIN_KEEP="$2"
      shift 2
      ;;
    --pattern)
      [[ $# -ge 2 ]] || { log ERROR "--pattern requires a value"; exit 2; }
      FILE_PATTERN="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --delete)
      DRY_RUN="false"
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

for command_name in date find rm sort wc du; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    log ERROR "Required command is unavailable: $command_name"
    exit 2
  fi
done

if [[ "$DRY_RUN" != "true" && "$DRY_RUN" != "false" ]]; then
  log ERROR "DRY_RUN must be true or false"
  exit 2
fi

if ! is_positive_integer "$RETENTION_DAYS"; then
  log ERROR "Retention days must be a positive integer"
  exit 2
fi

if ! is_non_negative_integer "$MIN_KEEP"; then
  log ERROR "Minimum keep count must be a non-negative integer"
  exit 2
fi

if [[ -z "$FILE_PATTERN" ]]; then
  log ERROR "File pattern cannot be empty"
  exit 2
fi

if [[ ! -d "$BACKUP_DIR" ]]; then
  log ERROR "Backup directory does not exist: $BACKUP_DIR"
  exit 2
fi

if [[ ! -r "$BACKUP_DIR" ]]; then
  log ERROR "Backup directory is not readable: $BACKUP_DIR"
  exit 2
fi

if [[ "$DRY_RUN" == "false" && ! -w "$BACKUP_DIR" ]]; then
  log ERROR "Backup directory must be writable when --delete is used: $BACKUP_DIR"
  exit 2
fi

case "$BACKUP_DIR" in
  /|/bin|/boot|/dev|/etc|/lib|/lib64|/proc|/root|/run|/sbin|/sys|/usr|/var|/home)
    log ERROR "Refusing to rotate directly from unsafe system path: $BACKUP_DIR"
    exit 2
    ;;
esac

log INFO "Backup rotation started"
printf 'Backup directory: %s\n' "$BACKUP_DIR"
printf 'Pattern: %s\n' "$FILE_PATTERN"
printf 'Retention days: %s\n' "$RETENTION_DAYS"
printf 'Minimum keep count: %s\n' "$MIN_KEEP"
printf 'Dry run: %s\n' "$DRY_RUN"

matching_count="$(
  find "$BACKUP_DIR" -maxdepth 1 -type f -name "$FILE_PATTERN" -print \
    | wc -l \
    | tr -d ' '
)"

eligible_count="$(
  find "$BACKUP_DIR" -maxdepth 1 -type f -name "$FILE_PATTERN" -mtime +"$RETENTION_DAYS" -print \
    | wc -l \
    | tr -d ' '
)"

printf '\nBackup inventory:\n'
printf 'Matching files: %s\n' "$matching_count"
printf 'Eligible files older than retention: %s\n' "$eligible_count"

if (( 10#$matching_count == 0 )); then
  log WARN "No matching backup files found"
  exit 1
fi

max_delete=$(( matching_count - MIN_KEEP ))

if (( max_delete <= 0 )); then
  log INFO "Rotation skipped because minimum keep policy protects all matching backups"
  exit 0
fi

delete_limit="$eligible_count"
if (( eligible_count > max_delete )); then
  delete_limit="$max_delete"
fi

if (( delete_limit <= 0 )); then
  log INFO "No files are eligible for rotation after minimum keep policy"
  exit 0
fi

printf '\nRotation candidates:\n'
deleted_count=0
freed_bytes=0

while IFS= read -r backup_file; do
  [[ -n "$backup_file" ]] || continue
  if (( deleted_count >= delete_limit )); then
    break
  fi

  file_size_bytes="$(du -k "$backup_file" | awk '{ printf "%.0f", $1 * 1024 }')"
  printf '%s %s bytes\n' "$backup_file" "$file_size_bytes"

  if [[ "$DRY_RUN" == "false" ]]; then
    rm -f -- "$backup_file"
  fi

  deleted_count=$(( deleted_count + 1 ))
  freed_bytes=$(( freed_bytes + file_size_bytes ))
done < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name "$FILE_PATTERN" -mtime +"$RETENTION_DAYS" -print | sort)

printf '\nRotation summary:\n'
printf 'Files selected: %s\n' "$deleted_count"
printf 'Estimated bytes reclaimable: %s\n' "$freed_bytes"

if [[ "$DRY_RUN" == "true" ]]; then
  log INFO "Dry-run completed; rerun with --delete to remove selected files"
else
  log INFO "Backup rotation deleted selected files"
fi

log INFO "Backup rotation completed successfully"

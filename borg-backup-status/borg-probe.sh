#!/usr/bin/env bash
# Print one of: current, running, failed, unavailable.
# This is the decision logic used by the Noctalia widget, kept standalone so it
# can also be tested without reloading Noctalia.

set -u

log() {
  printf '[borg-probe] %s\n' "$*" >&2
}

usage() {
  cat <<'EOF'
Usage: borg-probe.sh REPOSITORY [REQUIRED_MOUNT_PATH] [MAX_AGE_HOURS]

Examples:
  borg-probe.sh /run/media/me/Backup/borg /run/media/me/Backup 192
  borg-probe.sh ssh://borg@example.net/./repo

Prints exactly one status: current, running, failed, or unavailable.
EOF
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" || $# -eq 0 || $# -gt 3 ]]; then
  usage
  [[ $# -eq 0 ]] && exit 2
  exit 0
fi

repository=$1
mount_path=${2:-}
max_age_hours=${3:-192}
timeout_seconds=${BORG_PROBE_TIMEOUT_SECONDS:-30}

if ! [[ $max_age_hours =~ ^[0-9]+$ ]] || (( max_age_hours < 1 )); then
  log "invalid maximum age: $max_age_hours"
  printf '%s\n' 'failed'
  exit 2
fi

if ! [[ $timeout_seconds =~ ^[0-9]+$ ]] || (( timeout_seconds < 1 )); then
  log "invalid BORG_PROBE_TIMEOUT_SECONDS: $timeout_seconds"
  printf '%s\n' 'failed'
  exit 2
fi

log "starting: repository=$repository mount=${mount_path:-<none>} max_age=${max_age_hours}h"
log "client: $(borg --version 2>&1 || printf 'borg unavailable')"

# A running Borg process takes precedence over all other conditions.
if pgrep -f '[b]org( |$)' >/dev/null 2>&1; then
  log "a Borg process is already running"
  printf '%s\n' 'running'
  exit 0
fi

if [[ -n $mount_path && ! -d $mount_path ]]; then
  log "required mount path is unavailable: $mount_path"
  printf '%s\n' 'unavailable'
  exit 0
fi

log "querying newest archive (timeout: ${timeout_seconds}s)"
# Pika keeps its own Borg security cache. This separate read-only probe has
# already been pointed at the repository explicitly by the user, so answer the
# two location/security confirmations non-interactively. stdin is disconnected,
# so Borg cannot read an answer from this script's caller.
log "running non-interactively (no confirmation prompts)"
borg_output=$(BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes \
  BORG_RELOCATED_REPO_ACCESS_IS_OK=yes \
  timeout "${timeout_seconds}s" borg --lock-wait 1 list --last 1 --format '{time}{NL}' "$repository" </dev/null \
  2> >(while IFS= read -r line; do log "borg: $line"; done))
borg_exit=$?
log "Borg query exited with status $borg_exit"

if (( borg_exit == 124 )); then
  log "Borg query timed out"
  printf '%s\n' 'failed'
  exit 0
fi

stamp=$(printf '%s\n' "$borg_output" | head -n 1)
if [[ -z $stamp ]]; then
  log "Borg returned no archive timestamp"
  printf '%s\n' 'failed'
  exit 0
fi

then_epoch=$(date -d "$stamp" +%s 2>/dev/null || true)
now_epoch=$(date +%s)
if [[ -z $then_epoch ]]; then
  log "could not parse archive timestamp: $stamp"
  printf '%s\n' 'failed'
  exit 0
fi

age_seconds=$((now_epoch - then_epoch))
log "latest archive: $stamp (age: ${age_seconds}s)"
if (( age_seconds > max_age_hours * 3600 )); then
  log "archive exceeds the allowed age"
  printf '%s\n' 'failed'
else
  log "archive is current"
  printf '%s\n' 'current'
fi

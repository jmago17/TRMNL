#!/usr/bin/env bash
set -u

AGENT="${TRMNL_AGENT:-/Users/josu/Documents/Developer/trmnl/mac-agent/.build/release/trmnl-mac-agent}"
BRRR_SERVICE="${BRRR_KEYCHAIN_SERVICE:-trmnl-brrr-webhook-secret}"
BRRR_API_URL="${BRRR_API_URL:-https://api.brrr.now/v1/send}"

timestamp() {
  /bin/date '+%Y-%m-%d %H:%M:%S%z'
}

log_stdout() {
  /usr/bin/printf '[%s] %s\n' "$(timestamp)" "$*"
}

log_stderr() {
  /usr/bin/printf '[%s] %s\n' "$(timestamp)" "$*" >&2
}

emit_file_with_timestamps() {
  local stream="$1"
  local file="$2"

  [[ -s "$file" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$stream" == "stderr" ]]; then
      log_stderr "$line"
    else
      log_stdout "$line"
    fi
  done < "$file"
}

load_brrr_secret() {
  if [[ -n "${BRRR_WEBHOOK_SECRET:-}" ]]; then
    /usr/bin/printf '%s' "$BRRR_WEBHOOK_SECRET"
    return 0
  fi

  /usr/bin/security find-generic-password \
    -a "${USER:-josu}" \
    -s "$BRRR_SERVICE" \
    -w 2>/dev/null
}

send_brrr_failure_notification() {
  local command_label="$1"
  local exit_code="$2"
  local secret
  local message

  if ! secret="$(load_brrr_secret)" || [[ -z "$secret" ]]; then
    log_stderr "Brrr notification skipped: missing secret. Add it to Keychain service '$BRRR_SERVICE' or set BRRR_WEBHOOK_SECRET."
    return 0
  fi

  message="TRMNL automation failed
Command: ${command_label}
Exit code: ${exit_code}
Host: $(/bin/hostname -s)
Time: $(timestamp)"

  if /usr/bin/curl --fail --silent --show-error --max-time 15 \
    -X POST "$BRRR_API_URL" \
    -H "Authorization: Bearer $secret" \
    -H "Content-Type: text/plain; charset=utf-8" \
    --data-binary "$message" >/dev/null; then
    log_stderr "Brrr notification sent for failed command: ${command_label}"
  else
    log_stderr "Brrr notification failed for command: ${command_label}"
  fi
}

if [[ "$#" -eq 0 ]]; then
  log_stderr "Usage: $0 <trmnl-mac-agent command> [args...]"
  exit 64
fi

if [[ ! -x "$AGENT" ]]; then
  log_stderr "TRMNL agent is not executable: $AGENT"
  send_brrr_failure_notification "$*" 127
  exit 127
fi

stdout_file="$(/usr/bin/mktemp -t trmnl-command-stdout.XXXXXX)"
stderr_file="$(/usr/bin/mktemp -t trmnl-command-stderr.XXXXXX)"
trap '/bin/rm -f "$stdout_file" "$stderr_file"' EXIT

log_stdout "Starting TRMNL command: $*"
"$AGENT" "$@" >"$stdout_file" 2>"$stderr_file"
exit_code="$?"

emit_file_with_timestamps stdout "$stdout_file"
emit_file_with_timestamps stderr "$stderr_file"

if [[ "$exit_code" -eq 0 ]]; then
  log_stdout "Finished TRMNL command successfully: $*"
else
  log_stderr "TRMNL command failed with exit code ${exit_code}: $*"
  send_brrr_failure_notification "$*" "$exit_code"
fi

exit "$exit_code"

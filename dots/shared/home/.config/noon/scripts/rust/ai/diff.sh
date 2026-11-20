#!/usr/bin/env bash
# Diff a Go harness command against the Rust rewrite using the same env.
# Usage:
#   ./diff.sh <command> [args...]     e.g. ./diff.sh chat ses_x 10 0
#   ./diff.sh --all                   sessions + chat variants + skills + gen-tools
# Optional: RUST_HARNESS=<path> overrides the Rust binary (defaults to ./harness).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GO="$SCRIPT_DIR/../../go/ai/harness"
RUST="${RUST_HARNESS:-$SCRIPT_DIR/harness}"
SHELL_ROOT=/home/pharmaracist/.config/noon

export SESSION_DIR=/home/pharmaracist/.local/state/noon/harness
export XDG_CONFIG_HOME=/home/pharmaracist/.local/state/noon/harness/config

if [ ! -x "$GO" ]; then echo "missing Go harness: $GO" >&2; exit 3; fi
if [ ! -x "$RUST" ]; then echo "missing Rust harness: $RUST (build it or set RUST_HARNESS)" >&2; exit 3; fi

# Normalize volatile fields (epoch timestamps, timestamp fields, session ids).
normalize() {
  python3 -c '
import sys, re
s = sys.stdin.read()
s = re.sub(r"(?<![0-9])1[0-9]{12}(?![0-9])", "<TS>", s)
s = re.sub(r"(\"(?:updatedAt|createdAt|timestamp|created|updated)\"\s*:\s*)\"[^\"]*\"", r"\1\"<TS>\"", s)
s = re.sub(r"(\"(?:id|sessionId|session_id)\"\s*:\s*)\"ses_[^\"]*\"", r"\1\"<SID>\"", s)
sys.stdout.write(s)
'
}

status=0
compare() {
  local label="$1"; shift
  local go_out rust_out go_err rust_err
  go_out=$(mktemp); rust_out=$(mktemp); go_err=$(mktemp); rust_err=$(mktemp)
  "$GO" "$@" 2>"$go_err" | normalize >"$go_out"
  "$RUST" "$@" 2>"$rust_err" | normalize >"$rust_out"
  local ok=1
  diff -u "$go_out" "$rust_out" || ok=0
  diff -u "$go_err" "$rust_err" || ok=0
  if [ "$ok" -eq 1 ]; then echo "OK   $label"; else echo "DIFF $label"; status=1; fi
  rm -f "$go_out" "$rust_out" "$go_err" "$rust_err"
}

if [ "${1:-}" = "--all" ]; then
  sid=$("$GO" sessions | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d[0]["id"] if d else "")')
  compare "sessions" sessions
  compare "chat 10 0" chat "$sid" 10 0
  compare "chat 1 0" chat "$sid" 1 0
  compare "chat 500 0" chat "$sid" 500 0
  compare "chat 10 -5" chat "$sid" 10 -5
  compare "chat nonexistent" chat nonexistent-id 10 0
  compare "skills" skills
  compare "gen-tools" gen-tools "$SHELL_ROOT"
  python3 "$SCRIPT_DIR/tests/acp_replay.py" "$RUST" \
    "$SCRIPT_DIR/tests/golden/acp_readonly.ndjson" || status=1
else
  if [ $# -lt 1 ]; then echo "usage: $0 <command> [args...] | --all" >&2; exit 2; fi
  compare "$*" "$@"
fi

exit "$status"

#!/usr/bin/env bash
# Serve the marketing site build (build/web) on a fixed LAN port.
#
# Runs the dev server detached from the controlling terminal via
# `setsid`, so it survives shell session cleanup. PID is written
# to .serve_website.pid so `serve_website.sh stop` can stop it.
#
# Usage:
#   bash scripts/serve_website.sh            # default port 8080
#   PORT=8090 bash scripts/serve_website.sh  # custom port
#   bash scripts/serve_website.sh stop       # kill the running server

set -euo pipefail

PORT="${PORT:-8080}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="${ROOT}/.serve_website.pid"
LOG_FILE="${ROOT}/.serve_website.log"

cmd="${1:-start}"

stop_server() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      sleep 1
      if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
      fi
    fi
    rm -f "$PID_FILE"
    echo "stopped (pid $pid)"
  else
    echo "no pid file; nothing to stop"
  fi
  return 0
}

case "$cmd" in
  stop)
    stop_server
    exit 0
    ;;
  start|"")
    # If something is already listening on $PORT, leave it alone.
    if ss -tln 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${PORT}$"; then
      echo "port $PORT already in use; leaving existing server alone"
      exit 0
    fi
    # Stop any leftover from a previous run.
    if [[ -f "$PID_FILE" ]]; then
      stop_server || true
    fi
    cd "$ROOT"
    setsid python3 scripts/serve_website.py > "$LOG_FILE" 2>&1 < /dev/null &
    pid=$!
    echo "$pid" > "$PID_FILE"
    disown "$pid" 2>/dev/null || true
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
      echo "serving $ROOT/build/web on http://0.0.0.0:${PORT} (pid $pid, log: $LOG_FILE)"
    else
      echo "server failed to start; see $LOG_FILE" >&2
      exit 1
    fi
    ;;
  status)
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "running (pid $(cat "$PID_FILE")) on port $PORT"
    else
      echo "not running"
    fi
    ;;
  *)
    echo "Usage: $0 [start|stop|status]" >&2
    exit 1
    ;;
esac

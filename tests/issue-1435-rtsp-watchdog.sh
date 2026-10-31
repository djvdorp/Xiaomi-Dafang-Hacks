#!/bin/sh
set -eu

repo_root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
mkdir "$tmpdir/bin" "$tmpdir/paths with spaces"
. "$repo_root/firmware_mod/config/rtspserver.conf.dist"
[ "$RTSPWATCHDOG" = false ]
[ "$RTSPWATCHDOG_INTERVAL" = 60 ]
[ "$RTSPWATCHDOG_TIMEOUT" = 15 ]
[ "$RTSPWATCHDOG_MAX_RESTARTS" = 3 ]
grep -Fq 'RTSPWATCHDOG=${RTSPWATCHDOG:-false}' "$repo_root/firmware_mod/controlscripts/rtsp"
RTSPWATCHDOG=true
[ "$RTSPWATCHDOG_INTERVAL" = 60 ]
[ "$RTSPWATCHDOG_TIMEOUT" = 15 ]
[ "$RTSPWATCHDOG_MAX_RESTARTS" = 3 ]
cat > "$tmpdir/bin/timeout" <<'EOF'
#!/bin/sh
printf '%s\n' "$1" >> "$TIMEOUT_LOG"
shift
"$@"
EOF
cat > "$tmpdir/bin/sleep" <<'EOF'
#!/bin/sh
if [ "$1" = "$RTSPWATCHDOG_INTERVAL" ]; then
  count=$(cat "$SLEEP_COUNT")
  count=$((count + 1))
  echo "$count" > "$SLEEP_COUNT"
  [ "$count" -le "$LOOP_LIMIT" ]
fi
EOF
cat > "$tmpdir/bin/avconv" <<'EOF'
#!/bin/sh
count=$(cat "$AVCONV_COUNT")
count=$((count + 1))
echo "$count" > "$AVCONV_COUNT"
for output do :; done
case "$*" in
  *"rtsp://test-user:test-pass@127.0.0.1:8554/unicast"*) touch "$AUTH_SEEN" ;;
  *) exit 20 ;;
esac
case "$*" in
  *"-map 0:v:0 -c:v copy"*"-f h264"*) ;;
  *) exit 21 ;;
esac
case "$AVCONV_MODE" in
  success) echo frame > "$output" ;;
  once-empty) [ "$count" -eq 1 ] || echo frame > "$output" ;;
  empty) ;;
  fail) exit 1 ;;
esac
EOF
cat > "$tmpdir/bin/rtsp-control" <<'EOF'
#!/bin/sh
echo "$1" >> "$CONTROL_LOG"
echo 4321 > "$RTSP_PIDFILE"
"$RTSPWATCHDOG_BINARY"
EOF
cat > "$tmpdir/bin/rtsp-binary" <<'EOF'
#!/bin/sh
echo start >> "$BINARY_LOG"
touch "$SERVER_ALIVE"
EOF
cat > "$tmpdir/bin/watchdog-control" <<'EOF'
#!/bin/sh
touch "$CHILD_STARTED"
EOF
chmod +x "$tmpdir/bin/timeout" "$tmpdir/bin/sleep" "$tmpdir/bin/avconv" "$tmpdir/bin/rtsp-control" "$tmpdir/bin/rtsp-binary" "$tmpdir/bin/watchdog-control"
PATH="$tmpdir/bin:$PATH"
export PATH
TIMEOUT_LOG="$tmpdir/timeout.log"
SLEEP_COUNT="$tmpdir/sleep.count"
AVCONV_COUNT="$tmpdir/avconv.count"
AUTH_SEEN="$tmpdir/auth.seen"
CONTROL_LOG="$tmpdir/control.log"
BINARY_LOG="$tmpdir/binary.log"
SERVER_ALIVE="$tmpdir/server.alive"
RTSPWATCHDOG_OUTPUT="$tmpdir/paths with spaces/frame.h264"
RTSPWATCHDOG_AVCONV="$tmpdir/bin/avconv"
RTSPWATCHDOG_BINARY="$tmpdir/bin/rtsp-binary"
RTSPWATCHDOG_CONTROL="$tmpdir/bin/rtsp-control"
RTSPWATCHDOG_LOG="$tmpdir/watchdog.log"
RTSPWATCHDOG_INTERVAL=17
RTSPWATCHDOG_TIMEOUT=4
RTSPWATCHDOG_MAX_RESTARTS=3
RTSP_PIDFILE="$tmpdir/rtsp.pid"
PORT=8554
USERNAME=test-user
USERPASSWORD=test-pass
LOOP_LIMIT=2
AVCONV_MODE=success
WATCHDOG_ACTIVE="$tmpdir/watchdog.alive"
WATCHDOG_PIDFILE="$tmpdir/watchdog.pid"
CHILD_STARTED="$tmpdir/watchdog-child.started"
export TIMEOUT_LOG SLEEP_COUNT AVCONV_COUNT AUTH_SEEN CONTROL_LOG BINARY_LOG SERVER_ALIVE
export RTSPWATCHDOG_OUTPUT RTSPWATCHDOG_AVCONV RTSPWATCHDOG_BINARY RTSPWATCHDOG_CONTROL RTSPWATCHDOG_LOG
export RTSPWATCHDOG_INTERVAL RTSPWATCHDOG_TIMEOUT RTSPWATCHDOG_MAX_RESTARTS RTSP_PIDFILE PORT USERNAME USERPASSWORD LOOP_LIMIT AVCONV_MODE
export WATCHDOG_ACTIVE WATCHDOG_PIDFILE CHILD_STARTED
. "$repo_root/firmware_mod/scripts/common_functions.sh"

kill() {
  if [ "$1" = -0 ]; then
    if [ "$2" = 777 ]; then [ -f "$WATCHDOG_ACTIVE" ]; else [ -f "$SERVER_ALIVE" ]; fi
    return
  fi
  if [ "$1" = 777 ]; then
    [ ! -e "$WATCHDOG_PIDFILE" ] || return 10
    rm -f "$WATCHDOG_ACTIVE"
  fi
  echo "$1" >> "$tmpdir/kill.log"
  rm -f "$SERVER_ALIVE"
}

reset_case() {
  rm -f "$TIMEOUT_LOG" "$AVCONV_COUNT" "$AUTH_SEEN" "$CONTROL_LOG" "$BINARY_LOG" "$SERVER_ALIVE" "$RTSP_PIDFILE" "$RTSPWATCHDOG_LOG" "$tmpdir/kill.log"
  echo 0 > "$SLEEP_COUNT"
}

count_lines() {
  [ -f "$1" ] || { echo 0; return; }
  wc -l < "$1" | tr -d ' '
}

reset_case
rtsp_watchdog_loop
[ "$(count_lines "$CONTROL_LOG")" = 0 ]
[ "$(cat "$AVCONV_COUNT")" = 2 ]
[ -f "$AUTH_SEEN" ]
[ "$(cat "$TIMEOUT_LOG")" = "4
4" ]

reset_case
touch "$SERVER_ALIVE"
echo 1234 > "$RTSP_PIDFILE"
AVCONV_MODE=once-empty
LOOP_LIMIT=2
rtsp_watchdog_loop
[ "$(count_lines "$CONTROL_LOG")" = 1 ]
[ "$(count_lines "$BINARY_LOG")" = 1 ]
[ "$(count_lines "$tmpdir/kill.log")" = 1 ]
[ "$(cat "$AVCONV_COUNT")" = 2 ]
grep -q 'video probe failed; restart 1/3' "$RTSPWATCHDOG_LOG"

reset_case
touch "$SERVER_ALIVE"
echo 1234 > "$RTSP_PIDFILE"
AVCONV_MODE=empty
RTSPWATCHDOG_MAX_RESTARTS=1
LOOP_LIMIT=5
rtsp_watchdog_loop
[ "$(count_lines "$CONTROL_LOG")" = 1 ]
[ "$(count_lines "$BINARY_LOG")" = 1 ]
[ "$(cat "$AVCONV_COUNT")" = 2 ]
grep -q 'retry limit (1) reached' "$RTSPWATCHDOG_LOG"

reset_case
RTSPWATCHDOG_PIDFILE="$WATCHDOG_PIDFILE"
AVCONV_MODE=fail
LOOP_LIMIT=2
rtsp_watchdog_loop
[ "$(cat "$AVCONV_COUNT")" = 1 ]
[ "$(count_lines "$CONTROL_LOG")" = 0 ]
unset RTSPWATCHDOG_PIDFILE

reset_case
touch "$WATCHDOG_ACTIVE"
echo 777 > "$WATCHDOG_PIDFILE"
RTSPWATCHDOG_PIDFILE="$WATCHDOG_PIDFILE"
export RTSPWATCHDOG_PIDFILE
rtsp_watchdog_start "$WATCHDOG_PIDFILE" "$tmpdir/bin/watchdog-control"
[ "$(cat "$WATCHDOG_PIDFILE")" = 777 ]
[ ! -e "$CHILD_STARTED" ]
rtsp_watchdog_stop "$WATCHDOG_PIDFILE"
[ ! -e "$WATCHDOG_PIDFILE" ]
[ ! -e "$WATCHDOG_ACTIVE" ]
[ ! -e "$CHILD_STARTED" ]
[ "$(cat "$tmpdir/kill.log")" = 777 ]

echo 'RTSP watchdog: PASS'

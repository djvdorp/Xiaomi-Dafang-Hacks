#!/bin/sh
set -eu

repo_root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
. "$repo_root/firmware_mod/config/rtspserver.conf.dist"
[ "${RTSP_BINARY-}" = /system/sdcard/bin/v4l2rtspserver-master ]
[ "${RTSP_LIBDIR-}" = /system/sdcard/lib ]
. "$repo_root/firmware_mod/scripts/common_functions.sh"

testdir="$tmpdir/paths with spaces"
mkdir "$testdir"
stock="$testdir/stock"
candidate="$testdir/candidate"
stock_lib="$testdir/stock-lib"
candidate_lib="$testdir/candidate-lib"
mkdir "$stock_lib" "$candidate_lib"
touch "$stock" "$candidate"
chmod +x "$stock" "$candidate"

select_rtsp_binary "$stock" "$stock_lib" "$stock" "$stock_lib"
[ "$RTSP_BINARY" = "$stock" ] && [ "$RTSP_LIBDIR" = "$stock_lib" ]

select_rtsp_binary "$candidate" "$candidate_lib" "$stock" "$stock_lib"
[ "$RTSP_BINARY" = "$candidate" ] && [ "$RTSP_LIBDIR" = "$candidate_lib" ]

chmod -x "$candidate"
select_rtsp_binary "$candidate" "$candidate_lib" "$stock" "$stock_lib"
[ "$RTSP_BINARY" = "$stock" ] && [ "$RTSP_LIBDIR" = "$stock_lib" ]

chmod +x "$candidate"
select_rtsp_binary "$candidate" "$tmpdir/missing-lib" "$stock" "$stock_lib"
[ "$RTSP_BINARY" = "$stock" ] && [ "$RTSP_LIBDIR" = "$stock_lib" ]

calls="$tmpdir/launches"
selection_log="$tmpdir/selection.log"
server_log="$tmpdir/server.log"
pidfile="$tmpdir/server.pid"
RTSP_PROC_ROOT="$tmpdir/proc"
RTSP_STARTTIME_FILE="$tmpdir/starttime"
SERVER_RUNNER="$tmpdir/server-runner"
export RTSP_PROC_ROOT RTSP_STARTTIME_FILE SERVER_RUNNER
cat > "$SERVER_RUNNER" <<'EOF'
#!/bin/sh
echo "$1" >> "$CALLS"
[ "$1" != candidate ] || [ "$CANDIDATE_MODE" != fail ] || exit 1
mkdir -p "$RTSP_PROC_ROOT/$$"
printf '%s (rtsp server) S' "$$" > "$RTSP_PROC_ROOT/$$/stat"
field=4
while [ "$field" -lt 22 ]; do
  printf ' 0' >> "$RTSP_PROC_ROOT/$$/stat"
  field=$((field + 1))
done
printf ' 12345\n' >> "$RTSP_PROC_ROOT/$$/stat"
exec /bin/sleep 30
EOF
cat > "$candidate" <<'EOF'
#!/bin/sh
exec "$SERVER_RUNNER" candidate "$CANDIDATE_MODE"
EOF
cat > "$stock" <<'EOF'
#!/bin/sh
exec "$SERVER_RUNNER" stock "$CANDIDATE_MODE"
EOF
chmod +x "$SERVER_RUNNER" "$candidate" "$stock"
CALLS="$calls" CANDIDATE_MODE=success rtsp_start_server "$candidate" "$candidate_lib" "$stock" "$stock_lib" "$pidfile" "$server_log" "$selection_log" -P 8554
[ "$RTSP_BINARY" = "$candidate" ]
[ "$(cat "$RTSP_STARTTIME_FILE")" = 12345 ]
pid=$(cat "$pidfile")
kill "$pid"
wait "$pid" 2>/dev/null || true

: > "$calls"
CALLS="$calls" CANDIDATE_MODE=fail rtsp_start_server "$candidate" "$candidate_lib" "$stock" "$stock_lib" "$pidfile" "$server_log" "$selection_log" -P 8554
[ "$RTSP_BINARY" = "$stock" ] && [ "$RTSP_LIBDIR" = "$stock_lib" ]
[ "$(cat "$calls")" = "candidate
stock" ]
[ "$(cat "$RTSP_STARTTIME_FILE")" = 12345 ]
grep -q 'candidate server exited; falling back to stock' "$selection_log"
pid=$(cat "$pidfile")
kill "$pid"
wait "$pid" 2>/dev/null || true

echo 'RTSP selection: PASS'

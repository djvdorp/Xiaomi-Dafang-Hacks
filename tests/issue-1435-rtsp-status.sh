#!/bin/sh
set -eu

repo_root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
grep -Fq 'rtsp_reconcile_server_pid "$PIDFILE" "$RTSP_STARTTIME_FILE"' "$repo_root/firmware_mod/controlscripts/rtsp"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
mkdir -p "$tmpdir/bin" "$tmpdir/proc/368"
cat > "$tmpdir/bin/pidof" <<'EOF'
#!/bin/sh
printf '%s\n' "$PIDOF_OUTPUT"
EOF
chmod +x "$tmpdir/bin/pidof"
PATH="$tmpdir/bin:$PATH"
RTSP_PROC_ROOT="$tmpdir/proc"
RTSP_PIDFILE="$tmpdir/rtsp.pid"
RTSP_STARTTIME_FILE="$tmpdir/rtsp.starttime"
PIDOF_OUTPUT="369 368"
export PATH RTSP_PROC_ROOT RTSP_PIDFILE RTSP_STARTTIME_FILE PIDOF_OUTPUT
. "$repo_root/firmware_mod/scripts/common_functions.sh"

printf '368 (v4l2rtspserver-) S' > "$RTSP_PROC_ROOT/368/stat"
field=4
while [ "$field" -lt 22 ]; do
  printf ' 0' >> "$RTSP_PROC_ROOT/368/stat"
  field=$((field + 1))
done
printf ' 1577\n' >> "$RTSP_PROC_ROOT/368/stat"

echo 369 > "$RTSP_PIDFILE"
echo 1000 > "$RTSP_STARTTIME_FILE"
[ "$(rtsp_reconcile_server_pid "$RTSP_PIDFILE" "$RTSP_STARTTIME_FILE")" = 368 ]
[ "$(cat "$RTSP_PIDFILE")" = 368 ]
[ "$(cat "$RTSP_STARTTIME_FILE")" = 1577 ]

PIDOF_OUTPUT=
export PIDOF_OUTPUT
if rtsp_reconcile_server_pid "$RTSP_PIDFILE" "$RTSP_STARTTIME_FILE"; then
  echo 'stale RTSP PID was accepted without a live server' >&2
  exit 1
fi
[ ! -e "$RTSP_PIDFILE" ]
[ ! -e "$RTSP_STARTTIME_FILE" ]

echo 'RTSP status reconciliation: PASS'

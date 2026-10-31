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

echo 'RTSP selection: PASS'

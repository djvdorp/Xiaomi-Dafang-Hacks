#!/bin/sh
set -eu

repo_root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
mkdir "$tmpdir/bin"
cat > "$tmpdir/bin/insmod" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$INSMOD_LOG"
[ "$FAIL_MODULE" != all ] && [ "$FAIL_MODULE" != "$1" ]
EOF
chmod +x "$tmpdir/bin/insmod"
PATH="$tmpdir/bin:$PATH"
export PATH
INSMOD_LOG="$tmpdir/insmod.log"
export INSMOD_LOG
LOGPATH="$tmpdir/startup.log"
export LOGPATH
. "$repo_root/firmware_mod/scripts/common_functions.sh"
. "$repo_root/firmware_mod/config/wifi-driver.conf.dist"
[ "$WIFI_DRIVER" = stock ]

stock="$tmpdir/8189es-stock.ko"
candidate="$tmpdir/8189es-candidate.ko"
: > "$stock"
: > "$candidate"
mac=02:11:22:33:44:55

assert_calls() {
  expected=$1
  actual=$(cat "$INSMOD_LOG")
  [ "$actual" = "$expected" ] || {
    echo "Expected insmod calls:\n$expected\nGot:\n$actual" >&2
    exit 1
  }
}

: > "$INSMOD_LOG"
: > "$LOGPATH"
FAIL_MODULE=
export FAIL_MODULE
load_wifi_driver stock "$mac" "$stock" "$candidate"
assert_calls "$stock rtw_initmac=$mac"
grep -q "loaded $stock" "$LOGPATH"

: > "$INSMOD_LOG"
: > "$LOGPATH"
load_wifi_driver candidate "$mac" "$stock" "$tmpdir/missing.ko"
assert_calls "$stock rtw_initmac=$mac"
grep -q 'candidate missing; falling back to stock' "$LOGPATH"

: > "$INSMOD_LOG"
: > "$LOGPATH"
FAIL_MODULE="$candidate"
export FAIL_MODULE
load_wifi_driver candidate "$mac" "$stock" "$candidate"
assert_calls "$candidate rtw_initmac=$mac
$stock rtw_initmac=$mac"
grep -q 'candidate load failed; trying stock once' "$LOGPATH"

: > "$INSMOD_LOG"
FAIL_MODULE=
export FAIL_MODULE
load_wifi_driver candidate "$mac" "$stock" "$candidate"
assert_calls "$candidate rtw_initmac=$mac"

: > "$INSMOD_LOG"
FAIL_MODULE=all
export FAIL_MODULE
if load_wifi_driver candidate "$mac" "$stock" "$candidate"; then
  echo 'Expected failure when both drivers fail to load' >&2
  exit 1
fi
assert_calls "$candidate rtw_initmac=$mac
$stock rtw_initmac=$mac"

echo 'driver selection: PASS'

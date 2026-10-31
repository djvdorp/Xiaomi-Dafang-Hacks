#!/bin/sh
set -eu

repo_root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
artifact="$repo_root/firmware_mod/driver/8189es-candidate.ko"
provenance="$repo_root/docs/driver/issue-1435-8189es.md"

test -f "$artifact"
test -f "$provenance"
file "$artifact" | grep -q 'ELF 32-bit LSB relocatable, MIPS'
strings "$artifact" | grep -Fqx 'version=v5.8.9_35085.20190919'
strings "$artifact" | grep -Fq 'vermagic=3.10.14 preempt mod_unload MIPS32_R1 32BIT'

expected_hash=$(sed -n 's/^SHA256: `\([0-9a-f]*\)`$/\1/p' "$provenance")
actual_hash=$(shasum -a 256 "$artifact" | awk '{print $1}')
test -n "$expected_hash"
test "$expected_hash" = "$actual_hash"

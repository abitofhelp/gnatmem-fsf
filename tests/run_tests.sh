#!/usr/bin/env bash
# ============================================================================
# run_tests.sh - gnatmem_fsf report tests
# ============================================================================
# Copyright (c) 2026 Michael Gardner, A Bit of Help, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later
# See LICENSE file in the project root.
#
# Purpose:
#   Runs the instrumented Leaker program in each mode and checks that
#   gnatmem_fsf reports the expected counts, sizes (scaled and -t), and
#   allocation site.
# ============================================================================

# Usage: tests/run_tests.sh [path/to/gnatmem_fsf]

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
GNATMEM=$(realpath "${1:-$ROOT/bin/debug/gnatmem_fsf}")
LEAKER_DIR=$ROOT/tests/leaker
LEAKER=$LEAKER_DIR/bin/leaker
# Line of the main loop's allocation (the last "ALLOCATION SITE (" marker),
# and of the second site used by mode "two"
SITE_LINE=$(grep -n 'ALLOCATION SITE (' "$LEAKER_DIR/leaker.adb" | tail -1 | cut -d: -f1)
TWO_SITE_1=$(grep -n 'ALLOCATION SITE (' "$LEAKER_DIR/leaker.adb" | head -1 | cut -d: -f1)
TWO_SITE_2=$(grep -n 'ALLOCATION SITE 2' "$LEAKER_DIR/leaker.adb" | cut -d: -f1)
WORK=$ROOT/obj/tests

PASS=0
FAIL=0

check() {
   local name=$1 pattern=$2
   if grep -qE -- "$pattern" report.txt; then
      PASS=$((PASS + 1)); echo "PASS  $name"
   else
      FAIL=$((FAIL + 1)); echo "FAIL  $name (expected /$pattern/)"
   fi
}

check_absent() {
   local name=$1 pattern=$2
   if grep -qE -- "$pattern" report.txt; then
      FAIL=$((FAIL + 1)); echo "FAIL  $name (unexpected /$pattern/)"
   else
      PASS=$((PASS + 1)); echo "PASS  $name"
   fi
}

# run MODE ITERATIONS PAYLOAD [OPTION...]: run Leaker, then gnatmem_fsf on
# its gmem.out with any extra options
run() {
   local mode=$1 iterations=$2 payload=$3
   shift 3
   rm -f gmem.out report.txt
   "$LEAKER" "$mode" "$iterations" "$payload" || { echo "FAIL  leaker $mode did not run"; FAIL=$((FAIL + 1)); return 1; }
   "$GNATMEM" "$@" -b 5 -i gmem.out "$LEAKER" > report.txt 2>&1
}

gprbuild -q -P "$LEAKER_DIR/leaker.gpr" || exit 1
rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK" || exit 1

echo "== leak: 1000 blocks lost"
run leak 1000 128
check "allocations"               'Total number of allocations +: *1000$'
check "deallocations"             'Total number of deallocations +: *0$'
check "one allocation root"       '^Allocation Root # 1$'
check_absent "no second root"     '^Allocation Root # 2$'
check "root holds 1000 blocks"    'Number of non freed allocations +: *1000$'
check "allocation site symbolized" "leaker\\.adb:$SITE_LINE +Leaker$"

echo "== clean: nothing lost"
run clean 1000 128
check "allocations"               'Total number of allocations +: *1000$'
check "deallocations"             'Total number of deallocations +: *1000$'
check "nothing outstanding"       'Final Water Mark \(non freed mem\) +: +0 Bytes$'
check_absent "no allocation roots" '^Allocation Root #'

echo "== partial: one block in four lost"
run partial 1000 128
check "deallocations"             'Total number of deallocations +: *750$'
check "root holds 250 blocks"     'Number of non freed allocations +: *250$'
check "allocation site symbolized" "leaker\\.adb:$SITE_LINE +Leaker$"

# With -t every size is an exact byte count. Each 128-byte payload is a
# 136-byte block: Ada stores the array bounds (2 x 4 bytes) with the data.
echo "== -t: leak, exact bytes"
run leak 1000 128 -t
check "outstanding bytes"         'Final Water Mark \(non freed mem\) +: +136000 Bytes$'
check "peak bytes"                'High Water Mark +: +136000 Bytes$'
check_absent "no scaled units"    'Kilobytes|Megabytes'

echo "== -t: partial, exact bytes"
run partial 1000 128 -t
check "outstanding bytes"         'Final Water Mark \(non freed mem\) +: +34000 Bytes$'

echo "== -t: clean, exact bytes"
run clean 1000 128 -t
check "nothing outstanding"       'Final Water Mark \(non freed mem\) +: +0 Bytes$'
check "peak is one block"         'High Water Mark +: +136 Bytes$'

echo "== without -t: sizes stay scaled"
run leak 1000 128
check "scaled units"              'Final Water Mark \(non freed mem\) +: +132\.81 Kilobytes$'

# -s orders allocation roots. Mode two: site 1 leaks more blocks
# (100 x 136 bytes), site 2 leaks more bytes (50 x 520 bytes).
first_site() { grep -m1 -oE 'leaker\.adb:[0-9]+' report.txt | cut -d: -f2; }
expect_first() {
   local name=$1 want=$2 got
   got=$(first_site)
   if [ "$got" = "$want" ]; then PASS=$((PASS + 1)); echo "PASS  $name"
   else FAIL=$((FAIL + 1)); echo "FAIL  $name (first root at line ${got:-none}, want $want)"; fi
}
echo "== -s: sort order of allocation roots"
run two 100 128 -t
expect_first "default (nwh): most blocks first" "$TWO_SITE_1"
run two 100 128 -t -s n
expect_first "-s n: most blocks first"          "$TWO_SITE_1"
run two 100 128 -t -s w
expect_first "-s w: most bytes first"           "$TWO_SITE_2"
run two 100 128 -t -s hn
expect_first "-s hn: highest peak first"        "$TWO_SITE_2"
run two 100 128 -t -s nwh
expect_first "-s nwh: three criteria"           "$TWO_SITE_1"
for bad in x nn nwhw ""; do
   run two 100 128 -t -s "$bad"
   check "-s '$bad' rejected"     'Invalid sort criteria string'
done

# Synthetic gmem.out in libgmem's layout, to test values beyond 32 bits
# without allocating them: "GMEM DUMP\n" and a start time, then records
#   'A' address(8) size(8) time(8) count(4) frame(8)...
# Duration is stored in nanoseconds. Little-endian (x86-64 and AArch64).
le() {  # le BYTES VALUE: VALUE as BYTES little-endian bytes
   local n=$1 v=$2 i out=""
   for ((i = 0; i < n; i++)); do
      out+=$(printf '\\x%02x' $(( (v >> (8 * i)) & 0xff )))
   done
   printf "$out"
}
alloc() {  # alloc ADDRESS SIZE FRAME
   printf 'A'; le 8 "$1"; le 8 "$2"; le 8 2000000000; le 4 1; le 8 "$3"
}
{
   printf 'GMEM DUMP\n'; le 8 1000000000
   alloc $((0x10000)) 5000000000 $((0xA000))      # 5 GB at one site
   alloc $((0x20000)) 1 $((0xB000))               # three 1-byte blocks
   alloc $((0x20010)) 1 $((0xB000))               # at a second site
   alloc $((0x20020)) 1 $((0xB000))
} > big.out
echo "== 64-bit sizes (synthetic log)"
rm -f report.txt; "$GNATMEM" -t -i big.out "$LEAKER" > report.txt 2>&1
check "total beyond 32 bits"      'Final Water Mark \(non freed mem\) +: +5000000003 Bytes$'
check "site beyond 32 bits"       'Final Water Mark \(non freed mem\) +: +5000000000 Bytes$'
check "allocation count"          'Total number of allocations +: *4$'
rm -f report.txt; "$GNATMEM" -t -s w -i big.out "$LEAKER" > report.txt 2>&1
check "-s w sorts 5 GB site first" 'Number of non freed allocations +: +1$'
first_count=$(grep -m1 'Number of non freed allocations' report.txt | grep -oE '[0-9]+$')
[ "$first_count" = "1" ] && { PASS=$((PASS + 1)); echo "PASS  -s w: first root is the 5 GB site"; } || { FAIL=$((FAIL + 1)); echo "FAIL  -s w: first root has $first_count blocks"; }
rm -f report.txt; "$GNATMEM" -t -s n -i big.out "$LEAKER" > report.txt 2>&1
first_count=$(grep -m1 'Number of non freed allocations' report.txt | grep -oE '[0-9]+$')
[ "$first_count" = "3" ] && { PASS=$((PASS + 1)); echo "PASS  -s n: first root has the most blocks"; } || { FAIL=$((FAIL + 1)); echo "FAIL  -s n: first root has $first_count blocks"; }
rm -f report.txt; "$GNATMEM" -dd -t -i big.out "$LEAKER" > report.txt 2>&1
check "dump mode: 64-bit size"    '5000000000 bytes at moment'
check "dump mode: start time"     'Log started at T0 = .*\(1970-01-01 00:00:01 UTC\)$'

echo "== malformed logs"
run leak 1000 128
head -c 2000 gmem.out > truncated.out
rm -f report.txt; "$GNATMEM" -t -i truncated.out "$LEAKER" > report.txt 2>&1; rc=$?
check "truncated log is corrupt"  'GNATMEM dump file corrupt'
[ "$rc" -eq 1 ] && { PASS=$((PASS + 1)); echo "PASS  truncated log exits 1"; } || { FAIL=$((FAIL + 1)); echo "FAIL  truncated log exits 1 (rc=$rc)"; }
printf 'NOT A GMEM' > bad.out
rm -f report.txt; "$GNATMEM" -i bad.out "$LEAKER" > report.txt 2>&1
check "bad header rejected"       'is not a gnatmem log file'
rm -f report.txt; "$GNATMEM" -i gmem.out /nonexistent/program > report.txt 2>&1
check "unreadable executable gives ???" '\?\?\?'

echo
echo "gnatmem_fsf tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

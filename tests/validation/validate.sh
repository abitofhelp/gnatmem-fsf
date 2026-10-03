#!/usr/bin/env bash
# ============================================================================
# validate.sh - One-page validation of gnatmem_fsf against GNAT Pro gnatmem
# ============================================================================
# Copyright (c) 2026 Michael Gardner, A Bit of Help, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later
# See LICENSE file in the project root.
#
# Purpose:
#   Builds and tests gnatmem_fsf, runs the instrumented test program
#   tests/leaker in several workloads, and summarizes gnatmem_fsf's reports
#   on one page. Where GNAT Pro's gnatmem is on PATH, it also analyzes each
#   workload's gmem.out with it and compares the two tools. The page is
#   meant to be printed on one machine and compared by eye with another.
#
# Usage:
#   tests/validation/validate.sh [output file]
#   Run from Git Bash or MSYS2 (Windows) or a Linux shell, with GNAT and
#   make on PATH.
# ============================================================================

set -u

GM_DIR=$(cd "$(dirname "$0")/../.." && pwd)
OUT=${1:-$PWD/validation-$(hostname).txt}
OUT=$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")
# Outside the repository: "make distclean" removes obj/ and bin/
WORK=${TMPDIR:-/tmp}/gnatmem_fsf_validation

case "$(uname -s)" in
   MINGW* | MSYS* | CYGWIN*) EXE=.exe ;;
   *) EXE= ;;
esac

GNATMEM_FSF=$GM_DIR/bin/release/gnatmem_fsf$EXE
LEAKER=$GM_DIR/tests/leaker/bin/leaker$EXE
# MODE ITERATIONS PAYLOAD for each workload
WORKLOADS="leak:1000:128 clean:1000:128 partial:1000:128 two:100:128"

rm -rf "$WORK"
mkdir -p "$WORK"
: > "$OUT"

say() { echo "$*" | tee -a "$OUT"; }
first_line() { head -n 1 | tr -d '\r'; }

# Last "N passed, M failed" line of a test run
test_result() { grep -E 'passed, [0-9]+ failed' "$1" | tail -n 1 | sed 's/^.*: //'; }

# summary REPORT: the fields that must agree between gnatmem implementations
# and platforms. One "totals" line (allocations, deallocations, final bytes,
# peak bytes), then one line per allocation root: blocks and bytes not
# freed, the first frame with a source location, and a hash of the
# program's own frames (the frames that identify an allocation site),
# sorted. Every root is listed, with frame=none when no frame has a source
# location. Left out because they differ between platforms and toolchains:
# addresses, column widths, ??? frames, the binder's b__*.adb frames, and
# GNAT runtime units (a-*, s-*, g-*, i-*).
summary() {
   tr -d '\r' < "$1" | awk '
      # value: first word after the colon, whatever the column spacing
      function value(  v) { v = $0; sub(/^[^:]*:[ ]*/, "", v); sub(/ .*/, "", v); return v }
      function program_frame(f) {
         return f ~ /:[0-9]+$/ && f !~ /^b__/ && f !~ /^[asgi]-[a-z0-9]+\.ad[bs]:/
      }
      function flush() {
         if (in_root) {
            if (first == "") first = "frame=none"
            print "root " n " " w " " first "\t" trace
         }
      }
      /Total number of allocations/   { a = value() }
      /Total number of deallocations/ { d = value() }
      /^   Final Water Mark/          { f = value() }
      /^   High Water Mark/           { h = value() }
      /^Allocation Root #/            { flush(); in_root = 1; n = ""; w = ""; first = ""; trace = ""; frames = 0 }
      /^ Number of non freed/         { n = value() }
      /^ Final Water Mark/            { w = value() }
      /^ Backtrace/                   { frames = 1; next }
      frames && NF == 0               { frames = 0 }
      frames && program_frame($1) {
         if (first == "") first = $1 " " $2
         trace = trace (trace == "" ? "" : "|") $1 " " $2
      }
      END { flush(); print "totals " a " " d " " f " " h }' | sort
}

# hashed FILE: summary lines with each root trace replaced by a 12-digit
# SHA-256 prefix, as printed on the page
hashed() {
   while IFS=$(printf '\t') read -r line trace; do
      case "$line" in
         root*) echo "$line trace=$(printf '%s' "$trace" | sha256sum | cut -c1-12)" ;;
         *) echo "$line" ;;
      esac
   done < "$1"
}

# check_roots MODE FILE: leak, partial, and two must report at least one
# root, each with a program frame that has a source location; clean none
check_roots() {
   local roots unresolved
   roots=$(grep -c '^root ' "$2")
   unresolved=$(grep -c '^root .* frame=none' "$2")
   case "$1" in
      leak | partial | two)
         if [ "$roots" -gt 0 ] && [ "$unresolved" -eq 0 ]; then
            echo "check: $roots root(s), all with a source location: PASS"
         else
            echo "check: $roots root(s), $unresolved without a source location: FAIL"
         fi ;;
      *)
         if [ "$roots" -eq 0 ]; then echo "check: no roots: PASS"
         else echo "check: $roots unexpected root(s): FAIL"; fi ;;
   esac
}

# ---------------------------------------------------------------- header
say "GNATMEM_FSF VALIDATION"
say "Date (UTC) : $(date -u '+%Y-%m-%d %H:%M')"
say "Machine    : $(hostname) ($(uname -s) $(uname -m))"
say "GNAT       : $(gnatls --version 2>/dev/null | first_line)"
if command -v gnatmem >/dev/null 2>&1; then
   HAVE_PRO_GNATMEM=1
   say "gnatmem    : $(command -v gnatmem)"
else
   HAVE_PRO_GNATMEM=0
   say "gnatmem    : not found (GNAT Pro comparison skipped)"
fi
say ""

# ---------------------------------------------------------------- build
say "== gnatmem_fsf"
( cd "$GM_DIR" && make distclean >/dev/null 2>&1
  make release > "$WORK/build.txt" 2>&1 )
say "build : $([ $? -eq 0 ] && echo ok || echo FAILED) ($(grep -ci 'warning' "$WORK/build.txt") warnings)"
( cd "$GM_DIR" && make BUILD=release test > "$WORK/test.txt" 2>&1 )
say "tests : $(test_result "$WORK/test.txt")"
grep '^FAIL' "$WORK/test.txt" | head -n 5 | sed 's/^/  /' | tee -a "$OUT"

# ---------------------------------------------------------------- workloads
say ""
say "== Reports by workload (tests/leaker, gnatmem -b 10 -t)"
cd "$WORK" || exit 1
for w in $WORKLOADS; do
   IFS=: read -r m iterations payload <<EOF2
$w
EOF2
   rm -f gmem.out
   "$LEAKER" "$m" "$iterations" "$payload" > /dev/null 2>&1
   "$GNATMEM_FSF" -b 10 -t -i gmem.out "$LEAKER" > "fsf_$m.txt" 2>&1
   summary "fsf_$m.txt" > "fsf_$m.sum"
   hashed "fsf_$m.sum" > "fsf_$m.page"
   line="$m $iterations x $payload: fsf $(sha256sum < "fsf_$m.page" | cut -c1-16)"
   if [ "$HAVE_PRO_GNATMEM" -eq 1 ]; then
      gnatmem -b 10 -t -i gmem.out "$LEAKER" > "pro_$m.txt" 2>&1
      summary "pro_$m.txt" > "pro_$m.sum"
      hashed "pro_$m.sum" > "pro_$m.page"
      if cmp -s "fsf_$m.txt" "pro_$m.txt"; then same="reports identical"
      else same="reports differ in $(diff "fsf_$m.txt" "pro_$m.txt" | grep -c '^[<>]') lines"; fi
      if cmp -s "fsf_$m.page" "pro_$m.page"; then sum="summaries match"; else sum="SUMMARIES DIFFER"; fi
      line="$line  pro $(sha256sum < "pro_$m.page" | cut -c1-16)  $sum, $same"
   fi
   say "$line"
   sed 's/^/    /' "fsf_$m.page" | tee -a "$OUT"
   say "    $(check_roots "$m" "fsf_$m.page")"
   if [ "$HAVE_PRO_GNATMEM" -eq 1 ]; then
      say "    pro $(check_roots "$m" "pro_$m.page")"
      if ! cmp -s "fsf_$m.page" "pro_$m.page"; then
         diff "fsf_$m.page" "pro_$m.page" | grep '^[<>]' | head -n 4 | sed 's/^/    /' | tee -a "$OUT"
      fi
   fi
done

say ""
say "Summary lines: totals = allocations deallocations final-bytes peak-bytes;"
say "root = blocks bytes first-frame-with-source trace=<SHA-256 prefix of the"
say "program's own frames>. Workload hash = first 16 hex digits of SHA-256 of"
say "the summary lines. Full output: $WORK"
case "$OUT" in
   "$GM_DIR"/obj/* | "$GM_DIR"/bin/*)
      say "WARNING: output file is inside a build folder that make distclean removes" ;;
esac
say "Written to: $OUT"

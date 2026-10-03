# Validation procedure

**Version:** 0.1.0
**Date:** October 2, 2026
**SPDX-License-Identifier:** GPL-3.0-or-later
**License File:** See the LICENSE file in the project root.
**Copyright:** © 2026 Michael Gardner, A Bit of Help, Inc.
**Status:** In development

`validate.sh` builds and tests `gnatmem_fsf`, runs the instrumented test program `tests/leaker` in four workloads, and prints a one-page summary of `gnatmem_fsf`'s reports. On a machine where GNAT Pro's `gnatmem` is on `PATH`, it also analyzes each workload's `gmem.out` with GNAT Pro's `gnatmem` and compares the two tools on the **same** input. The page is meant to be printed and compared by eye with the page from another machine.

## Run

From any folder outside the repository, with GNAT and `make` on `PATH` (on Windows, from MSYS2 or Git Bash with `make`):

```sh
<gnatmem_fsf>/tests/validation/validate.sh validation.txt
```

The page is written to `validation.txt`; full outputs are kept in `$TMPDIR/gnatmem_fsf_validation` (or `/tmp/gnatmem_fsf_validation`).

## Workloads

| Workload | What `tests/leaker` does | Expected |
|---|---|---|
| `leak` 1000 × 128 | loses every block | 1 root, all 1000 blocks |
| `clean` 1000 × 128 | frees every block | no roots |
| `partial` 1000 × 128 | loses one block in four | 1 root, 250 blocks |
| `two` 100 × 128 | loses 100 small blocks at one site and 50 blocks four times larger at another | 2 roots |

## Reading the page

- Each workload has a `check:` line that must say **PASS**: roots that should exist all have a source location, and `clean` has none. A root whose backtrace could not be symbolized appears as `frame=none` and fails the check.
- With GNAT Pro's `gnatmem`, each workload must also say **`summaries match`**. `reports identical` is ideal; when the reports differ, the number of differing lines and the first differing summary lines are printed.
- Without GNAT Pro, compare the page with one produced where GNAT Pro was available: the summary lines, and therefore their hashes, should agree.

## What the summary contains

- `totals`: allocations, deallocations, final bytes (outstanding), peak bytes.
- `root`: for each allocation root, blocks not freed, bytes not freed, the first backtrace frame with a source location (for example `leaker.adb:43 Leaker`), and `trace=`, a SHA-256 prefix of all of the program's own frames.

Addresses, column widths, `???` frames, the binder's `b__*.adb` frames, and GNAT runtime units (`a-*`, `s-*`, `g-*`, `i-*`) are left out, because they differ between platforms and toolchains even when both tools count the same allocations.

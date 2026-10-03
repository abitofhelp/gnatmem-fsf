# gnatmem_fsf

**Version:** 0.1.0
**Date:** October 2, 2026
**SPDX-License-Identifier:** GPL-3.0-or-later
**License File:** See the LICENSE file in the project root.
**Copyright:** © 2026 Michael Gardner, A Bit of Help, Inc. Original gnatmem sources © 1997-2008 AdaCore and © 2000-2009 Free Software Foundation, Inc.
**Status:** In development

## Overview

`gnatmem_fsf` reads the `gmem.out` allocation log written by a program linked with GNAT's `libgmem` (`-lgmem`) and reports which allocations were never freed, how many bytes they hold, and the source location (`file:line`) of each allocation site.

It is the `gnatmem` tool from FSF GCC 4.5.4, the last GCC release that included it, ported to current GNAT. AdaCore's `gnatmem` ships only with GNAT Pro. FSF GNAT still includes `libgmem`, but without a `gnatmem` its `gmem.out` cannot be read. `gnatmem_fsf` is for use with FSF GNAT where GNAT Pro is not available.

The executable is named `gnatmem_fsf` so it never shadows GNAT Pro's `gnatmem` on a machine that has both.

`gnatmem_fsf` is an independent project. It is not affiliated with, endorsed by, or supported by AdaCore. GNAT and GNAT Pro are associated with AdaCore.

**Key Capabilities:**

- Reads `gmem.out` from current `libgmem` (GCC 13, 15). The format is unchanged since GCC 4.5.
- Reports allocations, deallocations, outstanding and peak memory, and allocation roots (backtraces).
- Symbolizes backtraces to `file:line` and subprogram names using the GNAT runtime's DWARF reader. FSF GCC never had this; its `convert_addresses` was a stub.

## Provenance and Validation Scope

> **Based on:** `gnatmem` from FSF GCC **4.5.4** (`releases/gcc-4.5.4`), the last FSF release that included it.
>
> **Validated against:** GNAT Pro **26.1** `gnatmem`, for our purposes only. **Status: pending**; see Validation below.
>
> Comprehensive validation has not been performed. `gnatmem_fsf` is checked only on the workloads described in Validation, and its results may differ from GNAT Pro's `gnatmem` in cases those workloads do not exercise.

## Status

| Item | State |
|---|---|
| Reading `gmem.out`, counts, allocation roots | Working |
| `file:line` symbolization | Working |
| Exact byte sizes (`-t`) | Working. Without `-t`, sizes are scaled (for example `132.81 Kilobytes`), as in FSF `gnatmem`. |
| Reading `gmem.out` in Ada | Done: `Gmem_Reader` replaced FSF's `gmem.c`, so the project compiles no C. On every recorded test log its reports match the C version, except where behavior was deliberately fixed (truncated logs, `-s`, usage text). |
| 64-bit values | Counts, sizes, addresses, and sort keys are 64-bit; tested with a synthetic 5 GB allocation. |
| Dump mode (`-dd`) | Working: lists every allocation and deallocation in order, with full 64-bit addresses and the log start time in UTC. |
| Agreement with GNAT Pro's `gnatmem` | Not yet compared (see Validation) |
| Sort order (`-s`) | Accepts 1 to 3 distinct criteria from `n`, `w`, `h`; the rest follow in default order. FSF required exactly 3. |

## Platform Support

| Platform | Status | Notes |
|---|---|---|
| Linux AArch64 | Tested | FSF GNAT 13.3 |
| Linux AMD64 | Expected | Same sources; not yet tested |
| Windows 11 AMD64 | Expected | Same sources; not yet tested. Symbolization may need work if the executable is loaded at a randomized address (ASLR). |
| macOS | Not supported | Until GNAT provides `libgmem` there |

## Requirements

- GNAT with `gprbuild`. Tested with FSF GNAT 13.3; later releases are expected to work but are untested, because the symbolizer relies on internal runtime units (see Design Notes).
- The program being analyzed must be built with debug information (`-g`) and linked with `-lgmem`. On Linux it must also be linked with `-no-pie`, so the addresses in `gmem.out` match the addresses in its debug information.

## Build and Test

```sh
make            # debug build: bin/debug/gnatmem_fsf
make release    # release build: bin/release/gnatmem_fsf
make test       # build tests/leaker and check gnatmem_fsf's reports
```

The Makefile and test scripts need GNU `make` and `bash`. Linux has both; on Windows use MSYS2 (`pacman -S make diffutils`) or Git Bash with `make`. Without them, build directly with `gprbuild`:

```sh
gprbuild -P gnatmem_fsf.gpr -XBUILD=debug
gprbuild -P gnatmem_fsf.gpr -XBUILD=release
```

## Usage

```sh
./my_program                        # instrumented; writes gmem.out
gnatmem_fsf -b 10 -t -i gmem.out ./my_program
```

`-t` prints every size as an exact number of bytes, for tools that need exact byte counts. Without it, sizes are scaled to Kilobytes or Megabytes.

Run `gnatmem_fsf` with no arguments for the full option list.

Example: a program that allocated eight 128-byte blocks and freed six of them, analyzed with `gnatmem_fsf -b 3 -t`:

```text
Global information
------------------
   Total number of allocations        :   8
   Total number of deallocations      :   6
   Final Water Mark (non freed mem)   : 272 Bytes
   High Water Mark                    : 272 Bytes

Allocation Root # 1
-------------------
 Number of non freed allocations    :   2
 Final Water Mark (non freed mem)   : 272 Bytes
 High Water Mark                    : 272 Bytes
 Backtrace                          :
   leaker.adb:54     Leaker
   b__leaker.adb:194 Main
   ???:?             ???
```

Each 128-byte block is reported as 136 bytes because Ada stores an unconstrained array's bounds with its data. Frames outside the program's debug information, such as the C runtime's startup code, appear as `???`.

## Limitations

- Backtraces are recorded to at most 200 frames (a `libgmem` limit).
- Source locations need debug information. Code built without `-g`, and system libraries, appear as `???`.
- On Linux the program must be linked with `-no-pie`; otherwise its load address differs from the addresses in its debug information and frames appear as `???`.
- On Windows, address space layout randomization (ASLR) may have the same effect. This has not been tested.
- A `gmem.out` that ends inside a record is reported as corrupt (exit status 1).

## Validation

`tests/validation/validate.sh` automates this and prints a one-page summary; see `tests/validation/README.md`.

Results can be trusted once they match GNAT Pro's `gnatmem`. The strongest check is to give the same `gmem.out` to both tools: run an instrumented program once on a machine with GNAT Pro, then analyze that one `gmem.out` with GNAT Pro's `gnatmem` and with `gnatmem_fsf`. The totals (allocations, deallocations, final and high water marks, number of allocation roots) must match exactly, and backtraces should name the same source lines.

## Design Notes

- The port changes the FSF sources as little as possible so its results stay comparable with GNAT Pro's `gnatmem`. It therefore keeps the original Ada 95 code style and does not follow the usual application architecture.
- `src/gmem_reader.ad?` reads `gmem.out` with `Ada.Streams.Stream_IO`. It is the Ada translation of FSF's `gmem.c`, and exports the same `__gnat_gmem_*` subprograms so `gnatmem.adb` and `memroot.adb` stay as FSF wrote them. A log that ends inside a record is reported as corrupt.
- `src/dwarf_symbolizer.adb` turns an address into `0x<address> in <subprogram> at <file>:<line>`. When the executable can't be read, it writes `???` instead of failing. It uses internal GNAT runtime units (`System.Dwarf_Lines`), because the runtime has no public interface for symbolizing another executable. Those units can change between GNAT releases, and this file is the one place to update.
- `src/gnatvsn.ad?` replaces the compiler's `Gnatvsn` unit, which is not part of the runtime.
- The unmodified FSF files, including `gmem.c`, are kept in `upstream/` for comparison; see `upstream/README.md`.

## License

GNU General Public License version 3 or later (`GPL-3.0-or-later`); see `LICENSE`. The files derived from GCC keep their original AdaCore or FSF notice unchanged below the project header, and record their modifications in a dated Modification History. `COPYING3` is the same license text under the name those original notices refer to, and `COPYING.RUNTIME` is the GCC Runtime Library Exception that the original `gmem.c` notice (kept in `src/gmem_reader.ad?`) refers to.

---

© 2026 Michael Gardner, A Bit of Help, Inc. · GPL-3.0-or-later

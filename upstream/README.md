# Upstream sources

**Version:** 0.1.0
**Date:** October 2, 2026
**SPDX-License-Identifier:** GPL-3.0-or-later
**License File:** See the LICENSE file in the project root.
**Copyright:** © 1997-2008 AdaCore; © 2000-2009 Free Software Foundation, Inc.
**Status:** Reference copy (do not modify)

Unmodified files from FSF GCC 4.5.4 (`releases/gcc-4.5.4` in the GCC git
repository), the last GCC release that included `gnatmem`:

| File | GCC path | Used in this project as |
|---|---|---|
| `gnatmem.adb` | `gcc/ada/gnatmem.adb` | `../src/gnatmem.adb` (working copy) |
| `memroot.ads`, `memroot.adb` | `gcc/ada/memroot.ads`, `gcc/ada/memroot.adb` | `../src/memroot.ad?` (working copies) |
| `gmem.c` | `gcc/ada/gmem.c` | **Source of the Ada port** `../src/gmem_reader.ad?`. Not built. |

They are kept here unchanged for reference and comparison.

`gmem.c` was translated to Ada as `Gmem_Reader`, which exports the same
`__gnat_gmem_*` subprograms, so `gnatmem.adb` and `memroot.adb` did not need
to change. The project no longer compiles any C. Against the C version, the
Ada port produced identical reports for every recorded test log and option
combination, except for one intended difference: a log that ends inside a
record is reported as corrupt (exit status 1), where `gmem.c` read past the
end of the file and reported leftover values.

All files are covered by the GNU General Public
License version 3 or later (see `../LICENSE`).

Source: https://github.com/gcc-mirror/gcc/tree/releases/gcc-4.5.4/gcc/ada

pragma Ada_95;
--  ==========================================================================
--  Dwarf_Symbolizer - DWARF-based address symbolization
--  ==========================================================================
--  Copyright (c) 2026 Michael Gardner, A Bit of Help, Inc.
--  SPDX-License-Identifier: GPL-3.0-or-later
--  See LICENSE file in the project root.
--
--  Purpose:
--    Turns a traceback address into '0x<addr> in <subprogram> at
--    <file>:<line>' using the executable's DWARF debug information. FSF
--    GCC only ever had a stub for this, so FSF gnatmem could not report
--    source locations.
--
--  Usage:
--    Dwarf_Symbolizer.Symbolize (Exe, Address, Line, Last);
--
--  Design Notes:
--    Built on the GNAT runtime's DWARF reader (System.Dwarf_Lines). The
--    executable must have debug info (-g) and, on Linux, be linked with
--    -no-pie so logged addresses match its DWARF tables.
--
--  See Also:
--    Gmem_Reader - caller
--    Memroot - parses the returned text
--  ==========================================================================


with System;

package Dwarf_Symbolizer is

   procedure Symbolize
     (Executable : String;
      Addr       : System.Address;
      Text       : out String;
      Last       : out Natural);
   --  Write the symbolic form of Addr in Executable, followed by a line
   --  feed, into Text (Text'First .. Last), truncated to Text'Length. When
   --  the executable cannot be read, or the address is not found, the
   --  subprogram, file, and line are written as "???".

end Dwarf_Symbolizer;

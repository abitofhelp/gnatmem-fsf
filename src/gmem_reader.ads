pragma Ada_95;
--  ==========================================================================
--  Gmem_Reader - gmem.out reader for gnatmem_fsf
--  ==========================================================================
--  Copyright (C) 2000-2009, Free Software Foundation, Inc. (gmem.c)
--  Ada translation Copyright (c) 2026 Michael Gardner, A Bit of Help, Inc.
--  SPDX-License-Identifier: GPL-3.0-or-later
--  See LICENSE file in the project root.
--
--  Purpose:
--    Reads the gmem.out allocation log written by libgmem and hands its
--    records, backtrace frames, and symbolized frames to Gnatmem and
--    Memroot. Ada replacement for FSF GCC 4.5.4 gmem.c.
--
--  Usage:
--    Not called by name: Gnatmem and Memroot import these subprograms by
--    their original C names (__gnat_gmem_*), which this package exports.
--
--  Design Notes:
--    Exporting the gmem.c symbol names keeps gnatmem.adb and memroot.adb
--    identical to FSF. Uses only the Ada runtime (Stream_IO, GNAT.OS_Lib).
--    Unlike gmem.c, a log that ends inside a record is reported as corrupt
--    instead of being read past its end.
--
--  See Also:
--    Dwarf_Symbolizer - symbolizes one address
--    upstream/gmem.c - the C original
--
--  Modification History (GPLv3 section 5a):
--    2026-10-02  Michael Gardner: translated gmem.c to Ada.
--    2026-10-02  Michael Gardner: added the original gmem.c notice.
--  ==========================================================================

------------------------------------------------------------------------------
--                                                                          --
--                            GNATMEM COMPONENTS                            --
--                                                                          --
--                                 G M E M                                  --
--                                                                          --
--                          C Implementation File                           --
--                                                                          --
--         Copyright (C) 2000-2009, Free Software Foundation, Inc.          --
--                                                                          --
-- GNAT is free software;  you can  redistribute it  and/or modify it under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  GNAT is distributed in the hope that it will be useful, but WITH- --
-- OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.                                     --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
-- GNAT was originally developed  by the GNAT team at  New York University. --
-- Extensive contributions were provided by Ada Core Technologies Inc.      --
--                                                                          --
------------------------------------------------------------------------------

--  The notice above is the original notice of FSF GCC 4.5.4 gmem.c, of
--  which this unit is an Ada translation; only the comment markers were
--  changed from C to Ada.

with Interfaces.C.Strings;
with System;

package Gmem_Reader is

   function Initialize
     (Dumpname : Interfaces.C.Strings.chars_ptr) return Duration;
   --  Open the log Dumpname and check its "GMEM DUMP" header. Returns the
   --  start timestamp, or 0.0 if the file is not a gmem.out log.
   pragma Export (C, Initialize, "__gnat_gmem_initialize");

   procedure A2l_Initialize (Exename : Interfaces.C.Strings.chars_ptr);
   --  Record the executable whose addresses are symbolized, resolved on
   --  PATH when it is not a path.
   pragma Export (C, A2l_Initialize, "__gnat_gmem_a2l_initialize");

   procedure Read_Next (Buf : System.Address);
   --  Read the next record into the Storage_Elmt at Buf: Elmt is 'A'
   --  (allocation), 'D' (deallocation), or '*' (end of log). Exits with
   --  status 1 if the log is corrupt.
   pragma Export (C, Read_Next, "__gnat_gmem_read_next");

   procedure Read_Next_Frame (Addr : out System.Address);
   --  Next frame of the current record's backtrace, or Null_Address when
   --  there are no more.
   pragma Export (C, Read_Next_Frame, "__gnat_gmem_read_next_frame");

   procedure Symbolic
     (Addr : System.Address; Buf : System.Address; Last : out Natural);
   --  Write the symbolic form of Addr, ending in a line feed, into the
   --  String at Buf; Last is the number of characters written.
   pragma Export (C, Symbolic, "__gnat_gmem_symbolic");

end Gmem_Reader;

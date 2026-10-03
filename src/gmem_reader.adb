pragma Ada_95;
--  ==========================================================================
--  Gmem_Reader - gmem.out reader for gnatmem_fsf (body)
--  ==========================================================================
--  Copyright (C) 2000-2009, Free Software Foundation, Inc. (gmem.c)
--  Ada translation Copyright (c) 2026 Michael Gardner, A Bit of Help, Inc.
--  SPDX-License-Identifier: GPL-3.0-or-later
--  See LICENSE file in the project root.
--
--  Purpose:
--    Reads gmem.out with Stream_IO, matching libgmem's record layout:
--    'A' address size timestamp count frames..., 'D' address timestamp
--    count frames..., after a 'GMEM DUMP' line and a start timestamp.
--
--  Usage:
--    See the specification.
--
--  Design Notes:
--    Field sizes come from the Ada types libgmem writes (System.Address,
--    size_t, Duration, Integer), read with their default stream
--    attributes, which use the native representation.
--
--  See Also:
--    Gmem_Reader (spec)
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

with Ada.IO_Exceptions;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Interfaces.C;
with System.Storage_Elements;
with Dwarf_Symbolizer;

package body Gmem_Reader is

   use type GNAT.OS_Lib.String_Access;

   package SIO renames Ada.Streams.Stream_IO;
   package SSE renames System.Storage_Elements;

   Max_Frames : constant := 200;
   --  Backtrace depth libgmem records (Max_Call_Stack in memtrack.adb)

   Max_Line : constant := 500;
   --  Size of the line buffer Memroot passes to Symbolic

   --  Layout of Gnatmem's Storage_Elmt, which Read_Next fills in
   type Storage_Elmt is record
      Elmt      : Character;
      Address   : SSE.Integer_Address;
      Size      : SSE.Storage_Count;
      Timestamp : Duration;
   end record;

   type Frame_Array is array (1 .. Max_Frames) of System.Address;

   Log         : SIO.File_Type;
   Log_Stream  : SIO.Stream_Access;
   Frames      : Frame_Array;
   Frame_Count : Natural := 0;
   Frame_Next  : Positive := 1;
   Executable  : GNAT.OS_Lib.String_Access;

   procedure Corrupt;
   pragma No_Return (Corrupt);
   --  Report a malformed log and exit, as gmem.c does

   procedure Corrupt is
   begin
      Ada.Text_IO.Put_Line ("GNATMEM dump file corrupt");
      GNAT.OS_Lib.OS_Exit (1);
   end Corrupt;

   ----------------
   -- Initialize --
   ----------------

   function Initialize
     (Dumpname : Interfaces.C.Strings.chars_ptr) return Duration
   is
      Header : String (1 .. 10);
      T0     : Duration;
   begin
      SIO.Open (Log, SIO.In_File, Interfaces.C.Strings.Value (Dumpname));
      Log_Stream := SIO.Stream (Log);
      String'Read (Log_Stream, Header);
      if Header /= "GMEM DUMP" & ASCII.LF then
         SIO.Close (Log);
         return 0.0;
      end if;
      Duration'Read (Log_Stream, T0);
      return T0;
   exception
      when Ada.IO_Exceptions.End_Error =>
         --  Shorter than the header: not a gmem.out log
         if SIO.Is_Open (Log) then
            SIO.Close (Log);
         end if;
         return 0.0;
   end Initialize;

   --------------------
   -- A2l_Initialize --
   --------------------

   procedure A2l_Initialize (Exename : Interfaces.C.Strings.chars_ptr) is
      Name : constant String := Interfaces.C.Strings.Value (Exename);
   begin
      Executable := GNAT.OS_Lib.Locate_Exec_On_Path (Name);
      if Executable = null then
         Executable := new String'(Name);
      end if;
   end A2l_Initialize;

   ---------------
   -- Read_Next --
   ---------------

   procedure Read_Next (Buf : System.Address) is
      Result : Storage_Elmt;
      for Result'Address use Buf;
      pragma Import (Ada, Result);

      Kind  : Character;
      Size  : Interfaces.C.size_t;
      Count : Integer;
   begin
      if SIO.End_Of_File (Log) then
         SIO.Close (Log);
         Result.Elmt := '*';
         return;
      end if;

      Character'Read (Log_Stream, Kind);
      case Kind is
         when 'A' =>
            Result.Elmt := 'A';
            SSE.Integer_Address'Read (Log_Stream, Result.Address);
            Interfaces.C.size_t'Read (Log_Stream, Size);
            Result.Size := SSE.Storage_Count (Size);
            Duration'Read (Log_Stream, Result.Timestamp);
         when 'D' =>
            Result.Elmt := 'D';
            SSE.Integer_Address'Read (Log_Stream, Result.Address);
            Duration'Read (Log_Stream, Result.Timestamp);
         when others =>
            Corrupt;
      end case;

      --  Backtrace: frame count, then that many addresses
      Integer'Read (Log_Stream, Count);
      if Count < 0 or else Count > Max_Frames then
         Corrupt;
      end if;
      for I in 1 .. Count loop
         System.Address'Read (Log_Stream, Frames (I));
      end loop;
      Frame_Count := Count;
      Frame_Next := 1;
   exception
      when Ada.IO_Exceptions.End_Error =>
         --  The log ends inside a record
         Corrupt;
   end Read_Next;

   ---------------------
   -- Read_Next_Frame --
   ---------------------

   procedure Read_Next_Frame (Addr : out System.Address) is
   begin
      if Frame_Next > Frame_Count then
         Addr := System.Null_Address;
      else
         Addr := Frames (Frame_Next);
         Frame_Next := Frame_Next + 1;
      end if;
   end Read_Next_Frame;

   --------------
   -- Symbolic --
   --------------

   procedure Symbolic
     (Addr : System.Address; Buf : System.Address; Last : out Natural)
   is
      Line : String (1 .. Max_Line);
      for Line'Address use Buf;
      pragma Import (Ada, Line);
   begin
      if Executable = null then
         Executable := new String'("");
      end if;
      Dwarf_Symbolizer.Symbolize (Executable.all, Addr, Line, Last);
   end Symbolic;

end Gmem_Reader;

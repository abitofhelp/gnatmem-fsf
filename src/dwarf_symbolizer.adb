pragma Ada_95;
--  ==========================================================================
--  Dwarf_Symbolizer - DWARF-based address symbolization (body)
--  ==========================================================================
--  Copyright (c) 2026 Michael Gardner, A Bit of Help, Inc.
--  SPDX-License-Identifier: GPL-3.0-or-later
--  See LICENSE file in the project root.
--
--  Purpose:
--    Symbolizes one address per call with System.Dwarf_Lines and formats
--    the result for Memroot.
--
--  Usage:
--    See the specification.
--
--  Design Notes:
--    Opens the executable once, on the first call. Uses internal GNAT
--    runtime units, so this is the one file to update when their
--    interfaces change.
--
--  See Also:
--    Dwarf_Symbolizer (spec)
--  ==========================================================================


--  These are internal GNAT runtime units: the GNAT runtime has no public
--  interface for symbolizing another executable's addresses. Their
--  interfaces can change between GNAT releases, so this unit is the one
--  place to update when moving to a new compiler.
pragma Warnings (Off, "*is an internal GNAT unit*");
pragma Warnings (Off, "*use of this unit is non-portable*");
with System.Address_Image;
with System.Bounded_Strings;
with System.Dwarf_Lines;
with System.Traceback_Entries;
pragma Warnings (On, "*is an internal GNAT unit*");
pragma Warnings (On, "*use of this unit is non-portable*");

package body Dwarf_Symbolizer is

   package BS renames System.Bounded_Strings;
   package DL renames System.Dwarf_Lines;
   package STE renames System.Traceback_Entries;

   Result_Size : constant := 1000;

   Context : DL.Dwarf_Context;
   Opened  : Boolean := False;
   Tried   : Boolean := False;
   --  The executable is opened once, on the first call

   procedure Put (Line : String; Text : out String; Last : out Natural);
   --  Copy Line and a line feed into Text, truncated to Text'Length

   procedure Put (Line : String; Text : out String; Last : out Natural) is
      Full  : constant String := Line & ASCII.LF;
      Count : constant Natural := Natural'Min (Full'Length, Text'Length);
   begin
      Text (Text'First .. Text'First + Count - 1) :=
        Full (Full'First .. Full'First + Count - 1);
      Last := Text'First + Count - 1;
   end Put;

   ---------------
   -- Symbolize --
   ---------------

   procedure Symbolize
     (Executable : String;
      Addr       : System.Address;
      Text       : out String;
      Last       : out Natural)
   is
      Unknown : constant String :=
        "0x" & System.Address_Image (Addr) & " in ??? at ???:?";
      Result  : BS.Bounded_String (Result_Size);
      Found   : Boolean := False;
   begin
      if not Tried then
         Tried := True;
         begin
            DL.Open (Executable, Context, Opened);
         exception
            when DL.Dwarf_Error =>
               --  The file is missing or is not a readable object file
               Opened := False;
         end;
      end if;

      if not Opened then
         Put (Unknown, Text, Last);
         return;
      end if;

      DL.Symbolic_Traceback
        (Context, (1 => STE.TB_Entry_For (Addr)),
         Suppress_Hex => False, Symbol_Found => Found, Res => Result);

      declare
         S     : constant String := BS.To_String (Result);
         Stop  : Natural := S'Last;
         Space : Natural := 0;
      begin
         --  Drop trailing line feeds; Put adds exactly one
         while Stop >= S'First and then S (Stop) = ASCII.LF loop
            Stop := Stop - 1;
         end loop;

         for I in S'First .. Stop loop
            if S (I) = ' ' then
               Space := I;
               exit;
            end if;
         end loop;

         if Space = 0 then
            Put (Unknown, Text, Last);
         else
            --  "0x<addr> <name> at <file>:<line>" becomes
            --  "0x<addr> in <name> at <file>:<line>"
            Put (S (S'First .. Space) & "in " & S (Space + 1 .. Stop),
                 Text, Last);
         end if;
      end;
   end Symbolize;

end Dwarf_Symbolizer;

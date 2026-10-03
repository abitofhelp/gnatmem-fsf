pragma Ada_95;
--  ==========================================================================
--  Leaker - Instrumented test program for gnatmem_fsf
--  ==========================================================================
--  Copyright (c) 2026 Michael Gardner, A Bit of Help, Inc.
--  SPDX-License-Identifier: GPL-3.0-or-later
--  See LICENSE file in the project root.
--
--  Purpose:
--    Allocates blocks and frees all, some, or none of them, so tests can
--    check gnatmem_fsf's report against known counts.
--
--  Usage:
--    leaker <leak|clean|partial|two> <iterations> <payload-bytes>
--    two: leaks Iterations blocks of Payload bytes at one site and
--    Iterations / 2 blocks of 4 * Payload bytes at a second site
--
--  Design Notes:
--    Each allocation line ends with a marker comment that the tests
--    search for to find its line number.
--
--  See Also:
--    tests/run_tests.sh - runs Leaker and checks the reports
--  ==========================================================================

with Ada.Command_Line;
with Ada.Unchecked_Deallocation;

procedure Leaker is
   use Ada.Command_Line;

   type Bytes is array (Positive range <>) of Character;
   type Bytes_Access is access Bytes;
   procedure Free is new Ada.Unchecked_Deallocation (Bytes, Bytes_Access);

   Mode       : constant String := Argument (1);
   Iterations : constant Natural := Natural'Value (Argument (2));
   Payload    : constant Positive := Positive'Value (Argument (3));
   P          : Bytes_Access;
begin
   if Mode = "two" then
      for I in 1 .. Iterations loop
         P := new Bytes (1 .. Payload);  --  ALLOCATION SITE (checked by tests)
         P (1) := 'X';
      end loop;
      for I in 1 .. Iterations / 2 loop
         P := new Bytes (1 .. 4 * Payload);  --  ALLOCATION SITE 2
         P (1) := 'X';
      end loop;
      return;
   end if;

   for I in 1 .. Iterations loop
      P := new Bytes (1 .. Payload);  --  ALLOCATION SITE (checked by tests)
      P (1) := 'X';
      if Mode = "clean" or else (Mode = "partial" and then I mod 4 /= 0) then
         Free (P);
      end if;
   end loop;
end Leaker;

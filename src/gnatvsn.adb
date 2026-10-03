pragma Ada_95;
--  ==========================================================================
--  Gnatvsn - Version banner for gnatmem_fsf (body)
--  ==========================================================================
--  Copyright (c) 2026 Michael Gardner, A Bit of Help, Inc.
--  SPDX-License-Identifier: GPL-3.0-or-later
--  See LICENSE file in the project root.
--
--  Purpose:
--    Returns the gnatmem_fsf version string.
--
--  Usage:
--    Put_Line (Gnatvsn.Gnat_Version_String);
--
--  Design Notes:
--    Update the version here for each release.
--
--  See Also:
--    Gnatvsn (spec)
--  ==========================================================================

package body Gnatvsn is

   -------------------------
   -- Gnat_Version_String --
   -------------------------

   function Gnat_Version_String return String is
   begin
      return "FSF 4.5.4 port with DWARF symbolization (gnatmem_fsf 0.1.0)";
   end Gnat_Version_String;

end Gnatvsn;

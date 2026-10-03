pragma Ada_95;
--  ==========================================================================
--  Gnatvsn - Version banner for gnatmem_fsf
--  ==========================================================================
--  Copyright (c) 2026 Michael Gardner, A Bit of Help, Inc.
--  SPDX-License-Identifier: GPL-3.0-or-later
--  See LICENSE file in the project root.
--
--  Purpose:
--    Provides the version string Gnatmem prints with its usage text,
--    replacing the compiler's Gnatvsn unit (not part of the GNAT runtime).
--
--  Usage:
--    Put_Line (Gnatvsn.Gnat_Version_String);
--
--  Design Notes:
--    Only the subprogram Gnatmem needs is provided.
--
--  See Also:
--    Gnatmem - main program
--  ==========================================================================

package Gnatvsn is
   pragma Preelaborate;

   function Gnat_Version_String return String;
   --  Name and origin of this build of gnatmem
end Gnatvsn;

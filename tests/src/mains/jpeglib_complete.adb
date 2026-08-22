with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

with Jpeglib_Tools;
with Project_Tools.Files;
with Project_Tools.Processes;

procedure Jpeglib_Complete is
   Root : constant String :=
     Project_Tools.Files.Find_Root_Upward
       (Ada.Directories.Current_Directory, "alire.toml");
   Errors : Natural := 0;

   procedure Fail (Message : String) is
   begin
      Errors := Errors + 1;
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_complete: " & Message);
   end Fail;

   procedure Require_Resolved (Path : String; Marker : String; Label : String) is
   begin
      if Project_Tools.Files.File_Contains (Project_Tools.Files.Join (Root, Path), Marker) then
         Fail (Label);
      end if;
   end Require_Resolved;

   procedure Run_Release_Gate is
      Status : constant Integer :=
        Project_Tools.Processes.Run_Status
          ("library-complete release baseline",
           Root,
           Project_Tools.Files.Join (Root, "tests/bin/jpeglib_release"),
           Project_Tools.Processes.No_Arguments);
   begin
      if Status /= 0 then
         Fail ("release baseline failed with status" & Integer'Image (Status));
      end if;
   end Run_Release_Gate;

   procedure Run_Real_World_Manifest is
      Status : constant Integer :=
        Project_Tools.Processes.Run_Status
          ("library-complete real-world corpus",
           Root,
           Project_Tools.Files.Join (Root, "tests/bin/jpeglib_real_world"),
           Project_Tools.Processes.No_Arguments);
   begin
      if Status /= 0 then
         Fail ("LC2 real-world corpus gate failed with status" & Integer'Image (Status));
      end if;
   end Run_Real_World_Manifest;

   procedure Run_Policy_Matrix is
      Status : constant Integer :=
        Project_Tools.Processes.Run_Status
          ("library-complete public API policy matrix",
           Root,
           Project_Tools.Files.Join (Root, "tests/bin/jpeglib_policy_matrix"),
           Project_Tools.Processes.No_Arguments);
   begin
      if Status /= 0 then
         Fail ("LC3 public API policy matrix failed with status" & Integer'Image (Status));
      end if;
   end Run_Policy_Matrix;
begin
   if Root = "" then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_complete: run below the jpeglib tree");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
      return;
   end if;

   Run_Release_Gate;
   Run_Real_World_Manifest;
   Run_Policy_Matrix;

   if Errors = 0 then
      Require_Resolved
        ("docs/external_reference_matrix.md",
         "remaining library-complete interoperability work",
         "LC1 external oracle closure is still open");
      Require_Resolved
        ("docs/external_reference_matrix.md",
         "ImageMagick diagnostic",
         "LC1 still has ImageMagick diagnostic rows");
      Require_Resolved
        ("docs/external_reference_matrix.md",
         "limitation sentinel",
         "LC1 still has ffmpeg limitation sentinels instead of final compatibility outcomes");
      Require_Resolved
        ("docs/proof_profile.md",
         "Library-complete proof work remains open",
         "LC4 proof expansion is still open");
      Require_Resolved
        ("docs/implementation_plan.md",
         "Open library-complete work remains",
         "library-complete implementation plan still lists open work");
      Require_Resolved
        ("docs/implementation_plan.md",
         "jpeglib_complete` succeeds locally and in CI",
         "LC6 release completeness gate is documented as a future exit criterion");
   end if;

   if Errors = 0 then
      Ada.Text_IO.Put_Line ("jpeglib_complete: library-complete gate passed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "jpeglib_complete: " & Natural'Image (Errors) & " completeness blocker(s)");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Policy_Failure)));
   end if;
end Jpeglib_Complete;

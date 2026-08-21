with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

with Jpeglib_Tools;
with Project_Tools.Files;
with Project_Tools.Processes;

procedure Jpeglib_Generate is
   Root : constant String :=
     Project_Tools.Files.Find_Root_Upward
       (Ada.Directories.Current_Directory, "alire.toml");
   Status : Integer;
begin
   if Root = "" then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_generate: run below the jpeglib tree");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
      return;
   end if;

   Status :=
     Project_Tools.Processes.Run_Status
       ("fixture generation",
        Root,
        Project_Tools.Files.Join (Root, "tests/bin/jpeglib_fixtures"),
        Project_Tools.Processes.Arguments
          ([Project_Tools.Processes.Argument ("--generate")]));

   if Status /= 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "jpeglib_generate: fixture generation failed with status" & Integer'Image (Status));
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Fixture_Integrity_Failure)));
      return;
   end if;

   Ada.Text_IO.Put_Line ("jpeglib_generate: generated artifacts are current");
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
end Jpeglib_Generate;

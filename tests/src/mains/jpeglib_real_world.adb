with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;

with Jpeglib_Tools;
with Project_Tools.Files;

procedure Jpeglib_Real_World is
   Root : constant String :=
     Project_Tools.Files.Find_Root_Upward
       (Ada.Directories.Current_Directory, "alire.toml");
   Allow_Empty : constant Boolean :=
     Ada.Command_Line.Argument_Count = 1 and then Ada.Command_Line.Argument (1) = "--allow-empty";
   Manifest_Relative : constant String := "tests/fixtures/real_world/manifest.txt";
   Errors : Natural := 0;
   Entries : Natural := 0;

   procedure Fail (Message : String) is
   begin
      Errors := Errors + 1;
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_real_world: " & Message);
   end Fail;

   function Separator_Count (Line : String) return Natural is
      Count : Natural := 0;
   begin
      for Ch of Line loop
         if Ch = '|' then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Separator_Count;

   procedure Check_Manifest is
      Path : constant String := Project_Tools.Files.Join (Root, Manifest_Relative);
      File : Ada.Text_IO.File_Type;
      Line : String (1 .. 4096);
      Last : Natural;
      Header_Found : Boolean := False;
   begin
      if not Project_Tools.Files.File_Exists (Path) then
         Fail ("missing " & Manifest_Relative);
         return;
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Line, Last);
         declare
            Text : constant String :=
              Ada.Strings.Fixed.Trim (Line (1 .. Last), Ada.Strings.Both);
         begin
            if Text = "# id|path|source|license|mode|entry_points|expected|sha256" then
               Header_Found := True;
            elsif Text'Length > 0 and then Text (Text'First) /= '#' then
               Entries := Entries + 1;
               if Separator_Count (Text) /= 7 then
                  Fail ("manifest entry has wrong column count: " & Text);
               end if;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);

      if not Header_Found then
         Fail ("manifest header is missing required columns");
      end if;

      if Entries = 0 and then not Allow_Empty then
         Fail ("real-world corpus has no manifest entries");
      end if;
   exception
      when Ada.Text_IO.Name_Error | Ada.Text_IO.Use_Error =>
         Fail ("cannot read " & Manifest_Relative);
   end Check_Manifest;
begin
   if Root = "" then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_real_world: run below the jpeglib tree");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
      return;
   end if;

   if Ada.Command_Line.Argument_Count > 1
     or else (Ada.Command_Line.Argument_Count = 1 and then not Allow_Empty)
   then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: jpeglib_real_world [--allow-empty]");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
      return;
   end if;

   Check_Manifest;

   if Errors = 0 then
      Ada.Text_IO.Put_Line
        ("jpeglib_real_world: manifest passed with" & Natural'Image (Entries) & " entries");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "jpeglib_real_world: " & Natural'Image (Errors) & " corpus issue(s)");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Fixture_Integrity_Failure)));
   end if;
end Jpeglib_Real_World;

with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Jpeglib_Testing.Fixtures;
with Jpeglib_Tools;

procedure Jpeglib_Fixtures is
   package Corpus renames Jpeglib_Testing.Fixtures;

   procedure Set_Status (Code : Jpeglib_Tools.Exit_Code) is
   begin
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Code)));
   end Set_Status;

   procedure Check (Root : String) is
      Result : constant Corpus.Decode_Check := Corpus.Check_Corpus (Root);
   begin
      if Result.Passed then
         Ada.Text_IO.Put_Line ("jpeglib_fixtures: fixture corpus passed");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            Ada.Strings.Unbounded.To_String (Result.Message));
         Set_Status (Jpeglib_Tools.Fixture_Integrity_Failure);
      end if;
   end Check;

   Root : constant String := Corpus.Project_Root;
begin
   if Root = "" then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_fixtures: run below the jpeglib tree");
      Set_Status (Jpeglib_Tools.Invalid_Command);
      return;
   end if;

   if Ada.Command_Line.Argument_Count = 0
     or else Ada.Command_Line.Argument (1) = "--check"
   then
      Check (Root);
   elsif Ada.Command_Line.Argument (1) = "--generate" then
      Corpus.Generate (Root);
      Ada.Text_IO.Put_Line
        ("jpeglib_fixtures: generated"
         & Natural'Image (Corpus.Coefficient_Fixtures'Length + Corpus.Image_Fixtures'Length)
         & " fixtures");
      Check (Root);
   else
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "usage: jpeglib_fixtures [--check|--generate]");
      Set_Status (Jpeglib_Tools.Invalid_Command);
   end if;
end Jpeglib_Fixtures;

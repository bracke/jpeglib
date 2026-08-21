with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Hostkit;
with Hostkit.Process;

with Jpeglib_Tools;
with Project_Tools.AUnit_Checks;
with Project_Tools.Files;
with Project_Tools.Processes;

procedure Jpeglib_Check is
   function Project_Root return String is
      Current : constant String := Ada.Directories.Current_Directory;
   begin
      if Project_Tools.Files.Exists ("alire.toml") and then Project_Tools.Files.Exists ("tests/alire.toml") then
         return Current;
      elsif Project_Tools.Files.Exists ("../alire.toml") and then Project_Tools.Files.Exists ("alire.toml") then
         return Ada.Directories.Full_Name ("..");
      else
         return "";
      end if;
   end Project_Root;

   function Run
     (Label   : String;
      Dir     : String;
      Program : String;
      Args    : Hostkit.String_Vectors.Vector) return Integer
   is
      Previous : constant String := Ada.Directories.Current_Directory;
      Status   : Integer;
      Started  : Boolean;
   begin
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line ("==> " & Label);

      Ada.Directories.Set_Directory (Dir);
      Started := Hostkit.Process.Run (Program, Args, Status);
      Ada.Directories.Set_Directory (Previous);

      if Started then
         return Status;
      end if;

      return -1;
   exception
      when others =>
         if Ada.Directories.Current_Directory /= Previous then
            Ada.Directories.Set_Directory (Previous);
         end if;
         raise;
   end Run;

   function Args (Items : String) return Hostkit.String_Vectors.Vector is
      Result : Hostkit.String_Vectors.Vector;
   begin
      Result.Append (Ada.Strings.Unbounded.To_Unbounded_String (Items));
      return Result;
   end Args;

   function No_Args return Hostkit.String_Vectors.Vector is
      Result : Hostkit.String_Vectors.Vector;
   begin
      return Result;
   end No_Args;

   Root : constant String := Project_Root;
   Alr  : constant String := Project_Tools.Processes.Locate_Command ("alr");
begin
   if Root = "" then
      Ada.Text_IO.Put_Line ("jpeglib_check: run from the repository root or tests directory");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
      return;
   end if;

   if Alr = "" then
      Ada.Text_IO.Put_Line ("jpeglib_check: alr executable not found on PATH");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
      return;
   end if;

   Project_Tools.AUnit_Checks.Require_Registered_Test_Packages
     (Test_Dir => Root & "/tests/src",
      Spec_Pattern => "jpeglib_testing-test_*.ads",
      Suite_Path => Root & "/tests/src/jpeglib_testing-suite.adb",
      Suite_Add_Prefix => "new ",
      Suite_Add_Suffix => ".Test",
      Required_Stem_Suffix => "",
      Quiet => False);

   declare
      Status : Integer;
   begin
      Status := Run ("root crate build", Root, Alr, Args ("build"));

      if Status /= 0 then
         Ada.Text_IO.Put_Line ("jpeglib_check: root build failed");
         Ada.Command_Line.Set_Exit_Status
           (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Build_Failure)));
         return;
      end if;
   end;

   declare
      Status : Integer;
   begin
      Status := Run ("tests crate build", Root & "/tests", Alr, Args ("build"));

      if Status /= 0 then
         Ada.Text_IO.Put_Line ("jpeglib_check: tests build failed");
         Ada.Command_Line.Set_Exit_Status
           (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Build_Failure)));
         return;
      end if;
   end;

   declare
      Status : Integer;
   begin
      Status := Run ("fixture corpus", Root, Root & "/tests/bin/jpeglib_fixtures", Args ("--check"));

      if Status /= 0 then
         Ada.Text_IO.Put_Line ("jpeglib_check: fixture corpus failed");
         Ada.Command_Line.Set_Exit_Status
           (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Fixture_Integrity_Failure)));
         return;
      end if;
   end;

   declare
      Status : Integer;
   begin
      Status := Run ("conformance", Root, Root & "/tests/bin/jpeglib_conformance", No_Args);

      if Status /= 0 then
         Ada.Text_IO.Put_Line ("jpeglib_check: conformance failed");
         Ada.Command_Line.Set_Exit_Status
           (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Conformance_Failure)));
         return;
      end if;
   end;

   declare
      Status : Integer;
   begin
      Status := Run ("deterministic fuzz", Root, Root & "/tests/bin/jpeglib_fuzz", No_Args);

      if Status /= 0 then
         Ada.Text_IO.Put_Line ("jpeglib_check: deterministic fuzz failed");
         Ada.Command_Line.Set_Exit_Status
           (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Test_Failure)));
         return;
      end if;
   end;

   declare
      Status : Integer;
   begin
      Status := Run ("documentation", Root, Root & "/tests/bin/jpeglib_docs", No_Args);

      if Status /= 0 then
         Ada.Text_IO.Put_Line ("jpeglib_check: documentation failed");
         Ada.Command_Line.Set_Exit_Status
           (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Documentation_Failure)));
         return;
      end if;
   end;

   declare
      Status : Integer;
   begin
      Status := Run ("foundation tests", Root, Root & "/tests/bin/jpeglib_tests", No_Args);

      if Status /= 0 then
         Ada.Text_IO.Put_Line ("jpeglib_check: foundation tests failed");
         Ada.Command_Line.Set_Exit_Status
           (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Test_Failure)));
         return;
      end if;
   end;

   Ada.Text_IO.New_Line;
   Ada.Text_IO.Put_Line ("jpeglib_check: all checks passed");
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
end Jpeglib_Check;

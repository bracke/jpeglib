with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Jpeglib_Tools;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Text;

procedure Jpeglib_Prove is
   use Ada.Strings.Unbounded;

   Root : constant String :=
     Project_Tools.Files.Find_Root_Upward
       (Ada.Directories.Current_Directory, "alire.toml");
   Errors : Natural := 0;

   procedure Fail (Message : String) is
   begin
      Errors := Errors + 1;
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_prove: " & Message);
   end Fail;

   procedure Require_Text (Text : String; Pattern : String; Message : String) is
   begin
      if not Project_Tools.Text.Contains (Text, Pattern) then
         Fail (Message);
      end if;
   end Require_Text;

   procedure Require_File (Path : String) is
   begin
      if not Project_Tools.Files.File_Exists (Project_Tools.Files.Join (Root, Path)) then
         Fail ("missing " & Path);
      end if;
   end Require_File;

   function Run_Requested return Boolean is
     (Ada.Command_Line.Argument_Count = 1 and then Ada.Command_Line.Argument (1) = "--run");

   procedure Run_Proof_Unit (Unit : String) is
      Alr : constant String := Project_Tools.Processes.Locate_Command ("alr");
      Proof_Log_Path : constant String :=
        Project_Tools.Files.Join (Root, "obj/proof/gnatprove/gnatprove.out");
      Status : Integer;
   begin
      if Alr = "" then
         Fail ("alr command not found for proof profile");
         return;
      end if;

      Status :=
        Project_Tools.Processes.Run_Status
          ("proof profile",
           Root,
           Alr,
           Project_Tools.Processes.Arguments
             ([Project_Tools.Processes.Argument ("exec"),
               Project_Tools.Processes.Argument ("--"),
               Project_Tools.Processes.Argument ("gnatprove"),
               Project_Tools.Processes.Argument ("-P"),
               Project_Tools.Processes.Argument ("proof/jpeglib_proof.gpr"),
               Project_Tools.Processes.Argument ("-u"),
               Project_Tools.Processes.Argument (Unit),
               Project_Tools.Processes.Argument ("--level=0")]));
      if Status /= 0 then
         Fail ("proof profile failed for " & Unit & " with status" & Integer'Image (Status));
         return;
      end if;

      declare
         Proof_Log : constant String := To_String (Project_Tools.Text.Read_Text_File (Proof_Log_Path));
      begin
         if Project_Tools.Text.Contains (Proof_Log, "might fail") then
            Fail ("proof profile left unproved checks in " & Unit);
         end if;

         if Project_Tools.Text.Contains (Proof_Log, "medium:")
           or else Project_Tools.Text.Contains (Proof_Log, "high:")
        then
            Fail ("proof profile reported proof severity diagnostics in " & Unit);
         end if;

         if Project_Tools.Text.Contains (Proof_Log, "skipped; body is SPARK_Mode => Off") then
            Fail ("proof profile skipped a declared SPARK body in " & Unit);
         end if;
      end;
   exception
      when others =>
         Fail ("proof profile log could not be checked for " & Unit);
   end Run_Proof_Unit;

   procedure Run_Proof_Profile is
   begin
      Run_Proof_Unit ("jpeglib-internal-checked_arithmetic.adb");
      Run_Proof_Unit ("jpeglib-images.adb");
      Run_Proof_Unit ("jpeglib-internal-segments.adb");
      Run_Proof_Unit ("jpeglib-internal-ownership.adb");
   end Run_Proof_Profile;
begin
   if Root = "" then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_prove: run below the jpeglib tree");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
      return;
   end if;

   Require_File ("proof/jpeglib_proof.gpr");
   Require_File ("docs/proof_profile.md");
   Require_File ("docs/limits_and_safety.md");

   declare
      Registry_Path : constant String := Project_Tools.Files.Join (Root, "docs/invariants.md");
      Registry : constant String := To_String (Project_Tools.Text.Read_Text_File (Registry_Path));
   begin
      if Registry = "" then
         Fail ("missing or empty docs/invariants.md");
      else
         Require_Text
           (Registry,
            "| SEC-OVERFLOW-001 |",
            "missing overflow proof-designated invariant");
         Require_Text
           (Registry,
            "Jpeglib.Internal.Checked_Arithmetic` | `foundation.arithmetic.*` | Proof-designated",
            "overflow invariant lacks checked-arithmetic runtime coverage");
         Require_Text
           (Registry,
            "| IMAGE-VALID-001 |",
            "missing image descriptor validation proof-designated invariant");
         Require_Text
           (Registry,
            "Jpeglib.Images` | `foundation.images.descriptor_overflow`,"
            & " `foundation.decoder.decode_invalid_view` | Proof-designated",
            "image validation invariant lacks runtime coverage");
         Require_Text
           (Registry,
            "| FMT-SEGMENT-001 |",
            "missing segment-boundary proof-designated invariant");
         Require_Text
           (Registry,
            "Jpeglib.Internal.Segments` | `foundation.segments.bounded` | Proof-designated",
            "segment invariant lacks bounded segment runtime coverage");
         Require_Text
           (Registry,
            "| MEM-OWNER-001 | Every charged byte reservation has one lease owner,"
            & " failed reservations have no side effects, and repeated release is idempotent.",
            "missing ownership proof-designated invariant");
         Require_Text
           (Registry,
            "Jpeglib.Internal.Ownership` | `foundation.ownership.reserve_release` | Proof-designated",
            "ownership invariant lacks runtime coverage");
         Require_Text
           (Registry,
            "arithmetic CMYK/YCCK `Balanced_Progressive` as the corresponding 24-scan component-local script",
            "arithmetic CMYK/YCCK balanced-progressive invariant is missing");
         Require_Text
           (Registry,
            "keeping arithmetic fixed-bin state scan-local",
            "arithmetic progressive fixed-bin state invariant is missing");
         Require_Text
           (Registry,
            "access-bearing public views remain runtime-checked",
            "image validation invariant does not document access-bearing runtime boundary");
      end if;
   end;

   declare
      Profile_Path : constant String := Project_Tools.Files.Join (Root, "docs/proof_profile.md");
      Profile : constant String := To_String (Project_Tools.Text.Read_Text_File (Profile_Path));
   begin
      if Profile = "" then
         Fail ("missing or empty docs/proof_profile.md");
      else
         Require_Text
           (Profile,
            "alr exec -- tests/bin/jpeglib_prove --run",
            "proof profile does not document alr-driven proof command");
         Require_Text
           (Profile,
            "Jpeglib.Internal.Checked_Arithmetic",
            "proof profile does not document checked-arithmetic target");
         Require_Text
           (Profile,
            "Jpeglib.Images",
            "proof profile does not document image descriptor target");
         Require_Text
           (Profile,
            "Jpeglib.Internal.Segments",
            "proof profile does not document segment boundary target");
         Require_Text
           (Profile,
            "Jpeglib.Internal.Ownership",
            "proof profile does not document ownership target");
         Require_Text
           (Profile,
            "docs/limits_and_safety.md",
            "proof profile does not link caller-buffer safety boundary");
      end if;
   end;

   declare
      Safety_Path : constant String := Project_Tools.Files.Join (Root, "docs/limits_and_safety.md");
      Safety : constant String := To_String (Project_Tools.Text.Read_Text_File (Safety_Path));
   begin
      if Safety = "" then
         Fail ("missing or empty docs/limits_and_safety.md");
      else
         Require_Text
           (Safety,
            "SPARK-proved descriptor arithmetic",
            "safety boundary does not document proved descriptor arithmetic");
         Require_Text
           (Safety,
            "runtime-checked access-bearing views",
            "safety boundary does not document runtime access-bearing views");
         Require_Text
           (Safety,
            "Unchecked_Access",
            "safety boundary does not document Unchecked_Access policy");
         Require_Text
           (Safety,
            "configured output byte limits",
            "safety boundary does not document output byte limits");
      end if;
   end;

   if Errors = 0 and then Run_Requested then
      Run_Proof_Profile;
   end if;

   if Errors = 0 then
      if Run_Requested then
         Ada.Text_IO.Put_Line ("jpeglib_prove: proof profile passed");
      else
         Ada.Text_IO.Put_Line ("jpeglib_prove: proof-readiness audit passed");
      end if;
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "jpeglib_prove: " & Natural'Image (Errors) & " proof-readiness issue(s)");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Proof_Failure)));
   end if;
end Jpeglib_Prove;

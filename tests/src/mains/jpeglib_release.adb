with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

with Jpeglib_Tools;
with Jpeglib_Tools.Release_Digests;
with Project_Tools.Files;
with Project_Tools.Processes;

procedure Jpeglib_Release is
   Root : constant String :=
     Project_Tools.Files.Find_Root_Upward
       (Ada.Directories.Current_Directory, "alire.toml");
   Errors : Natural := 0;

   procedure Fail (Message : String) is
   begin
      Errors := Errors + 1;
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_release: " & Message);
   end Fail;

   procedure Require_File (Path : String) is
   begin
      if not Project_Tools.Files.File_Exists (Project_Tools.Files.Join (Root, Path)) then
         Fail ("missing " & Path);
      end if;
   end Require_File;

   procedure Require_Text (Path : String; Text : String) is
   begin
      if not Project_Tools.Files.File_Contains (Project_Tools.Files.Join (Root, Path), Text) then
         Fail (Path & " does not mention " & Text);
      end if;
   end Require_Text;

   procedure Run_Step (Label : String; Program : String) is
      Status : constant Integer :=
        Project_Tools.Processes.Run_Status
          (Label,
           Root,
           Project_Tools.Files.Join (Root, Program),
           Project_Tools.Processes.No_Arguments);
   begin
      if Status /= 0 then
         Fail (Label & " failed with status" & Integer'Image (Status));
      end if;
   end Run_Step;

   procedure Run_Step
     (Label : String;
      Program : String;
      Args : Project_Tools.Processes.Argument_Vectors.Vector)
   is
      Status : constant Integer :=
        Project_Tools.Processes.Run_Status
          (Label,
           Root,
           Project_Tools.Files.Join (Root, Program),
           Args);
   begin
      if Status /= 0 then
         Fail (Label & " failed with status" & Integer'Image (Status));
      end if;
   end Run_Step;

   procedure Report_Release_Digests is
      procedure Report (Relative_Path : String) is
      begin
         Ada.Text_IO.Put_Line (Jpeglib_Tools.Release_Digests.Manifest_Line (Root, Relative_Path));
      end Report;
   begin
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line ("==> release artifact digests");
      Report ("alire.toml");
      Report ("jpeglib.gpr");
      Report ("tests/alire.toml");
      Report ("tests/tests.gpr");
      Report ("README.md");
      Report ("CHANGELOG.md");
      Report ("LICENSE");
   end Report_Release_Digests;
begin
   if Root = "" then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_release: run below the jpeglib tree");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
      return;
   end if;

   Require_File ("alire.toml");
   Require_File ("jpeglib.gpr");
   Require_File ("tests/alire.toml");
   Require_File ("tests/tests.gpr");
   Require_File ("README.md");
   Require_File ("CONTRIBUTING.md");
   Require_File ("CHANGELOG.md");
   Require_File ("LICENSE");
   Require_File ("docs/external_reference_matrix.md");
   Require_File ("docs/implementation_plan.md");
   Require_File ("docs/invariants.md");
   Require_File ("docs/proof_profile.md");
   Require_File ("proof/jpeglib_proof.gpr");

   Require_Text ("alire.toml", "gnat_native = ""^15""");
   Require_Text ("README.md", "alr exec -- tests/bin/jpeglib_check");
   Require_Text ("README.md", "alr exec -- tests/bin/jpeglib_benchmark");
   Require_Text ("README.md", "alr exec -- tests/bin/jpeglib_prove --run");
   Require_Text ("README.md", "descriptor-only image view");
   Require_Text ("CONTRIBUTING.md", "alr exec -- tests/bin/jpeglib_check");
   Require_Text ("CHANGELOG.md", "0.1.0-dev");
   Require_Text ("CHANGELOG.md", "baseline Huffman decode");
   Require_Text ("CHANGELOG.md", "baseline grayscale and RGB-family encode");
   Require_Text ("CHANGELOG.md", "progressive grayscale and RGB-family encode");
   Require_Text ("CHANGELOG.md", "progressive grayscale, YCbCr, and RGB image decode");
   Require_Text ("CHANGELOG.md", "Advertise the V1 capability flags");
   Require_Text ("CHANGELOG.md", "arithmetic coding");
   Require_Text ("CHANGELOG.md", "24-scan two-bitplane");
   Require_Text ("CHANGELOG.md", "4:4:4/4:2:2/4:2:0/4:1:1");
   Require_Text ("CHANGELOG.md", "81 cases");
   Require_Text ("CHANGELOG.md", "fixed matrix");
   Require_Text ("CHANGELOG.md", "proof profile");
   Require_Text ("CHANGELOG.md", "jpeglib_decode_raw");
   Require_Text ("CHANGELOG.md", "ffmpeg");
   Require_Text ("CHANGELOG.md", "RGB-conversion decode");
   Require_Text ("CHANGELOG.md", "raw gray/RGB decode");
   Require_Text ("CHANGELOG.md", "ImageMagick-generated");
   Require_Text ("CHANGELOG.md", "Jpeglib.Images");
   Require_Text ("CHANGELOG.md", "row-span overflow rejection");
   Require_Text ("CHANGELOG.md", "limits_and_safety.md");
   Require_Text ("CHANGELOG.md", "runtime-checked access-bearing views");
   Require_Text ("CHANGELOG.md", "Photoshop_APP13");
   Require_Text ("CHANGELOG.md", "YCCK");
   Require_Text ("docs/external_reference_matrix.md", "including restarted artifacts");
   Require_Text ("docs/external_reference_matrix.md", "emitted restart markers");
   Require_Text
     ("docs/external_reference_matrix.md",
      "Differential DCT, hierarchical DCT, and hierarchical lossless encode");
   Require_Text ("docs/external_reference_matrix.md", "Required native process oracle");
   Require_Text ("docs/external_reference_matrix.md", "required third-party `ffmpeg` oracle");
   Require_Text ("docs/external_reference_matrix.md", "required third-party `ffmpeg` RGB-conversion oracle");
   Require_Text ("docs/external_reference_matrix.md", "jpeglib_decode_raw");
   Require_Text ("docs/proof_profile.md", "alr exec -- tests/bin/jpeglib_prove --run");
   Require_Text ("docs/proof_profile.md", "Jpeglib.Internal.Checked_Arithmetic");
   Require_Text ("docs/proof_profile.md", "Jpeglib.Images");
   Require_Text ("docs/proof_profile.md", "Descriptor_Is_Valid");
   Require_Text ("docs/proof_profile.md", "overflow-safe row-span rejection");
   Require_Text ("docs/proof_profile.md", "Jpeglib.Internal.Segments");
   Require_Text ("docs/proof_profile.md", "Jpeglib.Internal.Ownership");
   Require_Text ("docs/proof_profile.md", "Reserve_State");
   Require_Text ("docs/proof_profile.md", "unproved checks");
   Require_Text ("docs/proof_profile.md", "jpeglib_release");
   Require_Text ("docs/proof_profile.md", "docs/limits_and_safety.md");
   Require_Text ("docs/limits_and_safety.md", "SPARK-proved descriptor arithmetic");
   Require_Text ("docs/limits_and_safety.md", "runtime-checked access-bearing views");
   Require_Text ("docs/limits_and_safety.md", "Unchecked_Access");
   Require_Text ("docs/limits_and_safety.md", "configured output byte limits");
   Require_Text ("docs/invariants.md", "IMAGE-VALID-001");
   Require_Text ("docs/invariants.md", "foundation.images.descriptor_overflow");
   Require_Text ("docs/invariants.md", "arithmetic CMYK/YCCK `Balanced_Progressive`");
   Require_Text ("docs/implementation_plan.md", "arithmetic CMYK/YCCK emits the corresponding 24-scan");
   Require_Text ("docs/implementation_plan.md", "optional external-support diagnostics");
   Require_Text ("docs/implementation_plan.md", "native process oracle");
   Require_Text ("docs/implementation_plan.md", "ffmpeg");
   Require_Text ("docs/implementation_plan.md", "baseline/progressive CMYK/YCCK rows require `ffmpeg`");
   Require_Text ("docs/implementation_plan.md", "lossless Huffman grayscale/RGB rows");
   Require_Text ("docs/implementation_plan.md", "including restarted artifacts");
   Require_Text ("docs/implementation_plan.md", "ImageMagick-generated baseline/progressive");
   Require_Text ("docs/implementation_plan.md", "RGB 4x3/5x2/17x9/9x17");
   Require_Text ("docs/implementation_plan.md", "grayscale 5x3/4x4/17x1/2x17");
   Require_Text ("docs/implementation_plan.md", "Jpeglib.Images");
   Require_Text ("docs/implementation_plan.md", "Jpeglib.Internal.Ownership");
   Require_Text ("docs/implementation_plan.md", "skipped declared SPARK bodies");
   Require_Text ("docs/implementation_plan.md", "runs 81 deterministic cases");
   Require_Text ("docs/implementation_plan.md", "fixed encode/decode timing matrix");
   Require_Text ("docs/implementation_plan.md", "proof profile");

   if Errors = 0 then
      Report_Release_Digests;
   end if;

   if Errors = 0 then
      Run_Step
        ("release proof profile",
         "tests/bin/jpeglib_prove",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("--run")]));
   end if;

   if Errors = 0 then
      Run_Step ("release aggregate gate", "tests/bin/jpeglib_check");
   end if;

   if Errors = 0 then
      Run_Step ("release benchmark smoke", "tests/bin/jpeglib_benchmark");
   end if;

   if Errors = 0 then
      Ada.Text_IO.Put_Line ("jpeglib_release: release readiness checks passed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "jpeglib_release: " & Natural'Image (Errors) & " release readiness issue(s)");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Release_Reproducibility_Failure)));
   end if;
end Jpeglib_Release;

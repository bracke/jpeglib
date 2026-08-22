with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

with Jpeglib_Tools;
with Project_Tools.Files;
with Project_Tools.Release_Checks;

procedure Jpeglib_Docs is
   Root : constant String :=
     Project_Tools.Files.Find_Root_Upward
       (Ada.Directories.Current_Directory, "alire.toml");
   Errors : Natural := 0;

   procedure Require_File (Path : String) is
   begin
      if Root = "" or else not Project_Tools.Files.File_Exists (Project_Tools.Files.Join (Root, Path)) then
         Errors := Errors + 1;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_docs: missing " & Path);
      end if;
   end Require_File;

   procedure Require_Text (Path : String; Text : String) is
   begin
      if Root = "" or else not Project_Tools.Files.File_Contains (Project_Tools.Files.Join (Root, Path), Text) then
         Errors := Errors + 1;
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "jpeglib_docs: " & Path & " does not mention " & Text);
      end if;
   end Require_Text;

   Stale : constant String :=
     (if Root = "" then "" else Project_Tools.Release_Checks.Stale_Doc_Scaffolding (Root));
begin
   if Root = "" then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_docs: run below the jpeglib tree");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
      return;
   end if;

   Require_File ("README.md");
   Require_File ("CONTRIBUTING.md");
   Require_File ("docs/ai_implementation_guide.md");
   Require_File ("docs/coefficient_decoding.md");
   Require_File ("docs/external_reference_matrix.md");
   Require_File ("docs/implementation_plan.md");
   Require_File ("docs/invariants.md");
   Require_File ("docs/proof_profile.md");
   Require_File ("docs/limits_and_safety.md");
   Require_File ("proof/jpeglib_proof.gpr");

   Require_Text ("README.md", "alr exec -- tests/bin/jpeglib_check");
   Require_Text ("README.md", "alr exec -- tests/bin/jpeglib_fuzz");
   Require_Text ("README.md", "alr exec -- tests/bin/jpeglib_benchmark");
   Require_Text ("README.md", "magick");
   Require_Text ("README.md", "ffmpeg");
   Require_Text ("README.md", "external_reference_matrix.md");
   Require_Text ("README.md", "jpeglib_decode_raw");
   Require_Text ("README.md", "ImageMagick-backed conformance");
   Require_Text ("README.md", "descriptor-only image view");
   Require_Text ("README.md", "Descriptor_Is_Valid");
   Require_Text ("README.md", "limits_and_safety.md");
   Require_Text ("README.md", "jpeglib_prove --run");
   Require_Text ("CONTRIBUTING.md", "alr exec -- tests/bin/jpeglib_check");
   Require_Text ("docs/external_reference_matrix.md", "Diagnostic");
   Require_Text ("docs/external_reference_matrix.md", "Required native process oracle");
   Require_Text ("docs/external_reference_matrix.md", "required third-party `ffmpeg` oracle");
   Require_Text ("docs/external_reference_matrix.md", "required third-party `ffmpeg` RGB-conversion oracle");
   Require_Text ("docs/external_reference_matrix.md", "jpeglib_decode_raw");
   Require_Text ("docs/external_reference_matrix.md", "Arithmetic sequential/progressive DCT encode");
   Require_Text ("docs/external_reference_matrix.md", "including restarted artifacts");
   Require_Text ("docs/external_reference_matrix.md", "emitted restart markers");
   Require_Text
     ("docs/external_reference_matrix.md",
      "Differential DCT, hierarchical DCT, and hierarchical lossless encode");
   Require_Text ("docs/proof_profile.md", "alr exec -- tests/bin/jpeglib_prove --run");
   Require_Text ("docs/proof_profile.md", "Jpeglib.Internal.Checked_Arithmetic");
   Require_Text ("docs/proof_profile.md", "Jpeglib.Images");
   Require_Text ("docs/proof_profile.md", "Descriptor_Is_Valid");
   Require_Text ("docs/proof_profile.md", "overflow-safe row-span rejection");
   Require_Text ("docs/proof_profile.md", "jpeglib_release");
   Require_Text ("docs/proof_profile.md", "Jpeglib.Internal.Ownership");
   Require_Text ("docs/proof_profile.md", "Reserve_State");
   Require_Text ("docs/proof_profile.md", "Jpeglib.Capabilities");
   Require_Text ("docs/proof_profile.md", "unproved checks");
   Require_Text ("docs/proof_profile.md", "docs/limits_and_safety.md");
   Require_Text ("docs/limits_and_safety.md", "SPARK-proved descriptor arithmetic");
   Require_Text ("docs/limits_and_safety.md", "runtime-checked access-bearing views");
   Require_Text ("docs/limits_and_safety.md", "Unchecked_Access");
   Require_Text ("docs/limits_and_safety.md", "configured output byte limits");
   Require_Text ("docs/implementation_plan.md", "Jpeglib.Capabilities.Baseline_Encode");
   Require_Text ("docs/implementation_plan.md", "jpeglib_conformance");
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
   Require_Text ("docs/implementation_plan.md", "Jpeglib.Capabilities");
   Require_Text ("docs/implementation_plan.md", "skipped declared SPARK bodies");
   Require_Text ("docs/proof_profile.md", "Jpeglib.Internal.Segments");
   Require_Text ("docs/implementation_plan.md", "jpeglib_fuzz");
   Require_Text ("docs/implementation_plan.md", "jpeglib_benchmark");
   Require_Text ("docs/implementation_plan.md", "Jpeglib.Encoding.Add_Metadata_Segment");
   Require_Text ("docs/invariants.md", "ARITH-001");
   Require_Text ("docs/invariants.md", "ARITH-002");
   Require_Text ("docs/invariants.md", "ARITH-003");
   Require_Text ("docs/invariants.md", "ARITH-004");
   Require_Text ("docs/invariants.md", "ARITH-005");
   Require_Text ("docs/invariants.md", "ARITH-006");
   Require_Text ("docs/invariants.md", "ARITH-007");
   Require_Text ("docs/invariants.md", "ARITH-008");
   Require_Text ("docs/invariants.md", "ARITH-009");
   Require_Text ("docs/invariants.md", "ARITH-010");
   Require_Text ("docs/invariants.md", "ARITH-011");
   Require_Text ("docs/invariants.md", "ARITH-012");
   Require_Text ("docs/invariants.md", "ARITH-013");
   Require_Text ("docs/invariants.md", "ARITH-014");
   Require_Text ("docs/invariants.md", "ARITH-015");
   Require_Text ("docs/invariants.md", "ARITH-016");
   Require_Text ("docs/invariants.md", "ARITH-017");
   Require_Text ("docs/invariants.md", "ARITH-018");
   Require_Text ("docs/invariants.md", "IMAGE-VALID-001");
   Require_Text ("docs/invariants.md", "foundation.images.descriptor_overflow");
   Require_Text ("docs/invariants.md", "ENCODE-011");
   Require_Text ("docs/invariants.md", "COEFF-007");
   Require_Text ("docs/invariants.md", "IMAGE-010");
   Require_Text ("docs/invariants.md", "IMAGE-013");
   Require_Text ("docs/invariants.md", "IMAGE-014");
   Require_Text ("docs/invariants.md", "IMAGE-015");
   Require_Text ("docs/invariants.md", "META-009");
   Require_Text ("docs/invariants.md", "META-010");
   Require_Text ("docs/invariants.md", "ADV-001");
   Require_Text ("docs/invariants.md", "MEM-OWNER-001");
   Require_Text ("README.md", "YCCK");
   Require_Text ("README.md", "V1 mode/format matrix");
   Require_Text ("README.md", "SOF zero-height/DNL-defined images");
   Require_Text ("CHANGELOG.md", "public V1 encode mode/format matrix");
   Require_Text ("CHANGELOG.md", "Photoshop_APP13");
   Require_Text ("README.md", "APP13 Photoshop");
   Require_Text ("docs/invariants.md", "APP13 Photoshop");
   Require_Text ("docs/implementation_plan.md", "Photoshop APP13");
   Require_Text ("docs/invariants.md", "foundation.encoder.encode_rgb_roundtrip");
   Require_Text ("docs/coefficient_decoding.md", "Jpeglib.Capabilities.Coefficients");

   if Stale /= "" then
      Errors := Errors + 1;
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "jpeglib_docs: stale documentation scaffolding remains:");
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Stale);
   end if;

   if Errors = 0 then
      Ada.Text_IO.Put_Line ("jpeglib_docs: documentation checks passed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "jpeglib_docs: " & Natural'Image (Errors) & " documentation issue(s)");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Documentation_Failure)));
   end if;
end Jpeglib_Docs;

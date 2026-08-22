with AUnit.Assertions;

with Jpeglib.Capabilities;
with Jpeglib_Tools.Release_Digests;

package body Jpeglib_Testing.Test_Capabilities_Release is
   use AUnit.Assertions;

   procedure Capability_Surface_Advertises_Complete_Library (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Release_Digest_Uses_SHA256 (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("capabilities and release");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Capability_Surface_Advertises_Complete_Library'Access,
         "capabilities.v1");
      Register_Routine (T, Release_Digest_Uses_SHA256'Access, "release.digest_sha256");
   end Register_Tests;

   procedure Capability_Surface_Advertises_Complete_Library (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Jpeglib.Capabilities.Coefficients, "public coefficient decode must be advertised");
      Assert (Jpeglib.Capabilities.Grayscale, "grayscale image decode must be advertised");
      Assert (Jpeglib.Capabilities.YCbCr, "YCbCr image decode must be advertised");
      Assert (Jpeglib.Capabilities.RGB_JPEG, "RGB JPEG image decode must be advertised");
      Assert (Jpeglib.Capabilities.CMYK, "CMYK image decode must be advertised");
      Assert (Jpeglib.Capabilities.Huffman_Coding, "Huffman-coded baseline decode must be advertised");
      Assert (Jpeglib.Capabilities.Restart_Intervals, "restart interval decode must be advertised");
      Assert (Jpeglib.Capabilities.Baseline_Decode, "baseline decode must be advertised");
      Assert (Jpeglib.Capabilities.Baseline_Encode, "baseline encode must be advertised");
      Assert (Jpeglib.Capabilities.Progressive_Decode, "progressive image decode must be advertised");
      Assert (Jpeglib.Capabilities.Progressive_Encode, "progressive encode must be advertised");
      Assert (Jpeglib.Capabilities.Arithmetic_Coding, "arithmetic coding must be advertised");
      Assert (Jpeglib.Capabilities.Twelve_Bit_DCT, "12-bit DCT must be advertised");
      Assert (Jpeglib.Capabilities.Lossless_JPEG, "lossless JPEG must be advertised");
      Assert (Jpeglib.Capabilities.Hierarchical_JPEG, "hierarchical JPEG must be advertised");
      Assert (Jpeglib.Capabilities.YCCK, "YCCK must be advertised");
      Assert (Jpeglib.Capabilities.Raw_Components, "raw components must be advertised");
      Assert (Jpeglib.Capabilities.Reduced_IDCT, "reduced IDCT must be advertised");
      Assert (Jpeglib.Capabilities.Exif_Orientation, "Exif orientation must be advertised");
      Assert (Jpeglib.Capabilities.ICC_Preservation, "ICC preservation must be advertised");
      Assert (Jpeglib.Capabilities.Coefficient_Transforms, "coefficient transforms must be advertised");
      Assert (Jpeglib.Capabilities.SIMD_Acceleration, "SIMD acceleration must be advertised");
   end Capability_Surface_Advertises_Complete_Library;

   procedure Release_Digest_Uses_SHA256 (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert
        (Jpeglib_Tools.Release_Digests.SHA256_Hex ("abc")
         = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
         "release digest helper did not compute SHA-256");
   end Release_Digest_Uses_SHA256;
end Jpeglib_Testing.Test_Capabilities_Release;

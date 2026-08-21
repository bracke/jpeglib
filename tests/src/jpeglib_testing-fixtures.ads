with Ada.Strings.Unbounded;

with Jpeglib.Coefficients;
with Jpeglib.Errors;
with Jpeglib.Images;

package Jpeglib_Testing.Fixtures is
   type Fixture_Kind is (Valid_Coefficients, Invalid_Coefficients);
   type Fixture_Id is
     (Baseline_Gray,
      Baseline_Gray_Restart,
      Baseline_YCbCr,
      Invalid_Gray_Wrong_Restart,
      Invalid_YCbCr_Incomplete_Scans);

   type Fixture is record
      Id : Fixture_Id;
      Kind : Fixture_Kind;
      Expected_Blocks : Jpeglib.Block_Count := 0;
      Expected_Error : Jpeglib.Errors.Error_Code := Jpeglib.Errors.No_Error;
      First_DC : Jpeglib.Coefficients.Quantized_Coefficient := 0;
      Last_DC : Jpeglib.Coefficients.Quantized_Coefficient := 0;
   end record;

   type Fixture_List is array (Positive range <>) of Fixture;

   Coefficient_Fixtures : constant Fixture_List :=
     [(Id => Baseline_Gray,
       Kind => Valid_Coefficients,
       Expected_Blocks => 2,
       Expected_Error => Jpeglib.Errors.No_Error,
       First_DC => 2,
       Last_DC => 4),
      (Id => Baseline_Gray_Restart,
       Kind => Valid_Coefficients,
       Expected_Blocks => 2,
       Expected_Error => Jpeglib.Errors.No_Error,
       First_DC => 2,
       Last_DC => 2),
      (Id => Baseline_YCbCr,
       Kind => Valid_Coefficients,
       Expected_Blocks => 12,
       Expected_Error => Jpeglib.Errors.No_Error,
       First_DC => 2,
       Last_DC => 4),
      (Id => Invalid_Gray_Wrong_Restart,
       Kind => Invalid_Coefficients,
       Expected_Blocks => 2,
       Expected_Error => Jpeglib.Errors.Restart_Invalid_State,
       First_DC => 0,
       Last_DC => 0),
      (Id => Invalid_YCbCr_Incomplete_Scans,
       Kind => Invalid_Coefficients,
       Expected_Blocks => 12,
       Expected_Error => Jpeglib.Errors.Scan_Invalid_Definition,
       First_DC => 0,
       Last_DC => 0)];

   type Image_Fixture_Id is
     (Image_Baseline_Gray,
      Image_Baseline_Gray_Restart,
      Image_Baseline_YCbCr,
      Image_Baseline_YCbCr_Restart,
      Image_Baseline_YCbCr_Separate,
      Image_Baseline_RGB,
      Image_Baseline_CMYK,
      Image_Baseline_CMYK_Separate,
      Image_Progressive_RGB_Encoded,
      Image_Arithmetic_Progressive_RGB_Encoded,
      Image_Differential_DCT_RGB_Encoded,
      Image_Hierarchical_DCT_RGB_Encoded,
      Image_Arithmetic_Lossless_RGB_Encoded,
      Image_Differential_Lossless_RGB_Encoded,
      Image_Hierarchical_Lossless_RGB_Encoded,
      Image_Arithmetic_Progressive_CMYK_Encoded,
      Image_Arithmetic_Progressive_YCCK_Encoded,
      Image_Arithmetic_Lossless_CMYK_Encoded,
      Image_Arithmetic_Lossless_YCCK_Encoded);

   type Image_Fixture is record
      Id : Image_Fixture_Id;
      Width : Jpeglib.Image_Width;
      Height : Jpeglib.Image_Height;
      Format : Jpeglib.Images.Pixel_Format;
      Alpha : Jpeglib.Byte := Jpeglib.Byte'Last;
      Expected_First : Jpeglib.Byte := 128;
      Expected_Last : Jpeglib.Byte := 128;
      Expected_SHA256 : String (1 .. 64) := [others => '0'];
   end record;

   type Image_Fixture_List is array (Positive range <>) of Image_Fixture;

   Image_Fixtures : constant Image_Fixture_List :=
     [(Id => Image_Baseline_Gray,
       Width => 16,
       Height => 8,
       Format => Jpeglib.Images.RGB_24,
       Alpha => Jpeglib.Byte'Last,
       Expected_First => 128,
       Expected_Last => 128,
       Expected_SHA256 => "f83545d43c6939ec393b6b8310959b6174fd764b08a12fc22d908408a7e6a43e"),
      (Id => Image_Baseline_Gray_Restart,
       Width => 16,
       Height => 8,
       Format => Jpeglib.Images.Gray_8,
       Alpha => Jpeglib.Byte'Last,
       Expected_First => 128,
       Expected_Last => 128,
       Expected_SHA256 => "b7effd43ee5016021d067dd32ade04f37a347efe942297070e5cc56f47fddfbb"),
      (Id => Image_Baseline_YCbCr,
       Width => 17,
       Height => 9,
       Format => Jpeglib.Images.RGBA_32,
       Alpha => 77,
       Expected_First => 128,
       Expected_Last => 130,
       Expected_SHA256 => "70873e8f831982bab4c21ec2ccbedf5093181a148443d1071970632cf991f127"),
      (Id => Image_Baseline_YCbCr_Restart,
       Width => 17,
       Height => 9,
       Format => Jpeglib.Images.RGBA_32,
       Alpha => 77,
       Expected_First => 128,
       Expected_Last => 129,
       Expected_SHA256 => "094e455d884c00d1e969b473c5e20a06824cc2baaa2eb87a51e9a2c2f7c8df4b"),
      (Id => Image_Baseline_YCbCr_Separate,
       Width => 17,
       Height => 9,
       Format => Jpeglib.Images.RGB_24,
       Alpha => Jpeglib.Byte'Last,
       Expected_First => 128,
       Expected_Last => 129,
       Expected_SHA256 => "0fddadf075543913e0916859904b2db40c624044ff8ab59dff51b01d0a024288"),
      (Id => Image_Baseline_RGB,
       Width => 8,
       Height => 8,
       Format => Jpeglib.Images.BGRA_32,
       Alpha => 31,
       Expected_First => 128,
       Expected_Last => 128,
       Expected_SHA256 => "7e00761e78b3d0cac49878d18966921b0ab15589ef84425511fc7e1980e7c119"),
      (Id => Image_Baseline_CMYK,
       Width => 8,
       Height => 8,
       Format => Jpeglib.Images.RGBA_32,
       Alpha => 91,
       Expected_First => 0,
       Expected_Last => 0,
       Expected_SHA256 => "d9442e00401281d3cfabd20e8c860fcc9c63b294699eaf1591c6ef6718a42ba7"),
      (Id => Image_Baseline_CMYK_Separate,
       Width => 8,
       Height => 8,
       Format => Jpeglib.Images.RGB_24,
       Alpha => Jpeglib.Byte'Last,
       Expected_First => 0,
       Expected_Last => 0,
       Expected_SHA256 => "5d89f056865052bcb89c910d2d62872e029fb273c3db03f8968a52a41593c1b5"),
      (Id => Image_Progressive_RGB_Encoded,
       Width => 2,
       Height => 2,
       Format => Jpeglib.Images.RGB_24,
       Alpha => Jpeglib.Byte'Last,
       Expected_First => 0,
       Expected_Last => 255,
      Expected_SHA256 => "8e77dd72063fcafbe4c3f1866521977adb9b4e28d13c52cd7c96f586a34be6f6"),
      (Id => Image_Arithmetic_Progressive_RGB_Encoded,
       Width => 2,
       Height => 2,
      Format => Jpeglib.Images.RGB_24,
      Alpha => Jpeglib.Byte'Last,
      Expected_First => 131,
      Expected_Last => 203,
      Expected_SHA256 => "96aa1d1a7e036826194954d0ec665bc2a8cb17a3a957429fd5e5f4f4a68c1567"),
      (Id => Image_Differential_DCT_RGB_Encoded,
       Width => 2,
       Height => 2,
       Format => Jpeglib.Images.RGB_24,
       Alpha => Jpeglib.Byte'Last,
       Expected_First => 0,
       Expected_Last => 255,
       Expected_SHA256 => "8e77dd72063fcafbe4c3f1866521977adb9b4e28d13c52cd7c96f586a34be6f6"),
      (Id => Image_Hierarchical_DCT_RGB_Encoded,
       Width => 2,
       Height => 2,
       Format => Jpeglib.Images.RGB_24,
       Alpha => Jpeglib.Byte'Last,
       Expected_First => 0,
       Expected_Last => 255,
       Expected_SHA256 => "8e77dd72063fcafbe4c3f1866521977adb9b4e28d13c52cd7c96f586a34be6f6"),
      (Id => Image_Arithmetic_Lossless_RGB_Encoded,
       Width => 2,
       Height => 2,
       Format => Jpeglib.Images.RGB_24,
       Alpha => Jpeglib.Byte'Last,
       Expected_First => 0,
       Expected_Last => 255,
       Expected_SHA256 => "80992d99f55f6928526c55a9a05314a712d86a56207daf8413793484904f1d4e"),
      (Id => Image_Differential_Lossless_RGB_Encoded,
       Width => 2,
       Height => 2,
       Format => Jpeglib.Images.RGB_24,
       Alpha => Jpeglib.Byte'Last,
       Expected_First => 0,
       Expected_Last => 255,
       Expected_SHA256 => "80992d99f55f6928526c55a9a05314a712d86a56207daf8413793484904f1d4e"),
      (Id => Image_Hierarchical_Lossless_RGB_Encoded,
       Width => 2,
       Height => 2,
       Format => Jpeglib.Images.RGB_24,
       Alpha => Jpeglib.Byte'Last,
       Expected_First => 0,
       Expected_Last => 255,
       Expected_SHA256 => "80992d99f55f6928526c55a9a05314a712d86a56207daf8413793484904f1d4e"),
      (Id => Image_Arithmetic_Progressive_CMYK_Encoded,
      Width => 2,
      Height => 2,
      Format => Jpeglib.Images.CMYK_32,
      Alpha => 172,
      Expected_First => 6,
      Expected_Last => 83,
      Expected_SHA256 => "8c45d93af4db7993fb4e7ea9af84241171c6ffb36a466b7615b57370b18444de"),
      (Id => Image_Arithmetic_Progressive_YCCK_Encoded,
      Width => 2,
      Height => 2,
      Format => Jpeglib.Images.YCCK_32,
      Alpha => 172,
      Expected_First => 6,
      Expected_Last => 83,
      Expected_SHA256 => "8c45d93af4db7993fb4e7ea9af84241171c6ffb36a466b7615b57370b18444de"),
      (Id => Image_Arithmetic_Lossless_CMYK_Encoded,
       Width => 2,
       Height => 2,
       Format => Jpeglib.Images.CMYK_32,
       Alpha => 176,
       Expected_First => 0,
       Expected_Last => 80,
       Expected_SHA256 => "b1f01163a0b3c0f051efc97247169352425bd90da9cadfa20e9a0835d4f811fd"),
      (Id => Image_Arithmetic_Lossless_YCCK_Encoded,
       Width => 2,
       Height => 2,
       Format => Jpeglib.Images.YCCK_32,
       Alpha => 176,
       Expected_First => 0,
       Expected_Last => 80,
       Expected_SHA256 => "b1f01163a0b3c0f051efc97247169352425bd90da9cadfa20e9a0835d4f811fd")];

   type Decode_Check is record
      Passed : Boolean := False;
      Message : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   function Name_Of (Id : Fixture_Id) return String;
   function Name_Of (Id : Image_Fixture_Id) return String;
   function Project_Root return String;
   function Coefficient_Directory (Root : String) return String;
   function Image_Directory (Root : String) return String;
   function Path_For (Root : String; Id : Fixture_Id) return String;
   function Path_For (Root : String; Id : Image_Fixture_Id) return String;
   function Read_File (Path : String) return Ada.Strings.Unbounded.Unbounded_String;
   function Manifest return String;
   function Image_Manifest return String;
   procedure Generate (Root : String);
   function Decode_File (Path : String; Item : Fixture) return Decode_Check;
   function Decode_Image_File (Path : String; Item : Image_Fixture) return Decode_Check;
   function Check_Corpus (Root : String) return Decode_Check;
end Jpeglib_Testing.Fixtures;

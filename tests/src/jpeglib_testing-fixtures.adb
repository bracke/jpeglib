with Ada.Directories;
with Ada.Streams;

with CryptoLib.Hashes;
with Jpeglib.Decoding;
with Jpeglib.Encoding;
with Jpeglib.Results;
with Jpeglib.Streams;
with Project_Tools.Files;

package body Jpeglib_Testing.Fixtures is
   use type Ada.Streams.Stream_Element_Offset;
   use type Jpeglib.Block_Count;
   use type Jpeglib.Byte;
   use type Jpeglib.Byte_Count;
   use type Jpeglib.Coefficients.Quantized_Coefficient;
   use type Jpeglib.Errors.Error_Code;

   type Payload_Access is access constant Jpeglib.Streams.Byte_Array;

   function SHA256_Hex (Data : Jpeglib.Streams.Byte_Array) return String is
      Hex : constant String := "0123456789abcdef";
      Bytes : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Data'Length));
      Cursor : Ada.Streams.Stream_Element_Offset := Bytes'First;
      Digest : CryptoLib.Hashes.SHA256_Digest;
      Result : String (1 .. 64);
      Value : Natural;
   begin
      for Item of Data loop
         Bytes (Cursor) := Ada.Streams.Stream_Element (Item);
         Cursor := Cursor + 1;
      end loop;

      Digest := CryptoLib.Hashes.SHA256 (Bytes);
      for Index in Digest'Range loop
         Value := Natural (Digest (Index));
         Result (Index * 2 - 1) := Hex (Value / 16 + 1);
         Result (Index * 2) := Hex (Value mod 16 + 1);
      end loop;

      return Result;
   end SHA256_Hex;

   Full_Gray_Coefficient_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#C4#,
      0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#10#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#C0#,
      0, 11,
      8, 0, 8, 0, 16, 1,
      1, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 63, 0,
      16#44#,
      16#FF#, 16#D9#];

   Full_Gray_Restart_Coefficient_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#C4#,
      0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#10#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#DD#, 0, 4, 0, 1,
      16#FF#, 16#C0#,
      0, 11,
      8, 0, 8, 0, 16, 1,
      1, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 63, 0,
      16#4F#,
      16#FF#, 16#D0#,
      16#40#,
      16#FF#, 16#D9#];

   Bad_Gray_Restart_Coefficient_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#C4#,
      0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#10#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#DD#, 0, 4, 0, 1,
      16#FF#, 16#C0#,
      0, 11,
      8, 0, 8, 0, 16, 1,
      1, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 63, 0,
      16#4F#,
      16#FF#, 16#D1#,
      16#40#,
      16#FF#, 16#D9#];

   Full_Color_Coefficient_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#C4#,
      0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#10#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#C4#,
      0, 20, 1,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#11#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#C0#,
      0, 17,
      8, 0, 9, 0, 17, 3,
      1, 16#22#, 0,
      2, 16#11#, 1,
      3, 16#11#, 1,
      16#FF#, 16#DA#,
      0, 12,
      3,
      1, 16#00#,
      2, 16#11#,
      3, 16#11#,
      0, 63, 0,
      16#44#, 16#44#, 16#44#, 16#44#, 16#44#, 16#44#,
      16#FF#, 16#D9#];

   Incomplete_Color_Separate_Scan_Coefficient_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#C4#,
      0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#10#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#C4#,
      0, 20, 1,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#11#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#C0#,
      0, 17,
      8, 0, 9, 0, 17, 3,
      1, 16#22#, 0,
      2, 16#11#, 1,
      3, 16#11#, 1,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 63, 0,
      16#44#, 16#44#, 16#44#,
      16#FF#, 16#D9#];

   Full_Gray_Image_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#DB#,
      0, 67, 0,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      16#FF#, 16#C4#,
      0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#10#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#C0#,
      0, 11,
      8, 0, 8, 0, 16, 1,
      1, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 63, 0,
      16#44#,
      16#FF#, 16#D9#];

   Full_Gray_Restart_Image_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#DB#,
      0, 67, 0,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      16#FF#, 16#C4#,
      0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#10#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#DD#, 0, 4, 0, 1,
      16#FF#, 16#C0#,
      0, 11,
      8, 0, 8, 0, 16, 1,
      1, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 63, 0,
      16#4F#,
      16#FF#, 16#D0#,
      16#40#,
      16#FF#, 16#D9#];

   Full_Color_Image_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#DB#,
      0, 132,
      0,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      16#FF#, 16#C4#,
      0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#10#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#C4#,
      0, 20, 1,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#11#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#C0#,
      0, 17,
      8, 0, 9, 0, 17, 3,
      1, 16#22#, 0,
      2, 16#11#, 1,
      3, 16#11#, 1,
      16#FF#, 16#DA#,
      0, 12,
      3,
      1, 16#00#,
      2, 16#11#,
      3, 16#11#,
      0, 63, 0,
      16#44#, 16#44#, 16#44#, 16#44#, 16#44#, 16#44#,
      16#FF#, 16#D9#];

   Full_Color_Restart_Image_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#DB#,
      0, 132,
      0,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      16#FF#, 16#C4#,
      0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#10#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#C4#,
      0, 20, 1,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#11#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#DD#, 0, 4, 0, 1,
      16#FF#, 16#C0#,
      0, 17,
      8, 0, 9, 0, 17, 3,
      1, 16#22#, 0,
      2, 16#11#, 1,
      3, 16#11#, 1,
      16#FF#, 16#DA#,
      0, 12,
      3,
      1, 16#00#,
      2, 16#11#,
      3, 16#11#,
      0, 63, 0,
      16#44#, 16#44#, 16#44#,
      16#FF#, 16#D0#,
      16#44#, 16#44#, 16#44#,
      16#FF#, 16#D9#];

   Full_Color_Separate_Image_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#DB#,
      0, 132,
      0,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      16#FF#, 16#C4#,
      0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#10#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#C4#,
      0, 20, 1,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#11#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#C0#,
      0, 17,
      8, 0, 9, 0, 17, 3,
      1, 16#22#, 0,
      2, 16#11#, 1,
      3, 16#11#, 1,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 63, 0,
      16#44#, 16#44#, 16#44#,
      16#FF#, 16#DA#,
      0, 8,
      1,
      2, 16#11#,
      0, 63, 0,
      16#44#,
      16#FF#, 16#DA#,
      0, 8,
      1,
      3, 16#11#,
      0, 63, 0,
      16#44#,
      16#FF#, 16#D9#];

   Full_RGB_Image_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#DB#,
      0, 67, 0,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      16#FF#, 16#C4#,
      0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#10#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#C0#,
      0, 17,
      8, 0, 8, 0, 8, 3,
      16#52#, 16#11#, 0,
      16#47#, 16#11#, 0,
      16#42#, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 12,
      3,
      16#52#, 16#00#,
      16#47#, 16#00#,
      16#42#, 16#00#,
      0, 63, 0,
      16#44#, 16#40#,
      16#FF#, 16#D9#];

   Full_CMYK_Image_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#DB#,
      0, 67, 0,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      16#FF#, 16#C4#,
      0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#10#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#C0#,
      0, 20,
      8, 0, 8, 0, 8, 4,
      16#43#, 16#11#, 0,
      16#4D#, 16#11#, 0,
      16#59#, 16#11#, 0,
      16#4B#, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 14,
      4,
      16#43#, 16#00#,
      16#4D#, 16#00#,
      16#59#, 16#00#,
      16#4B#, 16#00#,
      0, 63, 0,
      16#44#, 16#44#,
      16#FF#, 16#D9#];

   Full_CMYK_Separate_Image_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#DB#,
      0, 67, 0,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      16#FF#, 16#C4#,
      0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#10#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#C0#,
      0, 20,
      8, 0, 8, 0, 8, 4,
      16#43#, 16#11#, 0,
      16#4D#, 16#11#, 0,
      16#59#, 16#11#, 0,
      16#4B#, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 8,
      1,
      16#43#, 16#00#,
      0, 63, 0,
      16#40#,
      16#FF#, 16#DA#,
      0, 8,
      1,
      16#4D#, 16#00#,
      0, 63, 0,
      16#40#,
      16#FF#, 16#DA#,
      0, 8,
      1,
      16#59#, 16#00#,
      0, 63, 0,
      16#40#,
      16#FF#, 16#DA#,
      0, 8,
      1,
      16#4B#, 16#00#,
      0, 63, 0,
      16#40#,
      16#FF#, 16#D9#];

   function Payload_Of (Id : Fixture_Id) return Payload_Access is
   begin
      case Id is
         when Baseline_Gray =>
            return Full_Gray_Coefficient_Storage'Access;
         when Baseline_Gray_Restart =>
            return Full_Gray_Restart_Coefficient_Storage'Access;
         when Baseline_YCbCr =>
            return Full_Color_Coefficient_Storage'Access;
         when Invalid_Gray_Wrong_Restart =>
            return Bad_Gray_Restart_Coefficient_Storage'Access;
         when Invalid_YCbCr_Incomplete_Scans =>
            return Incomplete_Color_Separate_Scan_Coefficient_Storage'Access;
      end case;
   end Payload_Of;

   function Payload_Of (Id : Image_Fixture_Id) return Payload_Access is
   begin
      case Id is
         when Image_Baseline_Gray =>
            return Full_Gray_Image_Storage'Access;
         when Image_Baseline_Gray_Restart =>
            return Full_Gray_Restart_Image_Storage'Access;
         when Image_Baseline_YCbCr =>
            return Full_Color_Image_Storage'Access;
         when Image_Baseline_YCbCr_Restart =>
            return Full_Color_Restart_Image_Storage'Access;
         when Image_Baseline_YCbCr_Separate =>
            return Full_Color_Separate_Image_Storage'Access;
         when Image_Baseline_RGB =>
            return Full_RGB_Image_Storage'Access;
         when Image_Baseline_CMYK =>
            return Full_CMYK_Image_Storage'Access;
         when Image_Baseline_CMYK_Separate =>
            return Full_CMYK_Separate_Image_Storage'Access;
         when Image_Progressive_RGB_Encoded
            | Image_Arithmetic_Progressive_RGB_Encoded
            | Image_Differential_DCT_RGB_Encoded
            | Image_Hierarchical_DCT_RGB_Encoded
            | Image_Arithmetic_Lossless_RGB_Encoded
            | Image_Differential_Lossless_RGB_Encoded
            | Image_Hierarchical_Lossless_RGB_Encoded
            | Image_Arithmetic_Progressive_CMYK_Encoded
            | Image_Arithmetic_Progressive_YCCK_Encoded
            | Image_Arithmetic_Lossless_CMYK_Encoded
            | Image_Arithmetic_Lossless_YCCK_Encoded =>
            raise Program_Error with "generated image fixture has no static payload";
      end case;
   end Payload_Of;

   function Raw (Payload : Jpeglib.Streams.Byte_Array) return String is
      Result : String (1 .. Payload'Length);
      Index : Natural := Result'First;
   begin
      for Item of Payload loop
         Result (Index) := Character'Val (Natural (Item));
         Index := Index + 1;
      end loop;
      return Result;
   end Raw;

   function Encoded_RGB_2x2 (Label : String; Options : Jpeglib.Encoding.Options) return String is
      Input_Storage : aliased Jpeglib.Streams.Byte_Array :=
        [0, 32, 64,
         96, 128, 160,
         192, 224, 240,
         255, 16, 48];
      Encoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 4096 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Encoder : Jpeglib.Encoding.Encoder;
      Input : constant Jpeglib.Images.Image_View :=
        (Descriptor =>
           (Width => 2,
            Height => 2,
            Format => Jpeglib.Images.RGB_24,
            Stride => 6,
            Accessible_Bytes => 12),
         Storage => Input_Storage'Unchecked_Access);
      Outcome : Jpeglib.Results.Result;
      Last : Natural;
   begin
      Jpeglib.Streams.Open (Destination, Encoded_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize (Encoder, Destination'Access, Options);
      Outcome := Jpeglib.Encoding.Encode_Image (Encoder, Input);

      if not Jpeglib.Results.Succeeded (Outcome) then
         raise Program_Error with
           Label
           & " advanced fixture encode failed: "
           & Jpeglib.Errors.Error_Code'Image (Outcome.First_Error.Code);
      end if;

      Last := Natural (Jpeglib.Streams.Offset (Destination));
      return Raw (Encoded_Storage (Encoded_Storage'First .. Encoded_Storage'First + Last - 1));
   end Encoded_RGB_2x2;

   function Encoded_Four_Component_2x2
     (Label : String;
      Format : Jpeglib.Images.Pixel_Format;
      Options : Jpeglib.Encoding.Options) return String
   is
      Input_Storage : aliased Jpeglib.Streams.Byte_Array :=
        [0, 32, 64, 96,
         128, 160, 192, 224,
         240, 255, 16, 48,
         80, 112, 144, 176];
      Encoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 4096 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Encoder : Jpeglib.Encoding.Encoder;
      Input : constant Jpeglib.Images.Image_View :=
        (Descriptor =>
           (Width => 2,
            Height => 2,
            Format => Format,
            Stride => 8,
            Accessible_Bytes => 16),
         Storage => Input_Storage'Unchecked_Access);
      Outcome : Jpeglib.Results.Result;
      Last : Natural;
   begin
      Jpeglib.Streams.Open (Destination, Encoded_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize (Encoder, Destination'Access, Options);
      Outcome := Jpeglib.Encoding.Encode_Image (Encoder, Input);

      if not Jpeglib.Results.Succeeded (Outcome) then
         raise Program_Error with
           Label
           & " advanced fixture encode failed: "
           & Jpeglib.Errors.Error_Code'Image (Outcome.First_Error.Code);
      end if;

      Last := Natural (Jpeglib.Streams.Offset (Destination));
      return Raw (Encoded_Storage (Encoded_Storage'First .. Encoded_Storage'First + Last - 1));
   end Encoded_Four_Component_2x2;

   function Raw_For (Id : Image_Fixture_Id) return String is
   begin
      case Id is
         when Image_Progressive_RGB_Encoded =>
            return Encoded_RGB_2x2
              ("progressive RGB",
               (Quality => 100,
                Progressive => Jpeglib.Encoding.Balanced_Progressive,
                Subsampling => Jpeglib.Encoding.Subsampling_444,
                others => <>));
         when Image_Arithmetic_Progressive_RGB_Encoded =>
            return Encoded_RGB_2x2
              ("arithmetic progressive RGB",
               (Quality => 100,
                Mode => Jpeglib.Encoding.Arithmetic_Sequential_DCT,
                Progressive => Jpeglib.Encoding.Balanced_Progressive,
                Subsampling => Jpeglib.Encoding.Subsampling_444,
                others => <>));
         when Image_Differential_DCT_RGB_Encoded =>
            return Encoded_RGB_2x2
              ("differential DCT RGB",
               (Quality => 100,
                Mode => Jpeglib.Encoding.Differential_Sequential_DCT,
                Subsampling => Jpeglib.Encoding.Subsampling_444,
                others => <>));
         when Image_Hierarchical_DCT_RGB_Encoded =>
            return Encoded_RGB_2x2
              ("hierarchical DCT RGB",
               (Quality => 100,
                Mode => Jpeglib.Encoding.Hierarchical_Sequential_DCT,
                Subsampling => Jpeglib.Encoding.Subsampling_444,
                others => <>));
         when Image_Arithmetic_Lossless_RGB_Encoded =>
            return Encoded_RGB_2x2
              ("arithmetic lossless RGB",
               (Mode => Jpeglib.Encoding.Arithmetic_Lossless,
                Lossless_Predictor => 1,
                others => <>));
         when Image_Differential_Lossless_RGB_Encoded =>
            return Encoded_RGB_2x2
              ("differential lossless RGB",
               (Mode => Jpeglib.Encoding.Differential_Lossless_Huffman,
                Lossless_Predictor => 1,
                others => <>));
         when Image_Hierarchical_Lossless_RGB_Encoded =>
            return Encoded_RGB_2x2
              ("hierarchical lossless RGB",
               (Mode => Jpeglib.Encoding.Hierarchical_Lossless_Huffman,
                Lossless_Predictor => 1,
                others => <>));
         when Image_Arithmetic_Progressive_CMYK_Encoded =>
            return Encoded_Four_Component_2x2
              ("arithmetic progressive CMYK",
               Jpeglib.Images.CMYK_32,
                (Quality => 100,
                 Mode => Jpeglib.Encoding.Arithmetic_Sequential_DCT,
                 Progressive => Jpeglib.Encoding.Balanced_Progressive,
                 others => <>));
         when Image_Arithmetic_Progressive_YCCK_Encoded =>
            return Encoded_Four_Component_2x2
              ("arithmetic progressive YCCK",
               Jpeglib.Images.YCCK_32,
                (Quality => 100,
                 Mode => Jpeglib.Encoding.Arithmetic_Sequential_DCT,
                 Progressive => Jpeglib.Encoding.Balanced_Progressive,
                 others => <>));
         when Image_Arithmetic_Lossless_CMYK_Encoded =>
            return Encoded_Four_Component_2x2
              ("arithmetic lossless CMYK",
               Jpeglib.Images.CMYK_32,
               (Mode => Jpeglib.Encoding.Arithmetic_Lossless,
                Lossless_Predictor => 1,
                others => <>));
         when Image_Arithmetic_Lossless_YCCK_Encoded =>
            return Encoded_Four_Component_2x2
              ("arithmetic lossless YCCK",
               Jpeglib.Images.YCCK_32,
               (Mode => Jpeglib.Encoding.Arithmetic_Lossless,
                Lossless_Predictor => 1,
                others => <>));
         when others =>
            return Raw (Payload_Of (Id).all);
      end case;
   end Raw_For;

   function Name_Of (Id : Fixture_Id) return String is
   begin
      case Id is
         when Baseline_Gray =>
            return "baseline-gray-16x8.jpg";
         when Baseline_Gray_Restart =>
            return "baseline-gray-16x8-restart.jpg";
         when Baseline_YCbCr =>
            return "baseline-ycbcr-17x9-420.jpg";
         when Invalid_Gray_Wrong_Restart =>
            return "invalid-gray-wrong-restart.jpg";
         when Invalid_YCbCr_Incomplete_Scans =>
            return "invalid-ycbcr-incomplete-scans.jpg";
      end case;
   end Name_Of;

   function Name_Of (Id : Image_Fixture_Id) return String is
   begin
      case Id is
         when Image_Baseline_Gray =>
            return "baseline-gray-16x8.jpg";
         when Image_Baseline_Gray_Restart =>
            return "baseline-gray-16x8-restart.jpg";
         when Image_Baseline_YCbCr =>
            return "baseline-ycbcr-17x9-420.jpg";
         when Image_Baseline_YCbCr_Restart =>
            return "baseline-ycbcr-17x9-420-restart.jpg";
         when Image_Baseline_YCbCr_Separate =>
            return "baseline-ycbcr-17x9-420-separate.jpg";
         when Image_Baseline_RGB =>
            return "baseline-rgb-8x8.jpg";
         when Image_Baseline_CMYK =>
            return "baseline-cmyk-8x8.jpg";
         when Image_Baseline_CMYK_Separate =>
            return "baseline-cmyk-8x8-separate.jpg";
         when Image_Progressive_RGB_Encoded =>
            return "encoded-progressive-rgb-2x2.jpg";
         when Image_Arithmetic_Progressive_RGB_Encoded =>
            return "encoded-arithmetic-progressive-rgb-2x2.jpg";
         when Image_Differential_DCT_RGB_Encoded =>
            return "encoded-differential-dct-rgb-2x2.jpg";
         when Image_Hierarchical_DCT_RGB_Encoded =>
            return "encoded-hierarchical-dct-rgb-2x2.jpg";
         when Image_Arithmetic_Lossless_RGB_Encoded =>
            return "encoded-arithmetic-lossless-rgb-2x2.jpg";
         when Image_Differential_Lossless_RGB_Encoded =>
            return "encoded-differential-lossless-rgb-2x2.jpg";
         when Image_Hierarchical_Lossless_RGB_Encoded =>
            return "encoded-hierarchical-lossless-rgb-2x2.jpg";
         when Image_Arithmetic_Progressive_CMYK_Encoded =>
            return "encoded-arithmetic-progressive-cmyk-2x2.jpg";
         when Image_Arithmetic_Progressive_YCCK_Encoded =>
            return "encoded-arithmetic-progressive-ycck-2x2.jpg";
         when Image_Arithmetic_Lossless_CMYK_Encoded =>
            return "encoded-arithmetic-lossless-cmyk-2x2.jpg";
         when Image_Arithmetic_Lossless_YCCK_Encoded =>
            return "encoded-arithmetic-lossless-ycck-2x2.jpg";
      end case;
   end Name_Of;

   function Project_Root return String is
   begin
      return Project_Tools.Files.Find_Root_Upward
        (Ada.Directories.Current_Directory, "jpeglib.gpr");
   end Project_Root;

   function Coefficient_Directory (Root : String) return String is
     (Project_Tools.Files.Join (Root, "tests/fixtures/coefficients"));

   function Image_Directory (Root : String) return String is
     (Project_Tools.Files.Join (Root, "tests/fixtures/images"));

   function Path_For (Root : String; Id : Fixture_Id) return String is
     (Project_Tools.Files.Join (Coefficient_Directory (Root), Name_Of (Id)));

   function Path_For (Root : String; Id : Image_Fixture_Id) return String is
     (Project_Tools.Files.Join (Image_Directory (Root), Name_Of (Id)));

   function Read_File (Path : String) return Ada.Strings.Unbounded.Unbounded_String is
     (Ada.Strings.Unbounded.To_Unbounded_String (Project_Tools.Files.Read_Raw_File (Path)));

   function Line_For (Item : Fixture) return String is
     (Name_Of (Item.Id)
      & " bytes=" & Natural'Image (Payload_Of (Item.Id)'Length)
      & " blocks=" & Jpeglib.Block_Count'Image (Item.Expected_Blocks)
      & " kind=" & Fixture_Kind'Image (Item.Kind)
      & " error=" & Jpeglib.Errors.Error_Code'Image (Item.Expected_Error)
      & ASCII.LF);

   function Line_For (Item : Image_Fixture) return String is
     (Name_Of (Item.Id)
      & " bytes=" & Natural'Image (Raw_For (Item.Id)'Length)
      & " width=" & Jpeglib.Image_Width'Image (Item.Width)
      & " height=" & Jpeglib.Image_Height'Image (Item.Height)
      & " format=" & Jpeglib.Images.Pixel_Format'Image (Item.Format)
      & " first=" & Jpeglib.Byte'Image (Item.Expected_First)
      & " last=" & Jpeglib.Byte'Image (Item.Expected_Last)
      & " sha256=" & Item.Expected_SHA256
      & ASCII.LF);

   function Manifest return String is
      use Ada.Strings.Unbounded;
      Result : Unbounded_String;
   begin
      Append (Result, "# jpeglib coefficient fixtures" & ASCII.LF);
      for Item of Coefficient_Fixtures loop
         Append (Result, Line_For (Item));
      end loop;
      return To_String (Result);
   end Manifest;

   function Image_Manifest return String is
      use Ada.Strings.Unbounded;
      Result : Unbounded_String;
   begin
      Append (Result, "# jpeglib image decode fixtures" & ASCII.LF);
      for Item of Image_Fixtures loop
         Append (Result, Line_For (Item));
      end loop;
      return To_String (Result);
   end Image_Manifest;

   procedure Generate (Root : String) is
      Coefficient_Dir : constant String := Coefficient_Directory (Root);
      Image_Dir : constant String := Image_Directory (Root);
   begin
      Ada.Directories.Create_Path (Coefficient_Dir);
      for Item of Coefficient_Fixtures loop
         Project_Tools.Files.Write_Raw_File
           (Path_For (Root, Item.Id),
            Raw (Payload_Of (Item.Id).all));
      end loop;
      Project_Tools.Files.Write_Raw_File
        (Project_Tools.Files.Join (Coefficient_Dir, "manifest.txt"),
         Manifest);

      Ada.Directories.Create_Path (Image_Dir);
      for Item of Image_Fixtures loop
         Project_Tools.Files.Write_Raw_File
           (Path_For (Root, Item.Id),
            Raw_For (Item.Id));
      end loop;
      Project_Tools.Files.Write_Raw_File
        (Project_Tools.Files.Join (Image_Dir, "manifest.txt"),
         Image_Manifest);
   end Generate;

   function Failure (Text : String) return Decode_Check is
     ((Passed => False, Message => Ada.Strings.Unbounded.To_Unbounded_String (Text)));

   function Success return Decode_Check is
     ((Passed => True, Message => Ada.Strings.Unbounded.Null_Unbounded_String));

   function Decode_File (Path : String; Item : Fixture) return Decode_Check is
      use Ada.Strings.Unbounded;
      Content : constant String := To_String (Read_File (Path));
   begin
      if Content'Length = 0 then
         return Failure ("empty or unreadable fixture: " & Path);
      end if;

      declare
         Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. Content'Length => 0];
         Source : aliased Jpeglib.Streams.Memory_Source;
         Decoder : Jpeglib.Decoding.Decoder;
         Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Item.Expected_Blocks)) :=
           [others => [others => 0]];
         Blocks_Decoded : Jpeglib.Block_Count := 0;
         Outcome : Jpeglib.Results.Result;
      begin
         for Index in Content'Range loop
            Storage (Index) := Jpeglib.Byte (Character'Pos (Content (Index)));
         end loop;

         Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
         Jpeglib.Decoding.Initialize (Decoder, Source'Access);
         Outcome := Jpeglib.Decoding.Decode_Coefficients (Decoder, Blocks, Blocks_Decoded);

         case Item.Kind is
            when Valid_Coefficients =>
               if not Jpeglib.Results.Succeeded (Outcome) then
                  return Failure ("fixture did not decode: " & Name_Of (Item.Id));
               elsif Blocks_Decoded /= Item.Expected_Blocks then
                  return Failure ("fixture block count mismatch: " & Name_Of (Item.Id));
               elsif Blocks (Blocks'First) (0) /= Item.First_DC
                 or else Blocks (Blocks'Last) (0) /= Item.Last_DC
               then
                  return Failure ("fixture DC coefficient mismatch: " & Name_Of (Item.Id));
               end if;
            when Invalid_Coefficients =>
               if Jpeglib.Results.Succeeded (Outcome) then
                  return Failure ("invalid fixture decoded: " & Name_Of (Item.Id));
               elsif Outcome.First_Error.Code /= Item.Expected_Error then
                  return Failure ("invalid fixture error mismatch: " & Name_Of (Item.Id));
               elsif Blocks_Decoded /= 0 then
                  return Failure ("invalid fixture reported decoded blocks: " & Name_Of (Item.Id));
               end if;
         end case;
      end;

      return Success;
   end Decode_File;

   function Decode_Image_File (Path : String; Item : Image_Fixture) return Decode_Check is
      use Ada.Strings.Unbounded;
      Content : constant String := To_String (Read_File (Path));
      Bytes_Per_Pixel : constant Jpeglib.Byte_Count := Jpeglib.Images.Bytes_Per_Pixel (Item.Format);
      Row_Bytes : constant Jpeglib.Byte_Count := Jpeglib.Images.Minimum_Row_Bytes (Item.Width, Item.Format);
      Output_Bytes : constant Jpeglib.Byte_Count := Row_Bytes * Jpeglib.Byte_Count (Item.Height);
   begin
      if Content'Length = 0 then
         return Failure ("empty or unreadable image fixture: " & Path);
      end if;

      declare
         Input_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. Content'Length => 0];
         Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. Natural (Output_Bytes) => 0];
         Source : aliased Jpeglib.Streams.Memory_Source;
         Decoder : Jpeglib.Decoding.Decoder;
         View : Jpeglib.Images.Mutable_Image_View :=
           (Descriptor =>
              (Width => Item.Width,
               Height => Item.Height,
               Format => Item.Format,
               Stride => Jpeglib.Row_Stride (Row_Bytes),
               Accessible_Bytes => Output_Bytes),
            Storage => Output_Storage'Unchecked_Access);
         Outcome : Jpeglib.Results.Result;
         Last_Pixel : constant Positive :=
           Output_Storage'First
           + (Natural (Item.Height) - 1) * Natural (Row_Bytes)
           + (Natural (Item.Width) - 1) * Natural (Bytes_Per_Pixel);
         Output_SHA256 : String (1 .. 64);
      begin
         for Index in Content'Range loop
            Input_Storage (Index) := Jpeglib.Byte (Character'Pos (Content (Index)));
         end loop;

         Jpeglib.Streams.Open (Source, Input_Storage'Unchecked_Access);
         Jpeglib.Decoding.Initialize
           (Decoder,
            Source'Access,
            (Output_Format => Item.Format, Alpha_Fill => Item.Alpha, others => <>));
         Outcome := Jpeglib.Decoding.Decode_Image (Decoder, View);
         if not Jpeglib.Results.Succeeded (Outcome) then
            return Failure
              ("image fixture did not decode: "
               & Name_Of (Item.Id)
               & " error="
               & Jpeglib.Errors.Error_Code'Image (Outcome.First_Error.Code)
               & " source="
               & Jpeglib.Source_Offset'Image (Outcome.First_Error.Context.Source)
               & " marker="
               & Jpeglib.Marker_Code'Image (Outcome.First_Error.Context.Marker)
               & " detail="
               & Long_Long_Integer'Image (Outcome.First_Error.Context.Detail));
         end if;

         Output_SHA256 := SHA256_Hex (Output_Storage);
         if Output_SHA256 /= Item.Expected_SHA256 then
            return Failure
              ("image fixture sha256 mismatch: "
               & Name_Of (Item.Id)
               & " expected="
               & Item.Expected_SHA256
               & " actual="
               & Output_SHA256
               & " first="
               & Jpeglib.Byte'Image (Output_Storage (Output_Storage'First))
               & " last="
               & Jpeglib.Byte'Image (Output_Storage (Last_Pixel))
               & " fourth="
               & (if Bytes_Per_Pixel = 4 then Jpeglib.Byte'Image (Output_Storage (Last_Pixel + 3)) else " n/a"));
         elsif Output_Storage (Output_Storage'First) /= Item.Expected_First then
            return Failure
              ("image fixture first pixel mismatch: "
               & Name_Of (Item.Id)
               & " expected="
               & Jpeglib.Byte'Image (Item.Expected_First)
               & " actual="
               & Jpeglib.Byte'Image (Output_Storage (Output_Storage'First)));
         elsif Output_Storage (Last_Pixel) /= Item.Expected_Last then
            return Failure
              ("image fixture last pixel mismatch: "
               & Name_Of (Item.Id)
               & " expected="
               & Jpeglib.Byte'Image (Item.Expected_Last)
               & " actual="
               & Jpeglib.Byte'Image (Output_Storage (Last_Pixel)));
         elsif Bytes_Per_Pixel = 4
           and then Output_Storage (Last_Pixel + 3) /= Item.Alpha
         then
            return Failure ("image fixture alpha mismatch: " & Name_Of (Item.Id));
         end if;
      end;

      return Success;
   end Decode_Image_File;

   function Check_Corpus (Root : String) return Decode_Check is
      Coefficient_Dir : constant String := Coefficient_Directory (Root);
      Image_Dir : constant String := Image_Directory (Root);
   begin
      if not Project_Tools.Files.Directory_Exists (Coefficient_Dir) then
         return Failure ("missing fixture directory: " & Coefficient_Dir);
      end if;

      if Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Coefficient_Dir, "manifest.txt")) /= Manifest then
         return Failure ("coefficient fixture manifest is stale");
      end if;

      for Item of Coefficient_Fixtures loop
         declare
            Path : constant String := Path_For (Root, Item.Id);
            Result : Decode_Check;
         begin
            if Project_Tools.Files.Read_Raw_File (Path) /= Raw (Payload_Of (Item.Id).all) then
               return Failure ("fixture bytes are stale: " & Name_Of (Item.Id));
            end if;

            Result := Decode_File (Path, Item);
            if not Result.Passed then
               return Result;
            end if;
         end;
      end loop;

      if not Project_Tools.Files.Directory_Exists (Image_Dir) then
         return Failure ("missing fixture directory: " & Image_Dir);
      end if;

      if Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Image_Dir, "manifest.txt")) /= Image_Manifest then
         return Failure ("image fixture manifest is stale");
      end if;

      for Item of Image_Fixtures loop
         declare
            Path : constant String := Path_For (Root, Item.Id);
            Result : Decode_Check;
         begin
            if Project_Tools.Files.Read_Raw_File (Path) /= Raw_For (Item.Id) then
               return Failure ("image fixture bytes are stale: " & Name_Of (Item.Id));
            end if;

            Result := Decode_Image_File (Path, Item);
            if not Result.Passed then
               return Result;
            end if;
         end;
      end loop;

      return Success;
   end Check_Corpus;
end Jpeglib_Testing.Fixtures;

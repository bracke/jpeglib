with AUnit.Assertions;

with Jpeglib.Coefficients;
with Jpeglib.Coefficients.Encoding;
with Jpeglib.Decoding;
with Jpeglib.Encoding;
with Jpeglib.Errors;
with Jpeglib.Images;
with Jpeglib.Internal.Markers;
with Jpeglib.Limits;
with Jpeglib.Metadata;
with Jpeglib.Results;
with Jpeglib.Streams;

package body Jpeglib_Testing.Test_Coefficient_Encoding is
   use AUnit.Assertions;
   use type Jpeglib.Byte_Count;
   use type Jpeglib.Errors.Error_Code;
   use type Jpeglib.Decoding.Decoder_State;
   use type Jpeglib.Encoding.Encoder_State;
   use type Jpeglib.Block_Count;
   use type Jpeglib.Coefficients.DCT_Block;
   use type Jpeglib.Encoded_Color_Model;
   use type Jpeglib.Frame_Mode;
   use type Jpeglib.Marker_Code;
   use type Jpeglib.Metadata.Metadata_Kind;
   use type Jpeglib.Sample_Precision;
   use type Jpeglib.Streams.Byte_Array;

   procedure Coefficient_Encode_Rejects_Width_Limit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Coefficient_Encode_Rejects_Coefficient_Bytes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Coefficient_Encode_Rejects_Invalid_Twelve_Bit_Coefficient (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Coefficient_Encode_Writes_Twelve_Bit_Grayscale (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Coefficient_Encode_Writes_Twelve_Bit_YCbCr (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Coefficient_Encode_Writes_Twelve_Bit_CMYK (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Coefficient_Encode_Writes_Twelve_Bit_YCCK (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Raw_Encode_Rejects_Out_Of_Range_Twelve_Bit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Raw_Encode_Rejects_Invalid_Twelve_Bit_View (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Raw_Encode_Rejects_Wrong_Twelve_Bit_Component_Count (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Raw_Encode_Rejects_Twelve_Bit_Coefficient_Byte_Limit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Raw_Encode_Uses_Default_Big_Endian_Twelve_Bit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Raw_Encode_Rejects_Mismatched_Twelve_Bit_Geometry (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Raw_Encode_Writes_Progressive_Twelve_Bit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Raw_Encode_Rejects_Defined_Image_Mismatch_Twelve_Bit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Raw_Encode_Writes_Twelve_Bit_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Raw_Encode_Writes_Twelve_Bit_Grayscale (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Raw_Encode_Writes_Twelve_Bit_YCbCr (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Raw_Encode_Writes_Twelve_Bit_CMYK (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Raw_Encode_Writes_Twelve_Bit_YCCK (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("coefficient encoding");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Coefficient_Encode_Rejects_Width_Limit'Access,
         "coefficient_encoding.limits.width");
      Register_Routine
        (T,
         Coefficient_Encode_Rejects_Coefficient_Bytes'Access,
         "coefficient_encoding.limits.coefficient_bytes");
      Register_Routine
        (T,
         Coefficient_Encode_Rejects_Invalid_Twelve_Bit_Coefficient'Access,
         "coefficient_encoding.twelve_bit_invalid_coefficient");
      Register_Routine
        (T,
         Coefficient_Encode_Writes_Twelve_Bit_Grayscale'Access,
         "coefficient_encoding.twelve_bit_grayscale");
      Register_Routine
        (T,
         Coefficient_Encode_Writes_Twelve_Bit_YCbCr'Access,
         "coefficient_encoding.twelve_bit_ycbcr");
      Register_Routine
        (T,
         Coefficient_Encode_Writes_Twelve_Bit_CMYK'Access,
         "coefficient_encoding.twelve_bit_cmyk");
      Register_Routine
        (T,
         Coefficient_Encode_Writes_Twelve_Bit_YCCK'Access,
         "coefficient_encoding.twelve_bit_ycck");
      Register_Routine
        (T,
         Raw_Encode_Rejects_Out_Of_Range_Twelve_Bit'Access,
         "coefficient_encoding.raw_twelve_bit_out_of_range");
      Register_Routine
        (T,
         Raw_Encode_Rejects_Invalid_Twelve_Bit_View'Access,
         "coefficient_encoding.raw_twelve_bit_invalid_view");
      Register_Routine
        (T,
         Raw_Encode_Rejects_Wrong_Twelve_Bit_Component_Count'Access,
         "coefficient_encoding.raw_twelve_bit_wrong_component_count");
      Register_Routine
        (T,
         Raw_Encode_Rejects_Twelve_Bit_Coefficient_Byte_Limit'Access,
         "coefficient_encoding.raw_twelve_bit_coefficient_byte_limit");
      Register_Routine
        (T,
         Raw_Encode_Uses_Default_Big_Endian_Twelve_Bit'Access,
         "coefficient_encoding.raw_twelve_bit_default_byte_order");
      Register_Routine
        (T,
         Raw_Encode_Rejects_Mismatched_Twelve_Bit_Geometry'Access,
         "coefficient_encoding.raw_twelve_bit_mismatched_geometry");
      Register_Routine
        (T,
         Raw_Encode_Writes_Progressive_Twelve_Bit'Access,
         "coefficient_encoding.raw_twelve_bit_progressive");
      Register_Routine
        (T,
         Raw_Encode_Rejects_Defined_Image_Mismatch_Twelve_Bit'Access,
         "coefficient_encoding.raw_twelve_bit_defined_image_mismatch");
      Register_Routine
        (T,
         Raw_Encode_Writes_Twelve_Bit_Metadata'Access,
         "coefficient_encoding.raw_twelve_bit_metadata");
      Register_Routine
        (T,
         Raw_Encode_Writes_Twelve_Bit_Grayscale'Access,
         "coefficient_encoding.raw_twelve_bit_grayscale");
      Register_Routine
        (T,
         Raw_Encode_Writes_Twelve_Bit_YCbCr'Access,
         "coefficient_encoding.raw_twelve_bit_ycbcr");
      Register_Routine
        (T,
         Raw_Encode_Writes_Twelve_Bit_CMYK'Access,
         "coefficient_encoding.raw_twelve_bit_cmyk");
      Register_Routine
        (T,
         Raw_Encode_Writes_Twelve_Bit_YCCK'Access,
         "coefficient_encoding.raw_twelve_bit_ycck");
   end Register_Tests;

   procedure Coefficient_Encode_Rejects_Width_Limit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 512 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (1 .. 1) := [others => [others => 0]];
      Limits : constant Jpeglib.Limits.Limit_Set :=
        (Max_Width => 7,
         others => <>);
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Outcome :=
        Jpeglib.Coefficients.Encoding.Encode_Grayscale_Baseline
          (Destination,
           Width => 8,
           Height => 8,
           Blocks => Blocks,
           Encode_Limits => Limits);

      Assert (not Jpeglib.Results.Succeeded (Outcome), "coefficient encode accepted width over caller limit");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Frame_Invalid_Definition,
         "coefficient encode width limit used wrong error");
   end Coefficient_Encode_Rejects_Width_Limit;

   procedure Coefficient_Encode_Rejects_Coefficient_Bytes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 512 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (1 .. 1) := [others => [others => 0]];
      Limits : constant Jpeglib.Limits.Limit_Set :=
        (Max_Coefficient_Bytes => 127,
         others => <>);
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Outcome :=
        Jpeglib.Coefficients.Encoding.Encode_Grayscale_Progressive
          (Destination,
           Width => 8,
           Height => 8,
           Blocks => Blocks,
           Encode_Limits => Limits);

      Assert (not Jpeglib.Results.Succeeded (Outcome), "coefficient encode accepted coefficient storage over limit");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Output_Limit_Exceeded,
         "coefficient encode storage limit used wrong error");
   end Coefficient_Encode_Rejects_Coefficient_Bytes;

   procedure Coefficient_Encode_Rejects_Invalid_Twelve_Bit_Coefficient (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 512 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. 1) := [others => [others => 0]];
      Outcome : Jpeglib.Results.Result;
   begin
      Blocks (1) (0) := 16#8000#;

      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Outcome :=
        Jpeglib.Coefficients.Encoding.Encode_Grayscale_Twelve_Bit
          (Destination,
           Width => 8,
           Height => 8,
           Blocks => Blocks);

      Assert (not Jpeglib.Results.Succeeded (Outcome), "12-bit coefficient encode accepted out-of-range value");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Coefficient_Invalid_Encoding,
         "12-bit coefficient invalid value used wrong error");
      Assert
        (Natural (Jpeglib.Streams.Offset (Destination)) = 0,
         "12-bit coefficient invalid value wrote partial output");
   end Coefficient_Encode_Rejects_Invalid_Twelve_Bit_Coefficient;

   procedure Coefficient_Encode_Writes_Twelve_Bit_Grayscale (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 1024 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (1 .. 1) := [others => [others => 0]];
      Decoded_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. 1) := [others => [others => 99]];
      Blocks_Decoded : Jpeglib.Block_Count := 0;
      Header : Jpeglib.Decoding.Image_Info;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Outcome :=
        Jpeglib.Coefficients.Encoding.Encode_Grayscale_Twelve_Bit
          (Destination,
           Width => 8,
           Height => 8,
           Blocks => Blocks,
           Quality => 100);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit grayscale coefficient encode failed");

      Jpeglib.Streams.Open (Source, Output_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Decode_Coefficients (Decoder, Decoded_Blocks, Blocks_Decoded);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit grayscale coefficient decode failed after encode");
      Assert (Jpeglib.Decoding.State (Decoder) = Jpeglib.Decoding.Completed,
              "12-bit grayscale coefficient decoder state mismatch");

      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Precision = 12, "12-bit grayscale coefficient precision mismatch");
      Assert (Header.Mode = Jpeglib.Extended_Sequential_DCT, "12-bit grayscale coefficient mode mismatch");
      Assert (Header.Color_Model = Jpeglib.Grayscale, "12-bit grayscale coefficient color mismatch");
      Assert (Blocks_Decoded = 1, "12-bit grayscale coefficient count mismatch");
      Assert (Decoded_Blocks (1) = Blocks (1), "12-bit grayscale coefficients drifted");
   end Coefficient_Encode_Writes_Twelve_Bit_Grayscale;

   procedure Coefficient_Encode_Writes_Twelve_Bit_YCbCr (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 2048 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (1 .. 3) := [others => [others => 0]];
      Decoded_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. 3) := [others => [others => 99]];
      Layouts : constant Jpeglib.Coefficients.Component_Block_Layout_Array (1 .. 3) :=
        [others => (Width_In_Blocks => 1, Height_In_Blocks => 1)];
      Blocks_Decoded : Jpeglib.Block_Count := 0;
      Header : Jpeglib.Decoding.Image_Info;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Outcome :=
        Jpeglib.Coefficients.Encoding.Encode_YCbCr_Twelve_Bit
          (Destination,
           Width => 8,
           Height => 8,
           Blocks => Blocks,
           Layouts => Layouts,
           Quality => 100);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit YCbCr coefficient encode failed");

      Jpeglib.Streams.Open (Source, Output_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Decode_Coefficients (Decoder, Decoded_Blocks, Blocks_Decoded);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit YCbCr coefficient decode failed after encode");
      Assert (Jpeglib.Decoding.State (Decoder) = Jpeglib.Decoding.Completed,
              "12-bit YCbCr coefficient decoder state mismatch");

      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Precision = 12, "12-bit YCbCr coefficient precision mismatch");
      Assert (Header.Mode = Jpeglib.Extended_Sequential_DCT, "12-bit YCbCr coefficient mode mismatch");
      Assert (Header.Color_Model = Jpeglib.YCbCr, "12-bit YCbCr coefficient color mismatch");
      Assert (Blocks_Decoded = 3, "12-bit YCbCr coefficient count mismatch");
      for Index in Decoded_Blocks'Range loop
         Assert (Decoded_Blocks (Index) = Blocks (Index), "12-bit YCbCr coefficients drifted");
      end loop;
   end Coefficient_Encode_Writes_Twelve_Bit_YCbCr;

   procedure Coefficient_Encode_Writes_Twelve_Bit_CMYK (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 2048 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (1 .. 4) := [others => [others => 0]];
      Decoded_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. 4) := [others => [others => 99]];
      Blocks_Decoded : Jpeglib.Block_Count := 0;
      Header : Jpeglib.Decoding.Image_Info;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Outcome :=
        Jpeglib.Coefficients.Encoding.Encode_CMYK_Twelve_Bit
          (Destination,
           Width => 8,
           Height => 8,
           Blocks => Blocks,
           Quality => 100,
           Optimize_Huffman => True);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit CMYK coefficient encode failed: " & Outcome.First_Error.Code'Image);

      Jpeglib.Streams.Open (Source, Output_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Decode_Coefficients (Decoder, Decoded_Blocks, Blocks_Decoded);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit CMYK coefficient decode failed after encode");
      Assert (Jpeglib.Decoding.State (Decoder) = Jpeglib.Decoding.Completed,
              "12-bit CMYK coefficient decoder state mismatch");

      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Precision = 12, "12-bit CMYK coefficient precision mismatch");
      Assert (Header.Mode = Jpeglib.Extended_Sequential_DCT, "12-bit CMYK coefficient mode mismatch");
      Assert (Header.Color_Model = Jpeglib.CMYK, "12-bit CMYK coefficient color mismatch");
      Assert (Blocks_Decoded = 4, "12-bit CMYK coefficient count mismatch");
      for Index in Decoded_Blocks'Range loop
         Assert (Decoded_Blocks (Index) = Blocks (Index), "12-bit CMYK coefficients drifted");
      end loop;
   end Coefficient_Encode_Writes_Twelve_Bit_CMYK;

   procedure Coefficient_Encode_Writes_Twelve_Bit_YCCK (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 2048 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (1 .. 4) := [others => [others => 0]];
      Decoded_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. 4) := [others => [others => 99]];
      Blocks_Decoded : Jpeglib.Block_Count := 0;
      Header : Jpeglib.Decoding.Image_Info;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Outcome :=
        Jpeglib.Coefficients.Encoding.Encode_YCCK_Twelve_Bit
          (Destination,
           Width => 8,
           Height => 8,
           Blocks => Blocks,
           Quality => 100,
           Optimize_Huffman => True);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit YCCK coefficient encode failed: " & Outcome.First_Error.Code'Image);

      Jpeglib.Streams.Open (Source, Output_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Decode_Coefficients (Decoder, Decoded_Blocks, Blocks_Decoded);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit YCCK coefficient decode failed after encode");
      Assert (Jpeglib.Decoding.State (Decoder) = Jpeglib.Decoding.Completed,
              "12-bit YCCK coefficient decoder state mismatch");

      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Precision = 12, "12-bit YCCK coefficient precision mismatch");
      Assert (Header.Mode = Jpeglib.Extended_Sequential_DCT, "12-bit YCCK coefficient mode mismatch");
      Assert (Header.Color_Model = Jpeglib.YCCK, "12-bit YCCK coefficient color mismatch");
      Assert (Blocks_Decoded = 4, "12-bit YCCK coefficient count mismatch");
      for Index in Decoded_Blocks'Range loop
         Assert (Decoded_Blocks (Index) = Blocks (Index), "12-bit YCCK coefficients drifted");
      end loop;
   end Coefficient_Encode_Writes_Twelve_Bit_YCCK;

   procedure Raw_Encode_Rejects_Out_Of_Range_Twelve_Bit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 512 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Encoder : Jpeglib.Encoding.Encoder;
      Input : Jpeglib.Encoding.Raw_Component_View;
      Outcome : Jpeglib.Results.Result;
   begin
      Input_Storage (Input_Storage'First) := 0;
      Input_Storage (Input_Storage'First + 1) := 16;
      Input :=
        (Width => 8,
         Height => 8,
         Stride => 16,
         Accessible_Bytes => 128,
         Storage => Input_Storage'Unchecked_Access);

      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize (Encoder, Destination'Access);
      Outcome :=
        Jpeglib.Encoding.Encode_Raw_Grayscale_Twelve_Bit
          (Encoder,
           Input,
           Byte_Order => Jpeglib.Encoding.Least_Significant_Byte_First);

      Assert (not Jpeglib.Results.Succeeded (Outcome), "12-bit raw encode accepted sample above 4095");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Coefficient_Invalid_Encoding,
         "12-bit raw out-of-range sample used wrong error");
      Assert
        (Jpeglib.Encoding.State (Encoder) = Jpeglib.Encoding.Failed,
         "12-bit raw out-of-range sample did not fail encoder");
      Assert
        (Natural (Jpeglib.Streams.Offset (Destination)) = 0,
         "12-bit raw out-of-range sample wrote partial output");
   end Raw_Encode_Rejects_Out_Of_Range_Twelve_Bit;

   procedure Raw_Encode_Rejects_Invalid_Twelve_Bit_View (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 512 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Encoder : Jpeglib.Encoding.Encoder;
      Input : Jpeglib.Encoding.Raw_Component_View;
      Outcome : Jpeglib.Results.Result;
   begin
      for Index in Input_Storage'Range loop
         Input_Storage (Index) := (if Index mod 2 = 1 then 8 else 0);
      end loop;

      Input :=
        (Width => 8,
         Height => 8,
         Stride => 15,
         Accessible_Bytes => 128,
         Storage => Input_Storage'Unchecked_Access);

      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize (Encoder, Destination'Access);
      Outcome := Jpeglib.Encoding.Encode_Raw_Grayscale_Twelve_Bit (Encoder, Input);

      Assert (not Jpeglib.Results.Succeeded (Outcome), "12-bit raw encode accepted short packed stride");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Frame_Invalid_Definition,
         "12-bit raw invalid view used wrong error");
      Assert
        (Jpeglib.Encoding.State (Encoder) = Jpeglib.Encoding.Failed,
         "12-bit raw invalid view did not fail encoder");
      Assert
        (Natural (Jpeglib.Streams.Offset (Destination)) = 0,
         "12-bit raw invalid view wrote partial output");
   end Raw_Encode_Rejects_Invalid_Twelve_Bit_View;

   procedure Raw_Encode_Rejects_Wrong_Twelve_Bit_Component_Count (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Y_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Cb_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 512 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Encoder : Jpeglib.Encoding.Encoder;
      Input : Jpeglib.Encoding.Raw_Component_View_Array (1 .. 2);
      Outcome : Jpeglib.Results.Result;
   begin
      Input :=
        [1 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Y_Storage'Unchecked_Access),
         2 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Cb_Storage'Unchecked_Access)];

      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize (Encoder, Destination'Access);
      Outcome := Jpeglib.Encoding.Encode_Raw_YCbCr_Twelve_Bit (Encoder, Input);

      Assert (not Jpeglib.Results.Succeeded (Outcome), "12-bit raw encode accepted wrong component count");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Frame_Invalid_Definition,
         "12-bit raw wrong component count used wrong error");
      Assert
        (Jpeglib.Encoding.State (Encoder) = Jpeglib.Encoding.Failed,
         "12-bit raw wrong component count did not fail encoder");
      Assert
        (Natural (Jpeglib.Streams.Offset (Destination)) = 0,
         "12-bit raw wrong component count wrote partial output");
   end Raw_Encode_Rejects_Wrong_Twelve_Bit_Component_Count;

   procedure Raw_Encode_Rejects_Twelve_Bit_Coefficient_Byte_Limit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 512 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Encoder : Jpeglib.Encoding.Encoder;
      Input : Jpeglib.Encoding.Raw_Component_View;
      Limits : constant Jpeglib.Limits.Limit_Set :=
        (Max_Coefficient_Bytes => 127,
         others => <>);
      Outcome : Jpeglib.Results.Result;
   begin
      Input :=
        (Width => 8,
         Height => 8,
         Stride => 16,
         Accessible_Bytes => 128,
         Storage => Input_Storage'Unchecked_Access);

      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize (Encoder, Destination'Access, Encode_Limits => Limits);
      Outcome := Jpeglib.Encoding.Encode_Raw_Grayscale_Twelve_Bit (Encoder, Input);

      Assert (not Jpeglib.Results.Succeeded (Outcome), "12-bit raw encode ignored coefficient byte limit");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Output_Limit_Exceeded,
         "12-bit raw coefficient byte limit used wrong error");
      Assert
        (Jpeglib.Encoding.State (Encoder) = Jpeglib.Encoding.Failed,
         "12-bit raw coefficient byte limit did not fail encoder");
      Assert
        (Natural (Jpeglib.Streams.Offset (Destination)) = 0,
         "12-bit raw coefficient byte limit wrote partial output");
   end Raw_Encode_Rejects_Twelve_Bit_Coefficient_Byte_Limit;

   procedure Raw_Encode_Uses_Default_Big_Endian_Twelve_Bit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 2048 => 0];
      Raw_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Encoder : Jpeglib.Encoding.Encoder;
      Decoder : Jpeglib.Decoding.Decoder;
      Input : Jpeglib.Encoding.Raw_Component_View;
      Raw_Output : Jpeglib.Decoding.Raw_Component_View_Array (1 .. 1);
      Header : Jpeglib.Decoding.Image_Info;
      Outcome : Jpeglib.Results.Result;
   begin
      for Index in Input_Storage'Range loop
         Input_Storage (Index) := (if Index mod 2 = 1 then 8 else 0);
      end loop;

      Input :=
        (Width => 8,
         Height => 8,
         Stride => 16,
         Accessible_Bytes => 128,
         Storage => Input_Storage'Unchecked_Access);

      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize
        (Encoder,
         Destination'Access,
         (Quality => 100,
          Optimize_Huffman => True,
          others => <>));
      Outcome := Jpeglib.Encoding.Encode_Raw_Grayscale_Twelve_Bit (Encoder, Input);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit raw default-byte-order encode failed: " & Outcome.First_Error.Code'Image);

      Raw_Output (1) :=
        (Width => 8,
         Height => 8,
         Stride => 16,
         Accessible_Bytes => 128,
         Storage => Raw_Output_Storage'Unchecked_Access);
      Jpeglib.Streams.Open (Source, Output_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         (Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision, others => <>));
      Outcome := Jpeglib.Decoding.Decode_Raw_Components (Decoder, Raw_Output);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit raw default-byte-order decode failed after encode: " & Outcome.First_Error.Code'Image);

      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Precision = 12, "12-bit raw default-byte-order precision mismatch");
      Assert (Header.Color_Model = Jpeglib.Grayscale, "12-bit raw default-byte-order color mismatch");
      Assert
        (Jpeglib.Decoding.Raw_Sample_At
           (Raw_Output (1),
            0,
            0,
            (Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision, others => <>),
            12) = 2048,
         "12-bit raw default-byte-order sample mismatch");
   end Raw_Encode_Uses_Default_Big_Endian_Twelve_Bit;

   procedure Raw_Encode_Rejects_Mismatched_Twelve_Bit_Geometry (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Y_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Cb_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Cr_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 512 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Encoder : Jpeglib.Encoding.Encoder;
      Input : Jpeglib.Encoding.Raw_Component_View_Array (1 .. 3);
      Outcome : Jpeglib.Results.Result;
   begin
      Input :=
        [1 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Y_Storage'Unchecked_Access),
         2 =>
           (Width => 7,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Cb_Storage'Unchecked_Access),
         3 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Cr_Storage'Unchecked_Access)];

      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize (Encoder, Destination'Access);
      Outcome := Jpeglib.Encoding.Encode_Raw_YCbCr_Twelve_Bit (Encoder, Input);

      Assert (not Jpeglib.Results.Succeeded (Outcome), "12-bit raw encode accepted mismatched component geometry");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Frame_Invalid_Definition,
         "12-bit raw mismatched component geometry used wrong error");
      Assert
        (Jpeglib.Encoding.State (Encoder) = Jpeglib.Encoding.Failed,
         "12-bit raw mismatched component geometry did not fail encoder");
      Assert
        (Natural (Jpeglib.Streams.Offset (Destination)) = 0,
         "12-bit raw mismatched component geometry wrote partial output");
   end Raw_Encode_Rejects_Mismatched_Twelve_Bit_Geometry;

   procedure Raw_Encode_Writes_Progressive_Twelve_Bit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Decode_Options : constant Jpeglib.Decoding.Options :=
        (Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision,
         Raw_Byte_Order => Jpeglib.Decoding.Least_Significant_Byte_First,
         others => <>);

      procedure Fill_Twelve_Bit (Storage : in out Jpeglib.Streams.Byte_Array) is
      begin
         for Index in Storage'Range loop
            Storage (Index) := (if Index mod 2 = 0 then 8 else 0);
         end loop;
      end Fill_Twelve_Bit;

      procedure Assert_Raw_Plane
        (View : Jpeglib.Decoding.Raw_Component_View;
         Label : String)
      is
      begin
         Assert
           (Jpeglib.Decoding.Raw_Sample_At (View, 0, 0, Decode_Options, 12) = 2048,
            Label & " progressive 12-bit raw sample mismatch");
      end Assert_Raw_Plane;

      procedure Decode_And_Check
        (Storage : not null Jpeglib.Streams.Const_Byte_Array_Access;
         Raw_Output : in out Jpeglib.Decoding.Raw_Component_View_Array;
         Expected_Model : Jpeglib.Encoded_Color_Model;
         Label : String)
      is
         Source : aliased Jpeglib.Streams.Memory_Source;
         Decoder : Jpeglib.Decoding.Decoder;
         Header : Jpeglib.Decoding.Image_Info;
         Outcome : Jpeglib.Results.Result;
      begin
         Jpeglib.Streams.Open (Source, Storage);
         Jpeglib.Decoding.Initialize (Decoder, Source'Access, Decode_Options);
         Outcome := Jpeglib.Decoding.Decode_Raw_Components (Decoder, Raw_Output);
         Assert
           (Jpeglib.Results.Succeeded (Outcome),
            Label & " progressive 12-bit raw decode failed after encode: " & Outcome.First_Error.Code'Image);
         Header := Jpeglib.Decoding.Header (Decoder);
         Assert (Header.Precision = 12, Label & " progressive 12-bit raw precision mismatch");
         Assert (Header.Mode = Jpeglib.Progressive_DCT, Label & " progressive 12-bit raw mode mismatch");
         Assert (Header.Color_Model = Expected_Model, Label & " progressive 12-bit raw color mismatch");
         for Component in Raw_Output'Range loop
            Assert_Raw_Plane (Raw_Output (Component), Label);
         end loop;
      end Decode_And_Check;

      procedure Encodes_Grayscale is
         Input_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
         Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 4096 => 0];
         Raw_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
         Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
         Encoder : Jpeglib.Encoding.Encoder;
         Input : Jpeglib.Encoding.Raw_Component_View;
         Raw_Output : Jpeglib.Decoding.Raw_Component_View_Array (1 .. 1);
         Outcome : Jpeglib.Results.Result;
      begin
         Fill_Twelve_Bit (Input_Storage);
         Input :=
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Input_Storage'Unchecked_Access);
         Raw_Output (1) :=
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Raw_Output_Storage'Unchecked_Access);

         Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
         Jpeglib.Encoding.Initialize
           (Encoder,
            Destination'Access,
            (Quality => 100,
             Progressive => Jpeglib.Encoding.Fast_Preview_Progressive,
             Optimize_Huffman => True,
             others => <>));
         Outcome :=
           Jpeglib.Encoding.Encode_Raw_Grayscale_Twelve_Bit
             (Encoder, Input, Byte_Order => Jpeglib.Encoding.Least_Significant_Byte_First);
         Assert
           (Jpeglib.Results.Succeeded (Outcome),
            "progressive 12-bit raw grayscale encode failed: " & Outcome.First_Error.Code'Image);
         Assert
           (Jpeglib.Encoding.State (Encoder) = Jpeglib.Encoding.Completed,
            "progressive 12-bit raw grayscale encoder state mismatch");
         Decode_And_Check
           (Output_Storage'Unchecked_Access, Raw_Output, Jpeglib.Grayscale, "grayscale");
      end Encodes_Grayscale;

      procedure Encodes_Three_Component is
         Y_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
         Cb_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
         Cr_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
         Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 8192 => 0];
         Raw_Y_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
         Raw_Cb_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
         Raw_Cr_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
         Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
         Encoder : Jpeglib.Encoding.Encoder;
         Input : Jpeglib.Encoding.Raw_Component_View_Array (1 .. 3);
         Raw_Output : Jpeglib.Decoding.Raw_Component_View_Array (1 .. 3);
         Outcome : Jpeglib.Results.Result;
      begin
         Fill_Twelve_Bit (Y_Storage);
         Fill_Twelve_Bit (Cb_Storage);
         Fill_Twelve_Bit (Cr_Storage);
         Input :=
           [1 =>
              (Width => 8, Height => 8, Stride => 16, Accessible_Bytes => 128,
               Storage => Y_Storage'Unchecked_Access),
            2 =>
              (Width => 8, Height => 8, Stride => 16, Accessible_Bytes => 128,
               Storage => Cb_Storage'Unchecked_Access),
            3 =>
              (Width => 8, Height => 8, Stride => 16, Accessible_Bytes => 128,
               Storage => Cr_Storage'Unchecked_Access)];
         Raw_Output :=
           [1 =>
              (Width => 8, Height => 8, Stride => 16, Accessible_Bytes => 128,
               Storage => Raw_Y_Output_Storage'Unchecked_Access),
            2 =>
              (Width => 8, Height => 8, Stride => 16, Accessible_Bytes => 128,
               Storage => Raw_Cb_Output_Storage'Unchecked_Access),
            3 =>
              (Width => 8, Height => 8, Stride => 16, Accessible_Bytes => 128,
               Storage => Raw_Cr_Output_Storage'Unchecked_Access)];

         Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
         Jpeglib.Encoding.Initialize
           (Encoder,
            Destination'Access,
            (Quality => 100,
             Progressive => Jpeglib.Encoding.Balanced_Progressive,
             Optimize_Huffman => True,
             others => <>));
         Outcome :=
           Jpeglib.Encoding.Encode_Raw_YCbCr_Twelve_Bit
             (Encoder, Input, Byte_Order => Jpeglib.Encoding.Least_Significant_Byte_First);
         Assert
           (Jpeglib.Results.Succeeded (Outcome),
            "progressive 12-bit raw YCbCr encode failed: " & Outcome.First_Error.Code'Image);
         Decode_And_Check (Output_Storage'Unchecked_Access, Raw_Output, Jpeglib.YCbCr, "YCbCr");
      end Encodes_Three_Component;

      procedure Encodes_Four_Component (YCCK : Boolean) is
         C1_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
         C2_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
         C3_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
         C4_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
         Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 8192 => 0];
         Raw_C1_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
         Raw_C2_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
         Raw_C3_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
         Raw_C4_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
         Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
         Encoder : Jpeglib.Encoding.Encoder;
         Input : Jpeglib.Encoding.Raw_Component_View_Array (1 .. 4);
         Raw_Output : Jpeglib.Decoding.Raw_Component_View_Array (1 .. 4);
         Outcome : Jpeglib.Results.Result;
         Label : constant String := (if YCCK then "YCCK" else "CMYK");
      begin
         Fill_Twelve_Bit (C1_Storage);
         Fill_Twelve_Bit (C2_Storage);
         Fill_Twelve_Bit (C3_Storage);
         Fill_Twelve_Bit (C4_Storage);
         Input :=
           [1 =>
              (Width => 8, Height => 8, Stride => 16, Accessible_Bytes => 128,
               Storage => C1_Storage'Unchecked_Access),
            2 =>
              (Width => 8, Height => 8, Stride => 16, Accessible_Bytes => 128,
               Storage => C2_Storage'Unchecked_Access),
            3 =>
              (Width => 8, Height => 8, Stride => 16, Accessible_Bytes => 128,
               Storage => C3_Storage'Unchecked_Access),
            4 =>
              (Width => 8, Height => 8, Stride => 16, Accessible_Bytes => 128,
               Storage => C4_Storage'Unchecked_Access)];
         Raw_Output :=
           [1 =>
              (Width => 8, Height => 8, Stride => 16, Accessible_Bytes => 128,
               Storage => Raw_C1_Output_Storage'Unchecked_Access),
            2 =>
              (Width => 8, Height => 8, Stride => 16, Accessible_Bytes => 128,
               Storage => Raw_C2_Output_Storage'Unchecked_Access),
            3 =>
              (Width => 8, Height => 8, Stride => 16, Accessible_Bytes => 128,
               Storage => Raw_C3_Output_Storage'Unchecked_Access),
            4 =>
              (Width => 8, Height => 8, Stride => 16, Accessible_Bytes => 128,
               Storage => Raw_C4_Output_Storage'Unchecked_Access)];

         Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
         Jpeglib.Encoding.Initialize
           (Encoder,
            Destination'Access,
            (Quality => 100,
             Progressive => Jpeglib.Encoding.Balanced_Progressive,
             Optimize_Huffman => True,
             others => <>));
         if YCCK then
            Outcome :=
              Jpeglib.Encoding.Encode_Raw_YCCK_Twelve_Bit
                (Encoder, Input, Byte_Order => Jpeglib.Encoding.Least_Significant_Byte_First);
         else
            Outcome :=
              Jpeglib.Encoding.Encode_Raw_CMYK_Twelve_Bit
                (Encoder, Input, Byte_Order => Jpeglib.Encoding.Least_Significant_Byte_First);
         end if;
         Assert
           (Jpeglib.Results.Succeeded (Outcome),
            "progressive 12-bit raw " & Label & " encode failed: " & Outcome.First_Error.Code'Image);
         Decode_And_Check
           (Output_Storage'Unchecked_Access,
            Raw_Output,
            (if YCCK then Jpeglib.YCCK else Jpeglib.CMYK),
            Label);
      end Encodes_Four_Component;
   begin
      Encodes_Grayscale;
      Encodes_Three_Component;
      Encodes_Four_Component (YCCK => False);
      Encodes_Four_Component (YCCK => True);
   end Raw_Encode_Writes_Progressive_Twelve_Bit;

   procedure Raw_Encode_Rejects_Defined_Image_Mismatch_Twelve_Bit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 512 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Encoder : Jpeglib.Encoding.Encoder;
      Input : Jpeglib.Encoding.Raw_Component_View;
      Descriptor : constant Jpeglib.Images.Image_Descriptor :=
        (Width => 8,
         Height => 8,
         Format => Jpeglib.Images.RGB_24,
         Stride => 24,
         Accessible_Bytes => 192);
      Outcome : Jpeglib.Results.Result;
   begin
      Input :=
        (Width => 8,
         Height => 8,
         Stride => 16,
         Accessible_Bytes => 128,
         Storage => Input_Storage'Unchecked_Access);

      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize (Encoder, Destination'Access);
      Outcome := Jpeglib.Encoding.Define_Image (Encoder, Descriptor);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit raw mismatch setup failed to define image");

      Outcome := Jpeglib.Encoding.Encode_Raw_Grayscale_Twelve_Bit (Encoder, Input);

      Assert (not Jpeglib.Results.Succeeded (Outcome), "12-bit raw encode accepted mismatched defined image");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Frame_Invalid_Definition,
         "12-bit raw defined-image mismatch used wrong error");
      Assert
        (Jpeglib.Encoding.State (Encoder) = Jpeglib.Encoding.Failed,
         "12-bit raw defined-image mismatch did not fail encoder");
      Assert
        (Natural (Jpeglib.Streams.Offset (Destination)) = 0,
         "12-bit raw defined-image mismatch wrote partial output");
   end Raw_Encode_Rejects_Defined_Image_Mismatch_Twelve_Bit;

   procedure Raw_Encode_Writes_Twelve_Bit_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Payload : aliased constant Jpeglib.Streams.Byte_Array := [16#52#, 16#41#, 16#57#, 16#31#, 16#32#];
      Encoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 2048 => 0];
      Retained_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 16 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Encoder : Jpeglib.Encoding.Encoder;
      Decoder : Jpeglib.Decoding.Decoder;
      Input : Jpeglib.Encoding.Raw_Component_View;
      Header : Jpeglib.Decoding.Image_Info;
      Outcome : Jpeglib.Results.Result;
   begin
      for Index in Input_Storage'Range loop
         Input_Storage (Index) := (if Index mod 2 = 1 then 8 else 0);
      end loop;

      Input :=
        (Width => 8,
         Height => 8,
         Stride => 16,
         Accessible_Bytes => 128,
         Storage => Input_Storage'Unchecked_Access);

      Jpeglib.Streams.Open (Destination, Encoded_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize
        (Encoder,
         Destination'Access,
         (Quality => 100,
          Optimize_Huffman => True,
          others => <>));
      Outcome :=
        Jpeglib.Encoding.Add_Metadata_Segment
          (Encoder,
           Jpeglib.Internal.Markers.COM,
           Payload'Unchecked_Access);
      Assert (Jpeglib.Results.Succeeded (Outcome), "12-bit raw metadata segment was rejected");

      Outcome := Jpeglib.Encoding.Encode_Raw_Grayscale_Twelve_Bit (Encoder, Input);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit raw metadata encode failed: " & Outcome.First_Error.Code'Image);

      Jpeglib.Streams.Open (Source, Encoded_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         (Metadata => Jpeglib.Metadata.Preserve_Selected,
          Selected_Metadata => [Jpeglib.Metadata.Comment => True, others => False],
          Metadata_Buffer => Retained_Storage'Unchecked_Access,
          others => <>));
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit raw metadata header read failed: " & Outcome.First_Error.Code'Image);

      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Precision = 12, "12-bit raw metadata precision mismatch");
      Assert (Header.Color_Model = Jpeglib.Grayscale, "12-bit raw metadata color mismatch");
      Assert (Header.Metadata_Segments = 2, "12-bit raw metadata segment count mismatch");
      Assert (Header.Retained_Metadata_Summaries = 1, "12-bit raw metadata retained summary count mismatch");
      Assert
        (Header.Metadata_Summaries (1).Marker = Jpeglib.Internal.Markers.COM,
         "12-bit raw metadata marker mismatch");
      Assert
        (Header.Metadata_Summaries (1).Kind = Jpeglib.Metadata.Comment,
         "12-bit raw metadata kind mismatch");
      Assert
        (Header.Metadata_Summaries (1).Retained_Length = Payload'Length,
         "12-bit raw metadata retained length mismatch");
      Assert (Retained_Storage (1 .. Payload'Length) = Payload, "12-bit raw metadata payload mismatch");
   end Raw_Encode_Writes_Twelve_Bit_Metadata;

   procedure Raw_Encode_Writes_Twelve_Bit_Grayscale (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Input_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 2048 => 0];
      Raw_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Encoder : Jpeglib.Encoding.Encoder;
      Decoder : Jpeglib.Decoding.Decoder;
      Input : Jpeglib.Encoding.Raw_Component_View;
      Raw_Output : Jpeglib.Decoding.Raw_Component_View_Array (1 .. 1);
      Header : Jpeglib.Decoding.Image_Info;
      Outcome : Jpeglib.Results.Result;
   begin
      for Index in Input_Storage'Range loop
         Input_Storage (Index) := (if Index mod 2 = 0 then 8 else 0);
      end loop;

      Input :=
        (Width => 8,
         Height => 8,
         Stride => 16,
         Accessible_Bytes => 128,
         Storage => Input_Storage'Unchecked_Access);

      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize
        (Encoder,
         Destination'Access,
         (Quality => 100,
          Optimize_Huffman => True,
          others => <>));
      Outcome :=
        Jpeglib.Encoding.Encode_Raw_Grayscale_Twelve_Bit
          (Encoder,
           Input,
           Byte_Order => Jpeglib.Encoding.Least_Significant_Byte_First);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit raw grayscale encode failed: " & Outcome.First_Error.Code'Image);
      Assert
        (Jpeglib.Encoding.State (Encoder) = Jpeglib.Encoding.Completed,
         "12-bit raw grayscale encoder state mismatch");

      Raw_Output (1) :=
        (Width => 8,
         Height => 8,
         Stride => 16,
         Accessible_Bytes => 128,
         Storage => Raw_Output_Storage'Unchecked_Access);
      Jpeglib.Streams.Open (Source, Output_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         (Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision,
          Raw_Byte_Order => Jpeglib.Decoding.Least_Significant_Byte_First,
          others => <>));
      Outcome := Jpeglib.Decoding.Decode_Raw_Components (Decoder, Raw_Output);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit raw grayscale decode failed after encode: " & Outcome.First_Error.Code'Image);

      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Precision = 12, "12-bit raw grayscale precision mismatch");
      Assert (Header.Mode = Jpeglib.Extended_Sequential_DCT, "12-bit raw grayscale mode mismatch");
      Assert (Header.Color_Model = Jpeglib.Grayscale, "12-bit raw grayscale color mismatch");
      Assert
        (Jpeglib.Decoding.Raw_Sample_At
           (Raw_Output (1),
            0,
            0,
            (Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision,
             Raw_Byte_Order => Jpeglib.Decoding.Least_Significant_Byte_First,
             others => <>),
            12) = 2048,
         "12-bit raw grayscale sample mismatch");
   end Raw_Encode_Writes_Twelve_Bit_Grayscale;

   procedure Raw_Encode_Writes_Twelve_Bit_YCbCr (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Y_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Cb_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Cr_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 4096 => 0];
      Raw_Y_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Raw_Cb_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Raw_Cr_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Encoder : Jpeglib.Encoding.Encoder;
      Decoder : Jpeglib.Decoding.Decoder;
      Input : Jpeglib.Encoding.Raw_Component_View_Array (1 .. 3);
      Raw_Output : Jpeglib.Decoding.Raw_Component_View_Array (1 .. 3);
      Header : Jpeglib.Decoding.Image_Info;
      Outcome : Jpeglib.Results.Result;

      Decode_Options : constant Jpeglib.Decoding.Options :=
        (Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision,
         Raw_Byte_Order => Jpeglib.Decoding.Least_Significant_Byte_First,
         others => <>);
   begin
      for Index in Y_Storage'Range loop
         Y_Storage (Index) := (if Index mod 2 = 0 then 8 else 0);
         Cb_Storage (Index) := (if Index mod 2 = 0 then 8 else 0);
         Cr_Storage (Index) := (if Index mod 2 = 0 then 8 else 0);
      end loop;

      Input :=
        [1 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Y_Storage'Unchecked_Access),
         2 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Cb_Storage'Unchecked_Access),
         3 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Cr_Storage'Unchecked_Access)];

      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize
        (Encoder,
         Destination'Access,
         (Quality => 100,
          Optimize_Huffman => True,
          others => <>));
      Outcome :=
        Jpeglib.Encoding.Encode_Raw_YCbCr_Twelve_Bit
          (Encoder,
           Input,
           Byte_Order => Jpeglib.Encoding.Least_Significant_Byte_First);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit raw YCbCr encode failed: " & Outcome.First_Error.Code'Image);
      Assert
        (Jpeglib.Encoding.State (Encoder) = Jpeglib.Encoding.Completed,
         "12-bit raw YCbCr encoder state mismatch");

      Raw_Output :=
        [1 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Raw_Y_Output_Storage'Unchecked_Access),
         2 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Raw_Cb_Output_Storage'Unchecked_Access),
         3 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Raw_Cr_Output_Storage'Unchecked_Access)];
      Jpeglib.Streams.Open (Source, Output_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access, Decode_Options);
      Outcome := Jpeglib.Decoding.Decode_Raw_Components (Decoder, Raw_Output);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit raw YCbCr decode failed after encode: " & Outcome.First_Error.Code'Image);

      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Precision = 12, "12-bit raw YCbCr precision mismatch");
      Assert (Header.Mode = Jpeglib.Extended_Sequential_DCT, "12-bit raw YCbCr mode mismatch");
      Assert (Header.Color_Model = Jpeglib.YCbCr, "12-bit raw YCbCr color mismatch");
      for Component in Raw_Output'Range loop
         Assert
           (Jpeglib.Decoding.Raw_Sample_At (Raw_Output (Component), 0, 0, Decode_Options, 12) = 2048,
            "12-bit raw YCbCr sample mismatch");
      end loop;
   end Raw_Encode_Writes_Twelve_Bit_YCbCr;

   procedure Raw_Encode_Writes_Twelve_Bit_CMYK (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      C_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      M_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Y_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      K_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 4096 => 0];
      Raw_C_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Raw_M_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Raw_Y_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Raw_K_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Encoder : Jpeglib.Encoding.Encoder;
      Decoder : Jpeglib.Decoding.Decoder;
      Input : Jpeglib.Encoding.Raw_Component_View_Array (1 .. 4);
      Raw_Output : Jpeglib.Decoding.Raw_Component_View_Array (1 .. 4);
      Header : Jpeglib.Decoding.Image_Info;
      Outcome : Jpeglib.Results.Result;

      Decode_Options : constant Jpeglib.Decoding.Options :=
        (Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision,
         Raw_Byte_Order => Jpeglib.Decoding.Least_Significant_Byte_First,
         others => <>);
   begin
      for Index in C_Storage'Range loop
         C_Storage (Index) := (if Index mod 2 = 0 then 8 else 0);
         M_Storage (Index) := (if Index mod 2 = 0 then 8 else 0);
         Y_Storage (Index) := (if Index mod 2 = 0 then 8 else 0);
         K_Storage (Index) := (if Index mod 2 = 0 then 8 else 0);
      end loop;

      Input :=
        [1 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => C_Storage'Unchecked_Access),
         2 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => M_Storage'Unchecked_Access),
         3 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Y_Storage'Unchecked_Access),
         4 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => K_Storage'Unchecked_Access)];

      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize
        (Encoder,
         Destination'Access,
         (Quality => 100,
          Optimize_Huffman => True,
          others => <>));
      Outcome :=
        Jpeglib.Encoding.Encode_Raw_CMYK_Twelve_Bit
          (Encoder,
           Input,
           Byte_Order => Jpeglib.Encoding.Least_Significant_Byte_First);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit raw CMYK encode failed: " & Outcome.First_Error.Code'Image);
      Assert
        (Jpeglib.Encoding.State (Encoder) = Jpeglib.Encoding.Completed,
         "12-bit raw CMYK encoder state mismatch");

      Raw_Output :=
        [1 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Raw_C_Output_Storage'Unchecked_Access),
         2 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Raw_M_Output_Storage'Unchecked_Access),
         3 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Raw_Y_Output_Storage'Unchecked_Access),
         4 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Raw_K_Output_Storage'Unchecked_Access)];
      Jpeglib.Streams.Open (Source, Output_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access, Decode_Options);
      Outcome := Jpeglib.Decoding.Decode_Raw_Components (Decoder, Raw_Output);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit raw CMYK decode failed after encode: " & Outcome.First_Error.Code'Image);

      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Precision = 12, "12-bit raw CMYK precision mismatch");
      Assert (Header.Mode = Jpeglib.Extended_Sequential_DCT, "12-bit raw CMYK mode mismatch");
      Assert (Header.Color_Model = Jpeglib.CMYK, "12-bit raw CMYK color mismatch");
      for Component in Raw_Output'Range loop
         Assert
           (Jpeglib.Decoding.Raw_Sample_At (Raw_Output (Component), 0, 0, Decode_Options, 12) = 2048,
            "12-bit raw CMYK sample mismatch");
      end loop;
   end Raw_Encode_Writes_Twelve_Bit_CMYK;

   procedure Raw_Encode_Writes_Twelve_Bit_YCCK (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Y_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Cb_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Cr_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      K_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 4096 => 0];
      Raw_Y_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Raw_Cb_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Raw_Cr_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Raw_K_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
      Image_Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 8 * 8 * 4 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Image_Source : aliased Jpeglib.Streams.Memory_Source;
      Encoder : Jpeglib.Encoding.Encoder;
      Decoder : Jpeglib.Decoding.Decoder;
      Image_Decoder : Jpeglib.Decoding.Decoder;
      Input : Jpeglib.Encoding.Raw_Component_View_Array (1 .. 4);
      Raw_Output : Jpeglib.Decoding.Raw_Component_View_Array (1 .. 4);
      Image_Output : Jpeglib.Images.Mutable_Image_View :=
        (Descriptor =>
           (Width => 8,
            Height => 8,
            Format => Jpeglib.Images.RGBA_32,
            Stride => Jpeglib.Row_Stride (8 * 4),
            Accessible_Bytes => Jpeglib.Byte_Count (8 * 8 * 4)),
         Storage => Image_Output_Storage'Unchecked_Access);
      Header : Jpeglib.Decoding.Image_Info;
      Outcome : Jpeglib.Results.Result;

      Decode_Options : constant Jpeglib.Decoding.Options :=
        (Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision,
         Raw_Byte_Order => Jpeglib.Decoding.Least_Significant_Byte_First,
         others => <>);
   begin
      for Index in Y_Storage'Range loop
         Y_Storage (Index) := (if Index mod 2 = 0 then 8 else 0);
         Cb_Storage (Index) := (if Index mod 2 = 0 then 8 else 0);
         Cr_Storage (Index) := (if Index mod 2 = 0 then 8 else 0);
         K_Storage (Index) := (if Index mod 2 = 0 then 8 else 0);
      end loop;

      Input :=
        [1 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Y_Storage'Unchecked_Access),
         2 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Cb_Storage'Unchecked_Access),
         3 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Cr_Storage'Unchecked_Access),
         4 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => K_Storage'Unchecked_Access)];

      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize
        (Encoder,
         Destination'Access,
         (Quality => 100,
          Optimize_Huffman => True,
          others => <>));
      Outcome :=
        Jpeglib.Encoding.Encode_Raw_YCCK_Twelve_Bit
          (Encoder,
           Input,
           Byte_Order => Jpeglib.Encoding.Least_Significant_Byte_First);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit raw YCCK encode failed: " & Outcome.First_Error.Code'Image);
      Assert
        (Jpeglib.Encoding.State (Encoder) = Jpeglib.Encoding.Completed,
         "12-bit raw YCCK encoder state mismatch");

      Raw_Output :=
        [1 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Raw_Y_Output_Storage'Unchecked_Access),
         2 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Raw_Cb_Output_Storage'Unchecked_Access),
         3 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Raw_Cr_Output_Storage'Unchecked_Access),
         4 =>
           (Width => 8,
            Height => 8,
            Stride => 16,
            Accessible_Bytes => 128,
            Storage => Raw_K_Output_Storage'Unchecked_Access)];
      Jpeglib.Streams.Open (Source, Output_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access, Decode_Options);
      Outcome := Jpeglib.Decoding.Decode_Raw_Components (Decoder, Raw_Output);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit raw YCCK decode failed after encode: " & Outcome.First_Error.Code'Image);

      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Precision = 12, "12-bit raw YCCK precision mismatch");
      Assert (Header.Mode = Jpeglib.Extended_Sequential_DCT, "12-bit raw YCCK mode mismatch");
      Assert (Header.Color_Model = Jpeglib.YCCK, "12-bit raw YCCK color mismatch");
      for Component in Raw_Output'Range loop
         Assert
           (Jpeglib.Decoding.Raw_Sample_At (Raw_Output (Component), 0, 0, Decode_Options, 12) = 2048,
            "12-bit raw YCCK sample mismatch");
      end loop;

      Jpeglib.Streams.Open (Image_Source, Output_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize
        (Image_Decoder,
         Image_Source'Access,
         (Output_Format => Jpeglib.Images.RGBA_32, Alpha_Fill => 123, others => <>));
      Outcome := Jpeglib.Decoding.Decode_Image (Image_Decoder, Image_Output);
      Assert
        (Jpeglib.Results.Succeeded (Outcome),
         "12-bit raw YCCK image decode failed after encode: " & Outcome.First_Error.Code'Image);
      Assert
        (Jpeglib.Decoding.State (Image_Decoder) = Jpeglib.Decoding.Completed,
         "12-bit raw YCCK image decoder state mismatch");
      Header := Jpeglib.Decoding.Header (Image_Decoder);
      Assert (Header.Precision = 12, "12-bit raw YCCK image precision mismatch");
      Assert (Header.Mode = Jpeglib.Extended_Sequential_DCT, "12-bit raw YCCK image mode mismatch");
      Assert (Header.Color_Model = Jpeglib.YCCK, "12-bit raw YCCK image color mismatch");
      Assert
        (Natural (Image_Output_Storage (Image_Output_Storage'First + 3)) = 123,
         "12-bit raw YCCK image alpha mismatch");
   end Raw_Encode_Writes_Twelve_Bit_YCCK;
end Jpeglib_Testing.Test_Coefficient_Encoding;

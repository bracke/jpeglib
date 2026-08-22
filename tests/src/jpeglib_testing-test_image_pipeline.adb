with AUnit.Assertions;

with Jpeglib;
with Jpeglib.Coefficients;
with Jpeglib.Errors;
with Jpeglib.Images;
with Jpeglib.Internal.Colors;
with Jpeglib.Internal.Frames;
with Jpeglib.Internal.Image_Blocks;
with Jpeglib.Internal.Markers;
with Jpeglib.Internal.Quantization;
with Jpeglib.Internal.Sampling;
with Jpeglib.Internal.Segments;
with Jpeglib.Internal.Transforms;
with Jpeglib.Results;
with Jpeglib.Streams;

package body Jpeglib_Testing.Test_Image_Pipeline is
   use AUnit.Assertions;
   use type Jpeglib.Byte;
   use type Jpeglib.Byte_Count;
   use type Jpeglib.Errors.Error_Code;
   use type Jpeglib.Images.Pixel_Format;
   use type Jpeglib.Image_Width;
   use type Jpeglib.Image_Height;
   use type Jpeglib.Block_Count;
   use type Jpeglib.Coefficients.DCT_Block;
   use type Jpeglib.Coefficients.Quantized_Coefficient;
   use type Jpeglib.Internal.Transforms.Dequantized_Coefficient;
   use type Jpeglib.Internal.Colors.RGB_Sample;
   use type Jpeglib.Internal.Colors.YCbCr_Sample;
   use type Jpeglib.Internal.Sampling.Sample_Column;
   use type Jpeglib.Internal.Sampling.Sample_Row;
   use type Jpeglib.Internal.Sampling.Visible_Sample_Count;
   use type Jpeglib.Streams.Byte_Array;

   SOF0_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 17,
      8, 0, 9, 0, 17, 3,
      1, 16#22#, 0,
      2, 16#11#, 1,
      3, 16#11#, 1];


   procedure Transform_Dequantizes_Natural_Order (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Transform_Forwards_DC_Only_Block (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Transform_Forwards_DC_Only_With_Quantization (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Transform_Forwards_Full_Block_Matches_DC_Only (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Transform_Forwards_Full_Block_With_AC (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Image_Blocks_Count_Gray_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Image_Blocks_Encode_Gray_Row_Major (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Image_Blocks_Encode_Gray_Edge_Padding (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Image_Blocks_Encode_Gray_Full_Forward (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Image_Blocks_Encode_Plane_Row_Major (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Image_Blocks_Encode_Plane_Edge_Padding (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Image_Blocks_Rejects_Short_Plane_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Image_Blocks_Fill_YCbCr_Planes (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Image_Blocks_Rejects_Short_YCbCr_Planes (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Image_Blocks_Downsamples_Plane (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Image_Blocks_Downsamples_Plane_Edges (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Image_Blocks_Rejects_Short_Downsample_Target (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Image_Blocks_Computes_Chroma_Dimensions (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Image_Blocks_Subsamples_Chroma_Planes (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Transform_Full_IDCT_Matches_DC_Only (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Transform_Full_IDCT_Uses_AC_Coefficients (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Transform_Reconstructs_DC_Only_Block (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Transform_Clamps_DC_Only_Block (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Sampling_Places_420_Blocks_With_Edge_Clipping (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Sampling_Maps_Image_Pixels_To_Component_Samples (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Colors_Read_RGB_From_Input_Formats (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Colors_Convert_RGB_To_YCbCr (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Colors_Write_Gray_To_Output_Formats (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Colors_Convert_YCbCr_To_Output_Formats (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Colors_Clamp_YCbCr_Conversion (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Colors_Write_RGB_To_Output_Formats (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Colors_Write_CMYK_To_Output_Formats (T : in out AUnit.Test_Cases.Test_Case'Class);


   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("image_pipeline");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Transform_Dequantizes_Natural_Order'Access,
         "foundation.transforms.dequantize_natural_order");

      Register_Routine
        (T,
         Transform_Forwards_DC_Only_Block'Access,
         "foundation.transforms.fdct_dc_only");

      Register_Routine
        (T,
         Transform_Forwards_DC_Only_With_Quantization'Access,
         "foundation.transforms.fdct_dc_only_quantized");

      Register_Routine
        (T,
         Transform_Forwards_Full_Block_Matches_DC_Only'Access,
         "foundation.transforms.fdct_full_dc_only");

      Register_Routine
        (T,
         Transform_Forwards_Full_Block_With_AC'Access,
         "foundation.transforms.fdct_full_ac");

      Register_Routine
        (T,
         Image_Blocks_Count_Gray_Blocks'Access,
         "foundation.image_blocks.gray_count");

      Register_Routine
        (T,
         Image_Blocks_Encode_Gray_Row_Major'Access,
         "foundation.image_blocks.gray_row_major");

      Register_Routine
        (T,
         Image_Blocks_Encode_Gray_Edge_Padding'Access,
         "foundation.image_blocks.gray_edge_padding");

      Register_Routine
        (T,
         Image_Blocks_Encode_Gray_Full_Forward'Access,
         "foundation.image_blocks.gray_full_forward");

      Register_Routine
        (T,
         Image_Blocks_Encode_Plane_Row_Major'Access,
         "foundation.image_blocks.plane_row_major");

      Register_Routine
        (T,
         Image_Blocks_Encode_Plane_Edge_Padding'Access,
         "foundation.image_blocks.plane_edge_padding");

      Register_Routine
        (T,
         Image_Blocks_Rejects_Short_Plane_Blocks'Access,
         "foundation.image_blocks.plane_short");

      Register_Routine
        (T,
         Image_Blocks_Fill_YCbCr_Planes'Access,
         "foundation.image_blocks.ycbcr_planes");

      Register_Routine
        (T,
         Image_Blocks_Rejects_Short_YCbCr_Planes'Access,
         "foundation.image_blocks.ycbcr_planes_short");

      Register_Routine
        (T,
         Image_Blocks_Downsamples_Plane'Access,
         "foundation.image_blocks.downsample_plane");

      Register_Routine
        (T,
         Image_Blocks_Downsamples_Plane_Edges'Access,
         "foundation.image_blocks.downsample_plane_edges");

      Register_Routine
        (T,
         Image_Blocks_Rejects_Short_Downsample_Target'Access,
         "foundation.image_blocks.downsample_plane_short");

      Register_Routine
        (T,
         Image_Blocks_Computes_Chroma_Dimensions'Access,
         "foundation.image_blocks.chroma_dimensions");

      Register_Routine
        (T,
         Image_Blocks_Subsamples_Chroma_Planes'Access,
         "foundation.image_blocks.subsample_chroma_planes");

      Register_Routine
        (T,
         Transform_Full_IDCT_Matches_DC_Only'Access,
         "foundation.transforms.idct_full_dc_only");

      Register_Routine
        (T,
         Transform_Full_IDCT_Uses_AC_Coefficients'Access,
         "foundation.transforms.idct_full_ac");

      Register_Routine
        (T,
         Transform_Reconstructs_DC_Only_Block'Access,
         "foundation.transforms.idct_dc_only");

      Register_Routine
        (T,
         Transform_Clamps_DC_Only_Block'Access,
         "foundation.transforms.idct_dc_only_clamp");

      Register_Routine
        (T,
         Sampling_Places_420_Blocks_With_Edge_Clipping'Access,
         "foundation.sampling.420_block_placement");

      Register_Routine
        (T,
         Sampling_Maps_Image_Pixels_To_Component_Samples'Access,
         "foundation.sampling.420_pixel_mapping");

      Register_Routine
        (T,
         Colors_Read_RGB_From_Input_Formats'Access,
         "foundation.colors.read_rgb_input_formats");

      Register_Routine
        (T,
         Colors_Convert_RGB_To_YCbCr'Access,
         "foundation.colors.rgb_to_ycbcr");

      Register_Routine
        (T,
         Colors_Write_Gray_To_Output_Formats'Access,
         "foundation.colors.gray_output_formats");

      Register_Routine
        (T,
         Colors_Convert_YCbCr_To_Output_Formats'Access,
         "foundation.colors.ycbcr_output_formats");

      Register_Routine
        (T,
         Colors_Clamp_YCbCr_Conversion'Access,
         "foundation.colors.ycbcr_clamp");

      Register_Routine
        (T,
         Colors_Write_RGB_To_Output_Formats'Access,
         "foundation.colors.rgb_output_formats");

      Register_Routine
        (T,
         Colors_Write_CMYK_To_Output_Formats'Access,
         "foundation.colors.cmyk_output_formats");

   end Register_Tests;

   procedure Transform_Dequantizes_Natural_Order (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Block : Jpeglib.Coefficients.DCT_Block := [others => 0];
      Table : Jpeglib.Internal.Quantization.Quantization_Table := [others => 1];
      Output : Jpeglib.Internal.Transforms.Dequantized_Block;
   begin
      Block (0) := 3;
      Block (1) := -2;
      Block (8) := 4;
      Table (0) := 5;
      Table (1) := 7;
      Table (8) := 11;

      Output := Jpeglib.Internal.Transforms.Dequantize (Block, Table);
      Assert (Output (0) = 15, "DC dequantization mismatch");
      Assert (Output (1) = -14, "natural-order coefficient 1 dequantization mismatch");
      Assert (Output (8) = 44, "natural-order coefficient 8 dequantization mismatch");
   end Transform_Dequantizes_Natural_Order;

   procedure Transform_Forwards_DC_Only_Block (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Samples : constant Jpeglib.Internal.Transforms.Sample_Block := [others => 129];
      Table : constant Jpeglib.Internal.Quantization.Quantization_Table := [others => 1];
      Block : constant Jpeglib.Coefficients.DCT_Block :=
        Jpeglib.Internal.Transforms.Forward_DC_Only (Samples, Table);
   begin
      Assert (Block (0) = 8, "forward DC coefficient mismatch");
      for Index in Jpeglib.Coefficient_Index range 1 .. 63 loop
         Assert (Block (Index) = 0, "forward DC-only emitted AC coefficient");
      end loop;
   end Transform_Forwards_DC_Only_Block;

   procedure Transform_Forwards_DC_Only_With_Quantization (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Positive_Samples : constant Jpeglib.Internal.Transforms.Sample_Block := [others => 130];
      Negative_Samples : constant Jpeglib.Internal.Transforms.Sample_Block := [others => 127];
      Table : Jpeglib.Internal.Quantization.Quantization_Table := [others => 1];
      Positive_Block : Jpeglib.Coefficients.DCT_Block;
      Negative_Block : Jpeglib.Coefficients.DCT_Block;
   begin
      Table (0) := 2;
      Positive_Block := Jpeglib.Internal.Transforms.Forward_DC_Only (Positive_Samples, Table);
      Negative_Block := Jpeglib.Internal.Transforms.Forward_DC_Only (Negative_Samples, Table);

      Assert (Positive_Block (0) = 8, "positive quantized forward DC mismatch");
      Assert (Negative_Block (0) = -4, "negative quantized forward DC mismatch");
      for Index in Jpeglib.Coefficient_Index range 1 .. 63 loop
         Assert (Positive_Block (Index) = 0, "positive quantized forward DC emitted AC coefficient");
         Assert (Negative_Block (Index) = 0, "negative quantized forward DC emitted AC coefficient");
      end loop;
   end Transform_Forwards_DC_Only_With_Quantization;

   procedure Transform_Forwards_Full_Block_Matches_DC_Only (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Samples : constant Jpeglib.Internal.Transforms.Sample_Block := [others => 129];
      Table : constant Jpeglib.Internal.Quantization.Quantization_Table := [others => 1];
      DC_Block : constant Jpeglib.Coefficients.DCT_Block :=
        Jpeglib.Internal.Transforms.Forward_DC_Only (Samples, Table);
      Full_Block : constant Jpeglib.Coefficients.DCT_Block :=
        Jpeglib.Internal.Transforms.Forward_Block (Samples, Table);
   begin
      Assert (Full_Block = DC_Block, "full FDCT did not match DC-only path for constant block");
   end Transform_Forwards_Full_Block_Matches_DC_Only;

   procedure Transform_Forwards_Full_Block_With_AC (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Samples : constant Jpeglib.Internal.Transforms.Sample_Block :=
        [134, 133, 131, 129, 127, 125, 123, 122,
         134, 133, 131, 129, 127, 125, 123, 122,
         134, 133, 131, 129, 127, 125, 123, 122,
         134, 133, 131, 129, 127, 125, 123, 122,
         134, 133, 131, 129, 127, 125, 123, 122,
         134, 133, 131, 129, 127, 125, 123, 122,
         134, 133, 131, 129, 127, 125, 123, 122,
         134, 133, 131, 129, 127, 125, 123, 122];
      Table : constant Jpeglib.Internal.Quantization.Quantization_Table := [others => 1];
      Block : constant Jpeglib.Coefficients.DCT_Block :=
        Jpeglib.Internal.Transforms.Forward_Block (Samples, Table);
   begin
      Assert (Block (0) = 0, "full FDCT AC fixture DC mismatch");
      Assert (Block (1) = 34, "full FDCT coefficient 1 mismatch");
      Assert (Block (3) = 1, "full FDCT coefficient 3 mismatch");
      for Index in Jpeglib.Coefficient_Index loop
         if Index not in 0 | 1 | 3 then
            Assert (Block (Index) = 0, "full FDCT emitted unexpected coefficient");
         end if;
      end loop;
   end Transform_Forwards_Full_Block_With_AC;

   procedure Image_Blocks_Count_Gray_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Descriptor : constant Jpeglib.Images.Image_Descriptor :=
        (Width => 17, Height => 9, Format => Jpeglib.Images.Gray_8, Stride => 17, Accessible_Bytes => 153);
   begin
      Assert
        (Jpeglib.Internal.Image_Blocks.Required_Block_Count (Descriptor) = 6,
         "gray image block count mismatch");
   end Image_Blocks_Count_Gray_Blocks;

   procedure Image_Blocks_Encode_Gray_Row_Major (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 256 => 128];
      Input : constant Jpeglib.Images.Image_View :=
        ((Width => 16, Height => 16, Format => Jpeglib.Images.Gray_8, Stride => 16, Accessible_Bytes => 256),
         Storage'Unchecked_Access);
      Table : constant Jpeglib.Internal.Quantization.Quantization_Table := [others => 1];
      Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. 4) := [others => [others => 0]];
      Result : Jpeglib.Internal.Image_Blocks.Image_Block_Result;
   begin
      for Y in 0 .. 7 loop
         for X in 0 .. 7 loop
            Storage (1 + Y * 16 + X) := 129;
            Storage (1 + Y * 16 + 8 + X) := 130;
            Storage (1 + (8 + Y) * 16 + X) := 131;
            Storage (1 + (8 + Y) * 16 + 8 + X) := 132;
         end loop;
      end loop;

      Result := Jpeglib.Internal.Image_Blocks.Encode_Gray_DC_Blocks (Input, Table, Blocks);
      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "gray row-major block encoding failed");
      Assert (Result.Blocks_Encoded = 4, "gray row-major encoded block count mismatch");
      Assert (Blocks (1) (0) = 8, "gray row-major block 1 DC mismatch");
      Assert (Blocks (2) (0) = 16, "gray row-major block 2 DC mismatch");
      Assert (Blocks (3) (0) = 24, "gray row-major block 3 DC mismatch");
      Assert (Blocks (4) (0) = 32, "gray row-major block 4 DC mismatch");
   end Image_Blocks_Encode_Gray_Row_Major;

   procedure Image_Blocks_Encode_Gray_Edge_Padding (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array :=
        [128, 128, 128, 128, 128, 128, 128, 128, 136];
      Input : constant Jpeglib.Images.Image_View :=
        ((Width => 9, Height => 1, Format => Jpeglib.Images.Gray_8, Stride => 9, Accessible_Bytes => 9),
         Storage'Unchecked_Access);
      Table : constant Jpeglib.Internal.Quantization.Quantization_Table := [others => 1];
      Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. 2) := [others => [others => 0]];
      Result : Jpeglib.Internal.Image_Blocks.Image_Block_Result;
   begin
      Result := Jpeglib.Internal.Image_Blocks.Encode_Gray_DC_Blocks (Input, Table, Blocks);
      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "gray edge-padded block encoding failed");
      Assert (Result.Blocks_Encoded = 2, "gray edge-padded block count mismatch");
      Assert (Blocks (1) (0) = 0, "gray first edge-padded block DC mismatch");
      Assert (Blocks (2) (0) = 64, "gray replicated edge block DC mismatch");
   end Image_Blocks_Encode_Gray_Edge_Padding;

   procedure Image_Blocks_Encode_Gray_Full_Forward (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array :=
        [134, 133, 131, 129, 127, 125, 123, 122,
         134, 133, 131, 129, 127, 125, 123, 122,
         134, 133, 131, 129, 127, 125, 123, 122,
         134, 133, 131, 129, 127, 125, 123, 122,
         134, 133, 131, 129, 127, 125, 123, 122,
         134, 133, 131, 129, 127, 125, 123, 122,
         134, 133, 131, 129, 127, 125, 123, 122,
         134, 133, 131, 129, 127, 125, 123, 122];
      Input : constant Jpeglib.Images.Image_View :=
        ((Width => 8, Height => 8, Format => Jpeglib.Images.Gray_8, Stride => 8, Accessible_Bytes => 64),
         Storage'Unchecked_Access);
      Table : constant Jpeglib.Internal.Quantization.Quantization_Table := [others => 1];
      Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. 1) := [others => [others => 0]];
      Result : Jpeglib.Internal.Image_Blocks.Image_Block_Result;
   begin
      Result :=
        Jpeglib.Internal.Image_Blocks.Encode_Gray_Blocks
          (Input, Table, Blocks, Mode => Jpeglib.Internal.Image_Blocks.Full_Forward);
      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "gray full-forward block encoding failed");
      Assert (Result.Blocks_Encoded = 1, "gray full-forward encoded block count mismatch");
      Assert (Blocks (1) (0) = 0, "gray full-forward DC mismatch");
      Assert (Blocks (1) (1) = 34, "gray full-forward coefficient 1 mismatch");
      Assert (Blocks (1) (3) = 1, "gray full-forward coefficient 3 mismatch");
   end Image_Blocks_Encode_Gray_Full_Forward;

   procedure Image_Blocks_Encode_Plane_Row_Major (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Plane : Jpeglib.Streams.Byte_Array (1 .. 256) := [others => 128];
      Table : constant Jpeglib.Internal.Quantization.Quantization_Table := [others => 1];
      Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. 4) := [others => [others => 0]];
      Result : Jpeglib.Internal.Image_Blocks.Image_Block_Result;
   begin
      for Y in 0 .. 7 loop
         for X in 0 .. 7 loop
            Plane (1 + Y * 16 + X) := 129;
            Plane (1 + Y * 16 + 8 + X) := 130;
            Plane (1 + (8 + Y) * 16 + X) := 131;
            Plane (1 + (8 + Y) * 16 + 8 + X) := 132;
         end loop;
      end loop;

      Result :=
        Jpeglib.Internal.Image_Blocks.Encode_Plane_Blocks
          (Plane,
           Width => 16,
           Height => 16,
           Table => Table,
           Blocks => Blocks,
           Mode => Jpeglib.Internal.Image_Blocks.DC_Only);
      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "plane row-major block encoding failed");
      Assert (Result.Blocks_Encoded = 4, "plane row-major encoded block count mismatch");
      Assert (Blocks (1) (0) = 8, "plane row-major block 1 DC mismatch");
      Assert (Blocks (2) (0) = 16, "plane row-major block 2 DC mismatch");
      Assert (Blocks (3) (0) = 24, "plane row-major block 3 DC mismatch");
      Assert (Blocks (4) (0) = 32, "plane row-major block 4 DC mismatch");
   end Image_Blocks_Encode_Plane_Row_Major;

   procedure Image_Blocks_Encode_Plane_Edge_Padding (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Plane : constant Jpeglib.Streams.Byte_Array :=
        [128, 128, 128, 128, 128, 128, 128, 128, 136];
      Table : constant Jpeglib.Internal.Quantization.Quantization_Table := [others => 1];
      Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. 2) := [others => [others => 0]];
      Result : Jpeglib.Internal.Image_Blocks.Image_Block_Result;
   begin
      Result :=
        Jpeglib.Internal.Image_Blocks.Encode_Plane_Blocks
          (Plane,
           Width => 9,
           Height => 1,
           Table => Table,
           Blocks => Blocks,
           Mode => Jpeglib.Internal.Image_Blocks.DC_Only);
      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "plane edge-padded block encoding failed");
      Assert (Result.Blocks_Encoded = 2, "plane edge-padded block count mismatch");
      Assert (Blocks (1) (0) = 0, "plane first edge-padded block DC mismatch");
      Assert (Blocks (2) (0) = 64, "plane replicated edge block DC mismatch");
   end Image_Blocks_Encode_Plane_Edge_Padding;

   procedure Image_Blocks_Rejects_Short_Plane_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Plane : constant Jpeglib.Streams.Byte_Array := [1 .. 3 => 128];
      Table : constant Jpeglib.Internal.Quantization.Quantization_Table := [others => 1];
      Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. 1) := [others => [others => 0]];
      Result : Jpeglib.Internal.Image_Blocks.Image_Block_Result;
   begin
      Result :=
        Jpeglib.Internal.Image_Blocks.Encode_Plane_Blocks
          (Plane,
           Width => 2,
           Height => 2,
           Table => Table,
           Blocks => Blocks,
           Mode => Jpeglib.Internal.Image_Blocks.DC_Only);
      Assert (not Jpeglib.Results.Succeeded (Result.Outcome), "short plane block encoding succeeded");
      Assert
        (Result.Outcome.First_Error.Code = Jpeglib.Errors.Output_Limit_Exceeded,
         "short plane block encoding used wrong error");
      Assert (Result.Blocks_Encoded = 0, "short plane block encoding reported blocks");
   end Image_Blocks_Rejects_Short_Plane_Blocks;

   procedure Image_Blocks_Fill_YCbCr_Planes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array :=
        [255, 0, 0,
         0, 255, 0,
         0, 0, 255,
         128, 128, 128];
      Input : constant Jpeglib.Images.Image_View :=
        ((Width => 2, Height => 2, Format => Jpeglib.Images.RGB_24, Stride => 6, Accessible_Bytes => 12),
         Storage'Unchecked_Access);
      Y_Plane : Jpeglib.Streams.Byte_Array (3 .. 6) := [others => 0];
      Cb_Plane : Jpeglib.Streams.Byte_Array (5 .. 8) := [others => 0];
      Cr_Plane : Jpeglib.Streams.Byte_Array (7 .. 10) := [others => 0];
      Result : Jpeglib.Internal.Image_Blocks.Plane_Result;
   begin
      Result := Jpeglib.Internal.Image_Blocks.Fill_YCbCr_Planes (Input, Y_Plane, Cb_Plane, Cr_Plane);
      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "YCbCr plane fill failed");
      Assert (Result.Samples_Written = 4, "YCbCr plane sample count mismatch");
      Assert (Y_Plane = [76, 150, 29, 128], "Y plane mismatch");
      Assert (Cb_Plane = [85, 44, 255, 128], "Cb plane mismatch");
      Assert (Cr_Plane = [255, 21, 107, 128], "Cr plane mismatch");
   end Image_Blocks_Fill_YCbCr_Planes;

   procedure Image_Blocks_Rejects_Short_YCbCr_Planes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 6 => 128];
      Input : constant Jpeglib.Images.Image_View :=
        ((Width => 2, Height => 1, Format => Jpeglib.Images.RGB_24, Stride => 6, Accessible_Bytes => 6),
         Storage'Unchecked_Access);
      Y_Plane : Jpeglib.Streams.Byte_Array (1 .. 2) := [others => 0];
      Cb_Plane : Jpeglib.Streams.Byte_Array (1 .. 1) := [others => 0];
      Cr_Plane : Jpeglib.Streams.Byte_Array (1 .. 2) := [others => 0];
      Result : Jpeglib.Internal.Image_Blocks.Plane_Result;
   begin
      Result := Jpeglib.Internal.Image_Blocks.Fill_YCbCr_Planes (Input, Y_Plane, Cb_Plane, Cr_Plane);
      Assert (not Jpeglib.Results.Succeeded (Result.Outcome), "short YCbCr plane fill succeeded");
      Assert
        (Result.Outcome.First_Error.Code = Jpeglib.Errors.Output_Limit_Exceeded,
         "short YCbCr plane fill used wrong error");
      Assert (Result.Samples_Written = 0, "short YCbCr plane fill reported samples");
   end Image_Blocks_Rejects_Short_YCbCr_Planes;

   procedure Image_Blocks_Downsamples_Plane (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : constant Jpeglib.Streams.Byte_Array :=
        [10, 20, 30, 40,
         50, 60, 70, 80];
      Target : Jpeglib.Streams.Byte_Array (4 .. 5) := [others => 0];
      Result : Jpeglib.Internal.Image_Blocks.Plane_Result;
   begin
      Result :=
        Jpeglib.Internal.Image_Blocks.Downsample_Plane
          (Source,
           Source_Width => 4,
           Source_Height => 2,
           Horizontal_Factor => 2,
           Vertical_Factor => 2,
           Target => Target);
      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "downsample plane failed");
      Assert (Result.Samples_Written = 2, "downsample plane sample count mismatch");
      Assert (Target = [35, 55], "downsample plane average mismatch");
   end Image_Blocks_Downsamples_Plane;

   procedure Image_Blocks_Downsamples_Plane_Edges (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : constant Jpeglib.Streams.Byte_Array :=
        [10, 20, 30,
         40, 50, 60,
         70, 80, 90];
      Target : Jpeglib.Streams.Byte_Array (7 .. 10) := [others => 0];
      Result : Jpeglib.Internal.Image_Blocks.Plane_Result;
   begin
      Result :=
        Jpeglib.Internal.Image_Blocks.Downsample_Plane
          (Source,
           Source_Width => 3,
           Source_Height => 3,
           Horizontal_Factor => 2,
           Vertical_Factor => 2,
           Target => Target);
      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "edge downsample plane failed");
      Assert (Result.Samples_Written = 4, "edge downsample sample count mismatch");
      Assert (Target = [30, 45, 75, 90], "edge downsample average mismatch");
   end Image_Blocks_Downsamples_Plane_Edges;

   procedure Image_Blocks_Rejects_Short_Downsample_Target (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : constant Jpeglib.Streams.Byte_Array := [1 .. 4 => 128];
      Target : Jpeglib.Streams.Byte_Array (1 .. 1) := [others => 0];
      Result : Jpeglib.Internal.Image_Blocks.Plane_Result;
   begin
      Result :=
        Jpeglib.Internal.Image_Blocks.Downsample_Plane
          (Source,
           Source_Width => 2,
           Source_Height => 2,
           Horizontal_Factor => 1,
           Vertical_Factor => 1,
           Target => Target);
      Assert (not Jpeglib.Results.Succeeded (Result.Outcome), "short downsample target succeeded");
      Assert
        (Result.Outcome.First_Error.Code = Jpeglib.Errors.Output_Limit_Exceeded,
         "short downsample target used wrong error");
      Assert (Result.Samples_Written = 0, "short downsample target reported samples");
   end Image_Blocks_Rejects_Short_Downsample_Target;

   procedure Image_Blocks_Computes_Chroma_Dimensions (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert
        (Jpeglib.Internal.Image_Blocks.Chroma_Width (5, Jpeglib.Internal.Image_Blocks.Subsampling_444) = 5,
         "4:4:4 chroma width mismatch");
      Assert
        (Jpeglib.Internal.Image_Blocks.Chroma_Height (3, Jpeglib.Internal.Image_Blocks.Subsampling_444) = 3,
         "4:4:4 chroma height mismatch");
      Assert
        (Jpeglib.Internal.Image_Blocks.Chroma_Width (5, Jpeglib.Internal.Image_Blocks.Subsampling_422) = 3,
         "4:2:2 chroma width mismatch");
      Assert
        (Jpeglib.Internal.Image_Blocks.Chroma_Height (3, Jpeglib.Internal.Image_Blocks.Subsampling_422) = 3,
         "4:2:2 chroma height mismatch");
      Assert
        (Jpeglib.Internal.Image_Blocks.Chroma_Width (5, Jpeglib.Internal.Image_Blocks.Subsampling_420) = 3,
         "4:2:0 chroma width mismatch");
      Assert
        (Jpeglib.Internal.Image_Blocks.Chroma_Height (3, Jpeglib.Internal.Image_Blocks.Subsampling_420) = 2,
         "4:2:0 chroma height mismatch");
      Assert
        (Jpeglib.Internal.Image_Blocks.Chroma_Width (5, Jpeglib.Internal.Image_Blocks.Subsampling_411) = 2,
         "4:1:1 chroma width mismatch");
      Assert
        (Jpeglib.Internal.Image_Blocks.Chroma_Height (3, Jpeglib.Internal.Image_Blocks.Subsampling_411) = 3,
         "4:1:1 chroma height mismatch");
   end Image_Blocks_Computes_Chroma_Dimensions;

   procedure Image_Blocks_Subsamples_Chroma_Planes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Cb_Source : constant Jpeglib.Streams.Byte_Array :=
        [10, 20, 30, 40,
         50, 60, 70, 80];
      Cr_Source : constant Jpeglib.Streams.Byte_Array :=
        [80, 70, 60, 50,
         40, 30, 20, 10];
      Cb_Target : Jpeglib.Streams.Byte_Array (3 .. 4) := [others => 0];
      Cr_Target : Jpeglib.Streams.Byte_Array (5 .. 6) := [others => 0];
      Result : Jpeglib.Internal.Image_Blocks.Plane_Result;
   begin
      Result :=
        Jpeglib.Internal.Image_Blocks.Subsample_Chroma_Planes
          (Cb_Source,
           Cr_Source,
           Source_Width => 4,
           Source_Height => 2,
           Layout => Jpeglib.Internal.Image_Blocks.Subsampling_420,
           Cb_Target => Cb_Target,
           Cr_Target => Cr_Target);
      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "chroma plane subsampling failed");
      Assert (Result.Samples_Written = 4, "chroma plane subsampling count mismatch");
      Assert (Cb_Target = [35, 55], "subsampled Cb plane mismatch");
      Assert (Cr_Target = [55, 35], "subsampled Cr plane mismatch");
   end Image_Blocks_Subsamples_Chroma_Planes;

   procedure Transform_Full_IDCT_Matches_DC_Only (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Block : Jpeglib.Internal.Transforms.Dequantized_Block := [others => 0];
      Full : Jpeglib.Internal.Transforms.Sample_Block;
      DC_Only : Jpeglib.Internal.Transforms.Sample_Block;
   begin
      Block (0) := 32;
      Full := Jpeglib.Internal.Transforms.Reconstruct_Block (Block);
      DC_Only := Jpeglib.Internal.Transforms.Reconstruct_DC_Only (Block);
      for Index in Jpeglib.Coefficient_Index loop
         Assert (Full (Index) = DC_Only (Index), "full IDCT DC-only mismatch");
      end loop;
   end Transform_Full_IDCT_Matches_DC_Only;

   procedure Transform_Full_IDCT_Uses_AC_Coefficients (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Block : Jpeglib.Internal.Transforms.Dequantized_Block := [others => 0];
      Samples : Jpeglib.Internal.Transforms.Sample_Block;
   begin
      Block (1) := 32;
      Samples := Jpeglib.Internal.Transforms.Reconstruct_Block (Block);
      for Y in Jpeglib.Coefficient_Index range 0 .. 7 loop
         Assert
           (Samples (Jpeglib.Coefficient_Index (Natural (Y) * 8 + 0)) = 134,
            "AC column 0 sample mismatch");
         Assert
           (Samples (Jpeglib.Coefficient_Index (Natural (Y) * 8 + 1)) = 133,
            "AC column 1 sample mismatch");
         Assert
           (Samples (Jpeglib.Coefficient_Index (Natural (Y) * 8 + 2)) = 131,
            "AC column 2 sample mismatch");
         Assert
           (Samples (Jpeglib.Coefficient_Index (Natural (Y) * 8 + 3)) = 129,
            "AC column 3 sample mismatch");
         Assert
           (Samples (Jpeglib.Coefficient_Index (Natural (Y) * 8 + 4)) = 127,
            "AC column 4 sample mismatch");
         Assert
           (Samples (Jpeglib.Coefficient_Index (Natural (Y) * 8 + 5)) = 125,
            "AC column 5 sample mismatch");
         Assert
           (Samples (Jpeglib.Coefficient_Index (Natural (Y) * 8 + 6)) = 123,
            "AC column 6 sample mismatch");
         Assert
           (Samples (Jpeglib.Coefficient_Index (Natural (Y) * 8 + 7)) = 122,
            "AC column 7 sample mismatch");
      end loop;
   end Transform_Full_IDCT_Uses_AC_Coefficients;

   procedure Transform_Reconstructs_DC_Only_Block (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Block : Jpeglib.Internal.Transforms.Dequantized_Block := [others => 0];
      Samples : Jpeglib.Internal.Transforms.Sample_Block;
   begin
      Block (0) := 32;
      Samples := Jpeglib.Internal.Transforms.Reconstruct_DC_Only (Block);
      for Sample of Samples loop
         Assert (Sample = 132, "DC-only reconstructed sample mismatch");
      end loop;
   end Transform_Reconstructs_DC_Only_Block;

   procedure Transform_Clamps_DC_Only_Block (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Low_Block : Jpeglib.Internal.Transforms.Dequantized_Block := [others => 0];
      High_Block : Jpeglib.Internal.Transforms.Dequantized_Block := [others => 0];
      Low_Samples : Jpeglib.Internal.Transforms.Sample_Block;
      High_Samples : Jpeglib.Internal.Transforms.Sample_Block;
   begin
      Low_Block (0) := -2_000;
      High_Block (0) := 2_000;
      Low_Samples := Jpeglib.Internal.Transforms.Reconstruct_DC_Only (Low_Block);
      High_Samples := Jpeglib.Internal.Transforms.Reconstruct_DC_Only (High_Block);

      for Sample of Low_Samples loop
         Assert (Sample = 0, "low DC-only sample was not clamped");
      end loop;
      for Sample of High_Samples loop
         Assert (Sample = 255, "high DC-only sample was not clamped");
      end loop;
   end Transform_Clamps_DC_Only_Block;

   procedure Sampling_Places_420_Blocks_With_Edge_Clipping (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOF0_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOF0, 70);
         Frame : constant Jpeglib.Internal.Frames.Frame :=
           Jpeglib.Internal.Frames.Parse_SOF (Segment, Jpeglib.Baseline_DCT);
         Y_Edge : constant Jpeglib.Internal.Sampling.Block_Placement :=
           Jpeglib.Internal.Sampling.Placement
             (Frame, 1, MCU_C => 1, MCU_R => 0, Horizontal_Block => 0, Vertical_Block => 1);
         Y_Padded : constant Jpeglib.Internal.Sampling.Block_Placement :=
           Jpeglib.Internal.Sampling.Placement
             (Frame, 1, MCU_C => 1, MCU_R => 0, Horizontal_Block => 1, Vertical_Block => 1);
         Cb_Edge : constant Jpeglib.Internal.Sampling.Block_Placement :=
           Jpeglib.Internal.Sampling.Placement
             (Frame, 2, MCU_C => 1, MCU_R => 0, Horizontal_Block => 0, Vertical_Block => 0);
      begin
         Assert (Jpeglib.Results.Succeeded (Jpeglib.Internal.Frames.Status (Frame)), "SOF parse failed");

         Assert (Y_Edge.Column = 16, "Y edge block column mismatch");
         Assert (Y_Edge.Row = 8, "Y edge block row mismatch");
         Assert (Y_Edge.Visible_Width = 1, "Y edge block visible width mismatch");
         Assert (Y_Edge.Visible_Height = 1, "Y edge block visible height mismatch");

         Assert (Y_Padded.Column = 24, "Y padded block column mismatch");
         Assert (Y_Padded.Row = 8, "Y padded block row mismatch");
         Assert (Y_Padded.Visible_Width = 0, "Y padded block visible width mismatch");
         Assert (Y_Padded.Visible_Height = 1, "Y padded block visible height mismatch");

         Assert (Cb_Edge.Column = 8, "Cb edge block column mismatch");
         Assert (Cb_Edge.Row = 0, "Cb edge block row mismatch");
         Assert (Cb_Edge.Visible_Width = 1, "Cb edge block visible width mismatch");
         Assert (Cb_Edge.Visible_Height = 5, "Cb edge block visible height mismatch");
      end;
   end Sampling_Places_420_Blocks_With_Edge_Clipping;

   procedure Sampling_Maps_Image_Pixels_To_Component_Samples (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOF0_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOF0, 70);
         Frame : constant Jpeglib.Internal.Frames.Frame :=
           Jpeglib.Internal.Frames.Parse_SOF (Segment, Jpeglib.Baseline_DCT);
      begin
         Assert (Jpeglib.Results.Succeeded (Jpeglib.Internal.Frames.Status (Frame)), "SOF parse failed");

         Assert
           (Jpeglib.Internal.Sampling.Component_Column_For_Image (Frame, 1, 16) = 16,
            "full-resolution component column mismatch");
         Assert
           (Jpeglib.Internal.Sampling.Component_Row_For_Image (Frame, 1, 8) = 8,
            "full-resolution component row mismatch");
         Assert
           (Jpeglib.Internal.Sampling.Component_Column_For_Image (Frame, 2, 0) = 0,
            "subsampled component first column mismatch");
         Assert
           (Jpeglib.Internal.Sampling.Component_Column_For_Image (Frame, 2, 1) = 0,
            "subsampled component repeated column mismatch");
         Assert
           (Jpeglib.Internal.Sampling.Component_Column_For_Image (Frame, 2, 2) = 1,
            "subsampled component next column mismatch");
         Assert
           (Jpeglib.Internal.Sampling.Component_Column_For_Image (Frame, 2, 16) = 8,
            "subsampled component clipped column mismatch");
         Assert
           (Jpeglib.Internal.Sampling.Component_Row_For_Image (Frame, 2, 8) = 4,
            "subsampled component clipped row mismatch");
      end;
   end Sampling_Maps_Image_Pixels_To_Component_Samples;

   procedure Colors_Read_RGB_From_Input_Formats (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Gray_Storage : aliased Jpeglib.Streams.Byte_Array := [1 => 42];
      RGB_Storage : aliased Jpeglib.Streams.Byte_Array := [10, 20, 30];
      BGR_Storage : aliased Jpeglib.Streams.Byte_Array := [30, 20, 10];
      RGBA_Storage : aliased Jpeglib.Streams.Byte_Array := [10, 20, 30, 99];
      BGRA_Storage : aliased Jpeglib.Streams.Byte_Array := [30, 20, 10, 99];
      Gray_View : constant Jpeglib.Images.Image_View :=
        ((Width => 1, Height => 1, Format => Jpeglib.Images.Gray_8, Stride => 1, Accessible_Bytes => 1),
         Gray_Storage'Unchecked_Access);
      RGB_View : constant Jpeglib.Images.Image_View :=
        ((Width => 1, Height => 1, Format => Jpeglib.Images.RGB_24, Stride => 3, Accessible_Bytes => 3),
         RGB_Storage'Unchecked_Access);
      BGR_View : constant Jpeglib.Images.Image_View :=
        ((Width => 1, Height => 1, Format => Jpeglib.Images.BGR_24, Stride => 3, Accessible_Bytes => 3),
         BGR_Storage'Unchecked_Access);
      RGBA_View : constant Jpeglib.Images.Image_View :=
        ((Width => 1, Height => 1, Format => Jpeglib.Images.RGBA_32, Stride => 4, Accessible_Bytes => 4),
         RGBA_Storage'Unchecked_Access);
      BGRA_View : constant Jpeglib.Images.Image_View :=
        ((Width => 1, Height => 1, Format => Jpeglib.Images.BGRA_32, Stride => 4, Accessible_Bytes => 4),
         BGRA_Storage'Unchecked_Access);
   begin
      Assert
        (Jpeglib.Internal.Colors.Read_RGB (Gray_View, 0, 0) = (R => 42, G => 42, B => 42),
         "gray input RGB sample mismatch");
      Assert
        (Jpeglib.Internal.Colors.Read_RGB (RGB_View, 0, 0) = (R => 10, G => 20, B => 30),
         "RGB input sample mismatch");
      Assert
        (Jpeglib.Internal.Colors.Read_RGB (BGR_View, 0, 0) = (R => 10, G => 20, B => 30),
         "BGR input sample mismatch");
      Assert
        (Jpeglib.Internal.Colors.Read_RGB (RGBA_View, 0, 0) = (R => 10, G => 20, B => 30),
         "RGBA input sample mismatch");
      Assert
        (Jpeglib.Internal.Colors.Read_RGB (BGRA_View, 0, 0) = (R => 10, G => 20, B => 30),
         "BGRA input sample mismatch");
   end Colors_Read_RGB_From_Input_Formats;

   procedure Colors_Convert_RGB_To_YCbCr (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert
        (Jpeglib.Internal.Colors.Convert_RGB_To_YCbCr ((R => 128, G => 128, B => 128))
         = (Y => 128, Cb => 128, Cr => 128),
         "neutral RGB to YCbCr mismatch");
      Assert
        (Jpeglib.Internal.Colors.Convert_RGB_To_YCbCr ((R => 255, G => 0, B => 0))
         = (Y => 76, Cb => 85, Cr => 255),
         "red RGB to YCbCr mismatch");
      Assert
        (Jpeglib.Internal.Colors.Convert_RGB_To_YCbCr ((R => 0, G => 255, B => 0))
         = (Y => 150, Cb => 44, Cr => 21),
         "green RGB to YCbCr mismatch");
      Assert
        (Jpeglib.Internal.Colors.Convert_RGB_To_YCbCr ((R => 0, G => 0, B => 255))
         = (Y => 29, Cb => 255, Cr => 107),
         "blue RGB to YCbCr mismatch");
   end Colors_Convert_RGB_To_YCbCr;

   procedure Colors_Write_Gray_To_Output_Formats (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Gray_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 1 => 0];
      RGB_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 3 => 0];
      BGR_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 3 => 0];
      RGBA_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 4 => 0];
      BGRA_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 4 => 0];
      Gray_View : Jpeglib.Images.Mutable_Image_View :=
        ((Width => 1, Height => 1, Format => Jpeglib.Images.Gray_8, Stride => 1, Accessible_Bytes => 1),
         Gray_Storage'Unchecked_Access);
      RGB_View : Jpeglib.Images.Mutable_Image_View :=
        ((Width => 1, Height => 1, Format => Jpeglib.Images.RGB_24, Stride => 3, Accessible_Bytes => 3),
         RGB_Storage'Unchecked_Access);
      BGR_View : Jpeglib.Images.Mutable_Image_View :=
        ((Width => 1, Height => 1, Format => Jpeglib.Images.BGR_24, Stride => 3, Accessible_Bytes => 3),
         BGR_Storage'Unchecked_Access);
      RGBA_View : Jpeglib.Images.Mutable_Image_View :=
        ((Width => 1, Height => 1, Format => Jpeglib.Images.RGBA_32, Stride => 4, Accessible_Bytes => 4),
         RGBA_Storage'Unchecked_Access);
      BGRA_View : Jpeglib.Images.Mutable_Image_View :=
        ((Width => 1, Height => 1, Format => Jpeglib.Images.BGRA_32, Stride => 4, Accessible_Bytes => 4),
         BGRA_Storage'Unchecked_Access);
   begin
      Jpeglib.Internal.Colors.Write_Gray (Gray_View, 0, 0, 42, Alpha => 77);
      Jpeglib.Internal.Colors.Write_Gray (RGB_View, 0, 0, 42, Alpha => 77);
      Jpeglib.Internal.Colors.Write_Gray (BGR_View, 0, 0, 42, Alpha => 77);
      Jpeglib.Internal.Colors.Write_Gray (RGBA_View, 0, 0, 42, Alpha => 77);
      Jpeglib.Internal.Colors.Write_Gray (BGRA_View, 0, 0, 42, Alpha => 77);

      Assert (Gray_Storage = [1 => 42], "gray output byte mismatch");
      Assert (RGB_Storage = [42, 42, 42], "RGB gray expansion mismatch");
      Assert (BGR_Storage = [42, 42, 42], "BGR gray expansion mismatch");
      Assert (RGBA_Storage = [42, 42, 42, 77], "RGBA gray expansion mismatch");
      Assert (BGRA_Storage = [42, 42, 42, 77], "BGRA gray expansion mismatch");
   end Colors_Write_Gray_To_Output_Formats;

   procedure Colors_Convert_YCbCr_To_Output_Formats (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      RGB_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 6 => 0];
      BGR_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 3 => 0];
      RGBA_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 4 => 0];
      RGB_View : Jpeglib.Images.Mutable_Image_View :=
        ((Width => 2, Height => 1, Format => Jpeglib.Images.RGB_24, Stride => 6, Accessible_Bytes => 6),
         RGB_Storage'Unchecked_Access);
      BGR_View : Jpeglib.Images.Mutable_Image_View :=
        ((Width => 1, Height => 1, Format => Jpeglib.Images.BGR_24, Stride => 3, Accessible_Bytes => 3),
         BGR_Storage'Unchecked_Access);
      RGBA_View : Jpeglib.Images.Mutable_Image_View :=
        ((Width => 1, Height => 1, Format => Jpeglib.Images.RGBA_32, Stride => 4, Accessible_Bytes => 4),
         RGBA_Storage'Unchecked_Access);
   begin
      Jpeglib.Internal.Colors.Write_YCbCr (RGB_View, 0, 0, 128, 128, 128);
      Jpeglib.Internal.Colors.Write_YCbCr (RGB_View, 1, 0, 76, 85, 255);
      Jpeglib.Internal.Colors.Write_YCbCr (BGR_View, 0, 0, 76, 85, 255);
      Jpeglib.Internal.Colors.Write_YCbCr (RGBA_View, 0, 0, 76, 85, 255, Alpha => 19);

      Assert (RGB_Storage (1 .. 3) = [128, 128, 128], "neutral YCbCr conversion mismatch");
      Assert (RGB_Storage (4 .. 6) = [254, 0, 0], "red YCbCr to RGB conversion mismatch");
      Assert (BGR_Storage = [0, 0, 254], "red YCbCr to BGR conversion mismatch");
      Assert (RGBA_Storage = [254, 0, 0, 19], "red YCbCr to RGBA conversion mismatch");
   end Colors_Convert_YCbCr_To_Output_Formats;

   procedure Colors_Clamp_YCbCr_Conversion (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 3 => 0];
      View : Jpeglib.Images.Mutable_Image_View :=
        ((Width => 1, Height => 1, Format => Jpeglib.Images.RGB_24, Stride => 3, Accessible_Bytes => 3),
         Storage'Unchecked_Access);
   begin
      Jpeglib.Internal.Colors.Write_YCbCr (View, 0, 0, 0, 0, 0);
      Assert (Storage = [0, 135, 0], "low YCbCr clamp mismatch");

      Jpeglib.Internal.Colors.Write_YCbCr (View, 0, 0, 255, 255, 255);
      Assert (Storage = [255, 121, 255], "high YCbCr clamp mismatch");
   end Colors_Clamp_YCbCr_Conversion;

   procedure Colors_Write_RGB_To_Output_Formats (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      RGB_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 3 => 0];
      BGR_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 3 => 0];
      BGRA_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 4 => 0];
      RGB_View : Jpeglib.Images.Mutable_Image_View :=
        ((Width => 1, Height => 1, Format => Jpeglib.Images.RGB_24, Stride => 3, Accessible_Bytes => 3),
         RGB_Storage'Unchecked_Access);
      BGR_View : Jpeglib.Images.Mutable_Image_View :=
        ((Width => 1, Height => 1, Format => Jpeglib.Images.BGR_24, Stride => 3, Accessible_Bytes => 3),
         BGR_Storage'Unchecked_Access);
      BGRA_View : Jpeglib.Images.Mutable_Image_View :=
        ((Width => 1, Height => 1, Format => Jpeglib.Images.BGRA_32, Stride => 4, Accessible_Bytes => 4),
         BGRA_Storage'Unchecked_Access);
   begin
      Jpeglib.Internal.Colors.Write_RGB (RGB_View, 0, 0, 10, 20, 30, Alpha => 40);
      Jpeglib.Internal.Colors.Write_RGB (BGR_View, 0, 0, 10, 20, 30, Alpha => 40);
      Jpeglib.Internal.Colors.Write_RGB (BGRA_View, 0, 0, 10, 20, 30, Alpha => 40);

      Assert (RGB_Storage = [10, 20, 30], "RGB writer channel order mismatch");
      Assert (BGR_Storage = [30, 20, 10], "BGR writer channel order mismatch");
      Assert (BGRA_Storage = [30, 20, 10, 40], "BGRA writer channel order mismatch");
   end Colors_Write_RGB_To_Output_Formats;

   procedure Colors_Write_CMYK_To_Output_Formats (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      RGB_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 3 => 0];
      RGBA_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 4 => 0];
      RGB_View : Jpeglib.Images.Mutable_Image_View :=
        ((Width => 1, Height => 1, Format => Jpeglib.Images.RGB_24, Stride => 3, Accessible_Bytes => 3),
         RGB_Storage'Unchecked_Access);
      RGBA_View : Jpeglib.Images.Mutable_Image_View :=
        ((Width => 1, Height => 1, Format => Jpeglib.Images.RGBA_32, Stride => 4, Accessible_Bytes => 4),
         RGBA_Storage'Unchecked_Access);
   begin
      Jpeglib.Internal.Colors.Write_CMYK (RGB_View, 0, 0, 10, 20, 30, 40);
      Jpeglib.Internal.Colors.Write_CMYK (RGBA_View, 0, 0, 128, 128, 128, 128, Alpha => 91);

      Assert (RGB_Storage = [205, 195, 185], "CMYK to RGB conversion mismatch");
      Assert (RGBA_Storage = [0, 0, 0, 91], "CMYK to RGBA clamp mismatch");

      Jpeglib.Internal.Colors.Write_YCCK (RGB_View, 0, 0, 128, 128, 128, 128);
      Assert (RGB_Storage = [0, 0, 0], "YCCK to RGB conversion mismatch");
   end Colors_Write_CMYK_To_Output_Formats;

end Jpeglib_Testing.Test_Image_Pipeline;

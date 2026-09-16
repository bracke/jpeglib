with Jpeglib.Coefficients;
with Jpeglib.Internal.Huffman;
with Jpeglib.Internal.Image_Blocks;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Encoder_Baseline_Scans is
   pragma Preelaborate;

   --  Encode blocks.
   --  @param Output See package contract for this parameter.
   --  @param DC_Definition See package contract for this parameter.
   --  @param AC_Definition See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @return Operation result.
   function Encode_Blocks
     (Output : in out Streams.Destination'Class;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval) return Results.Result;

   --  Encode ycbcr blocks.
   --  @param Output See package contract for this parameter.
   --  @param Luma_DC_Definition See package contract for this parameter.
   --  @param Luma_AC_Definition See package contract for this parameter.
   --  @param Chroma_DC_Definition See package contract for this parameter.
   --  @param Chroma_AC_Definition See package contract for this parameter.
   --  @param Y_Blocks See package contract for this parameter.
   --  @param Cb_Blocks See package contract for this parameter.
   --  @param Cr_Blocks See package contract for this parameter.
   --  @param Y_Block_Columns See package contract for this parameter.
   --  @param C_Block_Columns See package contract for this parameter.
   --  @param MCU_Columns See package contract for this parameter.
   --  @param MCU_Rows See package contract for this parameter.
   --  @param Layout See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @return Operation result.
   function Encode_YCbCr_Blocks
     (Output : in out Streams.Destination'Class;
      Luma_DC_Definition : Huffman.Huffman_Definition;
      Luma_AC_Definition : Huffman.Huffman_Definition;
      Chroma_DC_Definition : Huffman.Huffman_Definition;
      Chroma_AC_Definition : Huffman.Huffman_Definition;
      Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Cb_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Cr_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Y_Block_Columns : Positive;
      C_Block_Columns : Positive;
      MCU_Columns : Positive;
      MCU_Rows : Positive;
      Layout : Image_Blocks.Subsampling_Layout;
      Restart : Restart_Interval) return Results.Result;

   --  Encode cmyk blocks.
   --  @param Output See package contract for this parameter.
   --  @param DC_Definition See package contract for this parameter.
   --  @param AC_Definition See package contract for this parameter.
   --  @param C_Blocks See package contract for this parameter.
   --  @param M_Blocks See package contract for this parameter.
   --  @param Y_Blocks See package contract for this parameter.
   --  @param K_Blocks See package contract for this parameter.
   --  @param Block_Columns See package contract for this parameter.
   --  @param Block_Rows See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @return Operation result.
   function Encode_CMYK_Blocks
     (Output : in out Streams.Destination'Class;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      C_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      M_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      K_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Block_Columns : Positive;
      Block_Rows : Positive;
      Restart : Restart_Interval) return Results.Result;
end Jpeglib.Internal.Encoder_Baseline_Scans;

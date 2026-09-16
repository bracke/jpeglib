with Jpeglib.Coefficients;
with Jpeglib.Internal.Huffman;
with Jpeglib.Internal.Image_Blocks;

package Jpeglib.Internal.Encoder_Huffman_Optimization is
   pragma Preelaborate;

   --  Optimized definitions for blocks.
   --  @param Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param DC_Definition See package contract for this parameter.
   --  @param AC_Definition See package contract for this parameter.
   procedure Optimized_Definitions_For_Blocks
     (Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      DC_Definition : out Huffman.Huffman_Definition;
      AC_Definition : out Huffman.Huffman_Definition);

   --  Optimized definitions for ycbcr blocks.
   --  @param Y_Blocks See package contract for this parameter.
   --  @param Cb_Blocks See package contract for this parameter.
   --  @param Cr_Blocks See package contract for this parameter.
   --  @param Y_Block_Columns See package contract for this parameter.
   --  @param C_Block_Columns See package contract for this parameter.
   --  @param MCU_Columns See package contract for this parameter.
   --  @param MCU_Rows See package contract for this parameter.
   --  @param Layout See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Luma_DC_Definition See package contract for this parameter.
   --  @param Luma_AC_Definition See package contract for this parameter.
   --  @param Chroma_DC_Definition See package contract for this parameter.
   --  @param Chroma_AC_Definition See package contract for this parameter.
   procedure Optimized_Definitions_For_YCbCr_Blocks
     (Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Cb_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Cr_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Y_Block_Columns : Positive;
      C_Block_Columns : Positive;
      MCU_Columns : Positive;
      MCU_Rows : Positive;
      Layout : Image_Blocks.Subsampling_Layout;
      Restart : Restart_Interval;
      Luma_DC_Definition : out Huffman.Huffman_Definition;
      Luma_AC_Definition : out Huffman.Huffman_Definition;
      Chroma_DC_Definition : out Huffman.Huffman_Definition;
      Chroma_AC_Definition : out Huffman.Huffman_Definition);

   --  Optimized definitions for cmyk blocks.
   --  @param C_Blocks See package contract for this parameter.
   --  @param M_Blocks See package contract for this parameter.
   --  @param Y_Blocks See package contract for this parameter.
   --  @param K_Blocks See package contract for this parameter.
   --  @param Block_Columns See package contract for this parameter.
   --  @param Block_Rows See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param DC_Definition See package contract for this parameter.
   --  @param AC_Definition See package contract for this parameter.
   procedure Optimized_Definitions_For_CMYK_Blocks
     (C_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      M_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      K_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Block_Columns : Positive;
      Block_Rows : Positive;
      Restart : Restart_Interval;
      DC_Definition : out Huffman.Huffman_Definition;
      AC_Definition : out Huffman.Huffman_Definition);
end Jpeglib.Internal.Encoder_Huffman_Optimization;

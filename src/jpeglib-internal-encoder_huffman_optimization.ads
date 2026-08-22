with Jpeglib.Coefficients;
with Jpeglib.Internal.Huffman;
with Jpeglib.Internal.Image_Blocks;

package Jpeglib.Internal.Encoder_Huffman_Optimization is
   pragma Preelaborate;

   procedure Optimized_Definitions_For_Blocks
     (Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      DC_Definition : out Huffman.Huffman_Definition;
      AC_Definition : out Huffman.Huffman_Definition);

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
end Jpeglib.Internal.Encoder_Huffman_Optimization;

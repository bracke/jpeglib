with Jpeglib.Coefficients;
with Jpeglib.Internal.Huffman;
with Jpeglib.Internal.Image_Blocks;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Encoder_Progressive_Scans is
   pragma Preelaborate;

   function Encode_Progressive_Blocks
     (Output : in out Streams.Destination'Class;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      Refine : Boolean) return Results.Result;

   function Encode_Progressive_Component_Scan
     (Output : in out Streams.Destination'Class;
      Definition : Huffman.Huffman_Definition;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      DC_Scan : Boolean;
      Refinement : Boolean;
      Al : Successive_Approximation_Value) return Results.Result;

   function Encode_Progressive_Component_Scan_With_Header
     (Output : in out Streams.Destination'Class;
      Definition : Huffman.Huffman_Definition;
      Component : Component_Identifier;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      DC_Scan : Boolean;
      Refinement : Boolean;
      Al : Successive_Approximation_Value;
      DC_Table : Huffman_Table_Index := 0;
      AC_Table : Huffman_Table_Index := 0) return Results.Result;

   function Encode_Progressive_Component_Blocks
     (Output : in out Streams.Destination'Class;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      Component : Component_Identifier;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      Refine : Boolean;
      DC_Table : Huffman_Table_Index := 0;
      AC_Table : Huffman_Table_Index := 0) return Results.Result;

   function Encode_Progressive_Component_Grid
     (Output : in out Streams.Destination'Class;
      Definition : Huffman.Huffman_Definition;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Block_Columns : Positive;
      Block_Rows : Positive;
      Source_Block_Columns : Positive;
      Restart : Restart_Interval;
      DC_Scan : Boolean;
      Refinement : Boolean;
      Al : Successive_Approximation_Value) return Results.Result;

   function Encode_Progressive_YCbCr_Blocks
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
      Y_Component_Block_Columns : Positive;
      Y_Component_Block_Rows : Positive;
      Chroma_Component_Block_Columns : Positive;
      Chroma_Component_Block_Rows : Positive;
      MCU_Columns : Positive;
      MCU_Rows : Positive;
      Layout : Image_Blocks.Subsampling_Layout;
      Restart : Restart_Interval;
      Refine : Boolean) return Results.Result;
end Jpeglib.Internal.Encoder_Progressive_Scans;

with Jpeglib.Coefficients;
with Jpeglib.Internal.Arithmetic;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Encoder_Arithmetic_Scans is
   pragma Preelaborate;

   function Arithmetic_Blocks_Supported
     (Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval) return Boolean;

   function Encode_Arithmetic_Blocks
     (Output : in out Streams.Destination'Class;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval) return Results.Result;

   function Encode_Arithmetic_Progressive_Fast_Preview_Blocks
     (Output : in out Streams.Destination'Class;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      Refine : Boolean;
      Grayscale : Boolean := True;
      Component : Component_Identifier := 1;
      DC_Table : Huffman_Table_Index := 0;
      AC_Table : Huffman_Table_Index := 0;
      Shared_AC_Bins : in out Arithmetic.Probability_Bin_Array;
      Refinement_Bitplanes : Successive_Approximation_Value := 1) return Results.Result;

   function Encode_Arithmetic_Progressive_Gray_Alpha_Blocks
     (Output : in out Streams.Destination'Class;
      Gray_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Alpha_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      Refine : Boolean) return Results.Result;
end Jpeglib.Internal.Encoder_Arithmetic_Scans;

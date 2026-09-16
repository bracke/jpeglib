with Jpeglib.Coefficients;
with Jpeglib.Internal.Arithmetic;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Encoder_Arithmetic_Scans is
   pragma Preelaborate;

   --  Arithmetic blocks supported.
   --  @param Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @return Operation result.
   function Arithmetic_Blocks_Supported
     (Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval) return Boolean;

   --  Encode arithmetic blocks.
   --  @param Output See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @return Operation result.
   function Encode_Arithmetic_Blocks
     (Output : in out Streams.Destination'Class;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval) return Results.Result;

   --  Encode arithmetic component blocks.
   --  @param Output See package contract for this parameter.
   --  @param Component See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param DC_Table See package contract for this parameter.
   --  @param AC_Table See package contract for this parameter.
   --  @return Operation result.
   function Encode_Arithmetic_Component_Blocks
     (Output : in out Streams.Destination'Class;
      Component : Component_Identifier;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      DC_Table : Huffman_Table_Index;
      AC_Table : Huffman_Table_Index) return Results.Result;

   --  Encode arithmetic progressive fast preview blocks.
   --  @param Output See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Refine See package contract for this parameter.
   --  @param Grayscale See package contract for this parameter.
   --  @param Component See package contract for this parameter.
   --  @param DC_Table See package contract for this parameter.
   --  @param AC_Table See package contract for this parameter.
   --  @param Shared_AC_Bins See package contract for this parameter.
   --  @param Refinement_Bitplanes See package contract for this parameter.
   --  @return Operation result.
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

   --  Encode arithmetic progressive gray alpha blocks.
   --  @param Output See package contract for this parameter.
   --  @param Gray_Blocks See package contract for this parameter.
   --  @param Alpha_Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Refine See package contract for this parameter.
   --  @return Operation result.
   function Encode_Arithmetic_Progressive_Gray_Alpha_Blocks
     (Output : in out Streams.Destination'Class;
      Gray_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Alpha_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      Refine : Boolean) return Results.Result;
end Jpeglib.Internal.Encoder_Arithmetic_Scans;

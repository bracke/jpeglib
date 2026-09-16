with Interfaces;
with Jpeglib.Coefficients;
with Jpeglib.Internal.Arithmetic;
with Jpeglib.Internal.Bit_Streams;
with Jpeglib.Internal.Frames;
with Jpeglib.Internal.Huffman;
with Jpeglib.Internal.Progressive;
with Jpeglib.Internal.Scans;
with Jpeglib.Results;

package Jpeglib.Internal.Coefficients is
   pragma Preelaborate;

   type DC_Predictor is new Interfaces.Integer_32;
   type Predictor_Array is array (Component_Index) of DC_Predictor;
   type EOB_Run_Count is range 0 .. 65_535;

   type Block_Result is record
      Outcome : Results.Result := Results.Success;
      Block : Jpeglib.Coefficients.DCT_Block := [others => 0];
   end record;

   --  Decode baseline block.
   --  @param Bits See package contract for this parameter.
   --  @param DC_Table See package contract for this parameter.
   --  @param AC_Table See package contract for this parameter.
   --  @param Predictor See package contract for this parameter.
   --  @return Operation result.
   function Decode_Baseline_Block
     (Bits : in out Bit_Streams.Bit_Reader;
      DC_Table : Huffman.Compiled_Huffman;
      AC_Table : Huffman.Compiled_Huffman;
      Predictor : in out DC_Predictor) return Block_Result;

   --  Decode progressive dc first.
   --  @param Bits See package contract for this parameter.
   --  @param DC_Table See package contract for this parameter.
   --  @param Predictor See package contract for this parameter.
   --  @param Al See package contract for this parameter.
   --  @param Block See package contract for this parameter.
   --  @return Operation result.
   function Decode_Progressive_DC_First
     (Bits : in out Bit_Streams.Bit_Reader;
      DC_Table : Huffman.Compiled_Huffman;
      Predictor : in out DC_Predictor;
      Al : Successive_Approximation_Value;
      Block : in out Jpeglib.Coefficients.DCT_Block) return Results.Result;

   --  Decode progressive dc refine.
   --  @param Bits See package contract for this parameter.
   --  @param Al See package contract for this parameter.
   --  @param Block See package contract for this parameter.
   --  @return Operation result.
   function Decode_Progressive_DC_Refine
     (Bits : in out Bit_Streams.Bit_Reader;
      Al : Successive_Approximation_Value;
      Block : in out Jpeglib.Coefficients.DCT_Block) return Results.Result;

   --  Decode progressive ac first.
   --  @param Bits See package contract for this parameter.
   --  @param AC_Table See package contract for this parameter.
   --  @param Ss See package contract for this parameter.
   --  @param Se See package contract for this parameter.
   --  @param Al See package contract for this parameter.
   --  @param Block See package contract for this parameter.
   --  @param EOB_Run See package contract for this parameter.
   --  @return Operation result.
   function Decode_Progressive_AC_First
     (Bits : in out Bit_Streams.Bit_Reader;
      AC_Table : Huffman.Compiled_Huffman;
      Ss : Spectral_Selection_Index;
      Se : Spectral_Selection_Index;
      Al : Successive_Approximation_Value;
      Block : in out Jpeglib.Coefficients.DCT_Block;
      EOB_Run : in out EOB_Run_Count) return Results.Result;

   --  Decode progressive ac refine.
   --  @param Bits See package contract for this parameter.
   --  @param AC_Table See package contract for this parameter.
   --  @param Ss See package contract for this parameter.
   --  @param Se See package contract for this parameter.
   --  @param Al See package contract for this parameter.
   --  @param Block See package contract for this parameter.
   --  @param EOB_Run See package contract for this parameter.
   --  @return Operation result.
   function Decode_Progressive_AC_Refine
     (Bits : in out Bit_Streams.Bit_Reader;
      AC_Table : Huffman.Compiled_Huffman;
      Ss : Spectral_Selection_Index;
      Se : Spectral_Selection_Index;
      Al : Successive_Approximation_Value;
      Block : in out Jpeglib.Coefficients.DCT_Block;
      EOB_Run : in out EOB_Run_Count) return Results.Result;

   --  Encode baseline block.
   --  @param Bits See package contract for this parameter.
   --  @param DC_Table See package contract for this parameter.
   --  @param AC_Table See package contract for this parameter.
   --  @param Predictor See package contract for this parameter.
   --  @param Block See package contract for this parameter.
   --  @return Operation result.
   function Encode_Baseline_Block
     (Bits : in out Bit_Streams.Bit_Writer;
      DC_Table : Huffman.Compiled_Huffman;
      AC_Table : Huffman.Compiled_Huffman;
      Predictor : in out DC_Predictor;
      Block : Jpeglib.Coefficients.DCT_Block) return Results.Result;

   --  Encode lossless difference.
   --  @param Bits See package contract for this parameter.
   --  @param DC_Table See package contract for this parameter.
   --  @param Difference See package contract for this parameter.
   --  @return Operation result.
   function Encode_Lossless_Difference
     (Bits : in out Bit_Streams.Bit_Writer;
      DC_Table : Huffman.Compiled_Huffman;
      Difference : Interfaces.Integer_32) return Results.Result;

   --  Encode progressive dc first block.
   --  @param Bits See package contract for this parameter.
   --  @param DC_Table See package contract for this parameter.
   --  @param Predictor See package contract for this parameter.
   --  @param Block See package contract for this parameter.
   --  @param Al See package contract for this parameter.
   --  @return Operation result.
   function Encode_Progressive_DC_First_Block
     (Bits : in out Bit_Streams.Bit_Writer;
      DC_Table : Huffman.Compiled_Huffman;
      Predictor : in out DC_Predictor;
      Block : Jpeglib.Coefficients.DCT_Block;
      Al : Successive_Approximation_Value := 0) return Results.Result;

   --  Encode progressive dc refine block.
   --  @param Bits See package contract for this parameter.
   --  @param Block See package contract for this parameter.
   --  @param Al See package contract for this parameter.
   --  @return Operation result.
   function Encode_Progressive_DC_Refine_Block
     (Bits : in out Bit_Streams.Bit_Writer;
      Block : Jpeglib.Coefficients.DCT_Block;
      Al : Successive_Approximation_Value := 0) return Results.Result;

   --  Encode progressive ac first block.
   --  @param Bits See package contract for this parameter.
   --  @param AC_Table See package contract for this parameter.
   --  @param Block See package contract for this parameter.
   --  @param Al See package contract for this parameter.
   --  @return Operation result.
   function Encode_Progressive_AC_First_Block
     (Bits : in out Bit_Streams.Bit_Writer;
      AC_Table : Huffman.Compiled_Huffman;
      Block : Jpeglib.Coefficients.DCT_Block;
      Al : Successive_Approximation_Value := 0) return Results.Result;

   --  Encode progressive ac refine block.
   --  @param Bits See package contract for this parameter.
   --  @param AC_Table See package contract for this parameter.
   --  @param Block See package contract for this parameter.
   --  @param Ss See package contract for this parameter.
   --  @param Se See package contract for this parameter.
   --  @param Al See package contract for this parameter.
   --  @return Operation result.
   function Encode_Progressive_AC_Refine_Block
     (Bits : in out Bit_Streams.Bit_Writer;
      AC_Table : Huffman.Compiled_Huffman;
      Block : Jpeglib.Coefficients.DCT_Block;
      Ss : Spectral_Selection_Index := 1;
      Se : Spectral_Selection_Index := 63;
      Al : Successive_Approximation_Value := 0) return Results.Result;

   subtype Block_Array is Jpeglib.Coefficients.DCT_Block_Array;

   type Scan_Result is record
      Outcome : Results.Result := Results.Success;
      Blocks_Decoded : Block_Count := 0;
   end record;

   --  Decode baseline scan.
   --  @param Frame See package contract for this parameter.
   --  @param Scan See package contract for this parameter.
   --  @param Tables See package contract for this parameter.
   --  @param Entropy See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @return Operation result.
   function Decode_Baseline_Scan
     (Frame : Frames.Frame;
      Scan : Scans.Scan;
      Tables : Huffman.Huffman_State;
      Entropy : not null access Bit_Streams.Entropy_Reader;
      Blocks : in out Block_Array;
      Restart : Restart_Interval := 0) return Scan_Result;

   --  Decode baseline scan.
   --  @param Frame See package contract for this parameter.
   --  @param Scan See package contract for this parameter.
   --  @param Tables See package contract for this parameter.
   --  @param Entropy See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Next_Block See package contract for this parameter.
   --  @param Predictors See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @return Operation result.
   function Decode_Baseline_Scan
     (Frame : Frames.Frame;
      Scan : Scans.Scan;
      Tables : Huffman.Huffman_State;
      Entropy : not null access Bit_Streams.Entropy_Reader;
      Blocks : in out Block_Array;
      Next_Block : in out Natural;
      Predictors : in out Predictor_Array;
      Restart : Restart_Interval := 0) return Scan_Result;

   --  Decode arithmetic dc eob scan.
   --  @param Frame See package contract for this parameter.
   --  @param Scan See package contract for this parameter.
   --  @param Tables See package contract for this parameter.
   --  @param Entropy See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Next_Block See package contract for this parameter.
   --  @param Predictors See package contract for this parameter.
   --  @param DC_Bins See package contract for this parameter.
   --  @param AC_Bins See package contract for this parameter.
   --  @param DC_Contexts See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @return Operation result.
   function Decode_Arithmetic_DC_EOB_Scan
     (Frame : Frames.Frame;
      Scan : Scans.Scan;
      Tables : Arithmetic.Arithmetic_State;
      Entropy : not null access Bit_Streams.Entropy_Reader;
      Blocks : in out Block_Array;
      Next_Block : in out Natural;
      Predictors : in out Predictor_Array;
      DC_Bins : in out Arithmetic.Probability_Bin_Array;
      AC_Bins : in out Arithmetic.Probability_Bin_Array;
      DC_Contexts : in out Arithmetic.DC_Context_Array;
     Restart : Restart_Interval := 0) return Scan_Result
     with Pre => DC_Bins'First <= 0 and then DC_Bins'Last >= 48
                 and then AC_Bins'First <= 0 and then AC_Bins'Last >= 0;

   --  Decode arithmetic sequential scan.
   --  @param Frame See package contract for this parameter.
   --  @param Scan See package contract for this parameter.
   --  @param Tables See package contract for this parameter.
   --  @param Entropy See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Next_Block See package contract for this parameter.
   --  @param Predictors See package contract for this parameter.
   --  @param DC_Bins See package contract for this parameter.
   --  @param AC_Bins See package contract for this parameter.
   --  @param Fixed_Bin See package contract for this parameter.
   --  @param DC_Contexts See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @return Operation result.
   function Decode_Arithmetic_Sequential_Scan
     (Frame : Frames.Frame;
      Scan : Scans.Scan;
      Tables : Arithmetic.Arithmetic_State;
      Entropy : not null access Bit_Streams.Entropy_Reader;
      Blocks : in out Block_Array;
      Next_Block : in out Natural;
      Predictors : in out Predictor_Array;
      DC_Bins : in out Arithmetic.Probability_Bin_Array;
      AC_Bins : in out Arithmetic.Probability_Bin_Array;
      Fixed_Bin : in out Arithmetic.Probability_Bin;
      DC_Contexts : in out Arithmetic.DC_Context_Array;
      Restart : Restart_Interval := 0) return Scan_Result
     with Pre => DC_Bins'First <= 0 and then DC_Bins'Last >= 48
                 and then AC_Bins'First <= 0 and then AC_Bins'Last >= 245;

   --  Decode arithmetic progressive scan.
   --  @param Frame See package contract for this parameter.
   --  @param Scan See package contract for this parameter.
   --  @param Tables See package contract for this parameter.
   --  @param Entropy See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Decoded_Coefficients See package contract for this parameter.
   --  @param Predictors See package contract for this parameter.
   --  @param DC_Bins See package contract for this parameter.
   --  @param AC_Bins See package contract for this parameter.
   --  @param DC_Contexts See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @return Operation result.
   function Decode_Arithmetic_Progressive_Scan
     (Frame : Frames.Frame;
      Scan : Scans.Scan;
      Tables : Arithmetic.Arithmetic_State;
      Entropy : not null access Bit_Streams.Entropy_Reader;
      Blocks : in out Block_Array;
      Decoded_Coefficients : in out Arithmetic.Decoded_Coefficient_Map;
      Predictors : in out Predictor_Array;
      DC_Bins : in out Arithmetic.Probability_Bin_Array;
      AC_Bins : in out Arithmetic.Probability_Bin_Array;
      DC_Contexts : in out Arithmetic.DC_Context_Array;
     Restart : Restart_Interval := 0) return Scan_Result
     with Pre => DC_Bins'First <= 0 and then DC_Bins'Last >= 48
                 and then AC_Bins'First <= 0 and then AC_Bins'Last >= 245;

   --  Decode progressive scan.
   --  @param Frame See package contract for this parameter.
   --  @param Scan See package contract for this parameter.
   --  @param Tables See package contract for this parameter.
   --  @param Entropy See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @return Operation result.
   function Decode_Progressive_Scan
     (Frame : Frames.Frame;
      Scan : Scans.Scan;
      Tables : Huffman.Huffman_State;
      Entropy : not null access Bit_Streams.Entropy_Reader;
      Blocks : in out Block_Array;
      Restart : Restart_Interval := 0) return Scan_Result;

   --  Decode progressive scan.
   --  @param Frame See package contract for this parameter.
   --  @param Scan See package contract for this parameter.
   --  @param Tables See package contract for this parameter.
   --  @param Entropy See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param State See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @return Operation result.
   function Decode_Progressive_Scan
     (Frame : Frames.Frame;
      Scan : Scans.Scan;
      Tables : Huffman.Huffman_State;
      Entropy : not null access Bit_Streams.Entropy_Reader;
      Blocks : in out Block_Array;
      State : in out Progressive.Scan_State;
      Restart : Restart_Interval := 0) return Scan_Result;

   --  Encode baseline scan.
   --  @param Frame See package contract for this parameter.
   --  @param Scan See package contract for this parameter.
   --  @param Tables See package contract for this parameter.
   --  @param Bits See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @return Operation result.
   function Encode_Baseline_Scan
     (Frame : Frames.Frame;
      Scan : Scans.Scan;
      Tables : Huffman.Huffman_State;
      Bits : in out Bit_Streams.Bit_Writer;
      Blocks : Block_Array;
      Restart : Restart_Interval := 0) return Scan_Result;
end Jpeglib.Internal.Coefficients;

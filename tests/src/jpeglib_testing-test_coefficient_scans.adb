with AUnit.Assertions;

with Jpeglib;
with Jpeglib.Coefficients;
with Jpeglib.Errors;
with Jpeglib.Internal.Bit_Streams;
with Jpeglib.Internal.Coefficients;
with Jpeglib.Internal.Decoder;
with Jpeglib.Internal.Frames;
with Jpeglib.Internal.Huffman;
with Jpeglib.Internal.Markers;
with Jpeglib.Internal.Progressive;
with Jpeglib.Internal.Scans;
with Jpeglib.Internal.Segments;
with Jpeglib.Results;
with Jpeglib.Streams;

package body Jpeglib_Testing.Test_Coefficient_Scans is
   use AUnit.Assertions;
   use type Jpeglib.Byte;
   use type Jpeglib.Block_Count;
   use type Jpeglib.Component_Index;
   use type Jpeglib.Destination_Offset;
   use type Jpeglib.Errors.Error_Code;
   use type Jpeglib.Frame_Mode;
   use type Jpeglib.Marker_Code;
   use type Jpeglib.Restart_Interval;
   use type Jpeglib.Coefficients.DCT_Block;
   use type Jpeglib.Coefficients.DCT_Block_Array;
   use type Jpeglib.Coefficients.Quantized_Coefficient;
   use type Jpeglib.Internal.Coefficients.DC_Predictor;
   use type Jpeglib.Internal.Coefficients.EOB_Run_Count;
   use type Jpeglib.Streams.Byte_Array;

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

   Bit_Storage : aliased constant Jpeglib.Streams.Byte_Array := [16#A0#];

   Block_AC_Run_Storage : aliased constant Jpeglib.Streams.Byte_Array := [16#54#];

   Block_DC_EOB_Storage : aliased constant Jpeglib.Streams.Byte_Array := [16#40#];

   Block_ZRL_Overflow_Storage : aliased constant Jpeglib.Streams.Byte_Array := [0, 0, 0, 0, 0, 0, 0, 0, 0];

   DHT_AC_EOB_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 20, 16#10#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0];

   DHT_AC_Run2_Size1_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 21, 16#10#,
      1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 16#21#];

   DHT_AC_Size1_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 21, 16#10#,
      1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 16#01#];

   DHT_AC_ZRL_Only_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 20, 16#10#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      16#F0#];

   DHT_DC_Category2_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2];

   Duplicate_Color_Separate_Scan_Coefficient_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
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
      16#FF#, 16#DA#,
      0, 8,
      1,
      2, 16#11#,
      0, 63, 0,
      16#44#,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 63, 0,
      16#44#, 16#44#, 16#44#,
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

   Full_Color_Separate_Scan_Coefficient_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
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

   Gray_Two_Block_Entropy_Storage : aliased constant Jpeglib.Streams.Byte_Array := [16#44#];

   Huffman_Bit_Storage : aliased constant Jpeglib.Streams.Byte_Array := [16#40#];

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

   Missing_Gray_Restart_Coefficient_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
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
      16#40#,
      16#FF#, 16#D9#];

   Progressive_AC_Refine_Add_Storage : aliased constant Jpeglib.Streams.Byte_Array := [16#90#];

   Progressive_Gray_Coefficient_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#C2#,
      0, 11,
      8, 0, 8, 0, 8, 1,
      1, 16#11#, 0,
      16#FF#, 16#C4#,
      0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 0, 0,
      16#40#,
      16#FF#, 16#D9#];

   Progressive_Gray_Multi_Scan_Coefficient_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#C2#,
      0, 11,
      8, 0, 8, 0, 8, 1,
      1, 16#11#, 0,
      16#FF#, 16#C4#,
      0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 0, 0,
      16#40#,
      16#FF#, 16#C4#,
      0, 21, 16#10#,
      1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 16#21#,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      1, 5, 1,
      16#A0#,
      16#FF#, 16#D9#];

   Progressive_Gray_Restart_Coefficient_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#DD#, 0, 4, 0, 1,
      16#FF#, 16#C2#,
      0, 11,
      8, 0, 8, 0, 16, 1,
      1, 16#11#, 0,
      16#FF#, 16#C4#,
      0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 0, 0,
      16#4F#,
      16#FF#, 16#D0#,
      16#40#,
      16#FF#, 16#D9#];

   Progressive_YCbCr_Interleaved_Coefficient_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#C2#,
      0, 17,
      8, 0, 8, 0, 16, 3,
      1, 16#11#, 0,
      2, 16#11#, 0,
      3, 16#11#, 0,
      16#FF#, 16#C4#,
      0, 21, 0,
      2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 2,
      16#FF#, 16#DA#,
      0, 12,
      3,
      1, 16#00#,
      2, 16#00#,
      3, 16#00#,
      0, 0, 0,
      16#C3#, 16#00#,
      16#FF#, 16#D9#];

   SOF0_Gray_16x8_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 11,
      8, 0, 8, 0, 16, 1,
      1, 16#11#, 0];

   SOF0_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 17,
      8, 0, 9, 0, 17, 3,
      1, 16#22#, 0,
      2, 16#11#, 1,
      3, 16#11#, 1];

   SOF2_Gray_8x8_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 11,
      8, 0, 8, 0, 8, 1,
      1, 16#11#, 0];

   SOS_All_Luma_Tables_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 12,
      3,
      1, 16#00#,
      2, 16#00#,
      3, 16#00#,
      0, 63, 0];

   SOS_Gray_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 8,
      1,
      1, 16#00#,
      0, 63, 0];

   SOS_Progressive_AC_First_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 8,
      1,
      1, 16#00#,
      1, 5, 1];

   SOS_Progressive_AC_Refine_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 8,
      1,
      1, 16#00#,
      1, 5, 16#10#];

   SOS_Progressive_Gray_DC_First_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 8,
      1,
      1, 16#00#,
      0, 0, 0];

   SOS_Progressive_Gray_DC_Refine_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 8,
      1,
      1, 16#00#,
      0, 0, 16#10#];


   procedure Baseline_Block_Decodes_DC_EOB (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Baseline_Block_Decodes_AC_Run_Size (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Baseline_Block_Rejects_Run_Overflow (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Progressive_DC_First_Decodes_Shifted_Value (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Progressive_DC_Refine_Updates_Signed_Value (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Progressive_AC_First_Decodes_Run_And_Value (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Progressive_AC_Refine_Adds_And_Updates_Coefficients (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Progressive_AC_Refine_EOB_Updates_Existing (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Baseline_Block_Encodes_DC_EOB (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Baseline_Block_Encodes_AC_Run_Size (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Baseline_Block_Encode_Rejects_Missing_AC_Symbol (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Baseline_Scan_Decodes_Grayscale_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Baseline_Scan_Rejects_Missing_Huffman_Table (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Baseline_Scan_Encodes_Grayscale_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Baseline_Scan_Encodes_Restarted_Grayscale_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Baseline_Scan_Encodes_Interleaved_Color_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Baseline_Scan_Encodes_Restarted_Color_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Baseline_Scan_Encode_Rejects_Missing_Huffman_Table (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Progressive_Scan_Decodes_DC_First (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Progressive_Scan_Decodes_DC_Refine (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Progressive_Scan_Decodes_AC_First (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Progressive_Scan_State_Accepts_Sequence (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Progressive_Scan_State_Rejects_Refine_First (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Decoder_Decodes_Baseline_Coefficients (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Decoder_Rejects_Too_Few_Coefficient_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Decoder_Decodes_Restarted_Coefficients (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Decoder_Rejects_Wrong_Restart_Marker (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Decoder_Rejects_Missing_Restart_Marker (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Decoder_Decodes_Interleaved_Color_Coefficients (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Decoder_Decodes_Separate_Color_Scans (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Decoder_Rejects_Incomplete_Color_Scans (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Decoder_Rejects_Duplicate_Color_Scans (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Decoder_Decodes_Progressive_Coefficients (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Decoder_Decodes_Progressive_Multi_Scan_Coefficients (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Decoder_Decodes_Progressive_Restarted_Coefficients
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Decoder_Decodes_Progressive_Interleaved_Color_Coefficients
     (T : in out AUnit.Test_Cases.Test_Case'Class);


   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("coefficient_scans");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Baseline_Block_Decodes_DC_EOB'Access, "foundation.coefficients.block_dc_eob");

      Register_Routine (T, Baseline_Block_Decodes_AC_Run_Size'Access, "foundation.coefficients.block_ac_run");

      Register_Routine (T, Baseline_Block_Rejects_Run_Overflow'Access, "foundation.coefficients.block_run_overflow");

      Register_Routine
        (T,
         Progressive_DC_First_Decodes_Shifted_Value'Access,
         "foundation.coefficients.progressive_dc_first");

      Register_Routine
        (T,
         Progressive_DC_Refine_Updates_Signed_Value'Access,
         "foundation.coefficients.progressive_dc_refine");

      Register_Routine
        (T,
         Progressive_AC_First_Decodes_Run_And_Value'Access,
         "foundation.coefficients.progressive_ac_first");

      Register_Routine
        (T,
         Progressive_AC_Refine_Adds_And_Updates_Coefficients'Access,
         "foundation.coefficients.progressive_ac_refine_add");

      Register_Routine
        (T,
         Progressive_AC_Refine_EOB_Updates_Existing'Access,
         "foundation.coefficients.progressive_ac_refine_eob");

      Register_Routine (T, Baseline_Block_Encodes_DC_EOB'Access, "foundation.coefficients.encode_block_dc_eob");

      Register_Routine (T, Baseline_Block_Encodes_AC_Run_Size'Access, "foundation.coefficients.encode_block_ac_run");

      Register_Routine
        (T,
         Baseline_Block_Encode_Rejects_Missing_AC_Symbol'Access,
         "foundation.coefficients.encode_block_missing_ac");

      Register_Routine (T, Baseline_Scan_Decodes_Grayscale_Blocks'Access, "foundation.coefficients.scan_gray");

      Register_Routine
        (T,
         Baseline_Scan_Rejects_Missing_Huffman_Table'Access,
         "foundation.coefficients.scan_missing_huffman");

      Register_Routine (T, Baseline_Scan_Encodes_Grayscale_Blocks'Access, "foundation.coefficients.encode_scan_gray");

      Register_Routine
        (T,
         Baseline_Scan_Encodes_Restarted_Grayscale_Blocks'Access,
         "foundation.coefficients.encode_scan_gray_restart");

      Register_Routine
        (T,
         Baseline_Scan_Encodes_Interleaved_Color_Blocks'Access,
         "foundation.coefficients.encode_scan_color_interleaved");

      Register_Routine
        (T,
         Baseline_Scan_Encodes_Restarted_Color_Blocks'Access,
         "foundation.coefficients.encode_scan_color_restart");

      Register_Routine
        (T,
         Baseline_Scan_Encode_Rejects_Missing_Huffman_Table'Access,
         "foundation.coefficients.encode_scan_missing_huffman");

      Register_Routine
        (T,
         Progressive_Scan_Decodes_DC_First'Access,
         "foundation.coefficients.progressive_scan_dc_first");

      Register_Routine
        (T,
         Progressive_Scan_Decodes_DC_Refine'Access,
         "foundation.coefficients.progressive_scan_dc_refine");

      Register_Routine
        (T,
         Progressive_Scan_Decodes_AC_First'Access,
         "foundation.coefficients.progressive_scan_ac_first");

      Register_Routine
        (T,
         Progressive_Scan_State_Accepts_Sequence'Access,
         "foundation.coefficients.progressive_scan_state_sequence");

      Register_Routine
        (T,
         Progressive_Scan_State_Rejects_Refine_First'Access,
         "foundation.coefficients.progressive_scan_state_refine_first");

      Register_Routine
        (T,
         Decoder_Decodes_Baseline_Coefficients'Access,
         "foundation.decoder.coefficients_baseline");

      Register_Routine
        (T,
         Decoder_Rejects_Too_Few_Coefficient_Blocks'Access,
         "foundation.decoder.coefficients_small_output");

      Register_Routine
        (T,
         Decoder_Decodes_Restarted_Coefficients'Access,
         "foundation.decoder.coefficients_restart");

      Register_Routine
        (T,
         Decoder_Rejects_Wrong_Restart_Marker'Access,
         "foundation.decoder.coefficients_restart_wrong_marker");

      Register_Routine
        (T,
         Decoder_Rejects_Missing_Restart_Marker'Access,
         "foundation.decoder.coefficients_restart_missing_marker");

      Register_Routine
        (T,
         Decoder_Decodes_Interleaved_Color_Coefficients'Access,
         "foundation.decoder.coefficients_interleaved_color");

      Register_Routine
        (T,
         Decoder_Decodes_Separate_Color_Scans'Access,
         "foundation.decoder.coefficients_separate_color_scans");

      Register_Routine
        (T,
         Decoder_Rejects_Incomplete_Color_Scans'Access,
         "foundation.decoder.coefficients_incomplete_color_scans");

      Register_Routine
        (T,
         Decoder_Rejects_Duplicate_Color_Scans'Access,
         "foundation.decoder.coefficients_duplicate_color_scans");

      Register_Routine
        (T,
         Decoder_Decodes_Progressive_Coefficients'Access,
         "foundation.decoder.coefficients_progressive");

      Register_Routine
        (T,
         Decoder_Decodes_Progressive_Multi_Scan_Coefficients'Access,
         "foundation.decoder.coefficients_progressive_multi_scan");

      Register_Routine
        (T,
         Decoder_Decodes_Progressive_Restarted_Coefficients'Access,
         "foundation.decoder.coefficients_progressive_restart");

      Register_Routine
        (T,
         Decoder_Decodes_Progressive_Interleaved_Color_Coefficients'Access,
         "foundation.decoder.coefficients_progressive_interleaved_color");

   end Register_Tests;

   function Compile_Test_Huffman
     (Storage : not null Jpeglib.Streams.Const_Byte_Array_Access;
      Class : Jpeglib.Internal.Huffman.Huffman_Class) return Jpeglib.Internal.Huffman.Compiled_Huffman
   is
      Source : aliased Jpeglib.Streams.Memory_Source;
      State : Jpeglib.Internal.Huffman.Huffman_State;
   begin
      Jpeglib.Streams.Open (Source, Storage);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.DHT, 150);
         Parse_Outcome : constant Jpeglib.Results.Result := Jpeglib.Internal.Huffman.Parse_DHT (State, Segment);
         Definition : Jpeglib.Internal.Huffman.Huffman_Definition;
         Compiled : Jpeglib.Internal.Huffman.Compile_Result;
      begin
         Assert (Jpeglib.Results.Succeeded (Parse_Outcome), "test DHT parse failed");
         Definition := Jpeglib.Internal.Huffman.Definition (State, Class, 0);
         Compiled := Jpeglib.Internal.Huffman.Compile (Definition);
         Assert (Jpeglib.Results.Succeeded (Compiled.Outcome), "test Huffman compile failed");
         return Compiled.Table;
      end;
   end Compile_Test_Huffman;

   function Gray_Frame_16x8 return Jpeglib.Internal.Frames.Frame is
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOF0_Gray_16x8_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOF0, 160);
      begin
         return Jpeglib.Internal.Frames.Parse_SOF (Segment, Jpeglib.Baseline_DCT);
      end;
   end Gray_Frame_16x8;

   function Color_Frame_17x9 return Jpeglib.Internal.Frames.Frame is
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOF0_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOF0, 165);
      begin
         return Jpeglib.Internal.Frames.Parse_SOF (Segment, Jpeglib.Baseline_DCT);
      end;
   end Color_Frame_17x9;

   function Gray_Scan (Frame : Jpeglib.Internal.Frames.Frame) return Jpeglib.Internal.Scans.Scan is
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOS_Gray_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOS, 170);
      begin
         return Jpeglib.Internal.Scans.Parse_SOS (Frame, Segment, Progressive => False);
      end;
   end Gray_Scan;

   function Color_Scan_All_Luma_Tables
     (Frame : Jpeglib.Internal.Frames.Frame) return Jpeglib.Internal.Scans.Scan
   is
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOS_All_Luma_Tables_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOS, 175);
      begin
         return Jpeglib.Internal.Scans.Parse_SOS (Frame, Segment, Progressive => False);
      end;
   end Color_Scan_All_Luma_Tables;

   function Tiny_Block_Huffman_State return Jpeglib.Internal.Huffman.Huffman_State is
      DC_Source : aliased Jpeglib.Streams.Memory_Source;
      AC_Source : aliased Jpeglib.Streams.Memory_Source;
      State : Jpeglib.Internal.Huffman.Huffman_State;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (DC_Source, DHT_DC_Category2_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (DC_Source'Access, Jpeglib.Internal.Markers.DHT, 180);
      begin
         Outcome := Jpeglib.Internal.Huffman.Parse_DHT (State, Segment);
         Assert (Jpeglib.Results.Succeeded (Outcome), "DC DHT parse failed for scan test");
      end;

      Jpeglib.Streams.Open (AC_Source, DHT_AC_EOB_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (AC_Source'Access, Jpeglib.Internal.Markers.DHT, 181);
      begin
         Outcome := Jpeglib.Internal.Huffman.Parse_DHT (State, Segment);
         Assert (Jpeglib.Results.Succeeded (Outcome), "AC DHT parse failed for scan test");
      end;

      return State;
   end Tiny_Block_Huffman_State;

   function Tiny_Progressive_AC_Huffman_State return Jpeglib.Internal.Huffman.Huffman_State is
      DC_Source : aliased Jpeglib.Streams.Memory_Source;
      AC_Source : aliased Jpeglib.Streams.Memory_Source;
      State : Jpeglib.Internal.Huffman.Huffman_State;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (DC_Source, DHT_DC_Category2_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (DC_Source'Access, Jpeglib.Internal.Markers.DHT, 182);
      begin
         Outcome := Jpeglib.Internal.Huffman.Parse_DHT (State, Segment);
         Assert (Jpeglib.Results.Succeeded (Outcome), "DC DHT parse failed for progressive scan test");
      end;

      Jpeglib.Streams.Open (AC_Source, DHT_AC_Run2_Size1_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (AC_Source'Access, Jpeglib.Internal.Markers.DHT, 183);
      begin
         Outcome := Jpeglib.Internal.Huffman.Parse_DHT (State, Segment);
         Assert (Jpeglib.Results.Succeeded (Outcome), "AC DHT parse failed for progressive scan test");
      end;

      return State;
   end Tiny_Progressive_AC_Huffman_State;

   function Tiny_Progressive_AC_Refine_Huffman_State return Jpeglib.Internal.Huffman.Huffman_State is
      DC_Source : aliased Jpeglib.Streams.Memory_Source;
      AC_Source : aliased Jpeglib.Streams.Memory_Source;
      State : Jpeglib.Internal.Huffman.Huffman_State;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (DC_Source, DHT_DC_Category2_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (DC_Source'Access, Jpeglib.Internal.Markers.DHT, 184);
      begin
         Outcome := Jpeglib.Internal.Huffman.Parse_DHT (State, Segment);
         Assert (Jpeglib.Results.Succeeded (Outcome), "DC DHT parse failed for progressive refine test");
      end;

      Jpeglib.Streams.Open (AC_Source, DHT_AC_Size1_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (AC_Source'Access, Jpeglib.Internal.Markers.DHT, 185);
      begin
         Outcome := Jpeglib.Internal.Huffman.Parse_DHT (State, Segment);
         Assert (Jpeglib.Results.Succeeded (Outcome), "AC DHT parse failed for progressive refine test");
      end;

      return State;
   end Tiny_Progressive_AC_Refine_Huffman_State;

   function Progressive_Gray_Frame_8x8 return Jpeglib.Internal.Frames.Frame is
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOF2_Gray_8x8_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOF2, 95);
      begin
         return Jpeglib.Internal.Frames.Parse_SOF (Segment, Jpeglib.Progressive_DCT);
      end;
   end Progressive_Gray_Frame_8x8;

   function Progressive_Gray_DC_First_Scan
     (Frame : Jpeglib.Internal.Frames.Frame) return Jpeglib.Internal.Scans.Scan
   is
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOS_Progressive_Gray_DC_First_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOS, 96);
      begin
         return Jpeglib.Internal.Scans.Parse_SOS (Frame, Segment, Progressive => True);
      end;
   end Progressive_Gray_DC_First_Scan;

   function Progressive_Gray_DC_Refine_Scan
     (Frame : Jpeglib.Internal.Frames.Frame) return Jpeglib.Internal.Scans.Scan
   is
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOS_Progressive_Gray_DC_Refine_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOS, 97);
      begin
         return Jpeglib.Internal.Scans.Parse_SOS (Frame, Segment, Progressive => True);
      end;
   end Progressive_Gray_DC_Refine_Scan;

   function Progressive_AC_First_Scan
     (Frame : Jpeglib.Internal.Frames.Frame) return Jpeglib.Internal.Scans.Scan
   is
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOS_Progressive_AC_First_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOS, 93);
      begin
         return Jpeglib.Internal.Scans.Parse_SOS (Frame, Segment, Progressive => True);
      end;
   end Progressive_AC_First_Scan;

   function Progressive_AC_Refine_Scan
     (Frame : Jpeglib.Internal.Frames.Frame) return Jpeglib.Internal.Scans.Scan
   is
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOS_Progressive_AC_Refine_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOS, 94);
      begin
         return Jpeglib.Internal.Scans.Parse_SOS (Frame, Segment, Progressive => True);
      end;
   end Progressive_AC_Refine_Scan;

   procedure Baseline_Block_Decodes_DC_EOB (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      DC : constant Jpeglib.Internal.Huffman.Compiled_Huffman :=
        Compile_Test_Huffman (DHT_DC_Category2_Storage'Access, Jpeglib.Internal.Huffman.DC);
      AC : constant Jpeglib.Internal.Huffman.Compiled_Huffman :=
        Compile_Test_Huffman (DHT_AC_EOB_Storage'Access, Jpeglib.Internal.Huffman.AC);
      Predictor : Jpeglib.Internal.Coefficients.DC_Predictor := 0;
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, Block_DC_EOB_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Reader (Entropy'Access);
         Result : constant Jpeglib.Internal.Coefficients.Block_Result :=
           Jpeglib.Internal.Coefficients.Decode_Baseline_Block (Bits, DC, AC, Predictor);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "baseline block decode failed");
         Assert (Predictor = 2, "DC predictor mismatch");
         Assert (Result.Block (0) = 2, "DC coefficient mismatch");
         for Index in Jpeglib.Coefficient_Index range 1 .. 63 loop
            Assert (Result.Block (Index) = 0, "nonzero coefficient after EOB");
         end loop;
      end;
   end Baseline_Block_Decodes_DC_EOB;

   procedure Baseline_Block_Decodes_AC_Run_Size (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      DC : constant Jpeglib.Internal.Huffman.Compiled_Huffman :=
        Compile_Test_Huffman (DHT_DC_Category2_Storage'Access, Jpeglib.Internal.Huffman.DC);
      AC : constant Jpeglib.Internal.Huffman.Compiled_Huffman :=
        Compile_Test_Huffman (DHT_AC_Run2_Size1_Storage'Access, Jpeglib.Internal.Huffman.AC);
      Predictor : Jpeglib.Internal.Coefficients.DC_Predictor := 5;
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, Block_AC_Run_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Reader (Entropy'Access);
         Result : constant Jpeglib.Internal.Coefficients.Block_Result :=
           Jpeglib.Internal.Coefficients.Decode_Baseline_Block (Bits, DC, AC, Predictor);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "AC run block decode failed");
         Assert (Predictor = 7, "updated predictor mismatch");
         Assert (Result.Block (0) = 7, "updated DC coefficient mismatch");
         Assert (Result.Block (16) = 1, "AC run/size coefficient not placed in natural order");
      end;
   end Baseline_Block_Decodes_AC_Run_Size;

   procedure Baseline_Block_Rejects_Run_Overflow (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      DC : constant Jpeglib.Internal.Huffman.Compiled_Huffman :=
        Compile_Test_Huffman (DHT_DC_Category2_Storage'Access, Jpeglib.Internal.Huffman.DC);
      AC : constant Jpeglib.Internal.Huffman.Compiled_Huffman :=
        Compile_Test_Huffman (DHT_AC_ZRL_Only_Storage'Access, Jpeglib.Internal.Huffman.AC);
      Predictor : Jpeglib.Internal.Coefficients.DC_Predictor := 0;
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, Block_ZRL_Overflow_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Reader (Entropy'Access);
         Result : constant Jpeglib.Internal.Coefficients.Block_Result :=
           Jpeglib.Internal.Coefficients.Decode_Baseline_Block (Bits, DC, AC, Predictor);
      begin
         Assert (not Jpeglib.Results.Succeeded (Result.Outcome), "ZRL overflow was accepted");
         Assert
           (Result.Outcome.First_Error.Code = Jpeglib.Errors.Coefficient_Invalid_Encoding,
           "ZRL overflow used wrong error");
      end;
   end Baseline_Block_Rejects_Run_Overflow;

   procedure Progressive_DC_First_Decodes_Shifted_Value (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      DC : constant Jpeglib.Internal.Huffman.Compiled_Huffman :=
        Compile_Test_Huffman (DHT_DC_Category2_Storage'Access, Jpeglib.Internal.Huffman.DC);
      Predictor : Jpeglib.Internal.Coefficients.DC_Predictor := 0;
      Block : Jpeglib.Coefficients.DCT_Block := [others => 0];
      Source : aliased Jpeglib.Streams.Memory_Source;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Source, Block_DC_EOB_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Reader (Entropy'Access);
      begin
         Outcome := Jpeglib.Internal.Coefficients.Decode_Progressive_DC_First (Bits, DC, Predictor, 2, Block);
      end;

      Assert (Jpeglib.Results.Succeeded (Outcome), "progressive DC first decode failed");
      Assert (Predictor = 2, "progressive DC first predictor mismatch");
      Assert (Block (0) = 8, "progressive DC first did not shift by Al");
      for Index in Jpeglib.Coefficient_Index range 1 .. 63 loop
         Assert (Block (Index) = 0, "progressive DC first touched AC coefficient");
      end loop;
   end Progressive_DC_First_Decodes_Shifted_Value;

   procedure Progressive_DC_Refine_Updates_Signed_Value (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Positive_Block : Jpeglib.Coefficients.DCT_Block := [0 => 8, others => 0];
      Negative_Block : Jpeglib.Coefficients.DCT_Block := [0 => -8, others => 0];
      Positive_Source : aliased Jpeglib.Streams.Memory_Source;
      Negative_Source : aliased Jpeglib.Streams.Memory_Source;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Positive_Source, Bit_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Positive_Source'Access);
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Reader (Entropy'Access);
      begin
         Outcome := Jpeglib.Internal.Coefficients.Decode_Progressive_DC_Refine (Bits, 1, Positive_Block);
      end;

      Assert (Jpeglib.Results.Succeeded (Outcome), "positive progressive DC refine failed");
      Assert (Positive_Block (0) = 10, "positive progressive DC refine mismatch");

      Jpeglib.Streams.Open (Negative_Source, Bit_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Negative_Source'Access);
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Reader (Entropy'Access);
      begin
         Outcome := Jpeglib.Internal.Coefficients.Decode_Progressive_DC_Refine (Bits, 1, Negative_Block);
      end;

      Assert (Jpeglib.Results.Succeeded (Outcome), "negative progressive DC refine failed");
      Assert (Negative_Block (0) = -10, "negative progressive DC refine mismatch");
   end Progressive_DC_Refine_Updates_Signed_Value;

   procedure Progressive_AC_First_Decodes_Run_And_Value (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      AC : constant Jpeglib.Internal.Huffman.Compiled_Huffman :=
        Compile_Test_Huffman (DHT_AC_Run2_Size1_Storage'Access, Jpeglib.Internal.Huffman.AC);
      Block : Jpeglib.Coefficients.DCT_Block := [others => 0];
      EOB_Run : Jpeglib.Internal.Coefficients.EOB_Run_Count := 0;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Source, Bit_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Reader (Entropy'Access);
      begin
         Outcome :=
           Jpeglib.Internal.Coefficients.Decode_Progressive_AC_First
             (Bits, AC, 1, 5, 1, Block, EOB_Run);
      end;

      Assert (Jpeglib.Results.Succeeded (Outcome), "progressive AC first decode failed");
      Assert (Block (16) = 2, "progressive AC first run/value mismatch");
      Assert (EOB_Run = 0, "progressive AC first EOB run mismatch");
   end Progressive_AC_First_Decodes_Run_And_Value;

   procedure Progressive_AC_Refine_Adds_And_Updates_Coefficients (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      AC : constant Jpeglib.Internal.Huffman.Compiled_Huffman :=
        Compile_Test_Huffman (DHT_AC_Size1_Storage'Access, Jpeglib.Internal.Huffman.AC);
      Block : Jpeglib.Coefficients.DCT_Block := [1 => 2, others => 0];
      EOB_Run : Jpeglib.Internal.Coefficients.EOB_Run_Count := 0;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Source, Progressive_AC_Refine_Add_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Reader (Entropy'Access);
      begin
         Outcome :=
           Jpeglib.Internal.Coefficients.Decode_Progressive_AC_Refine
             (Bits, AC, 1, 3, 0, Block, EOB_Run);
      end;

      Assert (Jpeglib.Results.Succeeded (Outcome), "progressive AC refine add failed");
      Assert (Block (1) = 3, "progressive AC refine existing coefficient mismatch");
      Assert (Block (8) = -1, "progressive AC refine new coefficient mismatch");
      Assert (EOB_Run = 0, "progressive AC refine add EOB run mismatch");
   end Progressive_AC_Refine_Adds_And_Updates_Coefficients;

   procedure Progressive_AC_Refine_EOB_Updates_Existing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      AC : constant Jpeglib.Internal.Huffman.Compiled_Huffman :=
        Compile_Test_Huffman (DHT_AC_EOB_Storage'Access, Jpeglib.Internal.Huffman.AC);
      Block : Jpeglib.Coefficients.DCT_Block := [1 => -2, others => 0];
      EOB_Run : Jpeglib.Internal.Coefficients.EOB_Run_Count := 0;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Source, Huffman_Bit_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Reader (Entropy'Access);
      begin
         Outcome :=
           Jpeglib.Internal.Coefficients.Decode_Progressive_AC_Refine
             (Bits, AC, 1, 3, 0, Block, EOB_Run);
      end;

      Assert (Jpeglib.Results.Succeeded (Outcome), "progressive AC refine EOB failed");
      Assert (Block (1) = -3, "progressive AC refine EOB existing coefficient mismatch");
      Assert (EOB_Run = 0, "progressive AC refine EOB run mismatch");
   end Progressive_AC_Refine_EOB_Updates_Existing;

   procedure Baseline_Block_Encodes_DC_EOB (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      DC : constant Jpeglib.Internal.Huffman.Compiled_Huffman :=
        Compile_Test_Huffman (DHT_DC_Category2_Storage'Access, Jpeglib.Internal.Huffman.DC);
      AC : constant Jpeglib.Internal.Huffman.Compiled_Huffman :=
        Compile_Test_Huffman (DHT_AC_EOB_Storage'Access, Jpeglib.Internal.Huffman.AC);
      Predictor : Jpeglib.Internal.Coefficients.DC_Predictor := 0;
      Block : Jpeglib.Coefficients.DCT_Block := [others => 0];
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 2 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Block (0) := 2;
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      declare
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Writer (Destination'Access);
      begin
         Outcome := Jpeglib.Internal.Coefficients.Encode_Baseline_Block (Bits, DC, AC, Predictor, Block);
         Assert (Jpeglib.Results.Succeeded (Outcome), "DC/EOB block encode failed");
         Outcome := Jpeglib.Internal.Bit_Streams.Flush_Byte (Bits);
         Assert (Jpeglib.Results.Succeeded (Outcome), "DC/EOB block flush failed");
      end;
      Assert (Predictor = 2, "encoded DC predictor mismatch");
      Assert (Storage (1) = 16#4F#, "encoded DC/EOB block byte mismatch");
      Assert (Jpeglib.Streams.Offset (Destination) = 1, "encoded DC/EOB block length mismatch");
   end Baseline_Block_Encodes_DC_EOB;

   procedure Baseline_Block_Encodes_AC_Run_Size (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      DC : constant Jpeglib.Internal.Huffman.Compiled_Huffman :=
        Compile_Test_Huffman (DHT_DC_Category2_Storage'Access, Jpeglib.Internal.Huffman.DC);
      AC : constant Jpeglib.Internal.Huffman.Compiled_Huffman :=
        Compile_Test_Huffman (DHT_AC_Run2_Size1_Storage'Access, Jpeglib.Internal.Huffman.AC);
      Predictor : Jpeglib.Internal.Coefficients.DC_Predictor := 5;
      Block : Jpeglib.Coefficients.DCT_Block := [others => 0];
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 2 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Block (0) := 7;
      Block (16) := 1;
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      declare
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Writer (Destination'Access);
      begin
         Outcome := Jpeglib.Internal.Coefficients.Encode_Baseline_Block (Bits, DC, AC, Predictor, Block);
         Assert (Jpeglib.Results.Succeeded (Outcome), "AC run block encode failed");
         Outcome := Jpeglib.Internal.Bit_Streams.Flush_Byte (Bits);
         Assert (Jpeglib.Results.Succeeded (Outcome), "AC run block flush failed");
      end;
      Assert (Predictor = 7, "encoded AC run predictor mismatch");
      Assert (Storage (1) = 16#55#, "encoded AC run block byte mismatch");
      Assert (Jpeglib.Streams.Offset (Destination) = 1, "encoded AC run block length mismatch");
   end Baseline_Block_Encodes_AC_Run_Size;

   procedure Baseline_Block_Encode_Rejects_Missing_AC_Symbol (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      DC : constant Jpeglib.Internal.Huffman.Compiled_Huffman :=
        Compile_Test_Huffman (DHT_DC_Category2_Storage'Access, Jpeglib.Internal.Huffman.DC);
      AC : constant Jpeglib.Internal.Huffman.Compiled_Huffman :=
        Compile_Test_Huffman (DHT_AC_EOB_Storage'Access, Jpeglib.Internal.Huffman.AC);
      Predictor : Jpeglib.Internal.Coefficients.DC_Predictor := 5;
      Block : Jpeglib.Coefficients.DCT_Block := [others => 0];
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 4 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Block (0) := 7;
      Block (16) := 1;
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      declare
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Writer (Destination'Access);
      begin
         Outcome := Jpeglib.Internal.Coefficients.Encode_Baseline_Block (Bits, DC, AC, Predictor, Block);
      end;
      Assert (not Jpeglib.Results.Succeeded (Outcome), "missing AC symbol block was encoded");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Huffman_Invalid_Definition,
         "missing AC symbol block used wrong error");
   end Baseline_Block_Encode_Rejects_Missing_AC_Symbol;

   procedure Baseline_Scan_Decodes_Grayscale_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Gray_Frame_16x8;
      Scan : constant Jpeglib.Internal.Scans.Scan := Gray_Scan (Frame);
      Tables : constant Jpeglib.Internal.Huffman.Huffman_State := Tiny_Block_Huffman_State;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 2) := [others => [others => 0]];
   begin
      Jpeglib.Streams.Open (Source, Gray_Two_Block_Entropy_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Result : constant Jpeglib.Internal.Coefficients.Scan_Result :=
           Jpeglib.Internal.Coefficients.Decode_Baseline_Scan
             (Frame, Scan, Tables, Entropy'Access, Blocks);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "grayscale scan decode failed");
         Assert (Result.Blocks_Decoded = 2, "decoded block count mismatch");
         Assert (Blocks (1) (0) = 2, "first block DC mismatch");
         Assert (Blocks (2) (0) = 4, "second block DC predictor mismatch");
      end;
   end Baseline_Scan_Decodes_Grayscale_Blocks;

   procedure Baseline_Scan_Rejects_Missing_Huffman_Table (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Gray_Frame_16x8;
      Scan : constant Jpeglib.Internal.Scans.Scan := Gray_Scan (Frame);
      Tables : Jpeglib.Internal.Huffman.Huffman_State;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 2) := [others => [others => 0]];
   begin
      Jpeglib.Streams.Open (Source, Gray_Two_Block_Entropy_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Result : constant Jpeglib.Internal.Coefficients.Scan_Result :=
           Jpeglib.Internal.Coefficients.Decode_Baseline_Scan
             (Frame, Scan, Tables, Entropy'Access, Blocks);
      begin
         Assert (not Jpeglib.Results.Succeeded (Result.Outcome), "missing Huffman tables were accepted");
         Assert
           (Result.Outcome.First_Error.Code = Jpeglib.Errors.Huffman_Invalid_Definition,
           "missing Huffman tables used wrong error");
      end;
   end Baseline_Scan_Rejects_Missing_Huffman_Table;

   procedure Baseline_Scan_Encodes_Grayscale_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Gray_Frame_16x8;
      Scan : constant Jpeglib.Internal.Scans.Scan := Gray_Scan (Frame);
      Tables : constant Jpeglib.Internal.Huffman.Huffman_State := Tiny_Block_Huffman_State;
      Blocks : constant Jpeglib.Internal.Coefficients.Block_Array (1 .. 2) :=
        [1 => [0 => 2, others => 0],
         2 => [0 => 4, others => 0]];
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 2 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      declare
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Writer (Destination'Access);
         Result : constant Jpeglib.Internal.Coefficients.Scan_Result :=
           Jpeglib.Internal.Coefficients.Encode_Baseline_Scan
             (Frame, Scan, Tables, Bits, Blocks);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "grayscale scan encode failed");
         Assert (Result.Blocks_Decoded = 2, "encoded block count mismatch");
      end;
      Assert (Storage (1) = 16#44#, "encoded grayscale scan byte mismatch");
      Assert (Jpeglib.Streams.Offset (Destination) = 1, "encoded grayscale scan length mismatch");
   end Baseline_Scan_Encodes_Grayscale_Blocks;

   procedure Baseline_Scan_Encodes_Restarted_Grayscale_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Gray_Frame_16x8;
      Scan : constant Jpeglib.Internal.Scans.Scan := Gray_Scan (Frame);
      Tables : constant Jpeglib.Internal.Huffman.Huffman_State := Tiny_Block_Huffman_State;
      Blocks : constant Jpeglib.Internal.Coefficients.Block_Array (1 .. 2) :=
        [1 => [0 => 2, others => 0],
         2 => [0 => 2, others => 0]];
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 8 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      declare
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Writer (Destination'Access);
         Result : constant Jpeglib.Internal.Coefficients.Scan_Result :=
           Jpeglib.Internal.Coefficients.Encode_Baseline_Scan
             (Frame, Scan, Tables, Bits, Blocks, Restart => 1);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "restarted grayscale scan encode failed");
         Assert (Result.Blocks_Decoded = 2, "restarted encoded block count mismatch");
      end;
      Assert
        (Storage (1 .. 5) = [16#4F#, 16#FF#, 16#D0#, 16#4F#, 0],
         "encoded restarted grayscale scan bytes mismatch");
      Assert (Jpeglib.Streams.Offset (Destination) = 4, "encoded restarted grayscale scan length mismatch");
   end Baseline_Scan_Encodes_Restarted_Grayscale_Blocks;

   procedure Baseline_Scan_Encodes_Interleaved_Color_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Color_Frame_17x9;
      Scan : constant Jpeglib.Internal.Scans.Scan := Color_Scan_All_Luma_Tables (Frame);
      Tables : constant Jpeglib.Internal.Huffman.Huffman_State := Tiny_Block_Huffman_State;
      Blocks : constant Jpeglib.Internal.Coefficients.Block_Array (1 .. 12) :=
        [1 => [0 => 2, others => 0],
         2 => [0 => 4, others => 0],
         3 => [0 => 6, others => 0],
         4 => [0 => 8, others => 0],
         5 => [0 => 2, others => 0],
         6 => [0 => 2, others => 0],
         7 => [0 => 10, others => 0],
         8 => [0 => 12, others => 0],
         9 => [0 => 14, others => 0],
         10 => [0 => 16, others => 0],
         11 => [0 => 4, others => 0],
         12 => [0 => 4, others => 0]];
      Decoded : Jpeglib.Internal.Coefficients.Block_Array (1 .. 12) := [others => [others => 0]];
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 16 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      declare
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Writer (Destination'Access);
         Encode_Result : constant Jpeglib.Internal.Coefficients.Scan_Result :=
           Jpeglib.Internal.Coefficients.Encode_Baseline_Scan
             (Frame, Scan, Tables, Bits, Blocks);
      begin
         Assert (Jpeglib.Results.Succeeded (Encode_Result.Outcome), "interleaved color scan encode failed");
         Assert (Encode_Result.Blocks_Decoded = 12, "interleaved color encoded block count mismatch");
      end;

      Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Decode_Result : constant Jpeglib.Internal.Coefficients.Scan_Result :=
           Jpeglib.Internal.Coefficients.Decode_Baseline_Scan
             (Frame, Scan, Tables, Entropy'Access, Decoded);
      begin
         Assert (Jpeglib.Results.Succeeded (Decode_Result.Outcome), "interleaved color scan decode failed");
         Assert (Decode_Result.Blocks_Decoded = 12, "interleaved color decoded block count mismatch");
      end;

      Assert (Decoded = Blocks, "interleaved color scan roundtrip blocks mismatch");
   end Baseline_Scan_Encodes_Interleaved_Color_Blocks;

   procedure Baseline_Scan_Encodes_Restarted_Color_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Color_Frame_17x9;
      Scan : constant Jpeglib.Internal.Scans.Scan := Color_Scan_All_Luma_Tables (Frame);
      Tables : constant Jpeglib.Internal.Huffman.Huffman_State := Tiny_Block_Huffman_State;
      Blocks : constant Jpeglib.Internal.Coefficients.Block_Array (1 .. 12) :=
        [1 => [0 => 2, others => 0],
         2 => [0 => 4, others => 0],
         3 => [0 => 6, others => 0],
         4 => [0 => 8, others => 0],
         5 => [0 => 2, others => 0],
         6 => [0 => 2, others => 0],
         7 => [0 => 2, others => 0],
         8 => [0 => 4, others => 0],
         9 => [0 => 6, others => 0],
         10 => [0 => 8, others => 0],
         11 => [0 => 2, others => 0],
         12 => [0 => 2, others => 0]];
      Decoded : Jpeglib.Internal.Coefficients.Block_Array (1 .. 12) := [others => [others => 0]];
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 24 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Found_RST0 : Boolean := False;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      declare
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Writer (Destination'Access);
         Encode_Result : constant Jpeglib.Internal.Coefficients.Scan_Result :=
           Jpeglib.Internal.Coefficients.Encode_Baseline_Scan
             (Frame, Scan, Tables, Bits, Blocks, Restart => 1);
      begin
         Assert (Jpeglib.Results.Succeeded (Encode_Result.Outcome), "restarted color scan encode failed");
         Assert (Encode_Result.Blocks_Decoded = 12, "restarted color encoded block count mismatch");
      end;

      for Index in Storage'First .. Storage'First + Natural (Jpeglib.Streams.Offset (Destination)) - 2 loop
         if Storage (Index) = 16#FF# and then Storage (Index + 1) = Jpeglib.Byte (Jpeglib.Internal.Markers.RST0) then
            Found_RST0 := True;
         end if;
      end loop;
      Assert (Found_RST0, "restarted color scan missing RST0 marker");

      Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Decode_Result : constant Jpeglib.Internal.Coefficients.Scan_Result :=
           Jpeglib.Internal.Coefficients.Decode_Baseline_Scan
             (Frame, Scan, Tables, Entropy'Access, Decoded, Restart => 1);
      begin
         Assert (Jpeglib.Results.Succeeded (Decode_Result.Outcome), "restarted color scan decode failed");
         Assert (Decode_Result.Blocks_Decoded = 12, "restarted color decoded block count mismatch");
      end;

      Assert (Decoded = Blocks, "restarted color scan roundtrip blocks mismatch");
   end Baseline_Scan_Encodes_Restarted_Color_Blocks;

   procedure Baseline_Scan_Encode_Rejects_Missing_Huffman_Table (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Gray_Frame_16x8;
      Scan : constant Jpeglib.Internal.Scans.Scan := Gray_Scan (Frame);
      Tables : Jpeglib.Internal.Huffman.Huffman_State;
      Blocks : constant Jpeglib.Internal.Coefficients.Block_Array (1 .. 2) :=
        [others => [others => 0]];
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 2 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      declare
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Writer (Destination'Access);
         Result : constant Jpeglib.Internal.Coefficients.Scan_Result :=
           Jpeglib.Internal.Coefficients.Encode_Baseline_Scan
             (Frame, Scan, Tables, Bits, Blocks);
      begin
         Assert (not Jpeglib.Results.Succeeded (Result.Outcome), "missing Huffman tables were encoded");
         Assert
           (Result.Outcome.First_Error.Code = Jpeglib.Errors.Huffman_Invalid_Definition,
            "missing encode Huffman tables used wrong error");
      end;
      Assert (Jpeglib.Streams.Offset (Destination) = 0, "missing encode Huffman tables wrote output");
   end Baseline_Scan_Encode_Rejects_Missing_Huffman_Table;

   procedure Progressive_Scan_Decodes_DC_First (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Progressive_Gray_Frame_8x8;
      Scan : constant Jpeglib.Internal.Scans.Scan := Progressive_Gray_DC_First_Scan (Frame);
      Tables : constant Jpeglib.Internal.Huffman.Huffman_State := Tiny_Block_Huffman_State;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 1) := [others => [others => 0]];
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, Block_DC_EOB_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Result : constant Jpeglib.Internal.Coefficients.Scan_Result :=
           Jpeglib.Internal.Coefficients.Decode_Progressive_Scan
             (Frame, Scan, Tables, Entropy'Access, Blocks);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "progressive DC first scan failed");
         Assert (Result.Blocks_Decoded = 1, "progressive DC first block count mismatch");
         Assert (Blocks (1) (0) = 2, "progressive DC first scan coefficient mismatch");
      end;
   end Progressive_Scan_Decodes_DC_First;

   procedure Progressive_Scan_Decodes_DC_Refine (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Progressive_Gray_Frame_8x8;
      Scan : constant Jpeglib.Internal.Scans.Scan := Progressive_Gray_DC_Refine_Scan (Frame);
      Tables : constant Jpeglib.Internal.Huffman.Huffman_State := Tiny_Block_Huffman_State;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 1) := [1 => [0 => 2, others => 0]];
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, Bit_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Result : constant Jpeglib.Internal.Coefficients.Scan_Result :=
           Jpeglib.Internal.Coefficients.Decode_Progressive_Scan
             (Frame, Scan, Tables, Entropy'Access, Blocks);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "progressive DC refine scan failed");
         Assert (Result.Blocks_Decoded = 1, "progressive DC refine block count mismatch");
         Assert (Blocks (1) (0) = 3, "progressive DC refine scan coefficient mismatch");
      end;
   end Progressive_Scan_Decodes_DC_Refine;

   procedure Progressive_Scan_Decodes_AC_First (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Progressive_Gray_Frame_8x8;
      Scan : constant Jpeglib.Internal.Scans.Scan := Progressive_AC_First_Scan (Frame);
      Tables : constant Jpeglib.Internal.Huffman.Huffman_State := Tiny_Progressive_AC_Huffman_State;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 1) := [others => [others => 0]];
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, Bit_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Result : constant Jpeglib.Internal.Coefficients.Scan_Result :=
           Jpeglib.Internal.Coefficients.Decode_Progressive_Scan
             (Frame, Scan, Tables, Entropy'Access, Blocks);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "progressive AC first scan failed");
         Assert (Result.Blocks_Decoded = 1, "progressive AC first block count mismatch");
         Assert (Blocks (1) (16) = 2, "progressive AC first scan coefficient mismatch");
      end;
   end Progressive_Scan_Decodes_AC_First;

   procedure Progressive_Scan_State_Accepts_Sequence (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Progressive_Gray_Frame_8x8;
      DC_First : constant Jpeglib.Internal.Scans.Scan := Progressive_Gray_DC_First_Scan (Frame);
      AC_First : constant Jpeglib.Internal.Scans.Scan := Progressive_AC_First_Scan (Frame);
      AC_Refine : constant Jpeglib.Internal.Scans.Scan := Progressive_AC_Refine_Scan (Frame);
      DC_Tables : constant Jpeglib.Internal.Huffman.Huffman_State := Tiny_Block_Huffman_State;
      AC_First_Tables : constant Jpeglib.Internal.Huffman.Huffman_State := Tiny_Progressive_AC_Huffman_State;
      AC_Refine_Tables : constant Jpeglib.Internal.Huffman.Huffman_State := Tiny_Progressive_AC_Refine_Huffman_State;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 1) := [others => [others => 0]];
      State : Jpeglib.Internal.Progressive.Scan_State;
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Internal.Progressive.Reset (State);

      Jpeglib.Streams.Open (Source, Block_DC_EOB_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Result : constant Jpeglib.Internal.Coefficients.Scan_Result :=
           Jpeglib.Internal.Coefficients.Decode_Progressive_Scan
             (Frame, DC_First, DC_Tables, Entropy'Access, Blocks, State);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "stateful progressive DC first scan failed");
      end;

      Jpeglib.Streams.Open (Source, Bit_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Result : constant Jpeglib.Internal.Coefficients.Scan_Result :=
           Jpeglib.Internal.Coefficients.Decode_Progressive_Scan
             (Frame, AC_First, AC_First_Tables, Entropy'Access, Blocks, State);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "stateful progressive AC first scan failed");
      end;

      Jpeglib.Streams.Open (Source, Progressive_AC_Refine_Add_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Result : constant Jpeglib.Internal.Coefficients.Scan_Result :=
           Jpeglib.Internal.Coefficients.Decode_Progressive_Scan
             (Frame, AC_Refine, AC_Refine_Tables, Entropy'Access, Blocks, State);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "stateful progressive AC refine scan failed");
      end;

      Assert (Blocks (1) (0) = 2, "stateful progressive DC coefficient mismatch");
      Assert (Blocks (1) (16) = 2, "stateful progressive AC first coefficient mismatch");
      Assert (Blocks (1) (1) = -1, "stateful progressive AC newly nonzero coefficient mismatch");
   end Progressive_Scan_State_Accepts_Sequence;

   procedure Progressive_Scan_State_Rejects_Refine_First (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Progressive_Gray_Frame_8x8;
      AC_Refine : constant Jpeglib.Internal.Scans.Scan := Progressive_AC_Refine_Scan (Frame);
      Tables : constant Jpeglib.Internal.Huffman.Huffman_State := Tiny_Progressive_AC_Refine_Huffman_State;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 1) := [others => [others => 0]];
      State : Jpeglib.Internal.Progressive.Scan_State;
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Internal.Progressive.Reset (State);
      Jpeglib.Streams.Open (Source, Progressive_AC_Refine_Add_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Result : constant Jpeglib.Internal.Coefficients.Scan_Result :=
           Jpeglib.Internal.Coefficients.Decode_Progressive_Scan
             (Frame, AC_Refine, Tables, Entropy'Access, Blocks, State);
      begin
         Assert (not Jpeglib.Results.Succeeded (Result.Outcome), "stateful progressive refine-first scan accepted");
         Assert
           (Result.Outcome.First_Error.Code = Jpeglib.Errors.Scan_Invalid_Definition,
            "stateful progressive refine-first scan used wrong error");
      end;
   end Progressive_Scan_State_Rejects_Refine_First;

   procedure Decoder_Decodes_Baseline_Coefficients (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 2) := [others => [others => 0]];
   begin
      Jpeglib.Streams.Open (Source, Full_Gray_Coefficient_Storage'Access);
      declare
         Result : constant Jpeglib.Internal.Decoder.Coefficient_Result :=
           Jpeglib.Internal.Decoder.Decode_Baseline_Coefficients (Source'Access, Blocks);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "baseline coefficient decode failed");
         Assert (Result.Blocks_Decoded = 2, "coefficient decode block count mismatch");
         Assert
           (Result.Ending_Marker = Jpeglib.Internal.Markers.EOI,
            "coefficient decode did not consume EOI");
         Assert (Blocks (1) (0) = 2, "first decoded coefficient block DC mismatch");
         Assert (Blocks (2) (0) = 4, "second decoded coefficient block DC mismatch");
      end;
   end Decoder_Decodes_Baseline_Coefficients;

   procedure Decoder_Rejects_Too_Few_Coefficient_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 1) := [others => [others => 99]];
   begin
      Jpeglib.Streams.Open (Source, Full_Gray_Coefficient_Storage'Access);
      declare
         Result : constant Jpeglib.Internal.Decoder.Coefficient_Result :=
           Jpeglib.Internal.Decoder.Decode_Baseline_Coefficients (Source'Access, Blocks);
      begin
         Assert (not Jpeglib.Results.Succeeded (Result.Outcome), "undersized coefficient storage was accepted");
         Assert
           (Result.Outcome.First_Error.Code = Jpeglib.Errors.Output_Limit_Exceeded,
            "undersized coefficient storage used wrong error");
         Assert (Blocks (1) (0) = 99, "undersized coefficient storage was partially written");
      end;
   end Decoder_Rejects_Too_Few_Coefficient_Blocks;

   procedure Decoder_Decodes_Restarted_Coefficients (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 2) := [others => [others => 0]];
   begin
      Jpeglib.Streams.Open (Source, Full_Gray_Restart_Coefficient_Storage'Access);
      declare
         Result : constant Jpeglib.Internal.Decoder.Coefficient_Result :=
           Jpeglib.Internal.Decoder.Decode_Baseline_Coefficients (Source'Access, Blocks);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "restarted coefficient decode failed");
         Assert (Result.Blocks_Decoded = 2, "restarted coefficient block count mismatch");
         Assert (Blocks (1) (0) = 2, "first restarted block DC mismatch");
         Assert (Blocks (2) (0) = 2, "restart did not reset DC predictor");
      end;
   end Decoder_Decodes_Restarted_Coefficients;

   procedure Decoder_Rejects_Wrong_Restart_Marker (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 2) := [others => [others => 0]];
   begin
      Jpeglib.Streams.Open (Source, Bad_Gray_Restart_Coefficient_Storage'Access);
      declare
         Result : constant Jpeglib.Internal.Decoder.Coefficient_Result :=
           Jpeglib.Internal.Decoder.Decode_Baseline_Coefficients (Source'Access, Blocks);
      begin
         Assert (not Jpeglib.Results.Succeeded (Result.Outcome), "wrong restart marker was accepted");
         Assert
           (Result.Outcome.First_Error.Code = Jpeglib.Errors.Restart_Invalid_State,
            "wrong restart marker used wrong error");
      end;
   end Decoder_Rejects_Wrong_Restart_Marker;

   procedure Decoder_Rejects_Missing_Restart_Marker (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 2) := [others => [others => 0]];
   begin
      Jpeglib.Streams.Open (Source, Missing_Gray_Restart_Coefficient_Storage'Access);
      declare
         Result : constant Jpeglib.Internal.Decoder.Coefficient_Result :=
           Jpeglib.Internal.Decoder.Decode_Baseline_Coefficients (Source'Access, Blocks);
      begin
         Assert (not Jpeglib.Results.Succeeded (Result.Outcome), "missing restart marker was accepted");
         Assert
           (Result.Outcome.First_Error.Code = Jpeglib.Errors.Restart_Invalid_State,
            "missing restart marker used wrong error");
      end;
   end Decoder_Rejects_Missing_Restart_Marker;

   procedure Decoder_Decodes_Interleaved_Color_Coefficients (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 12) := [others => [others => 0]];
   begin
      Jpeglib.Streams.Open (Source, Full_Color_Coefficient_Storage'Access);
      declare
         Result : constant Jpeglib.Internal.Decoder.Coefficient_Result :=
           Jpeglib.Internal.Decoder.Decode_Baseline_Coefficients (Source'Access, Blocks);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "interleaved color coefficient decode failed");
         Assert (Result.Blocks_Decoded = 12, "interleaved color block count mismatch");
         Assert (Jpeglib.Internal.Frames.Total_Blocks (Result.Header.Frame) = 12, "color padded block count mismatch");
         Assert (Blocks (1) (0) = 2, "first MCU Y block 1 mismatch");
         Assert (Blocks (2) (0) = 4, "first MCU Y block 2 mismatch");
         Assert (Blocks (3) (0) = 6, "first MCU Y block 3 mismatch");
         Assert (Blocks (4) (0) = 8, "first MCU Y block 4 mismatch");
         Assert (Blocks (5) (0) = 2, "first MCU Cb block mismatch");
         Assert (Blocks (6) (0) = 2, "first MCU Cr block mismatch");
         Assert (Blocks (7) (0) = 10, "second MCU Y block 1 mismatch");
         Assert (Blocks (8) (0) = 12, "second MCU Y block 2 mismatch");
         Assert (Blocks (9) (0) = 14, "second MCU Y block 3 mismatch");
         Assert (Blocks (10) (0) = 16, "second MCU Y block 4 mismatch");
         Assert (Blocks (11) (0) = 4, "second MCU Cb block mismatch");
         Assert (Blocks (12) (0) = 4, "second MCU Cr block mismatch");
      end;
   end Decoder_Decodes_Interleaved_Color_Coefficients;

   procedure Decoder_Decodes_Separate_Color_Scans (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 12) := [others => [others => 0]];
   begin
      Jpeglib.Streams.Open (Source, Full_Color_Separate_Scan_Coefficient_Storage'Access);
      declare
         Result : constant Jpeglib.Internal.Decoder.Coefficient_Result :=
           Jpeglib.Internal.Decoder.Decode_Baseline_Coefficients (Source'Access, Blocks);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "separate color scan coefficient decode failed");
         Assert (Jpeglib.Internal.Frames.Total_Blocks (Result.Header.Frame) = 12, "separate scan capacity mismatch");
         Assert (Result.Blocks_Decoded = 10, "separate scan decoded block count mismatch");
         Assert (Blocks (1) (0) = 2, "separate Y block 1 mismatch");
         Assert (Blocks (2) (0) = 4, "separate Y block 2 mismatch");
         Assert (Blocks (3) (0) = 6, "separate Y block 3 mismatch");
         Assert (Blocks (4) (0) = 8, "separate Y block 4 mismatch");
         Assert (Blocks (5) (0) = 10, "separate Y block 5 mismatch");
         Assert (Blocks (6) (0) = 12, "separate Y block 6 mismatch");
         Assert (Blocks (7) (0) = 2, "separate Cb block 1 mismatch");
         Assert (Blocks (8) (0) = 4, "separate Cb block 2 mismatch");
         Assert (Blocks (9) (0) = 2, "separate Cr block 1 mismatch");
         Assert (Blocks (10) (0) = 4, "separate Cr block 2 mismatch");
         Assert (Blocks (11) (0) = 0 and then Blocks (12) (0) = 0, "unused capacity was modified");
      end;
   end Decoder_Decodes_Separate_Color_Scans;

   procedure Decoder_Rejects_Incomplete_Color_Scans (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 12) := [others => [others => 0]];
   begin
      Jpeglib.Streams.Open (Source, Incomplete_Color_Separate_Scan_Coefficient_Storage'Access);
      declare
         Result : constant Jpeglib.Internal.Decoder.Coefficient_Result :=
           Jpeglib.Internal.Decoder.Decode_Baseline_Coefficients (Source'Access, Blocks);
      begin
         Assert (not Jpeglib.Results.Succeeded (Result.Outcome), "incomplete color scans were accepted");
         Assert
           (Result.Outcome.First_Error.Code = Jpeglib.Errors.Scan_Invalid_Definition,
            "incomplete color scans used wrong error");
         Assert
           (Result.Outcome.First_Error.Context.Frame_Component = 2,
            "incomplete color scans did not identify first missing component");
      end;
   end Decoder_Rejects_Incomplete_Color_Scans;

   procedure Decoder_Rejects_Duplicate_Color_Scans (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 12) := [others => [others => 55]];
   begin
      Jpeglib.Streams.Open (Source, Duplicate_Color_Separate_Scan_Coefficient_Storage'Access);
      declare
         Result : constant Jpeglib.Internal.Decoder.Coefficient_Result :=
           Jpeglib.Internal.Decoder.Decode_Baseline_Coefficients (Source'Access, Blocks);
      begin
         Assert (not Jpeglib.Results.Succeeded (Result.Outcome), "duplicate color scan was accepted");
         Assert
           (Result.Outcome.First_Error.Code = Jpeglib.Errors.Scan_Invalid_Definition,
            "duplicate color scan used wrong error");
         Assert
         (Result.Outcome.First_Error.Context.Frame_Component = 1,
            "duplicate color scan did not identify repeated component");
         Assert (Blocks (1) (0) = 2, "first scan block 1 mismatch before duplicate failure");
         Assert (Blocks (6) (0) = 12, "first scan block 6 mismatch before duplicate failure");
         Assert (Blocks (7) (0) = 2, "second scan block mismatch before duplicate failure");
         Assert (Blocks (9) (0) = 55, "duplicate scan wrote into caller output before rejection");
      end;
   end Decoder_Rejects_Duplicate_Color_Scans;

   procedure Decoder_Decodes_Progressive_Coefficients (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 1) := [others => [others => 0]];
   begin
      Jpeglib.Streams.Open (Source, Progressive_Gray_Coefficient_Storage'Access);
      declare
         Result : constant Jpeglib.Internal.Decoder.Coefficient_Result :=
           Jpeglib.Internal.Decoder.Decode_Progressive_Coefficients (Source'Access, Blocks);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "progressive coefficient decode failed");
         Assert (Result.Blocks_Decoded = 1, "progressive coefficient block count mismatch");
         Assert (Result.Ending_Marker = Jpeglib.Internal.Markers.EOI, "progressive coefficient ending mismatch");
         Assert
           (Jpeglib.Internal.Frames.Mode (Result.Header.Frame) = Jpeglib.Progressive_DCT,
            "progressive coefficient frame mode mismatch");
         Assert (Blocks (1) (0) = 2, "progressive coefficient DC mismatch");
      end;
   end Decoder_Decodes_Progressive_Coefficients;

   procedure Decoder_Decodes_Progressive_Multi_Scan_Coefficients (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 1) := [others => [others => 0]];
   begin
      Jpeglib.Streams.Open (Source, Progressive_Gray_Multi_Scan_Coefficient_Storage'Access);
      declare
         Result : constant Jpeglib.Internal.Decoder.Coefficient_Result :=
           Jpeglib.Internal.Decoder.Decode_Progressive_Coefficients (Source'Access, Blocks);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "progressive multi-scan coefficient decode failed");
         Assert (Result.Blocks_Decoded = 2, "progressive multi-scan block pass count mismatch");
         Assert (Result.Ending_Marker = Jpeglib.Internal.Markers.EOI, "progressive multi-scan ending mismatch");
         Assert (Blocks (1) (0) = 2, "progressive multi-scan DC mismatch");
         Assert (Blocks (1) (16) = 2, "progressive multi-scan AC mismatch");
      end;
   end Decoder_Decodes_Progressive_Multi_Scan_Coefficients;

   procedure Decoder_Decodes_Progressive_Restarted_Coefficients (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 2) := [others => [others => 0]];
   begin
      Jpeglib.Streams.Open (Source, Progressive_Gray_Restart_Coefficient_Storage'Access);
      declare
         Result : constant Jpeglib.Internal.Decoder.Coefficient_Result :=
           Jpeglib.Internal.Decoder.Decode_Progressive_Coefficients (Source'Access, Blocks);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "progressive restarted coefficient decode failed");
         Assert (Result.Blocks_Decoded = 2, "progressive restarted block count mismatch");
         Assert (Result.Ending_Marker = Jpeglib.Internal.Markers.EOI, "progressive restarted ending mismatch");
         Assert (Result.Header.Restart = 1, "progressive restarted interval mismatch");
         Assert (Blocks (1) (0) = 2, "progressive restarted first DC mismatch");
         Assert (Blocks (2) (0) = 2, "progressive restarted predictor was not reset");
      end;
   end Decoder_Decodes_Progressive_Restarted_Coefficients;

   procedure Decoder_Decodes_Progressive_Interleaved_Color_Coefficients
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 6) := [others => [others => 0]];
   begin
      Jpeglib.Streams.Open (Source, Progressive_YCbCr_Interleaved_Coefficient_Storage'Access);
      declare
         Result : constant Jpeglib.Internal.Decoder.Coefficient_Result :=
           Jpeglib.Internal.Decoder.Decode_Progressive_Coefficients (Source'Access, Blocks);
      begin
         Assert
           (Jpeglib.Results.Succeeded (Result.Outcome),
            "progressive interleaved color coefficient decode failed");
         Assert (Result.Blocks_Decoded = 6, "progressive interleaved color block count mismatch");
         Assert (Result.Ending_Marker = Jpeglib.Internal.Markers.EOI, "progressive color ending mismatch");
         Assert (Blocks (1) (0) = 2, "progressive color Y block 1 mismatch");
         Assert (Blocks (2) (0) = 2, "progressive color Y block 2 mismatch");
         Assert (Blocks (3) (0) = 0, "progressive color Cb block 1 mismatch");
         Assert (Blocks (4) (0) = 2, "progressive color Cb block 2 mismatch");
         Assert (Blocks (5) (0) = 0, "progressive color Cr block 1 mismatch");
         Assert (Blocks (6) (0) = 0, "progressive color Cr block 2 mismatch");
      end;
   end Decoder_Decodes_Progressive_Interleaved_Color_Coefficients;

end Jpeglib_Testing.Test_Coefficient_Scans;

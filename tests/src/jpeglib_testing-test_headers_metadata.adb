with AUnit.Assertions;
with Jpeglib.Decoding;
with Jpeglib.Errors;
with Jpeglib.Internal.Bit_Streams;
with Jpeglib.Internal.Frames;
with Jpeglib.Internal.Markers;
with Jpeglib.Internal.Progressive;
with Jpeglib.Internal.Restarts;
with Jpeglib.Internal.Scans;
with Jpeglib.Internal.Segments;
with Jpeglib.Limits;
with Jpeglib.Metadata;
with Jpeglib.Results;
with Jpeglib.Streams;

package body Jpeglib_Testing.Test_Headers_Metadata is
   use AUnit.Assertions;
   use type Jpeglib.Byte;
   use type Jpeglib.Byte_Count;
   use type Jpeglib.Errors.Error_Code;
   use type Jpeglib.Marker_Code;
   use type Jpeglib.Frame_Mode;
   use type Jpeglib.Encoded_Color_Model;
   use type Jpeglib.Image_Width;
   use type Jpeglib.Image_Height;
   use type Jpeglib.Component_Count;
   use type Jpeglib.Component_Index;
   use type Jpeglib.Component_Identifier;
   use type Jpeglib.Huffman_Table_Index;
   use type Jpeglib.Spectral_Selection_Index;
   use type Jpeglib.Successive_Approximation_Value;
   use type Jpeglib.Restart_Interval;
   use type Jpeglib.Block_Column;
   use type Jpeglib.Block_Row;
   use type Jpeglib.Block_Count;
   use type Jpeglib.MCU_Column;
   use type Jpeglib.MCU_Row;
   use type Jpeglib.Streams.Byte_Array;
   use type Jpeglib.Streams.Const_Byte_Array_Access;
   use type Jpeglib.Internal.Bit_Streams.Entropy_Byte_Kind;
   use type Jpeglib.Internal.Frames.Sampling_Factor;
   use type Jpeglib.Metadata.Callback_Event;
   use type Jpeglib.Metadata.Exif_Orientation;
   use type Jpeglib.Metadata.Metadata_Kind;

   Callback_Event_Count : Natural := 0;
   Callback_Begin_Count : Natural := 0;
   Callback_Data_Count : Natural := 0;
   Callback_End_Count : Natural := 0;
   Callback_Data_Bytes : Jpeglib.Byte_Count := 0;
   Callback_Data_Sum : Natural := 0;

   procedure Reset_Metadata_Callback_State;
   procedure Capture_Metadata_Callback
     (Event : Jpeglib.Metadata.Callback_Event;
      View : Jpeglib.Metadata.Callback_View);
   function Progressive_AC_First_Scan
     (Frame : Jpeglib.Internal.Frames.Frame) return Jpeglib.Internal.Scans.Scan;
   function Progressive_AC_Refine_Scan
     (Frame : Jpeglib.Internal.Frames.Frame) return Jpeglib.Internal.Scans.Scan;

   procedure Reset_Metadata_Callback_State is
   begin
      Callback_Event_Count := 0;
      Callback_Begin_Count := 0;
      Callback_Data_Count := 0;
      Callback_End_Count := 0;
      Callback_Data_Bytes := 0;
      Callback_Data_Sum := 0;
   end Reset_Metadata_Callback_State;

   procedure Capture_Metadata_Callback
     (Event : Jpeglib.Metadata.Callback_Event;
      View : Jpeglib.Metadata.Callback_View) is
   begin
      Callback_Event_Count := Callback_Event_Count + 1;

      case Event is
         when Jpeglib.Metadata.Segment_Begin =>
            Callback_Begin_Count := Callback_Begin_Count + 1;
         when Jpeglib.Metadata.Segment_Data =>
            Callback_Data_Count := Callback_Data_Count + 1;
            if View.Chunk /= null then
               Callback_Data_Bytes := Callback_Data_Bytes + Jpeglib.Byte_Count (View.Chunk'Length);
               for Item of View.Chunk.all loop
                  Callback_Data_Sum := Callback_Data_Sum + Natural (Item);
               end loop;
            end if;
         when Jpeglib.Metadata.Segment_End =>
            Callback_End_Count := Callback_End_Count + 1;
      end case;
   end Capture_Metadata_Callback;

   Bad_Header_No_SOI_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#DB#, 0, 2];
   Bad_SOF_Duplicate_Component_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 17,
      8, 0, 9, 0, 17, 3,
      1, 16#22#, 0,
      1, 16#11#, 1,
      3, 16#11#, 1];
   Bad_SOS_Baseline_Spectral_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 12,
      3,
      1, 16#00#,
      2, 16#11#,
      3, 16#11#,
      1, 63, 0];
   Bad_SOS_Progressive_AC_Multi_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 10,
      2,
      1, 16#00#,
      2, 16#11#,
      1, 5, 0];
   Bad_SOS_Progressive_Refine_Gap_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 8,
      1,
      1, 16#00#,
      1, 63, 16#31#];
   Bad_SOS_Unknown_Component_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 12,
      3,
      1, 16#00#,
      4, 16#11#,
      3, 16#11#,
      0, 63, 0];
   CMYK_Header_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#C0#,
      0, 20,
      8, 0, 8, 0, 8, 4,
      16#43#, 16#11#, 0,
      16#4D#, 16#11#, 0,
      16#59#, 16#11#, 0,
      16#4B#, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 14,
      4,
      16#43#, 16#00#,
      16#4D#, 16#00#,
      16#59#, 16#00#,
      16#4B#, 16#00#,
      0, 63, 0,
      16#00#];
   DRI_Storage : aliased constant Jpeglib.Streams.Byte_Array := [0, 4, 0, 7];
   Entropy_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#11#, 16#FF#, 16#00#, 16#22#, 16#FF#, 16#FF#, 16#D0#, 16#33#, 16#FF#, 16#D9#, 16#44#];
   Exif_Orientation_Header_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#E1#, 0, 34,
      16#45#, 16#78#, 16#69#, 16#66#, 0, 0,
      16#49#, 16#49#, 16#2A#, 0, 8, 0, 0, 0,
      1, 0,
      16#12#, 1, 3, 0, 1, 0, 0, 0, 6, 0, 0, 0,
      0, 0, 0, 0,
      16#FF#, 16#C0#,
      0, 11,
      8, 0, 8, 0, 4, 1,
      1, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 63, 0,
      16#00#];
   ICC_Duplicate_Header_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#E2#, 0, 16,
      16#49#, 16#43#, 16#43#, 16#5F#, 16#50#, 16#52#, 16#4F#,
      16#46#, 16#49#, 16#4C#, 16#45#, 0, 1, 2,
      16#FF#, 16#E2#, 0, 16,
      16#49#, 16#43#, 16#43#, 16#5F#, 16#50#, 16#52#, 16#4F#,
      16#46#, 16#49#, 16#4C#, 16#45#, 0, 1, 2,
      16#FF#, 16#C0#,
      0, 11,
      8, 0, 8, 0, 8, 1,
      1, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 63, 0,
      16#00#];
   ICC_Fragmented_Header_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#E2#, 0, 18,
      16#49#, 16#43#, 16#43#, 16#5F#, 16#50#, 16#52#, 16#4F#,
      16#46#, 16#49#, 16#4C#, 16#45#, 0, 1, 2, 16#41#, 16#42#,
      16#FF#, 16#E2#, 0, 18,
      16#49#, 16#43#, 16#43#, 16#5F#, 16#50#, 16#52#, 16#4F#,
      16#46#, 16#49#, 16#4C#, 16#45#, 0, 2, 2, 16#43#, 16#44#,
      16#FF#, 16#C0#,
      0, 11,
      8, 0, 8, 0, 8, 1,
      1, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 63, 0,
      16#00#];
   ICC_Incomplete_Header_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#E2#, 0, 16,
      16#49#, 16#43#, 16#43#, 16#5F#, 16#50#, 16#52#, 16#4F#,
      16#46#, 16#49#, 16#4C#, 16#45#, 0, 1, 2,
      16#FF#, 16#C0#,
      0, 11,
      8, 0, 8, 0, 8, 1,
      1, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 63, 0,
      16#00#];
   ICC_Out_Of_Order_Header_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#E2#, 0, 18,
      16#49#, 16#43#, 16#43#, 16#5F#, 16#50#, 16#52#, 16#4F#,
      16#46#, 16#49#, 16#4C#, 16#45#, 0, 2, 2, 16#43#, 16#44#,
      16#FF#, 16#E2#, 0, 18,
      16#49#, 16#43#, 16#43#, 16#5F#, 16#50#, 16#52#, 16#4F#,
      16#46#, 16#49#, 16#4C#, 16#45#, 0, 1, 2, 16#41#, 16#42#,
      16#FF#, 16#C0#,
      0, 11,
      8, 0, 8, 0, 8, 1,
      1, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 63, 0,
      16#00#];
   Many_Metadata_Header_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#FE#, 0, 3, 1,
      16#FF#, 16#FE#, 0, 3, 2,
      16#FF#, 16#FE#, 0, 3, 3,
      16#FF#, 16#FE#, 0, 3, 4,
      16#FF#, 16#FE#, 0, 3, 5,
      16#FF#, 16#FE#, 0, 3, 6,
      16#FF#, 16#FE#, 0, 3, 7,
      16#FF#, 16#FE#, 0, 3, 8,
      16#FF#, 16#FE#, 0, 3, 9,
      16#FF#, 16#FE#, 0, 3, 10,
      16#FF#, 16#FE#, 0, 3, 11,
      16#FF#, 16#FE#, 0, 3, 12,
      16#FF#, 16#FE#, 0, 3, 13,
      16#FF#, 16#FE#, 0, 3, 14,
      16#FF#, 16#FE#, 0, 3, 15,
      16#FF#, 16#FE#, 0, 3, 16,
      16#FF#, 16#FE#, 0, 3, 17,
      16#FF#, 16#C0#,
      0, 11,
      8, 0, 8, 0, 8, 1,
      1, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 63, 0,
      16#00#];
   Metadata_Header_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#E0#, 0, 7, 16#4A#, 16#46#, 16#49#, 16#46#, 0,
      16#FF#, 16#FE#, 0, 5, 16#41#, 16#42#, 16#43#,
      16#FF#, 16#EE#, 0, 7, 16#41#, 16#64#, 16#6F#, 16#62#, 16#65#,
      16#FF#, 16#C0#,
      0, 11,
      8, 0, 8, 0, 8, 1,
      1, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 63, 0,
      16#00#];
   Metadata_Kinds_Header_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#E0#, 0, 7, 16#4A#, 16#46#, 16#58#, 16#58#, 0,
      16#FF#, 16#E1#, 0, 8, 16#45#, 16#78#, 16#69#, 16#66#, 0, 0,
      16#FF#, 16#E2#, 0, 16,
      16#49#, 16#43#, 16#43#, 16#5F#, 16#50#, 16#52#, 16#4F#,
      16#46#, 16#49#, 16#4C#, 16#45#, 0, 1, 1,
      16#FF#, 16#E1#, 0, 31,
      16#68#, 16#74#, 16#74#, 16#70#, 16#3A#, 16#2F#, 16#2F#,
      16#6E#, 16#73#, 16#2E#, 16#61#, 16#64#, 16#6F#, 16#62#,
      16#65#, 16#2E#, 16#63#, 16#6F#, 16#6D#, 16#2F#, 16#78#,
      16#61#, 16#70#, 16#2F#, 16#31#, 16#2E#, 16#30#, 16#2F#, 0,
      16#FF#, 16#E1#, 0, 37,
      16#68#, 16#74#, 16#74#, 16#70#, 16#3A#, 16#2F#, 16#2F#,
      16#6E#, 16#73#, 16#2E#, 16#61#, 16#64#, 16#6F#, 16#62#,
      16#65#, 16#2E#, 16#63#, 16#6F#, 16#6D#, 16#2F#, 16#78#,
      16#6D#, 16#70#, 16#2F#, 16#65#, 16#78#, 16#74#, 16#65#,
      16#6E#, 16#73#, 16#69#, 16#6F#, 16#6E#, 16#2F#, 0,
      16#FF#, 16#ED#, 0, 16,
      16#50#, 16#68#, 16#6F#, 16#74#, 16#6F#, 16#73#, 16#68#,
      16#6F#, 16#70#, 16#20#, 16#33#, 16#2E#, 16#30#, 0,
      16#FF#, 16#C0#,
      0, 11,
      8, 0, 8, 0, 8, 1,
      1, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 63, 0,
      16#00#];
   Minimal_Header_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#DB#,
      0, 67, 0,
      1, 2, 3, 4, 5, 6, 7, 8,
      9, 10, 11, 12, 13, 14, 15, 16,
      17, 18, 19, 20, 21, 22, 23, 24,
      25, 26, 27, 28, 29, 30, 31, 32,
      33, 34, 35, 36, 37, 38, 39, 40,
      41, 42, 43, 44, 45, 46, 47, 48,
      49, 50, 51, 52, 53, 54, 55, 56,
      57, 58, 59, 60, 61, 62, 63, 64,
      16#FF#, 16#C4#,
      0, 20, 0,
      0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      16#05#,
      16#FF#, 16#DD#, 0, 4, 0, 7,
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
      16#00#];
   RGB_Header_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#C0#,
      0, 17,
      8, 0, 8, 0, 8, 3,
      16#52#, 16#11#, 0,
      16#47#, 16#11#, 0,
      16#42#, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 12,
      3,
      16#52#, 16#00#,
      16#47#, 16#00#,
      16#42#, 16#00#,
      0, 63, 0,
      16#00#];
   SOF0_Gray_DNL_Pending_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 11,
      8, 0, 0, 0, 8, 1,
      1, 16#11#, 0];
   SOF0_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 17,
      8, 0, 9, 0, 17, 3,
      1, 16#22#, 0,
      2, 16#11#, 1,
      3, 16#11#, 1];
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
   SOS_Progressive_DC_First_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 12,
      3,
      1, 16#00#,
      2, 16#11#,
      3, 16#11#,
      0, 0, 0];
   SOS_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 12,
      3,
      1, 16#00#,
      2, 16#11#,
      3, 16#11#,
      0, 63, 0];
   Unknown_Metadata_Header_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#EF#, 0, 5, 16#41#, 16#42#, 16#43#,
      16#FF#, 16#C0#,
      0, 11,
      8, 0, 8, 0, 8, 1,
      1, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 63, 0,
      16#00#];
   YCCK_Header_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#EE#, 0, 14,
      16#41#, 16#64#, 16#6F#, 16#62#, 16#65#, 0, 100, 0, 0, 0, 0, 2,
      16#FF#, 16#C0#,
      0, 20,
      8, 0, 8, 0, 8, 4,
      16#43#, 16#11#, 0,
      16#4D#, 16#11#, 0,
      16#59#, 16#11#, 0,
      16#4B#, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 14,
      4,
      16#43#, 16#00#,
      16#4D#, 16#00#,
      16#59#, 16#00#,
      16#4B#, 16#00#,
      0, 63, 0,
      16#00#];

   procedure SOF_Parser_Derives_Geometry (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure SOF_Parser_Accepts_DNL_Pending_Height (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure SOF_Parser_Rejects_Duplicate_Components (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure SOS_Parser_Resolves_Baseline_Scan (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure SOS_Parser_Rejects_Unknown_Component (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure SOS_Parser_Rejects_Baseline_Spectral_Range (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure SOS_Parser_Accepts_Progressive_DC_First (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure SOS_Parser_Accepts_Progressive_AC_First (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure SOS_Parser_Accepts_Progressive_AC_Refine (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure SOS_Parser_Rejects_Progressive_AC_Multi_Component (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure SOS_Parser_Rejects_Progressive_Refine_Gap (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Progressive_State_Accepts_First_And_Refine (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Progressive_State_Rejects_Duplicate_First (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Progressive_State_Rejects_Refine_Without_First (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure DRI_Parser_Reads_Interval (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Restart_State_Sequences_Markers (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Entropy_Reader_Classifies_Markers (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Reads_Structural_Header (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Rejects_Missing_SOI (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Infers_RGB_Header (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Infers_CMYK_Header (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Infers_YCCK_Header (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Reports_Metadata_Summaries (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Classifies_Metadata_Kinds (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Honors_Discard_Metadata_Policy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Streams_Metadata_Callbacks (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Enforces_Metadata_Callback_Limit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Retains_Known_Metadata_Payloads (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Retains_Selected_Metadata_Payloads (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Retains_All_Metadata_Payloads (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Enforces_Metadata_Retention_Buffer (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Applies_Metadata_Policy_To_Unknown_APP (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Enforces_Metadata_Byte_Limit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Enforces_Metadata_Segment_Count_Limit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Enforces_Metadata_Segment_Byte_Limit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Tracks_ICC_Profile_Bytes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Enforces_ICC_Profile_Byte_Limit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Rejects_Duplicate_ICC_Profile_Fragment (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Rejects_Out_Of_Order_ICC_Profile_Fragment (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Rejects_Incomplete_ICC_Profile (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Parses_Exif_Orientation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Caps_Metadata_Summaries (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Decoder_Stress_Streams_Metadata_Callbacks (T : in out AUnit.Test_Cases.Test_Case'Class);
   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("headers_metadata");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, SOF_Parser_Derives_Geometry'Access, "headers_metadata.frames.sof_geometry");
      Register_Routine
        (T,
         SOF_Parser_Accepts_DNL_Pending_Height'Access,
         "headers_metadata.frames.sof_dnl_pending_height");
      Register_Routine (T, SOF_Parser_Rejects_Duplicate_Components'Access, "headers_metadata.frames.sof_duplicate");
      Register_Routine (T, SOS_Parser_Resolves_Baseline_Scan'Access, "headers_metadata.scans.sos_baseline");
      Register_Routine (T, SOS_Parser_Rejects_Unknown_Component'Access, "headers_metadata.scans.sos_unknown_component");
      Register_Routine
        (T,
         SOS_Parser_Rejects_Baseline_Spectral_Range'Access,
         "headers_metadata.scans.sos_baseline_spectral");
      Register_Routine
        (T,
         SOS_Parser_Accepts_Progressive_DC_First'Access,
         "headers_metadata.scans.sos_progressive_dc_first");
      Register_Routine
        (T,
         SOS_Parser_Accepts_Progressive_AC_First'Access,
         "headers_metadata.scans.sos_progressive_ac_first");
      Register_Routine
        (T,
         SOS_Parser_Accepts_Progressive_AC_Refine'Access,
         "headers_metadata.scans.sos_progressive_ac_refine");
      Register_Routine
        (T,
         SOS_Parser_Rejects_Progressive_AC_Multi_Component'Access,
         "headers_metadata.scans.sos_progressive_ac_multi");
      Register_Routine
        (T,
         SOS_Parser_Rejects_Progressive_Refine_Gap'Access,
         "headers_metadata.scans.sos_progressive_refine_gap");
      Register_Routine
        (T,
         Progressive_State_Accepts_First_And_Refine'Access,
         "headers_metadata.progressive.state_first_refine");
      Register_Routine
        (T,
         Progressive_State_Rejects_Duplicate_First'Access,
         "headers_metadata.progressive.state_duplicate_first");
      Register_Routine
        (T,
         Progressive_State_Rejects_Refine_Without_First'Access,
         "headers_metadata.progressive.state_refine_without_first");
      Register_Routine (T, DRI_Parser_Reads_Interval'Access, "headers_metadata.restarts.dri");
      Register_Routine (T, Restart_State_Sequences_Markers'Access, "headers_metadata.restarts.sequence");
      Register_Routine (T, Entropy_Reader_Classifies_Markers'Access, "headers_metadata.entropy.reader_markers");
      Register_Routine (T, Decoder_Reads_Structural_Header'Access, "headers_metadata.decoder.header");
      Register_Routine (T, Decoder_Rejects_Missing_SOI'Access, "headers_metadata.decoder.missing_soi");
      Register_Routine (T, Decoder_Infers_RGB_Header'Access, "headers_metadata.decoder.header_rgb");
      Register_Routine (T, Decoder_Infers_CMYK_Header'Access, "headers_metadata.decoder.header_cmyk");
      Register_Routine (T, Decoder_Infers_YCCK_Header'Access, "headers_metadata.decoder.header_ycck");
      Register_Routine (T, Decoder_Reports_Metadata_Summaries'Access, "headers_metadata.decoder.metadata_summaries");
      Register_Routine (T, Decoder_Classifies_Metadata_Kinds'Access, "headers_metadata.decoder.metadata_kinds");
      Register_Routine
        (T,
         Decoder_Honors_Discard_Metadata_Policy'Access,
         "headers_metadata.decoder.metadata_discard_policy");
      Register_Routine
        (T,
         Decoder_Streams_Metadata_Callbacks'Access,
         "headers_metadata.decoder.metadata_callback_stream");
      Register_Routine
        (T,
         Decoder_Enforces_Metadata_Callback_Limit'Access,
         "headers_metadata.decoder.metadata_callback_limit");
      Register_Routine
        (T,
         Decoder_Retains_Known_Metadata_Payloads'Access,
         "headers_metadata.decoder.metadata_retain_known");
      Register_Routine
        (T,
         Decoder_Retains_Selected_Metadata_Payloads'Access,
         "headers_metadata.decoder.metadata_retain_selected");
      Register_Routine
        (T,
         Decoder_Retains_All_Metadata_Payloads'Access,
         "headers_metadata.decoder.metadata_retain_all");
      Register_Routine
        (T,
         Decoder_Enforces_Metadata_Retention_Buffer'Access,
         "headers_metadata.decoder.metadata_retain_buffer_limit");
      Register_Routine
        (T,
         Decoder_Applies_Metadata_Policy_To_Unknown_APP'Access,
         "headers_metadata.decoder.metadata_unknown_app_policy");
      Register_Routine
        (T,
         Decoder_Enforces_Metadata_Byte_Limit'Access,
         "headers_metadata.decoder.metadata_limit_bytes");
      Register_Routine
        (T,
         Decoder_Enforces_Metadata_Segment_Count_Limit'Access,
         "headers_metadata.decoder.metadata_limit_segments");
      Register_Routine
        (T,
         Decoder_Enforces_Metadata_Segment_Byte_Limit'Access,
         "headers_metadata.decoder.metadata_limit_segment_bytes");
      Register_Routine (T, Decoder_Tracks_ICC_Profile_Bytes'Access, "headers_metadata.decoder.metadata_icc_bytes");
      Register_Routine
        (T,
         Decoder_Enforces_ICC_Profile_Byte_Limit'Access,
         "headers_metadata.decoder.metadata_limit_icc_bytes");
      Register_Routine
        (T,
         Decoder_Rejects_Duplicate_ICC_Profile_Fragment'Access,
         "headers_metadata.decoder.metadata_icc_duplicate");
      Register_Routine
        (T,
         Decoder_Rejects_Out_Of_Order_ICC_Profile_Fragment'Access,
         "headers_metadata.decoder.metadata_icc_out_of_order");
      Register_Routine
        (T,
         Decoder_Rejects_Incomplete_ICC_Profile'Access,
         "headers_metadata.decoder.metadata_icc_incomplete");
      Register_Routine
        (T,
         Decoder_Parses_Exif_Orientation'Access,
         "headers_metadata.decoder.metadata_exif_orientation");
      Register_Routine (T, Decoder_Caps_Metadata_Summaries'Access, "headers_metadata.decoder.metadata_summary_cap");
      Register_Routine
        (T,
         Decoder_Stress_Streams_Metadata_Callbacks'Access,
         "headers_metadata.decoder.metadata_callback_stress");
   end Register_Tests;

   type Chunked_Read_Source is limited new Jpeglib.Streams.Source with record
      Storage : Jpeglib.Streams.Const_Byte_Array_Access := null;
      Position : Natural := 0;
      Max_Read : Positive := 1;
   end record;

   overriding function Read
     (Object : in out Chunked_Read_Source;
      Buffer : out Jpeglib.Streams.Byte_Array) return Jpeglib.Streams.Source_Result;

   overriding function Offset (Object : Chunked_Read_Source) return Jpeglib.Source_Offset;

   overriding function Skip
     (Object : in out Chunked_Read_Source;
      Count : Jpeglib.Byte_Count) return Jpeglib.Streams.Source_Result;

   overriding function Read
     (Object : in out Chunked_Read_Source;
      Buffer : out Jpeglib.Streams.Byte_Array) return Jpeglib.Streams.Source_Result
   is
      Available : Natural;
      To_Copy : Natural;
   begin
      if Object.Storage = null then
         return (Result => Jpeglib.Errors.Make (Jpeglib.Errors.Source_Read_Failed), Count => 0, End_Of_Input => False);
      end if;

      Available := Object.Storage'Length - Object.Position;
      To_Copy := Natural'Min (Natural'Min (Buffer'Length, Available), Object.Max_Read);

      for I in 0 .. To_Copy - 1 loop
         Buffer (Buffer'First + I) := Object.Storage (Object.Storage'First + Object.Position + I);
      end loop;

      Object.Position := Object.Position + To_Copy;
      return
        (Result => Jpeglib.Errors.Make (Jpeglib.Errors.No_Error),
         Count => Jpeglib.Byte_Count (To_Copy),
         End_Of_Input => To_Copy = 0);
   end Read;

   overriding function Offset (Object : Chunked_Read_Source) return Jpeglib.Source_Offset is
   begin
      return Jpeglib.Source_Offset (Object.Position);
   end Offset;

   overriding function Skip
     (Object : in out Chunked_Read_Source;
      Count : Jpeglib.Byte_Count) return Jpeglib.Streams.Source_Result
   is
      Available : Natural;
      To_Skip : Natural;
   begin
      if Object.Storage = null then
         return (Result => Jpeglib.Errors.Make (Jpeglib.Errors.Source_Read_Failed), Count => 0, End_Of_Input => False);
      end if;

      Available := Object.Storage'Length - Object.Position;
      if Count > Jpeglib.Byte_Count (Natural'Last) then
         To_Skip := Natural'Min (Available, Object.Max_Read);
      else
         To_Skip := Natural'Min (Natural'Min (Natural (Count), Available), Object.Max_Read);
      end if;

      Object.Position := Object.Position + To_Skip;
      return
        (Result => Jpeglib.Errors.Make (Jpeglib.Errors.No_Error),
         Count => Jpeglib.Byte_Count (To_Skip),
         End_Of_Input => To_Skip = 0);
   end Skip;

   procedure SOF_Parser_Derives_Geometry (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOF0_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOF0, 70);
         Frame : constant Jpeglib.Internal.Frames.Frame :=
           Jpeglib.Internal.Frames.Parse_SOF (Segment, Jpeglib.Baseline_DCT);
         Y : constant Jpeglib.Internal.Frames.Frame_Component := Jpeglib.Internal.Frames.Component (Frame, 1);
         Cb : constant Jpeglib.Internal.Frames.Frame_Component := Jpeglib.Internal.Frames.Component (Frame, 2);
      begin
         Assert (Jpeglib.Results.Succeeded (Jpeglib.Internal.Frames.Status (Frame)), "SOF parse failed");
         Assert (Jpeglib.Internal.Frames.Width (Frame) = 17, "width mismatch");
         Assert (Jpeglib.Internal.Frames.Height (Frame) = 9, "height mismatch");
         Assert (Jpeglib.Internal.Frames.Components (Frame) = 3, "component count mismatch");
         Assert (Jpeglib.Internal.Frames.Maximum_Horizontal_Sampling (Frame) = 2, "max H mismatch");
         Assert (Jpeglib.Internal.Frames.Maximum_Vertical_Sampling (Frame) = 2, "max V mismatch");
         Assert (Jpeglib.Internal.Frames.MCU_Columns (Frame) = 2, "MCU columns mismatch");
         Assert (Jpeglib.Internal.Frames.MCU_Rows (Frame) = 1, "MCU rows mismatch");
         Assert (Y.Identifier = 1, "Y identifier mismatch");
         Assert (Y.Component_Width = 17, "Y component width mismatch");
         Assert (Y.Component_Height = 9, "Y component height mismatch");
         Assert (Y.Block_Columns = 3, "Y block columns mismatch");
         Assert (Y.Block_Rows = 2, "Y block rows mismatch");
         Assert (Cb.Identifier = 2, "Cb identifier mismatch");
         Assert (Cb.Component_Width = 9, "Cb component width mismatch");
         Assert (Cb.Component_Height = 5, "Cb component height mismatch");
         Assert (Cb.Block_Columns = 2, "Cb block columns mismatch");
         Assert (Cb.Block_Rows = 1, "Cb block rows mismatch");
      end;
   end SOF_Parser_Derives_Geometry;

   procedure SOF_Parser_Accepts_DNL_Pending_Height (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOF0_Gray_DNL_Pending_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOF0, 75);
         Frame : Jpeglib.Internal.Frames.Frame :=
           Jpeglib.Internal.Frames.Parse_SOF (Segment, Jpeglib.Baseline_DCT);
         Outcome : Jpeglib.Results.Result;
         Component : Jpeglib.Internal.Frames.Frame_Component;
      begin
         Assert
           (Jpeglib.Results.Succeeded (Jpeglib.Internal.Frames.Status (Frame)),
            "DNL-pending SOF parse failed");
         Assert (not Jpeglib.Internal.Frames.Height_Defined (Frame), "DNL-pending height was marked defined");
         Assert (Jpeglib.Internal.Frames.Height (Frame) = 1, "DNL-pending placeholder height mismatch");
         Assert (Jpeglib.Internal.Frames.Width (Frame) = 8, "DNL-pending width mismatch");
         Assert (Jpeglib.Internal.Frames.MCU_Columns (Frame) = 1, "DNL-pending MCU columns mismatch");
         Assert (Jpeglib.Internal.Frames.MCU_Rows (Frame) = 0, "DNL-pending MCU rows mismatch");
         Assert (Jpeglib.Internal.Frames.Total_Blocks (Frame) = 0, "DNL-pending block count mismatch");

         Outcome := Jpeglib.Internal.Frames.Define_Height (Frame, 8);
         Assert (Jpeglib.Results.Succeeded (Outcome), "DNL height resolution failed");
         Component := Jpeglib.Internal.Frames.Component (Frame, 1);
         Assert (Jpeglib.Internal.Frames.Height_Defined (Frame), "DNL-resolved height stayed undefined");
         Assert (Jpeglib.Internal.Frames.Height (Frame) = 8, "DNL-resolved height mismatch");
         Assert (Jpeglib.Internal.Frames.MCU_Rows (Frame) = 1, "DNL-resolved MCU rows mismatch");
         Assert (Jpeglib.Internal.Frames.Total_Blocks (Frame) = 1, "DNL-resolved total blocks mismatch");
         Assert (Component.Component_Width = 8, "DNL-resolved component width mismatch");
         Assert (Component.Component_Height = 8, "DNL-resolved component height mismatch");
         Assert (Component.Block_Columns = 1, "DNL-resolved block columns mismatch");
         Assert (Component.Block_Rows = 1, "DNL-resolved block rows mismatch");
      end;
   end SOF_Parser_Accepts_DNL_Pending_Height;

   procedure SOF_Parser_Rejects_Duplicate_Components (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, Bad_SOF_Duplicate_Component_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOF0, 80);
         Frame : constant Jpeglib.Internal.Frames.Frame :=
           Jpeglib.Internal.Frames.Parse_SOF (Segment, Jpeglib.Baseline_DCT);
      begin
         Assert
           (not Jpeglib.Results.Succeeded (Jpeglib.Internal.Frames.Status (Frame)),
            "duplicate component accepted");
         Assert
           (Jpeglib.Internal.Frames.Status (Frame).First_Error.Code = Jpeglib.Errors.Frame_Invalid_Definition,
            "duplicate component used wrong error");
      end;
   end SOF_Parser_Rejects_Duplicate_Components;

   function Test_Frame return Jpeglib.Internal.Frames.Frame is
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOF0_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOF0, 90);
      begin
         return Jpeglib.Internal.Frames.Parse_SOF (Segment, Jpeglib.Baseline_DCT);
      end;
   end Test_Frame;

   function Progressive_Test_Frame return Jpeglib.Internal.Frames.Frame is
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOF0_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOF2, 91);
      begin
         return Jpeglib.Internal.Frames.Parse_SOF (Segment, Jpeglib.Progressive_DCT);
      end;
   end Progressive_Test_Frame;




   function Progressive_DC_First_Scan
     (Frame : Jpeglib.Internal.Frames.Frame) return Jpeglib.Internal.Scans.Scan
   is
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOS_Progressive_DC_First_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOS, 92);
      begin
         return Jpeglib.Internal.Scans.Parse_SOS (Frame, Segment, Progressive => True);
      end;
   end Progressive_DC_First_Scan;

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

   procedure SOS_Parser_Resolves_Baseline_Scan (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Test_Frame;
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOS_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOS, 100);
         Scan : constant Jpeglib.Internal.Scans.Scan :=
           Jpeglib.Internal.Scans.Parse_SOS (Frame, Segment, Progressive => False);
         First : constant Jpeglib.Internal.Scans.Scan_Component := Jpeglib.Internal.Scans.Component (Scan, 1);
         Second : constant Jpeglib.Internal.Scans.Scan_Component := Jpeglib.Internal.Scans.Component (Scan, 2);
      begin
         Assert (Jpeglib.Results.Succeeded (Jpeglib.Internal.Scans.Status (Scan)), "SOS parse failed");
         Assert (Jpeglib.Internal.Scans.Components (Scan) = 3, "scan component count mismatch");
         Assert (First.Frame_Component = 1, "first component did not resolve to frame component 1");
         Assert (First.DC_Table = 0, "first DC table mismatch");
         Assert (First.AC_Table = 0, "first AC table mismatch");
         Assert (Second.Frame_Component = 2, "second component did not resolve to frame component 2");
         Assert (Second.DC_Table = 1, "second DC table mismatch");
         Assert (Second.AC_Table = 1, "second AC table mismatch");
         Assert (Jpeglib.Internal.Scans.Spectral_Start (Scan) = 0, "spectral start mismatch");
         Assert (Jpeglib.Internal.Scans.Spectral_End (Scan) = 63, "spectral end mismatch");
         Assert (Jpeglib.Internal.Scans.Successive_High (Scan) = 0, "successive high mismatch");
         Assert (Jpeglib.Internal.Scans.Successive_Low (Scan) = 0, "successive low mismatch");
      end;
   end SOS_Parser_Resolves_Baseline_Scan;

   procedure SOS_Parser_Rejects_Unknown_Component (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Test_Frame;
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, Bad_SOS_Unknown_Component_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOS, 110);
         Scan : constant Jpeglib.Internal.Scans.Scan :=
           Jpeglib.Internal.Scans.Parse_SOS (Frame, Segment, Progressive => False);
      begin
         Assert (not Jpeglib.Results.Succeeded (Jpeglib.Internal.Scans.Status (Scan)), "unknown component accepted");
         Assert
           (Jpeglib.Internal.Scans.Status (Scan).First_Error.Code = Jpeglib.Errors.Scan_Invalid_Definition,
            "unknown component used wrong error");
      end;
   end SOS_Parser_Rejects_Unknown_Component;

   procedure SOS_Parser_Rejects_Baseline_Spectral_Range (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Test_Frame;
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, Bad_SOS_Baseline_Spectral_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOS, 120);
         Scan : constant Jpeglib.Internal.Scans.Scan :=
           Jpeglib.Internal.Scans.Parse_SOS (Frame, Segment, Progressive => False);
      begin
         Assert (not Jpeglib.Results.Succeeded (Jpeglib.Internal.Scans.Status (Scan)), "bad spectral range accepted");
         Assert
           (Jpeglib.Internal.Scans.Status (Scan).First_Error.Code = Jpeglib.Errors.Scan_Invalid_Definition,
            "bad spectral range used wrong error");
      end;
   end SOS_Parser_Rejects_Baseline_Spectral_Range;

   procedure SOS_Parser_Accepts_Progressive_DC_First (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Test_Frame;
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOS_Progressive_DC_First_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOS, 121);
         Scan : constant Jpeglib.Internal.Scans.Scan :=
           Jpeglib.Internal.Scans.Parse_SOS (Frame, Segment, Progressive => True);
      begin
         Assert (Jpeglib.Results.Succeeded (Jpeglib.Internal.Scans.Status (Scan)), "progressive DC first rejected");
         Assert (Jpeglib.Internal.Scans.Components (Scan) = 3, "progressive DC component count mismatch");
         Assert (Jpeglib.Internal.Scans.Spectral_Start (Scan) = 0, "progressive DC Ss mismatch");
         Assert (Jpeglib.Internal.Scans.Spectral_End (Scan) = 0, "progressive DC Se mismatch");
         Assert (Jpeglib.Internal.Scans.Successive_High (Scan) = 0, "progressive DC Ah mismatch");
         Assert (Jpeglib.Internal.Scans.Successive_Low (Scan) = 0, "progressive DC Al mismatch");
      end;
   end SOS_Parser_Accepts_Progressive_DC_First;

   procedure SOS_Parser_Accepts_Progressive_AC_First (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Test_Frame;
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOS_Progressive_AC_First_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOS, 122);
         Scan : constant Jpeglib.Internal.Scans.Scan :=
           Jpeglib.Internal.Scans.Parse_SOS (Frame, Segment, Progressive => True);
      begin
         Assert (Jpeglib.Results.Succeeded (Jpeglib.Internal.Scans.Status (Scan)), "progressive AC first rejected");
         Assert (Jpeglib.Internal.Scans.Components (Scan) = 1, "progressive AC component count mismatch");
         Assert (Jpeglib.Internal.Scans.Spectral_Start (Scan) = 1, "progressive AC Ss mismatch");
         Assert (Jpeglib.Internal.Scans.Spectral_End (Scan) = 5, "progressive AC Se mismatch");
         Assert (Jpeglib.Internal.Scans.Successive_High (Scan) = 0, "progressive AC Ah mismatch");
         Assert (Jpeglib.Internal.Scans.Successive_Low (Scan) = 1, "progressive AC Al mismatch");
      end;
   end SOS_Parser_Accepts_Progressive_AC_First;

   procedure SOS_Parser_Accepts_Progressive_AC_Refine (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Test_Frame;
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, SOS_Progressive_AC_Refine_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOS, 123);
         Scan : constant Jpeglib.Internal.Scans.Scan :=
           Jpeglib.Internal.Scans.Parse_SOS (Frame, Segment, Progressive => True);
      begin
         Assert (Jpeglib.Results.Succeeded (Jpeglib.Internal.Scans.Status (Scan)), "progressive AC refine rejected");
         Assert (Jpeglib.Internal.Scans.Components (Scan) = 1, "progressive AC refine component count mismatch");
         Assert (Jpeglib.Internal.Scans.Spectral_Start (Scan) = 1, "progressive AC refine Ss mismatch");
         Assert (Jpeglib.Internal.Scans.Spectral_End (Scan) = 5, "progressive AC refine Se mismatch");
         Assert (Jpeglib.Internal.Scans.Successive_High (Scan) = 1, "progressive AC refine Ah mismatch");
         Assert (Jpeglib.Internal.Scans.Successive_Low (Scan) = 0, "progressive AC refine Al mismatch");
      end;
   end SOS_Parser_Accepts_Progressive_AC_Refine;

   procedure SOS_Parser_Rejects_Progressive_AC_Multi_Component (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Test_Frame;
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, Bad_SOS_Progressive_AC_Multi_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOS, 124);
         Scan : constant Jpeglib.Internal.Scans.Scan :=
           Jpeglib.Internal.Scans.Parse_SOS (Frame, Segment, Progressive => True);
      begin
         Assert (not Jpeglib.Results.Succeeded (Jpeglib.Internal.Scans.Status (Scan)), "multi-component AC accepted");
         Assert
           (Jpeglib.Internal.Scans.Status (Scan).First_Error.Code = Jpeglib.Errors.Scan_Invalid_Definition,
            "multi-component AC used wrong error");
      end;
   end SOS_Parser_Rejects_Progressive_AC_Multi_Component;

   procedure SOS_Parser_Rejects_Progressive_Refine_Gap (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Test_Frame;
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, Bad_SOS_Progressive_Refine_Gap_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOS, 125);
         Scan : constant Jpeglib.Internal.Scans.Scan :=
           Jpeglib.Internal.Scans.Parse_SOS (Frame, Segment, Progressive => True);
      begin
         Assert (not Jpeglib.Results.Succeeded (Jpeglib.Internal.Scans.Status (Scan)), "bad refine gap accepted");
         Assert
           (Jpeglib.Internal.Scans.Status (Scan).First_Error.Code = Jpeglib.Errors.Scan_Invalid_Definition,
            "bad refine gap used wrong error");
      end;
   end SOS_Parser_Rejects_Progressive_Refine_Gap;

   procedure Progressive_State_Accepts_First_And_Refine (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Progressive_Test_Frame;
      DC_First : constant Jpeglib.Internal.Scans.Scan := Progressive_DC_First_Scan (Frame);
      AC_First : constant Jpeglib.Internal.Scans.Scan := Progressive_AC_First_Scan (Frame);
      AC_Refine : constant Jpeglib.Internal.Scans.Scan := Progressive_AC_Refine_Scan (Frame);
      State : Jpeglib.Internal.Progressive.Scan_State;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Internal.Progressive.Reset (State);

      Outcome := Jpeglib.Internal.Progressive.Accept_Scan (State, Frame, DC_First);
      Assert (Jpeglib.Results.Succeeded (Outcome), "progressive state rejected DC first scan");
      Assert (Jpeglib.Internal.Progressive.Coefficient_Seen (State, 1, 0), "component 1 DC not marked seen");
      Assert (Jpeglib.Internal.Progressive.Coefficient_Seen (State, 3, 0), "component 3 DC not marked seen");

      Outcome := Jpeglib.Internal.Progressive.Accept_Scan (State, Frame, AC_First);
      Assert (Jpeglib.Results.Succeeded (Outcome), "progressive state rejected AC first scan");
      Assert (Jpeglib.Internal.Progressive.Coefficient_Seen (State, 1, 1), "first AC coefficient not marked seen");
      Assert (Jpeglib.Internal.Progressive.Coefficient_Seen (State, 1, 5), "last AC coefficient not marked seen");
      Assert
        (not Jpeglib.Internal.Progressive.Coefficient_Seen (State, 1, 6),
         "outside AC range was marked seen");

      Outcome := Jpeglib.Internal.Progressive.Accept_Scan (State, Frame, AC_Refine);
      Assert (Jpeglib.Results.Succeeded (Outcome), "progressive state rejected AC refinement scan");
   end Progressive_State_Accepts_First_And_Refine;

   procedure Progressive_State_Rejects_Duplicate_First (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Progressive_Test_Frame;
      AC_First : constant Jpeglib.Internal.Scans.Scan := Progressive_AC_First_Scan (Frame);
      State : Jpeglib.Internal.Progressive.Scan_State;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Internal.Progressive.Reset (State);

      Outcome := Jpeglib.Internal.Progressive.Accept_Scan (State, Frame, AC_First);
      Assert (Jpeglib.Results.Succeeded (Outcome), "progressive state rejected initial AC first scan");

      Outcome := Jpeglib.Internal.Progressive.Accept_Scan (State, Frame, AC_First);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "duplicate progressive first scan accepted");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Scan_Invalid_Definition,
         "duplicate progressive first scan used wrong error");
   end Progressive_State_Rejects_Duplicate_First;

   procedure Progressive_State_Rejects_Refine_Without_First (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : constant Jpeglib.Internal.Frames.Frame := Progressive_Test_Frame;
      AC_Refine : constant Jpeglib.Internal.Scans.Scan := Progressive_AC_Refine_Scan (Frame);
      State : Jpeglib.Internal.Progressive.Scan_State;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Internal.Progressive.Reset (State);

      Outcome := Jpeglib.Internal.Progressive.Accept_Scan (State, Frame, AC_Refine);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "progressive refinement without first scan accepted");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Scan_Invalid_Definition,
         "progressive refinement without first scan used wrong error");
   end Progressive_State_Rejects_Refine_Without_First;

   procedure DRI_Parser_Reads_Interval (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, DRI_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.DRI, 130);
         Result : constant Jpeglib.Internal.Restarts.DRI_Result :=
           Jpeglib.Internal.Restarts.Read_DRI (Segment);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), "DRI parse failed");
         Assert (Result.Interval = 7, "DRI interval mismatch");
      end;
   end DRI_Parser_Reads_Interval;

   procedure Restart_State_Sequences_Markers (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      State : Jpeglib.Internal.Restarts.Restart_State;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Internal.Restarts.Configure (State, 2);
      Assert (Jpeglib.Internal.Restarts.Interval (State) = 2, "restart interval mismatch");
      Assert (Jpeglib.Internal.Restarts.MCUs_Until_Restart (State) = 2, "initial MCU countdown mismatch");
      Assert
        (Jpeglib.Internal.Restarts.Expected_Marker (State) = Jpeglib.Internal.Markers.RST0,
         "initial expected restart mismatch");

      Outcome := Jpeglib.Internal.Restarts.Advance_MCU (State);
      Assert (Jpeglib.Results.Succeeded (Outcome), "first MCU advance failed");
      Outcome := Jpeglib.Internal.Restarts.Advance_MCU (State);
      Assert (Jpeglib.Results.Succeeded (Outcome), "second MCU advance failed");
      Assert (Jpeglib.Internal.Restarts.MCUs_Until_Restart (State) = 0, "restart countdown did not reach zero");

      Outcome := Jpeglib.Internal.Restarts.Advance_MCU (State);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "MCU advance past restart boundary succeeded");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Restart_Invalid_State,
         "restart boundary used wrong error");

      Outcome := Jpeglib.Internal.Restarts.Accept_Restart (State, Jpeglib.Internal.Markers.RST0, 200);
      Assert (Jpeglib.Results.Succeeded (Outcome), "expected restart was rejected");
      Assert (Jpeglib.Internal.Restarts.MCUs_Until_Restart (State) = 2, "restart did not reload interval");
      Assert
        (Jpeglib.Internal.Restarts.Expected_Marker (State) = Jpeglib.Internal.Markers.RST1,
         "restart marker did not advance");

      Outcome := Jpeglib.Internal.Restarts.Accept_Restart (State, Jpeglib.Internal.Markers.RST3, 201);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "wrong restart marker accepted");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Restart_Invalid_State,
         "wrong restart marker used wrong error");
   end Restart_State_Sequences_Markers;

   procedure Entropy_Reader_Classifies_Markers (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Jpeglib.Internal.Bit_Streams;
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, Entropy_Storage'Access);
      declare
         Reader : Entropy_Reader (Source'Access);
         Result : Entropy_Read_Result;
         Pending : Jpeglib.Internal.Markers.Marker_Result;
      begin
         Result := Read_Byte (Reader);
         Assert (Result.Kind = Entropy_Data and then Result.Value = 16#11#, "first entropy byte mismatch");
         Result := Read_Byte (Reader);
         Assert (Result.Kind = Entropy_Data and then Result.Value = 16#FF#, "stuffed FF was not returned as data");
         Result := Read_Byte (Reader);
         Assert (Result.Kind = Entropy_Data and then Result.Value = 16#22#, "third entropy byte mismatch");
         Result := Read_Byte (Reader);
         Assert
           (Result.Kind = Restart_Marker and then Result.Marker = Jpeglib.Internal.Markers.RST0,
            "restart marker was not classified");
         Result := Read_Byte (Reader);
         Assert (Result.Kind = Entropy_Data and then Result.Value = 16#33#, "post-restart entropy byte mismatch");
         Result := Read_Byte (Reader);
         Assert
           (Result.Kind = Scan_Ending_Marker and then Result.Marker = Jpeglib.Internal.Markers.EOI,
            "scan-ending marker was not classified");
         Assert (Has_Pending_Marker (Reader), "pending marker not retained");
         Pending := Take_Pending_Marker (Reader);
         Assert (Pending.Marker = Jpeglib.Internal.Markers.EOI, "pending marker mismatch");
         Assert (not Has_Pending_Marker (Reader), "pending marker was not handed back exactly once");
         Result := Read_Byte (Reader);
         Assert (Result.Kind = Entropy_Data and then Result.Value = 16#44#, "reader did not resume after handoff");
      end;
   end Entropy_Reader_Classifies_Markers;

   procedure Decoder_Reads_Structural_Header (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Jpeglib.Decoding.Decoder_State;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Header : Jpeglib.Decoding.Image_Info;
   begin
      Jpeglib.Streams.Open (Source, Minimal_Header_Storage'Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (Jpeglib.Results.Succeeded (Outcome), "public header read failed");
      Assert (Jpeglib.Decoding.State (Decoder) = Jpeglib.Decoding.Header_Ready, "decoder state mismatch");
      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Width = 17, "decoder header width mismatch");
      Assert (Header.Height = 9, "decoder header height mismatch");
      Assert (Header.Components = 3, "decoder header components mismatch");
      Assert (Header.Mode = Jpeglib.Baseline_DCT, "decoder frame mode mismatch");
      Assert (not Header.Progressive, "baseline header marked progressive");
      Assert (Header.Color_Model = Jpeglib.YCbCr, "decoder header color model mismatch");
      Assert (Header.Restart = 7, "decoder restart interval mismatch");
      Assert (Header.Coefficient_Blocks = 12, "decoder coefficient block count mismatch");
   end Decoder_Reads_Structural_Header;

   procedure Decoder_Rejects_Missing_SOI (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Jpeglib.Decoding.Decoder_State;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Source, Bad_Header_No_SOI_Storage'Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "missing SOI was accepted");
      Assert (Jpeglib.Decoding.State (Decoder) = Jpeglib.Decoding.Failed, "decoder did not fail");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Marker_Unexpected,
         "missing SOI used wrong error");
   end Decoder_Rejects_Missing_SOI;

   procedure Decoder_Infers_RGB_Header (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Header : Jpeglib.Decoding.Image_Info;
   begin
      Jpeglib.Streams.Open (Source, RGB_Header_Storage'Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (Jpeglib.Results.Succeeded (Outcome), "RGB header read failed");
      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Components = 3, "RGB header component count mismatch");
      Assert (Header.Color_Model = Jpeglib.RGB, "RGB header color model mismatch");
   end Decoder_Infers_RGB_Header;

   procedure Decoder_Infers_CMYK_Header (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Header : Jpeglib.Decoding.Image_Info;
   begin
      Jpeglib.Streams.Open (Source, CMYK_Header_Storage'Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (Jpeglib.Results.Succeeded (Outcome), "CMYK header read failed");
      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Components = 4, "CMYK header component count mismatch");
      Assert (Header.Color_Model = Jpeglib.CMYK, "CMYK header color model mismatch");
   end Decoder_Infers_CMYK_Header;

   procedure Decoder_Infers_YCCK_Header (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Header : Jpeglib.Decoding.Image_Info;
   begin
      Jpeglib.Streams.Open (Source, YCCK_Header_Storage'Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (Jpeglib.Results.Succeeded (Outcome), "YCCK header read failed");
      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Components = 4, "YCCK header component count mismatch");
      Assert (Header.Color_Model = Jpeglib.YCCK, "YCCK header color model mismatch");
      Assert (Header.Metadata_Segments = 1, "YCCK APP14 metadata segment count mismatch");
   end Decoder_Infers_YCCK_Header;

   procedure Decoder_Reports_Metadata_Summaries (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Header : Jpeglib.Decoding.Image_Info;
   begin
      Jpeglib.Streams.Open (Source, Metadata_Header_Storage'Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (Jpeglib.Results.Succeeded (Outcome), "metadata header read failed");
      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Metadata_Segments = 3, "metadata segment count mismatch");
      Assert (Header.Metadata_Bytes = 13, "metadata byte count mismatch");
      Assert (Header.Retained_Metadata_Summaries = 3, "metadata summary count mismatch");
      Assert (Header.Metadata_Summaries (1).Marker = Jpeglib.Internal.Markers.APP0, "APP0 summary marker mismatch");
      Assert (Header.Metadata_Summaries (1).Kind = Jpeglib.Metadata.JFIF, "APP0 summary kind mismatch");
      Assert (Header.Metadata_Summaries (1).Payload_Length = 5, "APP0 summary length mismatch");
      Assert (Header.Metadata_Summaries (2).Marker = Jpeglib.Internal.Markers.COM, "COM summary marker mismatch");
      Assert (Header.Metadata_Summaries (2).Kind = Jpeglib.Metadata.Comment, "COM summary kind mismatch");
      Assert (Header.Metadata_Summaries (2).Payload_Length = 3, "COM summary length mismatch");
      Assert (Header.Metadata_Summaries (3).Marker = Jpeglib.Internal.Markers.APP14, "APP14 summary marker mismatch");
      Assert (Header.Metadata_Summaries (3).Kind = Jpeglib.Metadata.Adobe_APP14, "APP14 summary kind mismatch");
      Assert (Header.Metadata_Summaries (3).Payload_Length = 5, "APP14 summary length mismatch");
   end Decoder_Reports_Metadata_Summaries;

   procedure Decoder_Classifies_Metadata_Kinds (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Header : Jpeglib.Decoding.Image_Info;
   begin
      Jpeglib.Streams.Open (Source, Metadata_Kinds_Header_Storage'Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (Jpeglib.Results.Succeeded (Outcome), "metadata kind header read failed");
      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Metadata_Segments = 6, "metadata kind segment count mismatch");
      Assert (Header.Retained_Metadata_Summaries = 6, "metadata kind summary count mismatch");
      Assert (Header.Metadata_Summaries (1).Kind = Jpeglib.Metadata.JFXX, "JFXX kind mismatch");
      Assert (Header.Metadata_Summaries (2).Kind = Jpeglib.Metadata.Exif, "Exif kind mismatch");
      Assert (Header.Metadata_Summaries (3).Kind = Jpeglib.Metadata.ICC, "ICC kind mismatch");
      Assert (Header.Metadata_Summaries (4).Kind = Jpeglib.Metadata.XMP, "XMP kind mismatch");
      Assert (Header.Metadata_Summaries (5).Kind = Jpeglib.Metadata.Extended_XMP, "Extended XMP kind mismatch");
      Assert
        (Header.Metadata_Summaries (6).Kind = Jpeglib.Metadata.Photoshop_APP13,
         "Photoshop APP13 kind mismatch");
   end Decoder_Classifies_Metadata_Kinds;

   procedure Decoder_Honors_Discard_Metadata_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Header : Jpeglib.Decoding.Image_Info;
   begin
      Jpeglib.Streams.Open (Source, Metadata_Header_Storage'Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         Decode_Options => (Metadata => Jpeglib.Metadata.Discard_All, others => <>));
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (Jpeglib.Results.Succeeded (Outcome), "metadata discard header read failed");
      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Metadata_Segments = 3, "discard policy segment count mismatch");
      Assert (Header.Metadata_Bytes = 13, "discard policy byte count mismatch");
      Assert (Header.Retained_Metadata_Summaries = 0, "discard policy retained summaries");
   end Decoder_Honors_Discard_Metadata_Policy;

   procedure Decoder_Streams_Metadata_Callbacks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Header : Jpeglib.Decoding.Image_Info;
   begin
      Reset_Metadata_Callback_State;
      Jpeglib.Streams.Open (Source, Metadata_Header_Storage'Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         Decode_Options =>
           (Metadata => Jpeglib.Metadata.Stream_To_Callback,
            Metadata_Callback => Capture_Metadata_Callback'Access,
            others => <>));
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (Jpeglib.Results.Succeeded (Outcome), "metadata callback header read failed");
      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Metadata_Segments = 3, "metadata callback segment count mismatch");
      Assert (Header.Metadata_Bytes = 13, "metadata callback byte count mismatch");
      Assert (Callback_Begin_Count = 3, "metadata callback begin count mismatch");
      Assert (Callback_Data_Count = 13, "metadata callback data count mismatch");
      Assert (Callback_End_Count = 3, "metadata callback end count mismatch");
      Assert (Callback_Event_Count = 19, "metadata callback event count mismatch");
      Assert (Callback_Data_Bytes = 13, "metadata callback data byte count mismatch");
      Assert (Callback_Data_Sum = 960, "metadata callback payload checksum mismatch");
   end Decoder_Streams_Metadata_Callbacks;

   procedure Decoder_Enforces_Metadata_Callback_Limit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Tight_Limits : Jpeglib.Limits.Limit_Set := Jpeglib.Limits.Default_Limits;
   begin
      Reset_Metadata_Callback_State;
      Tight_Limits.Max_Metadata_Callbacks := 18;
      Jpeglib.Streams.Open (Source, Metadata_Header_Storage'Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         Decode_Options =>
           (Metadata => Jpeglib.Metadata.Stream_To_Callback,
            Metadata_Callback => Capture_Metadata_Callback'Access,
            others => <>),
         Decode_Limits => Tight_Limits);
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "metadata callback limit was not enforced");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Metadata_Limit_Exceeded,
         "metadata callback limit used wrong error");
      Assert (Callback_Event_Count = 18, "metadata callback limit event count mismatch");
   end Decoder_Enforces_Metadata_Callback_Limit;

   procedure Decoder_Retains_Known_Metadata_Payloads (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Header : Jpeglib.Decoding.Image_Info;
      Buffer : aliased Jpeglib.Streams.Byte_Array := [1 .. 16 => 0];
   begin
      Jpeglib.Streams.Open (Source, Metadata_Header_Storage'Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         Decode_Options =>
           (Metadata => Jpeglib.Metadata.Preserve_Known,
            Metadata_Buffer => Buffer'Unchecked_Access,
            others => <>));
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (Jpeglib.Results.Succeeded (Outcome), "known metadata retention header read failed");
      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Metadata_Segments = 3, "known metadata retention segment count mismatch");
      Assert (Header.Retained_Metadata_Bytes = 13, "known metadata retained byte count mismatch");
      Assert (Buffer (1 .. 5) = [16#4A#, 16#46#, 16#49#, 16#46#, 0], "retained JFIF payload mismatch");
      Assert (Buffer (6 .. 8) = [16#41#, 16#42#, 16#43#], "retained COM payload mismatch");
      Assert (Buffer (9 .. 13) = [16#41#, 16#64#, 16#6F#, 16#62#, 16#65#], "retained Adobe payload mismatch");
      Assert (Header.Metadata_Summaries (1).Payload_Offset = 0, "JFIF payload offset mismatch");
      Assert (Header.Metadata_Summaries (1).Retained_Length = 5, "JFIF retained length mismatch");
      Assert (Header.Metadata_Summaries (2).Payload_Offset = 5, "COM payload offset mismatch");
      Assert (Header.Metadata_Summaries (2).Retained_Length = 3, "COM retained length mismatch");
      Assert (Header.Metadata_Summaries (3).Payload_Offset = 8, "Adobe payload offset mismatch");
      Assert (Header.Metadata_Summaries (3).Retained_Length = 5, "Adobe retained length mismatch");
   end Decoder_Retains_Known_Metadata_Payloads;

   procedure Decoder_Retains_Selected_Metadata_Payloads (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Header : Jpeglib.Decoding.Image_Info;
      Buffer : aliased Jpeglib.Streams.Byte_Array := [1 .. 4 => 0];
   begin
      Jpeglib.Streams.Open (Source, Metadata_Header_Storage'Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         Decode_Options =>
           (Metadata => Jpeglib.Metadata.Preserve_Selected,
            Selected_Metadata => [Jpeglib.Metadata.Comment => True, others => False],
            Metadata_Buffer => Buffer'Unchecked_Access,
            others => <>));
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (Jpeglib.Results.Succeeded (Outcome), "selected metadata retention header read failed");
      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Metadata_Segments = 3, "selected metadata retention segment count mismatch");
      Assert (Header.Metadata_Bytes = 13, "selected metadata byte count mismatch");
      Assert (Header.Retained_Metadata_Bytes = 3, "selected metadata retained byte count mismatch");
      Assert (Header.Retained_Metadata_Summaries = 1, "selected metadata retained summary count mismatch");
      Assert (Header.Metadata_Summaries (1).Kind = Jpeglib.Metadata.Comment, "selected metadata kind mismatch");
      Assert (Header.Metadata_Summaries (1).Payload_Offset = 0, "selected metadata retained offset mismatch");
      Assert (Header.Metadata_Summaries (1).Retained_Length = 3, "selected metadata retained length mismatch");
      Assert (Buffer (1 .. 3) = [16#41#, 16#42#, 16#43#], "selected metadata retained payload mismatch");
   end Decoder_Retains_Selected_Metadata_Payloads;

   procedure Decoder_Retains_All_Metadata_Payloads (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Header : Jpeglib.Decoding.Image_Info;
      Buffer : aliased Jpeglib.Streams.Byte_Array := [1 .. 4 => 0];
   begin
      Jpeglib.Streams.Open (Source, Unknown_Metadata_Header_Storage'Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         Decode_Options =>
           (Metadata => Jpeglib.Metadata.Preserve_All_Bounded,
            Metadata_Buffer => Buffer'Unchecked_Access,
            others => <>));
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (Jpeglib.Results.Succeeded (Outcome), "all metadata retention header read failed");
      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Metadata_Segments = 1, "all metadata retention segment count mismatch");
      Assert (Header.Retained_Metadata_Bytes = 3, "all metadata retained byte count mismatch");
      Assert (Header.Retained_Metadata_Summaries = 1, "all metadata retained summary count mismatch");
      Assert (Header.Metadata_Summaries (1).Kind = Jpeglib.Metadata.Unknown_APP, "all metadata retained kind mismatch");
      Assert (Header.Metadata_Summaries (1).Payload_Offset = 0, "all metadata retained offset mismatch");
      Assert (Header.Metadata_Summaries (1).Retained_Length = 3, "all metadata retained length mismatch");
      Assert (Buffer (1 .. 3) = [16#41#, 16#42#, 16#43#], "all metadata retained payload mismatch");
   end Decoder_Retains_All_Metadata_Payloads;

   procedure Decoder_Enforces_Metadata_Retention_Buffer (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Buffer : aliased Jpeglib.Streams.Byte_Array := [1 .. 4 => 0];
   begin
      Jpeglib.Streams.Open (Source, Metadata_Header_Storage'Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         Decode_Options =>
           (Metadata => Jpeglib.Metadata.Preserve_Known,
            Metadata_Buffer => Buffer'Unchecked_Access,
            others => <>));
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "metadata retention buffer overflow was accepted");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Metadata_Limit_Exceeded,
         "metadata retention buffer overflow used wrong error");
   end Decoder_Enforces_Metadata_Retention_Buffer;

   procedure Decoder_Applies_Metadata_Policy_To_Unknown_APP (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source_Default : aliased Jpeglib.Streams.Memory_Source;
      Source_Preserve_All : aliased Jpeglib.Streams.Memory_Source;
      Default_Decoder : Jpeglib.Decoding.Decoder;
      Preserve_All_Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Header : Jpeglib.Decoding.Image_Info;
   begin
      Jpeglib.Streams.Open (Source_Default, Unknown_Metadata_Header_Storage'Access);
      Jpeglib.Decoding.Initialize (Default_Decoder, Source_Default'Access);
      Outcome := Jpeglib.Decoding.Read_Header (Default_Decoder);
      Assert (Jpeglib.Results.Succeeded (Outcome), "unknown APP default header read failed");
      Header := Jpeglib.Decoding.Header (Default_Decoder);
      Assert (Header.Metadata_Segments = 1, "unknown APP default segment count mismatch");
      Assert (Header.Metadata_Bytes = 3, "unknown APP default byte count mismatch");
      Assert (Header.Retained_Metadata_Summaries = 0, "unknown APP default retained summary");

      Jpeglib.Streams.Open (Source_Preserve_All, Unknown_Metadata_Header_Storage'Access);
      Jpeglib.Decoding.Initialize
        (Preserve_All_Decoder,
         Source_Preserve_All'Access,
         Decode_Options => (Metadata => Jpeglib.Metadata.Preserve_All_Bounded, others => <>));
      Outcome := Jpeglib.Decoding.Read_Header (Preserve_All_Decoder);
      Assert (Jpeglib.Results.Succeeded (Outcome), "unknown APP preserve-all header read failed");
      Header := Jpeglib.Decoding.Header (Preserve_All_Decoder);
      Assert (Header.Metadata_Segments = 1, "unknown APP preserve-all segment count mismatch");
      Assert (Header.Retained_Metadata_Summaries = 1, "unknown APP preserve-all retained summary count mismatch");
      Assert (Header.Metadata_Summaries (1).Kind = Jpeglib.Metadata.Unknown_APP, "unknown APP kind mismatch");
      Assert (Header.Metadata_Summaries (1).Payload_Length = 3, "unknown APP length mismatch");
   end Decoder_Applies_Metadata_Policy_To_Unknown_APP;

   procedure Decoder_Enforces_Metadata_Byte_Limit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Tight_Limits : Jpeglib.Limits.Limit_Set := Jpeglib.Limits.Default_Limits;
   begin
      Tight_Limits.Max_Metadata_Bytes := 4;
      Jpeglib.Streams.Open (Source, Metadata_Header_Storage'Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access, Decode_Limits => Tight_Limits);
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "metadata byte limit was not enforced");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Metadata_Limit_Exceeded,
         "metadata byte limit used wrong error");
   end Decoder_Enforces_Metadata_Byte_Limit;

   procedure Decoder_Enforces_Metadata_Segment_Count_Limit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Tight_Limits : Jpeglib.Limits.Limit_Set := Jpeglib.Limits.Default_Limits;
   begin
      Tight_Limits.Max_Metadata_Segments := 2;
      Jpeglib.Streams.Open (Source, Metadata_Header_Storage'Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access, Decode_Limits => Tight_Limits);
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "metadata segment count limit was not enforced");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Metadata_Limit_Exceeded,
         "metadata segment count limit used wrong error");
   end Decoder_Enforces_Metadata_Segment_Count_Limit;

   procedure Decoder_Enforces_Metadata_Segment_Byte_Limit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Tight_Limits : Jpeglib.Limits.Limit_Set := Jpeglib.Limits.Default_Limits;
   begin
      Tight_Limits.Max_Metadata_Segment_Bytes := 4;
      Jpeglib.Streams.Open (Source, Metadata_Header_Storage'Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access, Decode_Limits => Tight_Limits);
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "metadata segment byte limit was not enforced");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Metadata_Limit_Exceeded,
         "metadata segment byte limit used wrong error");
   end Decoder_Enforces_Metadata_Segment_Byte_Limit;

   procedure Decoder_Tracks_ICC_Profile_Bytes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Header : Jpeglib.Decoding.Image_Info;
      Buffer : aliased Jpeglib.Streams.Byte_Array := [1 .. 4 => 0];
   begin
      Jpeglib.Streams.Open (Source, ICC_Fragmented_Header_Storage'Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         Decode_Options =>
           (Metadata => Jpeglib.Metadata.Preserve_Known,
            Metadata_Buffer => Buffer'Unchecked_Access,
            others => <>));
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (Jpeglib.Results.Succeeded (Outcome), "fragmented ICC header read failed");
      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Metadata_Segments = 2, "fragmented ICC metadata segment count mismatch");
      Assert (Header.Metadata_Bytes = 32, "fragmented ICC metadata byte count mismatch");
      Assert (Header.Retained_Metadata_Bytes = 4, "fragmented ICC retained byte count mismatch");
      Assert (Header.ICC_Profile_Bytes = 4, "fragmented ICC byte count mismatch");
      Assert (Header.ICC_Profile_Fragments = 2, "fragmented ICC fragment count mismatch");
      Assert (Header.ICC_Profile_Fragment_Count = 2, "fragmented ICC declared count mismatch");
      Assert (Header.Retained_Metadata_Summaries = 2, "fragmented ICC summary count mismatch");
      Assert (Header.Metadata_Summaries (1).Kind = Jpeglib.Metadata.ICC, "first ICC kind mismatch");
      Assert (Header.Metadata_Summaries (2).Kind = Jpeglib.Metadata.ICC, "second ICC kind mismatch");
      Assert (Header.Metadata_Summaries (1).Payload_Offset = 0, "first ICC retained offset mismatch");
      Assert (Header.Metadata_Summaries (1).Retained_Length = 2, "first ICC retained length mismatch");
      Assert (Header.Metadata_Summaries (2).Payload_Offset = 2, "second ICC retained offset mismatch");
      Assert (Header.Metadata_Summaries (2).Retained_Length = 2, "second ICC retained length mismatch");
      Assert (Buffer = [16#41#, 16#42#, 16#43#, 16#44#], "assembled ICC profile payload mismatch");
   end Decoder_Tracks_ICC_Profile_Bytes;

   procedure Decoder_Enforces_ICC_Profile_Byte_Limit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Tight_Limits : Jpeglib.Limits.Limit_Set := Jpeglib.Limits.Default_Limits;
   begin
      Tight_Limits.Max_ICC_Profile_Bytes := 3;
      Jpeglib.Streams.Open (Source, ICC_Fragmented_Header_Storage'Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access, Decode_Limits => Tight_Limits);
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "ICC byte limit was not enforced");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Metadata_Limit_Exceeded,
         "ICC byte limit used wrong error");
   end Decoder_Enforces_ICC_Profile_Byte_Limit;

   procedure Decoder_Rejects_Duplicate_ICC_Profile_Fragment (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Source, ICC_Duplicate_Header_Storage'Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "duplicate ICC fragment was accepted");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Metadata_Limit_Exceeded,
         "duplicate ICC fragment used wrong error");
   end Decoder_Rejects_Duplicate_ICC_Profile_Fragment;

   procedure Decoder_Rejects_Out_Of_Order_ICC_Profile_Fragment (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Source, ICC_Out_Of_Order_Header_Storage'Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "out-of-order ICC fragment was accepted");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Metadata_Limit_Exceeded,
         "out-of-order ICC fragment used wrong error");
   end Decoder_Rejects_Out_Of_Order_ICC_Profile_Fragment;

   procedure Decoder_Rejects_Incomplete_ICC_Profile (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Source, ICC_Incomplete_Header_Storage'Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "incomplete ICC profile was accepted");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Metadata_Limit_Exceeded,
         "incomplete ICC profile used wrong error");
   end Decoder_Rejects_Incomplete_ICC_Profile;

   procedure Decoder_Parses_Exif_Orientation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Header : Jpeglib.Decoding.Image_Info;
   begin
      Jpeglib.Streams.Open (Source, Exif_Orientation_Header_Storage'Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (Jpeglib.Results.Succeeded (Outcome), "Exif orientation header read failed");
      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Metadata_Segments = 1, "Exif orientation metadata count mismatch");
      Assert (Header.Has_Exif_Orientation, "Exif orientation was not detected");
      Assert
        (Header.Exif_Orientation = Jpeglib.Metadata.Orientation_Rotate_90,
         "Exif orientation value mismatch");
   end Decoder_Parses_Exif_Orientation;

   procedure Decoder_Caps_Metadata_Summaries (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Header : Jpeglib.Decoding.Image_Info;
   begin
      Jpeglib.Streams.Open (Source, Many_Metadata_Header_Storage'Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (Jpeglib.Results.Succeeded (Outcome), "many metadata header read failed");
      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Metadata_Segments = 17, "many metadata segment count mismatch");
      Assert (Header.Metadata_Bytes = 17, "many metadata byte count mismatch");
      Assert
        (Header.Retained_Metadata_Summaries = Jpeglib.Metadata.Max_Header_Summaries,
         "metadata summary cap mismatch");
      Assert (Header.Metadata_Summaries (16).Payload_Length = 1, "last retained metadata length mismatch");
   end Decoder_Caps_Metadata_Summaries;

   procedure Decoder_Stress_Streams_Metadata_Callbacks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Chunked_Read_Source :=
        (Storage => Many_Metadata_Header_Storage'Access, Position => 0, Max_Read => 1);
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Header : Jpeglib.Decoding.Image_Info;
   begin
      Reset_Metadata_Callback_State;
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         Decode_Options =>
           (Metadata => Jpeglib.Metadata.Stream_To_Callback,
            Metadata_Callback => Capture_Metadata_Callback'Access,
            others => <>));
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      Assert (Jpeglib.Results.Succeeded (Outcome), "metadata callback stress header read failed");
      Header := Jpeglib.Decoding.Header (Decoder);
      Assert (Header.Metadata_Segments = 17, "metadata callback stress segment count mismatch");
      Assert (Header.Metadata_Bytes = 17, "metadata callback stress byte count mismatch");
      Assert (Callback_Begin_Count = 17, "metadata callback stress begin count mismatch");
      Assert (Callback_Data_Count = 17, "metadata callback stress data event count mismatch");
      Assert (Callback_End_Count = 17, "metadata callback stress end count mismatch");
      Assert (Callback_Event_Count = 51, "metadata callback stress event count mismatch");
      Assert (Callback_Data_Bytes = 17, "metadata callback stress byte count mismatch");
      Assert (Callback_Data_Sum = 153, "metadata callback stress checksum mismatch");
   end Decoder_Stress_Streams_Metadata_Callbacks;
end Jpeglib_Testing.Test_Headers_Metadata;

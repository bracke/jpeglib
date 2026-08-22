with AUnit.Assertions;

with Jpeglib;
with Jpeglib.Coefficients;
with Jpeglib.Errors;
with Jpeglib.Internal.Arithmetic;
with Jpeglib.Internal.Bit_Streams;
with Jpeglib.Internal.Coefficients;
with Jpeglib.Internal.Frames;
with Jpeglib.Internal.Markers;
with Jpeglib.Internal.Scans;
with Jpeglib.Internal.Segments;
with Jpeglib.Results;
with Jpeglib.Streams;

package body Jpeglib_Testing.Test_Arithmetic is
   use AUnit.Assertions;
   use type Jpeglib.Marker_Code;
   use type Jpeglib.Block_Count;
   use type Jpeglib.Errors.Error_Code;
   use type Jpeglib.Internal.Bit_Streams.Bit_Value;
   use type Jpeglib.Internal.Arithmetic.Conditioning_Value;
   use type Jpeglib.Internal.Arithmetic.DC_Difference;
   use type Jpeglib.Coefficients.DCT_Block;
   use type Jpeglib.Coefficients.Quantized_Coefficient;

   SOF2_Gray_8x8_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 11,
      8, 0, 8, 0, 8, 1,
      1, 16#11#, 0];
   SOS_Gray_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 8,
      1,
      1, 16#00#,
      0, 63, 0];

   function Gray_Scan
     (Frame : Jpeglib.Internal.Frames.Frame) return Jpeglib.Internal.Scans.Scan;

   procedure Arithmetic_DAC_Parser_Stores_Tables (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Arithmetic_DAC_Parser_Rejects_Invalid_Definitions (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Arithmetic_Decoder_Decodes_Binary_Decisions (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Arithmetic_Encoder_Maps_DC_Difference_Decisions (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Arithmetic_Encoder_Maps_DC_Difference_Events (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Arithmetic_Encoder_Emits_DC_Differences (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Arithmetic_Encoder_Emits_Sequential_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Arithmetic_Decoder_Decodes_DC_Difference (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Arithmetic_Decoder_Decodes_AC_EOB (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Arithmetic_Decoder_Decodes_Progressive_AC_Refine_Magnitude
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Arithmetic_Decoder_Decodes_DC_EOB_Block (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Arithmetic_Decoder_Decodes_Sequential_Block (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Arithmetic_Decoder_Decodes_DC_EOB_Scan (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Arithmetic_Decoder_Decodes_Color_DC_EOB_Scan (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Arithmetic_Decoder_Decodes_Sequential_Scan (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Arithmetic_Decoder_Decodes_Color_Sequential_Scan
     (T : in out AUnit.Test_Cases.Test_Case'Class);

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

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("arithmetic");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Arithmetic_DAC_Parser_Stores_Tables'Access, "foundation.arithmetic.dac_parse");
      Register_Routine
        (T,
         Arithmetic_DAC_Parser_Rejects_Invalid_Definitions'Access,
         "foundation.arithmetic.dac_invalid");
      Register_Routine
        (T,
         Arithmetic_Decoder_Decodes_Binary_Decisions'Access,
         "foundation.arithmetic.decode_binary");
      Register_Routine
        (T,
         Arithmetic_Encoder_Maps_DC_Difference_Decisions'Access,
         "foundation.arithmetic.encode_dc_difference_decisions");
      Register_Routine
        (T,
         Arithmetic_Encoder_Maps_DC_Difference_Events'Access,
         "foundation.arithmetic.encode_dc_difference_events");
      Register_Routine
        (T,
         Arithmetic_Encoder_Emits_DC_Differences'Access,
         "foundation.arithmetic.emit_dc_difference");
      Register_Routine
        (T,
         Arithmetic_Encoder_Emits_Sequential_Blocks'Access,
         "foundation.arithmetic.emit_sequential_blocks");
      Register_Routine
        (T,
         Arithmetic_Decoder_Decodes_DC_Difference'Access,
         "foundation.arithmetic.decode_dc_difference");
      Register_Routine
        (T,
         Arithmetic_Decoder_Decodes_AC_EOB'Access,
         "foundation.arithmetic.decode_ac_eob");
      Register_Routine
        (T,
         Arithmetic_Decoder_Decodes_DC_EOB_Block'Access,
         "foundation.arithmetic.decode_dc_eob_block");
      Register_Routine
        (T,
         Arithmetic_Decoder_Decodes_Sequential_Block'Access,
         "foundation.arithmetic.decode_sequential_block");
      Register_Routine
        (T,
         Arithmetic_Decoder_Decodes_DC_EOB_Scan'Access,
         "foundation.arithmetic.decode_dc_eob_scan");
      Register_Routine
        (T,
         Arithmetic_Decoder_Decodes_Color_DC_EOB_Scan'Access,
         "foundation.arithmetic.decode_color_dc_eob_scan");
      Register_Routine
        (T,
         Arithmetic_Decoder_Decodes_Sequential_Scan'Access,
         "foundation.arithmetic.decode_sequential_scan");
      Register_Routine
        (T,
         Arithmetic_Decoder_Decodes_Color_Sequential_Scan'Access,
         "foundation.arithmetic.decode_color_sequential_scan");
      Register_Routine
        (T,
         Arithmetic_Decoder_Decodes_Progressive_AC_Refine_Magnitude'Access,
         "foundation.arithmetic.decode_progressive_ac_refine_magnitude");
   end Register_Tests;

   procedure Arithmetic_DAC_Parser_Stores_Tables (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      State : Jpeglib.Internal.Arithmetic.Arithmetic_State;
      Outcome : Jpeglib.Results.Result;
      Storage : aliased constant Jpeglib.Streams.Byte_Array :=
        [0, 6,
         16#00#, 16#5A#,
         16#11#, 16#2A#];
   begin
      Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);

      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.DAC, 0);
      begin
         Outcome := Jpeglib.Internal.Arithmetic.Parse_DAC (State, Segment);
      end;

      Assert (Jpeglib.Results.Succeeded (Outcome), "DAC parse failed");
      Assert
        (Jpeglib.Internal.Arithmetic.Has_Table (State, Jpeglib.Internal.Arithmetic.DC, 0),
         "DAC parser did not store DC table");
      Assert
        (Jpeglib.Internal.Arithmetic.Has_Table (State, Jpeglib.Internal.Arithmetic.AC, 1),
         "DAC parser did not store AC table");
      Assert
        (Jpeglib.Internal.Arithmetic.Value (State, Jpeglib.Internal.Arithmetic.DC, 0) = 16#5A#,
         "DAC parser stored wrong DC value");
      Assert
        (Jpeglib.Internal.Arithmetic.Value (State, Jpeglib.Internal.Arithmetic.AC, 1) = 16#2A#,
         "DAC parser stored wrong AC value");
      Assert
        (Jpeglib.Internal.Arithmetic.DC_Lower_Bound (16#5A#) = 5,
         "DAC DC lower bound mismatch");
      Assert
        (Jpeglib.Internal.Arithmetic.DC_Upper_Bound (16#5A#) = 10,
         "DAC DC upper bound mismatch");
   end Arithmetic_DAC_Parser_Stores_Tables;

   procedure Arithmetic_DAC_Parser_Rejects_Invalid_Definitions (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      procedure Rejects (Storage : Jpeglib.Streams.Byte_Array; Label : String) is
         Local : aliased Jpeglib.Streams.Byte_Array := Storage;
         Source : aliased Jpeglib.Streams.Memory_Source;
         State : Jpeglib.Internal.Arithmetic.Arithmetic_State;
         Outcome : Jpeglib.Results.Result;
      begin
         Jpeglib.Streams.Open (Source, Local'Unchecked_Access);

         declare
            Segment : Jpeglib.Internal.Segments.Segment_Reader :=
              Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.DAC, 0);
         begin
            Outcome := Jpeglib.Internal.Arithmetic.Parse_DAC (State, Segment);
         end;

         Assert (not Jpeglib.Results.Succeeded (Outcome), Label & " DAC unexpectedly succeeded");
         Assert
           (Outcome.First_Error.Code = Jpeglib.Errors.Table_Invalid_Definition,
            Label & " DAC used wrong error");
      end Rejects;
   begin
      Rejects ([0, 3, 16#00#], "odd-length");
      Rejects ([0, 4, 16#20#, 0], "invalid-class");
      Rejects ([0, 4, 16#04#, 0], "invalid-index");
   end Arithmetic_DAC_Parser_Rejects_Invalid_Definitions;

   procedure Arithmetic_Decoder_Decodes_Binary_Decisions (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      procedure Check_Zero_Stream is
         Storage : aliased constant Jpeglib.Streams.Byte_Array := [0, 0, 0, 0];
         Source : aliased Jpeglib.Streams.Memory_Source;
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Decoder : Jpeglib.Internal.Arithmetic.Decoder (Entropy'Access);
         Bin : Jpeglib.Internal.Arithmetic.Probability_Bin :=
           Jpeglib.Internal.Arithmetic.Initial_Probability_Bin;
         Decision : Jpeglib.Internal.Arithmetic.Decision_Result;
      begin
         Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);

         Decision := Jpeglib.Internal.Arithmetic.Decode_Bit (Decoder, Bin);
         Assert (Jpeglib.Results.Succeeded (Decision.Outcome), "first arithmetic decision failed");
         Assert (Decision.Decision = 0, "first arithmetic decision mismatch");
         Assert (Jpeglib.Internal.Arithmetic.State_Index (Bin) = 0, "first arithmetic state mismatch");
         Assert (Jpeglib.Internal.Arithmetic.MPS_Sense (Bin) = 0, "first arithmetic MPS mismatch");

         Decision := Jpeglib.Internal.Arithmetic.Decode_Bit (Decoder, Bin);
         Assert (Jpeglib.Results.Succeeded (Decision.Outcome), "second arithmetic decision failed");
         Assert (Decision.Decision = 1, "second arithmetic decision mismatch");
         Assert (Jpeglib.Internal.Arithmetic.State_Index (Bin) = 1, "second arithmetic state mismatch");
         Assert (Jpeglib.Internal.Arithmetic.MPS_Sense (Bin) = 1, "second arithmetic MPS mismatch");

         Decision := Jpeglib.Internal.Arithmetic.Decode_Bit (Decoder, Bin);
         Assert (Jpeglib.Results.Succeeded (Decision.Outcome), "third arithmetic decision failed");
         Assert (Decision.Decision = 1, "third arithmetic decision mismatch");
         Assert (Jpeglib.Internal.Arithmetic.State_Index (Bin) = 2, "third arithmetic state mismatch");
         Assert (Jpeglib.Internal.Arithmetic.MPS_Sense (Bin) = 1, "third arithmetic MPS mismatch");
      end Check_Zero_Stream;

      procedure Check_Stuffed_And_Marker_Input is
         Storage : aliased constant Jpeglib.Streams.Byte_Array := [16#00#, 16#FF#, 16#00#, 16#FF#, 16#D9#];
         Source : aliased Jpeglib.Streams.Memory_Source;
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Decoder : Jpeglib.Internal.Arithmetic.Decoder (Entropy'Access);
         Bin : Jpeglib.Internal.Arithmetic.Probability_Bin :=
           Jpeglib.Internal.Arithmetic.Initial_Probability_Bin;
         Decision : Jpeglib.Internal.Arithmetic.Decision_Result;
      begin
         Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);

         for Index in 1 .. 20 loop
            Decision := Jpeglib.Internal.Arithmetic.Decode_Bit (Decoder, Bin);
            Assert (Jpeglib.Results.Succeeded (Decision.Outcome), "stuffed arithmetic decision failed");
            exit when Jpeglib.Internal.Bit_Streams.Has_Pending_Marker (Entropy);
         end loop;

         Assert
           (Jpeglib.Internal.Bit_Streams.Has_Pending_Marker (Entropy),
            "arithmetic decoder did not preserve pending marker");
         Assert
           (Jpeglib.Internal.Bit_Streams.Take_Pending_Marker (Entropy).Marker = Jpeglib.Internal.Markers.EOI,
            "arithmetic decoder preserved wrong marker");
      end Check_Stuffed_And_Marker_Input;
   begin
      Check_Zero_Stream;
      Check_Stuffed_And_Marker_Input;
   end Arithmetic_Decoder_Decodes_Binary_Decisions;

   procedure Arithmetic_Encoder_Maps_DC_Difference_Decisions (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      procedure Check
        (Difference : Jpeglib.Internal.Arithmetic.DC_Difference;
         Expected : Jpeglib.Internal.Arithmetic.DC_Difference_Decision_Array;
         Label : String)
      is
         Result : constant Jpeglib.Internal.Arithmetic.DC_Difference_Decision_Result :=
           Jpeglib.Internal.Arithmetic.Encode_DC_Difference_Decisions (Difference);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), Label & " decision encode failed");
         Assert (Result.Length = Expected'Length, Label & " decision length mismatch");
         for Index in Expected'Range loop
            Assert (Result.Decisions (Index) = Expected (Index), Label & " decision mismatch");
         end loop;
      end Check;

      Invalid : constant Jpeglib.Internal.Arithmetic.DC_Difference_Decision_Result :=
        Jpeglib.Internal.Arithmetic.Encode_DC_Difference_Decisions (16#8000#);
   begin
      Check (0, [1 => 0], "zero");
      Check (1, [1, 0, 0], "positive one");
      Check (-1, [1, 1, 0], "negative one");
      Check (2, [1, 0, 1, 0], "positive two");
      Check (3, [1, 0, 1, 1, 0, 0], "positive three");
      Check (4, [1, 0, 1, 1, 0, 1], "positive four");

      Assert (not Jpeglib.Results.Succeeded (Invalid.Outcome), "oversized arithmetic DC difference succeeded");
      Assert
        (Invalid.Outcome.First_Error.Code = Jpeglib.Errors.Coefficient_Invalid_Encoding,
         "oversized arithmetic DC difference used wrong error");
   end Arithmetic_Encoder_Maps_DC_Difference_Decisions;

   procedure Arithmetic_Encoder_Maps_DC_Difference_Events (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      type Expected_Event is record
         Bin_Index : Natural;
         Decision : Jpeglib.Internal.Bit_Streams.Bit_Value;
      end record;

      type Expected_Event_Array is array (Positive range <>) of Expected_Event;

      procedure Check
        (Difference : Jpeglib.Internal.Arithmetic.DC_Difference;
         Context : Jpeglib.Internal.Arithmetic.DC_Context_Index;
         Conditioning : Jpeglib.Internal.Arithmetic.Conditioning_Value;
         Expected : Expected_Event_Array;
         Expected_Context : Jpeglib.Internal.Arithmetic.DC_Context_Index;
         Label : String)
      is
         Result : constant Jpeglib.Internal.Arithmetic.DC_Difference_Event_Result :=
           Jpeglib.Internal.Arithmetic.Encode_DC_Difference_Events (Difference, Context, Conditioning);
      begin
         Assert (Jpeglib.Results.Succeeded (Result.Outcome), Label & " event encode failed");
         Assert (Result.Length = Expected'Length, Label & " event length mismatch");
         Assert (Result.Final_Context = Expected_Context, Label & " final context mismatch");
         for Index in Expected'Range loop
            Assert
              (Result.Events (Index).Bin_Index = Expected (Index).Bin_Index,
               Label & " event bin mismatch");
            Assert
              (Result.Events (Index).Decision = Expected (Index).Decision,
               Label & " event decision mismatch");
         end loop;
      end Check;

      Invalid : constant Jpeglib.Internal.Arithmetic.DC_Difference_Event_Result :=
        Jpeglib.Internal.Arithmetic.Encode_DC_Difference_Events (16#8000#, 4, 16#5A#);
   begin
      Check
        (0,
         4,
         16#5A#,
         [(4, 0)],
         0,
         "zero");
      Check
        (1,
         4,
         16#5A#,
         [(4, 1), (5, 0), (6, 0)],
         0,
         "positive one low-threshold");
      Check
        (-1,
         4,
         16#00#,
         [(4, 1), (5, 1), (7, 0)],
         8,
         "negative one mid-context");
      Check
        (3,
         4,
         16#00#,
         [(4, 1), (5, 0), (6, 1), (20, 1), (21, 0), (35, 0)],
         12,
         "positive three high-context");
      Check
        (4,
         12,
         16#5A#,
         [(12, 1), (13, 0), (14, 1), (20, 1), (21, 0), (35, 1)],
         0,
         "positive four reset-context");

      Assert (not Jpeglib.Results.Succeeded (Invalid.Outcome), "oversized arithmetic DC events succeeded");
      Assert
        (Invalid.Outcome.First_Error.Code = Jpeglib.Errors.Coefficient_Invalid_Encoding,
         "oversized arithmetic DC events used wrong error");
      Assert (Invalid.Final_Context = 4, "invalid arithmetic DC event changed context");
   end Arithmetic_Encoder_Maps_DC_Difference_Events;

   procedure Arithmetic_Encoder_Emits_DC_Differences (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      type DC_Difference_Array is array (Positive range <>) of
        Jpeglib.Internal.Arithmetic.DC_Difference;

      procedure Check
        (Differences : DC_Difference_Array;
         Expected_Length : Positive;
         Label : String)
      is
         Encoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 64 => 0];
         Source_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 64 => 0];
         Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
         Source : aliased Jpeglib.Streams.Memory_Source;
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Encoder : Jpeglib.Internal.Arithmetic.Encoder (Destination'Access);
         Decoder : Jpeglib.Internal.Arithmetic.Decoder (Entropy'Access);
         Encode_Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 63) :=
           [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
         Decode_Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 63) :=
           [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
         Encode_Context : Jpeglib.Internal.Arithmetic.DC_Context_Index := 0;
         Decode_Context : Jpeglib.Internal.Arithmetic.DC_Context_Index := 0;
         Events : Jpeglib.Internal.Arithmetic.DC_Difference_Event_Result;
         Decoded : Jpeglib.Internal.Arithmetic.DC_Result;
         Outcome : Jpeglib.Results.Result;
      begin
         Jpeglib.Streams.Open (Destination, Encoded_Storage'Unchecked_Access);

         for Index in Differences'First .. Differences'First + Expected_Length - 1 loop
            Events :=
              Jpeglib.Internal.Arithmetic.Encode_DC_Difference_Events
                (Differences (Index),
                 Encode_Context,
                 16#5A#);
            Assert (Jpeglib.Results.Succeeded (Events.Outcome), Label & " event generation failed");

            for Event_Index in 1 .. Events.Length loop
               Outcome :=
                 Jpeglib.Internal.Arithmetic.Encode_Bit
                   (Encoder,
                    Encode_Bins (Events.Events (Event_Index).Bin_Index),
                    Events.Events (Event_Index).Decision);
               Assert (Jpeglib.Results.Succeeded (Outcome), Label & " arithmetic bit encode failed");
            end loop;
            Encode_Context := Events.Final_Context;
         end loop;

         Outcome := Jpeglib.Internal.Arithmetic.Finish (Encoder);
         Assert (Jpeglib.Results.Succeeded (Outcome), Label & " arithmetic finish failed");

         Source_Storage := Encoded_Storage;
         Jpeglib.Streams.Open (Source, Source_Storage'Unchecked_Access);
         for Index in Differences'First .. Differences'First + Expected_Length - 1 loop
            Decoded :=
              Jpeglib.Internal.Arithmetic.Decode_DC_Difference
                (Decoder,
                 Decode_Bins,
                 Decode_Context,
                 16#5A#);
            Assert (Jpeglib.Results.Succeeded (Decoded.Outcome), Label & " emitted DC decode failed");
            Assert
              (Decoded.Difference = Differences (Index),
               Label & " emitted DC difference mismatch at"
               & Positive'Image (Index)
               & ": expected"
               & Jpeglib.Internal.Arithmetic.DC_Difference'Image (Differences (Index))
               & " got"
               & Jpeglib.Internal.Arithmetic.DC_Difference'Image (Decoded.Difference));
         end loop;
      end Check;
   begin
      Check ([1 => 0], 1, "zero difference");
      Check ([1 => 1], 1, "positive one difference");
      Check ([1 => -1], 1, "negative one difference");
      Check ([1 => 17], 1, "positive category difference");
      Check ([1 => -33], 1, "negative category difference");
      Check ([1 => 127], 1, "positive edge byte difference");
      Check ([1 => -127], 1, "negative edge byte difference");
   end Arithmetic_Encoder_Emits_DC_Differences;

   procedure Arithmetic_Encoder_Emits_Sequential_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      type Block_Array is array (Positive range <>) of Jpeglib.Coefficients.DCT_Block;

      procedure Check (Blocks : Block_Array; Label : String) is
         Encoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 256 => 0];
         Source_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 256 => 0];
         Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
         Source : aliased Jpeglib.Streams.Memory_Source;
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Encoder : Jpeglib.Internal.Arithmetic.Encoder (Destination'Access);
         Decoder : Jpeglib.Internal.Arithmetic.Decoder (Entropy'Access);
         Encode_DC_Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 63) :=
           [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
         Encode_AC_Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 255) :=
           [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
         Decode_DC_Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 63) :=
           [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
         Decode_AC_Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 255) :=
           [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
         Encode_Fixed_Bin : Jpeglib.Internal.Arithmetic.Probability_Bin :=
           Jpeglib.Internal.Arithmetic.Initial_Probability_Bin;
         Decode_Fixed_Bin : Jpeglib.Internal.Arithmetic.Probability_Bin :=
           Jpeglib.Internal.Arithmetic.Initial_Probability_Bin;
         Encode_Context : Jpeglib.Internal.Arithmetic.DC_Context_Index := 0;
         Decode_Context : Jpeglib.Internal.Arithmetic.DC_Context_Index := 0;
         Encode_Predictor : Jpeglib.Internal.Arithmetic.DC_Difference := 0;
         Decode_Predictor : Jpeglib.Internal.Arithmetic.DC_Difference := 0;
         Decoded : Jpeglib.Internal.Arithmetic.Block_Result;
         Outcome : Jpeglib.Results.Result;
      begin
         Jpeglib.Streams.Open (Destination, Encoded_Storage'Unchecked_Access);

         for Index in Blocks'Range loop
            Outcome :=
              Jpeglib.Internal.Arithmetic.Encode_Sequential_Block
                (Encoder,
                 Encode_DC_Bins,
                 Encode_AC_Bins,
                 Encode_Fixed_Bin,
                 Encode_Context,
                 Encode_Predictor,
                 DC_Conditioning => 16#5A#,
                 AC_Conditioning => 0,
                 Block => Blocks (Index));
            Assert (Jpeglib.Results.Succeeded (Outcome), Label & " arithmetic block encode failed");
         end loop;

         Outcome := Jpeglib.Internal.Arithmetic.Finish (Encoder);
         Assert (Jpeglib.Results.Succeeded (Outcome), Label & " arithmetic block finish failed");

         Source_Storage := Encoded_Storage;
         Jpeglib.Streams.Open (Source, Source_Storage'Unchecked_Access);
         for Index in Blocks'Range loop
            Decoded :=
              Jpeglib.Internal.Arithmetic.Decode_Sequential_Block
                (Decoder,
                 Decode_DC_Bins,
                 Decode_AC_Bins,
                 Decode_Fixed_Bin,
                 Decode_Context,
                 Decode_Predictor,
                 DC_Conditioning => 16#5A#,
                 AC_Conditioning => 0);
            Assert (Jpeglib.Results.Succeeded (Decoded.Outcome), Label & " arithmetic block decode failed");
            Assert (Decoded.Block = Blocks (Index), Label & " arithmetic block roundtrip mismatch");
         end loop;
      end Check;

      First : constant Jpeglib.Coefficients.DCT_Block :=
        [0 => 5,
         1 => -2,
         5 => 3,
         63 => -1,
         others => 0];
      Second : constant Jpeglib.Coefficients.DCT_Block :=
        [0 => -7,
         2 => 4,
         10 => -3,
         20 => 2,
         others => 0];
   begin
      Check ([1 => First], "single nonzero block");
      Check ([First, Second], "multiple nonzero blocks");
   end Arithmetic_Encoder_Emits_Sequential_Blocks;

   procedure Arithmetic_Decoder_Decodes_DC_Difference (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased constant Jpeglib.Streams.Byte_Array := [0, 0, 0, 0];
      Source : aliased Jpeglib.Streams.Memory_Source;
      Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
      Decoder : Jpeglib.Internal.Arithmetic.Decoder (Entropy'Access);
      Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 63) :=
        [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
      Context : Jpeglib.Internal.Arithmetic.DC_Context_Index := 4;
      Result : Jpeglib.Internal.Arithmetic.DC_Result;
   begin
      Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
      Result :=
        Jpeglib.Internal.Arithmetic.Decode_DC_Difference
          (Decoder,
           Bins,
           Context,
           Conditioning => 16#5A#);

      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "arithmetic DC difference decode failed");
      Assert (Result.Difference = 0, "arithmetic DC zero-difference mismatch");
      Assert (Context = 0, "arithmetic DC zero-difference did not reset context");
      Assert
        (Jpeglib.Internal.Arithmetic.State_Index (Bins (4)) = 0,
         "arithmetic DC zero-difference state mismatch");
   end Arithmetic_Decoder_Decodes_DC_Difference;

   procedure Arithmetic_Decoder_Decodes_AC_EOB (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased constant Jpeglib.Streams.Byte_Array := [0, 0, 0, 0];
      Source : aliased Jpeglib.Streams.Memory_Source;
      Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
      Decoder : Jpeglib.Internal.Arithmetic.Decoder (Entropy'Access);
      Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 31) :=
        [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
      Result : Jpeglib.Internal.Arithmetic.AC_EOB_Result;
   begin
      Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
      Result := Jpeglib.Internal.Arithmetic.Decode_AC_EOB (Decoder, Bins);

      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "arithmetic AC EOB decode failed");
      Assert (Result.End_Of_Block, "arithmetic AC zero-tail did not produce EOB");
      Assert
        (Jpeglib.Internal.Arithmetic.State_Index (Bins (0)) = 0,
         "arithmetic AC EOB state mismatch");
      Assert
        (Jpeglib.Internal.Arithmetic.MPS_Sense (Bins (0)) = 0,
         "arithmetic AC EOB MPS mismatch");
   end Arithmetic_Decoder_Decodes_AC_EOB;

   procedure Arithmetic_Decoder_Decodes_Progressive_AC_Refine_Magnitude
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Storage : aliased constant Jpeglib.Streams.Byte_Array := [179, 248];
      Source : aliased Jpeglib.Streams.Memory_Source;
      Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
      Decoder : Jpeglib.Internal.Arithmetic.Decoder (Entropy'Access);
      Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 245) :=
        [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
      Fixed_Bin : Jpeglib.Internal.Arithmetic.Probability_Bin :=
        Jpeglib.Internal.Arithmetic.Initial_Probability_Bin;
      Decoded : Jpeglib.Internal.Arithmetic.Decoded_Coefficient_Map (1 .. 1, 0 .. 63) :=
        [others => [others => False]];
      Block : Jpeglib.Coefficients.DCT_Block := [others => 0];
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
      Outcome :=
        Jpeglib.Internal.Arithmetic.Decode_Progressive_AC_Refine
          (Decoder,
           Bins,
           Fixed_Bin,
           AC_Conditioning => 0,
           Spectral_Start => 1,
           Spectral_End => 3,
           Successive_Low => 0,
           Decoded_Coefficients => Decoded,
           Block_Number => 1,
           Block => Block);

      Assert (Jpeglib.Results.Succeeded (Outcome), "arithmetic AC refine magnitude decode failed");
      Assert (Block (16) = -6, "arithmetic AC refine magnitude coefficient mismatch");
      Assert (Decoded (1, 16), "arithmetic AC refine magnitude did not mark coefficient decoded");
      Assert (Block (1) = 0, "arithmetic AC refine magnitude modified preceding coefficient");
      Assert (Block (8) = 0, "arithmetic AC refine magnitude modified skipped coefficient");
   end Arithmetic_Decoder_Decodes_Progressive_AC_Refine_Magnitude;

   procedure Arithmetic_Decoder_Decodes_DC_EOB_Block (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased constant Jpeglib.Streams.Byte_Array := [75, 198, 0, 0, 0, 0];
      Source : aliased Jpeglib.Streams.Memory_Source;
      Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
      Decoder : Jpeglib.Internal.Arithmetic.Decoder (Entropy'Access);
      DC_Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 63) :=
        [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
      AC_Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 31) :=
        [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
      Context : Jpeglib.Internal.Arithmetic.DC_Context_Index := 0;
      Predictor : Jpeglib.Internal.Arithmetic.DC_Difference := 5;
      Result : Jpeglib.Internal.Arithmetic.Block_Result;
   begin
      Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
      Result :=
        Jpeglib.Internal.Arithmetic.Decode_DC_EOB_Block
          (Decoder,
           DC_Bins,
           AC_Bins,
           Context,
           Predictor,
           DC_Conditioning => 16#5A#);

      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "arithmetic DC/EOB block decode failed");
      Assert (Predictor = 5, "arithmetic DC/EOB block predictor mismatch");
      Assert (Context = 0, "arithmetic DC/EOB block context mismatch");
      Assert (Result.Block (0) = 5, "arithmetic DC/EOB block DC mismatch");

      for Index in Jpeglib.Coefficient_Index range 1 .. 63 loop
         Assert (Result.Block (Index) = 0, "arithmetic DC/EOB block AC coefficient mismatch");
      end loop;
   end Arithmetic_Decoder_Decodes_DC_EOB_Block;

   procedure Arithmetic_Decoder_Decodes_Sequential_Block (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased constant Jpeglib.Streams.Byte_Array := [126, 119, 0, 0, 0, 0];
      Source : aliased Jpeglib.Streams.Memory_Source;
      Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
      Decoder : Jpeglib.Internal.Arithmetic.Decoder (Entropy'Access);
      DC_Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 63) :=
        [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
      AC_Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 255) :=
        [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
      Fixed_Bin : Jpeglib.Internal.Arithmetic.Probability_Bin :=
        Jpeglib.Internal.Arithmetic.Initial_Probability_Bin;
      Context : Jpeglib.Internal.Arithmetic.DC_Context_Index := 0;
      Predictor : Jpeglib.Internal.Arithmetic.DC_Difference := 0;
      Result : Jpeglib.Internal.Arithmetic.Block_Result;
   begin
      Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
      Result :=
        Jpeglib.Internal.Arithmetic.Decode_Sequential_Block
          (Decoder,
           DC_Bins,
           AC_Bins,
           Fixed_Bin,
           Context,
           Predictor,
           DC_Conditioning => 16#5A#,
           AC_Conditioning => 0);

      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "arithmetic sequential block decode failed");
      Assert (Predictor = 0, "arithmetic sequential block predictor mismatch");
      Assert (Context = 0, "arithmetic sequential block context mismatch");
      Assert (Result.Block (0) = 0, "arithmetic sequential block DC mismatch");
      Assert (Result.Block (1) = 1, "arithmetic sequential block AC coefficient mismatch");

      for Index in Jpeglib.Coefficient_Index range 2 .. 63 loop
         Assert (Result.Block (Index) = 0, "arithmetic sequential block AC tail mismatch");
      end loop;
   end Arithmetic_Decoder_Decodes_Sequential_Block;

   procedure Arithmetic_Decoder_Decodes_DC_EOB_Scan (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Gray_Frame_8x8 return Jpeglib.Internal.Frames.Frame is
         Source : aliased Jpeglib.Streams.Memory_Source;
      begin
         Jpeglib.Streams.Open (Source, SOF2_Gray_8x8_Storage'Access);
         declare
            Segment : Jpeglib.Internal.Segments.Segment_Reader :=
              Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOF0, 160);
         begin
            return Jpeglib.Internal.Frames.Parse_SOF (Segment, Jpeglib.Baseline_DCT);
         end;
      end Gray_Frame_8x8;

      function Arithmetic_Tables return Jpeglib.Internal.Arithmetic.Arithmetic_State is
         Storage : aliased constant Jpeglib.Streams.Byte_Array :=
           [0, 6,
            16#00#, 16#5A#,
            16#10#, 0];
         Source : aliased Jpeglib.Streams.Memory_Source;
         State : Jpeglib.Internal.Arithmetic.Arithmetic_State;
         Outcome : Jpeglib.Results.Result;
      begin
         Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
         declare
            Segment : Jpeglib.Internal.Segments.Segment_Reader :=
              Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.DAC, 0);
         begin
            Outcome := Jpeglib.Internal.Arithmetic.Parse_DAC (State, Segment);
         end;
         Assert (Jpeglib.Results.Succeeded (Outcome), "arithmetic scan DAC parse failed");
         return State;
      end Arithmetic_Tables;

      Frame : constant Jpeglib.Internal.Frames.Frame := Gray_Frame_8x8;
      Scan : constant Jpeglib.Internal.Scans.Scan := Gray_Scan (Frame);
      Tables : constant Jpeglib.Internal.Arithmetic.Arithmetic_State := Arithmetic_Tables;
      Storage : aliased constant Jpeglib.Streams.Byte_Array := [75, 198, 0, 0, 0, 0];
      Source : aliased Jpeglib.Streams.Memory_Source;
      Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 1) := [others => [others => 0]];
      Next_Block : Natural := Blocks'First;
      Predictors : Jpeglib.Internal.Coefficients.Predictor_Array := [others => 0];
      DC_Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 63) :=
        [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
      AC_Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 31) :=
        [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
      Contexts : Jpeglib.Internal.Arithmetic.DC_Context_Array := [others => 0];
      Result : Jpeglib.Internal.Coefficients.Scan_Result;
   begin
      Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
      Result :=
        Jpeglib.Internal.Coefficients.Decode_Arithmetic_DC_EOB_Scan
          (Frame,
           Scan,
           Tables,
           Entropy'Access,
           Blocks,
           Next_Block,
           Predictors,
           DC_Bins,
           AC_Bins,
           Contexts);

      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "arithmetic DC/EOB scan decode failed");
      Assert (Result.Blocks_Decoded = 1, "arithmetic DC/EOB scan block count mismatch");
      Assert (Next_Block = 2, "arithmetic DC/EOB scan next block mismatch");
      Assert (Blocks (1) (0) = 0, "arithmetic DC/EOB scan DC mismatch");

      for Index in Jpeglib.Coefficient_Index range 1 .. 63 loop
         Assert (Blocks (1) (Index) = 0, "arithmetic DC/EOB scan AC coefficient mismatch");
      end loop;
   end Arithmetic_Decoder_Decodes_DC_EOB_Scan;

   procedure Arithmetic_Decoder_Decodes_Color_DC_EOB_Scan
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);

      function Color_Frame_8x8 return Jpeglib.Internal.Frames.Frame is
         Storage : aliased constant Jpeglib.Streams.Byte_Array :=
           [0, 17,
            8, 0, 8, 0, 8, 3,
            1, 16#11#, 0,
            2, 16#11#, 0,
            3, 16#11#, 0];
         Source : aliased Jpeglib.Streams.Memory_Source;
      begin
         Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
         declare
            Segment : Jpeglib.Internal.Segments.Segment_Reader :=
              Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOF9, 0);
         begin
            return Jpeglib.Internal.Frames.Parse_SOF (Segment, Jpeglib.Baseline_DCT);
         end;
      end Color_Frame_8x8;

      function Color_Scan (Frame : Jpeglib.Internal.Frames.Frame) return Jpeglib.Internal.Scans.Scan is
         Storage : aliased constant Jpeglib.Streams.Byte_Array :=
           [0, 12,
            3,
            1, 16#00#,
            2, 16#00#,
            3, 16#00#,
            0, 63, 0];
         Source : aliased Jpeglib.Streams.Memory_Source;
      begin
         Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
         declare
            Segment : Jpeglib.Internal.Segments.Segment_Reader :=
              Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOS, 0);
         begin
            return Jpeglib.Internal.Scans.Parse_SOS (Frame, Segment);
         end;
      end Color_Scan;

      function Arithmetic_Tables return Jpeglib.Internal.Arithmetic.Arithmetic_State is
         Storage : aliased constant Jpeglib.Streams.Byte_Array :=
           [0, 6,
            16#00#, 16#5A#,
            16#10#, 0];
         Source : aliased Jpeglib.Streams.Memory_Source;
         State : Jpeglib.Internal.Arithmetic.Arithmetic_State;
         Outcome : Jpeglib.Results.Result;
      begin
         Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
         declare
            Segment : Jpeglib.Internal.Segments.Segment_Reader :=
              Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.DAC, 0);
         begin
            Outcome := Jpeglib.Internal.Arithmetic.Parse_DAC (State, Segment);
         end;
         Assert (Jpeglib.Results.Succeeded (Outcome), "arithmetic color DC/EOB DAC parse failed");
         return State;
      end Arithmetic_Tables;

      Frame : constant Jpeglib.Internal.Frames.Frame := Color_Frame_8x8;
      Scan : constant Jpeglib.Internal.Scans.Scan := Color_Scan (Frame);
      Tables : constant Jpeglib.Internal.Arithmetic.Arithmetic_State := Arithmetic_Tables;
      Storage : aliased constant Jpeglib.Streams.Byte_Array :=
        [75, 198, 75, 198, 75, 198, 0, 0, 0, 0];
      Source : aliased Jpeglib.Streams.Memory_Source;
      Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 3) := [others => [others => 77]];
      Next_Block : Natural := Blocks'First;
      Predictors : Jpeglib.Internal.Coefficients.Predictor_Array := [others => 0];
      DC_Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 63) :=
        [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
      AC_Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 31) :=
        [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
      Contexts : Jpeglib.Internal.Arithmetic.DC_Context_Array := [others => 0];
      Result : Jpeglib.Internal.Coefficients.Scan_Result;
   begin
      Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
      Result :=
        Jpeglib.Internal.Coefficients.Decode_Arithmetic_DC_EOB_Scan
          (Frame,
           Scan,
           Tables,
           Entropy'Access,
           Blocks,
           Next_Block,
           Predictors,
           DC_Bins,
           AC_Bins,
           Contexts);

      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "arithmetic color DC/EOB scan decode failed");
      Assert (Result.Blocks_Decoded = 3, "arithmetic color DC/EOB scan block count mismatch");
      Assert (Next_Block = 4, "arithmetic color DC/EOB scan next block mismatch");

      for Block_Index in Blocks'Range loop
         Assert (Blocks (Block_Index) (0) = 0, "arithmetic color DC/EOB scan DC mismatch");
         for Index in Jpeglib.Coefficient_Index range 1 .. 63 loop
            Assert (Blocks (Block_Index) (Index) = 0, "arithmetic color DC/EOB scan AC mismatch");
         end loop;
      end loop;
   end Arithmetic_Decoder_Decodes_Color_DC_EOB_Scan;

   procedure Arithmetic_Decoder_Decodes_Sequential_Scan (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Gray_Frame_8x8 return Jpeglib.Internal.Frames.Frame is
         Source : aliased Jpeglib.Streams.Memory_Source;
      begin
         Jpeglib.Streams.Open (Source, SOF2_Gray_8x8_Storage'Access);
         declare
            Segment : Jpeglib.Internal.Segments.Segment_Reader :=
              Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOF0, 160);
         begin
            return Jpeglib.Internal.Frames.Parse_SOF (Segment, Jpeglib.Baseline_DCT);
         end;
      end Gray_Frame_8x8;

      function Arithmetic_Tables return Jpeglib.Internal.Arithmetic.Arithmetic_State is
         Storage : aliased constant Jpeglib.Streams.Byte_Array :=
           [0, 6,
            16#00#, 16#5A#,
            16#10#, 0];
         Source : aliased Jpeglib.Streams.Memory_Source;
         State : Jpeglib.Internal.Arithmetic.Arithmetic_State;
         Outcome : Jpeglib.Results.Result;
      begin
         Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
         declare
            Segment : Jpeglib.Internal.Segments.Segment_Reader :=
              Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.DAC, 0);
         begin
            Outcome := Jpeglib.Internal.Arithmetic.Parse_DAC (State, Segment);
         end;
         Assert (Jpeglib.Results.Succeeded (Outcome), "arithmetic sequential scan DAC parse failed");
         return State;
      end Arithmetic_Tables;

      Frame : constant Jpeglib.Internal.Frames.Frame := Gray_Frame_8x8;
      Scan : constant Jpeglib.Internal.Scans.Scan := Gray_Scan (Frame);
      Tables : constant Jpeglib.Internal.Arithmetic.Arithmetic_State := Arithmetic_Tables;
      Storage : aliased constant Jpeglib.Streams.Byte_Array := [126, 119, 0, 0, 0, 0];
      Source : aliased Jpeglib.Streams.Memory_Source;
      Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 1) := [others => [others => 0]];
      Next_Block : Natural := Blocks'First;
      Predictors : Jpeglib.Internal.Coefficients.Predictor_Array := [others => 0];
      DC_Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 63) :=
        [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
      AC_Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 255) :=
        [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
      Fixed_Bin : Jpeglib.Internal.Arithmetic.Probability_Bin :=
        Jpeglib.Internal.Arithmetic.Initial_Probability_Bin;
      Contexts : Jpeglib.Internal.Arithmetic.DC_Context_Array := [others => 0];
      Result : Jpeglib.Internal.Coefficients.Scan_Result;
   begin
      Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
      Result :=
        Jpeglib.Internal.Coefficients.Decode_Arithmetic_Sequential_Scan
          (Frame,
           Scan,
           Tables,
           Entropy'Access,
           Blocks,
           Next_Block,
           Predictors,
           DC_Bins,
           AC_Bins,
           Fixed_Bin,
           Contexts);

      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "arithmetic sequential scan decode failed");
      Assert (Result.Blocks_Decoded = 1, "arithmetic sequential scan block count mismatch");
      Assert (Next_Block = 2, "arithmetic sequential scan next block mismatch");
      Assert (Blocks (1) (0) = 0, "arithmetic sequential scan DC mismatch");
      Assert (Blocks (1) (1) = 1, "arithmetic sequential scan AC coefficient mismatch");

      for Index in Jpeglib.Coefficient_Index range 2 .. 63 loop
         Assert (Blocks (1) (Index) = 0, "arithmetic sequential scan AC tail mismatch");
      end loop;
   end Arithmetic_Decoder_Decodes_Sequential_Scan;

   procedure Arithmetic_Decoder_Decodes_Color_Sequential_Scan
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);

      function Color_Frame_8x8 return Jpeglib.Internal.Frames.Frame is
         Storage : aliased constant Jpeglib.Streams.Byte_Array :=
           [0, 17,
            8, 0, 8, 0, 8, 3,
            1, 16#11#, 0,
            2, 16#11#, 0,
            3, 16#11#, 0];
         Source : aliased Jpeglib.Streams.Memory_Source;
      begin
         Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
         declare
            Segment : Jpeglib.Internal.Segments.Segment_Reader :=
              Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOF9, 0);
         begin
            return Jpeglib.Internal.Frames.Parse_SOF (Segment, Jpeglib.Baseline_DCT);
         end;
      end Color_Frame_8x8;

      function Color_Scan (Frame : Jpeglib.Internal.Frames.Frame) return Jpeglib.Internal.Scans.Scan is
         Storage : aliased constant Jpeglib.Streams.Byte_Array :=
           [0, 12,
            3,
            1, 16#00#,
            2, 16#00#,
            3, 16#00#,
            0, 63, 0];
         Source : aliased Jpeglib.Streams.Memory_Source;
      begin
         Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
         declare
            Segment : Jpeglib.Internal.Segments.Segment_Reader :=
              Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.SOS, 0);
         begin
            return Jpeglib.Internal.Scans.Parse_SOS (Frame, Segment);
         end;
      end Color_Scan;

      function Arithmetic_Tables return Jpeglib.Internal.Arithmetic.Arithmetic_State is
         Storage : aliased constant Jpeglib.Streams.Byte_Array :=
           [0, 6,
            16#00#, 16#5A#,
            16#10#, 0];
         Source : aliased Jpeglib.Streams.Memory_Source;
         State : Jpeglib.Internal.Arithmetic.Arithmetic_State;
         Outcome : Jpeglib.Results.Result;
      begin
         Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
         declare
            Segment : Jpeglib.Internal.Segments.Segment_Reader :=
              Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.DAC, 0);
         begin
            Outcome := Jpeglib.Internal.Arithmetic.Parse_DAC (State, Segment);
         end;
         Assert (Jpeglib.Results.Succeeded (Outcome), "arithmetic color scan DAC parse failed");
         return State;
      end Arithmetic_Tables;

      Frame : constant Jpeglib.Internal.Frames.Frame := Color_Frame_8x8;
      Scan : constant Jpeglib.Internal.Scans.Scan := Color_Scan (Frame);
      Tables : constant Jpeglib.Internal.Arithmetic.Arithmetic_State := Arithmetic_Tables;
      Storage : aliased constant Jpeglib.Streams.Byte_Array :=
        [126, 119, 126, 119, 126, 119, 0, 0, 0, 0];
      Source : aliased Jpeglib.Streams.Memory_Source;
      Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
      Blocks : Jpeglib.Internal.Coefficients.Block_Array (1 .. 3) := [others => [others => 0]];
      Next_Block : Natural := Blocks'First;
      Predictors : Jpeglib.Internal.Coefficients.Predictor_Array := [others => 0];
      DC_Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 63) :=
        [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
      AC_Bins : Jpeglib.Internal.Arithmetic.Probability_Bin_Array (0 .. 255) :=
        [others => Jpeglib.Internal.Arithmetic.Initial_Probability_Bin];
      Fixed_Bin : Jpeglib.Internal.Arithmetic.Probability_Bin :=
        Jpeglib.Internal.Arithmetic.Initial_Probability_Bin;
      Contexts : Jpeglib.Internal.Arithmetic.DC_Context_Array := [others => 0];
      Result : Jpeglib.Internal.Coefficients.Scan_Result;
   begin
      Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
      Result :=
        Jpeglib.Internal.Coefficients.Decode_Arithmetic_Sequential_Scan
          (Frame,
           Scan,
           Tables,
           Entropy'Access,
           Blocks,
           Next_Block,
           Predictors,
           DC_Bins,
           AC_Bins,
           Fixed_Bin,
           Contexts);

      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "arithmetic color sequential scan decode failed");
      Assert (Result.Blocks_Decoded = 3, "arithmetic color sequential scan block count mismatch");
      Assert (Next_Block = 4, "arithmetic color sequential scan next block mismatch");

      for Block_Index in Blocks'Range loop
         Assert (Blocks (Block_Index) (0) = 0, "arithmetic color sequential scan DC mismatch");
         Assert (Blocks (Block_Index) (1) = 1, "arithmetic color sequential scan AC mismatch");
         for Index in Jpeglib.Coefficient_Index range 2 .. 63 loop
            Assert (Blocks (Block_Index) (Index) = 0, "arithmetic color sequential scan AC tail mismatch");
         end loop;
      end loop;
   end Arithmetic_Decoder_Decodes_Color_Sequential_Scan;
end Jpeglib_Testing.Test_Arithmetic;

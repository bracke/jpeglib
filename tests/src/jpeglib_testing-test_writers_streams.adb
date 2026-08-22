with AUnit.Assertions;

with Jpeglib;
with Jpeglib.Errors;
with Jpeglib.Internal.Arithmetic;
with Jpeglib.Internal.Bit_Streams;
with Jpeglib.Internal.Bytes;
with Jpeglib.Internal.Huffman;
with Jpeglib.Internal.Markers;
with Jpeglib.Internal.Quantization;
with Jpeglib.Internal.Segments;
with Jpeglib.Internal.Writers;
with Jpeglib.Results;
with Jpeglib.Streams;

package body Jpeglib_Testing.Test_Writers_Streams is
   use AUnit.Assertions;
   use type Jpeglib.Byte;
   use type Jpeglib.Byte_Count;
   use type Jpeglib.Errors.Error_Code;
   use type Jpeglib.Marker_Code;
   use type Jpeglib.Source_Offset;
   use type Jpeglib.Destination_Offset;
   use type Jpeglib.Streams.Byte_Array;
   use type Jpeglib.Streams.Const_Byte_Array_Access;

   Marker_Fill_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [1 => 16#12#, 2 => 16#FF#, 3 => 16#FF#, 4 => 16#D8#];
   Segment_Storage : aliased constant Jpeglib.Streams.Byte_Array := [1 => 0, 2 => 3, 3 => 16#AB#, 4 => 16#CD#];
   DHT_DC_Category2_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2];
   DHT_AC_EOB_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 20, 16#10#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0];

   procedure Writer_Emits_Markers_And_Segments (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Writer_Propagates_Output_Limits (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Writer_Stuffs_Entropy_FF_Bytes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Writer_Emits_JFIF_Header (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Writer_Emits_DQT_In_Zigzag_Order (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Writer_Rejects_16_Bit_DQT_For_Baseline (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Writer_Emits_DHT_Definitions (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Writer_Emits_DAC_Definitions (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Writer_Emits_DRI (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Writer_Emits_Grayscale_Frame_And_Scan (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Writer_Emits_YCbCr_Frame_And_Scan (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Writer_Emits_Arithmetic_Frames (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Writer_Rejects_Oversized_Frame (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Bit_Writer_Packs_MSB_First (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Bit_Writer_Stuffs_FF_Bytes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Bit_Writer_Rejects_Invalid_Category (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Bit_Writer_Emits_Restart_Marker (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Byte_Reader_Detects_Zero_Progress (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Marker_Reader_Normalizes_Fill (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Segment_Reader_Stays_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Segment_Skip_Handles_Short_Progress (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Fixed_Buffer_Destination_Reports_Partial_Write (T : in out AUnit.Test_Cases.Test_Case'Class);

   type Zero_Progress_Source is limited new Jpeglib.Streams.Source with record
      Current_Offset : Jpeglib.Source_Offset := 0;
   end record;

   type One_Byte_Skip_Source is limited new Jpeglib.Streams.Source with record
      Storage : Jpeglib.Streams.Const_Byte_Array_Access := null;
      Position : Natural := 0;
      Skip_Calls : Natural := 0;
   end record;

   overriding function Read
     (Object : in out Zero_Progress_Source;
      Buffer : out Jpeglib.Streams.Byte_Array) return Jpeglib.Streams.Source_Result;
   overriding function Offset (Object : Zero_Progress_Source) return Jpeglib.Source_Offset;
   overriding function Skip
     (Object : in out Zero_Progress_Source;
      Count : Jpeglib.Byte_Count) return Jpeglib.Streams.Source_Result;
   overriding function Read
     (Object : in out One_Byte_Skip_Source;
      Buffer : out Jpeglib.Streams.Byte_Array) return Jpeglib.Streams.Source_Result;
   overriding function Offset (Object : One_Byte_Skip_Source) return Jpeglib.Source_Offset;
   overriding function Skip
     (Object : in out One_Byte_Skip_Source;
      Count : Jpeglib.Byte_Count) return Jpeglib.Streams.Source_Result;

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("writers_streams");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Writer_Emits_Markers_And_Segments'Access, "foundation.writers.markers_segments");
      Register_Routine (T, Writer_Propagates_Output_Limits'Access, "foundation.writers.output_limit");
      Register_Routine (T, Writer_Stuffs_Entropy_FF_Bytes'Access, "foundation.writers.entropy_stuffing");
      Register_Routine (T, Writer_Emits_JFIF_Header'Access, "foundation.writers.jfif");
      Register_Routine (T, Writer_Emits_DQT_In_Zigzag_Order'Access, "foundation.writers.dqt_zigzag");
      Register_Routine (T, Writer_Rejects_16_Bit_DQT_For_Baseline'Access, "foundation.writers.dqt_16bit");
      Register_Routine (T, Writer_Emits_DHT_Definitions'Access, "foundation.writers.dht");
      Register_Routine (T, Writer_Emits_DAC_Definitions'Access, "foundation.writers.dac");
      Register_Routine (T, Writer_Emits_DRI'Access, "foundation.writers.dri");
      Register_Routine (T, Writer_Emits_Grayscale_Frame_And_Scan'Access, "foundation.writers.gray_frame_scan");
      Register_Routine (T, Writer_Emits_YCbCr_Frame_And_Scan'Access, "foundation.writers.ycbcr_frame_scan");
      Register_Routine (T, Writer_Emits_Arithmetic_Frames'Access, "foundation.writers.arithmetic_frames");
      Register_Routine (T, Writer_Rejects_Oversized_Frame'Access, "foundation.writers.frame_size");
      Register_Routine (T, Byte_Reader_Detects_Zero_Progress'Access, "foundation.bytes.zero_progress");
      Register_Routine (T, Bit_Writer_Packs_MSB_First'Access, "foundation.entropy.bit_writer_msb_first");
      Register_Routine (T, Bit_Writer_Stuffs_FF_Bytes'Access, "foundation.entropy.bit_writer_stuffing");
      Register_Routine (T, Bit_Writer_Rejects_Invalid_Category'Access, "foundation.entropy.bit_writer_invalid");
      Register_Routine (T, Bit_Writer_Emits_Restart_Marker'Access, "foundation.entropy.bit_writer_restart");
      Register_Routine (T, Marker_Reader_Normalizes_Fill'Access, "foundation.markers.read_fill");
      Register_Routine (T, Segment_Reader_Stays_Bounded'Access, "foundation.segments.bounded");
      Register_Routine (T, Segment_Skip_Handles_Short_Progress'Access, "foundation.segments.short_skip");
      Register_Routine
        (T,
         Fixed_Buffer_Destination_Reports_Partial_Write'Access,
         "foundation.streams.fixed_destination_partial_write");
   end Register_Tests;

   procedure Writer_Emits_Markers_And_Segments (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 13 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      Outcome := Jpeglib.Internal.Writers.Write_Marker (Destination, Jpeglib.Internal.Markers.SOI);
      Assert (Jpeglib.Results.Succeeded (Outcome), "SOI write failed");
      Outcome :=
        Jpeglib.Internal.Writers.Write_Segment
          (Destination,
           Jpeglib.Internal.Markers.APP0,
           [16#4A#, 16#46#, 16#49#, 16#46#, 0]);
      Assert (Jpeglib.Results.Succeeded (Outcome), "APP0 segment write failed");
      Outcome := Jpeglib.Internal.Writers.Write_Marker (Destination, Jpeglib.Internal.Markers.EOI);
      Assert (Jpeglib.Results.Succeeded (Outcome), "EOI write failed");
      Assert
        (Storage =
           [16#FF#, 16#D8#, 16#FF#, 16#E0#, 0, 7, 16#4A#, 16#46#, 16#49#, 16#46#, 0, 16#FF#, 16#D9#],
         "marker and segment bytes mismatch");
   end Writer_Emits_Markers_And_Segments;

   procedure Writer_Propagates_Output_Limits (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 3 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      Outcome :=
        Jpeglib.Internal.Writers.Write_Segment
          (Destination, Jpeglib.Internal.Markers.APP0, [16#4A#, 16#46#, 16#49#, 16#46#, 0]);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "short destination accepted full segment");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Output_Limit_Exceeded,
         "short destination used wrong error");
      Assert (Jpeglib.Streams.Offset (Destination) = 3, "short destination offset mismatch");
   end Writer_Propagates_Output_Limits;

   procedure Writer_Stuffs_Entropy_FF_Bytes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 3 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      Outcome := Jpeglib.Internal.Writers.Write_Entropy_Byte (Destination, 16#12#);
      Assert (Jpeglib.Results.Succeeded (Outcome), "normal entropy byte write failed");
      Outcome := Jpeglib.Internal.Writers.Write_Entropy_Byte (Destination, 16#FF#);
      Assert (Jpeglib.Results.Succeeded (Outcome), "stuffed entropy byte write failed");
      Assert (Storage = [16#12#, 16#FF#, 0], "entropy byte stuffing mismatch");
   end Writer_Stuffs_Entropy_FF_Bytes;

   procedure Writer_Emits_JFIF_Header (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 18 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      Outcome := Jpeglib.Internal.Writers.Write_JFIF_APP0 (Destination);
      Assert (Jpeglib.Results.Succeeded (Outcome), "JFIF APP0 write failed");
      Assert
        (Storage =
           [16#FF#, 16#E0#, 0, 16,
            16#4A#, 16#46#, 16#49#, 16#46#, 0,
            1, 1, 0, 0, 1, 0, 1, 0, 0],
         "JFIF APP0 bytes mismatch");
   end Writer_Emits_JFIF_Header;

   procedure Writer_Emits_DQT_In_Zigzag_Order (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 69 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Table : Jpeglib.Internal.Quantization.Quantization_Table;
      Outcome : Jpeglib.Results.Result;
   begin
      for Index in Jpeglib.Coefficient_Index loop
         Table (Index) := Jpeglib.Internal.Quantization.Quantization_Value (Natural (Index) + 1);
      end loop;

      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      Outcome := Jpeglib.Internal.Writers.Write_DQT (Destination, 0, Table);
      Assert (Jpeglib.Results.Succeeded (Outcome), "DQT write failed");
      Assert (Storage (1 .. 5) = [16#FF#, 16#DB#, 0, 67, 0], "DQT header mismatch");
      Assert (Storage (6 .. 13) = [1, 2, 9, 17, 10, 3, 4, 11], "DQT zigzag prefix mismatch");
      Assert (Storage (69) = 64, "DQT zigzag suffix mismatch");
   end Writer_Emits_DQT_In_Zigzag_Order;

   procedure Writer_Rejects_16_Bit_DQT_For_Baseline (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 69 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Table : Jpeglib.Internal.Quantization.Quantization_Table := [others => 1];
      Outcome : Jpeglib.Results.Result;
   begin
      Table (0) := 256;
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      Outcome := Jpeglib.Internal.Writers.Write_DQT (Destination, 0, Table);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "16-bit DQT table was accepted");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Table_Invalid_Definition,
         "16-bit DQT table used wrong error");
      Assert (Jpeglib.Streams.Offset (Destination) = 0, "rejected DQT wrote bytes");
   end Writer_Rejects_16_Bit_DQT_For_Baseline;

   procedure Writer_Emits_DHT_Definitions (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      procedure Check_Table
        (Fixture : not null Jpeglib.Streams.Const_Byte_Array_Access;
         Class : Jpeglib.Internal.Huffman.Huffman_Class;
         Expected_Header : Jpeglib.Byte;
         Message : String)
      is
         Source : aliased Jpeglib.Streams.Memory_Source;
         State : Jpeglib.Internal.Huffman.Huffman_State;
         Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 22 => 0];
         Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
         Parse_Outcome : Jpeglib.Results.Result;
         Write_Outcome : Jpeglib.Results.Result;
      begin
         Jpeglib.Streams.Open (Source, Fixture);
         declare
            Segment : Jpeglib.Internal.Segments.Segment_Reader :=
              Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.DHT, 0);
         begin
            Parse_Outcome := Jpeglib.Internal.Huffman.Parse_DHT (State, Segment);
         end;
         Assert (Jpeglib.Results.Succeeded (Parse_Outcome), Message & " DHT parse failed");

         Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
         Write_Outcome :=
           Jpeglib.Internal.Writers.Write_DHT
             (Destination,
              Class,
              0,
              Jpeglib.Internal.Huffman.Definition (State, Class, 0));
         Assert (Jpeglib.Results.Succeeded (Write_Outcome), Message & " DHT write failed");
         Assert (Storage (1 .. 2) = [16#FF#, 16#C4#], Message & " DHT marker mismatch");
         Assert (Storage (3 .. 22) = Fixture.all, Message & " DHT payload mismatch");
         Assert (Storage (5) = Expected_Header, Message & " DHT table header mismatch");
      end Check_Table;
   begin
      Check_Table (DHT_DC_Category2_Storage'Access, Jpeglib.Internal.Huffman.DC, 0, "DC");
      Check_Table (DHT_AC_EOB_Storage'Access, Jpeglib.Internal.Huffman.AC, 16#10#, "AC");
   end Writer_Emits_DHT_Definitions;

   procedure Writer_Emits_DAC_Definitions (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 12 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      Outcome :=
        Jpeglib.Internal.Writers.Write_DAC
          (Destination,
           Jpeglib.Internal.Arithmetic.DC,
           Index => 2,
           Conditioning => 16#5A#);
      Assert (Jpeglib.Results.Succeeded (Outcome), "DC DAC write failed");
      Outcome :=
        Jpeglib.Internal.Writers.Write_DAC
          (Destination,
           Jpeglib.Internal.Arithmetic.AC,
           Index => 3,
           Conditioning => 16#0B#);
      Assert (Jpeglib.Results.Succeeded (Outcome), "AC DAC write failed");
      Assert
        (Storage =
           [16#FF#, 16#CC#, 0, 4, 2, 16#5A#,
            16#FF#, 16#CC#, 0, 4, 16#13#, 16#0B#],
         "DAC bytes mismatch");
   end Writer_Emits_DAC_Definitions;

   procedure Writer_Emits_DRI (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 6 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      Outcome := Jpeglib.Internal.Writers.Write_DRI (Destination, Restart => 257);
      Assert (Jpeglib.Results.Succeeded (Outcome), "DRI write failed");
      Assert (Storage = [16#FF#, 16#DD#, 0, 4, 1, 1], "DRI bytes mismatch");
   end Writer_Emits_DRI;

   procedure Writer_Emits_Grayscale_Frame_And_Scan (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 23 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      Outcome := Jpeglib.Internal.Writers.Write_SOF0_Grayscale (Destination, Width => 16, Height => 8);
      Assert (Jpeglib.Results.Succeeded (Outcome), "grayscale SOF0 write failed");
      Outcome := Jpeglib.Internal.Writers.Write_SOS_Grayscale (Destination);
      Assert (Jpeglib.Results.Succeeded (Outcome), "grayscale SOS write failed");
      Assert
        (Storage =
           [16#FF#, 16#C0#, 0, 11,
            8, 0, 8, 0, 16, 1, 1, 16#11#, 0,
            16#FF#, 16#DA#, 0, 8,
            1, 1, 0, 0, 63, 0],
         "grayscale frame/scan bytes mismatch");
   end Writer_Emits_Grayscale_Frame_And_Scan;

   procedure Writer_Emits_YCbCr_Frame_And_Scan (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 33 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      Outcome :=
        Jpeglib.Internal.Writers.Write_SOF0_YCbCr
          (Destination,
           Width => 16,
           Height => 8,
           Luma_Horizontal_Sampling => 2,
           Luma_Vertical_Sampling => 2);
      Assert (Jpeglib.Results.Succeeded (Outcome), "YCbCr SOF0 write failed");
      Outcome := Jpeglib.Internal.Writers.Write_SOS_YCbCr (Destination);
      Assert (Jpeglib.Results.Succeeded (Outcome), "YCbCr SOS write failed");
      Assert
        (Storage =
           [16#FF#, 16#C0#, 0, 17,
            8, 0, 8, 0, 16, 3,
            1, 16#22#, 0,
            2, 16#11#, 1,
            3, 16#11#, 1,
            16#FF#, 16#DA#, 0, 12,
            3,
            1, 0,
            2, 16#11#,
            3, 16#11#,
            0, 63, 0],
         "YCbCr frame/scan bytes mismatch");
   end Writer_Emits_YCbCr_Frame_And_Scan;

   procedure Writer_Emits_Arithmetic_Frames (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 64 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      Outcome := Jpeglib.Internal.Writers.Write_SOF9_Grayscale (Destination, Width => 16, Height => 8);
      Assert (Jpeglib.Results.Succeeded (Outcome), "SOF9 grayscale write failed");
      Outcome :=
        Jpeglib.Internal.Writers.Write_SOF10_YCbCr
          (Destination,
           Width => 16,
           Height => 8,
           Luma_Horizontal_Sampling => 2,
           Luma_Vertical_Sampling => 2);
      Assert (Jpeglib.Results.Succeeded (Outcome), "SOF10 YCbCr write failed");
      Outcome := Jpeglib.Internal.Writers.Write_SOF11_Grayscale (Destination, Width => 2, Height => 1);
      Assert (Jpeglib.Results.Succeeded (Outcome), "SOF11 grayscale write failed");
      Outcome := Jpeglib.Internal.Writers.Write_SOF11_RGB (Destination, Width => 2, Height => 1);
      Assert (Jpeglib.Results.Succeeded (Outcome), "SOF11 RGB write failed");
      Assert
        (Storage (1 .. 13) =
           [16#FF#, 16#C9#, 0, 11,
            8, 0, 8, 0, 16, 1, 1, 16#11#, 0],
         "SOF9 grayscale frame bytes mismatch");
      Assert
        (Storage (14 .. 32) =
           [16#FF#, 16#CA#, 0, 17,
            8, 0, 8, 0, 16, 3,
            1, 16#22#, 0,
            2, 16#11#, 1,
            3, 16#11#, 1],
         "SOF10 YCbCr frame bytes mismatch");
      Assert
        (Storage (33 .. 45) =
           [16#FF#, 16#CB#, 0, 11,
            8, 0, 1, 0, 2, 1, 1, 16#11#, 0],
         "SOF11 grayscale frame bytes mismatch");
      Assert
        (Storage (46 .. 64) =
           [16#FF#, 16#CB#, 0, 17,
            8, 0, 1, 0, 2, 3,
            16#52#, 16#11#, 0,
            16#47#, 16#11#, 0,
            16#42#, 16#11#, 0],
         "SOF11 RGB frame bytes mismatch");
   end Writer_Emits_Arithmetic_Frames;

   procedure Writer_Rejects_Oversized_Frame (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 16 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      Outcome :=
        Jpeglib.Internal.Writers.Write_SOF0_Grayscale
          (Destination, Width => Jpeglib.Image_Width (65_536), Height => 8);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "oversized SOF0 frame was accepted");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Frame_Invalid_Definition,
         "oversized SOF0 frame used wrong error");
   end Writer_Rejects_Oversized_Frame;

   procedure Bit_Writer_Packs_MSB_First (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 2 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      declare
         Writer : Jpeglib.Internal.Bit_Streams.Bit_Writer (Destination'Access);
      begin
         Outcome := Jpeglib.Internal.Bit_Streams.Write_Bits (Writer, 3, 2#101#);
         Assert (Jpeglib.Results.Succeeded (Outcome), "first bit write failed");
         Outcome := Jpeglib.Internal.Bit_Streams.Write_Bits (Writer, 5, 2#10010#);
         Assert (Jpeglib.Results.Succeeded (Outcome), "second bit write failed");
         Outcome := Jpeglib.Internal.Bit_Streams.Flush_Byte (Writer);
         Assert (Jpeglib.Results.Succeeded (Outcome), "aligned flush failed");
      end;
      Assert (Storage (1) = 2#10110010#, "MSB-first packed byte mismatch");
      Assert (Jpeglib.Streams.Offset (Destination) = 1, "aligned flush wrote extra byte");
   end Bit_Writer_Packs_MSB_First;

   procedure Bit_Writer_Stuffs_FF_Bytes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 3 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      declare
         Writer : Jpeglib.Internal.Bit_Streams.Bit_Writer (Destination'Access);
      begin
         Outcome := Jpeglib.Internal.Bit_Streams.Write_Bits (Writer, 8, 16#FF#);
         Assert (Jpeglib.Results.Succeeded (Outcome), "FF bit write failed");
         Outcome := Jpeglib.Internal.Bit_Streams.Write_Bits (Writer, 3, 2#101#);
         Assert (Jpeglib.Results.Succeeded (Outcome), "partial bit write failed");
         Outcome := Jpeglib.Internal.Bit_Streams.Flush_Byte (Writer, Pad => 0);
         Assert (Jpeglib.Results.Succeeded (Outcome), "partial flush failed");
      end;
      Assert (Storage = [16#FF#, 0, 2#10100000#], "bit writer stuffing or padding mismatch");
   end Bit_Writer_Stuffs_FF_Bytes;

   procedure Bit_Writer_Rejects_Invalid_Category (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 2 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      declare
         Writer : Jpeglib.Internal.Bit_Streams.Bit_Writer (Destination'Access);
      begin
         Outcome := Jpeglib.Internal.Bit_Streams.Write_Bits (Writer, 3, 8);
      end;
      Assert (not Jpeglib.Results.Succeeded (Outcome), "out-of-range entropy bits were accepted");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Entropy_Invalid_Category,
         "out-of-range entropy bits used wrong error");
      Assert (Jpeglib.Streams.Offset (Destination) = 0, "invalid entropy bits wrote output");
   end Bit_Writer_Rejects_Invalid_Category;

   procedure Bit_Writer_Emits_Restart_Marker (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 4 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      declare
         Writer : Jpeglib.Internal.Bit_Streams.Bit_Writer (Destination'Access);
      begin
         Outcome := Jpeglib.Internal.Bit_Streams.Write_Bits (Writer, 4, 2#0100#);
         Assert (Jpeglib.Results.Succeeded (Outcome), "restart preamble bit write failed");
         Outcome := Jpeglib.Internal.Bit_Streams.Write_Restart_Marker (Writer, Jpeglib.Internal.Markers.RST0);
         Assert (Jpeglib.Results.Succeeded (Outcome), "restart marker write failed");
      end;
      Assert (Storage = [16#4F#, 16#FF#, 16#D0#, 0], "restart marker bytes mismatch");
      Assert (Jpeglib.Streams.Offset (Destination) = 3, "restart marker write length mismatch");
   end Bit_Writer_Emits_Restart_Marker;

   overriding function Read
     (Object : in out Zero_Progress_Source;
      Buffer : out Jpeglib.Streams.Byte_Array) return Jpeglib.Streams.Source_Result
   is
      pragma Unreferenced (Object, Buffer);
   begin
      return (Result => Jpeglib.Errors.Make (Jpeglib.Errors.No_Error), Count => 0, End_Of_Input => False);
   end Read;

   overriding function Offset (Object : Zero_Progress_Source) return Jpeglib.Source_Offset is
   begin
      return Object.Current_Offset;
   end Offset;

   overriding function Skip
     (Object : in out Zero_Progress_Source;
      Count : Jpeglib.Byte_Count) return Jpeglib.Streams.Source_Result
   is
      pragma Unreferenced (Object, Count);
   begin
      return (Result => Jpeglib.Errors.Make (Jpeglib.Errors.No_Error), Count => 0, End_Of_Input => False);
   end Skip;

   overriding function Read
     (Object : in out One_Byte_Skip_Source;
      Buffer : out Jpeglib.Streams.Byte_Array) return Jpeglib.Streams.Source_Result
   is
      Available : Natural;
      To_Copy : Natural;
   begin
      if Object.Storage = null then
         return (Result => Jpeglib.Errors.Make (Jpeglib.Errors.Source_Read_Failed), Count => 0, End_Of_Input => False);
      end if;

      Available := Object.Storage'Length - Object.Position;
      To_Copy := Natural'Min (Buffer'Length, Available);

      for I in 0 .. To_Copy - 1 loop
         Buffer (Buffer'First + I) := Object.Storage (Object.Storage'First + Object.Position + I);
      end loop;

      Object.Position := Object.Position + To_Copy;
      return
        (Result => Jpeglib.Errors.Make (Jpeglib.Errors.No_Error),
         Count => Jpeglib.Byte_Count (To_Copy),
         End_Of_Input => To_Copy = 0);
   end Read;

   overriding function Offset (Object : One_Byte_Skip_Source) return Jpeglib.Source_Offset is
   begin
      return Jpeglib.Source_Offset (Object.Position);
   end Offset;

   overriding function Skip
     (Object : in out One_Byte_Skip_Source;
      Count : Jpeglib.Byte_Count) return Jpeglib.Streams.Source_Result
   is
      Available : Natural;
      To_Skip : Natural;
   begin
      if Object.Storage = null then
         return (Result => Jpeglib.Errors.Make (Jpeglib.Errors.Source_Read_Failed), Count => 0, End_Of_Input => False);
      end if;

      Available := Object.Storage'Length - Object.Position;
      if Count = 0 or else Available = 0 then
         To_Skip := 0;
      else
         To_Skip := 1;
      end if;

      Object.Position := Object.Position + To_Skip;
      Object.Skip_Calls := Object.Skip_Calls + 1;
      return
        (Result => Jpeglib.Errors.Make (Jpeglib.Errors.No_Error),
         Count => Jpeglib.Byte_Count (To_Skip),
         End_Of_Input => To_Skip = 0);
   end Skip;

   procedure Byte_Reader_Detects_Zero_Progress (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : Zero_Progress_Source;
      Result : constant Jpeglib.Internal.Bytes.Read_Byte_Result := Jpeglib.Internal.Bytes.Read_Byte (Source);
   begin
      Assert (not Jpeglib.Results.Succeeded (Result.Outcome), "zero-progress read succeeded");
      Assert
        (Result.Outcome.First_Error.Code = Jpeglib.Errors.Source_Zero_Progress,
         "zero-progress read used wrong error");
   end Byte_Reader_Detects_Zero_Progress;

   procedure Marker_Reader_Normalizes_Fill (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Jpeglib.Internal.Markers;
      Source : Jpeglib.Streams.Memory_Source;
      Result : Marker_Result;
   begin
      Jpeglib.Streams.Open (Source, Marker_Fill_Storage'Access);
      Result := Read_Next (Source);
      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "marker read failed");
      Assert (Result.Marker = SOI, "SOI marker not returned");
      Assert (Result.Source = 1, "marker offset mismatch");
   end Marker_Reader_Normalizes_Fill;

   procedure Segment_Reader_Stays_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, Segment_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.DQT, 10);
         First : Jpeglib.Internal.Bytes.Read_Byte_Result;
         Second : Jpeglib.Internal.Bytes.Read_Byte_Result;
      begin
         Assert (Jpeglib.Results.Succeeded (Jpeglib.Internal.Segments.Status (Segment)), "segment open failed");
         Assert (Jpeglib.Internal.Segments.Remaining (Segment) = 1, "payload length mismatch");
         First := Jpeglib.Internal.Segments.Read_Byte (Segment);
         Assert (Jpeglib.Results.Succeeded (First.Outcome), "payload byte read failed");
         Assert (First.Value = 16#AB#, "payload byte mismatch");
         Second := Jpeglib.Internal.Segments.Read_Byte (Segment);
         Assert (not Jpeglib.Results.Succeeded (Second.Outcome), "segment boundary was crossed");
         Assert
           (Second.Outcome.First_Error.Code = Jpeglib.Errors.Segment_Boundary_Exceeded,
           "segment boundary used wrong error");
      end;
   end Segment_Reader_Stays_Bounded;

   procedure Segment_Skip_Handles_Short_Progress (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased constant Jpeglib.Streams.Byte_Array := [0, 8, 1, 2, 3, 4, 5, 6];
      Source : aliased One_Byte_Skip_Source;
   begin
      Source.Storage := Storage'Unchecked_Access;
      Source.Position := 0;
      Source.Skip_Calls := 0;
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.APP1, 0);
         Outcome : Jpeglib.Results.Result;
      begin
         Assert (Jpeglib.Results.Succeeded (Jpeglib.Internal.Segments.Status (Segment)), "short-skip open failed");
         Outcome := Jpeglib.Internal.Segments.Skip_Remaining (Segment);
         Assert (Jpeglib.Results.Succeeded (Outcome), "short-skip segment skip failed");
         Assert (Jpeglib.Internal.Segments.Remaining (Segment) = 0, "short-skip segment retained bytes");
         Assert (Source.Position = 8, "short-skip source offset mismatch");
         Assert (Source.Skip_Calls = 6, "short-skip call count mismatch");
      end;
   end Segment_Skip_Handles_Short_Progress;

   procedure Fixed_Buffer_Destination_Reports_Partial_Write (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 3 => 0];
      Destination : Jpeglib.Streams.Fixed_Buffer_Destination;
      First : Jpeglib.Streams.Destination_Result;
      Second : Jpeglib.Streams.Destination_Result;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      First := Jpeglib.Streams.Write (Destination, [1 => 16#AA#, 2 => 16#BB#]);
      Assert (not Jpeglib.Errors.Is_Fatal (First.Result), "initial destination write failed");
      Assert (First.Count = 2, "initial destination write count mismatch");
      Assert (Jpeglib.Streams.Offset (Destination) = 2, "initial destination offset mismatch");

      Second := Jpeglib.Streams.Write (Destination, [1 => 16#CC#, 2 => 16#DD#]);
      Assert (Jpeglib.Errors.Is_Fatal (Second.Result), "partial destination write succeeded");
      Assert (Second.Result.Code = Jpeglib.Errors.Output_Limit_Exceeded, "partial destination write error mismatch");
      Assert (Second.Count = 1, "partial destination write count mismatch");
      Assert (Jpeglib.Streams.Offset (Destination) = 3, "partial destination offset mismatch");
      Assert (Storage = [16#AA#, 16#BB#, 16#CC#], "partial destination storage mismatch");
   end Fixed_Buffer_Destination_Reports_Partial_Write;

end Jpeglib_Testing.Test_Writers_Streams;

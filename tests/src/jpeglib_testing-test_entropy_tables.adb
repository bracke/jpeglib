with AUnit.Assertions;

with Jpeglib;
with Jpeglib.Errors;
with Jpeglib.Internal.Bit_Streams;
with Jpeglib.Internal.Huffman;
with Jpeglib.Internal.Markers;
with Jpeglib.Internal.Quantization;
with Jpeglib.Internal.Segments;
with Jpeglib.Results;
with Jpeglib.Streams;

package body Jpeglib_Testing.Test_Entropy_Tables is
   use AUnit.Assertions;
   use type Jpeglib.Byte;
   use type Jpeglib.Destination_Offset;
   use type Jpeglib.Errors.Error_Code;
   use type Jpeglib.Internal.Bit_Streams.Bit_Value;
   use type Jpeglib.Internal.Bit_Streams.Entropy_Value;

   DQT_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 67, 0,
      1, 2, 3, 4, 5, 6, 7, 8,
      9, 10, 11, 12, 13, 14, 15, 16,
      17, 18, 19, 20, 21, 22, 23, 24,
      25, 26, 27, 28, 29, 30, 31, 32,
      33, 34, 35, 36, 37, 38, 39, 40,
      41, 42, 43, 44, 45, 46, 47, 48,
      49, 50, 51, 52, 53, 54, 55, 56,
      57, 58, 59, 60, 61, 62, 63, 64];
   Bad_DQT_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 67, 0,
      0, 2, 3, 4, 5, 6, 7, 8,
      9, 10, 11, 12, 13, 14, 15, 16,
      17, 18, 19, 20, 21, 22, 23, 24,
      25, 26, 27, 28, 29, 30, 31, 32,
      33, 34, 35, 36, 37, 38, 39, 40,
      41, 42, 43, 44, 45, 46, 47, 48,
      49, 50, 51, 52, 53, 54, 55, 56,
      57, 58, 59, 60, 61, 62, 63, 64];
   DHT_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 20, 0,
      0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      16#05#];
   DHT_Tiny_Canonical_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 21, 0,
      1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      16#AA#, 16#BB#];
   Bad_DHT_Class_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 20, 16#20#,
      0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      16#05#];
   Bad_DHT_Oversubscribed_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [0, 21, 0,
      3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      1, 2, 3];
   Bit_Storage : aliased constant Jpeglib.Streams.Byte_Array := [16#A0#];
   Huffman_Bit_Storage : aliased constant Jpeglib.Streams.Byte_Array := [16#40#];
   Huffman_Marker_Storage : aliased constant Jpeglib.Streams.Byte_Array := [16#FF#, 16#D9#];

   procedure DQT_Parser_Stores_Natural_Order (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure DQT_Parser_Rejects_Zero_Values (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Quantization_Generates_Luma_Quality_Table (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Quantization_Generates_Chroma_Quality_Table (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure DHT_Parser_Stores_DC_Table (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure DHT_Parser_Rejects_Invalid_Class (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure DHT_Parser_Rejects_Oversubscription (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Huffman_Provides_Standard_Luma_Tables (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Huffman_Provides_Standard_Chroma_Tables (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Bit_Reader_Reads_MSB_First (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Huffman_Decoder_Uses_Canonical_Codes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Huffman_Decoder_Stops_At_Marker (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Huffman_Encoder_Writes_Canonical_Codes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Huffman_Encoder_Rejects_Missing_Symbol (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Entropy_Sign_Extension_Is_Deterministic (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Entropy_Sign_Extension_Rejects_Out_Of_Range (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("entropy_tables");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, DQT_Parser_Stores_Natural_Order'Access, "foundation.quantization.dqt_natural_order");
      Register_Routine (T, DQT_Parser_Rejects_Zero_Values'Access, "foundation.quantization.dqt_zero");
      Register_Routine (T, Quantization_Generates_Luma_Quality_Table'Access, "foundation.quantization.luma_quality");
      Register_Routine
        (T,
         Quantization_Generates_Chroma_Quality_Table'Access,
         "foundation.quantization.chroma_quality");
      Register_Routine (T, DHT_Parser_Stores_DC_Table'Access, "foundation.huffman.dht_dc");
      Register_Routine (T, DHT_Parser_Rejects_Invalid_Class'Access, "foundation.huffman.dht_invalid_class");
      Register_Routine (T, DHT_Parser_Rejects_Oversubscription'Access, "foundation.huffman.dht_oversubscribed");
      Register_Routine (T, Huffman_Provides_Standard_Luma_Tables'Access, "foundation.huffman.standard_luma_tables");
      Register_Routine (T, Huffman_Provides_Standard_Chroma_Tables'Access, "foundation.huffman.standard_chroma_tables");
      Register_Routine (T, Bit_Reader_Reads_MSB_First'Access, "foundation.entropy.bits_msb_first");
      Register_Routine (T, Huffman_Decoder_Uses_Canonical_Codes'Access, "foundation.huffman.decode_canonical");
      Register_Routine (T, Huffman_Decoder_Stops_At_Marker'Access, "foundation.huffman.decode_marker");
      Register_Routine (T, Huffman_Encoder_Writes_Canonical_Codes'Access, "foundation.huffman.encode_canonical");
      Register_Routine (T, Huffman_Encoder_Rejects_Missing_Symbol'Access, "foundation.huffman.encode_missing_symbol");
      Register_Routine (T, Entropy_Sign_Extension_Is_Deterministic'Access, "foundation.entropy.sign_extend");
      Register_Routine
        (T,
         Entropy_Sign_Extension_Rejects_Out_Of_Range'Access,
         "foundation.entropy.sign_extend_invalid");
   end Register_Tests;

   procedure DQT_Parser_Stores_Natural_Order (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Jpeglib.Internal.Quantization.Quantization_Value;
      Source : aliased Jpeglib.Streams.Memory_Source;
      State : Jpeglib.Internal.Quantization.Quantization_State;
   begin
      Jpeglib.Streams.Open (Source, DQT_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.DQT, 20);
         Outcome : Jpeglib.Results.Result;
         Table : Jpeglib.Internal.Quantization.Quantization_Table;
      begin
         Outcome := Jpeglib.Internal.Quantization.Parse_DQT (State, Segment);
         Assert (Jpeglib.Results.Succeeded (Outcome), "DQT parse failed");
         Assert (Jpeglib.Internal.Quantization.Has_Table (State, 0), "table 0 not installed");
         Table := Jpeglib.Internal.Quantization.Table (State, 0);
         Assert (Table (0) = 1, "natural coefficient 0 mismatch");
         Assert (Table (1) = 2, "natural coefficient 1 mismatch");
         Assert (Table (8) = 3, "zigzag coefficient 2 not mapped to natural 8");
         Assert (Table (63) = 64, "last natural coefficient mismatch");
      end;
   end DQT_Parser_Stores_Natural_Order;

   procedure DQT_Parser_Rejects_Zero_Values (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      State : Jpeglib.Internal.Quantization.Quantization_State;
   begin
      Jpeglib.Streams.Open (Source, Bad_DQT_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.DQT, 30);
         Outcome : constant Jpeglib.Results.Result :=
           Jpeglib.Internal.Quantization.Parse_DQT (State, Segment);
      begin
         Assert (not Jpeglib.Results.Succeeded (Outcome), "zero quantization value accepted");
         Assert
           (Outcome.First_Error.Code = Jpeglib.Errors.Table_Invalid_Definition,
            "zero quantization value used wrong error");
         Assert (not Jpeglib.Internal.Quantization.Has_Table (State, 0), "malformed table was installed");
      end;
   end DQT_Parser_Rejects_Zero_Values;

   procedure Quantization_Generates_Luma_Quality_Table (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Jpeglib.Internal.Quantization.Quantization_Value;
      Quality_50 : constant Jpeglib.Internal.Quantization.Quantization_Table :=
        Jpeglib.Internal.Quantization.Luma_Table_For_Quality (50);
      Quality_100 : constant Jpeglib.Internal.Quantization.Quantization_Table :=
        Jpeglib.Internal.Quantization.Luma_Table_For_Quality (100);
      Quality_1 : constant Jpeglib.Internal.Quantization.Quantization_Table :=
        Jpeglib.Internal.Quantization.Luma_Table_For_Quality (1);
   begin
      Assert (Quality_50 (0) = 16, "quality 50 luma DC mismatch");
      Assert (Quality_50 (1) = 11, "quality 50 luma coefficient 1 mismatch");
      Assert (Quality_50 (63) = 99, "quality 50 luma final coefficient mismatch");

      for Item of Quality_100 loop
         Assert (Item = 1, "quality 100 luma table was not all ones");
      end loop;

      Assert (Quality_1 (0) = 255, "quality 1 luma DC was not clamped");
      Assert (Quality_1 (63) = 255, "quality 1 luma final coefficient was not clamped");
   end Quantization_Generates_Luma_Quality_Table;

   procedure Quantization_Generates_Chroma_Quality_Table (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Jpeglib.Internal.Quantization.Quantization_Value;
      Quality_50 : constant Jpeglib.Internal.Quantization.Quantization_Table :=
        Jpeglib.Internal.Quantization.Chroma_Table_For_Quality (50);
      Quality_100 : constant Jpeglib.Internal.Quantization.Quantization_Table :=
        Jpeglib.Internal.Quantization.Chroma_Table_For_Quality (100);
      Quality_1 : constant Jpeglib.Internal.Quantization.Quantization_Table :=
        Jpeglib.Internal.Quantization.Chroma_Table_For_Quality (1);
   begin
      Assert (Quality_50 (0) = 17, "quality 50 chroma DC mismatch");
      Assert (Quality_50 (1) = 18, "quality 50 chroma coefficient 1 mismatch");
      Assert (Quality_50 (2) = 24, "quality 50 chroma coefficient 2 mismatch");
      Assert (Quality_50 (63) = 99, "quality 50 chroma final coefficient mismatch");

      for Item of Quality_100 loop
         Assert (Item = 1, "quality 100 chroma table was not all ones");
      end loop;

      Assert (Quality_1 (0) = 255, "quality 1 chroma DC was not clamped");
      Assert (Quality_1 (63) = 255, "quality 1 chroma final coefficient was not clamped");
   end Quantization_Generates_Chroma_Quality_Table;

   procedure DHT_Parser_Stores_DC_Table (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Jpeglib.Internal.Huffman.Symbol_Count;
      Source : aliased Jpeglib.Streams.Memory_Source;
      State : Jpeglib.Internal.Huffman.Huffman_State;
   begin
      Jpeglib.Streams.Open (Source, DHT_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.DHT, 40);
         Outcome : constant Jpeglib.Results.Result := Jpeglib.Internal.Huffman.Parse_DHT (State, Segment);
         Definition : Jpeglib.Internal.Huffman.Huffman_Definition;
         Counts : Jpeglib.Internal.Huffman.Length_Counts;
      begin
         Assert (Jpeglib.Results.Succeeded (Outcome), "DHT parse failed");
         Assert (Jpeglib.Internal.Huffman.Has_Table (State, Jpeglib.Internal.Huffman.DC, 0), "DC table not stored");
         Definition := Jpeglib.Internal.Huffman.Definition (State, Jpeglib.Internal.Huffman.DC, 0);
         Counts := Jpeglib.Internal.Huffman.Counts (Definition);
         Assert (Jpeglib.Internal.Huffman.Symbol_Total (Definition) = 1, "symbol count mismatch");
         Assert (Counts (2) = 1, "length-2 count mismatch");
         Assert (Jpeglib.Internal.Huffman.Symbol (Definition, 1) = 16#05#, "symbol mismatch");
      end;
   end DHT_Parser_Stores_DC_Table;

   procedure DHT_Parser_Rejects_Invalid_Class (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      State : Jpeglib.Internal.Huffman.Huffman_State;
   begin
      Jpeglib.Streams.Open (Source, Bad_DHT_Class_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.DHT, 50);
         Outcome : constant Jpeglib.Results.Result := Jpeglib.Internal.Huffman.Parse_DHT (State, Segment);
      begin
         Assert (not Jpeglib.Results.Succeeded (Outcome), "invalid Huffman class accepted");
         Assert
           (Outcome.First_Error.Code = Jpeglib.Errors.Huffman_Invalid_Definition,
            "invalid Huffman class used wrong error");
         Assert
           (not Jpeglib.Internal.Huffman.Has_Table (State, Jpeglib.Internal.Huffman.DC, 0),
            "invalid table was installed");
      end;
   end DHT_Parser_Rejects_Invalid_Class;

   procedure DHT_Parser_Rejects_Oversubscription (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
      State : Jpeglib.Internal.Huffman.Huffman_State;
   begin
      Jpeglib.Streams.Open (Source, Bad_DHT_Oversubscribed_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.DHT, 60);
         Outcome : constant Jpeglib.Results.Result := Jpeglib.Internal.Huffman.Parse_DHT (State, Segment);
      begin
         Assert (not Jpeglib.Results.Succeeded (Outcome), "oversubscribed Huffman tree accepted");
         Assert
           (Outcome.First_Error.Code = Jpeglib.Errors.Huffman_Invalid_Definition,
            "oversubscribed Huffman tree used wrong error");
      end;
   end DHT_Parser_Rejects_Oversubscription;

   procedure Huffman_Provides_Standard_Luma_Tables (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Jpeglib.Internal.Huffman.Symbol_Count;
      DC : constant Jpeglib.Internal.Huffman.Huffman_Definition :=
        Jpeglib.Internal.Huffman.Standard_Luminance_DC;
      AC : constant Jpeglib.Internal.Huffman.Huffman_Definition :=
        Jpeglib.Internal.Huffman.Standard_Luminance_AC;
      DC_Counts : constant Jpeglib.Internal.Huffman.Length_Counts := Jpeglib.Internal.Huffman.Counts (DC);
      AC_Counts : constant Jpeglib.Internal.Huffman.Length_Counts := Jpeglib.Internal.Huffman.Counts (AC);
   begin
      Assert (Jpeglib.Internal.Huffman.Symbol_Total (DC) = 12, "standard luma DC total mismatch");
      Assert (DC_Counts (2) = 1, "standard luma DC length-2 count mismatch");
      Assert (DC_Counts (3) = 5, "standard luma DC length-3 count mismatch");
      Assert (Jpeglib.Internal.Huffman.Symbol (DC, 1) = 0, "standard luma DC first symbol mismatch");
      Assert (Jpeglib.Internal.Huffman.Symbol (DC, 12) = 11, "standard luma DC final symbol mismatch");

      Assert (Jpeglib.Internal.Huffman.Symbol_Total (AC) = 162, "standard luma AC total mismatch");
      Assert (AC_Counts (2) = 2, "standard luma AC length-2 count mismatch");
      Assert (AC_Counts (16) = 125, "standard luma AC length-16 count mismatch");
      Assert (Jpeglib.Internal.Huffman.Symbol (AC, 4) = 0, "standard luma AC EOB symbol mismatch");
      Assert (Jpeglib.Internal.Huffman.Symbol (AC, 32) = 16#F0#, "standard luma AC ZRL symbol mismatch");
      Assert (Jpeglib.Internal.Huffman.Symbol (AC, 162) = 16#FA#, "standard luma AC final symbol mismatch");
   end Huffman_Provides_Standard_Luma_Tables;

   procedure Huffman_Provides_Standard_Chroma_Tables (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Jpeglib.Internal.Huffman.Symbol_Count;
      DC : constant Jpeglib.Internal.Huffman.Huffman_Definition :=
        Jpeglib.Internal.Huffman.Standard_Chrominance_DC;
      AC : constant Jpeglib.Internal.Huffman.Huffman_Definition :=
        Jpeglib.Internal.Huffman.Standard_Chrominance_AC;
      DC_Counts : constant Jpeglib.Internal.Huffman.Length_Counts := Jpeglib.Internal.Huffman.Counts (DC);
      AC_Counts : constant Jpeglib.Internal.Huffman.Length_Counts := Jpeglib.Internal.Huffman.Counts (AC);
   begin
      Assert (Jpeglib.Internal.Huffman.Symbol_Total (DC) = 12, "standard chroma DC total mismatch");
      Assert (DC_Counts (2) = 3, "standard chroma DC length-2 count mismatch");
      Assert (DC_Counts (11) = 1, "standard chroma DC length-11 count mismatch");
      Assert (Jpeglib.Internal.Huffman.Symbol (DC, 1) = 0, "standard chroma DC first symbol mismatch");
      Assert (Jpeglib.Internal.Huffman.Symbol (DC, 12) = 11, "standard chroma DC final symbol mismatch");

      Assert (Jpeglib.Internal.Huffman.Symbol_Total (AC) = 162, "standard chroma AC total mismatch");
      Assert (AC_Counts (2) = 2, "standard chroma AC length-2 count mismatch");
      Assert (AC_Counts (14) = 1, "standard chroma AC length-14 count mismatch");
      Assert (AC_Counts (16) = 119, "standard chroma AC length-16 count mismatch");
      Assert (Jpeglib.Internal.Huffman.Symbol (AC, 1) = 0, "standard chroma AC EOB symbol mismatch");
      Assert (Jpeglib.Internal.Huffman.Symbol (AC, 32) = 16#F0#, "standard chroma AC ZRL symbol mismatch");
      Assert (Jpeglib.Internal.Huffman.Symbol (AC, 162) = 16#FA#, "standard chroma AC final symbol mismatch");
   end Huffman_Provides_Standard_Chroma_Tables;

   procedure Bit_Reader_Reads_MSB_First (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, Bit_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Reader (Entropy'Access);
         B0 : constant Jpeglib.Internal.Bit_Streams.Bit_Result := Jpeglib.Internal.Bit_Streams.Read_Bit (Bits);
         B1 : constant Jpeglib.Internal.Bit_Streams.Bit_Result := Jpeglib.Internal.Bit_Streams.Read_Bit (Bits);
         B2 : constant Jpeglib.Internal.Bit_Streams.Bit_Result := Jpeglib.Internal.Bit_Streams.Read_Bit (Bits);
         B3 : constant Jpeglib.Internal.Bit_Streams.Bit_Result := Jpeglib.Internal.Bit_Streams.Read_Bit (Bits);
      begin
         Assert (Jpeglib.Results.Succeeded (B0.Outcome), "first bit read failed");
         Assert (B0.Value = 1, "bit 0 mismatch");
         Assert (B1.Value = 0, "bit 1 mismatch");
         Assert (B2.Value = 1, "bit 2 mismatch");
         Assert (B3.Value = 0, "bit 3 mismatch");
      end;
   end Bit_Reader_Reads_MSB_First;

   function Tiny_Canonical_Definition return Jpeglib.Internal.Huffman.Huffman_Definition is
      Source : aliased Jpeglib.Streams.Memory_Source;
      State : Jpeglib.Internal.Huffman.Huffman_State;
   begin
      Jpeglib.Streams.Open (Source, DHT_Tiny_Canonical_Storage'Access);
      declare
         Segment : Jpeglib.Internal.Segments.Segment_Reader :=
           Jpeglib.Internal.Segments.Open (Source'Access, Jpeglib.Internal.Markers.DHT, 140);
         Outcome : constant Jpeglib.Results.Result := Jpeglib.Internal.Huffman.Parse_DHT (State, Segment);
      begin
         Assert (Jpeglib.Results.Succeeded (Outcome), "tiny canonical DHT parse failed");
         return Jpeglib.Internal.Huffman.Definition (State, Jpeglib.Internal.Huffman.DC, 0);
      end;
   end Tiny_Canonical_Definition;

   procedure Huffman_Decoder_Uses_Canonical_Codes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Definition : constant Jpeglib.Internal.Huffman.Huffman_Definition := Tiny_Canonical_Definition;
      Compiled : constant Jpeglib.Internal.Huffman.Compile_Result := Jpeglib.Internal.Huffman.Compile (Definition);
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Assert (Jpeglib.Results.Succeeded (Compiled.Outcome), "Huffman compile failed");
      Jpeglib.Streams.Open (Source, Huffman_Bit_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Reader (Entropy'Access);
         First : constant Jpeglib.Internal.Huffman.Decode_Result :=
           Jpeglib.Internal.Huffman.Decode (Compiled.Table, Bits);
         Second : constant Jpeglib.Internal.Huffman.Decode_Result :=
           Jpeglib.Internal.Huffman.Decode (Compiled.Table, Bits);
      begin
         Assert (Jpeglib.Results.Succeeded (First.Outcome), "first Huffman decode failed");
         Assert (First.Symbol = 16#AA#, "first Huffman symbol mismatch");
         Assert (Jpeglib.Results.Succeeded (Second.Outcome), "second Huffman decode failed");
         Assert (Second.Symbol = 16#BB#, "second Huffman symbol mismatch");
      end;
   end Huffman_Decoder_Uses_Canonical_Codes;

   procedure Huffman_Decoder_Stops_At_Marker (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Definition : constant Jpeglib.Internal.Huffman.Huffman_Definition := Tiny_Canonical_Definition;
      Compiled : constant Jpeglib.Internal.Huffman.Compile_Result := Jpeglib.Internal.Huffman.Compile (Definition);
      Source : aliased Jpeglib.Streams.Memory_Source;
   begin
      Jpeglib.Streams.Open (Source, Huffman_Marker_Storage'Access);
      declare
         Entropy : aliased Jpeglib.Internal.Bit_Streams.Entropy_Reader (Source'Access);
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Reader (Entropy'Access);
         Result : constant Jpeglib.Internal.Huffman.Decode_Result :=
           Jpeglib.Internal.Huffman.Decode (Compiled.Table, Bits);
      begin
         Assert (not Jpeglib.Results.Succeeded (Result.Outcome), "marker during Huffman decode was accepted");
         Assert
           (Result.Outcome.First_Error.Code = Jpeglib.Errors.Entropy_Unexpected_Marker,
            "marker during Huffman decode used wrong error");
      end;
   end Huffman_Decoder_Stops_At_Marker;

   procedure Huffman_Encoder_Writes_Canonical_Codes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Definition : constant Jpeglib.Internal.Huffman.Huffman_Definition := Tiny_Canonical_Definition;
      Compiled : constant Jpeglib.Internal.Huffman.Compile_Result := Jpeglib.Internal.Huffman.Compile (Definition);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 2 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Assert (Jpeglib.Results.Succeeded (Compiled.Outcome), "Huffman compile failed");
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      declare
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Writer (Destination'Access);
      begin
         Outcome := Jpeglib.Internal.Huffman.Encode (Compiled.Table, Bits, 16#AA#);
         Assert (Jpeglib.Results.Succeeded (Outcome), "first Huffman encode failed");
         Outcome := Jpeglib.Internal.Huffman.Encode (Compiled.Table, Bits, 16#BB#);
         Assert (Jpeglib.Results.Succeeded (Outcome), "second Huffman encode failed");
         Outcome := Jpeglib.Internal.Bit_Streams.Flush_Byte (Bits);
         Assert (Jpeglib.Results.Succeeded (Outcome), "Huffman encode flush failed");
      end;
      Assert (Storage (1) = 16#5F#, "canonical Huffman encoded byte mismatch");
      Assert (Jpeglib.Streams.Offset (Destination) = 1, "canonical Huffman encode wrote wrong length");
   end Huffman_Encoder_Writes_Canonical_Codes;

   procedure Huffman_Encoder_Rejects_Missing_Symbol (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Definition : constant Jpeglib.Internal.Huffman.Huffman_Definition := Tiny_Canonical_Definition;
      Compiled : constant Jpeglib.Internal.Huffman.Compile_Result := Jpeglib.Internal.Huffman.Compile (Definition);
      Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 2 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Outcome : Jpeglib.Results.Result;
   begin
      Assert (Jpeglib.Results.Succeeded (Compiled.Outcome), "Huffman compile failed");
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      declare
         Bits : Jpeglib.Internal.Bit_Streams.Bit_Writer (Destination'Access);
      begin
         Outcome := Jpeglib.Internal.Huffman.Encode (Compiled.Table, Bits, 16#CC#);
      end;
      Assert (not Jpeglib.Results.Succeeded (Outcome), "missing Huffman symbol was encoded");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Huffman_Invalid_Definition,
         "missing Huffman symbol used wrong error");
      Assert (Jpeglib.Streams.Offset (Destination) = 0, "missing Huffman symbol wrote output");
   end Huffman_Encoder_Rejects_Missing_Symbol;

   procedure Assert_Sign
     (Category : Jpeglib.Internal.Bit_Streams.Entropy_Category;
      Bits : Jpeglib.Internal.Bit_Streams.Entropy_Bits;
      Expected : Jpeglib.Internal.Bit_Streams.Entropy_Value)
   is
      Result : constant Jpeglib.Internal.Bit_Streams.Sign_Extend_Result :=
        Jpeglib.Internal.Bit_Streams.Sign_Extend (Category, Bits);
   begin
      Assert (Jpeglib.Results.Succeeded (Result.Outcome), "sign extension failed");
      Assert (Result.Value = Expected, "sign extension value mismatch");
   end Assert_Sign;

   procedure Entropy_Sign_Extension_Is_Deterministic (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert_Sign (0, 0, 0);
      Assert_Sign (1, 0, -1);
      Assert_Sign (1, 1, 1);
      Assert_Sign (2, 0, -3);
      Assert_Sign (2, 1, -2);
      Assert_Sign (2, 2, 2);
      Assert_Sign (2, 3, 3);
      Assert_Sign (3, 0, -7);
      Assert_Sign (3, 3, -4);
      Assert_Sign (3, 4, 4);
      Assert_Sign (3, 7, 7);
   end Entropy_Sign_Extension_Is_Deterministic;

   procedure Entropy_Sign_Extension_Rejects_Out_Of_Range (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Result : constant Jpeglib.Internal.Bit_Streams.Sign_Extend_Result :=
        Jpeglib.Internal.Bit_Streams.Sign_Extend (2, 4);
   begin
      Assert (not Jpeglib.Results.Succeeded (Result.Outcome), "out-of-range entropy bits accepted");
      Assert
        (Result.Outcome.First_Error.Code = Jpeglib.Errors.Entropy_Invalid_Category,
         "out-of-range entropy bits used wrong error");
   end Entropy_Sign_Extension_Rejects_Out_Of_Range;

end Jpeglib_Testing.Test_Entropy_Tables;

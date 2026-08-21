with Interfaces;
with Jpeglib.Coefficients;
with Jpeglib.Streams;
with Jpeglib.Internal.Segments;
with Jpeglib.Internal.Bit_Streams;
with Jpeglib.Results;

package Jpeglib.Internal.Arithmetic is
   pragma Preelaborate;

   type Conditioning_Class is (DC, AC);
   type Conditioning_Value is new Byte;

   type Arithmetic_State is private;
   type Probability_Bin is private;
   type Probability_Bin_Array is array (Natural range <>) of Probability_Bin;
   type Decoded_Coefficient_Map is array (Positive range <>, Coefficient_Index range <>) of Boolean;
   type Decoder (Entropy : not null access Bit_Streams.Entropy_Reader) is limited private;
   type Encoder (Output : not null access Streams.Destination'Class) is limited private;
   type DC_Difference is new Interfaces.Integer_32;
   subtype DC_Context_Index is Natural range 0 .. 16;
   type DC_Context_Array is array (Component_Index) of DC_Context_Index;
   subtype DC_Difference_Decision_Index is Positive range 1 .. 64;
   type DC_Difference_Decision_Array is array (DC_Difference_Decision_Index range <>) of
     Bit_Streams.Bit_Value;

   type DC_Difference_Decision_Result is record
      Outcome : Results.Result := Results.Success;
      Length : Natural range 0 .. 64 := 0;
      Decisions : DC_Difference_Decision_Array (1 .. 64) := [others => 0];
   end record;

   type DC_Difference_Event is record
      Bin_Index : Natural range 0 .. 48 := 0;
      Decision : Bit_Streams.Bit_Value := 0;
   end record;

   type DC_Difference_Event_Array is array (DC_Difference_Decision_Index range <>) of
     DC_Difference_Event;

   type DC_Difference_Event_Result is record
      Outcome : Results.Result := Results.Success;
      Length : Natural range 0 .. 64 := 0;
      Events : DC_Difference_Event_Array (1 .. 64) := [others => <>];
      Final_Context : DC_Context_Index := 0;
   end record;

   type Decision_Result is record
      Outcome : Results.Result := Results.Success;
      Source : Source_Offset := 0;
      Decision : Bit_Streams.Bit_Value := 0;
   end record;

   type DC_Result is record
      Outcome : Results.Result := Results.Success;
      Source : Source_Offset := 0;
      Difference : DC_Difference := 0;
   end record;

   type AC_EOB_Result is record
      Outcome : Results.Result := Results.Success;
      Source : Source_Offset := 0;
      End_Of_Block : Boolean := False;
   end record;

   type Block_Result is record
      Outcome : Results.Result := Results.Success;
      Block : Jpeglib.Coefficients.DCT_Block := [others => 0];
   end record;

   function Initial_Probability_Bin return Probability_Bin;
   function MPS_Sense (Bin : Probability_Bin) return Bit_Streams.Bit_Value;
   function State_Index (Bin : Probability_Bin) return Natural;

   function Has_Table
     (State : Arithmetic_State;
      Class : Conditioning_Class;
      Index : Table_Index) return Boolean;

   function Value
     (State : Arithmetic_State;
      Class : Conditioning_Class;
      Index : Table_Index) return Conditioning_Value
     with Pre => Has_Table (State, Class, Index);

   function DC_Lower_Bound (Definition : Conditioning_Value) return Natural
     with Pre => Definition <= 16#FF#;
   function DC_Upper_Bound (Definition : Conditioning_Value) return Natural
     with Pre => Definition <= 16#FF#;

   function Parse_DAC
     (State : in out Arithmetic_State;
      Segment : in out Segments.Segment_Reader) return Results.Result;

   function Decode_Bit
     (Object : in out Decoder;
      Bin : in out Probability_Bin) return Decision_Result;

   procedure Reset (Object : in out Decoder);

   procedure Reset (Object : in out Encoder);

   function Encode_Bit
     (Object : in out Encoder;
      Bin : in out Probability_Bin;
      Decision : Bit_Streams.Bit_Value) return Results.Result;

   function Finish (Object : in out Encoder) return Results.Result;

   function Decode_DC_Difference
     (Object : in out Decoder;
      Bins : in out Probability_Bin_Array;
      Context : in out DC_Context_Index;
      Conditioning : Conditioning_Value) return DC_Result
     with Pre => Bins'First <= 0 and then Bins'Last >= 48;

   function Encode_DC_Difference_Decisions
     (Difference : DC_Difference) return DC_Difference_Decision_Result;

   function Encode_DC_Difference_Events
     (Difference : DC_Difference;
      Context : DC_Context_Index;
      Conditioning : Conditioning_Value) return DC_Difference_Event_Result;

   function Encode_DC_Difference
     (Object : in out Encoder;
      Bins : in out Probability_Bin_Array;
      Context : in out DC_Context_Index;
      Conditioning : Conditioning_Value;
      Difference : DC_Difference) return Results.Result
     with Pre => Bins'First <= 0 and then Bins'Last >= 48;

   function Encode_Sequential_Block
     (Object : in out Encoder;
      DC_Bins : in out Probability_Bin_Array;
      AC_Bins : in out Probability_Bin_Array;
      Fixed_Bin : in out Probability_Bin;
      DC_Context : in out DC_Context_Index;
      Predictor : in out DC_Difference;
      DC_Conditioning : Conditioning_Value;
      AC_Conditioning : Conditioning_Value;
      Block : Jpeglib.Coefficients.DCT_Block) return Results.Result
     with Pre => DC_Bins'First <= 0 and then DC_Bins'Last >= 48
                 and then AC_Bins'First <= 0 and then AC_Bins'Last >= 245;

   function Encode_Progressive_AC_First
     (Object : in out Encoder;
      Bins : in out Probability_Bin_Array;
      Fixed_Bin : in out Probability_Bin;
      AC_Conditioning : Conditioning_Value;
      Spectral_Start : Coefficient_Index;
      Spectral_End : Coefficient_Index;
      Successive_Low : Natural;
      Block : Jpeglib.Coefficients.DCT_Block) return Results.Result
     with Pre => Bins'First <= 0 and then Bins'Last >= 245
                 and then Spectral_Start in 1 .. 63
                 and then Spectral_End in Spectral_Start .. 63;

   function Encode_Progressive_DC_Refine
     (Object : in out Encoder;
      Bin : in out Probability_Bin;
      Block : Jpeglib.Coefficients.DCT_Block;
      Successive_Low : Natural) return Results.Result;

   function Encode_Progressive_AC_Refine
     (Object : in out Encoder;
      Bins : in out Probability_Bin_Array;
      Fixed_Bin : in out Probability_Bin;
      AC_Conditioning : Conditioning_Value;
      Spectral_Start : Coefficient_Index;
      Spectral_End : Coefficient_Index;
      Successive_Low : Natural;
      Decoded_Coefficients : in out Decoded_Coefficient_Map;
      Block_Number : Positive;
      Block : Jpeglib.Coefficients.DCT_Block) return Results.Result
     with Pre => Bins'First <= 0 and then Bins'Last >= 245
                 and then Spectral_Start in 1 .. 63
                 and then Spectral_End in Spectral_Start .. 63
                 and then Block_Number in Decoded_Coefficients'Range (1)
                 and then Decoded_Coefficients'First (2) <= Spectral_Start
                 and then Decoded_Coefficients'Last (2) >= Spectral_End;

   function Decode_AC_EOB
     (Object : in out Decoder;
      Bins : in out Probability_Bin_Array) return AC_EOB_Result
     with Pre => Bins'First <= 0 and then Bins'Last >= 0;

   function Decode_Progressive_AC_First
     (Object : in out Decoder;
      Bins : in out Probability_Bin_Array;
      Fixed_Bin : in out Probability_Bin;
      AC_Conditioning : Conditioning_Value;
      Spectral_Start : Coefficient_Index;
      Spectral_End : Coefficient_Index;
      Successive_Low : Natural;
      Decoded_Coefficients : in out Decoded_Coefficient_Map;
      Block_Number : Positive;
      Block : in out Jpeglib.Coefficients.DCT_Block) return Results.Result
     with Pre => Bins'First <= 0 and then Bins'Last >= 245
                 and then Spectral_Start in 1 .. 63
                 and then Spectral_End in Spectral_Start .. 63
                 and then Block_Number in Decoded_Coefficients'Range (1)
                 and then Decoded_Coefficients'First (2) <= Spectral_Start
                 and then Decoded_Coefficients'Last (2) >= Spectral_End;

   function Decode_Progressive_AC_Refine
     (Object : in out Decoder;
      Bins : in out Probability_Bin_Array;
      Fixed_Bin : in out Probability_Bin;
      AC_Conditioning : Conditioning_Value;
      Spectral_Start : Coefficient_Index;
      Spectral_End : Coefficient_Index;
      Successive_Low : Natural;
      Decoded_Coefficients : in out Decoded_Coefficient_Map;
      Block_Number : Positive;
      Block : in out Jpeglib.Coefficients.DCT_Block) return Results.Result
     with Pre => Bins'First <= 0 and then Bins'Last >= 0
                 and then Spectral_Start in 1 .. 63
                 and then Spectral_End in Spectral_Start .. 63
                 and then Block_Number in Decoded_Coefficients'Range (1)
                 and then Decoded_Coefficients'First (2) <= Spectral_Start
                 and then Decoded_Coefficients'Last (2) >= Spectral_End;

   function Decode_DC_EOB_Block
     (Object : in out Decoder;
      DC_Bins : in out Probability_Bin_Array;
      AC_Bins : in out Probability_Bin_Array;
      DC_Context : in out DC_Context_Index;
      Predictor : in out DC_Difference;
      DC_Conditioning : Conditioning_Value) return Block_Result
     with Pre => DC_Bins'First <= 0 and then DC_Bins'Last >= 48
                 and then AC_Bins'First <= 0 and then AC_Bins'Last >= 0;

   function Decode_Sequential_Block
     (Object : in out Decoder;
      DC_Bins : in out Probability_Bin_Array;
      AC_Bins : in out Probability_Bin_Array;
      Fixed_Bin : in out Probability_Bin;
      DC_Context : in out DC_Context_Index;
      Predictor : in out DC_Difference;
      DC_Conditioning : Conditioning_Value;
      AC_Conditioning : Conditioning_Value) return Block_Result
     with Pre => DC_Bins'First <= 0 and then DC_Bins'Last >= 48
                 and then AC_Bins'First <= 0 and then AC_Bins'Last >= 245;

private
   type Probability_Bin is record
      MPS : Bit_Streams.Bit_Value := 0;
      Index : Natural range 0 .. 113 := 0;
   end record;

   type Decoder (Entropy : not null access Bit_Streams.Entropy_Reader) is limited record
      C : Interfaces.Integer_64 := 0;
      A : Interfaces.Integer_64 := 0;
      CT : Integer range -17 .. 8 := -16;
      Last_Source : Source_Offset := 0;
   end record;

   type Encoder (Output : not null access Streams.Destination'Class) is limited record
      C : Interfaces.Integer_64 := 0;
      A : Interfaces.Integer_64 := 16#1_0000#;
      SC : Interfaces.Integer_64 := 0;
      ZC : Interfaces.Integer_64 := 0;
      CT : Integer range 0 .. 11 := 11;
      Buffer : Integer range -1 .. 255 := -1;
   end record;

   type Presence_By_Index is array (Table_Index) of Boolean;
   type Value_By_Index is array (Table_Index) of Conditioning_Value;
   type Presence_By_Class is array (Conditioning_Class) of Presence_By_Index;
   type Value_By_Class is array (Conditioning_Class) of Value_By_Index;

   type Arithmetic_State is record
      Present : Presence_By_Class := [others => [others => False]];
      Tables : Value_By_Class := [others => [others => 0]];
   end record;
end Jpeglib.Internal.Arithmetic;

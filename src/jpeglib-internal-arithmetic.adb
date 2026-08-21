with Jpeglib.Errors;
with Jpeglib.Internal.Bytes;
with Jpeglib.Internal.Markers;

package body Jpeglib.Internal.Arithmetic is
   use type Interfaces.Integer_64;
   use type Bit_Streams.Entropy_Byte_Kind;
   use type Bit_Streams.Bit_Value;
   use type Jpeglib.Errors.Error_Code;
   use type Jpeglib.Coefficients.Quantized_Coefficient;

   Zigzag_To_Natural : constant array (Coefficient_Index) of Coefficient_Index :=
     [0, 1, 8, 16, 9, 2, 3, 10,
      17, 24, 32, 25, 18, 11, 4, 5,
      12, 19, 26, 33, 40, 48, 41, 34,
      27, 20, 13, 6, 7, 14, 21, 28,
      35, 42, 49, 56, 57, 50, 43, 36,
      29, 22, 15, 23, 30, 37, 44, 51,
      58, 59, 52, 45, 38, 31, 39, 46,
      53, 60, 61, 54, 47, 55, 62, 63];

   type Probability_Entry is record
      Qe : Interfaces.Integer_64;
      Next_LPS : Natural range 0 .. 113;
      Next_MPS : Natural range 0 .. 113;
      Switch_MPS : Boolean;
   end record;

   type Probability_Table is array (Natural range 0 .. 113) of Probability_Entry;

   --  JPEG arithmetic probability estimation state machine from T.81 table D.2/D.3.
   Entries : constant Probability_Table :=
     [0 => (16#5A1D#, 1, 1, True),
      1 => (16#2586#, 14, 2, False),
      2 => (16#1114#, 16, 3, False),
      3 => (16#080B#, 18, 4, False),
      4 => (16#03D8#, 20, 5, False),
      5 => (16#01DA#, 23, 6, False),
      6 => (16#00E5#, 25, 7, False),
      7 => (16#006F#, 28, 8, False),
      8 => (16#0036#, 30, 9, False),
      9 => (16#001A#, 33, 10, False),
      10 => (16#000D#, 35, 11, False),
      11 => (16#0006#, 9, 12, False),
      12 => (16#0003#, 10, 13, False),
      13 => (16#0001#, 12, 13, False),
      14 => (16#5A7F#, 15, 15, True),
      15 => (16#3F25#, 36, 16, False),
      16 => (16#2CF2#, 38, 17, False),
      17 => (16#207C#, 39, 18, False),
      18 => (16#17B9#, 40, 19, False),
      19 => (16#1182#, 42, 20, False),
      20 => (16#0CEF#, 43, 21, False),
      21 => (16#09A1#, 45, 22, False),
      22 => (16#072F#, 46, 23, False),
      23 => (16#055C#, 48, 24, False),
      24 => (16#0406#, 49, 25, False),
      25 => (16#0303#, 51, 26, False),
      26 => (16#0240#, 52, 27, False),
      27 => (16#01B1#, 54, 28, False),
      28 => (16#0144#, 56, 29, False),
      29 => (16#00F5#, 57, 30, False),
      30 => (16#00B7#, 59, 31, False),
      31 => (16#008A#, 60, 32, False),
      32 => (16#0068#, 62, 33, False),
      33 => (16#004E#, 63, 34, False),
      34 => (16#003B#, 32, 35, False),
      35 => (16#002C#, 33, 9, False),
      36 => (16#5AE1#, 37, 37, True),
      37 => (16#484C#, 64, 38, False),
      38 => (16#3A0D#, 65, 39, False),
      39 => (16#2EF1#, 67, 40, False),
      40 => (16#261F#, 68, 41, False),
      41 => (16#1F33#, 69, 42, False),
      42 => (16#19A8#, 70, 43, False),
      43 => (16#1518#, 72, 44, False),
      44 => (16#1177#, 73, 45, False),
      45 => (16#0E74#, 74, 46, False),
      46 => (16#0BFB#, 75, 47, False),
      47 => (16#09F8#, 77, 48, False),
      48 => (16#0861#, 78, 49, False),
      49 => (16#0706#, 79, 50, False),
      50 => (16#05CD#, 48, 51, False),
      51 => (16#04DE#, 50, 52, False),
      52 => (16#040F#, 50, 53, False),
      53 => (16#0363#, 51, 54, False),
      54 => (16#02D4#, 52, 55, False),
      55 => (16#025C#, 53, 56, False),
      56 => (16#01F8#, 54, 57, False),
      57 => (16#01A4#, 55, 58, False),
      58 => (16#0160#, 56, 59, False),
      59 => (16#0125#, 57, 60, False),
      60 => (16#00F6#, 58, 61, False),
      61 => (16#00CB#, 59, 62, False),
      62 => (16#00AB#, 61, 63, False),
      63 => (16#008F#, 61, 32, False),
      64 => (16#5B12#, 65, 65, True),
      65 => (16#4D04#, 80, 66, False),
      66 => (16#412C#, 81, 67, False),
      67 => (16#37D8#, 82, 68, False),
      68 => (16#2FE8#, 83, 69, False),
      69 => (16#293C#, 84, 70, False),
      70 => (16#2379#, 86, 71, False),
      71 => (16#1EDF#, 87, 72, False),
      72 => (16#1AA9#, 87, 73, False),
      73 => (16#174E#, 72, 74, False),
      74 => (16#1424#, 72, 75, False),
      75 => (16#119C#, 74, 76, False),
      76 => (16#0F6B#, 74, 77, False),
      77 => (16#0D51#, 75, 78, False),
      78 => (16#0BB6#, 77, 79, False),
      79 => (16#0A40#, 77, 48, False),
      80 => (16#5832#, 80, 81, True),
      81 => (16#4D1C#, 88, 82, False),
      82 => (16#438E#, 89, 83, False),
      83 => (16#3BDD#, 90, 84, False),
      84 => (16#34EE#, 91, 85, False),
      85 => (16#2EAE#, 92, 86, False),
      86 => (16#299A#, 93, 87, False),
      87 => (16#2516#, 86, 71, False),
      88 => (16#5570#, 88, 89, True),
      89 => (16#4CA9#, 95, 90, False),
      90 => (16#44D9#, 96, 91, False),
      91 => (16#3E22#, 97, 92, False),
      92 => (16#3824#, 99, 93, False),
      93 => (16#32B4#, 99, 94, False),
      94 => (16#2E17#, 93, 86, False),
      95 => (16#56A8#, 95, 96, True),
      96 => (16#4F46#, 101, 97, False),
      97 => (16#47E5#, 102, 98, False),
      98 => (16#41CF#, 103, 99, False),
      99 => (16#3C3D#, 104, 100, False),
      100 => (16#375E#, 99, 93, False),
      101 => (16#5231#, 105, 102, False),
      102 => (16#4C0F#, 106, 103, False),
      103 => (16#4639#, 107, 104, False),
      104 => (16#415E#, 103, 99, False),
      105 => (16#5627#, 105, 106, True),
      106 => (16#50E7#, 108, 107, False),
      107 => (16#4B85#, 109, 103, False),
      108 => (16#5597#, 110, 109, False),
      109 => (16#504F#, 111, 107, False),
      110 => (16#5A10#, 110, 111, True),
      111 => (16#5522#, 112, 109, False),
      112 => (16#59EB#, 112, 111, True),
      113 => (16#5A1D#, 113, 113, False)];

   function Invalid
     (Segment : Segments.Segment_Reader;
      Source : Source_Offset;
      Detail : Long_Long_Integer := 0) return Results.Result
   is
   begin
      return
        Results.Failure
          (Errors.Make
             (Errors.Table_Invalid_Definition,
              (Source => Source,
               Marker => Segments.Descriptor (Segment).Marker,
               Detail => Detail,
                others => <>)));
   end Invalid;

   function Initial_Probability_Bin return Probability_Bin is
   begin
      return (MPS => 0, Index => 0);
   end Initial_Probability_Bin;

   function MPS_Sense (Bin : Probability_Bin) return Bit_Streams.Bit_Value is
   begin
      return Bin.MPS;
   end MPS_Sense;

   function State_Index (Bin : Probability_Bin) return Natural is
   begin
      return Bin.Index;
   end State_Index;

   function Has_Table
     (State : Arithmetic_State;
      Class : Conditioning_Class;
      Index : Table_Index) return Boolean
   is
   begin
      return State.Present (Class) (Index);
   end Has_Table;

   function Value
     (State : Arithmetic_State;
      Class : Conditioning_Class;
      Index : Table_Index) return Conditioning_Value
   is
   begin
      return State.Tables (Class) (Index);
   end Value;

   function DC_Lower_Bound (Definition : Conditioning_Value) return Natural is
   begin
      return Natural (Definition) / 16;
   end DC_Lower_Bound;

   function DC_Upper_Bound (Definition : Conditioning_Value) return Natural is
   begin
      return Natural (Definition) mod 16;
   end DC_Upper_Bound;

   function Parse_DAC
     (State : in out Arithmetic_State;
      Segment : in out Segments.Segment_Reader) return Results.Result
   is
      Descriptor : constant Segments.Segment_Descriptor := Segments.Descriptor (Segment);
      Table_Byte : Bytes.Read_Byte_Result;
      Value_Byte : Bytes.Read_Byte_Result;
      Class_Nibble : Natural;
      Table_Nibble : Natural;
      Class : Conditioning_Class;
      Index : Table_Index;
   begin
      if Descriptor.Marker /= Markers.DAC
        or else Descriptor.Payload_Length = 0
        or else Descriptor.Payload_Length mod 2 /= 0
      then
         return Invalid (Segment, Descriptor.Payload_Source, Long_Long_Integer (Descriptor.Payload_Length));
      end if;

      while Segments.Remaining (Segment) > 0 loop
         Table_Byte := Segments.Read_Byte (Segment);
         if not Results.Succeeded (Table_Byte.Outcome) then
            return Table_Byte.Outcome;
         end if;

         Value_Byte := Segments.Read_Byte (Segment);
         if not Results.Succeeded (Value_Byte.Outcome) then
            return Value_Byte.Outcome;
         end if;

         Class_Nibble := Natural (Table_Byte.Value) / 16;
         Table_Nibble := Natural (Table_Byte.Value) mod 16;

         if Class_Nibble > 1 or else Table_Nibble > 3 then
            return Invalid (Segment, Table_Byte.Source, Long_Long_Integer (Table_Byte.Value));
         end if;

         Class := (if Class_Nibble = 0 then DC else AC);
         Index := Table_Index (Table_Nibble);
         State.Present (Class) (Index) := True;
         State.Tables (Class) (Index) := Conditioning_Value (Value_Byte.Value);
      end loop;

      return Results.Success;
   end Parse_DAC;

   function Read_Arithmetic_Byte (Object : in out Decoder) return Decision_Result is
      Item : constant Bit_Streams.Entropy_Read_Result := Bit_Streams.Read_Byte (Object.Entropy.all);
   begin
      if not Results.Succeeded (Item.Outcome) then
         return (Outcome => Item.Outcome, Source => Item.Source, Decision => 0);
      end if;

      Object.Last_Source := Item.Source;
      if Item.Kind = Bit_Streams.Entropy_Data then
         Object.C := Object.C * 256 + Interfaces.Integer_64 (Item.Value);
      elsif Item.Kind = Bit_Streams.Restart_Marker then
         Bit_Streams.Put_Back_Marker (Object.Entropy.all, Item.Source, Item.Marker);
         Object.C := Object.C * 256;
      else
         Object.C := Object.C * 256;
      end if;

      return (Outcome => Results.Success, Source => Item.Source, Decision => 0);
   end Read_Arithmetic_Byte;

   function Decode_Bit
     (Object : in out Decoder;
      Bin : in out Probability_Bin) return Decision_Result
   is
      Input : Decision_Result;
      State_Entry : Probability_Entry;
      Temp : Interfaces.Integer_64;
      Decision : Bit_Streams.Bit_Value;
      MPS : Bit_Streams.Bit_Value;
   begin
      while Object.A < 16#8000# loop
         Object.CT := Object.CT - 1;
         if Object.CT < 0 then
            Input := Read_Arithmetic_Byte (Object);
            if not Results.Succeeded (Input.Outcome) then
               return Input;
            end if;

            Object.CT := Object.CT + 8;
            if Object.CT < 0 then
               Object.CT := Object.CT + 1;
               if Object.CT = 0 then
                  Object.A := 16#8000#;
               end if;
            end if;
         end if;

         Object.A := Object.A * 2;
      end loop;

      State_Entry := Entries (Bin.Index);
      MPS := Bin.MPS;
      Decision := MPS;
      Temp := Object.A - State_Entry.Qe;
      Object.A := Temp;
      Temp := Temp * (2 ** Object.CT);

      if Object.C >= Temp then
         Object.C := Object.C - Temp;
         if Object.A < State_Entry.Qe then
            Object.A := State_Entry.Qe;
            Bin.Index := State_Entry.Next_MPS;
         else
            Object.A := State_Entry.Qe;
            Decision := Bit_Streams.Bit_Value (1 - Natural (MPS));
            if State_Entry.Switch_MPS then
               Bin.MPS := Decision;
            end if;
            Bin.Index := State_Entry.Next_LPS;
         end if;
      elsif Object.A < 16#8000# then
         if Object.A < State_Entry.Qe then
            Decision := Bit_Streams.Bit_Value (1 - Natural (MPS));
            if State_Entry.Switch_MPS then
               Bin.MPS := Decision;
            end if;
            Bin.Index := State_Entry.Next_LPS;
         else
            Bin.Index := State_Entry.Next_MPS;
         end if;
      end if;

      return (Outcome => Results.Success, Source => Object.Last_Source, Decision => Decision);
   end Decode_Bit;

   procedure Reset (Object : in out Decoder) is
   begin
      Object.C := 0;
      Object.A := 0;
      Object.CT := -16;
      Object.Last_Source := 0;
   end Reset;

   procedure Reset (Object : in out Encoder) is
   begin
      Object.C := 0;
      Object.A := 16#1_0000#;
      Object.SC := 0;
      Object.ZC := 0;
      Object.CT := 11;
      Object.Buffer := -1;
   end Reset;

   function Emit_Raw_Byte
     (Object : in out Encoder;
      Value : Byte) return Results.Result
   is
      Written : constant Streams.Destination_Result := Streams.Write (Object.Output.all, [1 => Value]);
   begin
      if Written.Result.Code /= Errors.No_Error then
         return Results.Failure (Written.Result);
      elsif Written.Count /= 1 then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      return Results.Success;
   end Emit_Raw_Byte;

   function Emit_Pending_Zeroes (Object : in out Encoder) return Results.Result is
      Outcome : Results.Result;
   begin
      while Object.ZC > 0 loop
         Outcome := Emit_Raw_Byte (Object, 0);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Object.ZC := Object.ZC - 1;
      end loop;

      return Results.Success;
   end Emit_Pending_Zeroes;

   function Emit_Stuffed_Byte
     (Object : in out Encoder;
      Value : Byte) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Emit_Raw_Byte (Object, Value);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      elsif Value = 16#FF# then
         return Emit_Raw_Byte (Object, 0);
      end if;

      return Results.Success;
   end Emit_Stuffed_Byte;

   function Output_Ready_Byte (Object : in out Encoder) return Results.Result is
      Temp : constant Interfaces.Integer_64 := Object.C / (2 ** 19);
      Outcome : Results.Result;
   begin
      if Temp > 16#FF# then
         if Object.Buffer >= 0 then
            Outcome := Emit_Pending_Zeroes (Object);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Emit_Stuffed_Byte (Object, Byte (Object.Buffer + 1));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end if;

         Object.ZC := Object.ZC + Object.SC;
         Object.SC := 0;
         Object.Buffer := Natural (Temp) mod 256;
      elsif Temp = 16#FF# then
         Object.SC := Object.SC + 1;
      else
         if Object.Buffer = 0 then
            Object.ZC := Object.ZC + 1;
         elsif Object.Buffer >= 0 then
            Outcome := Emit_Pending_Zeroes (Object);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Emit_Raw_Byte (Object, Byte (Object.Buffer));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end if;

         if Object.SC > 0 then
            Outcome := Emit_Pending_Zeroes (Object);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            while Object.SC > 0 loop
               Outcome := Emit_Stuffed_Byte (Object, 16#FF#);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Object.SC := Object.SC - 1;
            end loop;
         end if;

         Object.Buffer := Natural (Temp) mod 256;
      end if;

      Object.C := Object.C mod (2 ** 19);
      Object.CT := Object.CT + 8;
      return Results.Success;
   end Output_Ready_Byte;

   function Encode_Bit
     (Object : in out Encoder;
      Bin : in out Probability_Bin;
      Decision : Bit_Streams.Bit_Value) return Results.Result
   is
      State_Entry : constant Probability_Entry := Entries (Bin.Index);
      Outcome : Results.Result;
   begin
      Object.A := Object.A - State_Entry.Qe;
      if Decision /= Bin.MPS then
         if Object.A >= State_Entry.Qe then
            Object.C := Object.C + Object.A;
            Object.A := State_Entry.Qe;
         end if;

         if State_Entry.Switch_MPS then
            Bin.MPS := Bit_Streams.Bit_Value (1 - Natural (Bin.MPS));
         end if;
         Bin.Index := State_Entry.Next_LPS;
      else
         if Object.A >= 16#8000# then
            return Results.Success;
         end if;

         if Object.A < State_Entry.Qe then
            Object.C := Object.C + Object.A;
            Object.A := State_Entry.Qe;
         end if;
         Bin.Index := State_Entry.Next_MPS;
      end if;

      loop
         Object.A := Object.A * 2;
         Object.C := Object.C * 2;
         Object.CT := Object.CT - 1;
         if Object.CT = 0 then
            Outcome := Output_Ready_Byte (Object);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end if;

         exit when Object.A >= 16#8000#;
      end loop;

      return Results.Success;
   end Encode_Bit;

   function Finish (Object : in out Encoder) return Results.Result is
      Temp : Interfaces.Integer_64;
      Outcome : Results.Result;
   begin
      Temp := ((Object.A - 1 + Object.C) / 16#1_0000#) * 16#1_0000#;
      if Temp < Object.C then
         Object.C := Temp + 16#8000#;
      else
         Object.C := Temp;
      end if;

      Object.C := Object.C * (2 ** Object.CT);
      if (Object.C / 16#0800_0000#) mod 32 /= 0 then
         if Object.Buffer >= 0 then
            Outcome := Emit_Pending_Zeroes (Object);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Emit_Stuffed_Byte (Object, Byte (Object.Buffer + 1));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end if;

         Object.ZC := Object.ZC + Object.SC;
         Object.SC := 0;
      else
         if Object.Buffer = 0 then
            Object.ZC := Object.ZC + 1;
         elsif Object.Buffer >= 0 then
            Outcome := Emit_Pending_Zeroes (Object);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Emit_Raw_Byte (Object, Byte (Object.Buffer));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end if;

         if Object.SC > 0 then
            Outcome := Emit_Pending_Zeroes (Object);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            while Object.SC > 0 loop
               Outcome := Emit_Stuffed_Byte (Object, 16#FF#);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Object.SC := Object.SC - 1;
            end loop;
         end if;
      end if;

      if (Object.C / (2 ** 11)) mod (2 ** 16) /= 0 then
         Outcome := Emit_Pending_Zeroes (Object);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Emit_Stuffed_Byte (Object, Byte ((Object.C / (2 ** 19)) mod 256));
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         if (Object.C / (2 ** 11)) mod 256 /= 0 then
            Outcome := Emit_Stuffed_Byte (Object, Byte ((Object.C / (2 ** 11)) mod 256));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end if;
      end if;

      return Results.Success;
   end Finish;

   function Coefficient_Error (Source : Source_Offset; Detail : Long_Long_Integer) return Results.Result is
   begin
      return
        Results.Failure
          (Errors.Make
             (Errors.Coefficient_Invalid_Encoding,
              (Source => Source, Detail => Detail, others => <>)));
   end Coefficient_Error;

   function Decode_DC_Difference
     (Object : in out Decoder;
      Bins : in out Probability_Bin_Array;
      Context : in out DC_Context_Index;
      Conditioning : Conditioning_Value) return DC_Result
   is
      Decision : Decision_Result;
      Sign : Natural := 0;
      M : Natural := 0;
      V : Natural := 0;
      Index : Natural;
      L : constant Natural := DC_Lower_Bound (Conditioning);
      U : constant Natural := DC_Upper_Bound (Conditioning);
      Low_Threshold : constant Natural := (2 ** L) / 2;
      High_Threshold : constant Natural := (2 ** U) / 2;
   begin
      Decision := Decode_Bit (Object, Bins (Context));
      if not Results.Succeeded (Decision.Outcome) then
         return (Outcome => Decision.Outcome, Source => Decision.Source, Difference => 0);
      elsif Decision.Decision = 0 then
         Context := 0;
         return (Outcome => Results.Success, Source => Decision.Source, Difference => 0);
      end if;

      Decision := Decode_Bit (Object, Bins (Context + 1));
      if not Results.Succeeded (Decision.Outcome) then
         return (Outcome => Decision.Outcome, Source => Decision.Source, Difference => 0);
      end if;
      Sign := Natural (Decision.Decision);

      Index := Context + 2 + Sign;
      Decision := Decode_Bit (Object, Bins (Index));
      if not Results.Succeeded (Decision.Outcome) then
         return (Outcome => Decision.Outcome, Source => Decision.Source, Difference => 0);
      end if;
      M := Natural (Decision.Decision);

      if M /= 0 then
         Index := 20;
         loop
            Decision := Decode_Bit (Object, Bins (Index));
            if not Results.Succeeded (Decision.Outcome) then
               return (Outcome => Decision.Outcome, Source => Decision.Source, Difference => 0);
            elsif Decision.Decision = 0 then
               exit;
            end if;

            M := M * 2;
            if M = 16#8000# then
               return
                 (Outcome => Coefficient_Error (Decision.Source, Long_Long_Integer (M)),
                  Source => Decision.Source,
                  Difference => 0);
            end if;
            Index := Index + 1;
         end loop;
      end if;

      if M < Low_Threshold then
         Context := 0;
      elsif M > High_Threshold then
         Context := DC_Context_Index (12 + Sign * 4);
      else
         Context := DC_Context_Index (4 + Sign * 4);
      end if;

      V := M;
      Index := Index + 14;
      while M > 1 loop
         M := M / 2;
         Decision := Decode_Bit (Object, Bins (Index));
         if not Results.Succeeded (Decision.Outcome) then
            return (Outcome => Decision.Outcome, Source => Decision.Source, Difference => 0);
         elsif Decision.Decision = 1 then
            V := V + M;
         end if;
      end loop;

      V := V + 1;
      if Sign = 0 then
         return (Outcome => Results.Success, Source => Decision.Source, Difference => DC_Difference (V));
      else
         return (Outcome => Results.Success, Source => Decision.Source, Difference => -DC_Difference (V));
      end if;
   end Decode_DC_Difference;

   function Encode_DC_Difference_Decisions
     (Difference : DC_Difference) return DC_Difference_Decision_Result
   is
      Events : constant DC_Difference_Event_Result :=
        Encode_DC_Difference_Events (Difference, 0, 0);
      Result : DC_Difference_Decision_Result;
   begin
      if not Results.Succeeded (Events.Outcome) then
         return
           (Outcome => Events.Outcome,
            Length => 0,
            Decisions => [others => 0]);
      end if;

      Result.Length := Events.Length;
      for Index in 1 .. Events.Length loop
         Result.Decisions (Index) := Events.Events (Index).Decision;
      end loop;

      return Result;
   end Encode_DC_Difference_Decisions;

   function Encode_DC_Difference_Events
     (Difference : DC_Difference;
      Context : DC_Context_Index;
      Conditioning : Conditioning_Value) return DC_Difference_Event_Result
   is
      Result : DC_Difference_Event_Result := (Final_Context => Context, others => <>);
      Magnitude : Natural;
      Base : Natural := 1;
      Remainder : Natural;
      Sign : Natural;
      Ladder_Index : Natural;
      Refinement_Index : Natural;
      L : constant Natural := DC_Lower_Bound (Conditioning);
      U : constant Natural := DC_Upper_Bound (Conditioning);
      Low_Threshold : constant Natural := (2 ** L) / 2;
      High_Threshold : constant Natural := (2 ** U) / 2;

      procedure Append
        (Bin_Index : Natural;
         Decision : Bit_Streams.Bit_Value)
      is
      begin
         Result.Length := Result.Length + 1;
         Result.Events (Result.Length) :=
           (Bin_Index => Bin_Index,
            Decision => Decision);
      end Append;
   begin
      if Difference = 0 then
         Append (Natural (Context), 0);
         Result.Final_Context := 0;
         return Result;
      elsif Difference = DC_Difference'First then
         return
           (Outcome => Coefficient_Error (0, Long_Long_Integer (Difference)),
            Length => 0,
            Events => [others => <>],
            Final_Context => Context);
      end if;

      Magnitude := Natural (abs Difference);
      if Magnitude > 16#7FFF# then
         return
           (Outcome => Coefficient_Error (0, Long_Long_Integer (Difference)),
            Length => 0,
            Events => [others => <>],
            Final_Context => Context);
      end if;

      Sign := (if Difference > 0 then 0 else 1);
      Append (Natural (Context), 1);
      Append (Natural (Context) + 1, Bit_Streams.Bit_Value (Sign));

      if Magnitude = 1 then
         Append (Natural (Context) + 2 + Sign, 0);
         if 0 < Low_Threshold then
            Result.Final_Context := 0;
         else
            Result.Final_Context := DC_Context_Index (4 + Sign * 4);
         end if;
         return Result;
      end if;

      Remainder := Magnitude - 1;
      while Base * 2 <= Remainder loop
         Base := Base * 2;
      end loop;

      Append (Natural (Context) + 2 + Sign, 1);
      Ladder_Index := 20;
      declare
         Step : Natural := 1;
      begin
         while Step < Base loop
            Append (Ladder_Index, 1);
            Step := Step * 2;
            Ladder_Index := Ladder_Index + 1;
         end loop;
      end;
      Append (Ladder_Index, 0);

      if Base < Low_Threshold then
         Result.Final_Context := 0;
      elsif Base > High_Threshold then
         Result.Final_Context := DC_Context_Index (12 + Sign * 4);
      else
         Result.Final_Context := DC_Context_Index (4 + Sign * 4);
      end if;

      Remainder := Remainder - Base;
      Refinement_Index := Ladder_Index + 14;
      while Base > 1 loop
         Base := Base / 2;
         if Remainder >= Base then
            Append (Refinement_Index, 1);
            Remainder := Remainder - Base;
         else
            Append (Refinement_Index, 0);
         end if;
      end loop;

      return Result;
   exception
      when Constraint_Error =>
         return
           (Outcome => Coefficient_Error (0, Long_Long_Integer (Difference)),
            Length => 0,
            Events => [others => <>],
           Final_Context => Context);
   end Encode_DC_Difference_Events;

   function Encode_DC_Difference
     (Object : in out Encoder;
      Bins : in out Probability_Bin_Array;
      Context : in out DC_Context_Index;
      Conditioning : Conditioning_Value;
      Difference : DC_Difference) return Results.Result
   is
      Events : constant DC_Difference_Event_Result :=
        Encode_DC_Difference_Events (Difference, Context, Conditioning);
      Outcome : Results.Result;
   begin
      if not Results.Succeeded (Events.Outcome) then
         return Events.Outcome;
      end if;

      for Index in 1 .. Events.Length loop
         Outcome := Encode_Bit (Object, Bins (Events.Events (Index).Bin_Index), Events.Events (Index).Decision);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end loop;

      Context := Events.Final_Context;
      return Results.Success;
   end Encode_DC_Difference;

   function Encode_AC_Coefficients
     (Object : in out Encoder;
      Bins : in out Probability_Bin_Array;
      Fixed_Bin : in out Probability_Bin;
      AC_Conditioning : Conditioning_Value;
      Block : Jpeglib.Coefficients.DCT_Block) return Results.Result
   is
      Last_Nonzero : Natural := 0;
      K : Natural := 1;
      Magnitude : Natural;
      Remainder : Natural;
      M : Natural;
      Temp : Natural;
      Bin_Index : Natural;
      Outcome : Results.Result;

      function Emit
        (Index : Natural;
         Decision : Bit_Streams.Bit_Value) return Results.Result is
      begin
         return Encode_Bit (Object, Bins (Index), Decision);
      end Emit;
   begin
      for Zigzag in reverse Coefficient_Index range 1 .. 63 loop
         if Block (Zigzag_To_Natural (Zigzag)) /= 0 then
            Last_Nonzero := Natural (Zigzag);
            exit;
         end if;
      end loop;

      while K <= Last_Nonzero loop
         Bin_Index := 3 * (K - 1);
         Outcome := Emit (Bin_Index, 0);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         while Block (Zigzag_To_Natural (Coefficient_Index (K))) = 0 loop
            Outcome := Emit (Bin_Index + 1, 0);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            K := K + 1;
            Bin_Index := Bin_Index + 3;
         end loop;

         Outcome := Emit (Bin_Index + 1, 1);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         if Block (Zigzag_To_Natural (Coefficient_Index (K))) > 0 then
            Outcome := Encode_Bit (Object, Fixed_Bin, 0);
            Magnitude := Natural (Block (Zigzag_To_Natural (Coefficient_Index (K))));
         else
            Outcome := Encode_Bit (Object, Fixed_Bin, 1);
            Magnitude := Natural (-Block (Zigzag_To_Natural (Coefficient_Index (K))));
         end if;
         if not Results.Succeeded (Outcome) then
            return Outcome;
         elsif Magnitude = 0 or else Magnitude > 16#7FFF# then
            return Coefficient_Error (0, Long_Long_Integer (Magnitude));
         end if;

         Bin_Index := Bin_Index + 2;
         Remainder := Magnitude - 1;
         M := 0;
         if Remainder /= 0 then
            Outcome := Emit (Bin_Index, 1);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            M := 1;
            Temp := Remainder / 2;
            if Temp /= 0 then
               Outcome := Emit (Bin_Index, 1);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               M := M * 2;
               Bin_Index := (if K <= Natural (AC_Conditioning) then 189 else 217);
               loop
                  Temp := Temp / 2;
                  exit when Temp = 0;

                  Outcome := Emit (Bin_Index, 1);
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  M := M * 2;
                  Bin_Index := Bin_Index + 1;
               end loop;
            end if;
         end if;

         Outcome := Emit (Bin_Index, 0);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Bin_Index := Bin_Index + 14;
         while M > 1 loop
            M := M / 2;
            Outcome :=
              Emit
                (Bin_Index,
                 (if (Remainder / M) mod 2 = 0 then 0 else 1));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;

         K := K + 1;
      end loop;

      if Last_Nonzero < 63 then
         return Emit (3 * Last_Nonzero, 1);
      end if;

      return Results.Success;
   exception
      when Constraint_Error =>
         return Coefficient_Error (0, 0);
   end Encode_AC_Coefficients;

   function Encode_Progressive_AC_First
     (Object : in out Encoder;
      Bins : in out Probability_Bin_Array;
      Fixed_Bin : in out Probability_Bin;
      AC_Conditioning : Conditioning_Value;
      Spectral_Start : Coefficient_Index;
      Spectral_End : Coefficient_Index;
      Successive_Low : Natural;
      Block : Jpeglib.Coefficients.DCT_Block) return Results.Result
   is
      Scale : constant Jpeglib.Coefficients.Quantized_Coefficient :=
        Jpeglib.Coefficients.Quantized_Coefficient (2 ** Successive_Low);
      Last_Nonzero : Natural := Natural (Spectral_Start) - 1;
      K : Natural := Natural (Spectral_Start);
      Coefficient : Jpeglib.Coefficients.Quantized_Coefficient;
      Magnitude : Natural;
      Remainder : Natural;
      M : Natural;
      Temp : Natural;
      Bin_Index : Natural;
      Outcome : Results.Result;

      function Emit
        (Index : Natural;
         Decision : Bit_Streams.Bit_Value) return Results.Result is
      begin
         return Encode_Bit (Object, Bins (Index), Decision);
      end Emit;
   begin
      for Zigzag in reverse Coefficient_Index range Spectral_Start .. Spectral_End loop
         Coefficient := Block (Zigzag_To_Natural (Zigzag));
         if Coefficient / Scale /= 0 then
            Last_Nonzero := Natural (Zigzag);
            exit;
         end if;
      end loop;

      while K <= Last_Nonzero loop
         Bin_Index := 3 * (K - 1);
         Outcome := Emit (Bin_Index, 1);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         while Block (Zigzag_To_Natural (Coefficient_Index (K))) / Scale = 0 loop
            Outcome := Emit (Bin_Index + 1, 0);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            K := K + 1;
            Bin_Index := Bin_Index + 3;
         end loop;

         Outcome := Emit (Bin_Index + 1, 1);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Coefficient := Block (Zigzag_To_Natural (Coefficient_Index (K))) / Scale;
         if Coefficient > 0 then
            Outcome := Encode_Bit (Object, Fixed_Bin, 0);
            Magnitude := Natural (Coefficient);
         else
            Outcome := Encode_Bit (Object, Fixed_Bin, 1);
            Magnitude := Natural (-Coefficient);
         end if;
         if not Results.Succeeded (Outcome) then
            return Outcome;
         elsif Magnitude = 0 or else Magnitude > 16#7FFF# then
            return Coefficient_Error (0, Long_Long_Integer (Magnitude));
         end if;

         Bin_Index := Bin_Index + 2;
         Remainder := Magnitude - 1;
         M := 0;
         if Remainder /= 0 then
            Outcome := Emit (Bin_Index, 1);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            M := 1;
            Temp := Remainder / 2;
            if Temp /= 0 then
               Outcome := Emit (Bin_Index, 1);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               M := M * 2;
               Bin_Index := (if K <= Natural (AC_Conditioning) then 189 else 217);
               loop
                  Temp := Temp / 2;
                  exit when Temp = 0;

                  Outcome := Emit (Bin_Index, 1);
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  M := M * 2;
                  Bin_Index := Bin_Index + 1;
               end loop;
            end if;
         end if;

         Outcome := Emit (Bin_Index, 0);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Bin_Index := Bin_Index + 14;
         while M > 1 loop
            M := M / 2;
            Outcome :=
              Emit
                (Bin_Index,
                 (if (Remainder / M) mod 2 = 0 then 0 else 1));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;

         K := K + 1;
      end loop;

      if Last_Nonzero < Natural (Spectral_End) then
         return Emit (3 * Last_Nonzero, 0);
      end if;

      return Results.Success;
   exception
      when Constraint_Error =>
         return Coefficient_Error (0, 0);
   end Encode_Progressive_AC_First;

   function Encode_Progressive_DC_Refine
     (Object : in out Encoder;
      Bin : in out Probability_Bin;
      Block : Jpeglib.Coefficients.DCT_Block;
      Successive_Low : Natural) return Results.Result
   is
      Scale : constant Jpeglib.Coefficients.Quantized_Coefficient :=
        Jpeglib.Coefficients.Quantized_Coefficient (2 ** Successive_Low);
      Bit : constant Natural := Natural ((abs Block (0) / Scale) mod 2);
   begin
      return Encode_Bit (Object, Bin, Bit_Streams.Bit_Value (Bit));
   exception
      when Constraint_Error =>
         return Coefficient_Error (0, Long_Long_Integer (Block (0)));
   end Encode_Progressive_DC_Refine;

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
   is
      Step : constant Jpeglib.Coefficients.Quantized_Coefficient :=
        Jpeglib.Coefficients.Quantized_Coefficient (2 ** Successive_Low);
      K : Natural := Natural (Spectral_Start);
      Target : Natural;
      Natural_Index : Coefficient_Index;
      Prior : Jpeglib.Coefficients.Quantized_Coefficient;
      Current : Jpeglib.Coefficients.Quantized_Coefficient;
      Outcome : Results.Result;

      function Refine_Bit (Value : Jpeglib.Coefficients.Quantized_Coefficient) return Bit_Streams.Bit_Value is
        (Bit_Streams.Bit_Value ((abs Value / Step) mod 2));

      function Existing_Nonzero (Zigzag_Index : Natural) return Boolean is
      begin
         Natural_Index := Zigzag_To_Natural (Coefficient_Index (Zigzag_Index));
         return Decoded_Coefficients (Block_Number, Natural_Index) and then Block (Natural_Index) /= 0;
      end Existing_Nonzero;

      function Newly_Significant (Zigzag_Index : Natural) return Boolean is
      begin
         Natural_Index := Zigzag_To_Natural (Coefficient_Index (Zigzag_Index));
         Prior := Block (Natural_Index) / (Step * 2);
         Current := Block (Natural_Index) / Step;
         return Prior = 0 and then Current /= 0;
      end Newly_Significant;

      function Emit (Index : Natural; Decision : Bit_Streams.Bit_Value) return Results.Result is
      begin
         return Encode_Bit (Object, Bins (Index), Decision);
      end Emit;

      function Emit_New_Significant (Zigzag_Index : Natural) return Results.Result is
         Coefficient : constant Jpeglib.Coefficients.Quantized_Coefficient :=
           Block (Zigzag_To_Natural (Coefficient_Index (Zigzag_Index)));
         Magnitude : Natural;
         Remainder : Natural;
         M : Natural := 0;
         Temp : Natural;
         Bin_Index : Natural := 3 * (Zigzag_Index - 1) + 2;
      begin
         if Coefficient > 0 then
            Outcome := Encode_Bit (Object, Fixed_Bin, 1);
            Magnitude := Natural (Coefficient / Step);
         else
            Outcome := Encode_Bit (Object, Fixed_Bin, 0);
            Magnitude := Natural ((-Coefficient) / Step);
         end if;
         if not Results.Succeeded (Outcome) then
            return Outcome;
         elsif Magnitude = 0 or else Magnitude > 16#7FFF# then
            return Coefficient_Error (0, Long_Long_Integer (Magnitude));
         end if;

         Remainder := Magnitude - 1;
         if Remainder /= 0 then
            Outcome := Emit (Bin_Index, 1);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            M := 1;
            Temp := Remainder / 2;
            if Temp /= 0 then
               Outcome := Emit (Bin_Index, 1);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               M := M * 2;
               Bin_Index := (if Zigzag_Index <= Natural (AC_Conditioning) then 189 else 217);
               loop
                  Temp := Temp / 2;
                  exit when Temp = 0;

                  Outcome := Emit (Bin_Index, 1);
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  M := M * 2;
                  Bin_Index := Bin_Index + 1;
               end loop;
            end if;
         end if;

         Outcome := Emit (Bin_Index, 0);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Bin_Index := Bin_Index + 14;
         while M > 1 loop
            M := M / 2;
            Outcome := Emit (Bin_Index, (if (Remainder / M) mod 2 = 0 then 0 else 1));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;

         return Results.Success;
      end Emit_New_Significant;

      function Refine_Existing (From_Zigzag, To_Zigzag : Natural) return Results.Result is
         Index : Coefficient_Index;
      begin
         if From_Zigzag > To_Zigzag then
            return Results.Success;
         end if;

         for Zigzag_Index in From_Zigzag .. To_Zigzag loop
            if Existing_Nonzero (Zigzag_Index) then
               Index := Zigzag_To_Natural (Coefficient_Index (Zigzag_Index));
               Outcome := Encode_Bit (Object, Fixed_Bin, Refine_Bit (Block (Index)));
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end if;
         end loop;

         return Results.Success;
      end Refine_Existing;
   begin
      Target := K;
      while Target <= Natural (Spectral_End) and then not Newly_Significant (Target) loop
         Target := Target + 1;
      end loop;

      Outcome := Emit (3 * (K - 1), (if Target > Natural (Spectral_End) then 0 else 1));
      if not Results.Succeeded (Outcome) then
         return Outcome;
      elsif Target > Natural (Spectral_End) then
         return Refine_Existing (K, Natural (Spectral_End));
      end if;

      while K < Target loop
         if Existing_Nonzero (K) then
            Outcome := Refine_Existing (K, K);
         else
            Outcome := Emit (3 * (K - 1) + 1, 0);
         end if;
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         K := K + 1;
      end loop;

      Outcome := Emit (3 * (Target - 1) + 1, 1);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Emit_New_Significant (Target);
      if Results.Succeeded (Outcome) then
         Natural_Index := Zigzag_To_Natural (Coefficient_Index (Target));
         Decoded_Coefficients (Block_Number, Natural_Index) := True;
         Outcome := Refine_Existing (Target + 1, Natural (Spectral_End));
      end if;

      return Outcome;
   exception
      when Constraint_Error =>
         return Coefficient_Error (0, 0);
   end Encode_Progressive_AC_Refine;

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
   is
      Difference : DC_Difference;
      Outcome : Results.Result;
   begin
      Difference := DC_Difference (Block (0)) - Predictor;
      Outcome := Encode_DC_Difference (Object, DC_Bins, DC_Context, DC_Conditioning, Difference);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Predictor := DC_Difference (Block (0));
      return Encode_AC_Coefficients (Object, AC_Bins, Fixed_Bin, AC_Conditioning, Block);
   exception
      when Constraint_Error =>
         return Coefficient_Error (0, Long_Long_Integer (Block (0)));
   end Encode_Sequential_Block;

   function Decode_AC_EOB
     (Object : in out Decoder;
      Bins : in out Probability_Bin_Array) return AC_EOB_Result
   is
      Decision : constant Decision_Result := Decode_Bit (Object, Bins (0));
   begin
      if not Results.Succeeded (Decision.Outcome) then
         return (Outcome => Decision.Outcome, Source => Decision.Source, End_Of_Block => False);
      end if;

      return
        (Outcome => Results.Success,
         Source => Decision.Source,
         End_Of_Block => Decision.Decision = 0);
   end Decode_AC_EOB;

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
   is
      Decision : Decision_Result;
      Sign : Natural;
      K : Natural := Natural (Spectral_Start) - 1;
      M : Natural;
      V : Natural;
      Bin_Index : Natural;
      Natural_Index : Coefficient_Index;
      Scale : constant Jpeglib.Coefficients.Quantized_Coefficient :=
        Jpeglib.Coefficients.Quantized_Coefficient (2 ** Successive_Low);
   begin
      loop
         Bin_Index := 3 * K;
         Decision := Decode_Bit (Object, Bins (Bin_Index));
         if not Results.Succeeded (Decision.Outcome) then
            return Decision.Outcome;
         elsif Decision.Decision = 0 then
            return Results.Success;
         end if;

         loop
            K := K + 1;
            Decision := Decode_Bit (Object, Bins (Bin_Index + 1));
            if not Results.Succeeded (Decision.Outcome) then
               return Decision.Outcome;
            elsif Decision.Decision = 1 then
               exit;
            end if;

            Bin_Index := Bin_Index + 3;
            if K >= Natural (Spectral_End) then
               return Coefficient_Error (Decision.Source, Long_Long_Integer (K));
            end if;
         end loop;

         Decision := Decode_Bit (Object, Fixed_Bin);
         if not Results.Succeeded (Decision.Outcome) then
            return Decision.Outcome;
         end if;
         Sign := Natural (Decision.Decision);

         Bin_Index := Bin_Index + 2;
         Decision := Decode_Bit (Object, Bins (Bin_Index));
         if not Results.Succeeded (Decision.Outcome) then
            return Decision.Outcome;
         end if;
         M := Natural (Decision.Decision);

         if M /= 0 then
            Decision := Decode_Bit (Object, Bins (Bin_Index));
            if not Results.Succeeded (Decision.Outcome) then
               return Decision.Outcome;
            elsif Decision.Decision = 1 then
               M := M * 2;
               Bin_Index := (if K <= Natural (AC_Conditioning) then 189 else 217);
               loop
                  Decision := Decode_Bit (Object, Bins (Bin_Index));
                  if not Results.Succeeded (Decision.Outcome) then
                     return Decision.Outcome;
                  elsif Decision.Decision = 0 then
                     exit;
                  end if;

                  M := M * 2;
                  if M = 16#8000# then
                     return Coefficient_Error (Decision.Source, Long_Long_Integer (M));
                  end if;
                  Bin_Index := Bin_Index + 1;
               end loop;
            end if;
         end if;

         V := M;
         Bin_Index := Bin_Index + 14;
         while M > 1 loop
            M := M / 2;
            Decision := Decode_Bit (Object, Bins (Bin_Index));
            if not Results.Succeeded (Decision.Outcome) then
               return Decision.Outcome;
            elsif Decision.Decision = 1 then
               V := V + M;
            end if;
         end loop;

         V := V + 1;
         Natural_Index := Zigzag_To_Natural (Coefficient_Index (K));
         if Sign = 0 then
            Block (Natural_Index) := Jpeglib.Coefficients.Quantized_Coefficient (V) * Scale;
         else
            Block (Natural_Index) := -(Jpeglib.Coefficients.Quantized_Coefficient (V) * Scale);
         end if;
         Decoded_Coefficients (Block_Number, Natural_Index) := True;

         if K >= Natural (Spectral_End) then
            return Results.Success;
         end if;
      end loop;
   exception
      when Constraint_Error =>
         return Coefficient_Error (Object.Last_Source, 0);
   end Decode_Progressive_AC_First;

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
   is
      Decision : Decision_Result;
      Sign : Natural;
      K : Natural := Natural (Spectral_Start) - 1;
      M : Natural;
      V : Natural;
      Bin_Index : Natural;
      Zeros_To_Skip : Natural;
      Natural_Index : Coefficient_Index;
      Step : constant Jpeglib.Coefficients.Quantized_Coefficient :=
        Jpeglib.Coefficients.Quantized_Coefficient (2 ** Successive_Low);

      function Refine_Existing (Index : Coefficient_Index) return Results.Result is
         Refine : Decision_Result;
      begin
         if Decoded_Coefficients (Block_Number, Index)
           and then Block (Index) /= 0
         then
            Refine := Decode_Bit (Object, Fixed_Bin);
            if not Results.Succeeded (Refine.Outcome) then
               return Refine.Outcome;
            elsif Refine.Decision = 1 then
               if Block (Index) < 0 then
                  Block (Index) := Block (Index) - Step;
               else
                  Block (Index) := Block (Index) + Step;
               end if;
            end if;
         end if;

         return Results.Success;
      end Refine_Existing;
   begin
      Bin_Index := 3 * K;
      Decision := Decode_Bit (Object, Bins (Bin_Index));
      if not Results.Succeeded (Decision.Outcome) then
         return Decision.Outcome;
      elsif Decision.Decision = 0 then
         for K_Value in Spectral_Start .. Spectral_End loop
            Natural_Index := Zigzag_To_Natural (K_Value);
            declare
               Outcome : constant Results.Result := Refine_Existing (Natural_Index);
            begin
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end;
         end loop;

         return Results.Success;
      end if;

      loop
         loop
            K := K + 1;
            Decision := Decode_Bit (Object, Bins (Bin_Index + 1));
            if not Results.Succeeded (Decision.Outcome) then
               return Decision.Outcome;
            elsif Decision.Decision = 1 then
               exit;
            end if;

            Bin_Index := Bin_Index + 3;
            if K >= Natural (Spectral_End) then
               return Coefficient_Error (Decision.Source, Long_Long_Integer (K));
            end if;
         end loop;

         Decision := Decode_Bit (Object, Fixed_Bin);
         if not Results.Succeeded (Decision.Outcome) then
            return Decision.Outcome;
         end if;
         Sign := Natural (Decision.Decision);

         Bin_Index := Bin_Index + 2;
         Decision := Decode_Bit (Object, Bins (Bin_Index));
         if not Results.Succeeded (Decision.Outcome) then
            return Decision.Outcome;
         end if;
         M := Natural (Decision.Decision);
         if M /= 0 then
            Decision := Decode_Bit (Object, Bins (Bin_Index));
            if not Results.Succeeded (Decision.Outcome) then
               return Decision.Outcome;
            elsif Decision.Decision = 1 then
               M := M * 2;
               Bin_Index := (if K <= Natural (AC_Conditioning) then 189 else 217);
               loop
                  Decision := Decode_Bit (Object, Bins (Bin_Index));
                  if not Results.Succeeded (Decision.Outcome) then
                     return Decision.Outcome;
                  elsif Decision.Decision = 0 then
                     exit;
                  end if;

                  M := M * 2;
                  if M = 16#8000# then
                     return Coefficient_Error (Decision.Source, Long_Long_Integer (M));
                  end if;
                  Bin_Index := Bin_Index + 1;
               end loop;
            end if;
         end if;

         V := M;
         Bin_Index := Bin_Index + 14;
         while M > 1 loop
            M := M / 2;
            Decision := Decode_Bit (Object, Bins (Bin_Index));
            if not Results.Succeeded (Decision.Outcome) then
               return Decision.Outcome;
            elsif Decision.Decision = 1 then
               V := V + M;
            end if;
         end loop;

         Zeros_To_Skip := K - Natural (Spectral_Start);
         K := Natural (Spectral_Start);
         loop
            if K > Natural (Spectral_End) then
               return Coefficient_Error (Decision.Source, Long_Long_Integer (K));
            end if;

            Natural_Index := Zigzag_To_Natural (Coefficient_Index (K));
            if Decoded_Coefficients (Block_Number, Natural_Index)
              and then Block (Natural_Index) /= 0
            then
               declare
                  Outcome : constant Results.Result := Refine_Existing (Natural_Index);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            else
               exit when Zeros_To_Skip = 0;
               Zeros_To_Skip := Zeros_To_Skip - 1;
            end if;

            K := K + 1;
         end loop;

         if Sign = 0 then
            Block (Natural_Index) := -(Jpeglib.Coefficients.Quantized_Coefficient (V + 1) * Step);
         else
            Block (Natural_Index) := Jpeglib.Coefficients.Quantized_Coefficient (V + 1) * Step;
         end if;
         Decoded_Coefficients (Block_Number, Natural_Index) := True;
         return Results.Success;
      end loop;
   exception
      when Constraint_Error =>
         return Coefficient_Error (Object.Last_Source, 0);
   end Decode_Progressive_AC_Refine;

   function Decode_DC_EOB_Block
     (Object : in out Decoder;
      DC_Bins : in out Probability_Bin_Array;
      AC_Bins : in out Probability_Bin_Array;
      DC_Context : in out DC_Context_Index;
      Predictor : in out DC_Difference;
      DC_Conditioning : Conditioning_Value) return Block_Result
   is
      Result : Block_Result;
      DC : DC_Result;
      AC : AC_EOB_Result;
   begin
      DC := Decode_DC_Difference (Object, DC_Bins, DC_Context, DC_Conditioning);
      if not Results.Succeeded (DC.Outcome) then
         Result.Outcome := DC.Outcome;
         return Result;
      end if;

      Predictor := Predictor + DC.Difference;
      Result.Block (0) := Jpeglib.Coefficients.Quantized_Coefficient (Predictor);

      AC := Decode_AC_EOB (Object, AC_Bins);
      if not Results.Succeeded (AC.Outcome) then
         Result.Outcome := AC.Outcome;
         return Result;
      elsif not AC.End_Of_Block then
         Result.Outcome := Coefficient_Error (AC.Source, 1);
         return Result;
      end if;

      return Result;
   end Decode_DC_EOB_Block;

   function Decode_AC_Coefficients
     (Object : in out Decoder;
      Bins : in out Probability_Bin_Array;
      Fixed_Bin : in out Probability_Bin;
      AC_Conditioning : Conditioning_Value;
      Block : in out Jpeglib.Coefficients.DCT_Block) return Results.Result
   is
      Decision : Decision_Result;
      Sign : Natural;
      K : Natural := 0;
      M : Natural;
      V : Natural;
      Bin_Index : Natural;
      Natural_Index : Coefficient_Index;
   begin
      loop
         Bin_Index := 3 * K;
         Decision := Decode_Bit (Object, Bins (Bin_Index));
         if not Results.Succeeded (Decision.Outcome) then
            return Decision.Outcome;
         elsif Decision.Decision = 1 then
            return Results.Success;
         end if;

         loop
            K := K + 1;
            Decision := Decode_Bit (Object, Bins (Bin_Index + 1));
            if not Results.Succeeded (Decision.Outcome) then
               return Decision.Outcome;
            elsif Decision.Decision = 1 then
               exit;
            end if;

            Bin_Index := Bin_Index + 3;
            if K >= 63 then
               return Coefficient_Error (Decision.Source, Long_Long_Integer (K));
            end if;
         end loop;

         Decision := Decode_Bit (Object, Fixed_Bin);
         if not Results.Succeeded (Decision.Outcome) then
            return Decision.Outcome;
         end if;
         Sign := Natural (Decision.Decision);

         Bin_Index := Bin_Index + 2;
         Decision := Decode_Bit (Object, Bins (Bin_Index));
         if not Results.Succeeded (Decision.Outcome) then
            return Decision.Outcome;
         end if;
         M := Natural (Decision.Decision);

         if M /= 0 then
            Decision := Decode_Bit (Object, Bins (Bin_Index));
            if not Results.Succeeded (Decision.Outcome) then
               return Decision.Outcome;
            elsif Decision.Decision = 1 then
               M := M * 2;
               Bin_Index := (if K <= Natural (AC_Conditioning) then 189 else 217);
               loop
                  Decision := Decode_Bit (Object, Bins (Bin_Index));
                  if not Results.Succeeded (Decision.Outcome) then
                     return Decision.Outcome;
                  elsif Decision.Decision = 0 then
                     exit;
                  end if;

                  M := M * 2;
                  if M = 16#8000# then
                     return Coefficient_Error (Decision.Source, Long_Long_Integer (M));
                  end if;
                  Bin_Index := Bin_Index + 1;
               end loop;
            end if;
         end if;

         V := M;
         Bin_Index := Bin_Index + 14;
         while M > 1 loop
            M := M / 2;
            Decision := Decode_Bit (Object, Bins (Bin_Index));
            if not Results.Succeeded (Decision.Outcome) then
               return Decision.Outcome;
            elsif Decision.Decision = 1 then
               V := V + M;
            end if;
         end loop;

         V := V + 1;
         Natural_Index := Zigzag_To_Natural (Coefficient_Index (K));
         if Sign = 0 then
            Block (Natural_Index) := Jpeglib.Coefficients.Quantized_Coefficient (V);
         else
            Block (Natural_Index) := -Jpeglib.Coefficients.Quantized_Coefficient (V);
         end if;

         if K >= 63 then
            return Results.Success;
         end if;
      end loop;
   exception
      when Constraint_Error =>
         return Coefficient_Error (Object.Last_Source, 0);
   end Decode_AC_Coefficients;

   function Decode_Sequential_Block
     (Object : in out Decoder;
      DC_Bins : in out Probability_Bin_Array;
      AC_Bins : in out Probability_Bin_Array;
      Fixed_Bin : in out Probability_Bin;
      DC_Context : in out DC_Context_Index;
      Predictor : in out DC_Difference;
      DC_Conditioning : Conditioning_Value;
      AC_Conditioning : Conditioning_Value) return Block_Result
   is
      Result : Block_Result;
      DC : DC_Result;
   begin
      DC := Decode_DC_Difference (Object, DC_Bins, DC_Context, DC_Conditioning);
      if not Results.Succeeded (DC.Outcome) then
         Result.Outcome := DC.Outcome;
         return Result;
      end if;

      Predictor := Predictor + DC.Difference;
      Result.Block (0) := Jpeglib.Coefficients.Quantized_Coefficient (Predictor);
      Result.Outcome :=
        Decode_AC_Coefficients (Object, AC_Bins, Fixed_Bin, AC_Conditioning, Result.Block);
      return Result;
   exception
      when Constraint_Error =>
         Result.Outcome := Coefficient_Error (Object.Last_Source, 0);
         return Result;
   end Decode_Sequential_Block;

end Jpeglib.Internal.Arithmetic;

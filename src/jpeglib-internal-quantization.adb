with Jpeglib.Errors;
with Jpeglib.Internal.Bytes;

package body Jpeglib.Internal.Quantization is
   Zigzag_To_Natural : constant array (Coefficient_Index) of Coefficient_Index :=
     [0, 1, 8, 16, 9, 2, 3, 10,
      17, 24, 32, 25, 18, 11, 4, 5,
      12, 19, 26, 33, 40, 48, 41, 34,
      27, 20, 13, 6, 7, 14, 21, 28,
      35, 42, 49, 56, 57, 50, 43, 36,
      29, 22, 15, 23, 30, 37, 44, 51,
      58, 59, 52, 45, 38, 31, 39, 46,
      53, 60, 61, 54, 47, 55, 62, 63];

   type Standard_Table is array (Coefficient_Index) of Natural;

   Standard_Luma : constant Standard_Table :=
     [16, 11, 10, 16, 24, 40, 51, 61,
      12, 12, 14, 19, 26, 58, 60, 55,
      14, 13, 16, 24, 40, 57, 69, 56,
      14, 17, 22, 29, 51, 87, 80, 62,
      18, 22, 37, 56, 68, 109, 103, 77,
      24, 35, 55, 64, 81, 104, 113, 92,
      49, 64, 78, 87, 103, 121, 120, 101,
      72, 92, 95, 98, 112, 100, 103, 99];

   Standard_Chroma : constant Standard_Table :=
     [17, 18, 24, 47, 99, 99, 99, 99,
      18, 21, 26, 66, 99, 99, 99, 99,
      24, 26, 56, 99, 99, 99, 99, 99,
      47, 66, 99, 99, 99, 99, 99, 99,
      99, 99, 99, 99, 99, 99, 99, 99,
      99, 99, 99, 99, 99, 99, 99, 99,
      99, 99, 99, 99, 99, 99, 99, 99,
      99, 99, 99, 99, 99, 99, 99, 99];

   function Clamp_Baseline_Value (Value : Natural) return Quantization_Value is
   begin
      if Value < 1 then
         return 1;
      elsif Value > 255 then
         return 255;
      else
         return Quantization_Value (Value);
      end if;
   end Clamp_Baseline_Value;

   function Scale_Table
     (Base : Standard_Table;
      Quality : Positive) return Quantization_Table
   is
      Scale : Natural;
      Scaled : Natural;
      Result : Quantization_Table;
   begin
      if Quality < 50 then
         Scale := 5_000 / Quality;
      else
         Scale := 200 - 2 * Quality;
      end if;

      for Index in Coefficient_Index loop
         Scaled := (Base (Index) * Scale + 50) / 100;
         Result (Index) := Clamp_Baseline_Value (Scaled);
      end loop;

      return Result;
   end Scale_Table;

   function Luma_Table_For_Quality (Quality : Positive) return Quantization_Table is
   begin
      return Scale_Table (Standard_Luma, Quality);
   end Luma_Table_For_Quality;

   function Chroma_Table_For_Quality (Quality : Positive) return Quantization_Table is
   begin
      return Scale_Table (Standard_Chroma, Quality);
   end Chroma_Table_For_Quality;

   function Has_Table (State : Quantization_State; Index : Quantization_Table_Index) return Boolean is
   begin
      return State.Present (Index);
   end Has_Table;

   function Table (State : Quantization_State; Index : Quantization_Table_Index) return Quantization_Table is
   begin
      return State.Tables (Index);
   end Table;

   function Read_Table
     (Segment : in out Segments.Segment_Reader;
      Precision : Natural;
      Output : out Quantization_Table) return Results.Result
   is
      High : Bytes.Read_Byte_Result;
      Low : Bytes.Read_Byte_Result;
      Zigzag_Value : Natural;
      Natural_Index : Coefficient_Index;
   begin
      for Zigzag_Index in Coefficient_Index loop
         High := Segments.Read_Byte (Segment);
         if not Results.Succeeded (High.Outcome) then
            return High.Outcome;
         end if;

         if Precision = 0 then
            Zigzag_Value := Natural (High.Value);
         else
            Low := Segments.Read_Byte (Segment);
            if not Results.Succeeded (Low.Outcome) then
               return Low.Outcome;
            end if;
            Zigzag_Value := Natural (High.Value) * 256 + Natural (Low.Value);
         end if;

         if Zigzag_Value = 0 then
            return
              Results.Failure
                (Errors.Make
                   (Errors.Table_Invalid_Definition,
                    (Source => High.Source,
                     Marker => Segments.Descriptor (Segment).Marker,
                     Detail => 0,
                     others => <>)));
         end if;

         Natural_Index := Zigzag_To_Natural (Zigzag_Index);
         Output (Natural_Index) := Quantization_Value (Zigzag_Value);
      end loop;

      return Results.Success;
   end Read_Table;

   function Parse_DQT
     (State : in out Quantization_State;
      Segment : in out Segments.Segment_Reader) return Results.Result
   is
      Header : Bytes.Read_Byte_Result;
      Precision : Natural;
      Index : Quantization_Table_Index;
      Candidate : Quantization_Table;
      Outcome : Results.Result;
   begin
      while Segments.Remaining (Segment) > 0 loop
         Header := Segments.Read_Byte (Segment);
         if not Results.Succeeded (Header.Outcome) then
            return Header.Outcome;
         end if;

         Precision := Natural (Header.Value) / 16;
         if Precision > 1 then
            return
              Results.Failure
                (Errors.Make
                   (Errors.Table_Invalid_Definition,
                    (Source => Header.Source,
                     Marker => Segments.Descriptor (Segment).Marker,
                     Detail => Long_Long_Integer (Precision),
                     others => <>)));
         end if;

         Index := Quantization_Table_Index (Natural (Header.Value) mod 16);
         Outcome := Read_Table (Segment, Precision, Candidate);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         State.Tables (Index) := Candidate;
         State.Present (Index) := True;
      end loop;

      return Results.Success;
   exception
      when Constraint_Error =>
         return
           Results.Failure
             (Errors.Make
                (Errors.Table_Invalid_Definition,
                 (Source => Segments.Descriptor (Segment).Payload_Source,
                  Marker => Segments.Descriptor (Segment).Marker,
                  others => <>)));
   end Parse_DQT;
end Jpeglib.Internal.Quantization;

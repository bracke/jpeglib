package body Jpeglib.Internal.Transforms is
   use type Interfaces.Integer_64;

   subtype Wide_Coefficient is Interfaces.Integer_64;
   Scale : constant Wide_Coefficient := 16_384;
   IDCT_Divisor : constant Wide_Coefficient := 4 * Scale * Scale;

   type Weight_Table is array (Coefficient_Index range 0 .. 7, Coefficient_Index range 0 .. 7) of Wide_Coefficient;

   --  Round (C(u) * cos ((2x + 1) * u * pi / 16)) * 2**14.
   Weights : constant Weight_Table :=
     [[11_585, 11_585, 11_585, 11_585, 11_585, 11_585, 11_585, 11_585],
      [16_069, 13_623, 9_102, 3_196, -3_196, -9_102, -13_623, -16_069],
      [15_137, 6_270, -6_270, -15_137, -15_137, -6_270, 6_270, 15_137],
      [13_623, -3_196, -16_069, -9_102, 9_102, 16_069, 3_196, -13_623],
      [11_585, -11_585, -11_585, 11_585, 11_585, -11_585, -11_585, 11_585],
      [9_102, -16_069, 3_196, 13_623, -13_623, -3_196, 16_069, -9_102],
      [6_270, -15_137, 15_137, -6_270, -6_270, 15_137, -15_137, 6_270],
      [3_196, -9_102, 13_623, -16_069, 16_069, -13_623, 9_102, -3_196]];

   function Scale_To_Output_Byte
     (Value : Dequantized_Coefficient;
      Precision : Sample_Precision) return Byte
   is
      Max_Sample : constant Dequantized_Coefficient := Dequantized_Coefficient (2 ** Natural (Precision) - 1);
      Scaled : Dequantized_Coefficient;
   begin
      if Value < 0 then
         return 0;
      elsif Value > Max_Sample then
         return Byte'Last;
      elsif Precision = 8 then
         return Byte (Value);
      else
         Scaled := (Value * Dequantized_Coefficient (Byte'Last) + Max_Sample / 2) / Max_Sample;
         return Byte (Scaled);
      end if;
   end Scale_To_Output_Byte;

   function Rounded_Divide_By_8 (Value : Dequantized_Coefficient) return Dequantized_Coefficient is
   begin
      if Value >= 0 then
         return (Value + 4) / 8;
      else
         return (Value - 4) / 8;
      end if;
   end Rounded_Divide_By_8;

   function Rounded_Divide
     (Value : Wide_Coefficient;
      Divisor : Wide_Coefficient) return Wide_Coefficient is
   begin
      if Value >= 0 then
         return (Value + Divisor / 2) / Divisor;
      else
         return (Value - Divisor / 2) / Divisor;
      end if;
   end Rounded_Divide;

   function Dequantize
     (Block : Jpeglib.Coefficients.DCT_Block;
      Table : Quantization.Quantization_Table) return Dequantized_Block
   is
      Result : Dequantized_Block := [others => 0];
   begin
      for Index in Coefficient_Index loop
         Result (Index) :=
           Dequantized_Coefficient (Block (Index))
           * Dequantized_Coefficient (Table (Index));
      end loop;

      return Result;
   end Dequantize;

   function Rounded_Divide_By_Quantization
     (Value : Wide_Coefficient;
      Divisor : Wide_Coefficient) return Wide_Coefficient is
   begin
      if Value >= 0 then
         return (Value + Divisor / 2) / Divisor;
      else
         return (Value - Divisor / 2) / Divisor;
      end if;
   end Rounded_Divide_By_Quantization;

   function Forward_DC_Only
     (Samples : Sample_Block;
      Table : Quantization.Quantization_Table) return Jpeglib.Coefficients.DCT_Block
   is
      Sum : Wide_Coefficient := 0;
      Quantized : Wide_Coefficient;
      Divisor : constant Wide_Coefficient := 8 * Wide_Coefficient (Table (0));
   begin
      for Item of Samples loop
         Sum := Sum + Wide_Coefficient (Item) - 128;
      end loop;

      Quantized := Rounded_Divide_By_Quantization (Sum, Divisor);
      return [0 => Jpeglib.Coefficients.Quantized_Coefficient (Quantized), others => 0];
   end Forward_DC_Only;

   function Forward_Block
     (Samples : Sample_Block;
      Table : Quantization.Quantization_Table) return Jpeglib.Coefficients.DCT_Block
   is
      Result : Jpeglib.Coefficients.DCT_Block := [others => 0];
      Sum : Wide_Coefficient;
      Dequantized : Wide_Coefficient;
      Quantized : Wide_Coefficient;
      Coefficient : Coefficient_Index;
   begin
      for V in Coefficient_Index range 0 .. 7 loop
         for U in Coefficient_Index range 0 .. 7 loop
            Sum := 0;
            for Y in Coefficient_Index range 0 .. 7 loop
               for X in Coefficient_Index range 0 .. 7 loop
                  Sum :=
                    Sum
                    + (Wide_Coefficient (Samples (Coefficient_Index (Natural (Y) * 8 + Natural (X)))) - 128)
                      * Weights (U, X)
                      * Weights (V, Y);
               end loop;
            end loop;

            Coefficient := Coefficient_Index (Natural (V) * 8 + Natural (U));
            Dequantized := Rounded_Divide (Sum, IDCT_Divisor);
            Quantized :=
              Rounded_Divide_By_Quantization
                (Dequantized, Wide_Coefficient (Table (Coefficient)));
            Result (Coefficient) := Jpeglib.Coefficients.Quantized_Coefficient (Quantized);
         end loop;
      end loop;

      return Result;
   end Forward_Block;

   function Reconstruct_Block
     (Block : Dequantized_Block;
      Precision : Sample_Precision := 8) return Sample_Block
   is
      Result : Sample_Block := [others => 0];
      Sum : Wide_Coefficient;
      Spatial : Wide_Coefficient;
      Index : Coefficient_Index;
      Level_Shift : constant Wide_Coefficient := 2 ** (Natural (Precision) - 1);
   begin
      for Y in Coefficient_Index range 0 .. 7 loop
         for X in Coefficient_Index range 0 .. 7 loop
            Sum := 0;
            for V in Coefficient_Index range 0 .. 7 loop
               for U in Coefficient_Index range 0 .. 7 loop
                  Sum :=
                    Sum
                    + Wide_Coefficient (Block (Coefficient_Index (Natural (V) * 8 + Natural (U))))
                      * Weights (U, X)
                      * Weights (V, Y);
               end loop;
            end loop;

            Spatial := Rounded_Divide (Sum, IDCT_Divisor) + Level_Shift;
            Index := Coefficient_Index (Natural (Y) * 8 + Natural (X));
            Result (Index) := Scale_To_Output_Byte (Dequantized_Coefficient (Spatial), Precision);
         end loop;
      end loop;

      return Result;
   end Reconstruct_Block;

   function Reconstruct_DC_Only
     (Block : Dequantized_Block;
      Precision : Sample_Precision := 8) return Sample_Block
   is
      Sample : constant Byte :=
        Scale_To_Output_Byte
          (Rounded_Divide_By_8 (Block (0)) + Dequantized_Coefficient (2 ** (Natural (Precision) - 1)),
           Precision);
   begin
      return [others => Sample];
   end Reconstruct_DC_Only;
end Jpeglib.Internal.Transforms;

with Jpeglib.Errors;
with Jpeglib.Internal.Restarts;
with Jpeglib.Internal.Sampling;

package body Jpeglib.Internal.Coefficients is
   use type Bit_Streams.Entropy_Bits;
   use type Bit_Streams.Entropy_Category;
   use type Bit_Streams.Entropy_Byte_Kind;
   use type Bit_Streams.Bit_Value;
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

   function Invalid (Source : Source_Offset := 0; Detail : Long_Long_Integer := 0) return Results.Result is
   begin
      return
        Results.Failure
          (Errors.Make
             (Errors.Coefficient_Invalid_Encoding,
              (Source => Source, Detail => Detail, others => <>)));
   end Invalid;

   function Read_Category_Bits
     (Bits : in out Bit_Streams.Bit_Reader;
      Category : Bit_Streams.Entropy_Category) return Bit_Streams.Sign_Extend_Result
   is
      Raw : Bit_Streams.Entropy_Bits := 0;
      Bit : Bit_Streams.Bit_Result;
   begin
      for Index in 1 .. Natural (Category) loop
         Bit := Bit_Streams.Read_Bit (Bits);
         if not Results.Succeeded (Bit.Outcome) then
            return (Outcome => Bit.Outcome, Value => 0);
         end if;

         Raw := (Raw * Bit_Streams.Entropy_Bits (2)) + Bit_Streams.Entropy_Bits (Bit.Value);
      end loop;

      return Bit_Streams.Sign_Extend (Category, Raw);
   end Read_Category_Bits;

   function Decode_Baseline_Block
     (Bits : in out Bit_Streams.Bit_Reader;
      DC_Table : Huffman.Compiled_Huffman;
      AC_Table : Huffman.Compiled_Huffman;
      Predictor : in out DC_Predictor) return Block_Result
   is
      Result : Block_Result;
      DC_Symbol : Huffman.Decode_Result;
      AC_Symbol : Huffman.Decode_Result;
      Extended : Bit_Streams.Sign_Extend_Result;
      Category : Natural;
      Run : Natural;
      Size : Natural;
      K : Natural := 1;
      Natural_Index : Coefficient_Index;
   begin
      DC_Symbol := Huffman.Decode (DC_Table, Bits);
      if not Results.Succeeded (DC_Symbol.Outcome) then
         Result.Outcome := DC_Symbol.Outcome;
         return Result;
      end if;

      Category := Natural (DC_Symbol.Symbol);
      if Category > Natural (Bit_Streams.Entropy_Category'Last) then
         Result.Outcome := Invalid (DC_Symbol.Source, Long_Long_Integer (Category));
         return Result;
      end if;

      Extended := Read_Category_Bits (Bits, Bit_Streams.Entropy_Category (Category));
      if not Results.Succeeded (Extended.Outcome) then
         Result.Outcome := Extended.Outcome;
         return Result;
      end if;

      Predictor := Predictor + DC_Predictor (Extended.Value);
      Result.Block (0) := Jpeglib.Coefficients.Quantized_Coefficient (Predictor);

      while K <= 63 loop
         AC_Symbol := Huffman.Decode (AC_Table, Bits);
         if not Results.Succeeded (AC_Symbol.Outcome) then
            Result.Outcome := AC_Symbol.Outcome;
            return Result;
         end if;

         if AC_Symbol.Symbol = 0 then
            return Result;
         elsif AC_Symbol.Symbol = 16#F0# then
            K := K + 16;
            if K > 64 then
               Result.Outcome := Invalid (AC_Symbol.Source, Long_Long_Integer (K));
               return Result;
            end if;
         else
            Run := Natural (AC_Symbol.Symbol) / 16;
            Size := Natural (AC_Symbol.Symbol) mod 16;
            if Size = 0 or else Size > Natural (Bit_Streams.Entropy_Category'Last) then
               Result.Outcome := Invalid (AC_Symbol.Source, Long_Long_Integer (AC_Symbol.Symbol));
               return Result;
            end if;

            K := K + Run;
            if K > 63 then
               Result.Outcome := Invalid (AC_Symbol.Source, Long_Long_Integer (K));
               return Result;
            end if;

            Extended := Read_Category_Bits (Bits, Bit_Streams.Entropy_Category (Size));
            if not Results.Succeeded (Extended.Outcome) then
               Result.Outcome := Extended.Outcome;
               return Result;
            end if;

            Natural_Index := Zigzag_To_Natural (Coefficient_Index (K));
            Result.Block (Natural_Index) := Jpeglib.Coefficients.Quantized_Coefficient (Extended.Value);
            K := K + 1;
         end if;
      end loop;

      return Result;
   exception
      when Constraint_Error =>
         Result.Outcome := Invalid;
         return Result;
   end Decode_Baseline_Block;

   function Approximation_Scale (Al : Successive_Approximation_Value) return Long_Long_Integer is
      Scale : Long_Long_Integer := 1;
   begin
      for Bit in 1 .. Natural (Al) loop
         Scale := Scale * 2;
      end loop;

      return Scale;
   end Approximation_Scale;

   type EOB_Run_Result is record
      Outcome : Results.Result := Results.Success;
      Value : EOB_Run_Count := 0;
   end record;

   function Read_EOB_Run
     (Bits : in out Bit_Streams.Bit_Reader;
      Run_Bits : Natural;
      Source : Source_Offset) return EOB_Run_Result
   is
      Raw : Bit_Streams.Entropy_Bits := 0;
      Bit : Bit_Streams.Bit_Result;
      Base : Natural := 1;
   begin
      for Index in 1 .. Run_Bits loop
         Bit := Bit_Streams.Read_Bit (Bits);
         if not Results.Succeeded (Bit.Outcome) then
            return (Outcome => Bit.Outcome, Value => 0);
         end if;

         Raw := Raw * 2 + Bit_Streams.Entropy_Bits (Bit.Value);
         Base := Base * 2;
      end loop;

      return (Outcome => Results.Success, Value => EOB_Run_Count (Base - 1 + Natural (Raw)));
   exception
      when Constraint_Error =>
         return (Outcome => Invalid (Source, Long_Long_Integer (Run_Bits)), Value => 0);
   end Read_EOB_Run;

   function Refine_Nonzero_AC
     (Bits : in out Bit_Streams.Bit_Reader;
      Al : Successive_Approximation_Value;
      Block : in out Jpeglib.Coefficients.DCT_Block;
      Natural_Index : Coefficient_Index) return Results.Result
   is
      Bit : Bit_Streams.Bit_Result;
      Step : constant Jpeglib.Coefficients.Quantized_Coefficient :=
        Jpeglib.Coefficients.Quantized_Coefficient (Approximation_Scale (Al));
   begin
      if Block (Natural_Index) = 0 then
         return Results.Success;
      end if;

      Bit := Bit_Streams.Read_Bit (Bits);
      if not Results.Succeeded (Bit.Outcome) then
         return Bit.Outcome;
      elsif Bit.Value = 0 then
         return Results.Success;
      elsif Block (Natural_Index) < 0 then
         Block (Natural_Index) := Block (Natural_Index) - Step;
      else
         Block (Natural_Index) := Block (Natural_Index) + Step;
      end if;

      return Results.Success;
   exception
      when Constraint_Error =>
         return Invalid;
   end Refine_Nonzero_AC;

   function Decode_Progressive_DC_First
     (Bits : in out Bit_Streams.Bit_Reader;
      DC_Table : Huffman.Compiled_Huffman;
      Predictor : in out DC_Predictor;
      Al : Successive_Approximation_Value;
      Block : in out Jpeglib.Coefficients.DCT_Block) return Results.Result
   is
      DC_Symbol : Huffman.Decode_Result;
      Extended : Bit_Streams.Sign_Extend_Result;
      Category : Natural;
      Difference : Long_Long_Integer;
   begin
      DC_Symbol := Huffman.Decode (DC_Table, Bits);
      if not Results.Succeeded (DC_Symbol.Outcome) then
         return DC_Symbol.Outcome;
      end if;

      Category := Natural (DC_Symbol.Symbol);
      if Category > Natural (Bit_Streams.Entropy_Category'Last) then
         return Invalid (DC_Symbol.Source, Long_Long_Integer (Category));
      end if;

      Extended := Read_Category_Bits (Bits, Bit_Streams.Entropy_Category (Category));
      if not Results.Succeeded (Extended.Outcome) then
         return Extended.Outcome;
      end if;

      Predictor := Predictor + DC_Predictor (Extended.Value);
      Difference := Long_Long_Integer (Predictor) * Approximation_Scale (Al);
      Block (0) := Jpeglib.Coefficients.Quantized_Coefficient (Difference);
      return Results.Success;
   exception
      when Constraint_Error =>
         return Invalid;
   end Decode_Progressive_DC_First;

   function Decode_Progressive_DC_Refine
     (Bits : in out Bit_Streams.Bit_Reader;
      Al : Successive_Approximation_Value;
      Block : in out Jpeglib.Coefficients.DCT_Block) return Results.Result
   is
      Bit : constant Bit_Streams.Bit_Result := Bit_Streams.Read_Bit (Bits);
      Step : constant Jpeglib.Coefficients.Quantized_Coefficient :=
        Jpeglib.Coefficients.Quantized_Coefficient (Approximation_Scale (Al));
   begin
      if not Results.Succeeded (Bit.Outcome) then
         return Bit.Outcome;
      elsif Bit.Value = 0 then
         return Results.Success;
      elsif Block (0) < 0 then
         Block (0) := Block (0) - Step;
      else
         Block (0) := Block (0) + Step;
      end if;

      return Results.Success;
   exception
      when Constraint_Error =>
         return Invalid;
   end Decode_Progressive_DC_Refine;

   function Decode_Progressive_AC_First
     (Bits : in out Bit_Streams.Bit_Reader;
      AC_Table : Huffman.Compiled_Huffman;
      Ss : Spectral_Selection_Index;
      Se : Spectral_Selection_Index;
      Al : Successive_Approximation_Value;
      Block : in out Jpeglib.Coefficients.DCT_Block;
      EOB_Run : in out EOB_Run_Count) return Results.Result
   is
      Symbol_Result : Huffman.Decode_Result;
      Extended : Bit_Streams.Sign_Extend_Result;
      EOB_Result : EOB_Run_Result;
      Run : Natural;
      Size : Natural;
      K : Natural := Natural (Ss);
      Natural_Index : Coefficient_Index;
      Value : Long_Long_Integer;
   begin
      if Ss = 0 or else Ss > Se then
         return Invalid (Detail => Long_Long_Integer (Ss));
      elsif EOB_Run > 0 then
         EOB_Run := EOB_Run - 1;
         return Results.Success;
      end if;

      while K <= Natural (Se) loop
         Symbol_Result := Huffman.Decode (AC_Table, Bits);
         if not Results.Succeeded (Symbol_Result.Outcome) then
            return Symbol_Result.Outcome;
         end if;

         Run := Natural (Symbol_Result.Symbol) / 16;
         Size := Natural (Symbol_Result.Symbol) mod 16;
         if Size = 0 then
            if Run = 15 then
               K := K + 16;
               if K > Natural (Se) + 1 then
                  return Invalid (Symbol_Result.Source, Long_Long_Integer (K));
               end if;
            else
               EOB_Result := Read_EOB_Run (Bits, Run, Symbol_Result.Source);
               if not Results.Succeeded (EOB_Result.Outcome) then
                  return EOB_Result.Outcome;
               end if;

               EOB_Run := EOB_Result.Value;
               return Results.Success;
            end if;
         else
            if Size > Natural (Bit_Streams.Entropy_Category'Last) then
               return Invalid (Symbol_Result.Source, Long_Long_Integer (Symbol_Result.Symbol));
            end if;

            K := K + Run;
            if K > Natural (Se) then
               return Invalid (Symbol_Result.Source, Long_Long_Integer (K));
            end if;

            Extended := Read_Category_Bits (Bits, Bit_Streams.Entropy_Category (Size));
            if not Results.Succeeded (Extended.Outcome) then
               return Extended.Outcome;
            end if;

            Natural_Index := Zigzag_To_Natural (Coefficient_Index (K));
            Value := Long_Long_Integer (Extended.Value) * Approximation_Scale (Al);
            Block (Natural_Index) := Jpeglib.Coefficients.Quantized_Coefficient (Value);
            K := K + 1;
         end if;
      end loop;

      return Results.Success;
   exception
      when Constraint_Error =>
         return Invalid;
   end Decode_Progressive_AC_First;

   function Decode_Progressive_AC_Refine
     (Bits : in out Bit_Streams.Bit_Reader;
      AC_Table : Huffman.Compiled_Huffman;
      Ss : Spectral_Selection_Index;
      Se : Spectral_Selection_Index;
      Al : Successive_Approximation_Value;
      Block : in out Jpeglib.Coefficients.DCT_Block;
      EOB_Run : in out EOB_Run_Count) return Results.Result
   is
      Symbol_Result : Huffman.Decode_Result;
      EOB_Result : EOB_Run_Result;
      Sign_Bit : Bit_Streams.Bit_Result;
      Outcome : Results.Result;
      Run : Natural;
      Size : Natural;
      K : Natural := Natural (Ss);
      Zeros_To_Skip : Natural;
      Natural_Index : Coefficient_Index;
      Step : constant Jpeglib.Coefficients.Quantized_Coefficient :=
        Jpeglib.Coefficients.Quantized_Coefficient (Approximation_Scale (Al));
   begin
      if Ss = 0 or else Ss > Se then
         return Invalid (Detail => Long_Long_Integer (Ss));
      elsif EOB_Run > 0 then
         while K <= Natural (Se) loop
            Natural_Index := Zigzag_To_Natural (Coefficient_Index (K));
            Outcome := Refine_Nonzero_AC (Bits, Al, Block, Natural_Index);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
            K := K + 1;
         end loop;

         EOB_Run := EOB_Run - 1;
         return Results.Success;
      end if;

      while K <= Natural (Se) loop
         Symbol_Result := Huffman.Decode (AC_Table, Bits);
         if not Results.Succeeded (Symbol_Result.Outcome) then
            return Symbol_Result.Outcome;
         end if;

         Run := Natural (Symbol_Result.Symbol) / 16;
         Size := Natural (Symbol_Result.Symbol) mod 16;
         if Size = 0 then
            if Run = 15 then
               Zeros_To_Skip := 16;
            else
               EOB_Result := Read_EOB_Run (Bits, Run, Symbol_Result.Source);
               if not Results.Succeeded (EOB_Result.Outcome) then
                  return EOB_Result.Outcome;
               end if;

               while K <= Natural (Se) loop
                  Natural_Index := Zigzag_To_Natural (Coefficient_Index (K));
                  Outcome := Refine_Nonzero_AC (Bits, Al, Block, Natural_Index);
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
                  K := K + 1;
               end loop;

               EOB_Run := EOB_Result.Value;
               return Results.Success;
            end if;
         elsif Size = 1 then
            Sign_Bit := Bit_Streams.Read_Bit (Bits);
            if not Results.Succeeded (Sign_Bit.Outcome) then
               return Sign_Bit.Outcome;
            end if;

            Zeros_To_Skip := Run;
         else
            return Invalid (Symbol_Result.Source, Long_Long_Integer (Symbol_Result.Symbol));
         end if;

         loop
            if K > Natural (Se) then
               return Invalid (Symbol_Result.Source, Long_Long_Integer (K));
            end if;

            Natural_Index := Zigzag_To_Natural (Coefficient_Index (K));
            if Block (Natural_Index) = 0 then
               exit when Zeros_To_Skip = 0;
               Zeros_To_Skip := Zeros_To_Skip - 1;
            else
               Outcome := Refine_Nonzero_AC (Bits, Al, Block, Natural_Index);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end if;

            K := K + 1;
         end loop;

         if Size = 1 then
            if Sign_Bit.Value = 0 then
               Block (Natural_Index) := -Step;
            else
               Block (Natural_Index) := Step;
            end if;
            K := K + 1;
         end if;
      end loop;

      return Results.Success;
   exception
      when Constraint_Error =>
         return Invalid;
   end Decode_Progressive_AC_Refine;

   type Amplitude_Result is record
      Outcome : Results.Result := Results.Success;
      Category : Bit_Streams.Entropy_Category := 0;
      Bits : Bit_Streams.Entropy_Bits := 0;
   end record;

   function Amplitude_For
     (Value : Jpeglib.Coefficients.Quantized_Coefficient) return Amplitude_Result
   is
      Signed_Value : constant Long_Long_Integer := Long_Long_Integer (Value);
      Magnitude : Long_Long_Integer;
      Category : Natural := 0;
      Limit : Long_Long_Integer := 1;
   begin
      if Value = 0 then
         return (Outcome => Results.Success, Category => 0, Bits => 0);
      elsif Value > 0 then
         Magnitude := Signed_Value;
      else
         Magnitude := -Signed_Value;
      end if;

      while Limit <= Magnitude loop
         Category := Category + 1;
         Limit := Limit * 2;
      end loop;

      if Category > Natural (Bit_Streams.Entropy_Category'Last) then
         return (Outcome => Invalid (Detail => Long_Long_Integer (Value)), Category => 0, Bits => 0);
      elsif Value > 0 then
         return
           (Outcome => Results.Success,
            Category => Bit_Streams.Entropy_Category (Category),
            Bits => Bit_Streams.Entropy_Bits (Magnitude));
      else
         return
           (Outcome => Results.Success,
            Category => Bit_Streams.Entropy_Category (Category),
            Bits => Bit_Streams.Entropy_Bits (Limit - 1 - Magnitude));
      end if;
   exception
      when Constraint_Error =>
         return (Outcome => Invalid (Detail => Long_Long_Integer (Value)), Category => 0, Bits => 0);
   end Amplitude_For;

   function Write_Amplitude
     (Bits : in out Bit_Streams.Bit_Writer;
      Amplitude : Amplitude_Result) return Results.Result is
   begin
      if not Results.Succeeded (Amplitude.Outcome) then
         return Amplitude.Outcome;
      end if;

      return Bit_Streams.Write_Bits (Bits, Amplitude.Category, Amplitude.Bits);
   end Write_Amplitude;

   function Scale_For (Al : Successive_Approximation_Value) return Long_Long_Integer is
   begin
      return Approximation_Scale (Al);
   end Scale_For;

   function Successive_Value
     (Value : Jpeglib.Coefficients.Quantized_Coefficient;
      Al : Successive_Approximation_Value) return Jpeglib.Coefficients.Quantized_Coefficient
   is
   begin
      return Jpeglib.Coefficients.Quantized_Coefficient (Long_Long_Integer (Value) / Scale_For (Al));
   exception
      when Constraint_Error =>
         return 0;
   end Successive_Value;

   function Refinement_Bit
     (Value : Jpeglib.Coefficients.Quantized_Coefficient;
      Al : Successive_Approximation_Value) return Bit_Streams.Bit_Value
   is
      Magnitude : Long_Long_Integer := Long_Long_Integer (Value);
      Scale : constant Long_Long_Integer := Scale_For (Al);
   begin
      if Magnitude < 0 then
         Magnitude := -Magnitude;
      end if;

      return Bit_Streams.Bit_Value ((Magnitude / Scale) mod 2);
   exception
      when Constraint_Error =>
         return 0;
   end Refinement_Bit;

   function Encode_Baseline_Block
     (Bits : in out Bit_Streams.Bit_Writer;
      DC_Table : Huffman.Compiled_Huffman;
      AC_Table : Huffman.Compiled_Huffman;
      Predictor : in out DC_Predictor;
      Block : Jpeglib.Coefficients.DCT_Block) return Results.Result
   is
      Difference : Jpeglib.Coefficients.Quantized_Coefficient;
      Amplitude : Amplitude_Result;
      Outcome : Results.Result;
      Run : Natural := 0;
      Value : Jpeglib.Coefficients.Quantized_Coefficient;
      Symbol : Byte;
   begin
      Difference :=
        Block (0) - Jpeglib.Coefficients.Quantized_Coefficient (Predictor);
      Amplitude := Amplitude_For (Difference);
      if not Results.Succeeded (Amplitude.Outcome) then
         return Amplitude.Outcome;
      end if;

      Outcome := Huffman.Encode (DC_Table, Bits, Byte (Amplitude.Category));
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_Amplitude (Bits, Amplitude);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Predictor := DC_Predictor (Block (0));

      for Zigzag_Index in Coefficient_Index range 1 .. 63 loop
         Value := Block (Zigzag_To_Natural (Zigzag_Index));
         if Value = 0 then
            Run := Run + 1;
         else
            while Run >= 16 loop
               Outcome := Huffman.Encode (AC_Table, Bits, 16#F0#);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
               Run := Run - 16;
            end loop;

            Amplitude := Amplitude_For (Value);
            if not Results.Succeeded (Amplitude.Outcome) then
               return Amplitude.Outcome;
            elsif Amplitude.Category = 0 then
               return Invalid;
            end if;

            Symbol := Byte (Run * 16 + Natural (Amplitude.Category));
            Outcome := Huffman.Encode (AC_Table, Bits, Symbol);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Write_Amplitude (Bits, Amplitude);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Run := 0;
         end if;
      end loop;

      if Run > 0 then
         return Huffman.Encode (AC_Table, Bits, 0);
      end if;

      return Results.Success;
   exception
      when Constraint_Error =>
         return Invalid;
   end Encode_Baseline_Block;

   function Encode_Lossless_Difference
     (Bits : in out Bit_Streams.Bit_Writer;
      DC_Table : Huffman.Compiled_Huffman;
      Difference : Interfaces.Integer_32) return Results.Result
   is
      Amplitude : Amplitude_Result;
      Outcome : Results.Result;
   begin
      Amplitude :=
        Amplitude_For
          (Jpeglib.Coefficients.Quantized_Coefficient (Difference));
      if not Results.Succeeded (Amplitude.Outcome) then
         return Amplitude.Outcome;
      end if;

      Outcome := Huffman.Encode (DC_Table, Bits, Byte (Amplitude.Category));
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      return Write_Amplitude (Bits, Amplitude);
   exception
      when Constraint_Error =>
         return Invalid;
   end Encode_Lossless_Difference;

   function Encode_Progressive_DC_First_Block
     (Bits : in out Bit_Streams.Bit_Writer;
      DC_Table : Huffman.Compiled_Huffman;
      Predictor : in out DC_Predictor;
      Block : Jpeglib.Coefficients.DCT_Block;
      Al : Successive_Approximation_Value := 0) return Results.Result
   is
      DC_Value : constant Jpeglib.Coefficients.Quantized_Coefficient := Successive_Value (Block (0), Al);
      Difference : Jpeglib.Coefficients.Quantized_Coefficient;
      Amplitude : Amplitude_Result;
      Outcome : Results.Result;
   begin
      Difference :=
        DC_Value - Jpeglib.Coefficients.Quantized_Coefficient (Predictor);
      Amplitude := Amplitude_For (Difference);
      if not Results.Succeeded (Amplitude.Outcome) then
         return Amplitude.Outcome;
      end if;

      Outcome := Huffman.Encode (DC_Table, Bits, Byte (Amplitude.Category));
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_Amplitude (Bits, Amplitude);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Predictor := DC_Predictor (DC_Value);
      return Results.Success;
   exception
      when Constraint_Error =>
         return Invalid;
   end Encode_Progressive_DC_First_Block;

   function Encode_Progressive_DC_Refine_Block
     (Bits : in out Bit_Streams.Bit_Writer;
      Block : Jpeglib.Coefficients.DCT_Block;
      Al : Successive_Approximation_Value := 0) return Results.Result is
   begin
      return Bit_Streams.Write_Bits (Bits, 1, Bit_Streams.Entropy_Bits (Refinement_Bit (Block (0), Al)));
   exception
      when Constraint_Error =>
         return Invalid;
   end Encode_Progressive_DC_Refine_Block;

   function Encode_Progressive_AC_First_Block
     (Bits : in out Bit_Streams.Bit_Writer;
      AC_Table : Huffman.Compiled_Huffman;
      Block : Jpeglib.Coefficients.DCT_Block;
      Al : Successive_Approximation_Value := 0) return Results.Result
   is
      Amplitude : Amplitude_Result;
      Outcome : Results.Result;
      Run : Natural := 0;
      Value : Jpeglib.Coefficients.Quantized_Coefficient;
      Symbol : Byte;
   begin
      for Zigzag_Index in Coefficient_Index range 1 .. 63 loop
         Value := Successive_Value (Block (Zigzag_To_Natural (Zigzag_Index)), Al);
         if Value = 0 then
            Run := Run + 1;
         else
            while Run >= 16 loop
               Outcome := Huffman.Encode (AC_Table, Bits, 16#F0#);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
               Run := Run - 16;
            end loop;

            Amplitude := Amplitude_For (Value);
            if not Results.Succeeded (Amplitude.Outcome) then
               return Amplitude.Outcome;
            elsif Amplitude.Category = 0 then
               return Invalid;
            end if;

            Symbol := Byte (Run * 16 + Natural (Amplitude.Category));
            Outcome := Huffman.Encode (AC_Table, Bits, Symbol);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Write_Amplitude (Bits, Amplitude);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Run := 0;
         end if;
      end loop;

      if Run > 0 then
         return Huffman.Encode (AC_Table, Bits, 0);
      end if;

      return Results.Success;
   exception
      when Constraint_Error =>
         return Invalid;
   end Encode_Progressive_AC_First_Block;

   function Encode_Progressive_AC_Refine_Block
     (Bits : in out Bit_Streams.Bit_Writer;
      AC_Table : Huffman.Compiled_Huffman;
      Block : Jpeglib.Coefficients.DCT_Block;
      Ss : Spectral_Selection_Index := 1;
      Se : Spectral_Selection_Index := 63;
      Al : Successive_Approximation_Value := 0) return Results.Result
   is
      K : Natural := Natural (Ss);
      Run : Natural := 0;
      Target : Natural;
      Natural_Index : Coefficient_Index;
      Prior : Jpeglib.Coefficients.Quantized_Coefficient;
      Current : Jpeglib.Coefficients.Quantized_Coefficient;
      Outcome : Results.Result;

      function Existing_Nonzero (Zigzag_Index : Natural) return Boolean is
        (Successive_Value (Block (Zigzag_To_Natural (Coefficient_Index (Zigzag_Index))), Al + 1) /= 0);

      function Newly_Significant (Zigzag_Index : Natural) return Boolean is
      begin
         Natural_Index := Zigzag_To_Natural (Coefficient_Index (Zigzag_Index));
         Prior := Successive_Value (Block (Natural_Index), Al + 1);
         Current := Successive_Value (Block (Natural_Index), Al);
         return Prior = 0 and then Current /= 0;
      end Newly_Significant;

      function Write_Refinement_Bits
        (From_Zigzag : Natural;
         To_Zigzag : Natural) return Results.Result
      is
         Index : Coefficient_Index;
         Refine_Outcome : Results.Result;
      begin
         if From_Zigzag > To_Zigzag then
            return Results.Success;
         end if;

         for Zigzag_Index in From_Zigzag .. To_Zigzag loop
            if Existing_Nonzero (Zigzag_Index) then
               Index := Zigzag_To_Natural (Coefficient_Index (Zigzag_Index));
               Refine_Outcome :=
                 Bit_Streams.Write_Bits (Bits, 1, Bit_Streams.Entropy_Bits (Refinement_Bit (Block (Index), Al)));
               if not Results.Succeeded (Refine_Outcome) then
                  return Refine_Outcome;
               end if;
            end if;
         end loop;

         return Results.Success;
      end Write_Refinement_Bits;
   begin
      if Ss = 0 or else Ss > Se then
         return Invalid (Detail => Long_Long_Integer (Ss));
      end if;

      while K <= Natural (Se) loop
         Target := K;
         while Target <= Natural (Se) and then not Newly_Significant (Target) loop
            if not Existing_Nonzero (Target) then
               Run := Run + 1;
            end if;
            Target := Target + 1;
         end loop;

         if Target > Natural (Se) then
            Outcome := Huffman.Encode (AC_Table, Bits, 0);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            return Write_Refinement_Bits (K, Natural (Se));
         end if;

         while Run >= 16 loop
            Outcome := Huffman.Encode (AC_Table, Bits, 16#F0#);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            declare
               Zero_Count : Natural := 0;
               Stop : Natural := K;
            begin
               while Stop <= Natural (Se) and then Zero_Count < 16 loop
                  if not Existing_Nonzero (Stop) then
                     Zero_Count := Zero_Count + 1;
                  end if;
                  Stop := Stop + 1;
               end loop;

               Outcome := Write_Refinement_Bits (K, Stop - 1);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               K := Stop;
               Run := Run - 16;
            end;
         end loop;

         Natural_Index := Zigzag_To_Natural (Coefficient_Index (Target));
         Current := Successive_Value (Block (Natural_Index), Al);
         Outcome := Huffman.Encode (AC_Table, Bits, Byte (Run * 16 + 1));
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Bit_Streams.Write_Bits (Bits, 1, (if Current < 0 then 0 else 1));
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Write_Refinement_Bits (K, Target - 1);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         K := Target + 1;
         Run := 0;
      end loop;

      return Results.Success;
   exception
      when Constraint_Error =>
         return Invalid;
   end Encode_Progressive_AC_Refine_Block;

   function Missing_Table (Detail : Long_Long_Integer := 0) return Results.Result is
   begin
      return
        Results.Failure
          (Errors.Make
             (Errors.Huffman_Invalid_Definition,
              (Detail => Detail, others => <>)));
   end Missing_Table;

   function Missing_Arithmetic_Table (Detail : Long_Long_Integer := 0) return Results.Result is
   begin
      return
        Results.Failure
          (Errors.Make
             (Errors.Table_Invalid_Definition,
              (Detail => Detail, others => <>)));
   end Missing_Arithmetic_Table;

   function Store_Block
     (Blocks : in out Block_Array;
      Next_Block : in out Natural;
      Value : Jpeglib.Coefficients.DCT_Block) return Results.Result
   is
   begin
      if Next_Block > Blocks'Last then
         return Invalid (Detail => Long_Long_Integer (Next_Block));
      end if;

      Blocks (Next_Block) := Value;
      Next_Block := Next_Block + 1;
      return Results.Success;
   end Store_Block;

   function Decode_Component_Block
     (Bits : in out Bit_Streams.Bit_Reader;
      Tables : Huffman.Huffman_State;
      Scan_Component : Scans.Scan_Component;
      Predictors : in out Predictor_Array;
      Blocks : in out Block_Array;
      Next_Block : in out Natural) return Results.Result
   is
      DC_Compile : Huffman.Compile_Result;
      AC_Compile : Huffman.Compile_Result;
      Block : Block_Result;
      Store_Outcome : Results.Result;
   begin
      if not Huffman.Has_Table (Tables, Huffman.DC, Scan_Component.DC_Table)
        or else not Huffman.Has_Table (Tables, Huffman.AC, Scan_Component.AC_Table)
      then
         return Missing_Table;
      end if;

      DC_Compile := Huffman.Compile (Huffman.Definition (Tables, Huffman.DC, Scan_Component.DC_Table));
      if not Results.Succeeded (DC_Compile.Outcome) then
         return DC_Compile.Outcome;
      end if;

      AC_Compile := Huffman.Compile (Huffman.Definition (Tables, Huffman.AC, Scan_Component.AC_Table));
      if not Results.Succeeded (AC_Compile.Outcome) then
         return AC_Compile.Outcome;
      end if;

      Block :=
        Decode_Baseline_Block
          (Bits,
           DC_Compile.Table,
           AC_Compile.Table,
           Predictors (Scan_Component.Frame_Component));
      if not Results.Succeeded (Block.Outcome) then
         return Block.Outcome;
      end if;

      Store_Outcome := Store_Block (Blocks, Next_Block, Block.Block);
      if not Results.Succeeded (Store_Outcome) then
         return Store_Outcome;
      end if;

      return Results.Success;
   end Decode_Component_Block;

   function Encode_Component_Block
     (Bits : in out Bit_Streams.Bit_Writer;
      Tables : Huffman.Huffman_State;
      Scan_Component : Scans.Scan_Component;
      Predictors : in out Predictor_Array;
      Blocks : Block_Array;
      Next_Block : in out Natural) return Results.Result
   is
      DC_Compile : Huffman.Compile_Result;
      AC_Compile : Huffman.Compile_Result;
   begin
      if Next_Block > Blocks'Last then
         return Invalid (Detail => Long_Long_Integer (Next_Block));
      elsif not Huffman.Has_Table (Tables, Huffman.DC, Scan_Component.DC_Table)
        or else not Huffman.Has_Table (Tables, Huffman.AC, Scan_Component.AC_Table)
      then
         return Missing_Table;
      end if;

      DC_Compile := Huffman.Compile (Huffman.Definition (Tables, Huffman.DC, Scan_Component.DC_Table));
      if not Results.Succeeded (DC_Compile.Outcome) then
         return DC_Compile.Outcome;
      end if;

      AC_Compile := Huffman.Compile (Huffman.Definition (Tables, Huffman.AC, Scan_Component.AC_Table));
      if not Results.Succeeded (AC_Compile.Outcome) then
         return AC_Compile.Outcome;
      end if;

      declare
         Outcome : constant Results.Result :=
           Encode_Baseline_Block
             (Bits,
              DC_Compile.Table,
              AC_Compile.Table,
              Predictors (Scan_Component.Frame_Component),
              Blocks (Next_Block));
      begin
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end;

      Next_Block := Next_Block + 1;
      return Results.Success;
   end Encode_Component_Block;

   function Encode_Baseline_Scan
     (Frame : Frames.Frame;
      Scan : Scans.Scan;
      Tables : Huffman.Huffman_State;
      Bits : in out Bit_Streams.Bit_Writer;
      Blocks : Block_Array;
      Restart : Restart_Interval := 0) return Scan_Result
   is
      Result : Scan_Result;
      Outcome : Results.Result;
      Scan_Component : Scans.Scan_Component;
      Frame_Component : Frames.Frame_Component;
      Predictors : Predictor_Array := [others => 0];
      Next_Block : Natural := Blocks'First;
      Restart_State : Restarts.Restart_State;

      function Write_Restart_When_Due (More_MCUs : Boolean) return Results.Result is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_MCUs then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Predictors := [others => 0];
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Results.Succeeded (Frames.Status (Frame)) then
         Result.Outcome := Frames.Status (Frame);
         return Result;
      elsif not Results.Succeeded (Scans.Status (Scan)) then
         Result.Outcome := Scans.Status (Scan);
         return Result;
      end if;

      Restarts.Configure (Restart_State, Restart);

      if Scans.Components (Scan) = 1 then
         Scan_Component := Scans.Component (Scan, 1);
         Frame_Component := Frames.Component (Frame, Scan_Component.Frame_Component);
         for Row in 1 .. Natural (Frame_Component.Block_Rows) loop
            for Column in 1 .. Natural (Frame_Component.Block_Columns) loop
               Outcome :=
                 Encode_Component_Block
                   (Bits, Tables, Scan_Component, Predictors, Blocks, Next_Block);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               Outcome :=
                 Write_Restart_When_Due
                   (Row /= Natural (Frame_Component.Block_Rows)
                    or else Column /= Natural (Frame_Component.Block_Columns));
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;
            end loop;
         end loop;
      else
         for MCU_R in 1 .. Natural (Frames.MCU_Rows (Frame)) loop
            for MCU_C in 1 .. Natural (Frames.MCU_Columns (Frame)) loop
               for Scan_Index in Component_Index range 1 .. Component_Index (Scans.Components (Scan)) loop
                  Scan_Component := Scans.Component (Scan, Scan_Index);
                  Frame_Component := Frames.Component (Frame, Scan_Component.Frame_Component);
                  for V in 1 .. Natural (Frame_Component.Vertical_Sampling) loop
                     for H in 1 .. Natural (Frame_Component.Horizontal_Sampling) loop
                        Outcome :=
                          Encode_Component_Block
                            (Bits, Tables, Scan_Component, Predictors, Blocks, Next_Block);
                        if not Results.Succeeded (Outcome) then
                           Result.Outcome := Outcome;
                           return Result;
                        end if;
                     end loop;
                  end loop;
               end loop;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               Outcome :=
                 Write_Restart_When_Due
                   (MCU_R /= Natural (Frames.MCU_Rows (Frame)) or else MCU_C /= Natural (Frames.MCU_Columns (Frame)));
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;
            end loop;
         end loop;
      end if;

      Outcome := Bit_Streams.Flush_Byte (Bits);
      if not Results.Succeeded (Outcome) then
         Result.Outcome := Outcome;
         return Result;
      end if;

      Result.Blocks_Decoded := Block_Count (Next_Block - Blocks'First);
      return Result;
   end Encode_Baseline_Scan;

   function Decode_Baseline_Scan
     (Frame : Frames.Frame;
      Scan : Scans.Scan;
      Tables : Huffman.Huffman_State;
      Entropy : not null access Bit_Streams.Entropy_Reader;
      Blocks : in out Block_Array;
      Restart : Restart_Interval := 0) return Scan_Result
   is
      Predictors : Predictor_Array := [others => 0];
      Next_Block : Natural := Blocks'First;
   begin
      return Decode_Baseline_Scan (Frame, Scan, Tables, Entropy, Blocks, Next_Block, Predictors, Restart);
   end Decode_Baseline_Scan;

   function Component_Block_Start
     (Frame : Frames.Frame;
      Component : Component_Index;
      Blocks : Block_Array) return Natural
   is
      Start : Natural := Blocks'First;
      Frame_Component : Frames.Frame_Component;
   begin
      for Index in Component_Index range 1 .. Component - 1 loop
         Frame_Component := Frames.Component (Frame, Index);
         Start := Start + Natural (Frame_Component.Block_Columns) * Natural (Frame_Component.Block_Rows);
      end loop;

      return Start;
   exception
      when Constraint_Error =>
         return Blocks'Last + 1;
   end Component_Block_Start;

   function Padded_Component_Block_Start
     (Frame : Frames.Frame;
      Component : Component_Index;
      Blocks : Block_Array) return Natural
   is
      Start : Natural := Blocks'First;
   begin
      for Index in Component_Index range 1 .. Component - 1 loop
         Start :=
           Start
           + Natural (Frames.Padded_Block_Columns (Frame, Index))
             * Natural (Frames.Padded_Block_Rows (Frame, Index));
      end loop;

      return Start;
   exception
      when Constraint_Error =>
         return Blocks'Last + 1;
   end Padded_Component_Block_Start;

   function Decode_Progressive_Scan
     (Frame : Frames.Frame;
      Scan : Scans.Scan;
      Tables : Huffman.Huffman_State;
      Entropy : not null access Bit_Streams.Entropy_Reader;
      Blocks : in out Block_Array;
      Restart : Restart_Interval := 0) return Scan_Result
   is
      Result : Scan_Result;
      Bits : Bit_Streams.Bit_Reader (Entropy);
      Outcome : Results.Result;
      Scan_Component : Scans.Scan_Component;
      Frame_Component : Frames.Frame_Component;
      AC_Compile : Huffman.Compile_Result;
      Predictors : Predictor_Array := [others => 0];
      EOB_Run : EOB_Run_Count := 0;
      Block_Number : Natural;
      Block_Start : Natural;
      Restart_State : Restarts.Restart_State;

      function Accept_Restart_When_Due (More_Blocks : Boolean) return Results.Result is
         Marker : Bit_Streams.Entropy_Read_Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
            return Results.Success;
         end if;

         Bit_Streams.Byte_Align (Bits);
         Marker := Bit_Streams.Read_Byte (Entropy.all);
         if not Results.Succeeded (Marker.Outcome) then
            return Marker.Outcome;
         elsif Marker.Kind /= Bit_Streams.Restart_Marker then
            return
              Results.Failure
                (Errors.Make
                   (Errors.Restart_Invalid_State,
                    (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
         end if;

         Outcome := Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
         if Results.Succeeded (Outcome) then
            Predictors := [others => 0];
            EOB_Run := 0;
         end if;

         return Outcome;
      end Accept_Restart_When_Due;

      function Decode_DC_First_Block_Into
        (Scan_Component : Scans.Scan_Component;
         Block : in out Jpeglib.Coefficients.DCT_Block) return Results.Result;

      function Decode_DC_First_Block
        (Scan_Component : Scans.Scan_Component;
         Block_Number : Natural) return Results.Result
      is
      begin
         if Block_Number > Blocks'Last then
            return Invalid (Detail => Long_Long_Integer (Block_Number));
         end if;

         return Decode_DC_First_Block_Into (Scan_Component, Blocks (Block_Number));
      end Decode_DC_First_Block;

      function Decode_DC_First_Block_Into
        (Scan_Component : Scans.Scan_Component;
         Block : in out Jpeglib.Coefficients.DCT_Block) return Results.Result
      is
         Compile : Huffman.Compile_Result;
      begin
         if not Huffman.Has_Table (Tables, Huffman.DC, Scan_Component.DC_Table) then
            return Missing_Table;
         end if;

         Compile := Huffman.Compile (Huffman.Definition (Tables, Huffman.DC, Scan_Component.DC_Table));
         if not Results.Succeeded (Compile.Outcome) then
            return Compile.Outcome;
         end if;

         return
           Decode_Progressive_DC_First
             (Bits,
             Compile.Table,
             Predictors (Scan_Component.Frame_Component),
             Scans.Successive_Low (Scan),
              Block);
      end Decode_DC_First_Block_Into;
   begin
      if not Results.Succeeded (Frames.Status (Frame)) then
         Result.Outcome := Frames.Status (Frame);
         return Result;
      elsif Frames.Mode (Frame) not in Progressive_DCT | Differential_Progressive_DCT then
         Result.Outcome := Results.Failure (Errors.Unsupported_Feature);
         return Result;
      elsif not Results.Succeeded (Scans.Status (Scan)) then
         Result.Outcome := Scans.Status (Scan);
         return Result;
      end if;

      Restarts.Configure (Restart_State, Restart);

      if Scans.Spectral_Start (Scan) = 0
        and then Scans.Successive_High (Scan) = 0
      then
         if Scans.Components (Scan) = 1 then
            Scan_Component := Scans.Component (Scan, 1);
            Frame_Component := Frames.Component (Frame, Scan_Component.Frame_Component);
            Block_Start := Component_Block_Start (Frame, Scan_Component.Frame_Component, Blocks);
            for Row in 0 .. Natural (Frame_Component.Block_Rows) - 1 loop
               for Column in 0 .. Natural (Frame_Component.Block_Columns) - 1 loop
                  Block_Number := Block_Start + Row * Natural (Frame_Component.Block_Columns) + Column;
                  Outcome := Decode_DC_First_Block (Scan_Component, Block_Number);
                  if not Results.Succeeded (Outcome) then
                     Result.Outcome := Outcome;
                     return Result;
                  end if;

                  Result.Blocks_Decoded := Result.Blocks_Decoded + 1;
                  Outcome := Restarts.Advance_MCU (Restart_State);
                  if not Results.Succeeded (Outcome) then
                     Result.Outcome := Outcome;
                     return Result;
                  end if;

                  Outcome :=
                    Accept_Restart_When_Due
                      (Row /= Natural (Frame_Component.Block_Rows) - 1
                       or else Column /= Natural (Frame_Component.Block_Columns) - 1);
                  if not Results.Succeeded (Outcome) then
                     Result.Outcome := Outcome;
                     return Result;
                  end if;
               end loop;
            end loop;
         else
            for MCU_R_Value in MCU_Row range 0 .. Frames.MCU_Rows (Frame) - 1 loop
               for MCU_C_Value in MCU_Column range 0 .. Frames.MCU_Columns (Frame) - 1 loop
                  for Scan_Index in Component_Index range 1 .. Component_Index (Scans.Components (Scan)) loop
                     Scan_Component := Scans.Component (Scan, Scan_Index);
                     Frame_Component := Frames.Component (Frame, Scan_Component.Frame_Component);
                     Block_Start := Component_Block_Start (Frame, Scan_Component.Frame_Component, Blocks);

                     for V in 0 .. Natural (Frame_Component.Vertical_Sampling) - 1 loop
                        for H in 0 .. Natural (Frame_Component.Horizontal_Sampling) - 1 loop
                           declare
                              Row : constant Natural :=
                                Natural (MCU_R_Value) * Natural (Frame_Component.Vertical_Sampling) + V;
                              Column : constant Natural :=
                                Natural (MCU_C_Value) * Natural (Frame_Component.Horizontal_Sampling) + H;
                           begin
                              if Row < Natural (Frame_Component.Block_Rows)
                                and then Column < Natural (Frame_Component.Block_Columns)
                              then
                                 Block_Number := Block_Start + Row * Natural (Frame_Component.Block_Columns) + Column;
                                 Outcome := Decode_DC_First_Block (Scan_Component, Block_Number);
                                 if not Results.Succeeded (Outcome) then
                                    Result.Outcome := Outcome;
                                    return Result;
                                 end if;

                                 Result.Blocks_Decoded := Result.Blocks_Decoded + 1;
                              else
                                 declare
                                    Dummy_Block : Jpeglib.Coefficients.DCT_Block := [others => 0];
                                 begin
                                    Outcome := Decode_DC_First_Block_Into (Scan_Component, Dummy_Block);
                                    if not Results.Succeeded (Outcome) then
                                       Result.Outcome := Outcome;
                                       return Result;
                                    end if;
                                 end;
                              end if;
                           end;
                        end loop;
                     end loop;
                  end loop;

                  Outcome := Restarts.Advance_MCU (Restart_State);
                  if not Results.Succeeded (Outcome) then
                     Result.Outcome := Outcome;
                     return Result;
                  end if;

                  Outcome :=
                    Accept_Restart_When_Due
                      (MCU_R_Value /= Frames.MCU_Rows (Frame) - 1
                       or else MCU_C_Value /= Frames.MCU_Columns (Frame) - 1);
                  if not Results.Succeeded (Outcome) then
                     Result.Outcome := Outcome;
                     return Result;
                  end if;
               end loop;
            end loop;
         end if;

         return Result;
      elsif Scans.Spectral_Start (Scan) = 0 then
         Scan_Component := Scans.Component (Scan, 1);
         Frame_Component := Frames.Component (Frame, Scan_Component.Frame_Component);
         Block_Start := Component_Block_Start (Frame, Scan_Component.Frame_Component, Blocks);
         for Row in 0 .. Natural (Frame_Component.Block_Rows) - 1 loop
            for Column in 0 .. Natural (Frame_Component.Block_Columns) - 1 loop
               Block_Number := Block_Start + Row * Natural (Frame_Component.Block_Columns) + Column;
               if Block_Number > Blocks'Last then
                  Result.Outcome := Invalid (Detail => Long_Long_Integer (Block_Number));
                  return Result;
               end if;

               Outcome :=
                 Decode_Progressive_DC_Refine
                   (Bits, Scans.Successive_Low (Scan), Blocks (Block_Number));
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               Result.Blocks_Decoded := Result.Blocks_Decoded + 1;
               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               Outcome :=
                 Accept_Restart_When_Due
                   (Row /= Natural (Frame_Component.Block_Rows) - 1
                    or else Column /= Natural (Frame_Component.Block_Columns) - 1);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;
            end loop;
         end loop;

         return Result;
      else
         Scan_Component := Scans.Component (Scan, 1);
         if not Huffman.Has_Table (Tables, Huffman.AC, Scan_Component.AC_Table) then
            Result.Outcome := Missing_Table;
            return Result;
         end if;

         AC_Compile := Huffman.Compile (Huffman.Definition (Tables, Huffman.AC, Scan_Component.AC_Table));
         if not Results.Succeeded (AC_Compile.Outcome) then
            Result.Outcome := AC_Compile.Outcome;
            return Result;
         end if;

         Frame_Component := Frames.Component (Frame, Scan_Component.Frame_Component);
         Block_Start := Component_Block_Start (Frame, Scan_Component.Frame_Component, Blocks);
         for Row in 0 .. Natural (Frame_Component.Block_Rows) - 1 loop
            for Column in 0 .. Natural (Frame_Component.Block_Columns) - 1 loop
               Block_Number := Block_Start + Row * Natural (Frame_Component.Block_Columns) + Column;
               if Block_Number > Blocks'Last then
                  Result.Outcome := Invalid (Detail => Long_Long_Integer (Block_Number));
                  return Result;
               end if;

               if Scans.Successive_High (Scan) = 0 then
                  Outcome :=
                    Decode_Progressive_AC_First
                      (Bits,
                       AC_Compile.Table,
                       Scans.Spectral_Start (Scan),
                       Scans.Spectral_End (Scan),
                       Scans.Successive_Low (Scan),
                       Blocks (Block_Number),
                       EOB_Run);
               else
                  Outcome :=
                    Decode_Progressive_AC_Refine
                      (Bits,
                       AC_Compile.Table,
                       Scans.Spectral_Start (Scan),
                       Scans.Spectral_End (Scan),
                       Scans.Successive_Low (Scan),
                       Blocks (Block_Number),
                       EOB_Run);
               end if;

               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               Result.Blocks_Decoded := Result.Blocks_Decoded + 1;
               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               Outcome :=
                 Accept_Restart_When_Due
                   (Row /= Natural (Frame_Component.Block_Rows) - 1
                    or else Column /= Natural (Frame_Component.Block_Columns) - 1);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;
            end loop;
         end loop;

         return Result;
      end if;
   exception
      when Constraint_Error =>
         Result.Outcome := Invalid;
         return Result;
   end Decode_Progressive_Scan;

   function Decode_Progressive_Scan
     (Frame : Frames.Frame;
      Scan : Scans.Scan;
      Tables : Huffman.Huffman_State;
      Entropy : not null access Bit_Streams.Entropy_Reader;
      Blocks : in out Block_Array;
      State : in out Progressive.Scan_State;
      Restart : Restart_Interval := 0) return Scan_Result
   is
      Candidate_State : Progressive.Scan_State := State;
      Result : Scan_Result;
      Outcome : Results.Result;
   begin
      Outcome := Progressive.Accept_Scan (Candidate_State, Frame, Scan);
      if not Results.Succeeded (Outcome) then
         Result.Outcome := Outcome;
         return Result;
      end if;

      Result := Decode_Progressive_Scan (Frame, Scan, Tables, Entropy, Blocks, Restart);
      if Results.Succeeded (Result.Outcome) then
         State := Candidate_State;
      end if;

      return Result;
   end Decode_Progressive_Scan;

   function Decode_Baseline_Scan
     (Frame : Frames.Frame;
      Scan : Scans.Scan;
      Tables : Huffman.Huffman_State;
      Entropy : not null access Bit_Streams.Entropy_Reader;
      Blocks : in out Block_Array;
      Next_Block : in out Natural;
      Predictors : in out Predictor_Array;
      Restart : Restart_Interval := 0) return Scan_Result
   is
      Result : Scan_Result;
      Bits : Bit_Streams.Bit_Reader (Entropy);
      Outcome : Results.Result;
      Scan_Component : Scans.Scan_Component;
      Frame_Component : Frames.Frame_Component;
      Restart_State : Restarts.Restart_State;

      function Accept_Restart_When_Due (More_MCUs : Boolean) return Results.Result is
         Marker : Bit_Streams.Entropy_Read_Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_MCUs then
            return Results.Success;
         end if;

         Bit_Streams.Byte_Align (Bits);
         Marker := Bit_Streams.Read_Byte (Entropy.all);
         if not Results.Succeeded (Marker.Outcome) then
            return Marker.Outcome;
         elsif Marker.Kind /= Bit_Streams.Restart_Marker then
            return
              Results.Failure
                (Errors.Make
                   (Errors.Restart_Invalid_State,
                    (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
         end if;

         Outcome := Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
         if Results.Succeeded (Outcome) then
            Predictors := [others => 0];
         end if;

         return Outcome;
      end Accept_Restart_When_Due;
   begin
      if not Results.Succeeded (Frames.Status (Frame)) then
         Result.Outcome := Frames.Status (Frame);
         return Result;
      elsif not Results.Succeeded (Scans.Status (Scan)) then
         Result.Outcome := Scans.Status (Scan);
         return Result;
      end if;

      Restarts.Configure (Restart_State, Restart);

      if Scans.Components (Scan) = 1 then
         Scan_Component := Scans.Component (Scan, 1);
         Frame_Component := Frames.Component (Frame, Scan_Component.Frame_Component);
         for Row in 1 .. Natural (Frame_Component.Block_Rows) loop
            for Column in 1 .. Natural (Frame_Component.Block_Columns) loop
               Outcome :=
                 Decode_Component_Block
                   (Bits, Tables, Scan_Component, Predictors, Blocks, Next_Block);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               Outcome :=
                 Accept_Restart_When_Due
                   (Row /= Natural (Frame_Component.Block_Rows)
                    or else Column /= Natural (Frame_Component.Block_Columns));
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;
            end loop;
         end loop;
      else
         for MCU_R in 1 .. Natural (Frames.MCU_Rows (Frame)) loop
            for MCU_C in 1 .. Natural (Frames.MCU_Columns (Frame)) loop
               for Scan_Index in Component_Index range 1 .. Component_Index (Scans.Components (Scan)) loop
                  Scan_Component := Scans.Component (Scan, Scan_Index);
                  Frame_Component := Frames.Component (Frame, Scan_Component.Frame_Component);
                  for V in 1 .. Natural (Frame_Component.Vertical_Sampling) loop
                     for H in 1 .. Natural (Frame_Component.Horizontal_Sampling) loop
                        Outcome :=
                          Decode_Component_Block
                            (Bits, Tables, Scan_Component, Predictors, Blocks, Next_Block);
                        if not Results.Succeeded (Outcome) then
                           Result.Outcome := Outcome;
                           return Result;
                        end if;
                     end loop;
                  end loop;
               end loop;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               Outcome :=
                 Accept_Restart_When_Due
                   (MCU_R /= Natural (Frames.MCU_Rows (Frame)) or else MCU_C /= Natural (Frames.MCU_Columns (Frame)));
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;
            end loop;
         end loop;
      end if;

      Result.Blocks_Decoded := Block_Count (Next_Block - Blocks'First);
      Bit_Streams.Byte_Align (Bits);
      return Result;
   end Decode_Baseline_Scan;

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
   is
      Result : Scan_Result;
      Decoder : Arithmetic.Decoder (Entropy);
      Outcome : Results.Result;
      Scan_Component : Scans.Scan_Component;
      Frame_Component : Frames.Frame_Component;
      Component : Frames.Frame_Component;
      Restart_State : Restarts.Restart_State;
      Block : Arithmetic.Block_Result;
      Arithmetic_Predictor : Arithmetic.DC_Difference;
      More_Blocks : Boolean;

      function Accept_Restart_When_Due (More_MCUs : Boolean) return Results.Result is
         Marker : Bit_Streams.Entropy_Read_Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_MCUs then
            return Results.Success;
         end if;

         Marker := Bit_Streams.Read_Byte (Entropy.all);
         if not Results.Succeeded (Marker.Outcome) then
            return Marker.Outcome;
         elsif Marker.Kind /= Bit_Streams.Restart_Marker then
            return
              Results.Failure
                (Errors.Make
                   (Errors.Restart_Invalid_State,
                    (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
         end if;

         Outcome := Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
         if Results.Succeeded (Outcome) then
            Arithmetic.Reset (Decoder);
            Predictors := [others => 0];
            DC_Bins := [others => Arithmetic.Initial_Probability_Bin];
            AC_Bins := [others => Arithmetic.Initial_Probability_Bin];
            DC_Contexts := [others => 0];
         end if;

         return Outcome;
      end Accept_Restart_When_Due;

      function Decode_Component_Block (Component_Item : Scans.Scan_Component) return Results.Result is
      begin
         if Next_Block > Blocks'Last then
            return Invalid (Detail => Long_Long_Integer (Next_Block));
         end if;

         Arithmetic_Predictor :=
           Arithmetic.DC_Difference (Predictors (Component_Item.Frame_Component));
         Block :=
           Arithmetic.Decode_DC_EOB_Block
             (Decoder,
              DC_Bins,
              AC_Bins,
              DC_Contexts (Component_Item.Frame_Component),
              Arithmetic_Predictor,
              Arithmetic.Value (Tables, Arithmetic.DC, Component_Item.DC_Table));
         if not Results.Succeeded (Block.Outcome) then
            return Block.Outcome;
         end if;

         Blocks (Next_Block) := Block.Block;
         Predictors (Component_Item.Frame_Component) := DC_Predictor (Arithmetic_Predictor);
         Next_Block := Next_Block + 1;
         return Results.Success;
      end Decode_Component_Block;
   begin
      if not Results.Succeeded (Frames.Status (Frame)) then
         Result.Outcome := Frames.Status (Frame);
         return Result;
      elsif Frames.Mode (Frame) not in Baseline_DCT | Extended_Sequential_DCT | Differential_Sequential_DCT then
         Result.Outcome := Results.Failure (Errors.Unsupported_Feature);
         return Result;
      elsif not Results.Succeeded (Scans.Status (Scan)) then
         Result.Outcome := Scans.Status (Scan);
         return Result;
      end if;

      for Scan_Index in Component_Index range 1 .. Component_Index (Scans.Components (Scan)) loop
         Scan_Component := Scans.Component (Scan, Scan_Index);
         if not Arithmetic.Has_Table (Tables, Arithmetic.DC, Scan_Component.DC_Table)
           or else not Arithmetic.Has_Table (Tables, Arithmetic.AC, Scan_Component.AC_Table)
         then
            Result.Outcome := Missing_Arithmetic_Table;
            return Result;
         end if;
      end loop;

      Restarts.Configure (Restart_State, Restart);
      if Scans.Components (Scan) = 1 then
         Scan_Component := Scans.Component (Scan, 1);
         Frame_Component := Frames.Component (Frame, Scan_Component.Frame_Component);
         for Row in 1 .. Natural (Frame_Component.Block_Rows) loop
            for Column in 1 .. Natural (Frame_Component.Block_Columns) loop
               Outcome := Decode_Component_Block (Scan_Component);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               More_Blocks :=
                 Row /= Natural (Frame_Component.Block_Rows)
                 or else Column /= Natural (Frame_Component.Block_Columns);
               Outcome := Accept_Restart_When_Due (More_Blocks);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;
            end loop;
         end loop;
      else
         for MCU_Row_Index in MCU_Row range 0 .. Frames.MCU_Rows (Frame) - 1 loop
            for MCU_Column_Index in MCU_Column range 0 .. Frames.MCU_Columns (Frame) - 1 loop
               for Scan_Index in Component_Index range 1 .. Component_Index (Scans.Components (Scan)) loop
                  Scan_Component := Scans.Component (Scan, Scan_Index);
                  Component := Frames.Component (Frame, Scan_Component.Frame_Component);
                  for V in Jpeglib.Internal.Sampling.Block_Offset range 0
                    .. Jpeglib.Internal.Sampling.Block_Offset (Natural (Component.Vertical_Sampling) - 1)
                  loop
                     for H in Jpeglib.Internal.Sampling.Block_Offset range 0
                       .. Jpeglib.Internal.Sampling.Block_Offset (Natural (Component.Horizontal_Sampling) - 1)
                     loop
                        Outcome := Decode_Component_Block (Scan_Component);
                        if not Results.Succeeded (Outcome) then
                           Result.Outcome := Outcome;
                           return Result;
                        end if;
                     end loop;
                  end loop;
               end loop;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               More_Blocks :=
                 MCU_Row_Index /= Frames.MCU_Rows (Frame) - 1
                 or else MCU_Column_Index /= Frames.MCU_Columns (Frame) - 1;
               Outcome := Accept_Restart_When_Due (More_Blocks);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;
            end loop;
         end loop;
      end if;

      Result.Blocks_Decoded := Block_Count (Next_Block - Blocks'First);
      return Result;
   end Decode_Arithmetic_DC_EOB_Scan;

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
   is
      Result : Scan_Result;
      Decoder : Arithmetic.Decoder (Entropy);
      Outcome : Results.Result;
      Scan_Component : Scans.Scan_Component;
      Frame_Component : Frames.Frame_Component;
      Restart_State : Restarts.Restart_State;
      Block : Arithmetic.Block_Result;
      Arithmetic_Predictor : Arithmetic.DC_Difference;
      More_Blocks : Boolean;

      function Accept_Restart_When_Due (More_MCUs : Boolean) return Results.Result is
         Marker : Bit_Streams.Entropy_Read_Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_MCUs then
            return Results.Success;
         end if;

         Marker := Bit_Streams.Read_Byte (Entropy.all);
         if not Results.Succeeded (Marker.Outcome) then
            return Marker.Outcome;
         elsif Marker.Kind /= Bit_Streams.Restart_Marker then
            return
              Results.Failure
                (Errors.Make
                   (Errors.Restart_Invalid_State,
                    (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
         end if;

         Outcome := Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
         if Results.Succeeded (Outcome) then
            Arithmetic.Reset (Decoder);
            Predictors := [others => 0];
            DC_Bins := [others => Arithmetic.Initial_Probability_Bin];
            AC_Bins := [others => Arithmetic.Initial_Probability_Bin];
            DC_Contexts := [others => 0];
            Fixed_Bin := Arithmetic.Initial_Probability_Bin;
         end if;

         return Outcome;
      end Accept_Restart_When_Due;
   begin
      if not Results.Succeeded (Frames.Status (Frame)) then
         Result.Outcome := Frames.Status (Frame);
         return Result;
      elsif Frames.Mode (Frame) not in Baseline_DCT | Extended_Sequential_DCT | Differential_Sequential_DCT then
         Result.Outcome := Results.Failure (Errors.Unsupported_Feature);
         return Result;
      elsif not Results.Succeeded (Scans.Status (Scan)) then
         Result.Outcome := Scans.Status (Scan);
         return Result;
      end if;

      for Scan_Index in Component_Index range 1 .. Component_Index (Scans.Components (Scan)) loop
         Scan_Component := Scans.Component (Scan, Scan_Index);
         if not Arithmetic.Has_Table (Tables, Arithmetic.DC, Scan_Component.DC_Table)
           or else not Arithmetic.Has_Table (Tables, Arithmetic.AC, Scan_Component.AC_Table)
         then
            Result.Outcome := Missing_Arithmetic_Table;
            return Result;
         end if;
      end loop;

      Restarts.Configure (Restart_State, Restart);

      if Scans.Components (Scan) = 1 then
         Scan_Component := Scans.Component (Scan, 1);
         Frame_Component := Frames.Component (Frame, Scan_Component.Frame_Component);
         declare
            Padded_Block_Rows : constant Natural :=
              Natural (Frames.MCU_Rows (Frame)) * Natural (Frame_Component.Vertical_Sampling);
            Padded_Block_Columns : constant Natural :=
              Natural (Frames.MCU_Columns (Frame)) * Natural (Frame_Component.Horizontal_Sampling);
         begin
         for Row in 1 .. Padded_Block_Rows loop
            for Column in 1 .. Padded_Block_Columns loop
               if Next_Block > Blocks'Last then
                  Result.Outcome := Invalid (Detail => Long_Long_Integer (Next_Block));
                  return Result;
               end if;

               Arithmetic_Predictor :=
                 Arithmetic.DC_Difference (Predictors (Scan_Component.Frame_Component));
               Block :=
                 Arithmetic.Decode_Sequential_Block
                   (Decoder,
                    DC_Bins,
                    AC_Bins,
                    Fixed_Bin,
                    DC_Contexts (Scan_Component.Frame_Component),
                    Arithmetic_Predictor,
                    Arithmetic.Value (Tables, Arithmetic.DC, Scan_Component.DC_Table),
                    Arithmetic.Value (Tables, Arithmetic.AC, Scan_Component.AC_Table));
               if not Results.Succeeded (Block.Outcome) then
                  Result.Outcome := Block.Outcome;
                  return Result;
               end if;

               Blocks (Next_Block) := Block.Block;
               Predictors (Scan_Component.Frame_Component) :=
                 DC_Predictor (Arithmetic_Predictor);
               Next_Block := Next_Block + 1;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               More_Blocks :=
                 Row /= Padded_Block_Rows
                 or else Column /= Padded_Block_Columns;
               Outcome := Accept_Restart_When_Due (More_Blocks);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;
            end loop;
         end loop;
         end;
      else
         for MCU_R in 1 .. Natural (Frames.MCU_Rows (Frame)) loop
            for MCU_C in 1 .. Natural (Frames.MCU_Columns (Frame)) loop
               for Scan_Index in Component_Index range 1 .. Component_Index (Scans.Components (Scan)) loop
                  Scan_Component := Scans.Component (Scan, Scan_Index);
                  Frame_Component := Frames.Component (Frame, Scan_Component.Frame_Component);
                  for V in 1 .. Natural (Frame_Component.Vertical_Sampling) loop
                     for H in 1 .. Natural (Frame_Component.Horizontal_Sampling) loop
                        if Next_Block > Blocks'Last then
                           Result.Outcome := Invalid (Detail => Long_Long_Integer (Next_Block));
                           return Result;
                        end if;

                        Arithmetic_Predictor :=
                          Arithmetic.DC_Difference (Predictors (Scan_Component.Frame_Component));
                        Block :=
                          Arithmetic.Decode_Sequential_Block
                            (Decoder,
                             DC_Bins,
                             AC_Bins,
                             Fixed_Bin,
                             DC_Contexts (Scan_Component.Frame_Component),
                             Arithmetic_Predictor,
                             Arithmetic.Value (Tables, Arithmetic.DC, Scan_Component.DC_Table),
                             Arithmetic.Value (Tables, Arithmetic.AC, Scan_Component.AC_Table));
                        if not Results.Succeeded (Block.Outcome) then
                           Result.Outcome := Block.Outcome;
                           return Result;
                        end if;

                        Blocks (Next_Block) := Block.Block;
                        Predictors (Scan_Component.Frame_Component) :=
                          DC_Predictor (Arithmetic_Predictor);
                        Next_Block := Next_Block + 1;
                     end loop;
                  end loop;
               end loop;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               Outcome :=
                 Accept_Restart_When_Due
                   (MCU_R /= Natural (Frames.MCU_Rows (Frame)) or else MCU_C /= Natural (Frames.MCU_Columns (Frame)));
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;
            end loop;
         end loop;
      end if;

      Result.Blocks_Decoded := Block_Count (Next_Block - Blocks'First);
      return Result;
   end Decode_Arithmetic_Sequential_Scan;

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
   is
      use type Arithmetic.DC_Difference;

      Result : Scan_Result;
      Decoder : Arithmetic.Decoder (Entropy);
      Outcome : Results.Result;
      Scan_Component : Scans.Scan_Component;
      Frame_Component : Frames.Frame_Component;
      DC : Arithmetic.DC_Result;
      Arithmetic_Predictor : Arithmetic.DC_Difference;
      Block_Number : Natural;
      Block_Start : Natural;
      Restart_State : Restarts.Restart_State;
      DC_Refinement_Bin : Arithmetic.Probability_Bin := Arithmetic.Initial_Probability_Bin;
      Fixed_Bin : Arithmetic.Probability_Bin := Arithmetic.Initial_Probability_Bin;

      function Accept_Restart_When_Due (More_Blocks : Boolean) return Results.Result is
         Marker : Bit_Streams.Entropy_Read_Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
            return Results.Success;
         end if;

         Marker := Bit_Streams.Read_Byte (Entropy.all);
         if not Results.Succeeded (Marker.Outcome) then
            return Marker.Outcome;
         elsif Marker.Kind /= Bit_Streams.Restart_Marker then
            return
              Results.Failure
                (Errors.Make
                   (Errors.Restart_Invalid_State,
                    (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
         end if;

         Outcome := Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
         if Results.Succeeded (Outcome) then
            Predictors := [others => 0];
            Arithmetic.Reset (Decoder);
            DC_Bins := [others => Arithmetic.Initial_Probability_Bin];
            AC_Bins := [others => Arithmetic.Initial_Probability_Bin];
            DC_Refinement_Bin := Arithmetic.Initial_Probability_Bin;
            Fixed_Bin := Arithmetic.Initial_Probability_Bin;
            DC_Contexts := [others => 0];
         end if;

         return Outcome;
      end Accept_Restart_When_Due;

      function Decode_DC_First_Block
        (Scan_Component : Scans.Scan_Component;
         Block_Number : Natural) return Results.Result
      is
      begin
         if Block_Number > Blocks'Last then
            return Invalid (Detail => Long_Long_Integer (Block_Number));
         elsif not Arithmetic.Has_Table (Tables, Arithmetic.DC, Scan_Component.DC_Table) then
            return Missing_Arithmetic_Table;
         end if;

         Arithmetic_Predictor := Arithmetic.DC_Difference (Predictors (Scan_Component.Frame_Component));
         DC :=
           Arithmetic.Decode_DC_Difference
             (Decoder,
              DC_Bins,
              DC_Contexts (Scan_Component.Frame_Component),
              Arithmetic.Value (Tables, Arithmetic.DC, Scan_Component.DC_Table));
         if not Results.Succeeded (DC.Outcome) then
            return DC.Outcome;
         end if;

         Arithmetic_Predictor := Arithmetic_Predictor + DC.Difference;
         Predictors (Scan_Component.Frame_Component) := DC_Predictor (Arithmetic_Predictor);
         Blocks (Block_Number) (0) :=
           Jpeglib.Coefficients.Quantized_Coefficient
             (Long_Long_Integer (Arithmetic_Predictor) * Approximation_Scale (Scans.Successive_Low (Scan)));
         return Results.Success;
      exception
         when Constraint_Error =>
            return Invalid;
      end Decode_DC_First_Block;

      function Decode_DC_Refine_Block (Block_Number : Natural) return Results.Result is
         Decision : Arithmetic.Decision_Result;
         Step : constant Jpeglib.Coefficients.Quantized_Coefficient :=
           Jpeglib.Coefficients.Quantized_Coefficient
             (Approximation_Scale (Scans.Successive_Low (Scan)));
      begin
         if Block_Number > Blocks'Last then
            return Invalid (Detail => Long_Long_Integer (Block_Number));
         end if;

         Decision := Arithmetic.Decode_Bit (Decoder, DC_Refinement_Bin);
         if not Results.Succeeded (Decision.Outcome) then
            return Decision.Outcome;
         elsif Decision.Decision = 0 then
            return Results.Success;
         elsif Blocks (Block_Number) (0) < 0 then
            Blocks (Block_Number) (0) := Blocks (Block_Number) (0) - Step;
         else
            Blocks (Block_Number) (0) := Blocks (Block_Number) (0) + Step;
         end if;

         return Results.Success;
      exception
         when Constraint_Error =>
            return Invalid;
      end Decode_DC_Refine_Block;

      function Decode_DC_Block
        (Scan_Component : Scans.Scan_Component;
         Block_Number : Natural) return Results.Result
      is
      begin
         if Scans.Successive_High (Scan) = 0 then
            return Decode_DC_First_Block (Scan_Component, Block_Number);
         else
            return Decode_DC_Refine_Block (Block_Number);
         end if;
      end Decode_DC_Block;

      function Decode_AC_First_Block
        (Scan_Component : Scans.Scan_Component;
         Block_Number : Natural) return Results.Result
      is
      begin
         if Block_Number > Blocks'Last then
            return Invalid (Detail => Long_Long_Integer (Block_Number));
         elsif not Arithmetic.Has_Table (Tables, Arithmetic.AC, Scan_Component.AC_Table) then
            return Missing_Arithmetic_Table;
         end if;

         return
           Arithmetic.Decode_Progressive_AC_First
             (Decoder,
              AC_Bins,
              Fixed_Bin,
              Arithmetic.Value (Tables, Arithmetic.AC, Scan_Component.AC_Table),
              Coefficient_Index (Scans.Spectral_Start (Scan)),
              Coefficient_Index (Scans.Spectral_End (Scan)),
              Natural (Scans.Successive_Low (Scan)),
              Decoded_Coefficients,
              Positive (Block_Number),
              Blocks (Block_Number));
      end Decode_AC_First_Block;

      function Decode_AC_Block
        (Scan_Component : Scans.Scan_Component;
         Block_Number : Natural) return Results.Result
      is
      begin
         if Scans.Successive_High (Scan) = 0 then
            return Decode_AC_First_Block (Scan_Component, Block_Number);
         elsif Block_Number > Blocks'Last then
            return Invalid (Detail => Long_Long_Integer (Block_Number));
         elsif not Arithmetic.Has_Table (Tables, Arithmetic.AC, Scan_Component.AC_Table) then
            return Missing_Arithmetic_Table;
         end if;

         return
           Arithmetic.Decode_Progressive_AC_Refine
             (Decoder,
              AC_Bins,
              Fixed_Bin,
              Arithmetic.Value (Tables, Arithmetic.AC, Scan_Component.AC_Table),
              Coefficient_Index (Scans.Spectral_Start (Scan)),
              Coefficient_Index (Scans.Spectral_End (Scan)),
              Natural (Scans.Successive_Low (Scan)),
              Decoded_Coefficients,
              Positive (Block_Number),
              Blocks (Block_Number));
      end Decode_AC_Block;
   begin
      if not Results.Succeeded (Frames.Status (Frame)) then
         Result.Outcome := Frames.Status (Frame);
         return Result;
      elsif Frames.Mode (Frame) not in Progressive_DCT | Differential_Progressive_DCT then
         Result.Outcome := Results.Failure (Errors.Unsupported_Feature);
         return Result;
      elsif not Results.Succeeded (Scans.Status (Scan)) then
         Result.Outcome := Scans.Status (Scan);
         return Result;
      elsif Scans.Spectral_Start (Scan) = 0
        and then Scans.Spectral_End (Scan) /= 0
      then
         Result.Outcome := Results.Failure (Errors.Unsupported_Feature);
         return Result;
      end if;

      Restarts.Configure (Restart_State, Restart);

      if Scans.Spectral_Start (Scan) /= 0 then
         Scan_Component := Scans.Component (Scan, 1);
         Frame_Component := Frames.Component (Frame, Scan_Component.Frame_Component);
         Block_Start := Padded_Component_Block_Start (Frame, Scan_Component.Frame_Component, Blocks);
         declare
            Padded_Block_Rows : constant Natural :=
              Natural (Frames.Padded_Block_Rows (Frame, Scan_Component.Frame_Component));
            Padded_Block_Columns : constant Natural :=
              Natural (Frames.Padded_Block_Columns (Frame, Scan_Component.Frame_Component));
         begin
         for Row in 0 .. Padded_Block_Rows - 1 loop
            for Column in 0 .. Padded_Block_Columns - 1 loop
               Block_Number := Block_Start + Row * Padded_Block_Columns + Column;
               Outcome := Decode_AC_Block (Scan_Component, Block_Number);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               Result.Blocks_Decoded := Result.Blocks_Decoded + 1;
               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               Outcome :=
                 Accept_Restart_When_Due
                   (Row /= Padded_Block_Rows - 1
                    or else Column /= Padded_Block_Columns - 1);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;
            end loop;
         end loop;
         end;
      elsif Scans.Components (Scan) = 1 then
         Scan_Component := Scans.Component (Scan, 1);
         Frame_Component := Frames.Component (Frame, Scan_Component.Frame_Component);
         Block_Start := Padded_Component_Block_Start (Frame, Scan_Component.Frame_Component, Blocks);
         declare
            Padded_Block_Rows : constant Natural :=
              Natural (Frames.Padded_Block_Rows (Frame, Scan_Component.Frame_Component));
            Padded_Block_Columns : constant Natural :=
              Natural (Frames.Padded_Block_Columns (Frame, Scan_Component.Frame_Component));
         begin
         for Row in 0 .. Padded_Block_Rows - 1 loop
            for Column in 0 .. Padded_Block_Columns - 1 loop
               Block_Number := Block_Start + Row * Padded_Block_Columns + Column;
               Outcome := Decode_DC_Block (Scan_Component, Block_Number);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               Result.Blocks_Decoded := Result.Blocks_Decoded + 1;
               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               Outcome :=
                 Accept_Restart_When_Due
                   (Row /= Padded_Block_Rows - 1
                    or else Column /= Padded_Block_Columns - 1);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;
            end loop;
         end loop;
         end;
      else
         for MCU_R_Value in MCU_Row range 0 .. Frames.MCU_Rows (Frame) - 1 loop
            for MCU_C_Value in MCU_Column range 0 .. Frames.MCU_Columns (Frame) - 1 loop
               for Scan_Index in Component_Index range 1 .. Component_Index (Scans.Components (Scan)) loop
                  Scan_Component := Scans.Component (Scan, Scan_Index);
                  Frame_Component := Frames.Component (Frame, Scan_Component.Frame_Component);
                  Block_Start := Padded_Component_Block_Start (Frame, Scan_Component.Frame_Component, Blocks);

                  for V in 0 .. Natural (Frame_Component.Vertical_Sampling) - 1 loop
                     for H in 0 .. Natural (Frame_Component.Horizontal_Sampling) - 1 loop
                        declare
                           Row : constant Natural :=
                             Natural (MCU_R_Value) * Natural (Frame_Component.Vertical_Sampling) + V;
                           Column : constant Natural :=
                             Natural (MCU_C_Value) * Natural (Frame_Component.Horizontal_Sampling) + H;
                        begin
                           Block_Number :=
                             Block_Start
                             + Row * Natural (Frames.Padded_Block_Columns (Frame, Scan_Component.Frame_Component))
                             + Column;
                           Outcome := Decode_DC_Block (Scan_Component, Block_Number);
                           if not Results.Succeeded (Outcome) then
                              Result.Outcome := Outcome;
                              return Result;
                           end if;

                           Result.Blocks_Decoded := Result.Blocks_Decoded + 1;
                        end;
                     end loop;
                  end loop;
               end loop;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               Outcome :=
                 Accept_Restart_When_Due
                   (MCU_R_Value /= Frames.MCU_Rows (Frame) - 1
                    or else MCU_C_Value /= Frames.MCU_Columns (Frame) - 1);
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;
            end loop;
         end loop;
      end if;

      return Result;
   exception
      when Constraint_Error =>
         Result.Outcome := Invalid;
         return Result;
   end Decode_Arithmetic_Progressive_Scan;
end Jpeglib.Internal.Coefficients;

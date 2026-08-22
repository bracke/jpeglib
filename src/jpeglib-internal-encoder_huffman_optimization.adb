with Jpeglib.Internal.Coefficients;
with Jpeglib.Internal.Restarts;
with Jpeglib.Results;

package body Jpeglib.Internal.Encoder_Huffman_Optimization is
   use type Jpeglib.Coefficients.Quantized_Coefficient;
   use type Huffman.Symbol_Frequency;

   Zigzag_To_Natural : constant array (Coefficient_Index) of Coefficient_Index :=
     [0, 1, 8, 16, 9, 2, 3, 10,
      17, 24, 32, 25, 18, 11, 4, 5,
      12, 19, 26, 33, 40, 48, 41, 34,
      27, 20, 13, 6, 7, 14, 21, 28,
      35, 42, 49, 56, 57, 50, 43, 36,
      29, 22, 15, 23, 30, 37, 44, 51,
      58, 59, 52, 45, 38, 31, 39, 46,
      53, 60, 61, 54, 47, 55, 62, 63];

   function Entropy_Category_For
     (Value : Jpeglib.Coefficients.Quantized_Coefficient) return Natural
   is
      Magnitude : Long_Long_Integer := Long_Long_Integer (Value);
      Limit : Long_Long_Integer := 1;
      Category : Natural := 0;
   begin
      if Magnitude < 0 then
         Magnitude := -Magnitude;
      end if;

      while Limit <= Magnitude loop
         Category := Category + 1;
         Limit := Limit * 2;
      end loop;

      return Category;
   end Entropy_Category_For;

   procedure Count_Baseline_Block_Symbols
     (DC_Frequencies : in out Huffman.Symbol_Frequencies;
      AC_Frequencies : in out Huffman.Symbol_Frequencies;
      Predictor : in out Coefficients.DC_Predictor;
      Block : Jpeglib.Coefficients.DCT_Block)
   is
      Difference : constant Jpeglib.Coefficients.Quantized_Coefficient :=
        Block (0) - Jpeglib.Coefficients.Quantized_Coefficient (Predictor);
      Run : Natural := 0;
      Value : Jpeglib.Coefficients.Quantized_Coefficient;
      Category : Natural;
      Symbol : Byte;
   begin
      Category := Entropy_Category_For (Difference);
      if Category <= Natural (Byte'Last) then
         Symbol := Byte (Category);
         DC_Frequencies (Symbol) := DC_Frequencies (Symbol) + 1;
      end if;

      Predictor := Coefficients.DC_Predictor (Block (0));

      for Zigzag_Index in Coefficient_Index range 1 .. 63 loop
         Value := Block (Zigzag_To_Natural (Zigzag_Index));
         if Value = 0 then
            Run := Run + 1;
         else
            while Run >= 16 loop
               AC_Frequencies (16#F0#) := AC_Frequencies (16#F0#) + 1;
               Run := Run - 16;
            end loop;

            Category := Entropy_Category_For (Value);
            if Category /= 0 then
               Symbol := Byte (Run * 16 + Category);
               AC_Frequencies (Symbol) := AC_Frequencies (Symbol) + 1;
            end if;
            Run := 0;
         end if;
      end loop;

      if Run > 0 then
         AC_Frequencies (0) := AC_Frequencies (0) + 1;
      end if;
   end Count_Baseline_Block_Symbols;

   procedure Optimized_Definitions_For_Blocks
     (Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      DC_Definition : out Huffman.Huffman_Definition;
      AC_Definition : out Huffman.Huffman_Definition)
   is
      DC_Frequencies : Huffman.Symbol_Frequencies := [others => 0];
      AC_Frequencies : Huffman.Symbol_Frequencies := [others => 0];
      Predictor : Coefficients.DC_Predictor := 0;
      Restart_State : Restarts.Restart_State;
      Encoded : Block_Count := 0;
   begin
      Restarts.Configure (Restart_State, Restart);
      for Block of Blocks loop
         Count_Baseline_Block_Symbols (DC_Frequencies, AC_Frequencies, Predictor, Block);
         Encoded := Encoded + 1;
         if Restart /= 0 and then Encoded /= Block_Count (Blocks'Length) then
            declare
               Outcome : constant Results.Result := Restarts.Advance_MCU (Restart_State);
            begin
               if Results.Succeeded (Outcome) and then Restarts.MCUs_Until_Restart (Restart_State) = 0 then
                  Predictor := 0;
               end if;
            end;
         end if;
      end loop;

      DC_Definition := Huffman.Optimized_Definition (DC_Frequencies);
      AC_Definition := Huffman.Optimized_Definition (AC_Frequencies);
   end Optimized_Definitions_For_Blocks;

   procedure Optimized_Definitions_For_YCbCr_Blocks
     (Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Cb_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Cr_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Y_Block_Columns : Positive;
      C_Block_Columns : Positive;
      MCU_Columns : Positive;
      MCU_Rows : Positive;
      Layout : Image_Blocks.Subsampling_Layout;
      Restart : Restart_Interval;
      Luma_DC_Definition : out Huffman.Huffman_Definition;
      Luma_AC_Definition : out Huffman.Huffman_Definition;
      Chroma_DC_Definition : out Huffman.Huffman_Definition;
      Chroma_AC_Definition : out Huffman.Huffman_Definition)
   is
      Luma_DC_Frequencies : Huffman.Symbol_Frequencies := [others => 0];
      Luma_AC_Frequencies : Huffman.Symbol_Frequencies := [others => 0];
      Chroma_DC_Frequencies : Huffman.Symbol_Frequencies := [others => 0];
      Chroma_AC_Frequencies : Huffman.Symbol_Frequencies := [others => 0];
      Y_Predictor : Coefficients.DC_Predictor := 0;
      Cb_Predictor : Coefficients.DC_Predictor := 0;
      Cr_Predictor : Coefficients.DC_Predictor := 0;
      Restart_State : Restarts.Restart_State;
   begin
      Restarts.Configure (Restart_State, Restart);
      for MCU_Row in 0 .. MCU_Rows - 1 loop
         for MCU_Column in 0 .. MCU_Columns - 1 loop
            for V in 0 .. Layout.Chroma_Vertical_Factor - 1 loop
               for H in 0 .. Layout.Chroma_Horizontal_Factor - 1 loop
                  declare
                     Block_Index : constant Positive :=
                       Y_Blocks'First
                       + (MCU_Row * Layout.Chroma_Vertical_Factor + V) * Y_Block_Columns
                       + MCU_Column * Layout.Chroma_Horizontal_Factor
                       + H;
                  begin
                     Count_Baseline_Block_Symbols
                       (Luma_DC_Frequencies,
                        Luma_AC_Frequencies,
                        Y_Predictor,
                        Y_Blocks (Block_Index));
                  end;
               end loop;
            end loop;

            declare
               Chroma_Index : constant Positive := Cb_Blocks'First + MCU_Row * C_Block_Columns + MCU_Column;
            begin
               Count_Baseline_Block_Symbols
                 (Chroma_DC_Frequencies,
                  Chroma_AC_Frequencies,
                  Cb_Predictor,
                  Cb_Blocks (Chroma_Index));
            end;

            declare
               Chroma_Index : constant Positive := Cr_Blocks'First + MCU_Row * C_Block_Columns + MCU_Column;
            begin
               Count_Baseline_Block_Symbols
                 (Chroma_DC_Frequencies,
                  Chroma_AC_Frequencies,
                  Cr_Predictor,
                  Cr_Blocks (Chroma_Index));
            end;

            if Restart /= 0 and then (MCU_Row /= MCU_Rows - 1 or else MCU_Column /= MCU_Columns - 1) then
               declare
                  Outcome : constant Results.Result := Restarts.Advance_MCU (Restart_State);
               begin
                  if Results.Succeeded (Outcome) and then Restarts.MCUs_Until_Restart (Restart_State) = 0 then
                     Y_Predictor := 0;
                     Cb_Predictor := 0;
                     Cr_Predictor := 0;
                  end if;
               end;
            end if;
         end loop;
      end loop;

      Luma_DC_Definition := Huffman.Optimized_Definition (Luma_DC_Frequencies);
      Luma_AC_Definition := Huffman.Optimized_Definition (Luma_AC_Frequencies);
      Chroma_DC_Definition := Huffman.Optimized_Definition (Chroma_DC_Frequencies);
      Chroma_AC_Definition := Huffman.Optimized_Definition (Chroma_AC_Frequencies);
   end Optimized_Definitions_For_YCbCr_Blocks;
end Jpeglib.Internal.Encoder_Huffman_Optimization;

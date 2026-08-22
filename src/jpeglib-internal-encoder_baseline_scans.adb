with Jpeglib.Internal.Bit_Streams;
with Jpeglib.Internal.Coefficients;
with Jpeglib.Internal.Restarts;

package body Jpeglib.Internal.Encoder_Baseline_Scans is

   function Encode_Blocks
     (Output : in out Streams.Destination'Class;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval) return Results.Result
   is
      DC_Compile : constant Huffman.Compile_Result :=
        Huffman.Compile (DC_Definition);
      AC_Compile : constant Huffman.Compile_Result :=
        Huffman.Compile (AC_Definition);
      Predictor : Coefficients.DC_Predictor := 0;
      Restart_State : Restarts.Restart_State;
      Encoded : Block_Count := 0;
      Outcome : Results.Result;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_Blocks : Boolean) return Results.Result
      is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Predictor := 0;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Results.Succeeded (DC_Compile.Outcome) then
         return DC_Compile.Outcome;
      elsif not Results.Succeeded (AC_Compile.Outcome) then
         return AC_Compile.Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for Block of Blocks loop
            Outcome :=
              Coefficients.Encode_Baseline_Block
                (Bits, DC_Compile.Table, AC_Compile.Table, Predictor, Block);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Outcome := Write_Restart_When_Due (Bits, Encoded /= Block_Count (Blocks'Length));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;

         return Bit_Streams.Flush_Byte (Bits);
      end;
   end Encode_Blocks;

   function Encode_YCbCr_Blocks
     (Output : in out Streams.Destination'Class;
      Luma_DC_Definition : Huffman.Huffman_Definition;
      Luma_AC_Definition : Huffman.Huffman_Definition;
      Chroma_DC_Definition : Huffman.Huffman_Definition;
      Chroma_AC_Definition : Huffman.Huffman_Definition;
      Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Cb_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Cr_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Y_Block_Columns : Positive;
      C_Block_Columns : Positive;
      MCU_Columns : Positive;
      MCU_Rows : Positive;
      Layout : Image_Blocks.Subsampling_Layout;
      Restart : Restart_Interval) return Results.Result
   is
      Luma_DC_Compile : constant Huffman.Compile_Result :=
        Huffman.Compile (Luma_DC_Definition);
      Luma_AC_Compile : constant Huffman.Compile_Result :=
        Huffman.Compile (Luma_AC_Definition);
      Chroma_DC_Compile : constant Huffman.Compile_Result :=
        Huffman.Compile (Chroma_DC_Definition);
      Chroma_AC_Compile : constant Huffman.Compile_Result :=
        Huffman.Compile (Chroma_AC_Definition);
      Y_Predictor : Coefficients.DC_Predictor := 0;
      Cb_Predictor : Coefficients.DC_Predictor := 0;
      Cr_Predictor : Coefficients.DC_Predictor := 0;
      Restart_State : Restarts.Restart_State;
      Outcome : Results.Result;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_MCUs : Boolean) return Results.Result
      is
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
            Y_Predictor := 0;
            Cb_Predictor := 0;
            Cr_Predictor := 0;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Results.Succeeded (Luma_DC_Compile.Outcome) then
         return Luma_DC_Compile.Outcome;
      elsif not Results.Succeeded (Luma_AC_Compile.Outcome) then
         return Luma_AC_Compile.Outcome;
      elsif not Results.Succeeded (Chroma_DC_Compile.Outcome) then
         return Chroma_DC_Compile.Outcome;
      elsif not Results.Succeeded (Chroma_AC_Compile.Outcome) then
         return Chroma_AC_Compile.Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
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
                        Outcome :=
                          Coefficients.Encode_Baseline_Block
                            (Bits,
                             Luma_DC_Compile.Table,
                             Luma_AC_Compile.Table,
                             Y_Predictor,
                             Y_Blocks (Block_Index));
                     end;
                     if not Results.Succeeded (Outcome) then
                        return Outcome;
                     end if;
                  end loop;
               end loop;

               declare
                  Chroma_Index : constant Positive := Cb_Blocks'First + MCU_Row * C_Block_Columns + MCU_Column;
               begin
                  Outcome :=
                    Coefficients.Encode_Baseline_Block
                      (Bits,
                       Chroma_DC_Compile.Table,
                       Chroma_AC_Compile.Table,
                       Cb_Predictor,
                       Cb_Blocks (Chroma_Index));
               end;
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               declare
                  Chroma_Index : constant Positive := Cr_Blocks'First + MCU_Row * C_Block_Columns + MCU_Column;
               begin
                  Outcome :=
                    Coefficients.Encode_Baseline_Block
                      (Bits,
                       Chroma_DC_Compile.Table,
                       Chroma_AC_Compile.Table,
                       Cr_Predictor,
                       Cr_Blocks (Chroma_Index));
               end;
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome :=
                 Write_Restart_When_Due (Bits, MCU_Row /= MCU_Rows - 1 or else MCU_Column /= MCU_Columns - 1);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;
         end loop;

         return Bit_Streams.Flush_Byte (Bits);
      end;
   end Encode_YCbCr_Blocks;

   function Encode_CMYK_Blocks
     (Output : in out Streams.Destination'Class;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      C_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      M_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      K_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Block_Columns : Positive;
      Block_Rows : Positive;
      Restart : Restart_Interval) return Results.Result
   is
      DC_Compile : constant Huffman.Compile_Result := Huffman.Compile (DC_Definition);
      AC_Compile : constant Huffman.Compile_Result := Huffman.Compile (AC_Definition);
      C_Predictor : Coefficients.DC_Predictor := 0;
      M_Predictor : Coefficients.DC_Predictor := 0;
      Y_Predictor : Coefficients.DC_Predictor := 0;
      K_Predictor : Coefficients.DC_Predictor := 0;
      Restart_State : Restarts.Restart_State;
      Outcome : Results.Result;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_MCUs : Boolean) return Results.Result
      is
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
            C_Predictor := 0;
            M_Predictor := 0;
            Y_Predictor := 0;
            K_Predictor := 0;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Results.Succeeded (DC_Compile.Outcome) then
         return DC_Compile.Outcome;
      elsif not Results.Succeeded (AC_Compile.Outcome) then
         return AC_Compile.Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for Block_Row in 0 .. Block_Rows - 1 loop
            for Block_Column in 0 .. Block_Columns - 1 loop
               declare
                  Block_Index : constant Positive := C_Blocks'First + Block_Row * Block_Columns + Block_Column;
               begin
                  Outcome :=
                    Coefficients.Encode_Baseline_Block
                      (Bits, DC_Compile.Table, AC_Compile.Table, C_Predictor, C_Blocks (Block_Index));
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome :=
                    Coefficients.Encode_Baseline_Block
                      (Bits, DC_Compile.Table, AC_Compile.Table, M_Predictor, M_Blocks (Block_Index));
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome :=
                    Coefficients.Encode_Baseline_Block
                      (Bits, DC_Compile.Table, AC_Compile.Table, Y_Predictor, Y_Blocks (Block_Index));
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome :=
                    Coefficients.Encode_Baseline_Block
                      (Bits, DC_Compile.Table, AC_Compile.Table, K_Predictor, K_Blocks (Block_Index));
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome :=
                 Write_Restart_When_Due (Bits, Block_Row /= Block_Rows - 1 or else Block_Column /= Block_Columns - 1);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;
         end loop;

         return Bit_Streams.Flush_Byte (Bits);
      end;
   end Encode_CMYK_Blocks;

end Jpeglib.Internal.Encoder_Baseline_Scans;

with Jpeglib.Errors;
with Jpeglib.Internal.Bit_Streams;
with Jpeglib.Internal.Coefficients;
with Jpeglib.Internal.Restarts;
with Jpeglib.Internal.Writers;

package body Jpeglib.Internal.Encoder_Progressive_Scans is
   function Encode_Progressive_Blocks
     (Output : in out Streams.Destination'Class;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      Refine : Boolean) return Results.Result
   is
      DC_Compile : constant Huffman.Compile_Result :=
        Huffman.Compile (DC_Definition);
      AC_Compile : constant Huffman.Compile_Result :=
        Huffman.Compile (AC_Definition);
      First_Al : constant Successive_Approximation_Value := (if Refine then 2 else 0);
      Outcome : Results.Result;

      function Encode_DC_Scan
        (Refinement : Boolean;
         Al : Successive_Approximation_Value := 0) return Results.Result
      is
         Predictor : Coefficients.DC_Predictor := 0;
         Restart_State : Restarts.Restart_State;
         Encoded : Block_Count := 0;

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
         Restarts.Configure (Restart_State, Restart);
         declare
            Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
         begin
            for Block of Blocks loop
               if Refinement then
                  Outcome := Coefficients.Encode_Progressive_DC_Refine_Block (Bits, Block, Al => Al);
               else
                  Outcome :=
                    Coefficients.Encode_Progressive_DC_First_Block
                      (Bits, DC_Compile.Table, Predictor, Block, Al => Al);
               end if;
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
      end Encode_DC_Scan;

      function Encode_AC_Scan
        (Refinement : Boolean;
         Al : Successive_Approximation_Value := 0) return Results.Result
      is
         Restart_State : Restarts.Restart_State;
         Encoded : Block_Count := 0;

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

            return Restarts.Accept_Restart (Restart_State, Marker, 0);
         end Write_Restart_When_Due;
      begin
         Restarts.Configure (Restart_State, Restart);
         declare
            Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
         begin
            for Block of Blocks loop
               if Refinement then
                  Outcome :=
                    Coefficients.Encode_Progressive_AC_Refine_Block
                      (Bits, AC_Compile.Table, Block, Al => Al);
               else
                  Outcome :=
                    Coefficients.Encode_Progressive_AC_First_Block
                      (Bits, AC_Compile.Table, Block, Al => Al);
               end if;
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
      end Encode_AC_Scan;
   begin
      if not Results.Succeeded (DC_Compile.Outcome) then
         return DC_Compile.Outcome;
      elsif not Results.Succeeded (AC_Compile.Outcome) then
         return AC_Compile.Outcome;
      end if;

      Outcome :=
        Writers.Write_SOS_Grayscale_Progressive
          (Output, Spectral_Start => 0, Spectral_End => 0, Al => First_Al, DC_Table => 0, AC_Table => 0);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Encode_DC_Scan (Refinement => False, Al => First_Al);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Writers.Write_SOS_Grayscale_Progressive
          (Output, Spectral_Start => 1, Spectral_End => 63, Al => First_Al, DC_Table => 0, AC_Table => 0);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Encode_AC_Scan (Refinement => False, Al => First_Al);
      if not Results.Succeeded (Outcome) or else not Refine then
         return Outcome;
      end if;

      for Refinement_Al in reverse Successive_Approximation_Value range 0 .. First_Al - 1 loop
         Outcome :=
           Writers.Write_SOS_Grayscale_Progressive
             (Output,
              Spectral_Start => 0,
              Spectral_End => 0,
              Ah => Refinement_Al + 1,
              Al => Refinement_Al,
              DC_Table => 0,
              AC_Table => 0);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_DC_Scan (Refinement => True, Al => Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Writers.Write_SOS_Grayscale_Progressive
             (Output,
              Spectral_Start => 1,
              Spectral_End => 63,
              Ah => Refinement_Al + 1,
              Al => Refinement_Al,
              DC_Table => 0,
              AC_Table => 0);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_AC_Scan (Refinement => True, Al => Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end loop;

      return Results.Success;
   end Encode_Progressive_Blocks;

   function Encode_Progressive_Component_Scan
     (Output : in out Streams.Destination'Class;
      Definition : Huffman.Huffman_Definition;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      DC_Scan : Boolean;
      Refinement : Boolean;
      Al : Successive_Approximation_Value) return Results.Result
   is
      Compile : constant Huffman.Compile_Result := Huffman.Compile (Definition);
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
      if not Refinement and then not Results.Succeeded (Compile.Outcome) then
         return Compile.Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for Block of Blocks loop
            if DC_Scan and then Refinement then
               Outcome := Coefficients.Encode_Progressive_DC_Refine_Block (Bits, Block, Al);
            elsif DC_Scan then
               Outcome :=
                 Coefficients.Encode_Progressive_DC_First_Block
                   (Bits, Compile.Table, Predictor, Block, Al);
            elsif Refinement then
               Outcome :=
                 Coefficients.Encode_Progressive_AC_Refine_Block
                   (Bits, Compile.Table, Block, Al => Al);
            else
               Outcome :=
                 Coefficients.Encode_Progressive_AC_First_Block
                   (Bits, Compile.Table, Block, Al);
            end if;
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
   end Encode_Progressive_Component_Scan;

   function Encode_Progressive_Component_Grid
     (Output : in out Streams.Destination'Class;
      Definition : Huffman.Huffman_Definition;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Block_Columns : Positive;
      Block_Rows : Positive;
      Source_Block_Columns : Positive;
      Restart : Restart_Interval;
      DC_Scan : Boolean;
      Refinement : Boolean;
      Al : Successive_Approximation_Value) return Results.Result
   is
      Compile : constant Huffman.Compile_Result := Huffman.Compile (Definition);
      Predictor : Coefficients.DC_Predictor := 0;
      Restart_State : Restarts.Restart_State;
      Encoded : Block_Count := 0;
      Total : constant Block_Count := Block_Count (Block_Columns) * Block_Count (Block_Rows);
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
      if not Refinement and then not Results.Succeeded (Compile.Outcome) then
         return Compile.Outcome;
      elsif Total > Block_Count (Positive'Last) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for Row in 0 .. Block_Rows - 1 loop
            for Column in 0 .. Block_Columns - 1 loop
               declare
                  Block_Index : constant Positive := Blocks'First + Row * Source_Block_Columns + Column;
               begin
                  if Block_Index > Blocks'Last then
                     return Results.Failure (Errors.Internal_Invariant_Failed);
                  elsif DC_Scan and then Refinement then
                     Outcome := Coefficients.Encode_Progressive_DC_Refine_Block (Bits, Blocks (Block_Index), Al);
                  elsif DC_Scan then
                     Outcome :=
                       Coefficients.Encode_Progressive_DC_First_Block
                         (Bits, Compile.Table, Predictor, Blocks (Block_Index), Al);
                  elsif Refinement then
                     Outcome :=
                       Coefficients.Encode_Progressive_AC_Refine_Block
                         (Bits, Compile.Table, Blocks (Block_Index), Al => Al);
                  else
                     Outcome :=
                       Coefficients.Encode_Progressive_AC_First_Block
                         (Bits, Compile.Table, Blocks (Block_Index), Al);
                  end if;
               end;
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Encoded := Encoded + 1;
               Outcome := Write_Restart_When_Due (Bits, Encoded /= Total);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;
         end loop;

         return Bit_Streams.Flush_Byte (Bits);
      end;
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Progressive_Component_Grid;

   function Encode_Progressive_YCbCr_Blocks
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
      Y_Component_Block_Columns : Positive;
      Y_Component_Block_Rows : Positive;
      Chroma_Component_Block_Columns : Positive;
      Chroma_Component_Block_Rows : Positive;
      MCU_Columns : Positive;
      MCU_Rows : Positive;
      Layout : Image_Blocks.Subsampling_Layout;
      Restart : Restart_Interval;
      Refine : Boolean) return Results.Result
   is
      Luma_DC_Compile : constant Huffman.Compile_Result := Huffman.Compile (Luma_DC_Definition);
      Chroma_DC_Compile : constant Huffman.Compile_Result := Huffman.Compile (Chroma_DC_Definition);
      First_Al : constant Successive_Approximation_Value := (if Refine then 2 else 0);
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

      function Write_Component_AC
        (Component : Component_Identifier;
         Definition : Huffman.Huffman_Definition;
         Blocks : Jpeglib.Coefficients.DCT_Block_Array;
         Block_Columns : Positive;
         Block_Rows : Positive;
         Source_Block_Columns : Positive;
         AC_Table : Huffman_Table_Index;
         Refinement : Boolean;
         Al : Successive_Approximation_Value) return Results.Result
      is
         Scan_Outcome : Results.Result;
      begin
         Scan_Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output,
              Component => Component,
              Spectral_Start => 1,
              Spectral_End => 63,
              Ah => (if Refinement then Al + 1 else 0),
              Al => Al,
              DC_Table => 0,
              AC_Table => AC_Table);
         if not Results.Succeeded (Scan_Outcome) then
            return Scan_Outcome;
         end if;

         return
           Encode_Progressive_Component_Grid
             (Output,
              Definition,
              Blocks,
              Block_Columns,
              Block_Rows,
              Source_Block_Columns,
              Restart,
              DC_Scan => False,
              Refinement => Refinement,
              Al => Al);
      end Write_Component_AC;

      function Write_Component_DC_Refine
        (Component : Component_Identifier;
         Blocks : Jpeglib.Coefficients.DCT_Block_Array;
         Block_Columns : Positive;
         Block_Rows : Positive;
         Source_Block_Columns : Positive;
         DC_Table : Huffman_Table_Index;
         Al : Successive_Approximation_Value) return Results.Result
      is
         Scan_Outcome : Results.Result;
      begin
         Scan_Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output,
              Component => Component,
              Spectral_Start => 0,
              Spectral_End => 0,
              Ah => Al + 1,
              Al => Al,
              DC_Table => DC_Table,
              AC_Table => 0);
         if not Results.Succeeded (Scan_Outcome) then
            return Scan_Outcome;
         end if;

         return
           Encode_Progressive_Component_Grid
             (Output,
              Luma_DC_Definition,
              Blocks,
              Block_Columns,
              Block_Rows,
              Source_Block_Columns,
              Restart,
              DC_Scan => True,
              Refinement => True,
              Al => Al);
      end Write_Component_DC_Refine;
   begin
      if not Results.Succeeded (Luma_DC_Compile.Outcome) then
         return Luma_DC_Compile.Outcome;
      elsif not Results.Succeeded (Chroma_DC_Compile.Outcome) then
         return Chroma_DC_Compile.Outcome;
      end if;

      Outcome := Writers.Write_SOS_YCbCr_Progressive_DC (Output, Al => First_Al);
      if not Results.Succeeded (Outcome) then
         return Outcome;
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
                          Coefficients.Encode_Progressive_DC_First_Block
                            (Bits, Luma_DC_Compile.Table, Y_Predictor, Y_Blocks (Block_Index), Al => First_Al);
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
                    Coefficients.Encode_Progressive_DC_First_Block
                      (Bits, Chroma_DC_Compile.Table, Cb_Predictor, Cb_Blocks (Chroma_Index), Al => First_Al);
               end;
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               declare
                  Chroma_Index : constant Positive := Cr_Blocks'First + MCU_Row * C_Block_Columns + MCU_Column;
               begin
                  Outcome :=
                    Coefficients.Encode_Progressive_DC_First_Block
                      (Bits, Chroma_DC_Compile.Table, Cr_Predictor, Cr_Blocks (Chroma_Index), Al => First_Al);
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

         Outcome := Bit_Streams.Flush_Byte (Bits);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end;

      Outcome :=
        Write_Component_AC
          (1,
           Luma_AC_Definition,
           Y_Blocks,
           Y_Component_Block_Columns,
           Y_Component_Block_Rows,
           Y_Block_Columns,
           0,
           Refinement => False,
           Al => First_Al);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_Component_AC
          (2,
           Chroma_AC_Definition,
           Cb_Blocks,
           Chroma_Component_Block_Columns,
           Chroma_Component_Block_Rows,
           C_Block_Columns,
           1,
           Refinement => False,
           Al => First_Al);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_Component_AC
          (3,
           Chroma_AC_Definition,
           Cr_Blocks,
           Chroma_Component_Block_Columns,
           Chroma_Component_Block_Rows,
           C_Block_Columns,
           1,
           Refinement => False,
           Al => First_Al);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if not Refine then
         return Results.Success;
      end if;

      for Refinement_Al in reverse Successive_Approximation_Value range 0 .. First_Al - 1 loop
         Outcome :=
           Write_Component_DC_Refine
             (1, Y_Blocks, Y_Component_Block_Columns, Y_Component_Block_Rows, Y_Block_Columns, 0, Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Write_Component_DC_Refine
             (2,
              Cb_Blocks,
              Chroma_Component_Block_Columns,
              Chroma_Component_Block_Rows,
              C_Block_Columns,
              1,
              Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Write_Component_DC_Refine
             (3,
              Cr_Blocks,
              Chroma_Component_Block_Columns,
              Chroma_Component_Block_Rows,
              C_Block_Columns,
              1,
              Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Write_Component_AC
             (1,
              Luma_AC_Definition,
              Y_Blocks,
              Y_Component_Block_Columns,
              Y_Component_Block_Rows,
              Y_Block_Columns,
              0,
              Refinement => True,
              Al => Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Write_Component_AC
             (2,
              Chroma_AC_Definition,
              Cb_Blocks,
              Chroma_Component_Block_Columns,
              Chroma_Component_Block_Rows,
              C_Block_Columns,
              1,
              Refinement => True,
              Al => Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Write_Component_AC
             (3,
              Chroma_AC_Definition,
              Cr_Blocks,
              Chroma_Component_Block_Columns,
              Chroma_Component_Block_Rows,
              C_Block_Columns,
              1,
              Refinement => True,
              Al => Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end loop;

      return Results.Success;
   end Encode_Progressive_YCbCr_Blocks;

end Jpeglib.Internal.Encoder_Progressive_Scans;

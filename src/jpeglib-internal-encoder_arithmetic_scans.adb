with Jpeglib.Errors;
with Jpeglib.Internal.Restarts;
with Jpeglib.Internal.Writers;

package body Jpeglib.Internal.Encoder_Arithmetic_Scans is
   use type Errors.Error_Code;
   use type Jpeglib.Coefficients.Quantized_Coefficient;
   use type Arithmetic.DC_Difference;

   function Write_Arithmetic_Component_Progressive_SOS
     (Output : in out Streams.Destination'Class;
      Component : Component_Identifier;
      DC_Scan : Boolean;
      Refinement : Boolean;
      Al : Successive_Approximation_Value) return Results.Result is
   begin
      return
        Writers.Write_SOS_Component_Progressive
          (Output,
           Component => Component,
           Spectral_Start => (if DC_Scan then 0 else 1),
           Spectral_End => (if DC_Scan then 0 else 63),
           Ah => (if Refinement then Al + 1 else 0),
           Al => Al,
           DC_Table => 0,
           AC_Table => 0);
   end Write_Arithmetic_Component_Progressive_SOS;

   function Arithmetic_Blocks_Supported
     (Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval) return Boolean
   is
   begin
      if Restart > 0 and then Blocks'Length = 0 then
         return False;
      end if;

      for Block of Blocks loop
         for Coefficient of Block loop
            if Coefficient not in -16#7FFF# .. 16#7FFF# then
               return False;
            end if;
         end loop;
      end loop;

      return True;
   end Arithmetic_Blocks_Supported;

   function Encode_Arithmetic_Blocks
     (Output : in out Streams.Destination'Class;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval) return Results.Result
   is
      Restart_State : Restarts.Restart_State;
      Encoded : Block_Count := 0;
      Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
      DC_Bins : Arithmetic.Probability_Bin_Array (0 .. 63) :=
        [others => Arithmetic.Initial_Probability_Bin];
      AC_Bins : Arithmetic.Probability_Bin_Array (0 .. 255) :=
        [others => Arithmetic.Initial_Probability_Bin];
      Fixed_Bin : Arithmetic.Probability_Bin := Arithmetic.Initial_Probability_Bin;
      DC_Context : Arithmetic.DC_Context_Index := 0;
      Predictor : Arithmetic.DC_Difference := 0;
      Outcome : Results.Result;

      function Write_Restart_When_Due (More_Blocks : Boolean) return Results.Result is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Writers.Write_Marker (Output, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Arithmetic.Reset (Arithmetic_Encoder);
            DC_Bins := [others => Arithmetic.Initial_Probability_Bin];
            AC_Bins := [others => Arithmetic.Initial_Probability_Bin];
            Fixed_Bin := Arithmetic.Initial_Probability_Bin;
            DC_Context := 0;
            Predictor := 0;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Arithmetic_Blocks_Supported (Blocks, Restart) then
         return Results.Failure (Errors.Unsupported_Feature);
      end if;

      Restarts.Configure (Restart_State, Restart);
      for Block of Blocks loop
         Outcome :=
           Arithmetic.Encode_Sequential_Block
             (Arithmetic_Encoder,
              DC_Bins,
              AC_Bins,
              Fixed_Bin,
              DC_Context,
              Predictor,
              DC_Conditioning => 16#5A#,
              AC_Conditioning => 0,
              Block => Block);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Restarts.Advance_MCU (Restart_State);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Encoded := Encoded + 1;
         Outcome := Write_Restart_When_Due (Encoded /= Block_Count (Blocks'Length));
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end loop;

      return Arithmetic.Finish (Arithmetic_Encoder);
   end Encode_Arithmetic_Blocks;

   function Encode_Arithmetic_Component_Blocks
     (Output : in out Streams.Destination'Class;
      Component : Component_Identifier;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      DC_Table : Huffman_Table_Index;
      AC_Table : Huffman_Table_Index) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome :=
        Writers.Write_SOS_Component_Progressive
          (Output,
           Component => Component,
           Spectral_Start => 0,
           Spectral_End => 63,
           DC_Table => DC_Table,
           AC_Table => AC_Table);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      return Encode_Arithmetic_Blocks (Output, Blocks, Restart);
   end Encode_Arithmetic_Component_Blocks;

   function Encode_Arithmetic_Progressive_Fast_Preview_Blocks
     (Output : in out Streams.Destination'Class;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      Refine : Boolean;
      Grayscale : Boolean := True;
      Component : Component_Identifier := 1;
      DC_Table : Huffman_Table_Index := 0;
      AC_Table : Huffman_Table_Index := 0;
      Shared_AC_Bins : in out Arithmetic.Probability_Bin_Array;
      Refinement_Bitplanes : Successive_Approximation_Value := 1) return Results.Result
   is
      First_Al : constant Successive_Approximation_Value := (if Refine then Refinement_Bitplanes else 0);
      Outcome : Results.Result;

      function Write_SOS
        (Spectral_Start : Spectral_Selection_Index;
         Spectral_End : Spectral_Selection_Index;
         Ah : Successive_Approximation_Value := 0;
         Al : Successive_Approximation_Value := 0) return Results.Result is
      begin
         if Grayscale then
            return
              Writers.Write_SOS_Grayscale_Progressive
                (Output,
                 Spectral_Start => Spectral_Start,
                 Spectral_End => Spectral_End,
                 Ah => Ah,
                 Al => Al,
                 DC_Table => DC_Table,
                 AC_Table => AC_Table);
         else
            return
              Writers.Write_SOS_Component_Progressive
                (Output,
                 Component => Component,
                 Spectral_Start => Spectral_Start,
                 Spectral_End => Spectral_End,
                 Ah => Ah,
                 Al => Al,
                 DC_Table => DC_Table,
                 AC_Table => AC_Table);
         end if;
      end Write_SOS;

      function Encode_DC_First_Scan return Results.Result is
         Restart_State : Restarts.Restart_State;
         Encoded : Block_Count := 0;
         Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
         DC_Bins : Arithmetic.Probability_Bin_Array (0 .. 63) :=
           [others => Arithmetic.Initial_Probability_Bin];
         DC_Context : Arithmetic.DC_Context_Index := 0;
         Predictor : Arithmetic.DC_Difference := 0;

         function Write_Restart_When_Due (More_Blocks : Boolean) return Results.Result is
            Marker : Marker_Code;
            Restart_Outcome : Results.Result;
         begin
            if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
               return Results.Success;
            end if;

            Marker := Restarts.Expected_Marker (Restart_State);
            Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Writers.Write_Marker (Output, Marker);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
            if Results.Succeeded (Restart_Outcome) then
               Arithmetic.Reset (Arithmetic_Encoder);
               DC_Bins := [others => Arithmetic.Initial_Probability_Bin];
               DC_Context := 0;
               Predictor := 0;
            end if;

            return Restart_Outcome;
         end Write_Restart_When_Due;
      begin
         Restarts.Configure (Restart_State, Restart);
         for Block of Blocks loop
            declare
               Scale : constant Arithmetic.DC_Difference := 2 ** Natural (First_Al);
               DC_Value : constant Arithmetic.DC_Difference :=
                 Arithmetic.DC_Difference (Block (0)) / Scale;
               Difference : constant Arithmetic.DC_Difference :=
                 DC_Value - Predictor;
            begin
               Outcome :=
                 Arithmetic.Encode_DC_Difference
                   (Arithmetic_Encoder,
                    DC_Bins,
                    DC_Context,
                    Conditioning => 16#5A#,
                    Difference => Difference);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Predictor := DC_Value;
            end;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Outcome := Write_Restart_When_Due (Encoded /= Block_Count (Blocks'Length));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;

         return Arithmetic.Finish (Arithmetic_Encoder);
      exception
         when Constraint_Error =>
            return Results.Failure (Errors.Internal_Invariant_Failed);
      end Encode_DC_First_Scan;

      function Encode_AC_First_Scan return Results.Result is
         Restart_State : Restarts.Restart_State;
         Encoded : Block_Count := 0;
         Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
         AC_Bins : Arithmetic.Probability_Bin_Array (0 .. 255) :=
           [others => Arithmetic.Initial_Probability_Bin];
         Fixed_Bin : Arithmetic.Probability_Bin := Arithmetic.Initial_Probability_Bin;

         function Write_Restart_When_Due (More_Blocks : Boolean) return Results.Result is
            Marker : Marker_Code;
            Restart_Outcome : Results.Result;
         begin
            if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
               return Results.Success;
            end if;

            Marker := Restarts.Expected_Marker (Restart_State);
            Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Writers.Write_Marker (Output, Marker);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
            if Results.Succeeded (Restart_Outcome) then
               Arithmetic.Reset (Arithmetic_Encoder);
               AC_Bins := [others => Arithmetic.Initial_Probability_Bin];
               Fixed_Bin := Arithmetic.Initial_Probability_Bin;
               Shared_AC_Bins := [others => Arithmetic.Initial_Probability_Bin];
            end if;

            return Restart_Outcome;
         end Write_Restart_When_Due;
      begin
         Restarts.Configure (Restart_State, Restart);
         for Block of Blocks loop
            if Restart = 0 then
               Outcome :=
                 Arithmetic.Encode_Progressive_AC_First
                   (Arithmetic_Encoder,
                    Shared_AC_Bins,
                    Fixed_Bin,
                    AC_Conditioning => 0,
                    Spectral_Start => 1,
                    Spectral_End => 63,
                    Successive_Low => Natural (First_Al),
                    Block => Block);
            else
               Outcome :=
                 Arithmetic.Encode_Progressive_AC_First
                   (Arithmetic_Encoder,
                    AC_Bins,
                    Fixed_Bin,
                    AC_Conditioning => 0,
                    Spectral_Start => 1,
                    Spectral_End => 63,
                    Successive_Low => Natural (First_Al),
                    Block => Block);
            end if;
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Outcome := Write_Restart_When_Due (Encoded /= Block_Count (Blocks'Length));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;

         return Arithmetic.Finish (Arithmetic_Encoder);
      end Encode_AC_First_Scan;

      function Encode_DC_Refine_Scan
        (Al : Successive_Approximation_Value) return Results.Result
      is
         Restart_State : Restarts.Restart_State;
         Encoded : Block_Count := 0;
         Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
         Bin : Arithmetic.Probability_Bin := Arithmetic.Initial_Probability_Bin;

         function Write_Restart_When_Due (More_Blocks : Boolean) return Results.Result is
            Marker : Marker_Code;
            Restart_Outcome : Results.Result;
         begin
            if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
               return Results.Success;
            end if;

            Marker := Restarts.Expected_Marker (Restart_State);
            Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Writers.Write_Marker (Output, Marker);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
            if Results.Succeeded (Restart_Outcome) then
               Arithmetic.Reset (Arithmetic_Encoder);
               Bin := Arithmetic.Initial_Probability_Bin;
            end if;

            return Restart_Outcome;
         end Write_Restart_When_Due;
      begin
         Restarts.Configure (Restart_State, Restart);
         for Block of Blocks loop
            Outcome := Arithmetic.Encode_Progressive_DC_Refine (Arithmetic_Encoder, Bin, Block, Natural (Al));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Outcome := Write_Restart_When_Due (Encoded /= Block_Count (Blocks'Length));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;

         return Arithmetic.Finish (Arithmetic_Encoder);
      end Encode_DC_Refine_Scan;

      function Encode_AC_Refine_Scan
        (Al : Successive_Approximation_Value) return Results.Result
      is
         Restart_State : Restarts.Restart_State;
         Encoded : Block_Count := 0;
         Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
         AC_Bins : Arithmetic.Probability_Bin_Array (0 .. 255) :=
           [others => Arithmetic.Initial_Probability_Bin];
         Fixed_Bin : Arithmetic.Probability_Bin := Arithmetic.Initial_Probability_Bin;
         Decoded : Arithmetic.Decoded_Coefficient_Map (Blocks'Range, Coefficient_Index) :=
           [others => [others => False]];

         function Write_Restart_When_Due (More_Blocks : Boolean) return Results.Result is
            Marker : Marker_Code;
            Restart_Outcome : Results.Result;
         begin
            if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
               return Results.Success;
            end if;

            Marker := Restarts.Expected_Marker (Restart_State);
            Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Writers.Write_Marker (Output, Marker);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
            if Results.Succeeded (Restart_Outcome) then
               Arithmetic.Reset (Arithmetic_Encoder);
               AC_Bins := [others => Arithmetic.Initial_Probability_Bin];
               Fixed_Bin := Arithmetic.Initial_Probability_Bin;
               Shared_AC_Bins := [others => Arithmetic.Initial_Probability_Bin];
            end if;

            return Restart_Outcome;
         end Write_Restart_When_Due;
      begin
         for Block_Index in Blocks'Range loop
            for Index in Coefficient_Index range 1 .. 63 loop
               Decoded (Block_Index, Index) := Blocks (Block_Index) (Index) / (2 ** Natural (Al + 1)) /= 0;
            end loop;
         end loop;

         Restarts.Configure (Restart_State, Restart);
         for Block_Index in Blocks'Range loop
            if Restart = 0 then
               Outcome :=
                 Arithmetic.Encode_Progressive_AC_Refine
                   (Arithmetic_Encoder,
                    Shared_AC_Bins,
                    Fixed_Bin,
                    AC_Conditioning => 0,
                    Spectral_Start => 1,
                    Spectral_End => 63,
                    Successive_Low => Natural (Al),
                    Decoded_Coefficients => Decoded,
                    Block_Number => Block_Index,
                    Block => Blocks (Block_Index));
            else
               Outcome :=
                 Arithmetic.Encode_Progressive_AC_Refine
                   (Arithmetic_Encoder,
                    AC_Bins,
                    Fixed_Bin,
                    AC_Conditioning => 0,
                    Spectral_Start => 1,
                    Spectral_End => 63,
                    Successive_Low => Natural (Al),
                    Decoded_Coefficients => Decoded,
                    Block_Number => Block_Index,
                    Block => Blocks (Block_Index));
            end if;
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Outcome := Write_Restart_When_Due (Encoded /= Block_Count (Blocks'Length));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;

         return Arithmetic.Finish (Arithmetic_Encoder);
      end Encode_AC_Refine_Scan;
   begin
      Outcome :=
        Write_SOS (Spectral_Start => 0, Spectral_End => 0, Al => First_Al);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Encode_DC_First_Scan;
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_SOS (Spectral_Start => 1, Spectral_End => 63, Al => First_Al);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Encode_AC_First_Scan;
      if not Results.Succeeded (Outcome) or else not Refine then
         return Outcome;
      end if;

      for Refinement_Al in reverse Successive_Approximation_Value range 0 .. First_Al - 1 loop
         Outcome :=
           Write_SOS
             (Spectral_Start => 0,
              Spectral_End => 0,
              Ah => Refinement_Al + 1,
              Al => Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_DC_Refine_Scan (Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Write_SOS
             (Spectral_Start => 1,
              Spectral_End => 63,
              Ah => Refinement_Al + 1,
              Al => Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_AC_Refine_Scan (Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end loop;

      return Results.Success;
   end Encode_Arithmetic_Progressive_Fast_Preview_Blocks;


   function Encode_Arithmetic_Progressive_Gray_Alpha_Blocks
     (Output : in out Streams.Destination'Class;
      Gray_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Alpha_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      Refine : Boolean) return Results.Result
   is
      First_Al : constant Successive_Approximation_Value := (if Refine then 2 else 0);
      Total_Blocks : constant Positive := Gray_Blocks'Length + Alpha_Blocks'Length;
      DC_Bins : Arithmetic.Probability_Bin_Array (0 .. 63) :=
        [others => Arithmetic.Initial_Probability_Bin];
      AC_Bins : Arithmetic.Probability_Bin_Array (0 .. 255) :=
        [others => Arithmetic.Initial_Probability_Bin];
      DC_Contexts : Arithmetic.DC_Context_Array := [others => 0];
      Predictors : array (Component_Index) of Arithmetic.DC_Difference := [others => 0];
      Decoded : Arithmetic.Decoded_Coefficient_Map (1 .. Total_Blocks, Coefficient_Index) :=
        [others => [others => False]];
      Outcome : Results.Result;

      function Write_Component_DC
        (Component : Component_Identifier;
         Blocks : Jpeglib.Coefficients.DCT_Block_Array;
         Refinement : Boolean;
         Al : Successive_Approximation_Value) return Results.Result
      is
         Component_Index_Value : constant Component_Index := Component_Index (Component);
         Restart_State : Restarts.Restart_State;
         Encoded : Block_Count := 0;
         Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
         DC_Refinement_Bin : Arithmetic.Probability_Bin := Arithmetic.Initial_Probability_Bin;
         Scan_Outcome : Results.Result;

         function Write_Restart_When_Due (More_Blocks : Boolean) return Results.Result is
            Marker : Marker_Code;
            Restart_Outcome : Results.Result;
         begin
            if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
               return Results.Success;
            end if;

            Marker := Restarts.Expected_Marker (Restart_State);
            Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Writers.Write_Marker (Output, Marker);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
            if Results.Succeeded (Restart_Outcome) then
               Arithmetic.Reset (Arithmetic_Encoder);
               DC_Bins := [others => Arithmetic.Initial_Probability_Bin];
               AC_Bins := [others => Arithmetic.Initial_Probability_Bin];
               DC_Contexts := [others => 0];
               Predictors := [others => 0];
               DC_Refinement_Bin := Arithmetic.Initial_Probability_Bin;
            end if;

            return Restart_Outcome;
         end Write_Restart_When_Due;
      begin
         Scan_Outcome :=
           Write_Arithmetic_Component_Progressive_SOS
             (Output,
              Component,
              DC_Scan => True,
              Refinement => Refinement,
              Al => Al);
         if not Results.Succeeded (Scan_Outcome) then
            return Scan_Outcome;
         end if;

         Restarts.Configure (Restart_State, Restart);
         for Block of Blocks loop
            if Refinement then
               Scan_Outcome :=
                 Arithmetic.Encode_Progressive_DC_Refine
                    (Arithmetic_Encoder,
                     DC_Refinement_Bin,
                     Block,
                     Natural (Al));
            else
               declare
                  Scale : constant Arithmetic.DC_Difference := 2 ** Natural (First_Al);
                  DC_Value : constant Arithmetic.DC_Difference :=
                    Arithmetic.DC_Difference (Block (0)) / Scale;
                  Difference : constant Arithmetic.DC_Difference :=
                    DC_Value - Predictors (Component_Index_Value);
               begin
                  Scan_Outcome :=
                    Arithmetic.Encode_DC_Difference
                      (Arithmetic_Encoder,
                       DC_Bins,
                       DC_Contexts (Component_Index_Value),
                       Conditioning => 16#5A#,
                       Difference => Difference);
                  if Results.Succeeded (Scan_Outcome) then
                     Predictors (Component_Index_Value) := DC_Value;
                  end if;
               end;
            end if;
            if not Results.Succeeded (Scan_Outcome) then
               return Scan_Outcome;
            end if;

            Scan_Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Scan_Outcome) then
               return Scan_Outcome;
            end if;

            Encoded := Encoded + 1;
            Scan_Outcome := Write_Restart_When_Due (Encoded /= Block_Count (Blocks'Length));
            if not Results.Succeeded (Scan_Outcome) then
               return Scan_Outcome;
            end if;
         end loop;

         return Arithmetic.Finish (Arithmetic_Encoder);
      exception
         when Constraint_Error =>
            return Results.Failure (Errors.Internal_Invariant_Failed);
      end Write_Component_DC;

      function Write_Component_AC
        (Component : Component_Identifier;
         Blocks : Jpeglib.Coefficients.DCT_Block_Array;
         Block_Start : Positive;
         Refinement : Boolean;
         Al : Successive_Approximation_Value) return Results.Result
      is
         Restart_State : Restarts.Restart_State;
         Encoded : Block_Count := 0;
         Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
         Fixed_Bin : Arithmetic.Probability_Bin := Arithmetic.Initial_Probability_Bin;
         Scan_Outcome : Results.Result;

         function Write_Restart_When_Due (More_Blocks : Boolean) return Results.Result is
            Marker : Marker_Code;
            Restart_Outcome : Results.Result;
         begin
            if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
               return Results.Success;
            end if;

            Marker := Restarts.Expected_Marker (Restart_State);
            Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Writers.Write_Marker (Output, Marker);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
            if Results.Succeeded (Restart_Outcome) then
               Arithmetic.Reset (Arithmetic_Encoder);
               DC_Bins := [others => Arithmetic.Initial_Probability_Bin];
               AC_Bins := [others => Arithmetic.Initial_Probability_Bin];
               DC_Contexts := [others => 0];
               Predictors := [others => 0];
               Fixed_Bin := Arithmetic.Initial_Probability_Bin;
            end if;

            return Restart_Outcome;
         end Write_Restart_When_Due;
      begin
         Scan_Outcome :=
           Write_Arithmetic_Component_Progressive_SOS
             (Output,
              Component,
              DC_Scan => False,
              Refinement => Refinement,
              Al => Al);
         if not Results.Succeeded (Scan_Outcome) then
            return Scan_Outcome;
         end if;

         Restarts.Configure (Restart_State, Restart);
         for Block_Index in Blocks'Range loop
            declare
               Global_Block : constant Positive :=
                 Positive (Block_Start + Block_Index - Blocks'First);
            begin
               if Refinement then
                  Scan_Outcome :=
                    Arithmetic.Encode_Progressive_AC_Refine
                      (Arithmetic_Encoder,
                       AC_Bins,
                       Fixed_Bin,
                       AC_Conditioning => 0,
                       Spectral_Start => 1,
                       Spectral_End => 63,
                       Successive_Low => Natural (Al),
                       Decoded_Coefficients => Decoded,
                       Block_Number => Global_Block,
                       Block => Blocks (Block_Index));
               else
                  Scan_Outcome :=
                    Arithmetic.Encode_Progressive_AC_First
                      (Arithmetic_Encoder,
                       AC_Bins,
                       Fixed_Bin,
                       AC_Conditioning => 0,
                       Spectral_Start => 1,
                       Spectral_End => 63,
                       Successive_Low => Natural (Al),
                       Block => Blocks (Block_Index));
               end if;
            end;
            if not Results.Succeeded (Scan_Outcome) then
               return Scan_Outcome;
            end if;

            Scan_Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Scan_Outcome) then
               return Scan_Outcome;
            end if;

            Encoded := Encoded + 1;
            Scan_Outcome := Write_Restart_When_Due (Encoded /= Block_Count (Blocks'Length));
            if not Results.Succeeded (Scan_Outcome) then
               return Scan_Outcome;
            end if;
         end loop;

         return Arithmetic.Finish (Arithmetic_Encoder);
      exception
         when Constraint_Error =>
            return Results.Failure (Errors.Internal_Invariant_Failed);
      end Write_Component_AC;
   begin
      if not Arithmetic_Blocks_Supported (Gray_Blocks, Restart)
        or else not Arithmetic_Blocks_Supported (Alpha_Blocks, Restart)
      then
         return Results.Failure (Errors.Unsupported_Feature);
      end if;

      for Block_Index in Gray_Blocks'Range loop
         for Index in Coefficient_Index range 1 .. 63 loop
            declare
               Local_Block : constant Positive := Positive (Block_Index - Gray_Blocks'First + 1);
            begin
               Decoded (Local_Block, Index) :=
                 Gray_Blocks (Block_Index) (Index) / (2 ** Natural (First_Al)) /= 0;
            end;
         end loop;
      end loop;

      for Block_Index in Alpha_Blocks'Range loop
         for Index in Coefficient_Index range 1 .. 63 loop
            declare
               Local_Block : constant Positive :=
                 Positive (Gray_Blocks'Length + Block_Index - Alpha_Blocks'First + 1);
            begin
               Decoded (Local_Block, Index) :=
                 Alpha_Blocks (Block_Index) (Index) / (2 ** Natural (First_Al)) /= 0;
            end;
         end loop;
      end loop;

      Outcome := Write_Component_DC (1, Gray_Blocks, Refinement => False, Al => First_Al);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_Component_DC (2, Alpha_Blocks, Refinement => False, Al => First_Al);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_Component_AC (1, Gray_Blocks, Block_Start => 1, Refinement => False, Al => First_Al);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_Component_AC
          (2,
           Alpha_Blocks,
           Block_Start => Positive (Gray_Blocks'Length) + 1,
           Refinement => False,
           Al => First_Al);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Refine then
         for Refinement_Al in reverse Successive_Approximation_Value range 0 .. First_Al - 1 loop
            Outcome := Write_Component_DC (1, Gray_Blocks, Refinement => True, Al => Refinement_Al);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Write_Component_DC (2, Alpha_Blocks, Refinement => True, Al => Refinement_Al);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Write_Component_AC (1, Gray_Blocks, Block_Start => 1, Refinement => True, Al => Refinement_Al);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome :=
              Write_Component_AC
                (2,
                 Alpha_Blocks,
                 Block_Start => Positive (Gray_Blocks'Length) + 1,
                 Refinement => True,
                 Al => Refinement_Al);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;
      end if;

      return Results.Success;
   end Encode_Arithmetic_Progressive_Gray_Alpha_Blocks;

end Jpeglib.Internal.Encoder_Arithmetic_Scans;

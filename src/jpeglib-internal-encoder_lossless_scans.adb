with Interfaces;

with Jpeglib.Errors;
with Jpeglib.Internal.Arithmetic;
with Jpeglib.Internal.Bit_Streams;
with Jpeglib.Internal.Coefficients;
with Jpeglib.Internal.Colors;
with Jpeglib.Internal.Restarts;
with Jpeglib.Internal.Writers;

package body Jpeglib.Internal.Encoder_Lossless_Scans is
   function Encode_Lossless_Gray_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value) return Results.Result
   is
      DC_Compile : constant Huffman.Compile_Result := Huffman.Compile (DC_Definition);
      Restart_State : Restarts.Restart_State;
      Restart_Base : Pixel_Count := 0;
      Encoded : Pixel_Count := 0;
      Total : constant Pixel_Count :=
        Pixel_Count (Input.Descriptor.Width) * Pixel_Count (Input.Descriptor.Height);
      Outcome : Results.Result;

      function Sample (Column, Row : Natural) return Integer is
         Index : constant Positive :=
           Input.Storage'First + Row * Natural (Input.Descriptor.Stride) + Column;
      begin
         return Integer (Input.Storage (Index)) / (2 ** Natural (Point_Transform));
      end Sample;

      function Predictor (Column, Row : Natural) return Integer is
         Ra : Integer;
         Rb : Integer;
         Rc : Integer;
      begin
         if Encoded = Restart_Base then
            return 2 ** (7 - Natural (Point_Transform));
         elsif Column = 0 then
            return Sample (Column, Row - 1);
         elsif Row = 0 then
            return Sample (Column - 1, Row);
         end if;

         Ra := Sample (Column - 1, Row);
         Rb := Sample (Column, Row - 1);
         Rc := Sample (Column - 1, Row - 1);

         case Predictor_Selection is
            when 1 =>
               return Ra;
            when 2 =>
               return Rb;
            when 3 =>
               return Rc;
            when 4 =>
               return Ra + Rb - Rc;
            when 5 =>
               return Ra + (Rb - Rc) / 2;
            when 6 =>
               return Rb + (Ra - Rc) / 2;
            when 7 =>
               return (Ra + Rb) / 2;
         end case;
      end Predictor;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_Samples : Boolean) return Results.Result
      is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Samples then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Restart_Base := Encoded;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Results.Succeeded (DC_Compile.Outcome) then
         return DC_Compile.Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for Row in Natural range 0 .. Natural (Input.Descriptor.Height) - 1 loop
            for Column in Natural range 0 .. Natural (Input.Descriptor.Width) - 1 loop
               Outcome :=
                 Coefficients.Encode_Lossless_Difference
                   (Bits,
                    DC_Compile.Table,
                    Interfaces.Integer_32 (Sample (Column, Row) - Predictor (Column, Row)));
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
   end Encode_Lossless_Gray_Scan;

   function Encode_Lossless_RGB_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value) return Results.Result
   is
      DC_Compile : constant Huffman.Compile_Result := Huffman.Compile (DC_Definition);
      Restart_State : Restarts.Restart_State;
      Restart_Base : Pixel_Count := 0;
      Encoded : Pixel_Count := 0;
      Total : constant Pixel_Count :=
        Pixel_Count (Input.Descriptor.Width) * Pixel_Count (Input.Descriptor.Height);
      Outcome : Results.Result;

      function RGB_At (Column, Row : Natural) return Colors.RGB_Sample is
        (Colors.Read_RGB (Input, Column, Row));

      function Component_Sample
        (Sample : Colors.RGB_Sample;
         Component : Component_Index) return Integer
      is
      begin
         case Component is
            when 1 =>
               return Integer (Sample.R) / (2 ** Natural (Point_Transform));
            when 2 =>
               return Integer (Sample.G) / (2 ** Natural (Point_Transform));
            when 3 =>
               return Integer (Sample.B) / (2 ** Natural (Point_Transform));
            when others =>
               return 0;
         end case;
      end Component_Sample;

      function Sample (Component : Component_Index; Column, Row : Natural) return Integer is
        (Component_Sample (RGB_At (Column, Row), Component));

      function Predictor (Component : Component_Index; Column, Row : Natural) return Integer is
         Ra : Integer;
         Rb : Integer;
         Rc : Integer;
      begin
         if Encoded = Restart_Base then
            return 2 ** (7 - Natural (Point_Transform));
         elsif Column = 0 then
            return Sample (Component, Column, Row - 1);
         elsif Row = 0 then
            return Sample (Component, Column - 1, Row);
         end if;

         Ra := Sample (Component, Column - 1, Row);
         Rb := Sample (Component, Column, Row - 1);
         Rc := Sample (Component, Column - 1, Row - 1);

         case Predictor_Selection is
            when 1 =>
               return Ra;
            when 2 =>
               return Rb;
            when 3 =>
               return Rc;
            when 4 =>
               return Ra + Rb - Rc;
            when 5 =>
               return Ra + (Rb - Rc) / 2;
            when 6 =>
               return Rb + (Ra - Rc) / 2;
            when 7 =>
               return (Ra + Rb) / 2;
         end case;
      end Predictor;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_Samples : Boolean) return Results.Result
      is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Samples then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Restart_Base := Encoded;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Results.Succeeded (DC_Compile.Outcome) then
         return DC_Compile.Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for Row in Natural range 0 .. Natural (Input.Descriptor.Height) - 1 loop
            for Column in Natural range 0 .. Natural (Input.Descriptor.Width) - 1 loop
               for Component in Component_Index range 1 .. 3 loop
                  Outcome :=
                    Coefficients.Encode_Lossless_Difference
                      (Bits,
                       DC_Compile.Table,
                       Interfaces.Integer_32
                         (Sample (Component, Column, Row) - Predictor (Component, Column, Row)));
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end loop;

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
   end Encode_Lossless_RGB_Scan;

   function Encode_Lossless_CMYK_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value;
      YCCK : Boolean) return Results.Result
   is
      DC_Compile : constant Huffman.Compile_Result := Huffman.Compile (DC_Definition);
      Restart_State : Restarts.Restart_State;
      Restart_Base : Pixel_Count := 0;
      Encoded : Pixel_Count := 0;
      Total : constant Pixel_Count :=
        Pixel_Count (Input.Descriptor.Width) * Pixel_Count (Input.Descriptor.Height);
      Outcome : Results.Result;

      function CMYK_At (Column, Row : Natural) return Colors.CMYK_Sample is
        ((if YCCK then Colors.Read_YCCK (Input, Column, Row) else Colors.Read_CMYK (Input, Column, Row)));

      function Component_Sample
        (Sample : Colors.CMYK_Sample;
         Component : Component_Index) return Integer
      is
      begin
         case Component is
            when 1 =>
               return Integer (Sample.C) / (2 ** Natural (Point_Transform));
            when 2 =>
               return Integer (Sample.M) / (2 ** Natural (Point_Transform));
            when 3 =>
               return Integer (Sample.Y) / (2 ** Natural (Point_Transform));
            when 4 =>
               return Integer (Sample.K) / (2 ** Natural (Point_Transform));
            when others =>
               return 0;
         end case;
      end Component_Sample;

      function Sample (Component : Component_Index; Column, Row : Natural) return Integer is
        (Component_Sample (CMYK_At (Column, Row), Component));

      function Predictor (Component : Component_Index; Column, Row : Natural) return Integer is
         Ra : Integer;
         Rb : Integer;
         Rc : Integer;
      begin
         if Encoded = Restart_Base then
            return 2 ** (7 - Natural (Point_Transform));
         elsif Column = 0 then
            return Sample (Component, Column, Row - 1);
         elsif Row = 0 then
            return Sample (Component, Column - 1, Row);
         end if;

         Ra := Sample (Component, Column - 1, Row);
         Rb := Sample (Component, Column, Row - 1);
         Rc := Sample (Component, Column - 1, Row - 1);

         case Predictor_Selection is
            when 1 =>
               return Ra;
            when 2 =>
               return Rb;
            when 3 =>
               return Rc;
            when 4 =>
               return Ra + Rb - Rc;
            when 5 =>
               return Ra + (Rb - Rc) / 2;
            when 6 =>
               return Rb + (Ra - Rc) / 2;
            when 7 =>
               return (Ra + Rb) / 2;
         end case;
      end Predictor;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_Samples : Boolean) return Results.Result
      is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Samples then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Restart_Base := Encoded;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Results.Succeeded (DC_Compile.Outcome) then
         return DC_Compile.Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for Row in Natural range 0 .. Natural (Input.Descriptor.Height) - 1 loop
            for Column in Natural range 0 .. Natural (Input.Descriptor.Width) - 1 loop
               for Component in Component_Index range 1 .. 4 loop
                  Outcome :=
                    Coefficients.Encode_Lossless_Difference
                      (Bits,
                       DC_Compile.Table,
                       Interfaces.Integer_32
                         (Sample (Component, Column, Row) - Predictor (Component, Column, Row)));
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end loop;

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
   end Encode_Lossless_CMYK_Scan;

   function Encode_Lossless_Gray_Alpha_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value) return Results.Result
   is
      DC_Compile : constant Huffman.Compile_Result := Huffman.Compile (DC_Definition);
      Restart_State : Restarts.Restart_State;
      Restart_Base : Pixel_Count := 0;
      Encoded : Pixel_Count := 0;
      Total : constant Pixel_Count :=
        Pixel_Count (Input.Descriptor.Width) * Pixel_Count (Input.Descriptor.Height);
      Outcome : Results.Result;

      function Component_Sample
        (Component : Component_Index;
         Column : Natural;
         Row : Natural) return Integer
      is
         Base : constant Positive :=
           Input.Storage'First
           + Row * Natural (Input.Descriptor.Stride)
           + Column * 2;
      begin
         case Component is
            when 1 =>
               return Integer (Input.Storage (Base)) / (2 ** Natural (Point_Transform));
            when 2 =>
               return Integer (Input.Storage (Base + 1)) / (2 ** Natural (Point_Transform));
            when others =>
               return 0;
         end case;
      end Component_Sample;

      function Predictor (Component : Component_Index; Column, Row : Natural) return Integer is
         Ra : Integer;
         Rb : Integer;
         Rc : Integer;
      begin
         if Encoded = Restart_Base then
            return 2 ** (7 - Natural (Point_Transform));
         elsif Column = 0 then
            return Component_Sample (Component, Column, Row - 1);
         elsif Row = 0 then
            return Component_Sample (Component, Column - 1, Row);
         end if;

         Ra := Component_Sample (Component, Column - 1, Row);
         Rb := Component_Sample (Component, Column, Row - 1);
         Rc := Component_Sample (Component, Column - 1, Row - 1);

         case Predictor_Selection is
            when 1 =>
               return Ra;
            when 2 =>
               return Rb;
            when 3 =>
               return Rc;
            when 4 =>
               return Ra + Rb - Rc;
            when 5 =>
               return Ra + (Rb - Rc) / 2;
            when 6 =>
               return Rb + (Ra - Rc) / 2;
            when 7 =>
               return (Ra + Rb) / 2;
         end case;
      end Predictor;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_Samples : Boolean) return Results.Result
      is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Samples then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Restart_Base := Encoded;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Results.Succeeded (DC_Compile.Outcome) then
         return DC_Compile.Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for Row in Natural range 0 .. Natural (Input.Descriptor.Height) - 1 loop
            for Column in Natural range 0 .. Natural (Input.Descriptor.Width) - 1 loop
               for Component in Component_Index range 1 .. 2 loop
                  Outcome :=
                    Coefficients.Encode_Lossless_Difference
                      (Bits,
                       DC_Compile.Table,
                       Interfaces.Integer_32
                         (Component_Sample (Component, Column, Row) - Predictor (Component, Column, Row)));
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end loop;

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
   end Encode_Lossless_Gray_Alpha_Scan;

   type Arithmetic_Lossless_Sample_Mode is (Gray, Gray_Alpha, RGB, CMYK);

   function Encode_Arithmetic_Lossless_Component_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value;
      Components : Component_Index;
      Mode : Arithmetic_Lossless_Sample_Mode;
      YCCK : Boolean := False) return Results.Result
   is
      type Difference_Array is array (Component_Index range 1 .. Components) of Integer;
      type DC_Bin_By_Component is array (Component_Index range 1 .. Components) of
        Arithmetic.Probability_Bin_Array (0 .. 63);
      Restart_State : Restarts.Restart_State;
      Restart_Base : Pixel_Count := 0;
      Encoded : Pixel_Count := 0;
      Total : constant Pixel_Count :=
        Pixel_Count (Input.Descriptor.Width) * Pixel_Count (Input.Descriptor.Height);
      Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
      DC_Bins : DC_Bin_By_Component := [others => [others => Arithmetic.Initial_Probability_Bin]];
      DC_Contexts : Arithmetic.DC_Context_Array := [others => 0];
      Outcome : Results.Result;

      function Sample (Component : Component_Index; Column, Row : Natural) return Integer is
      begin
         case Mode is
            when Gray =>
               return Integer
                 (Input.Storage
                    (Input.Storage'First + Row * Natural (Input.Descriptor.Stride) + Column))
                 / (2 ** Natural (Point_Transform));

            when Gray_Alpha =>
               declare
                  Base : constant Positive :=
                    Input.Storage'First
                    + Row * Natural (Input.Descriptor.Stride)
                    + Column * 2;
               begin
                  case Component is
                     when 1 =>
                        return Integer (Input.Storage (Base)) / (2 ** Natural (Point_Transform));
                     when 2 =>
                        return Integer (Input.Storage (Base + 1)) / (2 ** Natural (Point_Transform));
                     when others =>
                        return 0;
                  end case;
               end;

            when RGB =>
               declare
                  Value : constant Colors.RGB_Sample := Colors.Read_RGB (Input, Column, Row);
               begin
                  case Component is
                     when 1 =>
                        return Integer (Value.R) / (2 ** Natural (Point_Transform));
                     when 2 =>
                        return Integer (Value.G) / (2 ** Natural (Point_Transform));
                     when 3 =>
                        return Integer (Value.B) / (2 ** Natural (Point_Transform));
                     when others =>
                        return 0;
                  end case;
               end;

            when CMYK =>
               declare
                  Value : constant Colors.CMYK_Sample :=
                    (if YCCK then
                        Colors.Read_YCCK (Input, Column, Row)
                     else
                        Colors.Read_CMYK (Input, Column, Row));
               begin
                  case Component is
                     when 1 =>
                        return Integer (Value.C) / (2 ** Natural (Point_Transform));
                     when 2 =>
                        return Integer (Value.M) / (2 ** Natural (Point_Transform));
                     when 3 =>
                        return Integer (Value.Y) / (2 ** Natural (Point_Transform));
                     when 4 =>
                        return Integer (Value.K) / (2 ** Natural (Point_Transform));
                     when others =>
                        return 0;
                  end case;
               end;
         end case;
      end Sample;

      function Predicted (Component : Component_Index; Column, Row : Natural) return Integer is
         Ra : Integer;
         Rb : Integer;
         Rc : Integer;
      begin
         if Encoded = Restart_Base then
            return 2 ** (7 - Natural (Point_Transform));
         elsif Column = 0 then
            return Sample (Component, Column, Row - 1);
         elsif Row = 0 then
            return Sample (Component, Column - 1, Row);
         end if;

         Ra := Sample (Component, Column - 1, Row);
         Rb := Sample (Component, Column, Row - 1);
         Rc := Sample (Component, Column - 1, Row - 1);

         case Predictor_Selection is
            when 1 =>
               return Ra;
            when 2 =>
               return Rb;
            when 3 =>
               return Rc;
            when 4 =>
               return Ra + Rb - Rc;
            when 5 =>
               return Ra + (Rb - Rc) / 2;
            when 6 =>
               return Rb + (Ra - Rc) / 2;
            when 7 =>
               return (Ra + Rb) / 2;
         end case;
      end Predicted;

      function Write_Restart_When_Due (More_Samples : Boolean) return Results.Result is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Samples then
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
            DC_Bins := [others => [others => Arithmetic.Initial_Probability_Bin]];
            DC_Contexts := [others => 0];
            Restart_Base := Encoded;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;

      function Write_Differences (Differences : Difference_Array) return Results.Result is
         Events : Arithmetic.DC_Difference_Event_Result;
      begin
         for Component in Component_Index range 1 .. Components loop
            Events :=
              Arithmetic.Encode_DC_Difference_Events
                (Arithmetic.DC_Difference (Differences (Component)),
                 DC_Contexts (Component),
                 16#5A#);
            if not Results.Succeeded (Events.Outcome) then
               return Events.Outcome;
            end if;

            for Event_Index in 1 .. Events.Length loop
               Outcome :=
                 Arithmetic.Encode_Bit
                   (Arithmetic_Encoder,
                    DC_Bins (Component) (Events.Events (Event_Index).Bin_Index),
                    Events.Events (Event_Index).Decision);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;

            DC_Contexts (Component) := Events.Final_Context;
         end loop;

         return Results.Success;
      end Write_Differences;
   begin
      Restarts.Configure (Restart_State, Restart);
      for Row in Natural range 0 .. Natural (Input.Descriptor.Height) - 1 loop
         for Column in Natural range 0 .. Natural (Input.Descriptor.Width) - 1 loop
            declare
               Differences : Difference_Array;
            begin
               for Component in Component_Index range 1 .. Components loop
                  Differences (Component) :=
                    Sample (Component, Column, Row) - Predicted (Component, Column, Row);
               end loop;

               Outcome := Write_Differences (Differences);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Outcome := Write_Restart_When_Due (Encoded /= Total);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;
      end loop;

      return Arithmetic.Finish (Arithmetic_Encoder);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Arithmetic_Lossless_Component_Scan;

   function Encode_Arithmetic_Lossless_Gray_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value) return Results.Result is
     (Encode_Arithmetic_Lossless_Component_Scan
        (Output, Input, Restart, Predictor_Selection, Point_Transform, Components => 1, Mode => Gray));

   function Encode_Arithmetic_Lossless_RGB_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value) return Results.Result is
     (Encode_Arithmetic_Lossless_Component_Scan
        (Output, Input, Restart, Predictor_Selection, Point_Transform, Components => 3, Mode => RGB));

   function Encode_Arithmetic_Lossless_CMYK_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value;
      YCCK : Boolean) return Results.Result is
     (Encode_Arithmetic_Lossless_Component_Scan
        (Output, Input, Restart, Predictor_Selection, Point_Transform, Components => 4, Mode => CMYK, YCCK => YCCK));

   function Encode_Arithmetic_Lossless_Gray_Alpha_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value) return Results.Result is
     (Encode_Arithmetic_Lossless_Component_Scan
        (Output, Input, Restart, Predictor_Selection, Point_Transform, Components => 2, Mode => Gray_Alpha));

   function Encode_Huffman_Zero_Residual_Scan
     (Output : in out Streams.Destination'Class;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Width : Image_Width;
      Height : Image_Height;
      Components : Component_Index) return Results.Result
   is
      DC_Compile : constant Huffman.Compile_Result := Huffman.Compile (DC_Definition);
      Restart_State : Restarts.Restart_State;
      Encoded : Pixel_Count := 0;
      Total : constant Pixel_Count := Pixel_Count (Width) * Pixel_Count (Height);
      Outcome : Results.Result;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_Samples : Boolean) return Results.Result
      is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Samples then
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
      if not Results.Succeeded (DC_Compile.Outcome) then
         return DC_Compile.Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
         Remaining : Pixel_Count := Total;
      begin
         while Remaining > 0 loop
            for Component in Component_Index range 1 .. Components loop
               Outcome :=
                 Coefficients.Encode_Lossless_Difference
                   (Bits, DC_Compile.Table, Interfaces.Integer_32 (0));
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Remaining := Remaining - 1;
            Outcome := Write_Restart_When_Due (Bits, Remaining /= 0);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;

         return Bit_Streams.Flush_Byte (Bits);
      end;
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Huffman_Zero_Residual_Scan;

   function Encode_Arithmetic_Zero_Residual_Scan
     (Output : in out Streams.Destination'Class;
      Restart : Restart_Interval;
      Width : Image_Width;
      Height : Image_Height;
      Components : Component_Index) return Results.Result
   is
      type DC_Bin_By_Component is array (Component_Index range 1 .. Components) of
        Arithmetic.Probability_Bin_Array (0 .. 63);
      Restart_State : Restarts.Restart_State;
      Encoded : Pixel_Count := 0;
      Total : constant Pixel_Count := Pixel_Count (Width) * Pixel_Count (Height);
      Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
      DC_Bins : DC_Bin_By_Component := [others => [others => Arithmetic.Initial_Probability_Bin]];
      DC_Contexts : Arithmetic.DC_Context_Array := [others => 0];
      Outcome : Results.Result;

      function Write_Restart_When_Due (More_Samples : Boolean) return Results.Result is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Samples then
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
            DC_Bins := [others => [others => Arithmetic.Initial_Probability_Bin]];
            DC_Contexts := [others => 0];
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      Restarts.Configure (Restart_State, Restart);
      declare
         Remaining : Pixel_Count := Total;
      begin
         while Remaining > 0 loop
            for Component in Component_Index range 1 .. Components loop
               Outcome :=
                 Arithmetic.Encode_DC_Difference
                   (Arithmetic_Encoder,
                    DC_Bins (Component),
                    DC_Contexts (Component),
                    Conditioning => 16#5A#,
                    Difference => 0);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Remaining := Remaining - 1;
            Outcome := Write_Restart_When_Due (Remaining /= 0);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;
      end;

      return Arithmetic.Finish (Arithmetic_Encoder);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Arithmetic_Zero_Residual_Scan;

end Jpeglib.Internal.Encoder_Lossless_Scans;

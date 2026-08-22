with Jpeglib.Errors;
with Jpeglib.Internal.Arithmetic;
with Jpeglib.Internal.Decoding_Support;
with Jpeglib.Internal.Frames;
with Jpeglib.Internal.Huffman;
with Jpeglib.Internal.Markers;
with Jpeglib.Internal.Restarts;
with Jpeglib.Internal.Scans;
with Jpeglib.Internal.Segments;

package body Jpeglib.Internal.Decoder_Continuations is
   use type Internal.Frames.Sampling_Factor;

   function Decode_Hierarchical_Lossless_Continuation
     (Header : in out Internal.Decoder.Header_Result;
      Input : not null access Streams.Source'Class;
      Ending : Internal.Bit_Streams.Entropy_Read_Result;
      Samples : access Lossless_Sample_Array := null) return Results.Result
   is
      use type Internal.Bit_Streams.Entropy_Byte_Kind;
      use type Internal.Bit_Streams.Entropy_Bits;

      type Compiled_Array is array (Component_Index range <>) of Internal.Huffman.Compiled_Huffman;
      type Context_Array is array (Component_Index range <>) of Internal.Arithmetic.DC_Context_Index;
      type DC_Bin_Set_Array is array (Component_Index range <>) of
        Internal.Arithmetic.Probability_Bin_Array (0 .. 63);
      type Component_Decoded_Array is array (Component_Index range <>) of Boolean;
      type Scan_End_Result is record
         Outcome : Results.Result := Results.Success;
         Ending : Internal.Bit_Streams.Entropy_Read_Result;
      end record;

      Base_Frame : constant Internal.Frames.Frame := Header.Frame;
      Base_Scan : constant Internal.Scans.Scan := Header.Scan;
      Base_Entropy : constant Entropy_Mode := Header.Entropy;
      Base_Restart : constant Restart_Interval := Header.Restart;
      Marker : Internal.Markers.Marker_Result :=
        (Outcome => Ending.Outcome, Source => Ending.Source, Marker => Ending.Marker);
      Continuation_Decoded : Component_Decoded_Array
        (1 .. Component_Index (Internal.Frames.Components (Header.Frame))) := [others => False];

      procedure Restore_Base_Header is
      begin
         Header.Frame := Base_Frame;
         Header.Scan := Base_Scan;
         Header.Entropy := Base_Entropy;
         Header.Restart := Base_Restart;
      end Restore_Base_Header;

      function Unexpected (Item : Internal.Markers.Marker_Result) return Results.Result is
        (Results.Failure
           (Errors.Make
              (Errors.Marker_Unexpected,
               (Source => Item.Source, Marker => Item.Marker, others => <>))));

      function Unsupported (Item : Internal.Markers.Marker_Result) return Results.Result is
        (Results.Failure
           (Errors.Make
              (Errors.Unsupported_Feature,
               (Source => Item.Source, Marker => Item.Marker, others => <>))));

      procedure Skip_EXP_Payload is
         Segment : Internal.Segments.Segment_Reader :=
           Internal.Segments.Open (Input, Marker.Marker, Marker.Source);
      begin
         Header.Outcome := Internal.Segments.Status (Segment);
         if Results.Succeeded (Header.Outcome) then
            Header.Outcome := Internal.Segments.Skip_Remaining (Segment);
         end if;
      end Skip_EXP_Payload;

      procedure Skip_EXP_And_Read_Next is
      begin
         Skip_EXP_Payload;
         if Results.Succeeded (Header.Outcome) then
            Marker := Internal.Markers.Read_Next (Input.all);
            Header.Outcome := Marker.Outcome;
         end if;
      end Skip_EXP_And_Read_Next;

      function Read_Category_Bits
        (Bits : in out Internal.Bit_Streams.Bit_Reader;
         Category : Internal.Bit_Streams.Entropy_Category) return Internal.Bit_Streams.Sign_Extend_Result
      is
         Raw : Internal.Bit_Streams.Entropy_Bits := 0;
         Bit : Internal.Bit_Streams.Bit_Result;
      begin
         for Index in 1 .. Natural (Category) loop
            Bit := Internal.Bit_Streams.Read_Bit (Bits);
            if not Results.Succeeded (Bit.Outcome) then
               return (Outcome => Bit.Outcome, Value => 0);
            end if;

            Raw :=
              (Raw * Internal.Bit_Streams.Entropy_Bits (2))
              + Internal.Bit_Streams.Entropy_Bits (Bit.Value);
         end loop;

         return Internal.Bit_Streams.Sign_Extend (Category, Raw);
      end Read_Category_Bits;

      function Frame_Matches_Base return Boolean is
         Base_Component : Internal.Frames.Frame_Component;
         Diff_Component : Internal.Frames.Frame_Component;
      begin
         if Internal.Frames.Mode (Header.Frame) /= Differential_Lossless
           or else Internal.Frames.Width (Header.Frame) /= Internal.Frames.Width (Base_Frame)
           or else Internal.Frames.Height (Header.Frame) /= Internal.Frames.Height (Base_Frame)
           or else Internal.Frames.Precision (Header.Frame) /= Internal.Frames.Precision (Base_Frame)
           or else Internal.Frames.Components (Header.Frame) /= Internal.Frames.Components (Base_Frame)
         then
            return False;
         end if;

         for Index in Component_Index range 1 .. Component_Index (Internal.Frames.Components (Base_Frame)) loop
            Base_Component := Internal.Frames.Component (Base_Frame, Index);
            Diff_Component := Internal.Frames.Component (Header.Frame, Index);
            if Diff_Component.Identifier /= Base_Component.Identifier
              or else Diff_Component.Horizontal_Sampling /= Base_Component.Horizontal_Sampling
              or else Diff_Component.Vertical_Sampling /= Base_Component.Vertical_Sampling
              or else Diff_Component.Component_Width /= Base_Component.Component_Width
              or else Diff_Component.Component_Height /= Base_Component.Component_Height
            then
               return False;
            end if;
         end loop;

         return True;
      end Frame_Matches_Base;

      function Scan_Components_Valid return Boolean is
         Scan_Component : Internal.Scans.Scan_Component;
      begin
         for Index in Component_Index range 1 .. Component_Index (Internal.Scans.Components (Header.Scan)) loop
            Scan_Component := Internal.Scans.Component (Header.Scan, Index);
            if Scan_Component.Frame_Component not in
              1 .. Component_Index (Internal.Frames.Components (Header.Frame))
            then
               return False;
            end if;
         end loop;

         return True;
      end Scan_Components_Valid;

      function Scan_Components_Not_Previously_Decoded return Boolean is
         Scan_Component : Internal.Scans.Scan_Component;
      begin
         for Index in Component_Index range 1 .. Component_Index (Internal.Scans.Components (Header.Scan)) loop
            Scan_Component := Internal.Scans.Component (Header.Scan, Index);
            if Continuation_Decoded (Scan_Component.Frame_Component) then
               return False;
            end if;
         end loop;

         return True;
      end Scan_Components_Not_Previously_Decoded;

      procedure Mark_Continuation_Scan_Decoded is
         Scan_Component : Internal.Scans.Scan_Component;
      begin
         for Index in Component_Index range 1 .. Component_Index (Internal.Scans.Components (Header.Scan)) loop
            Scan_Component := Internal.Scans.Component (Header.Scan, Index);
            Continuation_Decoded (Scan_Component.Frame_Component) := True;
         end loop;
      end Mark_Continuation_Scan_Decoded;

      function Incomplete_Continuation_Scan_Data return Results.Result is
      begin
         for Index in Continuation_Decoded'Range loop
            if not Continuation_Decoded (Index) then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Scan_Invalid_Definition,
                       (Frame_Component => Index,
                        Detail => Long_Long_Integer (Index),
                        others => <>)));
            end if;
         end loop;

         return Results.Success;
      end Incomplete_Continuation_Scan_Data;

      function Residual_Scan_Width return Natural is
        ((Natural (Internal.Frames.Width (Base_Frame))
          + Natural (Internal.Frames.Maximum_Horizontal_Sampling (Base_Frame))
          - 1)
         / Natural (Internal.Frames.Maximum_Horizontal_Sampling (Base_Frame)));

      function Residual_Scan_Height return Natural is
        ((Natural (Internal.Frames.Height (Base_Frame))
          + Natural (Internal.Frames.Maximum_Vertical_Sampling (Base_Frame))
          - 1)
         / Natural (Internal.Frames.Maximum_Vertical_Sampling (Base_Frame)));

      function Add_Residual
        (Component : Component_Index;
         Column : Natural;
         Row : Natural;
         Residual : Integer;
         Source : Source_Offset := 0) return Results.Result
      is
         Sample : Integer;
         Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Base_Frame)) - 1;
      begin
         if Samples = null then
            if Residual = 0 then
               return Results.Success;
            end if;

            return
              Results.Failure
                (Errors.Make
                   (Errors.Unsupported_Feature,
                    (Source => Source, Detail => Long_Long_Integer (Residual), others => <>)));
         end if;

         declare
            Frame_Component : constant Internal.Frames.Frame_Component :=
              Internal.Frames.Component (Base_Frame, Component);
            Offset : constant Positive :=
              Samples'First (2) + Row * Natural (Frame_Component.Component_Width) + Column;
         begin
            Sample := Samples (Component, Offset) + Residual;
            if Sample not in 0 .. Max_Sample then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Coefficient_Invalid_Encoding,
                       (Source => Source, Detail => Long_Long_Integer (Sample), others => <>)));
            end if;

            Samples (Component, Offset) := Sample;
            return Results.Success;
         end;
      end Add_Residual;

      function Decode_Huffman_Residual_Scan return Scan_End_Result is
         Component_Total : constant Component_Index := Component_Index (Internal.Frames.Components (Header.Frame));
         Scan_Width : constant Natural := Residual_Scan_Width;
         Scan_Height : constant Natural := Residual_Scan_Height;
         Total : constant Natural := Scan_Width * Scan_Height;
         Entropy : aliased Internal.Bit_Streams.Entropy_Reader (Input);
         Bits : Internal.Bit_Streams.Bit_Reader (Entropy'Access);
         Tables : Compiled_Array (1 .. Component_Total);
         Compile : Internal.Huffman.Compile_Result;
         Symbol : Internal.Huffman.Decode_Result;
         Extended : Internal.Bit_Streams.Sign_Extend_Result;
         Restart_State : Internal.Restarts.Restart_State;
         Decoded : Natural := 0;

         function Accept_Restart_When_Due return Results.Result is
            Restart_Marker : Internal.Bit_Streams.Entropy_Read_Result;
            Outcome : Results.Result;
         begin
            if Header.Restart = 0
              or else Internal.Restarts.MCUs_Until_Restart (Restart_State) /= 0
              or else Decoded = Total
            then
               return Results.Success;
            end if;

            Internal.Bit_Streams.Byte_Align (Bits);
            Restart_Marker := Internal.Bit_Streams.Read_Byte (Entropy);
            if not Results.Succeeded (Restart_Marker.Outcome) then
               return Restart_Marker.Outcome;
            elsif Restart_Marker.Kind /= Internal.Bit_Streams.Restart_Marker then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Restart_Invalid_State,
                       (Source => Restart_Marker.Source, Marker => Restart_Marker.Marker, others => <>)));
            end if;

            Outcome :=
              Internal.Restarts.Accept_Restart
                (Restart_State, Restart_Marker.Marker, Restart_Marker.Source);
            return Outcome;
         end Accept_Restart_When_Due;
      begin
         if Header.Entropy = Jpeglib.Arithmetic or else not Scan_Components_Valid then
            return (Outcome => Results.Failure (Errors.Unsupported_Feature), Ending => <>);
         end if;

         for Index in Component_Index range 1 .. Component_Index (Internal.Scans.Components (Header.Scan)) loop
            declare
               Scan_Component : constant Internal.Scans.Scan_Component :=
                 Internal.Scans.Component (Header.Scan, Index);
            begin
               if not Internal.Huffman.Has_Table
                 (Header.Huffman_State, Internal.Huffman.DC, Scan_Component.DC_Table)
               then
                  return
                    (Outcome =>
                       Results.Failure
                         (Errors.Make
                            (Errors.Table_Invalid_Definition,
                             (Frame_Component => Scan_Component.Frame_Component,
                              Detail => Long_Long_Integer (Scan_Component.DC_Table),
                              others => <>))),
                     Ending => <>);
               end if;

               Compile :=
                 Internal.Huffman.Compile
                   (Internal.Huffman.Definition
                      (Header.Huffman_State, Internal.Huffman.DC, Scan_Component.DC_Table));
               if not Results.Succeeded (Compile.Outcome) then
                  return (Outcome => Compile.Outcome, Ending => <>);
               end if;
               Tables (Index) := Compile.Table;
            end;
         end loop;

         Internal.Restarts.Configure (Restart_State, Header.Restart);
         for MCU_Row_Value in Natural range 0 .. Scan_Height - 1 loop
            for MCU_Column_Value in Natural range 0 .. Scan_Width - 1 loop
               for Index in Component_Index range 1 .. Component_Index (Internal.Scans.Components (Header.Scan)) loop
                  declare
                     Scan_Component : constant Internal.Scans.Scan_Component :=
                       Internal.Scans.Component (Header.Scan, Index);
                     Frame_Component : constant Internal.Frames.Frame_Component :=
                       Internal.Frames.Component (Header.Frame, Scan_Component.Frame_Component);
                  begin
                     for V in Natural range 0 .. Natural (Frame_Component.Vertical_Sampling) - 1 loop
                        for H in Natural range 0 .. Natural (Frame_Component.Horizontal_Sampling) - 1 loop
                           declare
                              Column : constant Natural :=
                                MCU_Column_Value * Natural (Frame_Component.Horizontal_Sampling) + H;
                              Row : constant Natural :=
                                MCU_Row_Value * Natural (Frame_Component.Vertical_Sampling) + V;
                           begin
                              if Column < Natural (Frame_Component.Component_Width)
                                and then Row < Natural (Frame_Component.Component_Height)
                              then
                                 Symbol := Internal.Huffman.Decode (Tables (Index), Bits);
                                 if not Results.Succeeded (Symbol.Outcome) then
                                    return (Outcome => Symbol.Outcome, Ending => <>);
                                 elsif Symbol.Symbol > 16 then
                                    return
                                      (Outcome =>
                                         Results.Failure
                                           (Errors.Make
                                              (Errors.Coefficient_Invalid_Encoding,
                                               (Source => Symbol.Source,
                                                Detail => Long_Long_Integer (Symbol.Symbol),
                                                others => <>))),
                                       Ending => <>);
                                 end if;

                                 Extended :=
                                   Read_Category_Bits
                                     (Bits, Internal.Bit_Streams.Entropy_Category (Symbol.Symbol));
                                 if not Results.Succeeded (Extended.Outcome) then
                                    return (Outcome => Extended.Outcome, Ending => <>);
                                 end if;

                                 declare
                                    Outcome : constant Results.Result :=
                                      Add_Residual
                                        (Scan_Component.Frame_Component,
                                         Column,
                                         Row,
                                         Integer (Extended.Value),
                                         Symbol.Source);
                                 begin
                                    if not Results.Succeeded (Outcome) then
                                       return (Outcome => Outcome, Ending => <>);
                                    end if;
                                 end;
                              end if;
                           end;
                        end loop;
                     end loop;
                  end;
               end loop;

               Decoded := Decoded + 1;
               declare
                  Outcome : Results.Result := Internal.Restarts.Advance_MCU (Restart_State);
               begin
                  if not Results.Succeeded (Outcome) then
                     return (Outcome => Outcome, Ending => <>);
                  end if;

                  Outcome := Accept_Restart_When_Due;
                  if not Results.Succeeded (Outcome) then
                     return (Outcome => Outcome, Ending => <>);
                  end if;
               end;
            end loop;
         end loop;

         Internal.Bit_Streams.Byte_Align (Bits);
         declare
            Next_Ending : constant Internal.Bit_Streams.Entropy_Read_Result :=
              Internal.Bit_Streams.Read_Byte (Entropy);
         begin
            if not Results.Succeeded (Next_Ending.Outcome) then
               return (Outcome => Next_Ending.Outcome, Ending => <>);
            elsif Next_Ending.Kind /= Internal.Bit_Streams.Scan_Ending_Marker then
               return
                 (Outcome =>
                    Results.Failure
                      (Errors.Make
                         (Errors.Marker_Unexpected,
                          (Source => Next_Ending.Source, Marker => Next_Ending.Marker, others => <>))),
                  Ending => <>);
            end if;

            return (Outcome => Results.Success, Ending => Next_Ending);
         end;
      end Decode_Huffman_Residual_Scan;

      function Decode_Arithmetic_Residual_Scan return Scan_End_Result is
         Component_Total : constant Component_Index := Component_Index (Internal.Frames.Components (Header.Frame));
         Scan_Width : constant Natural := Residual_Scan_Width;
         Scan_Height : constant Natural := Residual_Scan_Height;
         Total : constant Natural := Scan_Width * Scan_Height;
         Entropy : aliased Internal.Bit_Streams.Entropy_Reader (Input);
         Arithmetic_Decoder : Internal.Arithmetic.Decoder (Entropy'Access);
         DC_Bins : DC_Bin_Set_Array (1 .. Component_Total) :=
           [others => [others => Internal.Arithmetic.Initial_Probability_Bin]];
         DC_Contexts : Context_Array (1 .. Component_Total) := [others => 0];
         DC : Internal.Arithmetic.DC_Result;
         Restart_State : Internal.Restarts.Restart_State;
         Decoded : Natural := 0;

         function Accept_Restart_When_Due return Results.Result is
            Restart_Marker : Internal.Bit_Streams.Entropy_Read_Result;
            Outcome : Results.Result;
         begin
            if Header.Restart = 0
              or else Internal.Restarts.MCUs_Until_Restart (Restart_State) /= 0
              or else Decoded = Total
            then
               return Results.Success;
            end if;

            Restart_Marker := Internal.Bit_Streams.Read_Byte (Entropy);
            if not Results.Succeeded (Restart_Marker.Outcome) then
               return Restart_Marker.Outcome;
            elsif Restart_Marker.Kind /= Internal.Bit_Streams.Restart_Marker then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Restart_Invalid_State,
                       (Source => Restart_Marker.Source, Marker => Restart_Marker.Marker, others => <>)));
            end if;

            Outcome :=
              Internal.Restarts.Accept_Restart
                (Restart_State, Restart_Marker.Marker, Restart_Marker.Source);
            if Results.Succeeded (Outcome) then
               Internal.Arithmetic.Reset (Arithmetic_Decoder);
               DC_Bins := [others => [others => Internal.Arithmetic.Initial_Probability_Bin]];
               DC_Contexts := [others => 0];
            end if;
            return Outcome;
         end Accept_Restart_When_Due;
      begin
         if not Scan_Components_Valid then
            return (Outcome => Results.Failure (Errors.Unsupported_Feature), Ending => <>);
         end if;

         for Index in Component_Index range 1 .. Component_Index (Internal.Scans.Components (Header.Scan)) loop
            declare
               Scan_Component : constant Internal.Scans.Scan_Component :=
                 Internal.Scans.Component (Header.Scan, Index);
            begin
               if not Internal.Arithmetic.Has_Table
                 (Header.Arithmetic_State, Internal.Arithmetic.DC, Scan_Component.DC_Table)
               then
                  return
                    (Outcome =>
                       Results.Failure
                         (Errors.Make
                            (Errors.Table_Invalid_Definition,
                             (Frame_Component => Scan_Component.Frame_Component,
                              Detail => Long_Long_Integer (Scan_Component.DC_Table),
                              others => <>))),
                     Ending => <>);
               end if;
            end;
         end loop;

         Internal.Restarts.Configure (Restart_State, Header.Restart);
         for MCU_Row_Value in Natural range 0 .. Scan_Height - 1 loop
            for MCU_Column_Value in Natural range 0 .. Scan_Width - 1 loop
               for Index in Component_Index range 1 .. Component_Index (Internal.Scans.Components (Header.Scan)) loop
                  declare
                     Scan_Component : constant Internal.Scans.Scan_Component :=
                       Internal.Scans.Component (Header.Scan, Index);
                     Frame_Component : constant Internal.Frames.Frame_Component :=
                       Internal.Frames.Component (Header.Frame, Scan_Component.Frame_Component);
                  begin
                     for V in Natural range 0 .. Natural (Frame_Component.Vertical_Sampling) - 1 loop
                        for H in Natural range 0 .. Natural (Frame_Component.Horizontal_Sampling) - 1 loop
                           declare
                              Column : constant Natural :=
                                MCU_Column_Value * Natural (Frame_Component.Horizontal_Sampling) + H;
                              Row : constant Natural :=
                                MCU_Row_Value * Natural (Frame_Component.Vertical_Sampling) + V;
                           begin
                              if Column < Natural (Frame_Component.Component_Width)
                                and then Row < Natural (Frame_Component.Component_Height)
                              then
                                 DC :=
                                   Internal.Arithmetic.Decode_DC_Difference
                                     (Arithmetic_Decoder,
                                      DC_Bins (Scan_Component.Frame_Component),
                                      DC_Contexts (Scan_Component.Frame_Component),
                                      Internal.Arithmetic.Value
                                        (Header.Arithmetic_State, Internal.Arithmetic.DC, Scan_Component.DC_Table));

                                 if not Results.Succeeded (DC.Outcome) then
                                    return (Outcome => DC.Outcome, Ending => <>);
                                 end if;

                                 declare
                                    Outcome : constant Results.Result :=
                                      Add_Residual
                                        (Scan_Component.Frame_Component,
                                         Column,
                                         Row,
                                         Integer (DC.Difference),
                                         DC.Source);
                                 begin
                                    if not Results.Succeeded (Outcome) then
                                       return (Outcome => Outcome, Ending => <>);
                                    end if;
                                 end;
                              end if;
                           end;
                        end loop;
                     end loop;
                  end;
               end loop;

               Decoded := Decoded + 1;
               declare
                  Outcome : Results.Result := Internal.Restarts.Advance_MCU (Restart_State);
               begin
                  if not Results.Succeeded (Outcome) then
                     return (Outcome => Outcome, Ending => <>);
                  end if;

                  Outcome := Accept_Restart_When_Due;
                  if not Results.Succeeded (Outcome) then
                     return (Outcome => Outcome, Ending => <>);
                  end if;
               end;
            end loop;
         end loop;

         declare
            Next_Ending : constant Internal.Bit_Streams.Entropy_Read_Result :=
              Internal.Bit_Streams.Read_Byte (Entropy);
         begin
            if not Results.Succeeded (Next_Ending.Outcome) then
               return (Outcome => Next_Ending.Outcome, Ending => <>);
            elsif Next_Ending.Kind /= Internal.Bit_Streams.Scan_Ending_Marker then
               return
                 (Outcome =>
                    Results.Failure
                      (Errors.Make
                         (Errors.Marker_Unexpected,
                          (Source => Next_Ending.Source, Marker => Next_Ending.Marker, others => <>))),
                  Ending => <>);
            end if;

            return (Outcome => Results.Success, Ending => Next_Ending);
         end;
      end Decode_Arithmetic_Residual_Scan;

      function Decode_Current_Continuation_Scan return Scan_End_Result is
         Scan_Component : Internal.Scans.Scan_Component;
         Scan_End : Scan_End_Result;
      begin
         if not Scan_Components_Not_Previously_Decoded then
            for Index in Component_Index range 1 .. Component_Index (Internal.Scans.Components (Header.Scan)) loop
               Scan_Component := Internal.Scans.Component (Header.Scan, Index);
               if Continuation_Decoded (Scan_Component.Frame_Component) then
                  return
                    (Outcome =>
                       Results.Failure
                         (Errors.Make
                            (Errors.Scan_Invalid_Definition,
                             (Frame_Component => Scan_Component.Frame_Component,
                              Detail => Long_Long_Integer (Scan_Component.Frame_Component),
                              others => <>))),
                     Ending => <>);
               end if;
            end loop;
         end if;

         Scan_End :=
           (if Header.Entropy = Jpeglib.Arithmetic
            then Decode_Arithmetic_Residual_Scan
            else Decode_Huffman_Residual_Scan);
         if Results.Succeeded (Scan_End.Outcome) then
            Mark_Continuation_Scan_Decoded;
         end if;

         return Scan_End;
      end Decode_Current_Continuation_Scan;
   begin
      if not Results.Succeeded (Ending.Outcome) then
         return Ending.Outcome;
      elsif Ending.Kind /= Internal.Bit_Streams.Scan_Ending_Marker then
         return
           Results.Failure
             (Errors.Make
                (Errors.Marker_Unexpected,
                 (Source => Ending.Source, Marker => Ending.Marker, others => <>)));
      elsif Ending.Marker = Internal.Markers.EOI then
         return Results.Success;
      elsif Ending.Marker = Internal.Markers.DNL then
         declare
            Outcome : constant Results.Result :=
              Internal.Decoding_Support.Parse_Known_Height_DNL (Input, Ending.Source, Header.Frame);
         begin
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end;

         Marker := Internal.Markers.Read_Next (Input.all);
         if not Results.Succeeded (Marker.Outcome) then
            return Marker.Outcome;
         elsif Marker.Marker = Internal.Markers.EOI then
            return Results.Success;
         elsif not Header.Hierarchical then
            return Unexpected (Marker);
         end if;
      elsif not Header.Hierarchical then
         return Unexpected (Marker);
      end if;

      loop
         if Marker.Marker = Internal.Markers.DHT then
            declare
               Segment : Internal.Segments.Segment_Reader :=
                 Internal.Segments.Open (Input, Marker.Marker, Marker.Source);
            begin
               Header.Outcome := Internal.Segments.Status (Segment);
               if Results.Succeeded (Header.Outcome) then
                  Header.Outcome := Internal.Huffman.Parse_DHT (Header.Huffman_State, Segment);
               end if;
            end;
            if Results.Succeeded (Header.Outcome) then
               Marker := Internal.Markers.Read_Next (Input.all);
               Header.Outcome := Marker.Outcome;
            end if;
         elsif Marker.Marker = Internal.Markers.DAC then
            declare
               Segment : Internal.Segments.Segment_Reader :=
                 Internal.Segments.Open (Input, Marker.Marker, Marker.Source);
            begin
               Header.Outcome := Internal.Segments.Status (Segment);
               if Results.Succeeded (Header.Outcome) then
                  Header.Outcome := Internal.Arithmetic.Parse_DAC (Header.Arithmetic_State, Segment);
               end if;
            end;
            if Results.Succeeded (Header.Outcome) then
               Marker := Internal.Markers.Read_Next (Input.all);
               Header.Outcome := Marker.Outcome;
            end if;
         elsif Marker.Marker = Internal.Markers.DRI then
            declare
               Segment : Internal.Segments.Segment_Reader :=
                 Internal.Segments.Open (Input, Marker.Marker, Marker.Source);
               DRI : Internal.Restarts.DRI_Result;
            begin
               Header.Outcome := Internal.Segments.Status (Segment);
               if Results.Succeeded (Header.Outcome) then
                  DRI := Internal.Restarts.Read_DRI (Segment);
                  Header.Outcome := DRI.Outcome;
                  Header.Restart := DRI.Interval;
               end if;
            end;
            if Results.Succeeded (Header.Outcome) then
               Marker := Internal.Markers.Read_Next (Input.all);
               Header.Outcome := Marker.Outcome;
            end if;
         elsif Marker.Marker = Internal.Markers.EXP then
            Skip_EXP_And_Read_Next;
         elsif Marker.Marker = Internal.Markers.TEM then
            Marker := Internal.Markers.Read_Next (Input.all);
            Header.Outcome := Marker.Outcome;
         elsif Marker.Marker in Internal.Markers.SOF7 | Internal.Markers.SOF15 then
            declare
               Segment : Internal.Segments.Segment_Reader :=
                 Internal.Segments.Open (Input, Marker.Marker, Marker.Source);
            begin
               Header.Outcome := Internal.Segments.Status (Segment);
               if Results.Succeeded (Header.Outcome) then
                  Header.Frame := Internal.Frames.Parse_SOF (Segment, Differential_Lossless);
                  Header.Outcome := Internal.Frames.Status (Header.Frame);
                  Header.Entropy :=
                    (if Marker.Marker = Internal.Markers.SOF15
                     then Entropy_Mode'Val (1)
                     else Entropy_Mode'Val (0));
                  Continuation_Decoded := [others => False];
               end if;
            end;

            if Results.Succeeded (Header.Outcome) and then not Frame_Matches_Base then
               Header.Outcome := Unsupported (Marker);
            end if;

            if Results.Succeeded (Header.Outcome) then
               loop
                  Marker := Internal.Markers.Read_Next (Input.all);
                  if not Results.Succeeded (Marker.Outcome) then
                     Header.Outcome := Marker.Outcome;
                     exit;
                  elsif Marker.Marker = Internal.Markers.DHT then
                     declare
                        Segment : Internal.Segments.Segment_Reader :=
                          Internal.Segments.Open (Input, Marker.Marker, Marker.Source);
                     begin
                        Header.Outcome := Internal.Segments.Status (Segment);
                        if Results.Succeeded (Header.Outcome) then
                           Header.Outcome := Internal.Huffman.Parse_DHT (Header.Huffman_State, Segment);
                        end if;
                     end;
                  elsif Marker.Marker = Internal.Markers.DAC then
                     declare
                        Segment : Internal.Segments.Segment_Reader :=
                          Internal.Segments.Open (Input, Marker.Marker, Marker.Source);
                     begin
                        Header.Outcome := Internal.Segments.Status (Segment);
                        if Results.Succeeded (Header.Outcome) then
                           Header.Outcome := Internal.Arithmetic.Parse_DAC (Header.Arithmetic_State, Segment);
                        end if;
                     end;
                  elsif Marker.Marker = Internal.Markers.DRI then
                     declare
                        Segment : Internal.Segments.Segment_Reader :=
                          Internal.Segments.Open (Input, Marker.Marker, Marker.Source);
                        DRI : Internal.Restarts.DRI_Result;
                     begin
                        Header.Outcome := Internal.Segments.Status (Segment);
                        if Results.Succeeded (Header.Outcome) then
                           DRI := Internal.Restarts.Read_DRI (Segment);
                           Header.Outcome := DRI.Outcome;
                           Header.Restart := DRI.Interval;
                        end if;
                     end;
                  elsif Marker.Marker = Internal.Markers.EXP then
                     Skip_EXP_Payload;
                  elsif Marker.Marker = Internal.Markers.TEM then
                     null;
                  elsif Marker.Marker = Internal.Markers.SOS then
                     declare
                        Segment : Internal.Segments.Segment_Reader :=
                          Internal.Segments.Open (Input, Marker.Marker, Marker.Source);
                     begin
                        Header.Outcome := Internal.Segments.Status (Segment);
                        if Results.Succeeded (Header.Outcome) then
                           Header.Scan :=
                             Internal.Scans.Parse_SOS
                               (Header.Frame,
                                Segment,
                                Progressive => False,
                                Lossless => True);
                           Header.Outcome := Internal.Scans.Status (Header.Scan);
                        end if;
                     end;
                     exit;
                  else
                     Header.Outcome := Unexpected (Marker);
                     exit;
                  end if;

                  exit when not Results.Succeeded (Header.Outcome);
               end loop;
            end if;

            if Results.Succeeded (Header.Outcome) then
               declare
                  Scan_End : constant Scan_End_Result := Decode_Current_Continuation_Scan;
               begin
                  if not Results.Succeeded (Scan_End.Outcome) then
                     Header.Outcome := Scan_End.Outcome;
                  elsif Scan_End.Ending.Marker = Internal.Markers.EOI then
                     Header.Outcome := Incomplete_Continuation_Scan_Data;
                     if Results.Succeeded (Header.Outcome) then
                        Restore_Base_Header;
                        return Results.Success;
                     end if;
                  else
                     Marker :=
                       (Outcome => Results.Success,
                        Source => Scan_End.Ending.Source,
                        Marker => Scan_End.Ending.Marker);
                  end if;
               end;
            end if;
         elsif Marker.Marker = Internal.Markers.SOS then
            if Internal.Frames.Mode (Header.Frame) /= Differential_Lossless
              or else not Frame_Matches_Base
            then
               Header.Outcome := Unexpected (Marker);
            else
               declare
                  Segment : Internal.Segments.Segment_Reader :=
                    Internal.Segments.Open (Input, Marker.Marker, Marker.Source);
                  Scan_End : Scan_End_Result;
               begin
                  Header.Outcome := Internal.Segments.Status (Segment);
                  if Results.Succeeded (Header.Outcome) then
                     Header.Scan :=
                       Internal.Scans.Parse_SOS
                         (Header.Frame,
                          Segment,
                          Progressive => False,
                          Lossless => True);
                     Header.Outcome := Internal.Scans.Status (Header.Scan);
                  end if;

                  if Results.Succeeded (Header.Outcome) then
                     Scan_End := Decode_Current_Continuation_Scan;
                     if not Results.Succeeded (Scan_End.Outcome) then
                        Header.Outcome := Scan_End.Outcome;
                     elsif Scan_End.Ending.Marker = Internal.Markers.EOI then
                        Header.Outcome := Incomplete_Continuation_Scan_Data;
                        if Results.Succeeded (Header.Outcome) then
                           Restore_Base_Header;
                           return Results.Success;
                        end if;
                     else
                        Marker :=
                          (Outcome => Results.Success,
                           Source => Scan_End.Ending.Source,
                           Marker => Scan_End.Ending.Marker);
                     end if;
                  end if;
               end;
            end if;
         elsif Internal.Markers.Is_Frame (Marker.Marker) then
            Header.Outcome := Unsupported (Marker);
         else
            Header.Outcome := Unexpected (Marker);
         end if;

         if not Results.Succeeded (Header.Outcome) then
            Restore_Base_Header;
            return Header.Outcome;
         end if;
      end loop;
   end Decode_Hierarchical_Lossless_Continuation;

end Jpeglib.Internal.Decoder_Continuations;

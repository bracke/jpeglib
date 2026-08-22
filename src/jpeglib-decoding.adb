with Ada.Unchecked_Deallocation;

with Jpeglib.Internal.Bit_Streams;
with Jpeglib.Internal.Arithmetic;
with Jpeglib.Internal.Bytes;
with Jpeglib.Internal.Colors;
with Jpeglib.Internal.Frames;
with Jpeglib.Internal.Huffman;
with Jpeglib.Internal.Markers;
with Jpeglib.Internal.Quantization;
with Jpeglib.Internal.Restarts;
with Jpeglib.Internal.Sampling;
with Jpeglib.Internal.Scans;
with Jpeglib.Internal.Segments;
with Jpeglib.Internal.Transforms;

package body Jpeglib.Decoding is
   use type Internal.Frames.Sampling_Factor;
   use type Internal.Sampling.Visible_Sample_Count;
   use type Streams.Byte_Array_Access;

   type Lossless_Sample_Array is array (Component_Index range <>, Positive range <>) of Integer;

   function Parse_Known_Height_DNL
     (Input : not null access Streams.Source'Class;
      Marker_Source : Source_Offset;
      Frame : Internal.Frames.Frame) return Results.Result
   is
      Segment : Internal.Segments.Segment_Reader :=
        Internal.Segments.Open (Input, Internal.Markers.DNL, Marker_Source);
      Outcome : constant Results.Result := Internal.Segments.Status (Segment);
      High : Internal.Bytes.Read_Byte_Result;
      Low : Internal.Bytes.Read_Byte_Result;
      Lines : Natural;
   begin
      if not Results.Succeeded (Outcome) then
         return Outcome;
      elsif Internal.Segments.Descriptor (Segment).Payload_Length /= 2 then
         return
           Results.Failure
             (Errors.Make
                (Errors.Segment_Invalid_Length,
                 (Source => Internal.Segments.Descriptor (Segment).Length_Source,
                  Marker => Internal.Markers.DNL,
                  Detail => Long_Long_Integer (Internal.Segments.Descriptor (Segment).Declared_Length),
                  others => <>)));
      end if;

      High := Internal.Segments.Read_Byte (Segment);
      if not Results.Succeeded (High.Outcome) then
         return High.Outcome;
      end if;

      Low := Internal.Segments.Read_Byte (Segment);
      if not Results.Succeeded (Low.Outcome) then
         return Low.Outcome;
      end if;

      Lines := Natural (High.Value) * 256 + Natural (Low.Value);
      if Lines /= Natural (Internal.Frames.Height (Frame)) then
         return
           Results.Failure
             (Errors.Make
                (Errors.Frame_Invalid_Definition,
                 (Source => High.Source,
                  Marker => Internal.Markers.DNL,
                  Detail => Long_Long_Integer (Lines),
                  others => <>)));
      end if;

      return Results.Success;
   end Parse_Known_Height_DNL;

   function Infer_Color_Model (Frame : Internal.Frames.Frame) return Encoded_Color_Model is
      C1 : Internal.Frames.Frame_Component;
      C2 : Internal.Frames.Frame_Component;
      C3 : Internal.Frames.Frame_Component;
      C4 : Internal.Frames.Frame_Component;
   begin
      case Internal.Frames.Components (Frame) is
         when 1 =>
            return Grayscale;
         when 2 =>
            return Unknown;
         when 3 =>
            C1 := Internal.Frames.Component (Frame, 1);
            C2 := Internal.Frames.Component (Frame, 2);
            C3 := Internal.Frames.Component (Frame, 3);
            if C1.Identifier = 1 and then C2.Identifier = 2 and then C3.Identifier = 3 then
               return YCbCr;
            elsif C1.Identifier = Component_Identifier (Character'Pos ('R'))
              and then C2.Identifier = Component_Identifier (Character'Pos ('G'))
              and then C3.Identifier = Component_Identifier (Character'Pos ('B'))
            then
               return RGB;
            else
               return Unknown;
            end if;
         when 4 =>
            C1 := Internal.Frames.Component (Frame, 1);
            C2 := Internal.Frames.Component (Frame, 2);
            C3 := Internal.Frames.Component (Frame, 3);
            C4 := Internal.Frames.Component (Frame, 4);
            if C1.Identifier = Component_Identifier (Character'Pos ('C'))
              and then C2.Identifier = Component_Identifier (Character'Pos ('M'))
              and then C3.Identifier = Component_Identifier (Character'Pos ('Y'))
              and then C4.Identifier = Component_Identifier (Character'Pos ('K'))
            then
               return CMYK;
            else
               return Unknown;
            end if;
         when others =>
            return Unknown;
      end case;
   end Infer_Color_Model;

   function Infer_Color_Model (Header_Result : Internal.Decoder.Header_Result) return Encoded_Color_Model is
      Frame_Model : constant Encoded_Color_Model := Infer_Color_Model (Header_Result.Frame);
   begin
      if Frame_Model = CMYK
        and then Header_Result.Has_Adobe_APP14_Transform
        and then Header_Result.Adobe_APP14_Transform = 2
      then
         return YCCK;
      end if;

      return Frame_Model;
   end Infer_Color_Model;

   function Lossless_Coefficient_Blocks (Frame : Internal.Frames.Frame) return Block_Count is
      Result : Byte_Count := 0;
      Component : Internal.Frames.Frame_Component;
   begin
      for Index in Component_Index range 1 .. Component_Index (Internal.Frames.Components (Frame)) loop
         Component := Internal.Frames.Component (Frame, Index);
         Result :=
           Result
           + Byte_Count (Component.Component_Width)
           * Byte_Count (Component.Component_Height);
      end loop;

      return Block_Count (Result);
   exception
      when Constraint_Error =>
         return 0;
   end Lossless_Coefficient_Blocks;

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
         if Header.Entropy = Arithmetic or else not Scan_Components_Valid then
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
           (if Header.Entropy = Arithmetic
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
              Parse_Known_Height_DNL (Input, Ending.Source, Header.Frame);
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

   function Compose_Hierarchical_DCT_Continuation
     (Object : in out Decoder;
      Base_Result : Internal.Decoder.Coefficient_Result;
      Blocks : in out Jpeglib.Coefficients.DCT_Block_Array) return Results.Result
   is
      Base_Frame : constant Internal.Frames.Frame := Object.Saved_Header.Frame;
      Continuation_Header : Internal.Decoder.Header_Result := Base_Result.Header;
      Continuation_Result : Internal.Decoder.Coefficient_Result;
      Required : constant Block_Count := Internal.Frames.Total_Blocks (Base_Frame);

      function Continuation_Mode return Frame_Mode is
      begin
         if Base_Result.Ending_Marker = Internal.Markers.SOF5
           or else Base_Result.Ending_Marker = Internal.Markers.SOF13
         then
            return Differential_Sequential_DCT;
         elsif Base_Result.Ending_Marker = Internal.Markers.SOF6
           or else Base_Result.Ending_Marker = Internal.Markers.SOF14
         then
            return Differential_Progressive_DCT;
         else
            return Unsupported_Frame;
         end if;
      end Continuation_Mode;

      function Continuation_Entropy return Entropy_Mode is
        (if Base_Result.Ending_Marker in Internal.Markers.SOF13 | Internal.Markers.SOF14
         then Arithmetic
         else Huffman);

      function Frame_Matches_Base return Boolean is
         Base_Component : Internal.Frames.Frame_Component;
         Diff_Component : Internal.Frames.Frame_Component;
      begin
         if Internal.Frames.Width (Continuation_Header.Frame) /= Internal.Frames.Width (Base_Frame)
           or else Internal.Frames.Height (Continuation_Header.Frame) /= Internal.Frames.Height (Base_Frame)
           or else Internal.Frames.Precision (Continuation_Header.Frame) /= Internal.Frames.Precision (Base_Frame)
           or else Internal.Frames.Components (Continuation_Header.Frame) /= Internal.Frames.Components (Base_Frame)
         then
            return False;
         end if;

         for Index in Component_Index range 1 .. Component_Index (Internal.Frames.Components (Base_Frame)) loop
            Base_Component := Internal.Frames.Component (Base_Frame, Index);
            Diff_Component := Internal.Frames.Component (Continuation_Header.Frame, Index);
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

      function Parse_Continuation_Frame return Results.Result is
         Mode : constant Frame_Mode := Continuation_Mode;
         Segment : Internal.Segments.Segment_Reader :=
           Internal.Segments.Open (Object.Input, Base_Result.Ending_Marker, Base_Result.Ending_Source);
         Outcome : Results.Result := Internal.Segments.Status (Segment);
      begin
         if Mode = Unsupported_Frame then
            return
              Results.Failure
                (Errors.Make
                   (Errors.Unsupported_Feature,
                    (Source => Base_Result.Ending_Source,
                     Marker => Base_Result.Ending_Marker,
                     others => <>)));
         elsif Results.Succeeded (Outcome) then
            Continuation_Header.Frame := Internal.Frames.Parse_SOF (Segment, Mode);
            Outcome := Internal.Frames.Status (Continuation_Header.Frame);
         end if;

         if Results.Succeeded (Outcome) and then not Frame_Matches_Base then
            return
              Results.Failure
                (Errors.Make
                   (Errors.Frame_Invalid_Definition,
                    (Source => Base_Result.Ending_Source,
                     Marker => Base_Result.Ending_Marker,
                     others => <>)));
         end if;

         Continuation_Header.Entropy := Continuation_Entropy;
         Continuation_Header.Saw_SOS := False;
         return Outcome;
      end Parse_Continuation_Frame;

      function Read_Continuation_Scan return Results.Result is
         Marker : Internal.Markers.Marker_Result := Internal.Markers.Read_Next (Object.Input.all);
         DRI : Internal.Restarts.DRI_Result;
      begin
         loop
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Marker.Marker = Internal.Markers.EOI then
               return Results.Failure (Errors.Invalid_State);
            elsif Internal.Markers.Is_Restart (Marker.Marker)
              or else Marker.Marker = Internal.Markers.SOI
              or else Internal.Markers.Is_Frame (Marker.Marker)
            then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Marker_Unexpected,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            elsif Marker.Marker = Internal.Markers.TEM then
               null;
            elsif Marker.Marker = Internal.Markers.DQT then
               declare
                  Segment : Internal.Segments.Segment_Reader :=
                    Internal.Segments.Open (Object.Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Internal.Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                     Outcome :=
                       Internal.Quantization.Parse_DQT
                         (Continuation_Header.Quantization_State, Segment);
                  end if;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            elsif Marker.Marker = Internal.Markers.DHT then
               declare
                  Segment : Internal.Segments.Segment_Reader :=
                    Internal.Segments.Open (Object.Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Internal.Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                     Outcome := Internal.Huffman.Parse_DHT (Continuation_Header.Huffman_State, Segment);
                  end if;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            elsif Marker.Marker = Internal.Markers.DAC then
               declare
                  Segment : Internal.Segments.Segment_Reader :=
                    Internal.Segments.Open (Object.Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Internal.Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                     Outcome :=
                       Internal.Arithmetic.Parse_DAC
                         (Continuation_Header.Arithmetic_State, Segment);
                  end if;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            elsif Marker.Marker = Internal.Markers.DRI then
               declare
                  Segment : Internal.Segments.Segment_Reader :=
                    Internal.Segments.Open (Object.Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Internal.Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                     DRI := Internal.Restarts.Read_DRI (Segment);
                     Outcome := DRI.Outcome;
                     Continuation_Header.Restart := DRI.Interval;
                  end if;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            elsif Marker.Marker = Internal.Markers.SOS then
               declare
                  Segment : Internal.Segments.Segment_Reader :=
                    Internal.Segments.Open (Object.Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Internal.Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                      Continuation_Header.Scan :=
                        Internal.Scans.Parse_SOS
                          (Continuation_Header.Frame,
                           Segment,
                          Progressive =>
                            Internal.Frames.Mode (Continuation_Header.Frame)
                              in Progressive_DCT | Differential_Progressive_DCT);
                     Outcome := Internal.Scans.Status (Continuation_Header.Scan);
                  end if;
                  Continuation_Header.Saw_SOS := Results.Succeeded (Outcome);
                  return Outcome;
               end;
            elsif Internal.Markers.Is_Reserved (Marker.Marker) then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Unsupported_Feature,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            elsif Internal.Markers.Has_Length (Marker.Marker) then
               declare
                  Segment : Internal.Segments.Segment_Reader :=
                    Internal.Segments.Open (Object.Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Internal.Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                     Outcome := Internal.Segments.Skip_Remaining (Segment);
                  end if;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            else
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Marker_Unexpected,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            end if;

            Marker := Internal.Markers.Read_Next (Object.Input.all);
         end loop;
      end Read_Continuation_Scan;
   begin
      if not Object.Saved_Header.Hierarchical
        or else Base_Result.Ending_Marker not in
          Internal.Markers.SOF5 | Internal.Markers.SOF6 |
          Internal.Markers.SOF13 | Internal.Markers.SOF14
      then
         return Results.Success;
      elsif Required = 0 or else Block_Count (Blocks'Length) < Required then
         return
           Results.Failure
             (Errors.Make
                (Errors.Output_Limit_Exceeded,
                 (Detail => Long_Long_Integer (Required), others => <>)));
      end if;

      declare
         Continuation_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Natural (Required)) :=
           [others => [others => 0]];
         Outcome : Results.Result := Parse_Continuation_Frame;
      begin
         if Results.Succeeded (Outcome) then
            Outcome := Read_Continuation_Scan;
         end if;

         if Results.Succeeded (Outcome) then
            if Internal.Frames.Mode (Continuation_Header.Frame) in
              Progressive_DCT | Differential_Progressive_DCT
            then
               Continuation_Result :=
                 Internal.Decoder.Decode_Progressive_Coefficients
                   (Continuation_Header, Object.Input, Continuation_Blocks);
            elsif Continuation_Header.Entropy = Arithmetic then
               Continuation_Result :=
                 Internal.Decoder.Decode_Arithmetic_Coefficients
                   (Continuation_Header, Object.Input, Continuation_Blocks);
            else
               Continuation_Result :=
                 Internal.Decoder.Decode_Baseline_Coefficients
                   (Continuation_Header, Object.Input, Continuation_Blocks);
            end if;
            Outcome := Continuation_Result.Outcome;
         end if;

         if not Results.Succeeded (Outcome) then
            return Outcome;
         elsif Continuation_Result.Blocks_Decoded /= Required then
            return Results.Failure (Errors.Invalid_State);
         end if;

         for Block_Index in 1 .. Natural (Required) loop
            for Coefficient in Jpeglib.Coefficient_Index loop
               declare
                  Sum : constant Long_Long_Integer :=
                    Long_Long_Integer (Blocks (Block_Index) (Coefficient))
                    + Long_Long_Integer (Continuation_Blocks (Block_Index) (Coefficient));
               begin
                  if Sum not in
                    Long_Long_Integer (Jpeglib.Coefficients.Quantized_Coefficient'First)
                      .. Long_Long_Integer (Jpeglib.Coefficients.Quantized_Coefficient'Last)
                  then
                     return
                       Results.Failure
                         (Errors.Make
                            (Errors.Coefficient_Invalid_Encoding,
                             (Detail => Sum, others => <>)));
                  end if;

                  Blocks (Block_Index) (Coefficient) :=
                    Jpeglib.Coefficients.Quantized_Coefficient (Integer (Sum));
               end;
            end loop;
         end loop;

         Object.Saved_Header := Base_Result.Header;
         Object.Saved_Header.Saw_SOS := False;
         return Results.Success;
      end;
   end Compose_Hierarchical_DCT_Continuation;

   function To_Image_Info (Header_Result : Internal.Decoder.Header_Result) return Image_Info is
   begin
      return
        (Width => Internal.Frames.Width (Header_Result.Frame),
         Height => Internal.Frames.Height (Header_Result.Frame),
         Height_Defined => Internal.Frames.Height_Defined (Header_Result.Frame),
         Precision => Internal.Frames.Precision (Header_Result.Frame),
         Mode => Internal.Frames.Mode (Header_Result.Frame),
         Entropy => Header_Result.Entropy,
         Components => Internal.Frames.Components (Header_Result.Frame),
         Progressive => Internal.Frames.Mode (Header_Result.Frame) in Progressive_DCT | Differential_Progressive_DCT,
         Hierarchical => Header_Result.Hierarchical,
         Lossless_Predictor =>
           (if Internal.Frames.Mode (Header_Result.Frame) in Lossless | Differential_Lossless
            then Lossless_Predictor_Selection (Internal.Scans.Spectral_Start (Header_Result.Scan))
            else 1),
         Lossless_Point_Transform =>
           (if Internal.Frames.Mode (Header_Result.Frame) in Lossless | Differential_Lossless
            then Internal.Scans.Successive_Low (Header_Result.Scan)
            else 0),
         Color_Model => Infer_Color_Model (Header_Result),
         Restart => Header_Result.Restart,
         Coefficient_Blocks =>
           (if not Internal.Frames.Height_Defined (Header_Result.Frame)
            then 0
            elsif Internal.Frames.Mode (Header_Result.Frame) in Lossless | Differential_Lossless
            then Lossless_Coefficient_Blocks (Header_Result.Frame)
            else Internal.Frames.Total_Blocks (Header_Result.Frame)),
         Metadata_Segments => Header_Result.Metadata_Segments,
         Metadata_Bytes => Header_Result.Metadata_Bytes,
         Retained_Metadata_Bytes => Header_Result.Retained_Metadata_Bytes,
         ICC_Profile_Bytes => Header_Result.ICC_Profile_Bytes,
         ICC_Profile_Fragments => Header_Result.ICC_Profile_Fragments,
         ICC_Profile_Fragment_Count => Header_Result.ICC_Profile_Fragment_Count,
         Has_Exif_Orientation => Header_Result.Has_Exif_Orientation,
         Exif_Orientation => Header_Result.Exif_Orientation,
         Retained_Metadata_Summaries => Header_Result.Retained_Metadata_Summaries,
         Metadata_Summaries => Header_Result.Metadata_Summaries);
   end To_Image_Info;

   procedure Fail (Object : in out Decoder; Code : Errors.Error_Code) is
   begin
      if not Errors.Is_Fatal (Object.First_Error) then
         Object.First_Error := Errors.Make (Code);
      end if;
      Object.Current_State := Failed;
   end Fail;

   procedure Fail_With (Object : in out Decoder; Error : Errors.Error) is
   begin
      if not Errors.Is_Fatal (Object.First_Error) then
         Object.First_Error := Error;
      end if;
      Object.Current_State := Failed;
   end Fail_With;

   procedure Initialize
     (Object : in out Decoder;
      Input : not null access Streams.Source'Class;
      Decode_Options : Options := (others => <>);
      Decode_Limits : Limits.Limit_Set := Limits.Default_Limits) is
   begin
      Object.Input := Input.all'Unchecked_Access;
      Object.Decode_Options := Decode_Options;
      Object.Decode_Limits := Decode_Limits;
      Object.First_Error := Errors.Make (Errors.No_Error);
      Object.Header_Info := (others => <>);
      Object.Saved_Header := (others => <>);
      Object.Current_State := Initialized;
   end Initialize;

   procedure Reset (Object : in out Decoder; Input : not null access Streams.Source'Class) is
   begin
      Object.Input := Input.all'Unchecked_Access;
      Object.First_Error := Errors.Make (Errors.No_Error);
      Object.Header_Info := (others => <>);
      Object.Saved_Header := (others => <>);
      Object.Current_State := Initialized;
   end Reset;

   function State (Object : Decoder) return Decoder_State is
   begin
      return Object.Current_State;
   end State;

   function Read_Header (Object : in out Decoder) return Results.Result is
      Header_Result : Internal.Decoder.Header_Result;
   begin
      if Object.Current_State not in Initialized | Header_Ready then
         Fail (Object, Errors.Invalid_State);
         return Results.Failure (Object.First_Error);
      end if;

      Object.Current_State := Header_Reading;
      Header_Result :=
        Internal.Decoder.Read_Header
          (Object.Input,
           Object.Decode_Options.Metadata,
           Object.Decode_Options.Selected_Metadata,
           Object.Decode_Options.Metadata_Callback,
           Object.Decode_Options.Metadata_Buffer,
           Object.Decode_Limits);

      if not Results.Succeeded (Header_Result.Outcome) then
         if not Errors.Is_Fatal (Object.First_Error) then
            Object.First_Error := Header_Result.Outcome.First_Error;
         end if;
         Object.Current_State := Failed;
         return Results.Failure (Object.First_Error);
      end if;

      Object.Header_Info := To_Image_Info (Header_Result);
      Object.Saved_Header := Header_Result;
      Object.Current_State := Header_Ready;
      return Results.Success;
   end Read_Header;

   function Header (Object : Decoder) return Image_Info is
   begin
      return Object.Header_Info;
   end Header;

   function Decode_Coefficients
     (Object : in out Decoder;
      Blocks : in out Jpeglib.Coefficients.DCT_Block_Array;
      Blocks_Decoded : out Block_Count) return Results.Result
   is
      Result : Internal.Decoder.Coefficient_Result;
      Header_Outcome : Results.Result;
      Height_Provisionally_Defined : Boolean := False;

      function Missing_DNL_Error (Marker : Marker_Code) return Errors.Error is
        (Errors.Make
           (Errors.Frame_Invalid_Definition,
            (Marker => Marker, others => <>)));

      function Define_Pending_Coefficient_Height return Results.Result is
         Frame : Internal.Frames.Frame renames Object.Saved_Header.Frame;
         Block_Total : constant Block_Count := Block_Count (Blocks'Length);
         Blocks_Per_Row : Block_Count := 0;
         Row_Count : Block_Count;
         Height : Block_Count;
         Component : Internal.Frames.Frame_Component;
      begin
         if Block_Total = 0 then
            return Results.Failure (Errors.Unsupported_Feature);
         elsif Internal.Frames.Mode (Frame) in Lossless | Differential_Lossless then
            Blocks_Per_Row :=
              Block_Count (Internal.Frames.Width (Frame))
              * Block_Count (Internal.Frames.Components (Frame));
         else
            for Index in Component_Index range 1 .. Component_Index (Internal.Frames.Components (Frame)) loop
               Component := Internal.Frames.Component (Frame, Index);
               Blocks_Per_Row :=
                 Blocks_Per_Row
                 + Block_Count (Internal.Frames.MCU_Columns (Frame))
                   * Block_Count (Component.Horizontal_Sampling)
                   * Block_Count (Component.Vertical_Sampling);
            end loop;

         end if;

         if Blocks_Per_Row = 0 or else Block_Total mod Blocks_Per_Row /= 0 then
            return Results.Failure (Errors.Unsupported_Feature);
         end if;

         Row_Count := Block_Total / Blocks_Per_Row;
         if Row_Count = 0 then
            return Results.Failure (Errors.Unsupported_Feature);
         elsif Internal.Frames.Mode (Frame) in Lossless | Differential_Lossless then
            Height := Row_Count;
         else
            Height :=
              Row_Count
              * Block_Count (Internal.Frames.Maximum_Vertical_Sampling (Frame))
              * 8;
         end if;

         if Height > Block_Count (Image_Height'Last) then
            return Results.Failure (Errors.Unsupported_Feature);
         end if;

         declare
            Outcome : constant Results.Result :=
              Internal.Frames.Define_Height (Frame, Image_Height (Height));
         begin
            if Results.Succeeded (Outcome) then
               Height_Provisionally_Defined := True;
            end if;
            return Outcome;
         end;
      exception
         when Constraint_Error =>
            return Results.Failure (Errors.Unsupported_Feature);
      end Define_Pending_Coefficient_Height;

      function Decode_Lossless_Coefficients return Results.Result is
         use type Internal.Bit_Streams.Entropy_Bits;
         use type Internal.Bit_Streams.Entropy_Byte_Kind;
         Header : Internal.Decoder.Header_Result renames Object.Saved_Header;
         Required : constant Block_Count := Lossless_Coefficient_Blocks (Header.Frame);
         Component_Total : constant Component_Index := Component_Index (Internal.Frames.Components (Header.Frame));
         type Huffman_Table_Array is array (Component_Index range <>) of Internal.Huffman.Compiled_Huffman;
         type Context_Array is array (Component_Index range <>) of Internal.Arithmetic.DC_Context_Index;
         type DC_Bin_Set_Array is array (Component_Index range <>) of
           Internal.Arithmetic.Probability_Bin_Array (0 .. 63);
         type Component_Decoded_Array is array (Component_Index range <>) of Boolean;
         type Component_Sample_Count_Array is array (Component_Index range <>) of Natural;

         function Component_Sample_Count (Index : Component_Index) return Natural is
            Item : constant Internal.Frames.Frame_Component :=
              Internal.Frames.Component (Header.Frame, Index);
         begin
            return Natural (Item.Component_Width) * Natural (Item.Component_Height);
         end Component_Sample_Count;

         function Max_Component_Sample_Count return Positive is
            Result : Natural := 1;
         begin
            for Index in Component_Index range 1 .. Component_Total loop
               Result := Natural'Max (Result, Component_Sample_Count (Index));
            end loop;

            return Positive (Result);
         end Max_Component_Sample_Count;

         Samples : aliased Lossless_Sample_Array :=
           [1 .. Component_Total => [1 .. Max_Component_Sample_Count => 0]];
         Component_Decoded : Component_Decoded_Array (1 .. Component_Total) := [others => False];
         Component : Internal.Frames.Frame_Component;
         Next_Block : Positive := Blocks'First;
         Scan_Width : Natural := 0;
         Scan_Height : Natural := 0;
         Scan_Total : Natural := 0;

         function Initial_Predictor return Integer is
         begin
            return
              2 **
                (Natural (Internal.Frames.Precision (Header.Frame))
                 - Natural (Internal.Scans.Successive_Low (Header.Scan))
                 - 1);
         end Initial_Predictor;

         function Stored (Component_Index_Value : Component_Index; Column, Row : Natural) return Integer is
           (Samples
              (Component_Index_Value,
               Samples'First (2)
               + Row * Natural
                   (Internal.Frames.Component (Header.Frame, Component_Index_Value).Component_Width)
               + Column));

         function Predicted
           (Component_Index_Value : Component_Index;
            Column : Natural;
            Row : Natural;
            Decoded : Natural;
            Restart_Base : Natural) return Integer
         is
            Ra : Integer;
            Rb : Integer;
            Rc : Integer;
         begin
            if Decoded = Restart_Base then
               return Initial_Predictor;
            elsif Column = 0 then
               return Stored (Component_Index_Value, Column, Row - 1);
            elsif Row = 0 then
               return Stored (Component_Index_Value, Column - 1, Row);
            end if;

            Ra := Stored (Component_Index_Value, Column - 1, Row);
            Rb := Stored (Component_Index_Value, Column, Row - 1);
            Rc := Stored (Component_Index_Value, Column - 1, Row - 1);

            case Internal.Scans.Spectral_Start (Header.Scan) is
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
               when others =>
                  return Initial_Predictor;
            end case;
         end Predicted;

         function Store_Sample
           (Component_Index_Value : Component_Index;
            Column : Natural;
            Row : Natural;
            Sample : Integer) return Results.Result
         is
            Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
         begin
            if Sample not in 0 .. Max_Sample then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Coefficient_Invalid_Encoding,
                       (Detail => Long_Long_Integer (Sample), others => <>)));
            end if;

            Samples
              (Component_Index_Value,
               Samples'First (2)
               + Row * Natural
                   (Internal.Frames.Component (Header.Frame, Component_Index_Value).Component_Width)
               + Column) := Sample;
            return Results.Success;
         end Store_Sample;

         function Incomplete_Scan_Data return Results.Result is
         begin
            for Index in Component_Index range 1 .. Component_Total loop
               if not Component_Decoded (Index) then
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
         end Incomplete_Scan_Data;

         function All_Components_Decoded return Boolean is
         begin
            for Index in Component_Index range 1 .. Component_Total loop
               if not Component_Decoded (Index) then
                  return False;
               end if;
            end loop;

            return True;
         end All_Components_Decoded;

         procedure Mark_Current_Scan_Decoded is
            Scan_Component : Internal.Scans.Scan_Component;
         begin
            for Index in Component_Index range 1 .. Component_Index (Internal.Scans.Components (Header.Scan)) loop
               Scan_Component := Internal.Scans.Component (Header.Scan, Index);
               Component_Decoded (Scan_Component.Frame_Component) := True;
            end loop;
         end Mark_Current_Scan_Decoded;

         function Validate_Lossless_Coefficient_Scan return Results.Result is
            Scan_Component : Internal.Scans.Scan_Component;
            Seen_In_Scan : Component_Decoded_Array (1 .. Component_Total) := [others => False];
            First_Component : Boolean := True;
            Component_Width : Natural;
            Component_Height : Natural;
         begin
            Scan_Width := 0;
            Scan_Height := 0;
            Scan_Total := 0;

            for Index in Component_Index range 1 .. Component_Index (Internal.Scans.Components (Header.Scan)) loop
               Scan_Component := Internal.Scans.Component (Header.Scan, Index);
               if Scan_Component.Frame_Component not in 1 .. Component_Total
                 or else Seen_In_Scan (Scan_Component.Frame_Component)
                 or else Component_Decoded (Scan_Component.Frame_Component)
               then
                  return
                    Results.Failure
                      (Errors.Make
                         (Errors.Scan_Invalid_Definition,
                          (Frame_Component => Scan_Component.Frame_Component,
                           Detail => Long_Long_Integer (Scan_Component.Frame_Component),
                           others => <>)));
               end if;

               Seen_In_Scan (Scan_Component.Frame_Component) := True;
               Component := Internal.Frames.Component (Header.Frame, Scan_Component.Frame_Component);
               Component_Width := Natural (Component.Component_Width);
               Component_Height := Natural (Component.Component_Height);
               if Component_Width = 0 or else Component_Height = 0
               then
                  return Results.Failure (Errors.Unsupported_Feature);
               elsif First_Component then
                  First_Component := False;
               end if;
            end loop;

            if First_Component then
               return Results.Failure (Errors.Unsupported_Feature);
            end if;

            Scan_Width :=
              (Natural (Internal.Frames.Width (Header.Frame))
               + Natural (Internal.Frames.Maximum_Horizontal_Sampling (Header.Frame))
               - 1)
              / Natural (Internal.Frames.Maximum_Horizontal_Sampling (Header.Frame));
            Scan_Height :=
              (Natural (Internal.Frames.Height (Header.Frame))
               + Natural (Internal.Frames.Maximum_Vertical_Sampling (Header.Frame))
               - 1)
              / Natural (Internal.Frames.Maximum_Vertical_Sampling (Header.Frame));
            Scan_Total := Scan_Width * Scan_Height;
            if Scan_Total = 0 then
               return Results.Failure (Errors.Unsupported_Feature);
            end if;

            return Results.Success;
         end Validate_Lossless_Coefficient_Scan;

         procedure Store_Blocks is
         begin
            for Index in Component_Index range 1 .. Component_Total loop
               for Offset in Natural range 0 .. Component_Sample_Count (Index) - 1 loop
                  Blocks (Next_Block) := [others => 0];
                  Blocks (Next_Block) (0) :=
                    Jpeglib.Coefficients.Quantized_Coefficient
                      (Samples (Index, Samples'First (2) + Offset));
                  Next_Block := Next_Block + 1;
               end loop;
            end loop;
         end Store_Blocks;

         function Check_Ending (Ending : Internal.Bit_Streams.Entropy_Read_Result) return Results.Result is
         begin
            if Results.Succeeded (Ending.Outcome)
              and then Height_Provisionally_Defined
              and then Ending.Marker /= Internal.Markers.DNL
            then
               return Results.Failure (Missing_DNL_Error (Ending.Marker));
            end if;

            return Decode_Hierarchical_Lossless_Continuation
              (Header, Object.Input, Ending, Samples'Access);
         end Check_Ending;

         function Parse_Following_Lossless_Scan
           (Ending : Internal.Bit_Streams.Entropy_Read_Result) return Results.Result
         is
            Marker : Internal.Markers.Marker_Result :=
              (Outcome => Ending.Outcome,
               Source => Ending.Source,
               Marker => Ending.Marker);
         begin
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Ending.Kind /= Internal.Bit_Streams.Scan_Ending_Marker then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Marker_Unexpected,
                       (Source => Ending.Source, Marker => Ending.Marker, others => <>)));
            end if;

            loop
               if Marker.Marker = Internal.Markers.EOI then
                  return Incomplete_Scan_Data;
               elsif Marker.Marker = Internal.Markers.DNL then
                  declare
                     Outcome : constant Results.Result :=
                       Parse_Known_Height_DNL (Object.Input, Marker.Source, Header.Frame);
                  begin
                     if not Results.Succeeded (Outcome) then
                        return Outcome;
                     end if;
                  end;
               elsif Marker.Marker = Internal.Markers.DHT then
                  declare
                     Segment : Internal.Segments.Segment_Reader :=
                       Internal.Segments.Open (Object.Input, Marker.Marker, Marker.Source);
                     Outcome : Results.Result := Internal.Segments.Status (Segment);
                  begin
                     if Results.Succeeded (Outcome) then
                        Outcome := Internal.Huffman.Parse_DHT (Header.Huffman_State, Segment);
                     end if;
                     if not Results.Succeeded (Outcome) then
                        return Outcome;
                     end if;
                  end;
               elsif Marker.Marker = Internal.Markers.DAC then
                  declare
                     Segment : Internal.Segments.Segment_Reader :=
                       Internal.Segments.Open (Object.Input, Marker.Marker, Marker.Source);
                     Outcome : Results.Result := Internal.Segments.Status (Segment);
                  begin
                     if Results.Succeeded (Outcome) then
                        Outcome := Internal.Arithmetic.Parse_DAC (Header.Arithmetic_State, Segment);
                     end if;
                     if not Results.Succeeded (Outcome) then
                        return Outcome;
                     end if;
                  end;
               elsif Marker.Marker = Internal.Markers.DRI then
                  declare
                     Segment : Internal.Segments.Segment_Reader :=
                       Internal.Segments.Open (Object.Input, Marker.Marker, Marker.Source);
                     DRI : Internal.Restarts.DRI_Result;
                     Outcome : Results.Result := Internal.Segments.Status (Segment);
                  begin
                     if Results.Succeeded (Outcome) then
                        DRI := Internal.Restarts.Read_DRI (Segment);
                        Outcome := DRI.Outcome;
                        Header.Restart := DRI.Interval;
                     end if;
                     if not Results.Succeeded (Outcome) then
                        return Outcome;
                     end if;
                  end;
               elsif Marker.Marker = Internal.Markers.TEM then
                  null;
               elsif Marker.Marker = Internal.Markers.SOS then
                  declare
                     Segment : Internal.Segments.Segment_Reader :=
                       Internal.Segments.Open (Object.Input, Marker.Marker, Marker.Source);
                     Outcome : Results.Result := Internal.Segments.Status (Segment);
                  begin
                     if Results.Succeeded (Outcome) then
                        Header.Scan :=
                          Internal.Scans.Parse_SOS
                            (Header.Frame,
                             Segment,
                             Progressive => False,
                             Lossless => True);
                        Outcome := Internal.Scans.Status (Header.Scan);
                     end if;
                     return Outcome;
                  end;
               elsif Internal.Markers.Is_Reserved (Marker.Marker)
                 or else Internal.Markers.Is_Frame (Marker.Marker)
               then
                  return
                    Results.Failure
                      (Errors.Make
                         (Errors.Unsupported_Feature,
                          (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
               elsif Internal.Markers.Has_Length (Marker.Marker) then
                  declare
                     Segment : Internal.Segments.Segment_Reader :=
                       Internal.Segments.Open (Object.Input, Marker.Marker, Marker.Source);
                     Outcome : Results.Result := Internal.Segments.Status (Segment);
                  begin
                     if Results.Succeeded (Outcome) then
                        Outcome := Internal.Segments.Skip_Remaining (Segment);
                     end if;
                     if not Results.Succeeded (Outcome) then
                        return Outcome;
                     end if;
                  end;
               else
                  return
                    Results.Failure
                      (Errors.Make
                         (Errors.Marker_Unexpected,
                          (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
               end if;

               Marker := Internal.Markers.Read_Next (Object.Input.all);
               if not Results.Succeeded (Marker.Outcome) then
                  return Marker.Outcome;
               end if;
            end loop;
         end Parse_Following_Lossless_Scan;

         function Decode_Huffman_Lossless_Coefficient_Scan
           (Ending : out Internal.Bit_Streams.Entropy_Read_Result) return Results.Result
         is
            Entropy : aliased Internal.Bit_Streams.Entropy_Reader (Object.Input);
            Bits : Internal.Bit_Streams.Bit_Reader (Entropy'Access);
            Tables : Huffman_Table_Array (1 .. Component_Total);
            Compile : Internal.Huffman.Compile_Result;
            Symbol : Internal.Huffman.Decode_Result;
            Extended : Internal.Bit_Streams.Sign_Extend_Result;
            Restart_State : Internal.Restarts.Restart_State;
            Restart_Bases : Component_Sample_Count_Array (1 .. Component_Total) := [others => 0];
            Decoded_Samples : Component_Sample_Count_Array (1 .. Component_Total) := [others => 0];
            Decoded_MCUs : Natural := 0;

            function Read_Category_Bits
              (Category : Internal.Bit_Streams.Entropy_Category) return Internal.Bit_Streams.Sign_Extend_Result
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

            function Accept_Restart_When_Due return Results.Result is
               Marker : Internal.Bit_Streams.Entropy_Read_Result;
               Outcome : Results.Result;
            begin
               if Header.Restart = 0
                 or else Internal.Restarts.MCUs_Until_Restart (Restart_State) /= 0
                 or else Decoded_MCUs = Scan_Total
               then
                  return Results.Success;
               end if;

               Internal.Bit_Streams.Byte_Align (Bits);
               Marker := Internal.Bit_Streams.Read_Byte (Entropy);
               if not Results.Succeeded (Marker.Outcome) then
                  return Marker.Outcome;
               elsif Marker.Kind /= Internal.Bit_Streams.Restart_Marker then
                  return
                    Results.Failure
                      (Errors.Make
                         (Errors.Restart_Invalid_State,
                          (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
               end if;

               Outcome := Internal.Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
               if Results.Succeeded (Outcome) then
                  Restart_Bases := Decoded_Samples;
               end if;
               return Outcome;
            end Accept_Restart_When_Due;
         begin
            Ending := (Outcome => Results.Success,
                       Kind => Internal.Bit_Streams.Scan_Ending_Marker,
                       Source => 0,
                       Value => 0,
                       Marker => Internal.Markers.EOI);

            for Index in Component_Index range 1 .. Component_Index (Internal.Scans.Components (Header.Scan)) loop
               declare
                  Scan_Component : constant Internal.Scans.Scan_Component :=
                    Internal.Scans.Component (Header.Scan, Index);
               begin
                  if not Internal.Huffman.Has_Table
                    (Header.Huffman_State, Internal.Huffman.DC, Scan_Component.DC_Table)
                  then
                     return
                       Results.Failure
                         (Errors.Make
                            (Errors.Table_Invalid_Definition,
                             (Frame_Component => Scan_Component.Frame_Component,
                              Detail => Long_Long_Integer (Scan_Component.DC_Table),
                              others => <>)));
                  end if;

                  Compile :=
                    Internal.Huffman.Compile
                      (Internal.Huffman.Definition
                         (Header.Huffman_State, Internal.Huffman.DC, Scan_Component.DC_Table));
                  if not Results.Succeeded (Compile.Outcome) then
                     return Compile.Outcome;
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
                                       return Symbol.Outcome;
                                    elsif Symbol.Symbol > 16 then
                                       return
                                         Results.Failure
                                           (Errors.Make
                                              (Errors.Coefficient_Invalid_Encoding,
                                               (Source => Symbol.Source,
                                                Detail => Long_Long_Integer (Symbol.Symbol),
                                                others => <>)));
                                    end if;

                                    Extended :=
                                      Read_Category_Bits
                                        (Internal.Bit_Streams.Entropy_Category (Symbol.Symbol));
                                    if not Results.Succeeded (Extended.Outcome) then
                                       return Extended.Outcome;
                                    end if;

                                    declare
                                       Store_Outcome : constant Results.Result :=
                                         Store_Sample
                                           (Scan_Component.Frame_Component,
                                            Column,
                                            Row,
                                            Predicted
                                              (Scan_Component.Frame_Component,
                                               Column,
                                               Row,
                                               Decoded_Samples (Scan_Component.Frame_Component),
                                               Restart_Bases (Scan_Component.Frame_Component))
                                            + Integer (Extended.Value));
                                    begin
                                       if not Results.Succeeded (Store_Outcome) then
                                          return Store_Outcome;
                                       end if;
                                    end;

                                    Decoded_Samples (Scan_Component.Frame_Component) :=
                                      Decoded_Samples (Scan_Component.Frame_Component) + 1;
                                 end if;
                              end;
                           end loop;
                        end loop;
                     end;
                  end loop;

                  Decoded_MCUs := Decoded_MCUs + 1;
                  declare
                     Outcome : Results.Result := Internal.Restarts.Advance_MCU (Restart_State);
                  begin
                     if not Results.Succeeded (Outcome) then
                        return Outcome;
                     end if;

                     Outcome := Accept_Restart_When_Due;
                     if not Results.Succeeded (Outcome) then
                        return Outcome;
                     end if;
                  end;
               end loop;
            end loop;

            Internal.Bit_Streams.Byte_Align (Bits);
            Ending := Internal.Bit_Streams.Read_Byte (Entropy);
            return Ending.Outcome;
         end Decode_Huffman_Lossless_Coefficient_Scan;

         function Decode_Arithmetic_Lossless_Coefficient_Scan
           (Ending : out Internal.Bit_Streams.Entropy_Read_Result) return Results.Result
         is
            Entropy : aliased Internal.Bit_Streams.Entropy_Reader (Object.Input);
            Arithmetic_Decoder : Internal.Arithmetic.Decoder (Entropy'Access);
            DC_Bins : DC_Bin_Set_Array (1 .. Component_Total) :=
              [others => [others => Internal.Arithmetic.Initial_Probability_Bin]];
            DC_Contexts : Context_Array (1 .. Component_Total) := [others => 0];
            DC : Internal.Arithmetic.DC_Result;
            Restart_State : Internal.Restarts.Restart_State;
            Restart_Bases : Component_Sample_Count_Array (1 .. Component_Total) := [others => 0];
            Decoded_Samples : Component_Sample_Count_Array (1 .. Component_Total) := [others => 0];
            Decoded_MCUs : Natural := 0;

            function Accept_Restart_When_Due return Results.Result is
               Marker : Internal.Bit_Streams.Entropy_Read_Result;
               Outcome : Results.Result;
            begin
               if Header.Restart = 0
                 or else Internal.Restarts.MCUs_Until_Restart (Restart_State) /= 0
                 or else Decoded_MCUs = Scan_Total
               then
                  return Results.Success;
               end if;

               Marker := Internal.Bit_Streams.Read_Byte (Entropy);
               if not Results.Succeeded (Marker.Outcome) then
                  return Marker.Outcome;
               elsif Marker.Kind /= Internal.Bit_Streams.Restart_Marker then
                  return
                    Results.Failure
                      (Errors.Make
                         (Errors.Restart_Invalid_State,
                          (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
               end if;

               Outcome := Internal.Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
               if Results.Succeeded (Outcome) then
                  Restart_Bases := Decoded_Samples;
                  Internal.Arithmetic.Reset (Arithmetic_Decoder);
                  DC_Bins := [others => [others => Internal.Arithmetic.Initial_Probability_Bin]];
                  DC_Contexts := [others => 0];
               end if;
               return Outcome;
            end Accept_Restart_When_Due;
         begin
            Ending := (Outcome => Results.Success,
                       Kind => Internal.Bit_Streams.Scan_Ending_Marker,
                       Source => 0,
                       Value => 0,
                       Marker => Internal.Markers.EOI);

            for Index in Component_Index range 1 .. Component_Index (Internal.Scans.Components (Header.Scan)) loop
               declare
                  Scan_Component : constant Internal.Scans.Scan_Component :=
                    Internal.Scans.Component (Header.Scan, Index);
               begin
                  if not Internal.Arithmetic.Has_Table
                    (Header.Arithmetic_State, Internal.Arithmetic.DC, Scan_Component.DC_Table)
                  then
                     return
                       Results.Failure
                         (Errors.Make
                            (Errors.Table_Invalid_Definition,
                             (Frame_Component => Scan_Component.Frame_Component,
                              Detail => Long_Long_Integer (Scan_Component.DC_Table),
                              others => <>)));
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
                                       return DC.Outcome;
                                    end if;

                                    declare
                                       Outcome : constant Results.Result :=
                                         Store_Sample
                                           (Scan_Component.Frame_Component,
                                            Column,
                                            Row,
                                            Predicted
                                              (Scan_Component.Frame_Component,
                                               Column,
                                               Row,
                                               Decoded_Samples (Scan_Component.Frame_Component),
                                               Restart_Bases (Scan_Component.Frame_Component))
                                            + Integer (DC.Difference));
                                    begin
                                       if not Results.Succeeded (Outcome) then
                                          return Outcome;
                                       end if;
                                    end;

                                    Decoded_Samples (Scan_Component.Frame_Component) :=
                                      Decoded_Samples (Scan_Component.Frame_Component) + 1;
                                 end if;
                              end;
                           end loop;
                        end loop;
                     end;
                  end loop;

                  Decoded_MCUs := Decoded_MCUs + 1;
                  declare
                     Outcome : Results.Result := Internal.Restarts.Advance_MCU (Restart_State);
                  begin
                     if not Results.Succeeded (Outcome) then
                        return Outcome;
                     end if;

                     Outcome := Accept_Restart_When_Due;
                     if not Results.Succeeded (Outcome) then
                        return Outcome;
                     end if;
                  end;
               end loop;
            end loop;

            Ending := Internal.Bit_Streams.Read_Byte (Entropy);
            return Ending.Outcome;
         end Decode_Arithmetic_Lossless_Coefficient_Scan;
      begin
         if Required = 0 or else Block_Count (Blocks'Length) < Required then
            Fail_With
              (Object,
               Errors.Make
                 (Errors.Output_Limit_Exceeded,
                  (Detail => Long_Long_Integer (Required), others => <>)));
            return Results.Failure (Object.First_Error);
         end if;

         declare
            Outcome : Results.Result := Results.Success;
            Ending : Internal.Bit_Streams.Entropy_Read_Result;
         begin
            loop
               Outcome := Validate_Lossless_Coefficient_Scan;
               if Results.Succeeded (Outcome) then
                  if Header.Entropy = Arithmetic then
                     Outcome := Decode_Arithmetic_Lossless_Coefficient_Scan (Ending);
                  else
                     Outcome := Decode_Huffman_Lossless_Coefficient_Scan (Ending);
                  end if;
               end if;

               if Results.Succeeded (Outcome) then
                  Mark_Current_Scan_Decoded;
                  if All_Components_Decoded then
                     Outcome := Check_Ending (Ending);
                  else
                     Outcome := Parse_Following_Lossless_Scan (Ending);
                  end if;
               end if;

               exit when not Results.Succeeded (Outcome) or else All_Components_Decoded;
            end loop;

            if not Results.Succeeded (Outcome) then
               Fail_With (Object, Outcome.First_Error);
               return Results.Failure (Object.First_Error);
            end if;
         end;

         Store_Blocks;
         Object.Saved_Header.Saw_SOS := False;
         Object.Header_Info := To_Image_Info (Object.Saved_Header);
         Object.Current_State := Completed;
         Blocks_Decoded := Required;
         return Results.Success;
      exception
         when Constraint_Error =>
            Fail (Object, Errors.Internal_Invariant_Failed);
            return Results.Failure (Object.First_Error);
      end Decode_Lossless_Coefficients;

   begin
      Blocks_Decoded := 0;
      if Object.Current_State not in Initialized | Header_Ready then
         Fail (Object, Errors.Invalid_State);
         return Results.Failure (Object.First_Error);
      end if;

      if Object.Current_State = Initialized then
         Header_Outcome := Read_Header (Object);
         if not Results.Succeeded (Header_Outcome) then
            return Header_Outcome;
         end if;
      end if;

      if Internal.Frames.Mode (Object.Saved_Header.Frame) in Lossless | Differential_Lossless then
         if not Internal.Frames.Height_Defined (Object.Saved_Header.Frame) then
            declare
               Outcome : constant Results.Result := Define_Pending_Coefficient_Height;
            begin
               if not Results.Succeeded (Outcome) then
                  Fail_With (Object, Outcome.First_Error);
                  return Results.Failure (Object.First_Error);
               end if;
            end;
         end if;
         return Decode_Lossless_Coefficients;
      end if;

      if not Internal.Frames.Height_Defined (Object.Saved_Header.Frame) then
         declare
            Outcome : constant Results.Result := Define_Pending_Coefficient_Height;
         begin
            if not Results.Succeeded (Outcome) then
               Fail_With (Object, Outcome.First_Error);
               return Results.Failure (Object.First_Error);
            end if;
         end;
      end if;

      Object.Current_State := Decoding;
      if Internal.Frames.Mode (Object.Saved_Header.Frame) in Progressive_DCT | Differential_Progressive_DCT then
         Result := Internal.Decoder.Decode_Progressive_Coefficients (Object.Saved_Header, Object.Input, Blocks);
      elsif Object.Saved_Header.Entropy = Entropy_Mode'Val (1) then
         Result := Internal.Decoder.Decode_Arithmetic_Coefficients (Object.Saved_Header, Object.Input, Blocks);
      else
         Result := Internal.Decoder.Decode_Baseline_Coefficients (Object.Saved_Header, Object.Input, Blocks);
      end if;

      if not Results.Succeeded (Result.Outcome) then
         if not Errors.Is_Fatal (Object.First_Error) then
            Object.First_Error := Result.Outcome.First_Error;
         end if;
         Object.Current_State := Failed;
         return Results.Failure (Object.First_Error);
      elsif Height_Provisionally_Defined and then Result.Ending_Marker /= Internal.Markers.DNL then
         Fail_With (Object, Missing_DNL_Error (Result.Ending_Marker));
         return Results.Failure (Object.First_Error);
      end if;

      declare
         Continuation_Outcome : constant Results.Result :=
           Compose_Hierarchical_DCT_Continuation (Object, Result, Blocks);
      begin
         if not Results.Succeeded (Continuation_Outcome) then
            Fail_With (Object, Continuation_Outcome.First_Error);
            return Results.Failure (Object.First_Error);
         end if;
      end;

      Object.Saved_Header := Result.Header;
      Object.Header_Info := To_Image_Info (Result.Header);
      Blocks_Decoded := Result.Blocks_Decoded;
      Object.Current_State := Completed;
      return Results.Success;
   end Decode_Coefficients;

   function Decode_Raw_Components
     (Object : in out Decoder;
      Components : in out Raw_Component_View_Array) return Results.Result
   is
      Header_Outcome : Results.Result;
      Header : Internal.Decoder.Header_Result;
      Required_Blocks : Block_Count;

      function Coefficient_Bytes (Blocks : Block_Count) return Byte_Count is
        (Byte_Count (Blocks) * 64 * 4);

      function Component_Plane_Bytes return Byte_Count is
         Result : Byte_Count := 0;
         Item : Internal.Frames.Frame_Component;
      begin
         for Component in Component_Index range 1 .. Component_Index (Internal.Frames.Components (Header.Frame)) loop
            Item := Internal.Frames.Component (Header.Frame, Component);
            Result := Result + Byte_Count (Item.Component_Width) * Byte_Count (Item.Component_Height);
         end loop;

         return Result;
      end Component_Plane_Bytes;

      function Missing_Quantization_Table return Results.Result is
         Item : Internal.Frames.Frame_Component;
      begin
         for Component in Component_Index range 1 .. Component_Index (Internal.Frames.Components (Header.Frame)) loop
            Item := Internal.Frames.Component (Header.Frame, Component);
            if not Internal.Quantization.Has_Table (Header.Quantization_State, Item.Quantization_Table) then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Table_Invalid_Definition,
                       (Frame_Component => Component,
                        Detail => Long_Long_Integer (Item.Quantization_Table),
                        others => <>)));
            end if;
         end loop;

         return Results.Success;
      end Missing_Quantization_Table;

      function Progressive_Raw_Scope_Supported return Boolean is
      begin
         if Internal.Frames.Mode (Header.Frame) not in Progressive_DCT | Differential_Progressive_DCT then
            return True;
         end if;

         return True;
      end Progressive_Raw_Scope_Supported;

      function Effective_Raw_Precision return Sample_Precision is
      begin
         if Object.Decode_Options.Raw_Precision = Preserve_Source_Precision then
            return Internal.Frames.Precision (Header.Frame);
         else
            return Object.Decode_Options.Raw_Output_Precision;
         end if;
      end Effective_Raw_Precision;

      function Raw_View_Is_Valid
        (View : Raw_Component_View;
         Expected_Width : Natural;
         Expected_Height : Natural) return Boolean
      is
         Sample_Bytes : constant Positive :=
           (if Effective_Raw_Precision = 8 then 1 else 2);
         Minimum : constant Byte_Count :=
           (if Expected_Height = 0 then 0
            else
              Byte_Count (View.Stride) * Byte_Count (Expected_Height - 1)
              + Byte_Count (Expected_Width * Sample_Bytes));
      begin
         return View.Storage /= null
           and then View.Width = Expected_Width
           and then View.Height = Expected_Height
           and then View.Stride >= Row_Stride (Expected_Width * Sample_Bytes)
           and then View.Accessible_Bytes >= Minimum
           and then Byte_Count (View.Storage'Length) >= Minimum;
      end Raw_View_Is_Valid;

      function Raw_Output_Error (Detail : Long_Long_Integer := 0) return Errors.Error is
        (Errors.Make (Errors.Output_Limit_Exceeded, (Detail => Detail, others => <>)));

      function Converted_Raw_Sample
        (Sample : Integer;
         Source_Precision : Sample_Precision) return Integer
      is
         Source_Max : constant Integer := 2 ** Natural (Source_Precision) - 1;
         Target_Precision : constant Sample_Precision := Effective_Raw_Precision;
         Target_Max : constant Integer := 2 ** Natural (Target_Precision) - 1;
      begin
         case Object.Decode_Options.Raw_Precision is
            when Preserve_Source_Precision =>
               return Integer'Max (0, Integer'Min (Sample, Source_Max));
            when Clamp_To_Output_Precision =>
               return Integer'Max (0, Integer'Min (Sample, Target_Max));
            when Scale_To_Output_Precision | Reject_Precision_Mismatch =>
               if Source_Max = Target_Max then
                  return Integer'Max (0, Integer'Min (Sample, Target_Max));
               else
                  return
                    Integer'Max
                      (0,
                       Integer'Min
                         ((Sample * Target_Max + Source_Max / 2) / Source_Max,
                          Target_Max));
               end if;
         end case;
      end Converted_Raw_Sample;

      procedure Store_Raw_Sample
        (Target : in out Raw_Component_View;
         Row : Natural;
         Column : Natural;
         Sample : Integer)
      is
         Value : constant Integer := Converted_Raw_Sample (Sample, Internal.Frames.Precision (Header.Frame));
         Sample_Bytes : constant Positive :=
           (if Effective_Raw_Precision = 8 then 1 else 2);
         Offset : constant Natural := Row * Natural (Target.Stride) + Column * Sample_Bytes;
      begin
         if Sample_Bytes = 1 then
            Target.Storage (Target.Storage'First + Offset) := Byte (Value);
         else
            Target.Storage (Target.Storage'First + Offset) := Byte (Value / 256);
            Target.Storage (Target.Storage'First + Offset + 1) := Byte (Value mod 256);
         end if;
      end Store_Raw_Sample;

      function Validate_Raw_Output return Results.Result is
         Item : Internal.Frames.Frame_Component;
      begin
         if Object.Decode_Options.Raw_Precision = Reject_Precision_Mismatch
           and then Internal.Frames.Precision (Header.Frame) /= Object.Decode_Options.Raw_Output_Precision
         then
            return Results.Failure (Errors.Unsupported_Feature);
         end if;

         if Components'Length < Natural (Internal.Frames.Components (Header.Frame)) then
            return Results.Failure (Raw_Output_Error (Long_Long_Integer (Internal.Frames.Components (Header.Frame))));
         end if;

         for Component in Component_Index range 1 .. Component_Index (Internal.Frames.Components (Header.Frame)) loop
            if Component not in Components'Range then
               return Results.Failure (Raw_Output_Error (Long_Long_Integer (Component)));
            end if;

            Item := Internal.Frames.Component (Header.Frame, Component);
            if not Raw_View_Is_Valid
              (Components (Component),
               Natural (Item.Component_Width),
               Natural (Item.Component_Height))
            then
               return Results.Failure (Raw_Output_Error (Long_Long_Integer (Component)));
            end if;
         end loop;

         return Results.Success;
      end Validate_Raw_Output;

      function Define_Pending_Height_From_Raw_Output return Results.Result is
         Item : Internal.Frames.Frame_Component;
      begin
         if Components'Length < Natural (Internal.Frames.Components (Header.Frame)) then
            return Results.Failure (Raw_Output_Error (Long_Long_Integer (Internal.Frames.Components (Header.Frame))));
         end if;

         for Component in Component_Index range 1 .. Component_Index (Internal.Frames.Components (Header.Frame)) loop
            if Component not in Components'Range then
               return Results.Failure (Raw_Output_Error (Long_Long_Integer (Component)));
            end if;

            Item := Internal.Frames.Component (Header.Frame, Component);
            if Item.Vertical_Sampling = Internal.Frames.Maximum_Vertical_Sampling (Header.Frame) then
               return Internal.Frames.Define_Height (Header.Frame, Image_Height (Components (Component).Height));
            end if;
         end loop;

         return Results.Failure (Errors.Unsupported_Feature);
      end Define_Pending_Height_From_Raw_Output;

      procedure Store_Block
        (Blocks : Jpeglib.Coefficients.DCT_Block_Array;
         Block_Number : in out Positive;
         Component_Index_Value : Component_Index;
         MCU_C : MCU_Column;
         MCU_R : MCU_Row;
         H : Internal.Sampling.Block_Offset;
         V : Internal.Sampling.Block_Offset)
      is
         Component : constant Internal.Frames.Frame_Component :=
           Internal.Frames.Component (Header.Frame, Component_Index_Value);
         Table : constant Internal.Quantization.Quantization_Table :=
           Internal.Quantization.Table (Header.Quantization_State, Component.Quantization_Table);
         Dequantized : constant Internal.Transforms.Dequantized_Block :=
           Internal.Transforms.Dequantize (Blocks (Block_Number), Table);
         Samples : constant Internal.Transforms.Sample_Block :=
           Internal.Transforms.Reconstruct_Block
             (Dequantized, Internal.Frames.Precision (Header.Frame));
         Placement : constant Internal.Sampling.Block_Placement :=
           Internal.Sampling.Placement (Header.Frame, Component_Index_Value, MCU_C, MCU_R, H, V);
         Target : Raw_Component_View renames Components (Component_Index_Value);
      begin
         if Placement.Visible_Width > 0 and then Placement.Visible_Height > 0 then
            for Y in Natural range 0 .. Natural (Placement.Visible_Height) - 1 loop
               for X in Natural range 0 .. Natural (Placement.Visible_Width) - 1 loop
                  Target.Storage
                    (Target.Storage'First
                     + (Natural (Placement.Row) + Y) * Natural (Target.Stride)
                     + Natural (Placement.Column)
                     + X) :=
                    Samples (Coefficient_Index (Y * 8 + X));
               end loop;
            end loop;
         end if;

         Block_Number := Block_Number + 1;
      end Store_Block;

      procedure Store_Separate_Component
        (Blocks : Jpeglib.Coefficients.DCT_Block_Array;
         Block_Number : in out Positive;
         Component_Index_Value : Component_Index)
      is
         Component : constant Internal.Frames.Frame_Component :=
           Internal.Frames.Component (Header.Frame, Component_Index_Value);
         Padded_Order : constant Boolean :=
           Header.Entropy = Arithmetic
           and then Internal.Frames.Mode (Header.Frame) in Progressive_DCT | Differential_Progressive_DCT;
         Block_Rows : constant Natural :=
           (if Padded_Order
            then Natural (Internal.Frames.Padded_Block_Rows (Header.Frame, Component_Index_Value))
            else Natural (Component.Block_Rows));
         Block_Columns : constant Natural :=
           (if Padded_Order
            then Natural (Internal.Frames.Padded_Block_Columns (Header.Frame, Component_Index_Value))
            else Natural (Component.Block_Columns));
      begin
         for Row in Natural range 0 .. Block_Rows - 1 loop
            for Column in Natural range 0 .. Block_Columns - 1 loop
               Store_Block
                 (Blocks,
                  Block_Number,
                  Component_Index_Value,
                  MCU_Column (Column / Natural (Component.Horizontal_Sampling)),
                  MCU_Row (Row / Natural (Component.Vertical_Sampling)),
                  Internal.Sampling.Block_Offset (Column mod Natural (Component.Horizontal_Sampling)),
                  Internal.Sampling.Block_Offset (Row mod Natural (Component.Vertical_Sampling)));
            end loop;
         end loop;
      end Store_Separate_Component;

      procedure Store_Raw_Blocks
        (Blocks : Jpeglib.Coefficients.DCT_Block_Array;
         Separate_Order : Boolean)
      is
         Block_Number : Positive := Blocks'First;
         Component : Internal.Frames.Frame_Component;
      begin
         if Separate_Order then
            for Component_Index_Value in Component_Index range
              1 .. Component_Index (Internal.Frames.Components (Header.Frame))
            loop
               Store_Separate_Component (Blocks, Block_Number, Component_Index_Value);
            end loop;
         else
            for MCU_R in MCU_Row range 0 .. Internal.Frames.MCU_Rows (Header.Frame) - 1 loop
               for MCU_C in MCU_Column range 0 .. Internal.Frames.MCU_Columns (Header.Frame) - 1 loop
                  for Component_Index_Value in Component_Index range
                    1 .. Component_Index (Internal.Frames.Components (Header.Frame))
                  loop
                     Component := Internal.Frames.Component (Header.Frame, Component_Index_Value);
                     for V in Internal.Sampling.Block_Offset range 0
                       .. Internal.Sampling.Block_Offset (Component.Vertical_Sampling - 1)
                     loop
                        for H in Internal.Sampling.Block_Offset range 0
                          .. Internal.Sampling.Block_Offset (Component.Horizontal_Sampling - 1)
                        loop
                           Store_Block (Blocks, Block_Number, Component_Index_Value, MCU_C, MCU_R, H, V);
                        end loop;
                     end loop;
                  end loop;
               end loop;
            end loop;
         end if;
      end Store_Raw_Blocks;

      function Decode_Lossless_Raw_From_Coefficients return Results.Result is
         Required : constant Block_Count := Lossless_Coefficient_Blocks (Header.Frame);
         Blocks_Decoded : Block_Count := 0;

      begin
         if Required = 0
           or else Coefficient_Bytes (Required) > Object.Decode_Limits.Max_Coefficient_Bytes
           or else Coefficient_Bytes (Required) + Component_Plane_Bytes > Object.Decode_Limits.Max_Allocation_Bytes
         then
            return Results.Failure (Raw_Output_Error (Long_Long_Integer (Required)));
         end if;

         declare
            Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Required)) := [others => [others => 0]];
            Outcome : constant Results.Result := Decode_Coefficients (Object, Blocks, Blocks_Decoded);
            Block_Number : Positive := Blocks'First;
         begin
            if not Results.Succeeded (Outcome) then
               return Outcome;
            elsif Blocks_Decoded /= Required then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Scan_Invalid_Definition,
                       (Detail => Long_Long_Integer (Blocks_Decoded), others => <>)));
            end if;

            for Component_Index_Value in Component_Index range
              1 .. Component_Index (Internal.Frames.Components (Header.Frame))
            loop
               declare
                  Component : constant Internal.Frames.Frame_Component :=
                    Internal.Frames.Component (Header.Frame, Component_Index_Value);
                  Target : Raw_Component_View renames Components (Component_Index_Value);
               begin
                  for Row in Natural range 0 .. Natural (Component.Component_Height) - 1 loop
                     for Column in Natural range 0 .. Natural (Component.Component_Width) - 1 loop
                        Store_Raw_Sample (Target, Row, Column, Integer (Blocks (Block_Number) (0)));
                        Block_Number := Block_Number + 1;
                     end loop;
                  end loop;
               end;
            end loop;
         end;

         return Results.Success;
      end Decode_Lossless_Raw_From_Coefficients;

      function Decode_Lossless_Grayscale_Raw return Results.Result is
         use type Internal.Bit_Streams.Entropy_Byte_Kind;
         use type Internal.Bit_Streams.Entropy_Bits;

         Component : constant Internal.Scans.Scan_Component := Internal.Scans.Component (Header.Scan, 1);
         Compile : Internal.Huffman.Compile_Result;
         Entropy : aliased Internal.Bit_Streams.Entropy_Reader (Object.Input);
         Bits : Internal.Bit_Streams.Bit_Reader (Entropy'Access);
         Symbol : Internal.Huffman.Decode_Result;
         Extended : Internal.Bit_Streams.Sign_Extend_Result;
         Ending : Internal.Bit_Streams.Entropy_Read_Result;
         Target : Raw_Component_View renames Components (1);
         Restart_State : Internal.Restarts.Restart_State;
         Restart_Base : Natural := 0;
         Decoded : Natural := 0;
         Total : constant Natural :=
           Natural (Internal.Frames.Width (Header.Frame)) * Natural (Internal.Frames.Height (Header.Frame));
         Samples : aliased Lossless_Sample_Array := [1 .. 1 => [1 .. Total => 0]];

         function Read_Category_Bits
           (Category : Internal.Bit_Streams.Entropy_Category) return Internal.Bit_Streams.Sign_Extend_Result
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

         function Initial_Predictor return Integer is
         begin
            return
              2 **
                (Natural (Internal.Frames.Precision (Header.Frame))
                 - Natural (Internal.Scans.Successive_Low (Header.Scan))
                 - 1);
         end Initial_Predictor;

        function Stored (Column, Row : Natural) return Integer is
         begin
            return Samples (1, Samples'First (2) + Row * Natural (Internal.Frames.Width (Header.Frame)) + Column);
         end Stored;

         function Predictor (Column, Row : Natural) return Integer is
            Ra : Integer;
            Rb : Integer;
            Rc : Integer;
         begin
            if Decoded = Restart_Base then
               return Initial_Predictor;
            elsif Column = 0 then
               return Stored (Column, Row - 1);
            elsif Row = 0 then
               return Stored (Column - 1, Row);
            end if;

            Ra := Stored (Column - 1, Row);
            Rb := Stored (Column, Row - 1);
            Rc := Stored (Column - 1, Row - 1);

            case Internal.Scans.Spectral_Start (Header.Scan) is
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
               when others =>
                  return Initial_Predictor;
            end case;
         end Predictor;

         function Accept_Restart_When_Due return Results.Result is
            Marker : Internal.Bit_Streams.Entropy_Read_Result;
            Outcome : Results.Result;
         begin
            if Header.Restart = 0
              or else Internal.Restarts.MCUs_Until_Restart (Restart_State) /= 0
              or else Decoded = Total
            then
               return Results.Success;
            end if;

            Internal.Bit_Streams.Byte_Align (Bits);
            Marker := Internal.Bit_Streams.Read_Byte (Entropy);
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Marker.Kind /= Internal.Bit_Streams.Restart_Marker then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Restart_Invalid_State,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            end if;

            Outcome := Internal.Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
            if Results.Succeeded (Outcome) then
               Restart_Base := Decoded;
            end if;
            return Outcome;
         end Accept_Restart_When_Due;
      begin
         if Internal.Scans.Components (Header.Scan) /= 1
           or else not Internal.Huffman.Has_Table (Header.Huffman_State, Internal.Huffman.DC, Component.DC_Table)
         then
            return
              Results.Failure
                (Errors.Make
                   (Errors.Table_Invalid_Definition,
                    (Frame_Component => Component.Frame_Component,
                     Detail => Long_Long_Integer (Component.DC_Table),
                     others => <>)));
         end if;

         Compile :=
           Internal.Huffman.Compile
             (Internal.Huffman.Definition (Header.Huffman_State, Internal.Huffman.DC, Component.DC_Table));
         if not Results.Succeeded (Compile.Outcome) then
            return Compile.Outcome;
         end if;

         Internal.Restarts.Configure (Restart_State, Header.Restart);
         for Row in Natural range 0 .. Natural (Internal.Frames.Height (Header.Frame)) - 1 loop
            for Column in Natural range 0 .. Natural (Internal.Frames.Width (Header.Frame)) - 1 loop
               Symbol := Internal.Huffman.Decode (Compile.Table, Bits);
               if not Results.Succeeded (Symbol.Outcome) then
                  return Symbol.Outcome;
               elsif Symbol.Symbol > 16 then
                  return
                    Results.Failure
                      (Errors.Make
                         (Errors.Coefficient_Invalid_Encoding,
                          (Source => Symbol.Source,
                           Detail => Long_Long_Integer (Symbol.Symbol),
                           others => <>)));
               end if;

               Extended := Read_Category_Bits (Internal.Bit_Streams.Entropy_Category (Symbol.Symbol));
               if not Results.Succeeded (Extended.Outcome) then
                  return Extended.Outcome;
               end if;

               declare
                  Sample : constant Integer := Predictor (Column, Row) + Integer (Extended.Value);
                  Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
               begin
                  if Sample not in 0 .. Max_Sample then
                     return
                       Results.Failure
                         (Errors.Make
                            (Errors.Coefficient_Invalid_Encoding,
                             (Detail => Long_Long_Integer (Sample), others => <>)));
                  end if;
                  Samples
                    (1, Samples'First (2) + Row * Natural (Internal.Frames.Width (Header.Frame)) + Column) :=
                    Sample;
               end;

               Decoded := Decoded + 1;
               declare
                  Outcome : Results.Result := Internal.Restarts.Advance_MCU (Restart_State);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome := Accept_Restart_When_Due;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            end loop;
         end loop;

         Internal.Bit_Streams.Byte_Align (Bits);
         Ending := Internal.Bit_Streams.Read_Byte (Entropy);
         declare
            Outcome : constant Results.Result :=
              Decode_Hierarchical_Lossless_Continuation
                (Header, Object.Input, Ending, Samples'Access);
         begin
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end;

         for Row in Natural range 0 .. Natural (Internal.Frames.Height (Header.Frame)) - 1 loop
            for Column in Natural range 0 .. Natural (Internal.Frames.Width (Header.Frame)) - 1 loop
               Store_Raw_Sample
                 (Target,
                  Row,
                  Column,
                  Samples
                    (1, Samples'First (2) + Row * Natural (Internal.Frames.Width (Header.Frame)) + Column));
            end loop;
         end loop;

         return Results.Success;
      end Decode_Lossless_Grayscale_Raw;
      pragma Unreferenced (Decode_Lossless_Grayscale_Raw);

      function Decode_Lossless_Two_Component_Raw return Results.Result is
         use type Internal.Bit_Streams.Entropy_Byte_Kind;
         use type Internal.Bit_Streams.Entropy_Bits;

         type Compiled_Array is array (Component_Index range 1 .. 2) of Internal.Huffman.Compiled_Huffman;

         Compile : Internal.Huffman.Compile_Result;
         Entropy : aliased Internal.Bit_Streams.Entropy_Reader (Object.Input);
         Bits : Internal.Bit_Streams.Bit_Reader (Entropy'Access);
         Tables : Compiled_Array;
         Symbol : Internal.Huffman.Decode_Result;
         Extended : Internal.Bit_Streams.Sign_Extend_Result;
         Ending : Internal.Bit_Streams.Entropy_Read_Result;
         Restart_State : Internal.Restarts.Restart_State;
         Restart_Base : Natural := 0;
         Decoded : Natural := 0;
         Width : constant Natural := Natural (Internal.Frames.Width (Header.Frame));
         Height : constant Natural := Natural (Internal.Frames.Height (Header.Frame));
         Total : constant Natural := Width * Height;
         Samples : aliased Lossless_Sample_Array := [1 .. 2 => [1 .. Total => 0]];

         function Read_Category_Bits
           (Category : Internal.Bit_Streams.Entropy_Category) return Internal.Bit_Streams.Sign_Extend_Result
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

         function Initial_Predictor return Integer is
         begin
            return
              2 **
                (Natural (Internal.Frames.Precision (Header.Frame))
                 - Natural (Internal.Scans.Successive_Low (Header.Scan))
                 - 1);
         end Initial_Predictor;

         function Stored (Component : Component_Index; Column, Row : Natural) return Integer is
           (Samples (Component, Samples'First (2) + Row * Width + Column));

         function Predictor (Component : Component_Index; Column, Row : Natural) return Integer is
            Ra : Integer;
            Rb : Integer;
            Rc : Integer;
         begin
            if Decoded = Restart_Base then
               return Initial_Predictor;
            elsif Column = 0 then
               return Stored (Component, Column, Row - 1);
            elsif Row = 0 then
               return Stored (Component, Column - 1, Row);
            end if;

            Ra := Stored (Component, Column - 1, Row);
            Rb := Stored (Component, Column, Row - 1);
            Rc := Stored (Component, Column - 1, Row - 1);

            case Internal.Scans.Spectral_Start (Header.Scan) is
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
               when others =>
                  return Initial_Predictor;
            end case;
         end Predictor;

         function Accept_Restart_When_Due return Results.Result is
            Marker : Internal.Bit_Streams.Entropy_Read_Result;
            Outcome : Results.Result;
         begin
            if Header.Restart = 0
              or else Internal.Restarts.MCUs_Until_Restart (Restart_State) /= 0
              or else Decoded = Total
            then
               return Results.Success;
            end if;

            Internal.Bit_Streams.Byte_Align (Bits);
            Marker := Internal.Bit_Streams.Read_Byte (Entropy);
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Marker.Kind /= Internal.Bit_Streams.Restart_Marker then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Restart_Invalid_State,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            end if;

            Outcome := Internal.Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
            if Results.Succeeded (Outcome) then
               Restart_Base := Decoded;
            end if;
            return Outcome;
         end Accept_Restart_When_Due;
      begin
         if Internal.Scans.Components (Header.Scan) /= 2 then
            return Results.Failure (Errors.Table_Invalid_Definition);
         end if;

         for Component_Index_Value in Component_Index range 1 .. 2 loop
            declare
               Scan_Component : constant Internal.Scans.Scan_Component :=
                 Internal.Scans.Component (Header.Scan, Component_Index_Value);
               Frame_Component : constant Internal.Frames.Frame_Component :=
                 Internal.Frames.Component (Header.Frame, Scan_Component.Frame_Component);
            begin
               if Frame_Component.Horizontal_Sampling /= 1
                 or else Frame_Component.Vertical_Sampling /= 1
                 or else not Internal.Huffman.Has_Table
                   (Header.Huffman_State, Internal.Huffman.DC, Scan_Component.DC_Table)
               then
                  return
                    Results.Failure
                      (Errors.Make
                         (Errors.Table_Invalid_Definition,
                          (Frame_Component => Scan_Component.Frame_Component,
                           Detail => Long_Long_Integer (Scan_Component.DC_Table),
                           others => <>)));
               end if;

               Compile :=
                 Internal.Huffman.Compile
                   (Internal.Huffman.Definition
                      (Header.Huffman_State, Internal.Huffman.DC, Scan_Component.DC_Table));
               if not Results.Succeeded (Compile.Outcome) then
                  return Compile.Outcome;
               end if;
               Tables (Component_Index_Value) := Compile.Table;
            end;
         end loop;

         Internal.Restarts.Configure (Restart_State, Header.Restart);
         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               for Component_Index_Value in Component_Index range 1 .. 2 loop
                  Symbol := Internal.Huffman.Decode (Tables (Component_Index_Value), Bits);
                  if not Results.Succeeded (Symbol.Outcome) then
                     return Symbol.Outcome;
                  elsif Symbol.Symbol > 16 then
                     return
                       Results.Failure
                         (Errors.Make
                            (Errors.Coefficient_Invalid_Encoding,
                             (Source => Symbol.Source,
                              Detail => Long_Long_Integer (Symbol.Symbol),
                              others => <>)));
                  end if;

                  Extended := Read_Category_Bits (Internal.Bit_Streams.Entropy_Category (Symbol.Symbol));
                  if not Results.Succeeded (Extended.Outcome) then
                     return Extended.Outcome;
                  end if;

                  declare
                     Sample : constant Integer :=
                       Predictor (Component_Index_Value, Column, Row) + Integer (Extended.Value);
                     Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
                  begin
                     if Sample not in 0 .. Max_Sample then
                        return
                         Results.Failure
                            (Errors.Make
                               (Errors.Coefficient_Invalid_Encoding,
                                (Detail => Long_Long_Integer (Sample), others => <>)));
                     end if;
                     Samples (Component_Index_Value, Samples'First (2) + Row * Width + Column) := Sample;
                  end;
               end loop;

               Decoded := Decoded + 1;
               declare
                  Outcome : Results.Result := Internal.Restarts.Advance_MCU (Restart_State);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome := Accept_Restart_When_Due;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            end loop;
         end loop;

         Internal.Bit_Streams.Byte_Align (Bits);
         Ending := Internal.Bit_Streams.Read_Byte (Entropy);
         declare
            Outcome : constant Results.Result :=
              Decode_Hierarchical_Lossless_Continuation
                (Header, Object.Input, Ending, Samples'Access);
         begin
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end;

         for Component_Index_Value in Component_Index range 1 .. 2 loop
            declare
               Target : Raw_Component_View renames Components (Component_Index_Value);
            begin
               for Row in Natural range 0 .. Height - 1 loop
                  for Column in Natural range 0 .. Width - 1 loop
                     Store_Raw_Sample
                       (Target,
                        Row,
                        Column,
                        Samples (Component_Index_Value, Samples'First (2) + Row * Width + Column));
                  end loop;
               end loop;
            end;
         end loop;

         return Results.Success;
      end Decode_Lossless_Two_Component_Raw;
      pragma Unreferenced (Decode_Lossless_Two_Component_Raw);

      function Decode_Lossless_Three_Component_Raw return Results.Result is
         use type Internal.Bit_Streams.Entropy_Byte_Kind;
         use type Internal.Bit_Streams.Entropy_Bits;

         type Compiled_Array is array (Component_Index range 1 .. 3) of Internal.Huffman.Compiled_Huffman;

         Compile : Internal.Huffman.Compile_Result;
         Entropy : aliased Internal.Bit_Streams.Entropy_Reader (Object.Input);
         Bits : Internal.Bit_Streams.Bit_Reader (Entropy'Access);
         Tables : Compiled_Array;
         Symbol : Internal.Huffman.Decode_Result;
         Extended : Internal.Bit_Streams.Sign_Extend_Result;
         Ending : Internal.Bit_Streams.Entropy_Read_Result;
         Restart_State : Internal.Restarts.Restart_State;
         Restart_Base : Natural := 0;
         Decoded : Natural := 0;
         Width : constant Natural := Natural (Internal.Frames.Width (Header.Frame));
         Height : constant Natural := Natural (Internal.Frames.Height (Header.Frame));
         Total : constant Natural := Width * Height;
         Samples : aliased Lossless_Sample_Array := [1 .. 3 => [1 .. Total => 0]];

         function Read_Category_Bits
           (Category : Internal.Bit_Streams.Entropy_Category) return Internal.Bit_Streams.Sign_Extend_Result
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

         function Initial_Predictor return Integer is
         begin
            return
              2 **
                (Natural (Internal.Frames.Precision (Header.Frame))
                 - Natural (Internal.Scans.Successive_Low (Header.Scan))
                 - 1);
         end Initial_Predictor;

         function Stored (Component : Component_Index; Column, Row : Natural) return Integer is
           (Samples (Component, Samples'First (2) + Row * Width + Column));

         function Predictor (Component : Component_Index; Column, Row : Natural) return Integer is
            Ra : Integer;
            Rb : Integer;
            Rc : Integer;
         begin
            if Decoded = Restart_Base then
               return Initial_Predictor;
            elsif Column = 0 then
               return Stored (Component, Column, Row - 1);
            elsif Row = 0 then
               return Stored (Component, Column - 1, Row);
            end if;

            Ra := Stored (Component, Column - 1, Row);
            Rb := Stored (Component, Column, Row - 1);
            Rc := Stored (Component, Column - 1, Row - 1);

            case Internal.Scans.Spectral_Start (Header.Scan) is
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
               when others =>
                  return Initial_Predictor;
            end case;
         end Predictor;

         function Accept_Restart_When_Due return Results.Result is
            Marker : Internal.Bit_Streams.Entropy_Read_Result;
            Outcome : Results.Result;
         begin
            if Header.Restart = 0
              or else Internal.Restarts.MCUs_Until_Restart (Restart_State) /= 0
              or else Decoded = Total
            then
               return Results.Success;
            end if;

            Internal.Bit_Streams.Byte_Align (Bits);
            Marker := Internal.Bit_Streams.Read_Byte (Entropy);
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Marker.Kind /= Internal.Bit_Streams.Restart_Marker then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Restart_Invalid_State,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            end if;

            Outcome := Internal.Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
            if Results.Succeeded (Outcome) then
               Restart_Base := Decoded;
            end if;
            return Outcome;
         end Accept_Restart_When_Due;
      begin
         if Internal.Scans.Components (Header.Scan) /= 3 then
            return Results.Failure (Errors.Table_Invalid_Definition);
         end if;

         for Component_Index_Value in Component_Index range 1 .. 3 loop
            declare
               Scan_Component : constant Internal.Scans.Scan_Component :=
                 Internal.Scans.Component (Header.Scan, Component_Index_Value);
               Frame_Component : constant Internal.Frames.Frame_Component :=
                 Internal.Frames.Component (Header.Frame, Scan_Component.Frame_Component);
            begin
               if Frame_Component.Horizontal_Sampling /= 1
                 or else Frame_Component.Vertical_Sampling /= 1
                 or else not Internal.Huffman.Has_Table
                   (Header.Huffman_State, Internal.Huffman.DC, Scan_Component.DC_Table)
               then
                  return
                    Results.Failure
                      (Errors.Make
                         (Errors.Table_Invalid_Definition,
                          (Frame_Component => Scan_Component.Frame_Component,
                           Detail => Long_Long_Integer (Scan_Component.DC_Table),
                           others => <>)));
               end if;

               Compile :=
                 Internal.Huffman.Compile
                   (Internal.Huffman.Definition
                      (Header.Huffman_State, Internal.Huffman.DC, Scan_Component.DC_Table));
               if not Results.Succeeded (Compile.Outcome) then
                  return Compile.Outcome;
               end if;
               Tables (Component_Index_Value) := Compile.Table;
            end;
         end loop;

         Internal.Restarts.Configure (Restart_State, Header.Restart);
         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               for Component_Index_Value in Component_Index range 1 .. 3 loop
                  Symbol := Internal.Huffman.Decode (Tables (Component_Index_Value), Bits);
                  if not Results.Succeeded (Symbol.Outcome) then
                     return Symbol.Outcome;
                  elsif Symbol.Symbol > 16 then
                     return
                       Results.Failure
                         (Errors.Make
                            (Errors.Coefficient_Invalid_Encoding,
                             (Source => Symbol.Source,
                              Detail => Long_Long_Integer (Symbol.Symbol),
                              others => <>)));
                  end if;

                  Extended := Read_Category_Bits (Internal.Bit_Streams.Entropy_Category (Symbol.Symbol));
                  if not Results.Succeeded (Extended.Outcome) then
                     return Extended.Outcome;
                  end if;

                  declare
                     Sample : constant Integer :=
                       Predictor (Component_Index_Value, Column, Row) + Integer (Extended.Value);
                     Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
                  begin
                     if Sample not in 0 .. Max_Sample then
                        return
                          Results.Failure
                            (Errors.Make
                               (Errors.Coefficient_Invalid_Encoding,
                                (Detail => Long_Long_Integer (Sample), others => <>)));
                     end if;
                     Samples
                       (Component_Index_Value, Samples'First (2) + Row * Width + Column) := Sample;
                  end;
               end loop;

               Decoded := Decoded + 1;
               declare
                  Outcome : Results.Result := Internal.Restarts.Advance_MCU (Restart_State);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome := Accept_Restart_When_Due;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            end loop;
         end loop;

         Internal.Bit_Streams.Byte_Align (Bits);
         Ending := Internal.Bit_Streams.Read_Byte (Entropy);
         declare
            Outcome : constant Results.Result :=
              Decode_Hierarchical_Lossless_Continuation
                (Header, Object.Input, Ending, Samples'Access);
         begin
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end;

         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               for Component_Index_Value in Component_Index range 1 .. 3 loop
                  declare
                     Target : Raw_Component_View renames Components (Component_Index_Value);
                     Index : constant Natural := Samples'First (2) + Row * Width + Column;
                  begin
                     Store_Raw_Sample (Target, Row, Column, Samples (Component_Index_Value, Index));
                  end;
               end loop;
            end loop;
         end loop;

         return Results.Success;
      end Decode_Lossless_Three_Component_Raw;
      pragma Unreferenced (Decode_Lossless_Three_Component_Raw);

      function Decode_Lossless_Four_Component_Raw return Results.Result is
         use type Internal.Bit_Streams.Entropy_Byte_Kind;
         use type Internal.Bit_Streams.Entropy_Bits;

         type Compiled_Array is array (Component_Index range 1 .. 4) of Internal.Huffman.Compiled_Huffman;

         Compile : Internal.Huffman.Compile_Result;
         Entropy : aliased Internal.Bit_Streams.Entropy_Reader (Object.Input);
         Bits : Internal.Bit_Streams.Bit_Reader (Entropy'Access);
         Tables : Compiled_Array;
         Symbol : Internal.Huffman.Decode_Result;
         Extended : Internal.Bit_Streams.Sign_Extend_Result;
         Ending : Internal.Bit_Streams.Entropy_Read_Result;
         Restart_State : Internal.Restarts.Restart_State;
         Restart_Base : Natural := 0;
         Decoded : Natural := 0;
         Width : constant Natural := Natural (Internal.Frames.Width (Header.Frame));
         Height : constant Natural := Natural (Internal.Frames.Height (Header.Frame));
         Total : constant Natural := Width * Height;
         Samples : aliased Lossless_Sample_Array := [1 .. 4 => [1 .. Total => 0]];

         function Read_Category_Bits
           (Category : Internal.Bit_Streams.Entropy_Category) return Internal.Bit_Streams.Sign_Extend_Result
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

         function Initial_Predictor return Integer is
         begin
            return
              2 **
                (Natural (Internal.Frames.Precision (Header.Frame))
                 - Natural (Internal.Scans.Successive_Low (Header.Scan))
                 - 1);
         end Initial_Predictor;

         function Stored (Component : Component_Index; Column, Row : Natural) return Integer is
           (Samples (Component, Samples'First (2) + Row * Width + Column));

         function Predictor (Component : Component_Index; Column, Row : Natural) return Integer is
            Ra : Integer;
            Rb : Integer;
            Rc : Integer;
         begin
            if Decoded = Restart_Base then
               return Initial_Predictor;
            elsif Column = 0 then
               return Stored (Component, Column, Row - 1);
            elsif Row = 0 then
               return Stored (Component, Column - 1, Row);
            end if;

            Ra := Stored (Component, Column - 1, Row);
            Rb := Stored (Component, Column, Row - 1);
            Rc := Stored (Component, Column - 1, Row - 1);

            case Internal.Scans.Spectral_Start (Header.Scan) is
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
               when others =>
                  return Initial_Predictor;
            end case;
         end Predictor;

         function Accept_Restart_When_Due return Results.Result is
            Marker : Internal.Bit_Streams.Entropy_Read_Result;
            Outcome : Results.Result;
         begin
            if Header.Restart = 0
              or else Internal.Restarts.MCUs_Until_Restart (Restart_State) /= 0
              or else Decoded = Total
            then
               return Results.Success;
            end if;

            Internal.Bit_Streams.Byte_Align (Bits);
            Marker := Internal.Bit_Streams.Read_Byte (Entropy);
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Marker.Kind /= Internal.Bit_Streams.Restart_Marker then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Restart_Invalid_State,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            end if;

            Outcome := Internal.Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
            if Results.Succeeded (Outcome) then
               Restart_Base := Decoded;
            end if;
            return Outcome;
         end Accept_Restart_When_Due;
      begin
         if Internal.Scans.Components (Header.Scan) /= 4 then
            return Results.Failure (Errors.Table_Invalid_Definition);
         end if;

         for Component_Index_Value in Component_Index range 1 .. 4 loop
            declare
               Scan_Component : constant Internal.Scans.Scan_Component :=
                 Internal.Scans.Component (Header.Scan, Component_Index_Value);
               Frame_Component : constant Internal.Frames.Frame_Component :=
                 Internal.Frames.Component (Header.Frame, Scan_Component.Frame_Component);
            begin
               if Frame_Component.Horizontal_Sampling /= 1
                 or else Frame_Component.Vertical_Sampling /= 1
                 or else not Internal.Huffman.Has_Table
                   (Header.Huffman_State, Internal.Huffman.DC, Scan_Component.DC_Table)
               then
                  return
                    Results.Failure
                      (Errors.Make
                         (Errors.Table_Invalid_Definition,
                          (Frame_Component => Scan_Component.Frame_Component,
                           Detail => Long_Long_Integer (Scan_Component.DC_Table),
                           others => <>)));
               end if;

               Compile :=
                 Internal.Huffman.Compile
                   (Internal.Huffman.Definition
                      (Header.Huffman_State, Internal.Huffman.DC, Scan_Component.DC_Table));
               if not Results.Succeeded (Compile.Outcome) then
                  return Compile.Outcome;
               end if;
               Tables (Component_Index_Value) := Compile.Table;
            end;
         end loop;

         Internal.Restarts.Configure (Restart_State, Header.Restart);
         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               for Component_Index_Value in Component_Index range 1 .. 4 loop
                  Symbol := Internal.Huffman.Decode (Tables (Component_Index_Value), Bits);
                  if not Results.Succeeded (Symbol.Outcome) then
                     return Symbol.Outcome;
                  elsif Symbol.Symbol > 16 then
                     return
                       Results.Failure
                         (Errors.Make
                            (Errors.Coefficient_Invalid_Encoding,
                             (Source => Symbol.Source,
                              Detail => Long_Long_Integer (Symbol.Symbol),
                              others => <>)));
                  end if;

                  Extended := Read_Category_Bits (Internal.Bit_Streams.Entropy_Category (Symbol.Symbol));
                  if not Results.Succeeded (Extended.Outcome) then
                     return Extended.Outcome;
                  end if;

                  declare
                     Sample : constant Integer :=
                       Predictor (Component_Index_Value, Column, Row) + Integer (Extended.Value);
                     Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
                  begin
                     if Sample not in 0 .. Max_Sample then
                        return
                          Results.Failure
                            (Errors.Make
                               (Errors.Coefficient_Invalid_Encoding,
                                (Detail => Long_Long_Integer (Sample), others => <>)));
                     end if;
                     Samples
                       (Component_Index_Value, Samples'First (2) + Row * Width + Column) := Sample;
                  end;
               end loop;

               Decoded := Decoded + 1;
               declare
                  Outcome : Results.Result := Internal.Restarts.Advance_MCU (Restart_State);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome := Accept_Restart_When_Due;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            end loop;
         end loop;

         Internal.Bit_Streams.Byte_Align (Bits);
         Ending := Internal.Bit_Streams.Read_Byte (Entropy);
         declare
            Outcome : constant Results.Result :=
              Decode_Hierarchical_Lossless_Continuation
                (Header, Object.Input, Ending, Samples'Access);
         begin
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end;

         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               for Component_Index_Value in Component_Index range 1 .. 4 loop
                  declare
                     Target : Raw_Component_View renames Components (Component_Index_Value);
                     Index : constant Natural := Samples'First (2) + Row * Width + Column;
                  begin
                     Store_Raw_Sample (Target, Row, Column, Samples (Component_Index_Value, Index));
                  end;
               end loop;
            end loop;
         end loop;

         return Results.Success;
      end Decode_Lossless_Four_Component_Raw;
      pragma Unreferenced (Decode_Lossless_Four_Component_Raw);

      function Decode_Arithmetic_Lossless_Grayscale_Raw return Results.Result is
         use type Internal.Bit_Streams.Entropy_Byte_Kind;

         Component : constant Internal.Scans.Scan_Component := Internal.Scans.Component (Header.Scan, 1);
         Entropy : aliased Internal.Bit_Streams.Entropy_Reader (Object.Input);
         Decoder : Internal.Arithmetic.Decoder (Entropy'Access);
         DC_Bins : Internal.Arithmetic.Probability_Bin_Array (0 .. 63) :=
           [others => Internal.Arithmetic.Initial_Probability_Bin];
         DC_Context : Internal.Arithmetic.DC_Context_Index := 0;
         DC : Internal.Arithmetic.DC_Result;
         Ending : Internal.Bit_Streams.Entropy_Read_Result;
         Restart_State : Internal.Restarts.Restart_State;
         Restart_Base : Natural := 0;
         Decoded : Natural := 0;
         Width : constant Natural := Natural (Internal.Frames.Width (Header.Frame));
         Height : constant Natural := Natural (Internal.Frames.Height (Header.Frame));
         Total : constant Natural := Width * Height;
         Samples : aliased Lossless_Sample_Array := [1 .. 1 => [1 .. Total => 0]];

         function Initial_Predictor return Integer is
         begin
            return
              2 **
                (Natural (Internal.Frames.Precision (Header.Frame))
                 - Natural (Internal.Scans.Successive_Low (Header.Scan))
                 - 1);
         end Initial_Predictor;

         function Stored (Column, Row : Natural) return Integer is
         begin
            return Samples (1, Samples'First (2) + Row * Width + Column);
         end Stored;

         function Predictor (Column, Row : Natural) return Integer is
            Ra : Integer;
            Rb : Integer;
            Rc : Integer;
         begin
            if Decoded = Restart_Base then
               return Initial_Predictor;
            elsif Column = 0 then
               return Stored (Column, Row - 1);
            elsif Row = 0 then
               return Stored (Column - 1, Row);
            end if;

            Ra := Stored (Column - 1, Row);
            Rb := Stored (Column, Row - 1);
            Rc := Stored (Column - 1, Row - 1);

            case Internal.Scans.Spectral_Start (Header.Scan) is
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
               when others =>
                  return Initial_Predictor;
            end case;
         end Predictor;

         function Accept_Restart_When_Due return Results.Result is
            Marker : Internal.Bit_Streams.Entropy_Read_Result;
            Outcome : Results.Result;
         begin
            if Header.Restart = 0
              or else Internal.Restarts.MCUs_Until_Restart (Restart_State) /= 0
              or else Decoded = Total
            then
               return Results.Success;
            end if;

            Marker := Internal.Bit_Streams.Read_Byte (Entropy);
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Marker.Kind /= Internal.Bit_Streams.Restart_Marker then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Restart_Invalid_State,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            end if;

            Outcome := Internal.Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
            if Results.Succeeded (Outcome) then
               Restart_Base := Decoded;
               Internal.Arithmetic.Reset (Decoder);
               DC_Bins := [others => Internal.Arithmetic.Initial_Probability_Bin];
               DC_Context := 0;
            end if;
            return Outcome;
         end Accept_Restart_When_Due;
      begin
         if Internal.Scans.Components (Header.Scan) /= 1
           or else not Internal.Arithmetic.Has_Table
             (Header.Arithmetic_State, Internal.Arithmetic.DC, Component.DC_Table)
         then
            return
              Results.Failure
                (Errors.Make
                   (Errors.Table_Invalid_Definition,
                    (Frame_Component => Component.Frame_Component,
                     Detail => Long_Long_Integer (Component.DC_Table),
                     others => <>)));
         end if;

         Internal.Restarts.Configure (Restart_State, Header.Restart);
         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               DC :=
                 Internal.Arithmetic.Decode_DC_Difference
                   (Decoder,
                    DC_Bins,
                    DC_Context,
                    Internal.Arithmetic.Value (Header.Arithmetic_State, Internal.Arithmetic.DC, Component.DC_Table));
               if not Results.Succeeded (DC.Outcome) then
                  return DC.Outcome;
               end if;

               declare
                  Sample : constant Integer := Predictor (Column, Row) + Integer (DC.Difference);
                  Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
               begin
                  if Sample not in 0 .. Max_Sample then
                     return
                       Results.Failure
                         (Errors.Make
                            (Errors.Coefficient_Invalid_Encoding,
                             (Detail => Long_Long_Integer (Sample), others => <>)));
                  end if;
                  Samples (1, Samples'First (2) + Row * Width + Column) := Sample;
               end;

               Decoded := Decoded + 1;
               declare
                  Outcome : Results.Result := Internal.Restarts.Advance_MCU (Restart_State);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome := Accept_Restart_When_Due;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            end loop;
         end loop;

         Ending := Internal.Bit_Streams.Read_Byte (Entropy);
         declare
            Outcome : constant Results.Result :=
              Decode_Hierarchical_Lossless_Continuation
                (Header, Object.Input, Ending, Samples'Access);
            Target : Raw_Component_View renames Components (1);
         begin
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            for Row in Natural range 0 .. Height - 1 loop
               for Column in Natural range 0 .. Width - 1 loop
                  Store_Raw_Sample
                    (Target,
                     Row,
                     Column,
                     Samples (1, Samples'First (2) + Row * Width + Column));
               end loop;
            end loop;
         end;

         return Results.Success;
      end Decode_Arithmetic_Lossless_Grayscale_Raw;
      pragma Unreferenced (Decode_Arithmetic_Lossless_Grayscale_Raw);

      function Decode_Arithmetic_Lossless_Two_Component_Raw return Results.Result is
         use type Internal.Bit_Streams.Entropy_Byte_Kind;

         type Context_Array is array (Component_Index range 1 .. 2) of
           Internal.Arithmetic.DC_Context_Index;
         type DC_Bin_Set_Array is array (Component_Index range 1 .. 2) of
           Internal.Arithmetic.Probability_Bin_Array (0 .. 63);

         Entropy : aliased Internal.Bit_Streams.Entropy_Reader (Object.Input);
         Decoder : Internal.Arithmetic.Decoder (Entropy'Access);
         DC_Bins : DC_Bin_Set_Array := [others => [others => Internal.Arithmetic.Initial_Probability_Bin]];
         DC_Contexts : Context_Array := [others => 0];
         DC : Internal.Arithmetic.DC_Result;
         Ending : Internal.Bit_Streams.Entropy_Read_Result;
         Restart_State : Internal.Restarts.Restart_State;
         Restart_Base : Natural := 0;
         Decoded : Natural := 0;
         Width : constant Natural := Natural (Internal.Frames.Width (Header.Frame));
         Height : constant Natural := Natural (Internal.Frames.Height (Header.Frame));
         Total : constant Natural := Width * Height;
         Samples : aliased Lossless_Sample_Array := [1 .. 2 => [1 .. Total => 0]];

         function Initial_Predictor return Integer is
         begin
            return
              2 **
                (Natural (Internal.Frames.Precision (Header.Frame))
                 - Natural (Internal.Scans.Successive_Low (Header.Scan))
                 - 1);
         end Initial_Predictor;

         function Stored (Component : Component_Index; Column, Row : Natural) return Integer is
           (Samples (Component, Samples'First (2) + Row * Width + Column));

         function Predictor (Component : Component_Index; Column, Row : Natural) return Integer is
            Ra : Integer;
            Rb : Integer;
            Rc : Integer;
         begin
            if Decoded = Restart_Base then
               return Initial_Predictor;
            elsif Column = 0 then
               return Stored (Component, Column, Row - 1);
            elsif Row = 0 then
               return Stored (Component, Column - 1, Row);
            end if;

            Ra := Stored (Component, Column - 1, Row);
            Rb := Stored (Component, Column, Row - 1);
            Rc := Stored (Component, Column - 1, Row - 1);

            case Internal.Scans.Spectral_Start (Header.Scan) is
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
               when others =>
                  return Initial_Predictor;
            end case;
         end Predictor;

         function Accept_Restart_When_Due return Results.Result is
            Marker : Internal.Bit_Streams.Entropy_Read_Result;
            Outcome : Results.Result;
         begin
            if Header.Restart = 0
              or else Internal.Restarts.MCUs_Until_Restart (Restart_State) /= 0
              or else Decoded = Total
            then
               return Results.Success;
            end if;

            Marker := Internal.Bit_Streams.Read_Byte (Entropy);
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Marker.Kind /= Internal.Bit_Streams.Restart_Marker then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Restart_Invalid_State,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            end if;

            Outcome := Internal.Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
            if Results.Succeeded (Outcome) then
               Restart_Base := Decoded;
               Internal.Arithmetic.Reset (Decoder);
               DC_Bins := [others => [others => Internal.Arithmetic.Initial_Probability_Bin]];
               DC_Contexts := [others => 0];
            end if;
            return Outcome;
         end Accept_Restart_When_Due;
      begin
         if Internal.Scans.Components (Header.Scan) /= 2 then
            return Results.Failure (Errors.Table_Invalid_Definition);
         end if;

         for Component_Index_Value in Component_Index range 1 .. 2 loop
            declare
               Scan_Component : constant Internal.Scans.Scan_Component :=
                 Internal.Scans.Component (Header.Scan, Component_Index_Value);
               Frame_Component : constant Internal.Frames.Frame_Component :=
                 Internal.Frames.Component (Header.Frame, Scan_Component.Frame_Component);
            begin
               if Frame_Component.Horizontal_Sampling /= 1
                 or else Frame_Component.Vertical_Sampling /= 1
                 or else not Internal.Arithmetic.Has_Table
                   (Header.Arithmetic_State, Internal.Arithmetic.DC, Scan_Component.DC_Table)
               then
                  return
                    Results.Failure
                      (Errors.Make
                         (Errors.Table_Invalid_Definition,
                          (Frame_Component => Scan_Component.Frame_Component,
                           Detail => Long_Long_Integer (Scan_Component.DC_Table),
                           others => <>)));
               end if;
            end;
         end loop;

         Internal.Restarts.Configure (Restart_State, Header.Restart);
         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               for Component_Index_Value in Component_Index range 1 .. 2 loop
                  declare
                     Scan_Component : constant Internal.Scans.Scan_Component :=
                       Internal.Scans.Component (Header.Scan, Component_Index_Value);
                  begin
                     DC :=
                       Internal.Arithmetic.Decode_DC_Difference
                         (Decoder,
                          DC_Bins (Component_Index_Value),
                          DC_Contexts (Component_Index_Value),
                          Internal.Arithmetic.Value
                            (Header.Arithmetic_State, Internal.Arithmetic.DC, Scan_Component.DC_Table));
                     if not Results.Succeeded (DC.Outcome) then
                        return DC.Outcome;
                     end if;

                     declare
                        Sample : constant Integer :=
                          Predictor (Component_Index_Value, Column, Row) + Integer (DC.Difference);
                        Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
                     begin
                        if Sample not in 0 .. Max_Sample then
                           return
                             Results.Failure
                               (Errors.Make
                                  (Errors.Coefficient_Invalid_Encoding,
                                   (Detail => Long_Long_Integer (Sample), others => <>)));
                        end if;
                        Samples
                          (Component_Index_Value, Samples'First (2) + Row * Width + Column) := Sample;
                     end;
                  end;
               end loop;

               Decoded := Decoded + 1;
               declare
                  Outcome : Results.Result := Internal.Restarts.Advance_MCU (Restart_State);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome := Accept_Restart_When_Due;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            end loop;
         end loop;

         Ending := Internal.Bit_Streams.Read_Byte (Entropy);
         declare
            Outcome : constant Results.Result :=
              Decode_Hierarchical_Lossless_Continuation
                (Header, Object.Input, Ending, Samples'Access);
         begin
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end;

         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               for Component_Index_Value in Component_Index range 1 .. 2 loop
                  declare
                     Target : Raw_Component_View renames Components (Component_Index_Value);
                     Index : constant Natural := Samples'First (2) + Row * Width + Column;
                  begin
                     Store_Raw_Sample (Target, Row, Column, Samples (Component_Index_Value, Index));
                  end;
               end loop;
            end loop;
         end loop;

         return Results.Success;
      end Decode_Arithmetic_Lossless_Two_Component_Raw;
      pragma Unreferenced (Decode_Arithmetic_Lossless_Two_Component_Raw);

      function Decode_Arithmetic_Lossless_Three_Component_Raw return Results.Result is
         use type Internal.Bit_Streams.Entropy_Byte_Kind;

         type Context_Array is array (Component_Index range 1 .. 3) of
           Internal.Arithmetic.DC_Context_Index;
         type DC_Bin_Set_Array is array (Component_Index range 1 .. 3) of
           Internal.Arithmetic.Probability_Bin_Array (0 .. 63);

         Entropy : aliased Internal.Bit_Streams.Entropy_Reader (Object.Input);
         Decoder : Internal.Arithmetic.Decoder (Entropy'Access);
         DC_Bins : DC_Bin_Set_Array := [others => [others => Internal.Arithmetic.Initial_Probability_Bin]];
         DC_Contexts : Context_Array := [others => 0];
         DC : Internal.Arithmetic.DC_Result;
         Ending : Internal.Bit_Streams.Entropy_Read_Result;
         Restart_State : Internal.Restarts.Restart_State;
         Restart_Base : Natural := 0;
         Decoded : Natural := 0;
         Width : constant Natural := Natural (Internal.Frames.Width (Header.Frame));
         Height : constant Natural := Natural (Internal.Frames.Height (Header.Frame));
         Total : constant Natural := Width * Height;
         Samples : aliased Lossless_Sample_Array := [1 .. 3 => [1 .. Total => 0]];

         function Initial_Predictor return Integer is
         begin
            return
              2 **
                (Natural (Internal.Frames.Precision (Header.Frame))
                 - Natural (Internal.Scans.Successive_Low (Header.Scan))
                 - 1);
         end Initial_Predictor;

         function Stored (Component : Component_Index; Column, Row : Natural) return Integer is
           (Samples (Component, Samples'First (2) + Row * Width + Column));

         function Predictor (Component : Component_Index; Column, Row : Natural) return Integer is
            Ra : Integer;
            Rb : Integer;
            Rc : Integer;
         begin
            if Decoded = Restart_Base then
               return Initial_Predictor;
            elsif Column = 0 then
               return Stored (Component, Column, Row - 1);
            elsif Row = 0 then
               return Stored (Component, Column - 1, Row);
            end if;

            Ra := Stored (Component, Column - 1, Row);
            Rb := Stored (Component, Column, Row - 1);
            Rc := Stored (Component, Column - 1, Row - 1);

            case Internal.Scans.Spectral_Start (Header.Scan) is
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
               when others =>
                  return Initial_Predictor;
            end case;
         end Predictor;

         function Accept_Restart_When_Due return Results.Result is
            Marker : Internal.Bit_Streams.Entropy_Read_Result;
            Outcome : Results.Result;
         begin
            if Header.Restart = 0
              or else Internal.Restarts.MCUs_Until_Restart (Restart_State) /= 0
              or else Decoded = Total
            then
               return Results.Success;
            end if;

            Marker := Internal.Bit_Streams.Read_Byte (Entropy);
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Marker.Kind /= Internal.Bit_Streams.Restart_Marker then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Restart_Invalid_State,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            end if;

            Outcome := Internal.Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
            if Results.Succeeded (Outcome) then
               Restart_Base := Decoded;
               Internal.Arithmetic.Reset (Decoder);
               DC_Bins := [others => [others => Internal.Arithmetic.Initial_Probability_Bin]];
               DC_Contexts := [others => 0];
            end if;
            return Outcome;
         end Accept_Restart_When_Due;
      begin
         if Internal.Scans.Components (Header.Scan) /= 3 then
            return Results.Failure (Errors.Table_Invalid_Definition);
         end if;

         for Component_Index_Value in Component_Index range 1 .. 3 loop
            declare
               Scan_Component : constant Internal.Scans.Scan_Component :=
                 Internal.Scans.Component (Header.Scan, Component_Index_Value);
               Frame_Component : constant Internal.Frames.Frame_Component :=
                 Internal.Frames.Component (Header.Frame, Scan_Component.Frame_Component);
            begin
               if Frame_Component.Horizontal_Sampling /= 1
                 or else Frame_Component.Vertical_Sampling /= 1
                 or else not Internal.Arithmetic.Has_Table
                   (Header.Arithmetic_State, Internal.Arithmetic.DC, Scan_Component.DC_Table)
               then
                  return
                    Results.Failure
                      (Errors.Make
                         (Errors.Table_Invalid_Definition,
                          (Frame_Component => Scan_Component.Frame_Component,
                           Detail => Long_Long_Integer (Scan_Component.DC_Table),
                           others => <>)));
               end if;
            end;
         end loop;

         Internal.Restarts.Configure (Restart_State, Header.Restart);
         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               for Component_Index_Value in Component_Index range 1 .. 3 loop
                  declare
                     Scan_Component : constant Internal.Scans.Scan_Component :=
                       Internal.Scans.Component (Header.Scan, Component_Index_Value);
                  begin
                     DC :=
                       Internal.Arithmetic.Decode_DC_Difference
                         (Decoder,
                          DC_Bins (Component_Index_Value),
                          DC_Contexts (Component_Index_Value),
                          Internal.Arithmetic.Value
                            (Header.Arithmetic_State, Internal.Arithmetic.DC, Scan_Component.DC_Table));
                     if not Results.Succeeded (DC.Outcome) then
                        return DC.Outcome;
                     end if;

                     declare
                        Sample : constant Integer :=
                          Predictor (Component_Index_Value, Column, Row) + Integer (DC.Difference);
                        Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
                     begin
                        if Sample not in 0 .. Max_Sample then
                           return
                             Results.Failure
                               (Errors.Make
                                  (Errors.Coefficient_Invalid_Encoding,
                                   (Detail => Long_Long_Integer (Sample), others => <>)));
                        end if;
                        Samples
                          (Component_Index_Value, Samples'First (2) + Row * Width + Column) := Sample;
                     end;
                  end;
               end loop;

               Decoded := Decoded + 1;
               declare
                  Outcome : Results.Result := Internal.Restarts.Advance_MCU (Restart_State);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome := Accept_Restart_When_Due;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            end loop;
         end loop;

         Ending := Internal.Bit_Streams.Read_Byte (Entropy);
         declare
            Outcome : constant Results.Result :=
              Decode_Hierarchical_Lossless_Continuation
                (Header, Object.Input, Ending, Samples'Access);
         begin
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end;

         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               for Component_Index_Value in Component_Index range 1 .. 3 loop
                  declare
                     Target : Raw_Component_View renames Components (Component_Index_Value);
                     Index : constant Natural := Samples'First (2) + Row * Width + Column;
                  begin
                     Store_Raw_Sample (Target, Row, Column, Samples (Component_Index_Value, Index));
                  end;
               end loop;
            end loop;
         end loop;

         return Results.Success;
      end Decode_Arithmetic_Lossless_Three_Component_Raw;
      pragma Unreferenced (Decode_Arithmetic_Lossless_Three_Component_Raw);

      function Decode_Arithmetic_Lossless_Four_Component_Raw return Results.Result is
         use type Internal.Bit_Streams.Entropy_Byte_Kind;

         type Context_Array is array (Component_Index range 1 .. 4) of
           Internal.Arithmetic.DC_Context_Index;
         type DC_Bin_Set_Array is array (Component_Index range 1 .. 4) of
           Internal.Arithmetic.Probability_Bin_Array (0 .. 63);

         Entropy : aliased Internal.Bit_Streams.Entropy_Reader (Object.Input);
         Decoder : Internal.Arithmetic.Decoder (Entropy'Access);
         DC_Bins : DC_Bin_Set_Array := [others => [others => Internal.Arithmetic.Initial_Probability_Bin]];
         DC_Contexts : Context_Array := [others => 0];
         DC : Internal.Arithmetic.DC_Result;
         Ending : Internal.Bit_Streams.Entropy_Read_Result;
         Restart_State : Internal.Restarts.Restart_State;
         Restart_Base : Natural := 0;
         Decoded : Natural := 0;
         Width : constant Natural := Natural (Internal.Frames.Width (Header.Frame));
         Height : constant Natural := Natural (Internal.Frames.Height (Header.Frame));
         Total : constant Natural := Width * Height;
         Samples : aliased Lossless_Sample_Array := [1 .. 4 => [1 .. Total => 0]];

         function Initial_Predictor return Integer is
         begin
            return
              2 **
                (Natural (Internal.Frames.Precision (Header.Frame))
                 - Natural (Internal.Scans.Successive_Low (Header.Scan))
                 - 1);
         end Initial_Predictor;

         function Stored (Component : Component_Index; Column, Row : Natural) return Integer is
           (Samples (Component, Samples'First (2) + Row * Width + Column));

         function Predictor (Component : Component_Index; Column, Row : Natural) return Integer is
            Ra : Integer;
            Rb : Integer;
            Rc : Integer;
         begin
            if Decoded = Restart_Base then
               return Initial_Predictor;
            elsif Column = 0 then
               return Stored (Component, Column, Row - 1);
            elsif Row = 0 then
               return Stored (Component, Column - 1, Row);
            end if;

            Ra := Stored (Component, Column - 1, Row);
            Rb := Stored (Component, Column, Row - 1);
            Rc := Stored (Component, Column - 1, Row - 1);

            case Internal.Scans.Spectral_Start (Header.Scan) is
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
               when others =>
                  return Initial_Predictor;
            end case;
         end Predictor;

         function Accept_Restart_When_Due return Results.Result is
            Marker : Internal.Bit_Streams.Entropy_Read_Result;
            Outcome : Results.Result;
         begin
            if Header.Restart = 0
              or else Internal.Restarts.MCUs_Until_Restart (Restart_State) /= 0
              or else Decoded = Total
            then
               return Results.Success;
            end if;

            Marker := Internal.Bit_Streams.Read_Byte (Entropy);
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Marker.Kind /= Internal.Bit_Streams.Restart_Marker then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Restart_Invalid_State,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            end if;

            Outcome := Internal.Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
            if Results.Succeeded (Outcome) then
               Restart_Base := Decoded;
               Internal.Arithmetic.Reset (Decoder);
               DC_Bins := [others => [others => Internal.Arithmetic.Initial_Probability_Bin]];
               DC_Contexts := [others => 0];
            end if;
            return Outcome;
         end Accept_Restart_When_Due;
      begin
         if Internal.Scans.Components (Header.Scan) /= 4 then
            return Results.Failure (Errors.Table_Invalid_Definition);
         end if;

         for Component_Index_Value in Component_Index range 1 .. 4 loop
            declare
               Scan_Component : constant Internal.Scans.Scan_Component :=
                 Internal.Scans.Component (Header.Scan, Component_Index_Value);
               Frame_Component : constant Internal.Frames.Frame_Component :=
                 Internal.Frames.Component (Header.Frame, Scan_Component.Frame_Component);
            begin
               if Frame_Component.Horizontal_Sampling /= 1
                 or else Frame_Component.Vertical_Sampling /= 1
                 or else not Internal.Arithmetic.Has_Table
                   (Header.Arithmetic_State, Internal.Arithmetic.DC, Scan_Component.DC_Table)
               then
                  return
                    Results.Failure
                      (Errors.Make
                         (Errors.Table_Invalid_Definition,
                          (Frame_Component => Scan_Component.Frame_Component,
                           Detail => Long_Long_Integer (Scan_Component.DC_Table),
                           others => <>)));
               end if;
            end;
         end loop;

         Internal.Restarts.Configure (Restart_State, Header.Restart);
         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               for Component_Index_Value in Component_Index range 1 .. 4 loop
                  declare
                     Scan_Component : constant Internal.Scans.Scan_Component :=
                       Internal.Scans.Component (Header.Scan, Component_Index_Value);
                  begin
                     DC :=
                       Internal.Arithmetic.Decode_DC_Difference
                         (Decoder,
                          DC_Bins (Component_Index_Value),
                          DC_Contexts (Component_Index_Value),
                          Internal.Arithmetic.Value
                            (Header.Arithmetic_State, Internal.Arithmetic.DC, Scan_Component.DC_Table));
                     if not Results.Succeeded (DC.Outcome) then
                        return DC.Outcome;
                     end if;

                     declare
                        Sample : constant Integer :=
                          Predictor (Component_Index_Value, Column, Row) + Integer (DC.Difference);
                        Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
                     begin
                        if Sample not in 0 .. Max_Sample then
                           return
                             Results.Failure
                               (Errors.Make
                                  (Errors.Coefficient_Invalid_Encoding,
                                   (Detail => Long_Long_Integer (Sample), others => <>)));
                        end if;
                        Samples
                          (Component_Index_Value, Samples'First (2) + Row * Width + Column) := Sample;
                     end;
                  end;
               end loop;

               Decoded := Decoded + 1;
               declare
                  Outcome : Results.Result := Internal.Restarts.Advance_MCU (Restart_State);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome := Accept_Restart_When_Due;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            end loop;
         end loop;

         Ending := Internal.Bit_Streams.Read_Byte (Entropy);
         declare
            Outcome : constant Results.Result :=
              Decode_Hierarchical_Lossless_Continuation
                (Header, Object.Input, Ending, Samples'Access);
         begin
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end;

         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               for Component_Index_Value in Component_Index range 1 .. 4 loop
                  declare
                     Target : Raw_Component_View renames Components (Component_Index_Value);
                     Index : constant Natural := Samples'First (2) + Row * Width + Column;
                  begin
                     Store_Raw_Sample (Target, Row, Column, Samples (Component_Index_Value, Index));
                  end;
               end loop;
            end loop;
         end loop;

         return Results.Success;
      end Decode_Arithmetic_Lossless_Four_Component_Raw;
      pragma Unreferenced (Decode_Arithmetic_Lossless_Four_Component_Raw);
   begin
      if Object.Current_State not in Initialized | Header_Ready then
         Fail (Object, Errors.Invalid_State);
         return Results.Failure (Object.First_Error);
      end if;

      if Object.Current_State = Initialized then
         Header_Outcome := Read_Header (Object);
         if not Results.Succeeded (Header_Outcome) then
            return Header_Outcome;
         end if;
      end if;

      Header := Object.Saved_Header;
      if not Internal.Frames.Height_Defined (Header.Frame) then
         Header_Outcome := Define_Pending_Height_From_Raw_Output;
         if not Results.Succeeded (Header_Outcome) then
            Fail_With (Object, Header_Outcome.First_Error);
            return Results.Failure (Object.First_Error);
         end if;

         Object.Saved_Header.Frame := Header.Frame;
         Object.Header_Info := To_Image_Info (Object.Saved_Header);
      end if;

      if Internal.Frames.Mode (Header.Frame)
                not in Baseline_DCT | Extended_Sequential_DCT | Progressive_DCT |
                       Differential_Sequential_DCT | Differential_Progressive_DCT |
                       Lossless | Differential_Lossless
        or else not Progressive_Raw_Scope_Supported
      then
         Fail (Object, Errors.Unsupported_Feature);
         return Results.Failure (Object.First_Error);
      end if;

      Header_Outcome := Validate_Raw_Output;
      if not Results.Succeeded (Header_Outcome) then
         Fail_With (Object, Header_Outcome.First_Error);
         return Results.Failure (Object.First_Error);
      end if;

      if Internal.Frames.Mode (Header.Frame) in Lossless | Differential_Lossless then
         if Header.Entropy not in Huffman | Arithmetic
           or else Internal.Frames.Precision (Header.Frame) not in 8 | 12
         then
            Fail (Object, Errors.Unsupported_Feature);
            return Results.Failure (Object.First_Error);
         end if;

         Header_Outcome := Decode_Lossless_Raw_From_Coefficients;
         if not Results.Succeeded (Header_Outcome) then
            Fail_With (Object, Header_Outcome.First_Error);
            return Results.Failure (Object.First_Error);
         end if;

         return Results.Success;
      end if;

      Header_Outcome := Missing_Quantization_Table;
      if not Results.Succeeded (Header_Outcome) then
         Fail_With (Object, Header_Outcome.First_Error);
         return Results.Failure (Object.First_Error);
      end if;

      Required_Blocks := Internal.Frames.Total_Blocks (Header.Frame);
      if Coefficient_Bytes (Required_Blocks) > Object.Decode_Limits.Max_Coefficient_Bytes
        or else Coefficient_Bytes (Required_Blocks) + Component_Plane_Bytes > Object.Decode_Limits.Max_Allocation_Bytes
      then
         Fail_With (Object, Raw_Output_Error (Long_Long_Integer (Required_Blocks)));
         return Results.Failure (Object.First_Error);
      end if;

      declare
         Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Required_Blocks)) := [others => [others => 0]];
      begin
         Object.Current_State := Decoding;
         declare
            Result : constant Internal.Decoder.Coefficient_Result :=
              (if Internal.Frames.Mode (Header.Frame) in Progressive_DCT | Differential_Progressive_DCT then
                 Internal.Decoder.Decode_Progressive_Coefficients (Header, Object.Input, Blocks)
               elsif Header.Entropy = Entropy_Mode'Val (1) then
                 Internal.Decoder.Decode_Arithmetic_Coefficients (Header, Object.Input, Blocks)
               else
                 Internal.Decoder.Decode_Baseline_Coefficients (Header, Object.Input, Blocks));
         begin
            if not Results.Succeeded (Result.Outcome) then
               Fail_With (Object, Result.Outcome.First_Error);
               return Results.Failure (Object.First_Error);
            end if;

            declare
               Continuation_Outcome : constant Results.Result :=
                 Compose_Hierarchical_DCT_Continuation (Object, Result, Blocks);
            begin
               if not Results.Succeeded (Continuation_Outcome) then
                  Fail_With (Object, Continuation_Outcome.First_Error);
                  return Results.Failure (Object.First_Error);
               end if;
            end;

            Object.Saved_Header := Result.Header;
            Object.Header_Info := To_Image_Info (Result.Header);
         end;

         Store_Raw_Blocks
           (Blocks,
            Internal.Frames.Mode (Header.Frame) in Progressive_DCT | Differential_Progressive_DCT
            or else Internal.Scans.Components (Header.Scan) = 1);
      end;

      Object.Current_State := Completed;
      return Results.Success;
   end Decode_Raw_Components;

   function Decode_Image (Object : in out Decoder; Output : in out Images.Mutable_Image_View) return Results.Result is
      Header_Outcome : Results.Result;
      Header : Internal.Decoder.Header_Result;
      Frame_Component : Internal.Frames.Frame_Component;
      Table : Internal.Quantization.Quantization_Table;
      Required_Blocks : Block_Count;
      Expected_Bytes : Byte_Count;
      Components : Component_Count;
      Header_Color_Model : Encoded_Color_Model;
      Expected_Width : Image_Width;
      Expected_Height : Image_Height;

      function Output_Error return Errors.Error is
        (Errors.Make
           (Errors.Output_Limit_Exceeded,
            (Detail =>
               Long_Long_Integer
                 (Images.Minimum_Row_Bytes (Output.Descriptor.Width, Output.Descriptor.Format)
                  * Byte_Count (Output.Descriptor.Height)),
             others => <>)));

      function Coefficient_Bytes (Blocks : Block_Count) return Byte_Count is
        (Byte_Count (Blocks) * 64 * 4);

      function Component_Plane_Bytes return Byte_Count is
         Result : Byte_Count := 0;
         Item : Internal.Frames.Frame_Component;
      begin
         for Component in Component_Index range 1 .. Component_Index (Internal.Frames.Components (Header.Frame)) loop
            Item := Internal.Frames.Component (Header.Frame, Component);
            Result := Result + Byte_Count (Item.Component_Width) * Byte_Count (Item.Component_Height);
         end loop;

         return Result;
      end Component_Plane_Bytes;

      function Missing_Quantization_Table return Results.Result is
         Item : Internal.Frames.Frame_Component;
      begin
         for Component in Component_Index range 1 .. Component_Index (Internal.Frames.Components (Header.Frame)) loop
            Item := Internal.Frames.Component (Header.Frame, Component);
            if not Internal.Quantization.Has_Table (Header.Quantization_State, Item.Quantization_Table) then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Table_Invalid_Definition,
                       (Frame_Component => Component,
                        Detail => Long_Long_Integer (Item.Quantization_Table),
                        others => <>)));
            end if;
         end loop;

         return Results.Success;
      end Missing_Quantization_Table;

      function Reduction_Factor return Natural is
      begin
         case Object.Decode_Options.IDCT_Scaling is
            when Full_Size => return 1;
            when Half_Size => return 2;
            when Quarter_Size => return 4;
            when Eighth_Size => return 8;
         end case;
      end Reduction_Factor;

      function Reduced_Dimension (Value : Natural) return Natural is
      begin
         return (Value + Reduction_Factor - 1) / Reduction_Factor;
      end Reduced_Dimension;

      function Emits_Reduced_Pixel (Source_X : Natural; Source_Y : Natural) return Boolean is
      begin
         return Source_X mod Reduction_Factor = 0 and then Source_Y mod Reduction_Factor = 0;
      end Emits_Reduced_Pixel;

      function Active_Orientation return Metadata.Exif_Orientation is
      begin
         if Object.Decode_Options.Apply_Exif_Orientation
           and then Header.Has_Exif_Orientation
         then
            return Header.Exif_Orientation;
         end if;
         return Metadata.Orientation_Normal;
      end Active_Orientation;

      function Swaps_Dimensions (Orientation : Metadata.Exif_Orientation) return Boolean is
      begin
         return Orientation in
           Metadata.Orientation_Transpose
           | Metadata.Orientation_Rotate_90
           | Metadata.Orientation_Transverse
           | Metadata.Orientation_Rotate_270;
      end Swaps_Dimensions;

      function Pending_Source_Height_From_Image_Output return Image_Height is
         Reduced_Output_Height : Natural;
      begin
         if Object.Decode_Options.Apply_Exif_Orientation
           and then Header.Has_Exif_Orientation
           and then Swaps_Dimensions (Header.Exif_Orientation)
         then
            Reduced_Output_Height := Natural (Output.Descriptor.Width);
         else
            Reduced_Output_Height := Natural (Output.Descriptor.Height);
         end if;

         return Image_Height (Reduced_Output_Height * Reduction_Factor);
      end Pending_Source_Height_From_Image_Output;

      procedure Map_Output_Coordinate
        (Source_X : Natural;
         Source_Y : Natural;
         Target_X : out Natural;
         Target_Y : out Natural)
      is
         Width : constant Natural := Reduced_Dimension (Natural (Internal.Frames.Width (Header.Frame)));
         Height : constant Natural := Reduced_Dimension (Natural (Internal.Frames.Height (Header.Frame)));
         Reduced_X : constant Natural := Source_X / Reduction_Factor;
         Reduced_Y : constant Natural := Source_Y / Reduction_Factor;
      begin
         case Active_Orientation is
            when Metadata.Orientation_Normal | Metadata.Orientation_Unknown =>
               Target_X := Reduced_X;
               Target_Y := Reduced_Y;
            when Metadata.Orientation_Mirror_Horizontal =>
               Target_X := Width - 1 - Reduced_X;
               Target_Y := Reduced_Y;
            when Metadata.Orientation_Rotate_180 =>
               Target_X := Width - 1 - Reduced_X;
               Target_Y := Height - 1 - Reduced_Y;
            when Metadata.Orientation_Mirror_Vertical =>
               Target_X := Reduced_X;
               Target_Y := Height - 1 - Reduced_Y;
            when Metadata.Orientation_Transpose =>
               Target_X := Reduced_Y;
               Target_Y := Reduced_X;
            when Metadata.Orientation_Rotate_90 =>
               Target_X := Height - 1 - Reduced_Y;
               Target_Y := Reduced_X;
            when Metadata.Orientation_Transverse =>
               Target_X := Height - 1 - Reduced_Y;
               Target_Y := Width - 1 - Reduced_X;
            when Metadata.Orientation_Rotate_270 =>
               Target_X := Reduced_Y;
               Target_Y := Width - 1 - Reduced_X;
         end case;
      end Map_Output_Coordinate;

      function Can_Write_Direct_Output_Rows (Width : Natural; Height : Natural) return Boolean is
        (Reduction_Factor = 1
         and then Active_Orientation in Metadata.Orientation_Normal | Metadata.Orientation_Unknown
         and then Natural (Output.Descriptor.Width) = Width
         and then Natural (Output.Descriptor.Height) = Height);

      procedure Write_Gray_Pixel
        (Source_X : Natural;
         Source_Y : Natural;
         Value : Byte) is
         Target_X : Natural;
         Target_Y : Natural;
      begin
         if Emits_Reduced_Pixel (Source_X, Source_Y) then
            Map_Output_Coordinate (Source_X, Source_Y, Target_X, Target_Y);
            Internal.Colors.Write_Gray (Output, Target_X, Target_Y, Value, Object.Decode_Options.Alpha_Fill);
         end if;
      end Write_Gray_Pixel;

      procedure Write_Gray_Alpha_Pixel
        (Source_X : Natural;
         Source_Y : Natural;
         Gray : Byte;
         Alpha : Byte) is
         Target_X : Natural;
         Target_Y : Natural;
      begin
         if Emits_Reduced_Pixel (Source_X, Source_Y) then
            Map_Output_Coordinate (Source_X, Source_Y, Target_X, Target_Y);
            Internal.Colors.Write_Gray_Alpha (Output, Target_X, Target_Y, Gray, Alpha);
         end if;
      end Write_Gray_Alpha_Pixel;

      function Decode_Lossless_Grayscale return Results.Result is
         use type Internal.Bit_Streams.Entropy_Byte_Kind;
         use type Internal.Bit_Streams.Entropy_Bits;

         Component : constant Internal.Scans.Scan_Component := Internal.Scans.Component (Header.Scan, 1);
         Compile : Internal.Huffman.Compile_Result;
         Entropy : aliased Internal.Bit_Streams.Entropy_Reader (Object.Input);
         Bits : Internal.Bit_Streams.Bit_Reader (Entropy'Access);
         Symbol : Internal.Huffman.Decode_Result;
         Extended : Internal.Bit_Streams.Sign_Extend_Result;
         Ending : Internal.Bit_Streams.Entropy_Read_Result;
         Restart_State : Internal.Restarts.Restart_State;
         Restart_Base : Natural := 0;
         Decoded : Natural := 0;
         Total : constant Natural :=
           Natural (Internal.Frames.Width (Header.Frame)) * Natural (Internal.Frames.Height (Header.Frame));
         Samples : aliased Lossless_Sample_Array := [1 .. 1 => [1 .. Total => 0]];

         function Read_Category_Bits
           (Category : Internal.Bit_Streams.Entropy_Category) return Internal.Bit_Streams.Sign_Extend_Result
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

         function Initial_Predictor return Integer is
         begin
            return
              2 **
                (Natural (Internal.Frames.Precision (Header.Frame))
                 - Natural (Internal.Scans.Successive_Low (Header.Scan))
                 - 1);
         end Initial_Predictor;

         function Predictor (Column, Row : Natural) return Integer is
            Width : constant Natural := Natural (Internal.Frames.Width (Header.Frame));
            function Stored (Stored_Column, Stored_Row : Natural) return Integer is
              (Samples (1, Samples'First (2) + Stored_Row * Width + Stored_Column));

            Ra : Integer;
            Rb : Integer;
            Rc : Integer;
         begin
            if Decoded = Restart_Base then
               return Initial_Predictor;
            elsif Column = 0 then
               return Stored (Column, Row - 1);
            elsif Row = 0 then
               return Stored (Column - 1, Row);
            end if;

            Ra := Stored (Column - 1, Row);
            Rb := Stored (Column, Row - 1);
            Rc := Stored (Column - 1, Row - 1);

            case Internal.Scans.Spectral_Start (Header.Scan) is
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
               when others =>
                  return Initial_Predictor;
            end case;
         end Predictor;

         function Output_Byte (Sample : Integer) return Byte is
            Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
         begin
            if Internal.Frames.Precision (Header.Frame) = 8 then
               return Byte (Sample);
            else
               return Byte ((Sample * Integer (Byte'Last) + Max_Sample / 2) / Max_Sample);
            end if;
         end Output_Byte;

         function Accept_Restart_When_Due return Results.Result is
            Marker : Internal.Bit_Streams.Entropy_Read_Result;
            Outcome : Results.Result;
         begin
            if Header.Restart = 0
              or else Internal.Restarts.MCUs_Until_Restart (Restart_State) /= 0
              or else Decoded = Total
            then
               return Results.Success;
            end if;

            Internal.Bit_Streams.Byte_Align (Bits);
            Marker := Internal.Bit_Streams.Read_Byte (Entropy);
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Marker.Kind /= Internal.Bit_Streams.Restart_Marker then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Restart_Invalid_State,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            end if;

            Outcome := Internal.Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
            if Results.Succeeded (Outcome) then
               Restart_Base := Decoded;
            end if;
            return Outcome;
         end Accept_Restart_When_Due;
      begin
         if Internal.Scans.Components (Header.Scan) /= 1
           or else not Internal.Huffman.Has_Table (Header.Huffman_State, Internal.Huffman.DC, Component.DC_Table)
         then
            return
              Results.Failure
                (Errors.Make
                   (Errors.Table_Invalid_Definition,
                    (Frame_Component => Component.Frame_Component,
                     Detail => Long_Long_Integer (Component.DC_Table),
                     others => <>)));
         end if;

         Compile :=
           Internal.Huffman.Compile
             (Internal.Huffman.Definition (Header.Huffman_State, Internal.Huffman.DC, Component.DC_Table));
         if not Results.Succeeded (Compile.Outcome) then
            return Compile.Outcome;
         end if;

         Internal.Restarts.Configure (Restart_State, Header.Restart);
         for Row in Natural range 0 .. Natural (Internal.Frames.Height (Header.Frame)) - 1 loop
            for Column in Natural range 0 .. Natural (Internal.Frames.Width (Header.Frame)) - 1 loop
               Symbol := Internal.Huffman.Decode (Compile.Table, Bits);
               if not Results.Succeeded (Symbol.Outcome) then
                  return Symbol.Outcome;
               elsif Symbol.Symbol > 16 then
                  return
                    Results.Failure
                      (Errors.Make
                         (Errors.Coefficient_Invalid_Encoding,
                          (Source => Symbol.Source,
                           Detail => Long_Long_Integer (Symbol.Symbol),
                           others => <>)));
               end if;

               Extended := Read_Category_Bits (Internal.Bit_Streams.Entropy_Category (Symbol.Symbol));
               if not Results.Succeeded (Extended.Outcome) then
                  return Extended.Outcome;
               end if;

               declare
                  Sample : constant Integer := Predictor (Column, Row) + Integer (Extended.Value);
                  Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
               begin
                  if Sample not in 0 .. Max_Sample then
                     return
                       Results.Failure
                         (Errors.Make
                            (Errors.Coefficient_Invalid_Encoding,
                             (Detail => Long_Long_Integer (Sample), others => <>)));
                  end if;
                  Samples (1, Samples'First (2) + Row * Natural (Internal.Frames.Width (Header.Frame)) + Column) :=
                    Sample;
               end;

               Decoded := Decoded + 1;
               declare
                  Outcome : Results.Result := Internal.Restarts.Advance_MCU (Restart_State);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome := Accept_Restart_When_Due;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            end loop;
         end loop;

         Internal.Bit_Streams.Byte_Align (Bits);
         Ending := Internal.Bit_Streams.Read_Byte (Entropy);
         declare
            Outcome : constant Results.Result :=
              Decode_Hierarchical_Lossless_Continuation
                (Header, Object.Input, Ending, Samples'Access);
         begin
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end;

         declare
            Width : constant Natural := Natural (Internal.Frames.Width (Header.Frame));
            Height : constant Natural := Natural (Internal.Frames.Height (Header.Frame));
         begin
            if Can_Write_Direct_Output_Rows (Width, Height) then
               for Row in Natural range 0 .. Height - 1 loop
                  declare
                     Gray_Row : Streams.Byte_Array (1 .. Width);
                     Written : Natural;
                  begin
                     for Column in Natural range 0 .. Width - 1 loop
                        Gray_Row (Gray_Row'First + Column) :=
                          Output_Byte (Samples (1, Samples'First (2) + Row * Width + Column));
                     end loop;

                     Internal.Colors.Write_Gray_Row
                       (Output,
                        Row,
                        Gray_Row,
                        0,
                        Width,
                        Object.Decode_Options.Alpha_Fill,
                        Written);

                     if Written /= Width then
                        for Column in Natural range 0 .. Width - 1 loop
                           Write_Gray_Pixel (Column, Row, Gray_Row (Gray_Row'First + Column));
                        end loop;
                     end if;
                  end;
               end loop;
            else
               for Row in Natural range 0 .. Height - 1 loop
                  for Column in Natural range 0 .. Width - 1 loop
                     Write_Gray_Pixel
                       (Column,
                        Row,
                        Output_Byte (Samples (1, Samples'First (2) + Row * Width + Column)));
                  end loop;
               end loop;
            end if;
         end;

         return Results.Success;
      end Decode_Lossless_Grayscale;
      pragma Unreferenced (Decode_Lossless_Grayscale);

      procedure Write_YCbCr_Pixel
        (Source_X : Natural;
         Source_Y : Natural;
         Y : Byte;
         Cb : Byte;
         Cr : Byte) is
         Target_X : Natural;
         Target_Y : Natural;
      begin
         if Emits_Reduced_Pixel (Source_X, Source_Y) then
            Map_Output_Coordinate (Source_X, Source_Y, Target_X, Target_Y);
            Internal.Colors.Write_YCbCr (Output, Target_X, Target_Y, Y, Cb, Cr, Object.Decode_Options.Alpha_Fill);
         end if;
      end Write_YCbCr_Pixel;

      procedure Write_RGB_Pixel
        (Source_X : Natural;
         Source_Y : Natural;
         R : Byte;
         G : Byte;
         B : Byte) is
         Target_X : Natural;
         Target_Y : Natural;
      begin
         if Emits_Reduced_Pixel (Source_X, Source_Y) then
            Map_Output_Coordinate (Source_X, Source_Y, Target_X, Target_Y);
            Internal.Colors.Write_RGB (Output, Target_X, Target_Y, R, G, B, Object.Decode_Options.Alpha_Fill);
         end if;
      end Write_RGB_Pixel;

      procedure Write_Four_Component_Pixel
        (Source_X : Natural;
         Source_Y : Natural;
         C1 : Byte;
         C2 : Byte;
         C3 : Byte;
         C4 : Byte) is
         Target_X : Natural;
         Target_Y : Natural;
      begin
         if Emits_Reduced_Pixel (Source_X, Source_Y) then
            Map_Output_Coordinate (Source_X, Source_Y, Target_X, Target_Y);
            if Header_Color_Model = YCCK then
               Internal.Colors.Write_YCCK
                 (Output, Target_X, Target_Y, C1, C2, C3, C4, Object.Decode_Options.Alpha_Fill);
            elsif Header_Color_Model = CMYK then
               Internal.Colors.Write_CMYK
                 (Output, Target_X, Target_Y, C1, C2, C3, C4, Object.Decode_Options.Alpha_Fill);
            else
               Internal.Colors.Write_RGB (Output, Target_X, Target_Y, C1, C2, C3, C4);
            end if;
         end if;
      end Write_Four_Component_Pixel;

      function Decode_Lossless_Three_Component return Results.Result is
         use type Internal.Bit_Streams.Entropy_Byte_Kind;
         use type Internal.Bit_Streams.Entropy_Bits;

         type Compiled_Array is array (Component_Index range 1 .. 3) of Internal.Huffman.Compiled_Huffman;

         Entropy : aliased Internal.Bit_Streams.Entropy_Reader (Object.Input);
         Bits : Internal.Bit_Streams.Bit_Reader (Entropy'Access);
         Compile : Internal.Huffman.Compile_Result;
         Tables : Compiled_Array;
         Symbol : Internal.Huffman.Decode_Result;
         Extended : Internal.Bit_Streams.Sign_Extend_Result;
         Ending : Internal.Bit_Streams.Entropy_Read_Result;
         Restart_State : Internal.Restarts.Restart_State;
         Restart_Base : Natural := 0;
         Decoded : Natural := 0;
         Width : constant Natural := Natural (Internal.Frames.Width (Header.Frame));
         Height : constant Natural := Natural (Internal.Frames.Height (Header.Frame));
         Total : constant Natural := Width * Height;
         Samples : aliased Lossless_Sample_Array := [1 .. 3 => [1 .. Total => 0]];

         function Read_Category_Bits
           (Category : Internal.Bit_Streams.Entropy_Category) return Internal.Bit_Streams.Sign_Extend_Result
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

         function Initial_Predictor return Integer is
         begin
            return
              2 **
                (Natural (Internal.Frames.Precision (Header.Frame))
                 - Natural (Internal.Scans.Successive_Low (Header.Scan))
                 - 1);
         end Initial_Predictor;

         function Stored (Component : Component_Index; Column, Row : Natural) return Integer is
           (Samples (Component, Samples'First (2) + Row * Width + Column));

         function Output_Byte (Sample : Integer) return Byte is
            Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
         begin
            if Internal.Frames.Precision (Header.Frame) = 8 then
               return Byte (Sample);
            else
               return Byte ((Sample * Integer (Byte'Last) + Max_Sample / 2) / Max_Sample);
            end if;
         end Output_Byte;

         function Predictor (Component : Component_Index; Column, Row : Natural) return Integer is
            Ra : Integer;
            Rb : Integer;
            Rc : Integer;
         begin
            if Decoded = Restart_Base then
               return Initial_Predictor;
            elsif Column = 0 then
               return Stored (Component, Column, Row - 1);
            elsif Row = 0 then
               return Stored (Component, Column - 1, Row);
            end if;

            Ra := Stored (Component, Column - 1, Row);
            Rb := Stored (Component, Column, Row - 1);
            Rc := Stored (Component, Column - 1, Row - 1);

            case Internal.Scans.Spectral_Start (Header.Scan) is
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
               when others =>
                  return Initial_Predictor;
            end case;
         end Predictor;

         function Accept_Restart_When_Due return Results.Result is
            Marker : Internal.Bit_Streams.Entropy_Read_Result;
            Outcome : Results.Result;
         begin
            if Header.Restart = 0
              or else Internal.Restarts.MCUs_Until_Restart (Restart_State) /= 0
              or else Decoded = Total
            then
               return Results.Success;
            end if;

            Internal.Bit_Streams.Byte_Align (Bits);
            Marker := Internal.Bit_Streams.Read_Byte (Entropy);
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Marker.Kind /= Internal.Bit_Streams.Restart_Marker then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Restart_Invalid_State,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            end if;

            Outcome := Internal.Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
            if Results.Succeeded (Outcome) then
               Restart_Base := Decoded;
            end if;
            return Outcome;
         end Accept_Restart_When_Due;
      begin
         if Internal.Scans.Components (Header.Scan) /= 3 then
            return Results.Failure (Errors.Table_Invalid_Definition);
         end if;

         for Component_Index_Value in Component_Index range 1 .. 3 loop
            declare
               Scan_Component : constant Internal.Scans.Scan_Component :=
                 Internal.Scans.Component (Header.Scan, Component_Index_Value);
               Frame_Component : constant Internal.Frames.Frame_Component :=
                 Internal.Frames.Component (Header.Frame, Scan_Component.Frame_Component);
            begin
               if Frame_Component.Horizontal_Sampling /= 1
                 or else Frame_Component.Vertical_Sampling /= 1
                 or else not Internal.Huffman.Has_Table
                   (Header.Huffman_State, Internal.Huffman.DC, Scan_Component.DC_Table)
               then
                  return
                    Results.Failure
                      (Errors.Make
                         (Errors.Table_Invalid_Definition,
                          (Frame_Component => Scan_Component.Frame_Component,
                           Detail => Long_Long_Integer (Scan_Component.DC_Table),
                           others => <>)));
               end if;

               Compile :=
                 Internal.Huffman.Compile
                   (Internal.Huffman.Definition
                      (Header.Huffman_State, Internal.Huffman.DC, Scan_Component.DC_Table));
               if not Results.Succeeded (Compile.Outcome) then
                  return Compile.Outcome;
               end if;
               Tables (Component_Index_Value) := Compile.Table;
            end;
         end loop;

         Internal.Restarts.Configure (Restart_State, Header.Restart);
         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               for Component_Index_Value in Component_Index range 1 .. 3 loop
                  Symbol := Internal.Huffman.Decode (Tables (Component_Index_Value), Bits);
                  if not Results.Succeeded (Symbol.Outcome) then
                     return Symbol.Outcome;
                  elsif Symbol.Symbol > 16 then
                     return
                       Results.Failure
                         (Errors.Make
                            (Errors.Coefficient_Invalid_Encoding,
                             (Source => Symbol.Source,
                              Detail => Long_Long_Integer (Symbol.Symbol),
                              others => <>)));
                  end if;

                  Extended := Read_Category_Bits (Internal.Bit_Streams.Entropy_Category (Symbol.Symbol));
                  if not Results.Succeeded (Extended.Outcome) then
                     return Extended.Outcome;
                  end if;

                  declare
                     Sample : constant Integer :=
                       Predictor (Component_Index_Value, Column, Row) + Integer (Extended.Value);
                     Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
                  begin
                     if Sample not in 0 .. Max_Sample then
                        return
                          Results.Failure
                            (Errors.Make
                               (Errors.Coefficient_Invalid_Encoding,
                                (Detail => Long_Long_Integer (Sample), others => <>)));
                    end if;
                    Samples
                       (Component_Index_Value, Samples'First (2) + Row * Width + Column) := Sample;
                  end;
               end loop;

               Decoded := Decoded + 1;
               declare
                  Outcome : Results.Result := Internal.Restarts.Advance_MCU (Restart_State);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome := Accept_Restart_When_Due;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            end loop;
         end loop;

         Internal.Bit_Streams.Byte_Align (Bits);
         Ending := Internal.Bit_Streams.Read_Byte (Entropy);
         declare
           Outcome : constant Results.Result :=
              Decode_Hierarchical_Lossless_Continuation
                (Header, Object.Input, Ending, Samples'Access);
         begin
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end;

         if Header_Color_Model in YCbCr | RGB and then Can_Write_Direct_Output_Rows (Width, Height) then
            for Row in Natural range 0 .. Height - 1 loop
               declare
                  C1_Row : Streams.Byte_Array (1 .. Width);
                  C2_Row : Streams.Byte_Array (1 .. Width);
                  C3_Row : Streams.Byte_Array (1 .. Width);
                  Written : Natural;
               begin
                  for Column in Natural range 0 .. Width - 1 loop
                     declare
                        Index : constant Natural := Samples'First (2) + Row * Width + Column;
                     begin
                        C1_Row (C1_Row'First + Column) := Output_Byte (Samples (1, Index));
                        C2_Row (C2_Row'First + Column) := Output_Byte (Samples (2, Index));
                        C3_Row (C3_Row'First + Column) := Output_Byte (Samples (3, Index));
                     end;
                  end loop;

                  if Header_Color_Model = YCbCr then
                     Internal.Colors.Write_YCbCr_Row
                       (Output,
                        Row,
                        C1_Row,
                        C2_Row,
                        C3_Row,
                        0,
                        Width,
                        Object.Decode_Options.Alpha_Fill,
                        Written);
                  else
                     Internal.Colors.Write_RGB_Row
                       (Output,
                        Row,
                        C1_Row,
                        C2_Row,
                        C3_Row,
                        0,
                        Width,
                        Object.Decode_Options.Alpha_Fill,
                        Written);
                  end if;

                  if Written /= Width then
                     for Column in Natural range 0 .. Width - 1 loop
                        if Header_Color_Model = YCbCr then
                           Write_YCbCr_Pixel
                             (Column,
                              Row,
                              C1_Row (C1_Row'First + Column),
                              C2_Row (C2_Row'First + Column),
                              C3_Row (C3_Row'First + Column));
                        else
                           Write_RGB_Pixel
                             (Column,
                              Row,
                              C1_Row (C1_Row'First + Column),
                              C2_Row (C2_Row'First + Column),
                              C3_Row (C3_Row'First + Column));
                        end if;
                     end loop;
                  end if;
               end;
            end loop;
         else
            for Row in Natural range 0 .. Height - 1 loop
               for Column in Natural range 0 .. Width - 1 loop
                  declare
                     Index : constant Natural := Samples'First (2) + Row * Width + Column;
                  begin
                     if Header_Color_Model = YCbCr then
                        Write_YCbCr_Pixel
                          (Column,
                           Row,
                           Output_Byte (Samples (1, Index)),
                           Output_Byte (Samples (2, Index)),
                           Output_Byte (Samples (3, Index)));
                     else
                        Write_RGB_Pixel
                          (Column,
                           Row,
                           Output_Byte (Samples (1, Index)),
                           Output_Byte (Samples (2, Index)),
                           Output_Byte (Samples (3, Index)));
                     end if;
                  end;
               end loop;
            end loop;
         end if;

         return Results.Success;
      end Decode_Lossless_Three_Component;
      pragma Unreferenced (Decode_Lossless_Three_Component);

      function Decode_Lossless_Four_Component return Results.Result is
         use type Internal.Bit_Streams.Entropy_Byte_Kind;
         use type Internal.Bit_Streams.Entropy_Bits;

         type Compiled_Array is array (Component_Index range 1 .. 4) of Internal.Huffman.Compiled_Huffman;

         Entropy : aliased Internal.Bit_Streams.Entropy_Reader (Object.Input);
         Bits : Internal.Bit_Streams.Bit_Reader (Entropy'Access);
         Compile : Internal.Huffman.Compile_Result;
         Tables : Compiled_Array;
         Symbol : Internal.Huffman.Decode_Result;
         Extended : Internal.Bit_Streams.Sign_Extend_Result;
         Ending : Internal.Bit_Streams.Entropy_Read_Result;
         Restart_State : Internal.Restarts.Restart_State;
         Restart_Base : Natural := 0;
         Decoded : Natural := 0;
         Width : constant Natural := Natural (Internal.Frames.Width (Header.Frame));
         Height : constant Natural := Natural (Internal.Frames.Height (Header.Frame));
         Total : constant Natural := Width * Height;
         Samples : aliased Lossless_Sample_Array := [1 .. 4 => [1 .. Total => 0]];

         function Read_Category_Bits
           (Category : Internal.Bit_Streams.Entropy_Category) return Internal.Bit_Streams.Sign_Extend_Result
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

         function Initial_Predictor return Integer is
         begin
            return
              2 **
                (Natural (Internal.Frames.Precision (Header.Frame))
                 - Natural (Internal.Scans.Successive_Low (Header.Scan))
                 - 1);
         end Initial_Predictor;

         function Stored (Component : Component_Index; Column, Row : Natural) return Integer is
           (Samples (Component, Samples'First (2) + Row * Width + Column));

         function Output_Byte (Sample : Integer) return Byte is
            Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
         begin
            if Internal.Frames.Precision (Header.Frame) = 8 then
               return Byte (Sample);
            else
               return Byte ((Sample * Integer (Byte'Last) + Max_Sample / 2) / Max_Sample);
            end if;
         end Output_Byte;

         function Predictor (Component : Component_Index; Column, Row : Natural) return Integer is
            Ra : Integer;
            Rb : Integer;
            Rc : Integer;
         begin
            if Decoded = Restart_Base then
               return Initial_Predictor;
            elsif Column = 0 then
               return Stored (Component, Column, Row - 1);
            elsif Row = 0 then
               return Stored (Component, Column - 1, Row);
            end if;

            Ra := Stored (Component, Column - 1, Row);
            Rb := Stored (Component, Column, Row - 1);
            Rc := Stored (Component, Column - 1, Row - 1);

            case Internal.Scans.Spectral_Start (Header.Scan) is
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
               when others =>
                  return Initial_Predictor;
            end case;
         end Predictor;

         function Accept_Restart_When_Due return Results.Result is
            Marker : Internal.Bit_Streams.Entropy_Read_Result;
            Outcome : Results.Result;
         begin
            if Header.Restart = 0
              or else Internal.Restarts.MCUs_Until_Restart (Restart_State) /= 0
              or else Decoded = Total
            then
               return Results.Success;
            end if;

            Internal.Bit_Streams.Byte_Align (Bits);
            Marker := Internal.Bit_Streams.Read_Byte (Entropy);
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Marker.Kind /= Internal.Bit_Streams.Restart_Marker then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Restart_Invalid_State,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            end if;

            Outcome := Internal.Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
            if Results.Succeeded (Outcome) then
               Restart_Base := Decoded;
            end if;
            return Outcome;
         end Accept_Restart_When_Due;
      begin
         if Internal.Scans.Components (Header.Scan) /= 4 then
            return Results.Failure (Errors.Table_Invalid_Definition);
         end if;

         for Component_Index_Value in Component_Index range 1 .. 4 loop
            declare
               Scan_Component : constant Internal.Scans.Scan_Component :=
                 Internal.Scans.Component (Header.Scan, Component_Index_Value);
               Frame_Component : constant Internal.Frames.Frame_Component :=
                 Internal.Frames.Component (Header.Frame, Scan_Component.Frame_Component);
            begin
               if Frame_Component.Horizontal_Sampling /= 1
                 or else Frame_Component.Vertical_Sampling /= 1
                 or else not Internal.Huffman.Has_Table
                   (Header.Huffman_State, Internal.Huffman.DC, Scan_Component.DC_Table)
               then
                  return
                    Results.Failure
                      (Errors.Make
                         (Errors.Table_Invalid_Definition,
                          (Frame_Component => Scan_Component.Frame_Component,
                           Detail => Long_Long_Integer (Scan_Component.DC_Table),
                           others => <>)));
               end if;

               Compile :=
                 Internal.Huffman.Compile
                   (Internal.Huffman.Definition
                      (Header.Huffman_State, Internal.Huffman.DC, Scan_Component.DC_Table));
               if not Results.Succeeded (Compile.Outcome) then
                  return Compile.Outcome;
               end if;
               Tables (Component_Index_Value) := Compile.Table;
            end;
         end loop;

         Internal.Restarts.Configure (Restart_State, Header.Restart);
         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               for Component_Index_Value in Component_Index range 1 .. 4 loop
                  Symbol := Internal.Huffman.Decode (Tables (Component_Index_Value), Bits);
                  if not Results.Succeeded (Symbol.Outcome) then
                     return Symbol.Outcome;
                  elsif Symbol.Symbol > 16 then
                     return
                       Results.Failure
                         (Errors.Make
                            (Errors.Coefficient_Invalid_Encoding,
                             (Source => Symbol.Source,
                              Detail => Long_Long_Integer (Symbol.Symbol),
                              others => <>)));
                  end if;

                  Extended := Read_Category_Bits (Internal.Bit_Streams.Entropy_Category (Symbol.Symbol));
                  if not Results.Succeeded (Extended.Outcome) then
                     return Extended.Outcome;
                  end if;

                  declare
                     Sample : constant Integer :=
                       Predictor (Component_Index_Value, Column, Row) + Integer (Extended.Value);
                     Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
                  begin
                     if Sample not in 0 .. Max_Sample then
                        return
                          Results.Failure
                            (Errors.Make
                               (Errors.Coefficient_Invalid_Encoding,
                                (Detail => Long_Long_Integer (Sample), others => <>)));
                     end if;
                     Samples
                       (Component_Index_Value, Samples'First (2) + Row * Width + Column) := Sample;
                  end;
               end loop;

               Decoded := Decoded + 1;
               declare
                  Outcome : Results.Result := Internal.Restarts.Advance_MCU (Restart_State);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome := Accept_Restart_When_Due;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            end loop;
         end loop;

         Internal.Bit_Streams.Byte_Align (Bits);
         Ending := Internal.Bit_Streams.Read_Byte (Entropy);
         declare
           Outcome : constant Results.Result :=
              Decode_Hierarchical_Lossless_Continuation
                (Header, Object.Input, Ending, Samples'Access);
         begin
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end;

         if Header_Color_Model in CMYK | YCCK and then Can_Write_Direct_Output_Rows (Width, Height) then
            for Row in Natural range 0 .. Height - 1 loop
               declare
                  C1_Row : Jpeglib.Streams.Byte_Array (1 .. Width);
                  C2_Row : Jpeglib.Streams.Byte_Array (1 .. Width);
                  C3_Row : Jpeglib.Streams.Byte_Array (1 .. Width);
                  C4_Row : Jpeglib.Streams.Byte_Array (1 .. Width);
                  Written : Natural;
               begin
                  for Column in Natural range 0 .. Width - 1 loop
                     declare
                        Index : constant Natural := Samples'First (2) + Row * Width + Column;
                     begin
                        C1_Row (C1_Row'First + Column) := Output_Byte (Samples (1, Index));
                        C2_Row (C2_Row'First + Column) := Output_Byte (Samples (2, Index));
                        C3_Row (C3_Row'First + Column) := Output_Byte (Samples (3, Index));
                        C4_Row (C4_Row'First + Column) := Output_Byte (Samples (4, Index));
                     end;
                  end loop;

                  if Header_Color_Model = YCCK then
                     Internal.Colors.Write_YCCK_Row
                       (Output,
                        Row,
                        C1_Row,
                        C2_Row,
                        C3_Row,
                        C4_Row,
                        0,
                        Width,
                        Object.Decode_Options.Alpha_Fill,
                        Written);
                  else
                     Internal.Colors.Write_CMYK_Row
                       (Output,
                        Row,
                        C1_Row,
                        C2_Row,
                        C3_Row,
                        C4_Row,
                        0,
                        Width,
                        Object.Decode_Options.Alpha_Fill,
                        Written);
                  end if;

                  if Written /= Width then
                     for Column in Natural range 0 .. Width - 1 loop
                        Write_Four_Component_Pixel
                          (Column,
                           Row,
                           C1_Row (C1_Row'First + Column),
                           C2_Row (C2_Row'First + Column),
                           C3_Row (C3_Row'First + Column),
                           C4_Row (C4_Row'First + Column));
                     end loop;
                  end if;
               end;
            end loop;
         else
            for Row in Natural range 0 .. Height - 1 loop
               for Column in Natural range 0 .. Width - 1 loop
                  declare
                     Index : constant Natural := Samples'First (2) + Row * Width + Column;
                  begin
                     Write_Four_Component_Pixel
                       (Column,
                        Row,
                        Output_Byte (Samples (1, Index)),
                        Output_Byte (Samples (2, Index)),
                        Output_Byte (Samples (3, Index)),
                        Output_Byte (Samples (4, Index)));
                  end;
               end loop;
            end loop;
         end if;

         return Results.Success;
      end Decode_Lossless_Four_Component;
      pragma Unreferenced (Decode_Lossless_Four_Component);

      function Decode_Arithmetic_Lossless_Grayscale return Results.Result is
         use type Internal.Bit_Streams.Entropy_Byte_Kind;

         Component : constant Internal.Scans.Scan_Component := Internal.Scans.Component (Header.Scan, 1);
         Entropy : aliased Internal.Bit_Streams.Entropy_Reader (Object.Input);
         Decoder : Internal.Arithmetic.Decoder (Entropy'Access);
         DC_Bins : Internal.Arithmetic.Probability_Bin_Array (0 .. 63) :=
           [others => Internal.Arithmetic.Initial_Probability_Bin];
         DC_Context : Internal.Arithmetic.DC_Context_Index := 0;
         DC : Internal.Arithmetic.DC_Result;
         Ending : Internal.Bit_Streams.Entropy_Read_Result;
         Restart_State : Internal.Restarts.Restart_State;
         Restart_Base : Natural := 0;
         Decoded : Natural := 0;
         Width : constant Natural := Natural (Internal.Frames.Width (Header.Frame));
         Height : constant Natural := Natural (Internal.Frames.Height (Header.Frame));
         Total : constant Natural := Width * Height;
         Samples : aliased Lossless_Sample_Array := [1 .. 1 => [1 .. Total => 0]];

         function Initial_Predictor return Integer is
         begin
            return
              2 **
                (Natural (Internal.Frames.Precision (Header.Frame))
                 - Natural (Internal.Scans.Successive_Low (Header.Scan))
                 - 1);
         end Initial_Predictor;

         function Predictor (Column, Row : Natural) return Integer is
            function Stored (Stored_Column, Stored_Row : Natural) return Integer is
              (Samples (1, Samples'First (2) + Stored_Row * Width + Stored_Column));

            Ra : Integer;
            Rb : Integer;
            Rc : Integer;
         begin
            if Decoded = Restart_Base then
               return Initial_Predictor;
            elsif Column = 0 then
               return Stored (Column, Row - 1);
            elsif Row = 0 then
               return Stored (Column - 1, Row);
            end if;

            Ra := Stored (Column - 1, Row);
            Rb := Stored (Column, Row - 1);
            Rc := Stored (Column - 1, Row - 1);

            case Internal.Scans.Spectral_Start (Header.Scan) is
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
               when others =>
                  return Initial_Predictor;
            end case;
         end Predictor;

         function Output_Byte (Sample : Integer) return Byte is
            Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
         begin
            if Internal.Frames.Precision (Header.Frame) = 8 then
               return Byte (Sample);
            else
               return Byte ((Sample * Integer (Byte'Last) + Max_Sample / 2) / Max_Sample);
            end if;
         end Output_Byte;

         function Accept_Restart_When_Due return Results.Result is
            Marker : Internal.Bit_Streams.Entropy_Read_Result;
            Outcome : Results.Result;
         begin
            if Header.Restart = 0
              or else Internal.Restarts.MCUs_Until_Restart (Restart_State) /= 0
              or else Decoded = Total
            then
               return Results.Success;
            end if;

            Marker := Internal.Bit_Streams.Read_Byte (Entropy);
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Marker.Kind /= Internal.Bit_Streams.Restart_Marker then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Restart_Invalid_State,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            end if;

            Outcome := Internal.Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
            if Results.Succeeded (Outcome) then
               Restart_Base := Decoded;
               Internal.Arithmetic.Reset (Decoder);
               DC_Bins := [others => Internal.Arithmetic.Initial_Probability_Bin];
               DC_Context := 0;
            end if;
            return Outcome;
         end Accept_Restart_When_Due;
      begin
         if Internal.Scans.Components (Header.Scan) /= 1
           or else not Internal.Arithmetic.Has_Table
             (Header.Arithmetic_State, Internal.Arithmetic.DC, Component.DC_Table)
         then
            return
              Results.Failure
                (Errors.Make
                   (Errors.Table_Invalid_Definition,
                    (Frame_Component => Component.Frame_Component,
                     Detail => Long_Long_Integer (Component.DC_Table),
                     others => <>)));
         end if;

         Internal.Restarts.Configure (Restart_State, Header.Restart);
         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               DC :=
                 Internal.Arithmetic.Decode_DC_Difference
                   (Decoder,
                    DC_Bins,
                    DC_Context,
                    Internal.Arithmetic.Value (Header.Arithmetic_State, Internal.Arithmetic.DC, Component.DC_Table));
               if not Results.Succeeded (DC.Outcome) then
                  return DC.Outcome;
               end if;

               declare
                  Sample : constant Integer := Predictor (Column, Row) + Integer (DC.Difference);
                  Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
               begin
                  if Sample not in 0 .. Max_Sample then
                     return
                       Results.Failure
                         (Errors.Make
                            (Errors.Coefficient_Invalid_Encoding,
                             (Detail => Long_Long_Integer (Sample), others => <>)));
                  end if;
                  Samples (1, Samples'First (2) + Row * Width + Column) := Sample;
               end;

               Decoded := Decoded + 1;
               declare
                  Outcome : Results.Result := Internal.Restarts.Advance_MCU (Restart_State);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome := Accept_Restart_When_Due;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            end loop;
         end loop;

         Ending := Internal.Bit_Streams.Read_Byte (Entropy);
         declare
            Outcome : constant Results.Result :=
              Decode_Hierarchical_Lossless_Continuation
                (Header, Object.Input, Ending, Samples'Access);
         begin
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end;

         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               Write_Gray_Pixel
                 (Column, Row, Output_Byte (Samples (1, Samples'First (2) + Row * Width + Column)));
            end loop;
         end loop;

         return Results.Success;
      end Decode_Arithmetic_Lossless_Grayscale;
      pragma Unreferenced (Decode_Arithmetic_Lossless_Grayscale);

      function Decode_Arithmetic_Lossless_Three_Component return Results.Result is
         use type Internal.Bit_Streams.Entropy_Byte_Kind;

         type Context_Array is array (Component_Index range 1 .. 3) of
           Internal.Arithmetic.DC_Context_Index;
         type DC_Bin_Set_Array is array (Component_Index range 1 .. 3) of
           Internal.Arithmetic.Probability_Bin_Array (0 .. 63);

         Entropy : aliased Internal.Bit_Streams.Entropy_Reader (Object.Input);
         Decoder : Internal.Arithmetic.Decoder (Entropy'Access);
         DC_Bins : DC_Bin_Set_Array := [others => [others => Internal.Arithmetic.Initial_Probability_Bin]];
         DC_Contexts : Context_Array := [others => 0];
         DC : Internal.Arithmetic.DC_Result;
         Ending : Internal.Bit_Streams.Entropy_Read_Result;
         Restart_State : Internal.Restarts.Restart_State;
         Restart_Base : Natural := 0;
         Decoded : Natural := 0;
         Width : constant Natural := Natural (Internal.Frames.Width (Header.Frame));
         Height : constant Natural := Natural (Internal.Frames.Height (Header.Frame));
         Total : constant Natural := Width * Height;
         Samples : aliased Lossless_Sample_Array := [1 .. 3 => [1 .. Total => 0]];

         function Initial_Predictor return Integer is
         begin
            return
              2 **
                (Natural (Internal.Frames.Precision (Header.Frame))
                 - Natural (Internal.Scans.Successive_Low (Header.Scan))
                 - 1);
         end Initial_Predictor;

         function Stored (Component : Component_Index; Column, Row : Natural) return Integer is
           (Samples (Component, Samples'First (2) + Row * Width + Column));

         function Output_Byte (Sample : Integer) return Byte is
            Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
         begin
            if Internal.Frames.Precision (Header.Frame) = 8 then
               return Byte (Sample);
            else
               return Byte ((Sample * Integer (Byte'Last) + Max_Sample / 2) / Max_Sample);
            end if;
         end Output_Byte;

         function Predictor (Component : Component_Index; Column, Row : Natural) return Integer is
            Ra : Integer;
            Rb : Integer;
            Rc : Integer;
         begin
            if Decoded = Restart_Base then
               return Initial_Predictor;
            elsif Column = 0 then
               return Stored (Component, Column, Row - 1);
            elsif Row = 0 then
               return Stored (Component, Column - 1, Row);
            end if;

            Ra := Stored (Component, Column - 1, Row);
            Rb := Stored (Component, Column, Row - 1);
            Rc := Stored (Component, Column - 1, Row - 1);

            case Internal.Scans.Spectral_Start (Header.Scan) is
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
               when others =>
                  return Initial_Predictor;
            end case;
         end Predictor;

         function Accept_Restart_When_Due return Results.Result is
            Marker : Internal.Bit_Streams.Entropy_Read_Result;
            Outcome : Results.Result;
         begin
            if Header.Restart = 0
              or else Internal.Restarts.MCUs_Until_Restart (Restart_State) /= 0
              or else Decoded = Total
            then
               return Results.Success;
            end if;

            Marker := Internal.Bit_Streams.Read_Byte (Entropy);
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Marker.Kind /= Internal.Bit_Streams.Restart_Marker then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Restart_Invalid_State,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            end if;

            Outcome := Internal.Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
            if Results.Succeeded (Outcome) then
               Restart_Base := Decoded;
               Internal.Arithmetic.Reset (Decoder);
               DC_Bins := [others => [others => Internal.Arithmetic.Initial_Probability_Bin]];
               DC_Contexts := [others => 0];
            end if;
            return Outcome;
         end Accept_Restart_When_Due;
      begin
         if Internal.Scans.Components (Header.Scan) /= 3 then
            return Results.Failure (Errors.Table_Invalid_Definition);
         end if;

         for Component_Index_Value in Component_Index range 1 .. 3 loop
            declare
               Scan_Component : constant Internal.Scans.Scan_Component :=
                 Internal.Scans.Component (Header.Scan, Component_Index_Value);
               Frame_Component : constant Internal.Frames.Frame_Component :=
                 Internal.Frames.Component (Header.Frame, Scan_Component.Frame_Component);
            begin
               if Frame_Component.Horizontal_Sampling /= 1
                 or else Frame_Component.Vertical_Sampling /= 1
                 or else not Internal.Arithmetic.Has_Table
                   (Header.Arithmetic_State, Internal.Arithmetic.DC, Scan_Component.DC_Table)
               then
                  return
                    Results.Failure
                      (Errors.Make
                         (Errors.Table_Invalid_Definition,
                          (Frame_Component => Scan_Component.Frame_Component,
                           Detail => Long_Long_Integer (Scan_Component.DC_Table),
                           others => <>)));
               end if;
            end;
         end loop;

         Internal.Restarts.Configure (Restart_State, Header.Restart);
         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               for Component_Index_Value in Component_Index range 1 .. 3 loop
                  declare
                     Scan_Component : constant Internal.Scans.Scan_Component :=
                       Internal.Scans.Component (Header.Scan, Component_Index_Value);
                  begin
                     DC :=
                       Internal.Arithmetic.Decode_DC_Difference
                         (Decoder,
                          DC_Bins (Component_Index_Value),
                          DC_Contexts (Component_Index_Value),
                          Internal.Arithmetic.Value
                            (Header.Arithmetic_State, Internal.Arithmetic.DC, Scan_Component.DC_Table));
                     if not Results.Succeeded (DC.Outcome) then
                        return DC.Outcome;
                     end if;

                     declare
                        Sample : constant Integer :=
                          Predictor (Component_Index_Value, Column, Row) + Integer (DC.Difference);
                        Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
                     begin
                        if Sample not in 0 .. Max_Sample then
                           return
                             Results.Failure
                               (Errors.Make
                                  (Errors.Coefficient_Invalid_Encoding,
                                   (Detail => Long_Long_Integer (Sample), others => <>)));
                        end if;
                        Samples
                          (Component_Index_Value, Samples'First (2) + Row * Width + Column) := Sample;
                     end;
                  end;
               end loop;

               Decoded := Decoded + 1;
               declare
                  Outcome : Results.Result := Internal.Restarts.Advance_MCU (Restart_State);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome := Accept_Restart_When_Due;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            end loop;
         end loop;

         Ending := Internal.Bit_Streams.Read_Byte (Entropy);
         declare
            Outcome : constant Results.Result :=
              Decode_Hierarchical_Lossless_Continuation
                (Header, Object.Input, Ending, Samples'Access);
         begin
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end;

         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               declare
                  Index : constant Natural := Samples'First (2) + Row * Width + Column;
               begin
                  if Header_Color_Model = YCbCr then
                     Write_YCbCr_Pixel
                       (Column,
                        Row,
                        Output_Byte (Samples (1, Index)),
                        Output_Byte (Samples (2, Index)),
                        Output_Byte (Samples (3, Index)));
                  else
                     Write_RGB_Pixel
                       (Column,
                        Row,
                        Output_Byte (Samples (1, Index)),
                        Output_Byte (Samples (2, Index)),
                        Output_Byte (Samples (3, Index)));
                  end if;
               end;
            end loop;
         end loop;

         return Results.Success;
      end Decode_Arithmetic_Lossless_Three_Component;
      pragma Unreferenced (Decode_Arithmetic_Lossless_Three_Component);

      function Decode_Arithmetic_Lossless_Four_Component return Results.Result is
         use type Internal.Bit_Streams.Entropy_Byte_Kind;

         type Context_Array is array (Component_Index range 1 .. 4) of
           Internal.Arithmetic.DC_Context_Index;
         type DC_Bin_Set_Array is array (Component_Index range 1 .. 4) of
           Internal.Arithmetic.Probability_Bin_Array (0 .. 63);

         Entropy : aliased Internal.Bit_Streams.Entropy_Reader (Object.Input);
         Decoder : Internal.Arithmetic.Decoder (Entropy'Access);
         DC_Bins : DC_Bin_Set_Array := [others => [others => Internal.Arithmetic.Initial_Probability_Bin]];
         DC_Contexts : Context_Array := [others => 0];
         DC : Internal.Arithmetic.DC_Result;
         Ending : Internal.Bit_Streams.Entropy_Read_Result;
         Restart_State : Internal.Restarts.Restart_State;
         Restart_Base : Natural := 0;
         Decoded : Natural := 0;
         Width : constant Natural := Natural (Internal.Frames.Width (Header.Frame));
         Height : constant Natural := Natural (Internal.Frames.Height (Header.Frame));
         Total : constant Natural := Width * Height;
         Samples : aliased Lossless_Sample_Array := [1 .. 4 => [1 .. Total => 0]];

         function Initial_Predictor return Integer is
         begin
            return
              2 **
                (Natural (Internal.Frames.Precision (Header.Frame))
                 - Natural (Internal.Scans.Successive_Low (Header.Scan))
                 - 1);
         end Initial_Predictor;

         function Stored (Component : Component_Index; Column, Row : Natural) return Integer is
           (Samples (Component, Samples'First (2) + Row * Width + Column));

         function Output_Byte (Sample : Integer) return Byte is
            Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
         begin
            if Internal.Frames.Precision (Header.Frame) = 8 then
               return Byte (Sample);
            else
               return Byte ((Sample * Integer (Byte'Last) + Max_Sample / 2) / Max_Sample);
            end if;
         end Output_Byte;

         function Predictor (Component : Component_Index; Column, Row : Natural) return Integer is
            Ra : Integer;
            Rb : Integer;
            Rc : Integer;
         begin
            if Decoded = Restart_Base then
               return Initial_Predictor;
            elsif Column = 0 then
               return Stored (Component, Column, Row - 1);
            elsif Row = 0 then
               return Stored (Component, Column - 1, Row);
            end if;

            Ra := Stored (Component, Column - 1, Row);
            Rb := Stored (Component, Column, Row - 1);
            Rc := Stored (Component, Column - 1, Row - 1);

            case Internal.Scans.Spectral_Start (Header.Scan) is
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
               when others =>
                  return Initial_Predictor;
            end case;
         end Predictor;

         function Accept_Restart_When_Due return Results.Result is
            Marker : Internal.Bit_Streams.Entropy_Read_Result;
            Outcome : Results.Result;
         begin
            if Header.Restart = 0
              or else Internal.Restarts.MCUs_Until_Restart (Restart_State) /= 0
              or else Decoded = Total
            then
               return Results.Success;
            end if;

            Marker := Internal.Bit_Streams.Read_Byte (Entropy);
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Marker.Kind /= Internal.Bit_Streams.Restart_Marker then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Restart_Invalid_State,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            end if;

            Outcome := Internal.Restarts.Accept_Restart (Restart_State, Marker.Marker, Marker.Source);
            if Results.Succeeded (Outcome) then
               Restart_Base := Decoded;
               Internal.Arithmetic.Reset (Decoder);
               DC_Bins := [others => [others => Internal.Arithmetic.Initial_Probability_Bin]];
               DC_Contexts := [others => 0];
            end if;
            return Outcome;
         end Accept_Restart_When_Due;
      begin
         if Internal.Scans.Components (Header.Scan) /= 4 then
            return Results.Failure (Errors.Table_Invalid_Definition);
         end if;

         for Component_Index_Value in Component_Index range 1 .. 4 loop
            declare
               Scan_Component : constant Internal.Scans.Scan_Component :=
                 Internal.Scans.Component (Header.Scan, Component_Index_Value);
               Frame_Component : constant Internal.Frames.Frame_Component :=
                 Internal.Frames.Component (Header.Frame, Scan_Component.Frame_Component);
            begin
               if Frame_Component.Horizontal_Sampling /= 1
                 or else Frame_Component.Vertical_Sampling /= 1
                 or else not Internal.Arithmetic.Has_Table
                   (Header.Arithmetic_State, Internal.Arithmetic.DC, Scan_Component.DC_Table)
               then
                  return
                    Results.Failure
                      (Errors.Make
                         (Errors.Table_Invalid_Definition,
                          (Frame_Component => Scan_Component.Frame_Component,
                           Detail => Long_Long_Integer (Scan_Component.DC_Table),
                           others => <>)));
               end if;
            end;
         end loop;

         Internal.Restarts.Configure (Restart_State, Header.Restart);
         for Row in Natural range 0 .. Height - 1 loop
            for Column in Natural range 0 .. Width - 1 loop
               for Component_Index_Value in Component_Index range 1 .. 4 loop
                  declare
                     Scan_Component : constant Internal.Scans.Scan_Component :=
                       Internal.Scans.Component (Header.Scan, Component_Index_Value);
                  begin
                     DC :=
                       Internal.Arithmetic.Decode_DC_Difference
                         (Decoder,
                          DC_Bins (Component_Index_Value),
                          DC_Contexts (Component_Index_Value),
                          Internal.Arithmetic.Value
                            (Header.Arithmetic_State, Internal.Arithmetic.DC, Scan_Component.DC_Table));
                     if not Results.Succeeded (DC.Outcome) then
                        return DC.Outcome;
                     end if;

                     declare
                        Sample : constant Integer :=
                          Predictor (Component_Index_Value, Column, Row) + Integer (DC.Difference);
                        Max_Sample : constant Integer := 2 ** Natural (Internal.Frames.Precision (Header.Frame)) - 1;
                     begin
                        if Sample not in 0 .. Max_Sample then
                           return
                             Results.Failure
                               (Errors.Make
                                  (Errors.Coefficient_Invalid_Encoding,
                                   (Detail => Long_Long_Integer (Sample), others => <>)));
                        end if;
                        Samples
                          (Component_Index_Value, Samples'First (2) + Row * Width + Column) := Sample;
                     end;
                  end;
               end loop;

               Decoded := Decoded + 1;
               declare
                  Outcome : Results.Result := Internal.Restarts.Advance_MCU (Restart_State);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome := Accept_Restart_When_Due;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            end loop;
         end loop;

         Ending := Internal.Bit_Streams.Read_Byte (Entropy);
         declare
            Outcome : constant Results.Result :=
              Decode_Hierarchical_Lossless_Continuation
                (Header, Object.Input, Ending, Samples'Access);
         begin
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end;

         if Header_Color_Model in CMYK | YCCK and then Can_Write_Direct_Output_Rows (Width, Height) then
            for Row in Natural range 0 .. Height - 1 loop
               declare
                  C1_Row : Jpeglib.Streams.Byte_Array (1 .. Width);
                  C2_Row : Jpeglib.Streams.Byte_Array (1 .. Width);
                  C3_Row : Jpeglib.Streams.Byte_Array (1 .. Width);
                  C4_Row : Jpeglib.Streams.Byte_Array (1 .. Width);
                  Written : Natural;
               begin
                  for Column in Natural range 0 .. Width - 1 loop
                     declare
                        Index : constant Natural := Samples'First (2) + Row * Width + Column;
                     begin
                        C1_Row (C1_Row'First + Column) := Output_Byte (Samples (1, Index));
                        C2_Row (C2_Row'First + Column) := Output_Byte (Samples (2, Index));
                        C3_Row (C3_Row'First + Column) := Output_Byte (Samples (3, Index));
                        C4_Row (C4_Row'First + Column) := Output_Byte (Samples (4, Index));
                     end;
                  end loop;

                  if Header_Color_Model = YCCK then
                     Internal.Colors.Write_YCCK_Row
                       (Output,
                        Row,
                        C1_Row,
                        C2_Row,
                        C3_Row,
                        C4_Row,
                        0,
                        Width,
                        Object.Decode_Options.Alpha_Fill,
                        Written);
                  else
                     Internal.Colors.Write_CMYK_Row
                       (Output,
                        Row,
                        C1_Row,
                        C2_Row,
                        C3_Row,
                        C4_Row,
                        0,
                        Width,
                        Object.Decode_Options.Alpha_Fill,
                        Written);
                  end if;

                  if Written /= Width then
                     for Column in Natural range 0 .. Width - 1 loop
                        Write_Four_Component_Pixel
                          (Column,
                           Row,
                           C1_Row (C1_Row'First + Column),
                           C2_Row (C2_Row'First + Column),
                           C3_Row (C3_Row'First + Column),
                           C4_Row (C4_Row'First + Column));
                     end loop;
                  end if;
               end;
            end loop;
         else
            for Row in Natural range 0 .. Height - 1 loop
               for Column in Natural range 0 .. Width - 1 loop
                  declare
                     Index : constant Natural := Samples'First (2) + Row * Width + Column;
                  begin
                     Write_Four_Component_Pixel
                       (Column,
                        Row,
                        Output_Byte (Samples (1, Index)),
                        Output_Byte (Samples (2, Index)),
                        Output_Byte (Samples (3, Index)),
                        Output_Byte (Samples (4, Index)));
                  end;
               end loop;
            end loop;
         end if;

         return Results.Success;
      end Decode_Arithmetic_Lossless_Four_Component;
      pragma Unreferenced (Decode_Arithmetic_Lossless_Four_Component);

      procedure Write_CMYK_Pixel
        (Source_X : Natural;
         Source_Y : Natural;
         C : Byte;
         M : Byte;
         Y : Byte;
         K : Byte) is
         Target_X : Natural;
         Target_Y : Natural;
      begin
         if Emits_Reduced_Pixel (Source_X, Source_Y) then
            Map_Output_Coordinate (Source_X, Source_Y, Target_X, Target_Y);
            Internal.Colors.Write_CMYK (Output, Target_X, Target_Y, C, M, Y, K, Object.Decode_Options.Alpha_Fill);
         end if;
      end Write_CMYK_Pixel;

      procedure Write_Grayscale_Blocks (Blocks : Jpeglib.Coefficients.DCT_Block_Array) is
         Block_Number : Positive := Blocks'First;
         Dequantized : Internal.Transforms.Dequantized_Block;
         Samples : Internal.Transforms.Sample_Block;
         Placement : Internal.Sampling.Block_Placement;
      begin
         for MCU_R in MCU_Row range 0 .. Internal.Frames.MCU_Rows (Header.Frame) - 1 loop
            for MCU_C in MCU_Column range 0 .. Internal.Frames.MCU_Columns (Header.Frame) - 1 loop
               Dequantized := Internal.Transforms.Dequantize (Blocks (Block_Number), Table);
               Samples :=
                 Internal.Transforms.Reconstruct_Block
                   (Dequantized, Internal.Frames.Precision (Header.Frame));
               Placement :=
                 Internal.Sampling.Placement
                   (Header.Frame, 1, MCU_C, MCU_R, Horizontal_Block => 0, Vertical_Block => 0);

               if Placement.Visible_Width > 0 and then Placement.Visible_Height > 0 then
                  for Y in Natural range 0 .. Natural (Placement.Visible_Height) - 1 loop
                     for X in Natural range 0 .. Natural (Placement.Visible_Width) - 1 loop
                        Write_Gray_Pixel
                          (Natural (Placement.Column) + X,
                           Natural (Placement.Row) + Y,
                           Samples (Coefficient_Index (Y * 8 + X)));
                     end loop;
                  end loop;
               end if;

               Block_Number := Block_Number + 1;
            end loop;
         end loop;
      end Write_Grayscale_Blocks;

      procedure Store_Block_In_Plane
        (Plane : in out Jpeglib.Streams.Byte_Array;
         Plane_Width : Natural;
         Placement : Internal.Sampling.Block_Placement;
         Samples : Internal.Transforms.Sample_Block) is
      begin
         if Placement.Visible_Width > 0 and then Placement.Visible_Height > 0 then
            for Y in Natural range 0 .. Natural (Placement.Visible_Height) - 1 loop
               for X in Natural range 0 .. Natural (Placement.Visible_Width) - 1 loop
                  Plane
                    (Plane'First
                     + (Natural (Placement.Row) + Y) * Plane_Width
                     + Natural (Placement.Column)
                     + X) :=
                    Samples (Coefficient_Index (Y * 8 + X));
               end loop;
            end loop;
         end if;
      end Store_Block_In_Plane;

      procedure Write_Two_Component_Blocks
        (Blocks : Jpeglib.Coefficients.DCT_Block_Array;
         C1_Plane : in out Jpeglib.Streams.Byte_Array;
         C2_Plane : in out Jpeglib.Streams.Byte_Array;
         Separate_Order : Boolean)
      is
         C1_Component : constant Internal.Frames.Frame_Component := Internal.Frames.Component (Header.Frame, 1);
         C2_Component : constant Internal.Frames.Frame_Component := Internal.Frames.Component (Header.Frame, 2);
         Component : Internal.Frames.Frame_Component;
         Dequantized : Internal.Transforms.Dequantized_Block;
         Samples : Internal.Transforms.Sample_Block;
         Placement : Internal.Sampling.Block_Placement;
         Block_Number : Positive := Blocks'First;

         procedure Store_Component_Block
           (Component_Index_Value : Component_Index;
            Target : in out Jpeglib.Streams.Byte_Array;
            Target_Width : Natural;
            MCU_C : MCU_Column;
            MCU_R : MCU_Row;
            H : Internal.Sampling.Block_Offset;
            V : Internal.Sampling.Block_Offset) is
         begin
            Component := Internal.Frames.Component (Header.Frame, Component_Index_Value);
            Table := Internal.Quantization.Table (Header.Quantization_State, Component.Quantization_Table);
            Dequantized := Internal.Transforms.Dequantize (Blocks (Block_Number), Table);
            Samples :=
              Internal.Transforms.Reconstruct_Block
                (Dequantized, Internal.Frames.Precision (Header.Frame));
            Placement :=
              Internal.Sampling.Placement
                (Header.Frame, Component_Index_Value, MCU_C, MCU_R, H, V);
            Store_Block_In_Plane (Target, Target_Width, Placement, Samples);
            Block_Number := Block_Number + 1;
         end Store_Component_Block;

         procedure Store_Separate_Component
           (Component_Index_Value : Component_Index;
            Frame_Item : Internal.Frames.Frame_Component;
            Target : in out Jpeglib.Streams.Byte_Array) is
            Padded_Order : constant Boolean :=
              Header.Entropy = Arithmetic
              and then Internal.Frames.Mode (Header.Frame) in Progressive_DCT | Differential_Progressive_DCT;
            Block_Rows : constant Natural :=
              (if Padded_Order
               then Natural (Internal.Frames.Padded_Block_Rows (Header.Frame, Component_Index_Value))
               else Natural (Frame_Item.Block_Rows));
            Block_Columns : constant Natural :=
              (if Padded_Order
               then Natural (Internal.Frames.Padded_Block_Columns (Header.Frame, Component_Index_Value))
               else Natural (Frame_Item.Block_Columns));
         begin
            for Row in Natural range 0 .. Block_Rows - 1 loop
               for Column in Natural range 0 .. Block_Columns - 1 loop
                  Store_Component_Block
                    (Component_Index_Value,
                     Target,
                     Natural (Frame_Item.Component_Width),
                     MCU_Column (Column / Natural (Frame_Item.Horizontal_Sampling)),
                     MCU_Row (Row / Natural (Frame_Item.Vertical_Sampling)),
                     Internal.Sampling.Block_Offset (Column mod Natural (Frame_Item.Horizontal_Sampling)),
                     Internal.Sampling.Block_Offset (Row mod Natural (Frame_Item.Vertical_Sampling)));
               end loop;
            end loop;
         end Store_Separate_Component;
      begin
         if Separate_Order then
            Store_Separate_Component (1, C1_Component, C1_Plane);
            Store_Separate_Component (2, C2_Component, C2_Plane);
         else
            for MCU_R in MCU_Row range 0 .. Internal.Frames.MCU_Rows (Header.Frame) - 1 loop
               for MCU_C in MCU_Column range 0 .. Internal.Frames.MCU_Columns (Header.Frame) - 1 loop
                  for V in Internal.Sampling.Block_Offset range 0
                    .. Internal.Sampling.Block_Offset (C1_Component.Vertical_Sampling - 1)
                  loop
                     for H in Internal.Sampling.Block_Offset range 0
                       .. Internal.Sampling.Block_Offset (C1_Component.Horizontal_Sampling - 1)
                     loop
                        Store_Component_Block
                          (1, C1_Plane, Natural (C1_Component.Component_Width), MCU_C, MCU_R, H, V);
                     end loop;
                  end loop;

                  for V in Internal.Sampling.Block_Offset range 0
                    .. Internal.Sampling.Block_Offset (C2_Component.Vertical_Sampling - 1)
                  loop
                     for H in Internal.Sampling.Block_Offset range 0
                       .. Internal.Sampling.Block_Offset (C2_Component.Horizontal_Sampling - 1)
                     loop
                        Store_Component_Block
                          (2, C2_Plane, Natural (C2_Component.Component_Width), MCU_C, MCU_R, H, V);
                     end loop;
                  end loop;
               end loop;
            end loop;
         end if;

         declare
            Width : constant Natural := Natural (Internal.Frames.Width (Header.Frame));
            Height : constant Natural := Natural (Internal.Frames.Height (Header.Frame));
            Can_Write_Direct_Rows : constant Boolean :=
              Can_Write_Direct_Output_Rows (Width, Height)
              and then Natural (C1_Component.Component_Width) = Width
              and then Natural (C1_Component.Component_Height) = Height
              and then Natural (C2_Component.Component_Width) = Width
              and then Natural (C2_Component.Component_Height) = Height;
         begin
            if Can_Write_Direct_Rows then
               for Row in Natural range 0 .. Height - 1 loop
                  declare
                     Row_Offset : constant Natural := Row * Width;
                     Written : Natural;
                  begin
                     Internal.Colors.Write_Gray_Alpha_Row
                       (Output, Row, C1_Plane, C2_Plane, Row_Offset, Width, Written);

                     if Written /= Width then
                        for Column in Natural range 0 .. Width - 1 loop
                           Write_Gray_Alpha_Pixel
                             (Column,
                              Row,
                              C1_Plane (C1_Plane'First + Row_Offset + Column),
                              C2_Plane (C2_Plane'First + Row_Offset + Column));
                        end loop;
                     end if;
                  end;
               end loop;
            else
               for Row in Natural range 0 .. Height - 1 loop
                  for Column in Natural range 0 .. Width - 1 loop
                     declare
                        C1_C : constant Natural :=
                          Natural
                            (Internal.Sampling.Component_Column_For_Image
                               (Header.Frame, 1, Internal.Sampling.Sample_Column (Column)));
                        C1_R : constant Natural :=
                          Natural
                            (Internal.Sampling.Component_Row_For_Image
                               (Header.Frame, 1, Internal.Sampling.Sample_Row (Row)));
                        C2_C : constant Natural :=
                          Natural
                            (Internal.Sampling.Component_Column_For_Image
                               (Header.Frame, 2, Internal.Sampling.Sample_Column (Column)));
                        C2_R : constant Natural :=
                          Natural
                            (Internal.Sampling.Component_Row_For_Image
                               (Header.Frame, 2, Internal.Sampling.Sample_Row (Row)));
                     begin
                        Write_Gray_Alpha_Pixel
                          (Column,
                           Row,
                           C1_Plane (C1_Plane'First + C1_R * Natural (C1_Component.Component_Width) + C1_C),
                           C2_Plane (C2_Plane'First + C2_R * Natural (C2_Component.Component_Width) + C2_C));
                     end;
                  end loop;
               end loop;
            end if;
         end;
      end Write_Two_Component_Blocks;

      procedure Write_Three_Component_Blocks
        (Blocks : Jpeglib.Coefficients.DCT_Block_Array;
         C1_Plane : in out Jpeglib.Streams.Byte_Array;
         C2_Plane : in out Jpeglib.Streams.Byte_Array;
         C3_Plane : in out Jpeglib.Streams.Byte_Array;
         Separate_Order : Boolean)
      is
         C1_Component : constant Internal.Frames.Frame_Component := Internal.Frames.Component (Header.Frame, 1);
         C2_Component : constant Internal.Frames.Frame_Component := Internal.Frames.Component (Header.Frame, 2);
         C3_Component : constant Internal.Frames.Frame_Component := Internal.Frames.Component (Header.Frame, 3);
         Width : constant Natural := Natural (Internal.Frames.Width (Header.Frame));
         Height : constant Natural := Natural (Internal.Frames.Height (Header.Frame));
         Component : Internal.Frames.Frame_Component;
         Dequantized : Internal.Transforms.Dequantized_Block;
         Samples : Internal.Transforms.Sample_Block;
         Placement : Internal.Sampling.Block_Placement;
         Block_Number : Positive := Blocks'First;

         procedure Store_Component_Block
           (Component_Index_Value : Component_Index;
            Target : in out Jpeglib.Streams.Byte_Array;
            Target_Width : Natural;
            MCU_C : MCU_Column;
            MCU_R : MCU_Row;
            H : Internal.Sampling.Block_Offset;
            V : Internal.Sampling.Block_Offset) is
         begin
            Component := Internal.Frames.Component (Header.Frame, Component_Index_Value);
            Table := Internal.Quantization.Table (Header.Quantization_State, Component.Quantization_Table);
            Dequantized := Internal.Transforms.Dequantize (Blocks (Block_Number), Table);
            Samples :=
              Internal.Transforms.Reconstruct_Block
                (Dequantized, Internal.Frames.Precision (Header.Frame));
            Placement :=
              Internal.Sampling.Placement
                (Header.Frame, Component_Index_Value, MCU_C, MCU_R, H, V);
            Store_Block_In_Plane (Target, Target_Width, Placement, Samples);
            Block_Number := Block_Number + 1;
         end Store_Component_Block;

         procedure Store_Separate_Component
           (Component_Index_Value : Component_Index;
            Frame_Item : Internal.Frames.Frame_Component;
            Target : in out Jpeglib.Streams.Byte_Array) is
            Padded_Order : constant Boolean :=
              Header.Entropy = Arithmetic
              and then Internal.Frames.Mode (Header.Frame) in Progressive_DCT | Differential_Progressive_DCT;
            Block_Rows : constant Natural :=
              (if Padded_Order
               then Natural (Internal.Frames.Padded_Block_Rows (Header.Frame, Component_Index_Value))
               else Natural (Frame_Item.Block_Rows));
            Block_Columns : constant Natural :=
              (if Padded_Order
               then Natural (Internal.Frames.Padded_Block_Columns (Header.Frame, Component_Index_Value))
               else Natural (Frame_Item.Block_Columns));
         begin
            for Row in Natural range 0 .. Block_Rows - 1 loop
               for Column in Natural range 0 .. Block_Columns - 1 loop
                  Store_Component_Block
                    (Component_Index_Value,
                     Target,
                     Natural (Frame_Item.Component_Width),
                     MCU_Column (Column / Natural (Frame_Item.Horizontal_Sampling)),
                     MCU_Row (Row / Natural (Frame_Item.Vertical_Sampling)),
                     Internal.Sampling.Block_Offset (Column mod Natural (Frame_Item.Horizontal_Sampling)),
                     Internal.Sampling.Block_Offset (Row mod Natural (Frame_Item.Vertical_Sampling)));
               end loop;
            end loop;
         end Store_Separate_Component;

         function Can_Write_Direct_Color_Rows return Boolean is
           (Header_Color_Model in YCbCr | RGB
            and then Can_Write_Direct_Output_Rows (Width, Height)
            and then Natural (C1_Component.Component_Width) = Width
            and then Natural (C1_Component.Component_Height) = Height
            and then Natural (C2_Component.Component_Width) = Width
            and then Natural (C2_Component.Component_Height) = Height
            and then Natural (C3_Component.Component_Width) = Width
            and then Natural (C3_Component.Component_Height) = Height);
      begin
         if Separate_Order then
            Store_Separate_Component (1, C1_Component, C1_Plane);
            Store_Separate_Component (2, C2_Component, C2_Plane);
            Store_Separate_Component (3, C3_Component, C3_Plane);
         else
            for MCU_R in MCU_Row range 0 .. Internal.Frames.MCU_Rows (Header.Frame) - 1 loop
               for MCU_C in MCU_Column range 0 .. Internal.Frames.MCU_Columns (Header.Frame) - 1 loop
                  for V in Internal.Sampling.Block_Offset range 0
                    .. Internal.Sampling.Block_Offset (C1_Component.Vertical_Sampling - 1)
                  loop
                     for H in Internal.Sampling.Block_Offset range 0
                       .. Internal.Sampling.Block_Offset (C1_Component.Horizontal_Sampling - 1)
                     loop
                        Store_Component_Block
                          (1, C1_Plane, Natural (C1_Component.Component_Width), MCU_C, MCU_R, H, V);
                     end loop;
                  end loop;

                  for V in Internal.Sampling.Block_Offset range 0
                    .. Internal.Sampling.Block_Offset (C2_Component.Vertical_Sampling - 1)
                  loop
                     for H in Internal.Sampling.Block_Offset range 0
                       .. Internal.Sampling.Block_Offset (C2_Component.Horizontal_Sampling - 1)
                     loop
                        Store_Component_Block
                          (2, C2_Plane, Natural (C2_Component.Component_Width), MCU_C, MCU_R, H, V);
                     end loop;
                  end loop;

                  for V in Internal.Sampling.Block_Offset range 0
                    .. Internal.Sampling.Block_Offset (C3_Component.Vertical_Sampling - 1)
                  loop
                     for H in Internal.Sampling.Block_Offset range 0
                       .. Internal.Sampling.Block_Offset (C3_Component.Horizontal_Sampling - 1)
                     loop
                        Store_Component_Block
                          (3, C3_Plane, Natural (C3_Component.Component_Width), MCU_C, MCU_R, H, V);
                     end loop;
                  end loop;
               end loop;
            end loop;
         end if;

         if Can_Write_Direct_Color_Rows then
            for Row in Natural range 0 .. Height - 1 loop
               declare
                  Row_Offset : constant Natural := Row * Width;
                  Written : Natural;
               begin
                  if Header_Color_Model = YCbCr then
                     Internal.Colors.Write_YCbCr_Row
                       (Output,
                        Row,
                        C1_Plane,
                        C2_Plane,
                        C3_Plane,
                        Row_Offset,
                        Width,
                        Object.Decode_Options.Alpha_Fill,
                        Written);
                  else
                     Internal.Colors.Write_RGB_Row
                       (Output,
                        Row,
                        C1_Plane,
                        C2_Plane,
                        C3_Plane,
                        Row_Offset,
                        Width,
                        Object.Decode_Options.Alpha_Fill,
                        Written);
                  end if;

                  if Written /= Width then
                     for Column in Natural range 0 .. Width - 1 loop
                        if Header_Color_Model = YCbCr then
                           Write_YCbCr_Pixel
                             (Column,
                              Row,
                              C1_Plane (C1_Plane'First + Row_Offset + Column),
                              C2_Plane (C2_Plane'First + Row_Offset + Column),
                              C3_Plane (C3_Plane'First + Row_Offset + Column));
                        else
                           Write_RGB_Pixel
                             (Column,
                              Row,
                              C1_Plane (C1_Plane'First + Row_Offset + Column),
                              C2_Plane (C2_Plane'First + Row_Offset + Column),
                              C3_Plane (C3_Plane'First + Row_Offset + Column));
                        end if;
                     end loop;
                  end if;
               end;
            end loop;
         elsif Header_Color_Model in YCbCr | RGB and then Can_Write_Direct_Output_Rows (Width, Height) then
            for Row in Natural range 0 .. Height - 1 loop
               declare
                  C1_Row : Jpeglib.Streams.Byte_Array (1 .. Width);
                  C2_Row : Jpeglib.Streams.Byte_Array (1 .. Width);
                  C3_Row : Jpeglib.Streams.Byte_Array (1 .. Width);
                  Written : Natural;
               begin
                  for Column in Natural range 0 .. Width - 1 loop
                     declare
                        C1_C : constant Natural :=
                          Natural
                            (Internal.Sampling.Component_Column_For_Image
                               (Header.Frame, 1, Internal.Sampling.Sample_Column (Column)));
                        C1_R : constant Natural :=
                          Natural
                            (Internal.Sampling.Component_Row_For_Image
                               (Header.Frame, 1, Internal.Sampling.Sample_Row (Row)));
                        C2_C : constant Natural :=
                          Natural
                            (Internal.Sampling.Component_Column_For_Image
                               (Header.Frame, 2, Internal.Sampling.Sample_Column (Column)));
                        C2_R : constant Natural :=
                          Natural
                            (Internal.Sampling.Component_Row_For_Image
                               (Header.Frame, 2, Internal.Sampling.Sample_Row (Row)));
                        C3_C : constant Natural :=
                          Natural
                            (Internal.Sampling.Component_Column_For_Image
                               (Header.Frame, 3, Internal.Sampling.Sample_Column (Column)));
                        C3_R : constant Natural :=
                          Natural
                            (Internal.Sampling.Component_Row_For_Image
                               (Header.Frame, 3, Internal.Sampling.Sample_Row (Row)));
                     begin
                        C1_Row (C1_Row'First + Column) :=
                          C1_Plane (C1_Plane'First + C1_R * Natural (C1_Component.Component_Width) + C1_C);
                        C2_Row (C2_Row'First + Column) :=
                          C2_Plane (C2_Plane'First + C2_R * Natural (C2_Component.Component_Width) + C2_C);
                        C3_Row (C3_Row'First + Column) :=
                          C3_Plane (C3_Plane'First + C3_R * Natural (C3_Component.Component_Width) + C3_C);
                     end;
                  end loop;

                  if Header_Color_Model = YCbCr then
                     Internal.Colors.Write_YCbCr_Row
                       (Output,
                        Row,
                        C1_Row,
                        C2_Row,
                        C3_Row,
                        0,
                        Width,
                        Object.Decode_Options.Alpha_Fill,
                        Written);
                  else
                     Internal.Colors.Write_RGB_Row
                       (Output,
                        Row,
                        C1_Row,
                        C2_Row,
                        C3_Row,
                        0,
                        Width,
                        Object.Decode_Options.Alpha_Fill,
                        Written);
                  end if;

                  if Written /= Width then
                     for Column in Natural range 0 .. Width - 1 loop
                        if Header_Color_Model = YCbCr then
                           Write_YCbCr_Pixel
                             (Column,
                              Row,
                              C1_Row (C1_Row'First + Column),
                              C2_Row (C2_Row'First + Column),
                              C3_Row (C3_Row'First + Column));
                        else
                           Write_RGB_Pixel
                             (Column,
                              Row,
                              C1_Row (C1_Row'First + Column),
                              C2_Row (C2_Row'First + Column),
                              C3_Row (C3_Row'First + Column));
                        end if;
                     end loop;
                  end if;
               end;
            end loop;
         else
            for Row in Natural range 0 .. Height - 1 loop
               for Column in Natural range 0 .. Width - 1 loop
                  declare
                     C1_C : constant Natural :=
                       Natural
                         (Internal.Sampling.Component_Column_For_Image
                            (Header.Frame, 1, Internal.Sampling.Sample_Column (Column)));
                     C1_R : constant Natural :=
                       Natural
                         (Internal.Sampling.Component_Row_For_Image
                            (Header.Frame, 1, Internal.Sampling.Sample_Row (Row)));
                     C2_C : constant Natural :=
                       Natural
                         (Internal.Sampling.Component_Column_For_Image
                            (Header.Frame, 2, Internal.Sampling.Sample_Column (Column)));
                     C2_R : constant Natural :=
                       Natural
                         (Internal.Sampling.Component_Row_For_Image
                            (Header.Frame, 2, Internal.Sampling.Sample_Row (Row)));
                     C3_C : constant Natural :=
                       Natural
                         (Internal.Sampling.Component_Column_For_Image
                            (Header.Frame, 3, Internal.Sampling.Sample_Column (Column)));
                     C3_R : constant Natural :=
                       Natural
                         (Internal.Sampling.Component_Row_For_Image
                            (Header.Frame, 3, Internal.Sampling.Sample_Row (Row)));
                  begin
                     if Header_Color_Model = YCbCr then
                        Write_YCbCr_Pixel
                          (Column,
                           Row,
                           C1_Plane (C1_Plane'First + C1_R * Natural (C1_Component.Component_Width) + C1_C),
                           C2_Plane (C2_Plane'First + C2_R * Natural (C2_Component.Component_Width) + C2_C),
                           C3_Plane (C3_Plane'First + C3_R * Natural (C3_Component.Component_Width) + C3_C));
                     else
                        Write_RGB_Pixel
                          (Column,
                           Row,
                           C1_Plane (C1_Plane'First + C1_R * Natural (C1_Component.Component_Width) + C1_C),
                           C2_Plane (C2_Plane'First + C2_R * Natural (C2_Component.Component_Width) + C2_C),
                           C3_Plane (C3_Plane'First + C3_R * Natural (C3_Component.Component_Width) + C3_C));
                     end if;
                  end;
               end loop;
            end loop;
         end if;
      end Write_Three_Component_Blocks;

      function Decode_Lossless_Image_From_Raw return Results.Result is
         Width : constant Natural := Natural (Internal.Frames.Width (Header.Frame));
         Height : constant Natural := Natural (Internal.Frames.Height (Header.Frame));
         procedure Free is new Ada.Unchecked_Deallocation
           (Jpeglib.Streams.Byte_Array,
            Jpeglib.Streams.Byte_Array_Access);
      begin
         case Components is
            when 1 =>
               declare
                  C1_Component : constant Internal.Frames.Frame_Component :=
                    Internal.Frames.Component (Header.Frame, 1);
                  C1_Width : constant Natural := Natural (C1_Component.Component_Width);
                  C1_Height : constant Natural := Natural (C1_Component.Component_Height);
                  C1 : aliased Jpeglib.Streams.Byte_Array := [1 .. C1_Width * C1_Height => 0];
                  Raw : Raw_Component_View_Array (1 .. 1) :=
                    [1 =>
                       (Width => C1_Width,
                        Height => C1_Height,
                        Stride => Row_Stride (C1_Width),
                        Accessible_Bytes => Byte_Count (C1_Width * C1_Height),
                        Storage => C1'Unchecked_Access)];
                  Outcome : constant Results.Result := Decode_Raw_Components (Object, Raw);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  if Can_Write_Direct_Output_Rows (Width, Height)
                    and then C1_Width = Width
                    and then C1_Height = Height
                  then
                     for Row in Natural range 0 .. Height - 1 loop
                        declare
                           Written : Natural := 0;
                        begin
                           Internal.Colors.Write_Gray_Row
                             (Output,
                              Row,
                              C1,
                              Row * Width,
                              Width,
                              Alpha => Object.Decode_Options.Alpha_Fill,
                              Written => Written);
                           if Written /= Width then
                              for Column in Natural range 0 .. Width - 1 loop
                                 Write_Gray_Pixel
                                   (Column, Row, C1 (C1'First + Row * C1_Width + Column));
                              end loop;
                           end if;
                        end;
                     end loop;
                  else
                     for Row in Natural range 0 .. Height - 1 loop
                        for Column in Natural range 0 .. Width - 1 loop
                           declare
                              C1_C : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Column_For_Image
                                     (Header.Frame, 1, Internal.Sampling.Sample_Column (Column)));
                              C1_R : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Row_For_Image
                                     (Header.Frame, 1, Internal.Sampling.Sample_Row (Row)));
                           begin
                              Write_Gray_Pixel
                                (Column, Row, C1 (C1'First + C1_R * C1_Width + C1_C));
                           end;
                        end loop;
                     end loop;
                  end if;
               end;

            when 2 =>
               declare
                  C1_Component : constant Internal.Frames.Frame_Component :=
                    Internal.Frames.Component (Header.Frame, 1);
                  C2_Component : constant Internal.Frames.Frame_Component :=
                    Internal.Frames.Component (Header.Frame, 2);
                  C1_Width : constant Natural := Natural (C1_Component.Component_Width);
                  C1_Height : constant Natural := Natural (C1_Component.Component_Height);
                  C2_Width : constant Natural := Natural (C2_Component.Component_Width);
                  C2_Height : constant Natural := Natural (C2_Component.Component_Height);
                  C1 : aliased Jpeglib.Streams.Byte_Array := [1 .. C1_Width * C1_Height => 0];
                  C2 : aliased Jpeglib.Streams.Byte_Array := [1 .. C2_Width * C2_Height => 0];
                  Raw : Raw_Component_View_Array (1 .. 2) :=
                    [1 =>
                       (Width => C1_Width,
                        Height => C1_Height,
                        Stride => Row_Stride (C1_Width),
                        Accessible_Bytes => Byte_Count (C1_Width * C1_Height),
                        Storage => C1'Unchecked_Access),
                     2 =>
                       (Width => C2_Width,
                        Height => C2_Height,
                        Stride => Row_Stride (C2_Width),
                        Accessible_Bytes => Byte_Count (C2_Width * C2_Height),
                        Storage => C2'Unchecked_Access)];
                  Outcome : constant Results.Result := Decode_Raw_Components (Object, Raw);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  if Can_Write_Direct_Output_Rows (Width, Height)
                    and then C1_Width = Width
                    and then C1_Height = Height
                    and then C2_Width = Width
                    and then C2_Height = Height
                  then
                     for Row in Natural range 0 .. Height - 1 loop
                        declare
                           Written : Natural := 0;
                        begin
                           Internal.Colors.Write_Gray_Alpha_Row
                             (Output,
                              Row,
                              C1,
                              C2,
                              Row * Width,
                              Width,
                              Written);
                           if Written /= Width then
                              for Column in Natural range 0 .. Width - 1 loop
                                 Write_Gray_Alpha_Pixel
                                   (Column,
                                    Row,
                                    C1 (C1'First + Row * C1_Width + Column),
                                    C2 (C2'First + Row * C2_Width + Column));
                              end loop;
                           end if;
                        end;
                     end loop;
                  else
                     for Row in Natural range 0 .. Height - 1 loop
                        for Column in Natural range 0 .. Width - 1 loop
                           declare
                              C1_C : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Column_For_Image
                                     (Header.Frame, 1, Internal.Sampling.Sample_Column (Column)));
                              C1_R : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Row_For_Image
                                     (Header.Frame, 1, Internal.Sampling.Sample_Row (Row)));
                              C2_C : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Column_For_Image
                                     (Header.Frame, 2, Internal.Sampling.Sample_Column (Column)));
                              C2_R : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Row_For_Image
                                     (Header.Frame, 2, Internal.Sampling.Sample_Row (Row)));
                           begin
                              Write_Gray_Alpha_Pixel
                                (Column,
                                 Row,
                                 C1 (C1'First + C1_R * C1_Width + C1_C),
                                 C2 (C2'First + C2_R * C2_Width + C2_C));
                           end;
                        end loop;
                     end loop;
                  end if;
               end;

            when 3 =>
               declare
                  C1_Component : constant Internal.Frames.Frame_Component :=
                    Internal.Frames.Component (Header.Frame, 1);
                  C2_Component : constant Internal.Frames.Frame_Component :=
                    Internal.Frames.Component (Header.Frame, 2);
                  C3_Component : constant Internal.Frames.Frame_Component :=
                    Internal.Frames.Component (Header.Frame, 3);
                  C1_Width : constant Natural := Natural (C1_Component.Component_Width);
                  C1_Height : constant Natural := Natural (C1_Component.Component_Height);
                  C2_Width : constant Natural := Natural (C2_Component.Component_Width);
                  C2_Height : constant Natural := Natural (C2_Component.Component_Height);
                  C3_Width : constant Natural := Natural (C3_Component.Component_Width);
                  C3_Height : constant Natural := Natural (C3_Component.Component_Height);
                  C1 : aliased Jpeglib.Streams.Byte_Array := [1 .. C1_Width * C1_Height => 0];
                  C2 : aliased Jpeglib.Streams.Byte_Array := [1 .. C2_Width * C2_Height => 0];
                  C3 : aliased Jpeglib.Streams.Byte_Array := [1 .. C3_Width * C3_Height => 0];
                  Raw : Raw_Component_View_Array (1 .. 3) :=
                    [1 =>
                       (Width => C1_Width,
                        Height => C1_Height,
                        Stride => Row_Stride (C1_Width),
                        Accessible_Bytes => Byte_Count (C1_Width * C1_Height),
                        Storage => C1'Unchecked_Access),
                     2 =>
                       (Width => C2_Width,
                        Height => C2_Height,
                        Stride => Row_Stride (C2_Width),
                        Accessible_Bytes => Byte_Count (C2_Width * C2_Height),
                        Storage => C2'Unchecked_Access),
                     3 =>
                       (Width => C3_Width,
                        Height => C3_Height,
                        Stride => Row_Stride (C3_Width),
                        Accessible_Bytes => Byte_Count (C3_Width * C3_Height),
                        Storage => C3'Unchecked_Access)];
                  Outcome : constant Results.Result := Decode_Raw_Components (Object, Raw);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  for Row in Natural range 0 .. Height - 1 loop
                     for Column in Natural range 0 .. Width - 1 loop
                        declare
                           C1_C : constant Natural :=
                             Natural
                               (Internal.Sampling.Component_Column_For_Image
                                  (Header.Frame, 1, Internal.Sampling.Sample_Column (Column)));
                           C1_R : constant Natural :=
                             Natural
                               (Internal.Sampling.Component_Row_For_Image
                                  (Header.Frame, 1, Internal.Sampling.Sample_Row (Row)));
                           C2_C : constant Natural :=
                             Natural
                               (Internal.Sampling.Component_Column_For_Image
                                  (Header.Frame, 2, Internal.Sampling.Sample_Column (Column)));
                           C2_R : constant Natural :=
                             Natural
                               (Internal.Sampling.Component_Row_For_Image
                                  (Header.Frame, 2, Internal.Sampling.Sample_Row (Row)));
                           C3_C : constant Natural :=
                             Natural
                               (Internal.Sampling.Component_Column_For_Image
                                  (Header.Frame, 3, Internal.Sampling.Sample_Column (Column)));
                           C3_R : constant Natural :=
                             Natural
                               (Internal.Sampling.Component_Row_For_Image
                                  (Header.Frame, 3, Internal.Sampling.Sample_Row (Row)));
                        begin
                        if Header_Color_Model = YCbCr then
                           Write_YCbCr_Pixel
                             (Column,
                              Row,
                              C1 (C1'First + C1_R * C1_Width + C1_C),
                              C2 (C2'First + C2_R * C2_Width + C2_C),
                              C3 (C3'First + C3_R * C3_Width + C3_C));
                        else
                           Write_RGB_Pixel
                             (Column,
                              Row,
                              C1 (C1'First + C1_R * C1_Width + C1_C),
                              C2 (C2'First + C2_R * C2_Width + C2_C),
                              C3 (C3'First + C3_R * C3_Width + C3_C));
                        end if;
                        end;
                     end loop;
                  end loop;
               end;

            when 4 =>
               declare
                  C1_Component : constant Internal.Frames.Frame_Component :=
                    Internal.Frames.Component (Header.Frame, 1);
                  C2_Component : constant Internal.Frames.Frame_Component :=
                    Internal.Frames.Component (Header.Frame, 2);
                  C3_Component : constant Internal.Frames.Frame_Component :=
                    Internal.Frames.Component (Header.Frame, 3);
                  C4_Component : constant Internal.Frames.Frame_Component :=
                    Internal.Frames.Component (Header.Frame, 4);
                  C1_Width : constant Natural := Natural (C1_Component.Component_Width);
                  C1_Height : constant Natural := Natural (C1_Component.Component_Height);
                  C2_Width : constant Natural := Natural (C2_Component.Component_Width);
                  C2_Height : constant Natural := Natural (C2_Component.Component_Height);
                  C3_Width : constant Natural := Natural (C3_Component.Component_Width);
                  C3_Height : constant Natural := Natural (C3_Component.Component_Height);
                  C4_Width : constant Natural := Natural (C4_Component.Component_Width);
                  C4_Height : constant Natural := Natural (C4_Component.Component_Height);
                  C1 : aliased Jpeglib.Streams.Byte_Array := [1 .. C1_Width * C1_Height => 0];
                  C2 : aliased Jpeglib.Streams.Byte_Array := [1 .. C2_Width * C2_Height => 0];
                  C3 : aliased Jpeglib.Streams.Byte_Array := [1 .. C3_Width * C3_Height => 0];
                  C4 : aliased Jpeglib.Streams.Byte_Array := [1 .. C4_Width * C4_Height => 0];
                  Raw : Raw_Component_View_Array (1 .. 4) :=
                    [1 =>
                       (Width => C1_Width,
                        Height => C1_Height,
                        Stride => Row_Stride (C1_Width),
                        Accessible_Bytes => Byte_Count (C1_Width * C1_Height),
                        Storage => C1'Unchecked_Access),
                     2 =>
                       (Width => C2_Width,
                        Height => C2_Height,
                        Stride => Row_Stride (C2_Width),
                        Accessible_Bytes => Byte_Count (C2_Width * C2_Height),
                        Storage => C2'Unchecked_Access),
                     3 =>
                       (Width => C3_Width,
                        Height => C3_Height,
                        Stride => Row_Stride (C3_Width),
                        Accessible_Bytes => Byte_Count (C3_Width * C3_Height),
                        Storage => C3'Unchecked_Access),
                     4 =>
                       (Width => C4_Width,
                        Height => C4_Height,
                        Stride => Row_Stride (C4_Width),
                        Accessible_Bytes => Byte_Count (C4_Width * C4_Height),
                        Storage => C4'Unchecked_Access)];
                  Outcome : constant Results.Result := Decode_Raw_Components (Object, Raw);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  if Header_Color_Model in CMYK | YCCK
                    and then Can_Write_Direct_Output_Rows (Width, Height)
                    and then C1_Width = Width
                    and then C1_Height = Height
                    and then C2_Width = Width
                    and then C2_Height = Height
                    and then C3_Width = Width
                    and then C3_Height = Height
                    and then C4_Width = Width
                    and then C4_Height = Height
                  then
                     for Row in Natural range 0 .. Height - 1 loop
                        declare
                           Row_Offset : constant Natural := Row * Width;
                           Written : Natural := 0;
                        begin
                           if Header_Color_Model = YCCK then
                              Internal.Colors.Write_YCCK_Row
                                (Output,
                                 Row,
                                 C1,
                                 C2,
                                 C3,
                                 C4,
                                 Row_Offset,
                                 Width,
                                 Object.Decode_Options.Alpha_Fill,
                                 Written);
                           else
                              Internal.Colors.Write_CMYK_Row
                                (Output,
                                 Row,
                                 C1,
                                 C2,
                                 C3,
                                 C4,
                                 Row_Offset,
                                 Width,
                                 Object.Decode_Options.Alpha_Fill,
                                 Written);
                           end if;

                           if Written /= Width then
                              for Column in Natural range 0 .. Width - 1 loop
                                 Write_Four_Component_Pixel
                                   (Column,
                                    Row,
                                    C1 (C1'First + Row_Offset + Column),
                                    C2 (C2'First + Row_Offset + Column),
                                    C3 (C3'First + Row_Offset + Column),
                                    C4 (C4'First + Row_Offset + Column));
                              end loop;
                           end if;
                        end;
                     end loop;
                  else
                     for Row in Natural range 0 .. Height - 1 loop
                        for Column in Natural range 0 .. Width - 1 loop
                           declare
                              C1_C : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Column_For_Image
                                     (Header.Frame, 1, Internal.Sampling.Sample_Column (Column)));
                              C1_R : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Row_For_Image
                                     (Header.Frame, 1, Internal.Sampling.Sample_Row (Row)));
                              C2_C : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Column_For_Image
                                     (Header.Frame, 2, Internal.Sampling.Sample_Column (Column)));
                              C2_R : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Row_For_Image
                                     (Header.Frame, 2, Internal.Sampling.Sample_Row (Row)));
                              C3_C : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Column_For_Image
                                     (Header.Frame, 3, Internal.Sampling.Sample_Column (Column)));
                              C3_R : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Row_For_Image
                                     (Header.Frame, 3, Internal.Sampling.Sample_Row (Row)));
                              C4_C : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Column_For_Image
                                     (Header.Frame, 4, Internal.Sampling.Sample_Column (Column)));
                              C4_R : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Row_For_Image
                                     (Header.Frame, 4, Internal.Sampling.Sample_Row (Row)));
                           begin
                              Write_Four_Component_Pixel
                                (Column,
                                 Row,
                                 C1 (C1'First + C1_R * C1_Width + C1_C),
                                 C2 (C2'First + C2_R * C2_Width + C2_C),
                                 C3 (C3'First + C3_R * C3_Width + C3_C),
                                 C4 (C4'First + C4_R * C4_Width + C4_C));
                           end;
                        end loop;
                     end loop;
                  end if;
               end;
            when others =>
               declare
                  Component_Total : constant Component_Index := Component_Index (Components);
                  type Plane_Access_Array is array (Component_Index range <>) of Jpeglib.Streams.Byte_Array_Access;
                  Planes : Plane_Access_Array (1 .. Component_Total) := [others => null];
                  Raw : Raw_Component_View_Array (1 .. Component_Total);
                  Outcome : Results.Result;

                  procedure Release_Planes is
                  begin
                     for Index in Planes'Range loop
                        if Planes (Index) /= null then
                           Free (Planes (Index));
                        end if;
                     end loop;
                  end Release_Planes;
               begin
                  for Index in Component_Index range 1 .. Component_Total loop
                     declare
                        Item : constant Internal.Frames.Frame_Component :=
                          Internal.Frames.Component (Header.Frame, Index);
                        Plane_Width : constant Natural := Natural (Item.Component_Width);
                        Plane_Height : constant Natural := Natural (Item.Component_Height);
                        Plane_Bytes : constant Natural := Plane_Width * Plane_Height;
                     begin
                        Planes (Index) := new Jpeglib.Streams.Byte_Array'(1 .. Plane_Bytes => 0);
                        Raw (Index) :=
                          (Width => Plane_Width,
                           Height => Plane_Height,
                           Stride => Row_Stride (Plane_Width),
                           Accessible_Bytes => Byte_Count (Plane_Bytes),
                           Storage => Planes (Index));
                     end;
                  end loop;

                  Outcome := Decode_Raw_Components (Object, Raw);
                  if not Results.Succeeded (Outcome) then
                     Release_Planes;
                     return Outcome;
                  end if;

                  declare
                     C1_Component : constant Internal.Frames.Frame_Component :=
                       Internal.Frames.Component (Header.Frame, 1);
                     C2_Component : constant Internal.Frames.Frame_Component :=
                       Internal.Frames.Component (Header.Frame, 2);
                     C3_Component : constant Internal.Frames.Frame_Component :=
                       Internal.Frames.Component (Header.Frame, 3);
                     C4_Component : constant Internal.Frames.Frame_Component :=
                       Internal.Frames.Component (Header.Frame, 4);
                     C1_Width : constant Natural := Natural (C1_Component.Component_Width);
                     C2_Width : constant Natural := Natural (C2_Component.Component_Width);
                     C3_Width : constant Natural := Natural (C3_Component.Component_Width);
                     C4_Width : constant Natural := Natural (C4_Component.Component_Width);
                  begin
                     for Row in Natural range 0 .. Height - 1 loop
                        for Column in Natural range 0 .. Width - 1 loop
                           declare
                              C1_C : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Column_For_Image
                                     (Header.Frame, 1, Internal.Sampling.Sample_Column (Column)));
                              C1_R : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Row_For_Image
                                     (Header.Frame, 1, Internal.Sampling.Sample_Row (Row)));
                              C2_C : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Column_For_Image
                                     (Header.Frame, 2, Internal.Sampling.Sample_Column (Column)));
                              C2_R : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Row_For_Image
                                     (Header.Frame, 2, Internal.Sampling.Sample_Row (Row)));
                              C3_C : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Column_For_Image
                                     (Header.Frame, 3, Internal.Sampling.Sample_Column (Column)));
                              C3_R : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Row_For_Image
                                     (Header.Frame, 3, Internal.Sampling.Sample_Row (Row)));
                              C4_C : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Column_For_Image
                                     (Header.Frame, 4, Internal.Sampling.Sample_Column (Column)));
                              C4_R : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Row_For_Image
                                     (Header.Frame, 4, Internal.Sampling.Sample_Row (Row)));
                           begin
                              Write_Four_Component_Pixel
                                (Column,
                                 Row,
                                 Planes (1) (Planes (1)'First + C1_R * C1_Width + C1_C),
                                 Planes (2) (Planes (2)'First + C2_R * C2_Width + C2_C),
                                 Planes (3) (Planes (3)'First + C3_R * C3_Width + C3_C),
                                 Planes (4) (Planes (4)'First + C4_R * C4_Width + C4_C));
                           end;
                        end loop;
                     end loop;
                  end;

                  Release_Planes;
               exception
                  when others =>
                     Release_Planes;
                     raise;
               end;
         end case;

         Object.Current_State := Completed;
         return Results.Success;
      end Decode_Lossless_Image_From_Raw;
   begin
      if Object.Current_State not in Initialized | Header_Ready then
         Fail (Object, Errors.Invalid_State);
         return Results.Failure (Object.First_Error);
      end if;

      if Object.Current_State = Initialized then
         Header_Outcome := Read_Header (Object);
         if not Results.Succeeded (Header_Outcome) then
            return Header_Outcome;
         end if;
      end if;

      Header := Object.Saved_Header;
      if not Internal.Frames.Height_Defined (Header.Frame) then
         Header_Outcome :=
           Internal.Frames.Define_Height
             (Header.Frame, Pending_Source_Height_From_Image_Output);
         if not Results.Succeeded (Header_Outcome) then
            Fail_With (Object, Header_Outcome.First_Error);
            return Results.Failure (Object.First_Error);
         end if;

         Object.Saved_Header.Frame := Header.Frame;
         Object.Header_Info := To_Image_Info (Object.Saved_Header);
      end if;

      Components := Internal.Frames.Components (Header.Frame);
      Header_Color_Model := Infer_Color_Model (Header);
      if Object.Decode_Options.Apply_Exif_Orientation
        and then Header.Has_Exif_Orientation
        and then Swaps_Dimensions (Header.Exif_Orientation)
      then
         Expected_Width := Image_Width (Reduced_Dimension (Natural (Internal.Frames.Height (Header.Frame))));
         Expected_Height := Image_Height (Reduced_Dimension (Natural (Internal.Frames.Width (Header.Frame))));
      else
         Expected_Width := Image_Width (Reduced_Dimension (Natural (Internal.Frames.Width (Header.Frame))));
         Expected_Height := Image_Height (Reduced_Dimension (Natural (Internal.Frames.Height (Header.Frame))));
      end if;

      if Internal.Frames.Mode (Header.Frame)
        not in Baseline_DCT | Extended_Sequential_DCT | Progressive_DCT |
               Differential_Sequential_DCT | Differential_Progressive_DCT |
               Lossless | Differential_Lossless
      then
         Fail (Object, Errors.Unsupported_Feature);
         return Results.Failure (Object.First_Error);
      end if;

      if not Images.Is_Valid (Output)
        or else Output.Descriptor.Width /= Expected_Width
        or else Output.Descriptor.Height /= Expected_Height
      then
         Fail_With (Object, Output_Error);
         return Results.Failure (Object.First_Error);
      end if;

      Expected_Bytes :=
        Images.Minimum_Row_Bytes (Output.Descriptor.Width, Output.Descriptor.Format)
        * Byte_Count (Output.Descriptor.Height);
      if Expected_Bytes > Object.Decode_Limits.Max_Output_Bytes then
         Fail_With (Object, Output_Error);
         return Results.Failure (Object.First_Error);
      end if;

      if Internal.Frames.Mode (Header.Frame) in Lossless | Differential_Lossless then
         if Header.Entropy not in Huffman | Arithmetic
           or else Internal.Frames.Precision (Header.Frame) not in 8 | 12
         then
            Fail (Object, Errors.Unsupported_Feature);
            return Results.Failure (Object.First_Error);
         end if;

         if Component_Plane_Bytes > Object.Decode_Limits.Max_Allocation_Bytes then
            Fail_With
              (Object,
               Errors.Make
                 (Errors.Output_Limit_Exceeded,
                  (Detail => Long_Long_Integer (Component_Plane_Bytes), others => <>)));
            return Results.Failure (Object.First_Error);
         end if;

         Header_Outcome := Decode_Lossless_Image_From_Raw;
         if not Results.Succeeded (Header_Outcome) then
            Fail_With (Object, Header_Outcome.First_Error);
            return Results.Failure (Object.First_Error);
         end if;

         return Results.Success;
      end if;

      Header_Outcome := Missing_Quantization_Table;
      if not Results.Succeeded (Header_Outcome) then
         Fail_With (Object, Header_Outcome.First_Error);
         return Results.Failure (Object.First_Error);
      end if;

      Required_Blocks := Internal.Frames.Total_Blocks (Header.Frame);
      if Coefficient_Bytes (Required_Blocks) > Object.Decode_Limits.Max_Coefficient_Bytes
        or else Coefficient_Bytes (Required_Blocks) + Component_Plane_Bytes > Object.Decode_Limits.Max_Allocation_Bytes
      then
         Fail_With
           (Object,
            Errors.Make
              (Errors.Output_Limit_Exceeded, (Detail => Long_Long_Integer (Required_Blocks), others => <>)));
         return Results.Failure (Object.First_Error);
      end if;

      Frame_Component := Internal.Frames.Component (Header.Frame, 1);
      Table := Internal.Quantization.Table (Header.Quantization_State, Frame_Component.Quantization_Table);
      declare
         Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Required_Blocks)) := [others => [others => 0]];
      begin
         Object.Current_State := Decoding;
         declare
            Result : constant Internal.Decoder.Coefficient_Result :=
              (if Internal.Frames.Mode (Header.Frame) in Progressive_DCT | Differential_Progressive_DCT then
                 Internal.Decoder.Decode_Progressive_Coefficients (Header, Object.Input, Blocks)
               elsif Header.Entropy = Entropy_Mode'Val (1) then
                 Internal.Decoder.Decode_Arithmetic_Coefficients (Header, Object.Input, Blocks)
               else
                 Internal.Decoder.Decode_Baseline_Coefficients (Header, Object.Input, Blocks));
         begin
            if not Results.Succeeded (Result.Outcome) then
               Fail_With (Object, Result.Outcome.First_Error);
               return Results.Failure (Object.First_Error);
            end if;

            declare
               Continuation_Outcome : constant Results.Result :=
                 Compose_Hierarchical_DCT_Continuation (Object, Result, Blocks);
            begin
               if not Results.Succeeded (Continuation_Outcome) then
                  Fail_With (Object, Continuation_Outcome.First_Error);
                  return Results.Failure (Object.First_Error);
               end if;
            end;

            Object.Saved_Header := Result.Header;
            Object.Header_Info := To_Image_Info (Result.Header);
         end;

         if Components = 1 then
            Write_Grayscale_Blocks (Blocks);
         elsif Components = 2 then
            declare
               C1_Component : constant Internal.Frames.Frame_Component := Internal.Frames.Component (Header.Frame, 1);
               C2_Component : constant Internal.Frames.Frame_Component := Internal.Frames.Component (Header.Frame, 2);
               C1_Plane : Jpeglib.Streams.Byte_Array
                 (1 .. Natural (C1_Component.Component_Width) * Natural (C1_Component.Component_Height)) :=
                   [others => 128];
               C2_Plane : Jpeglib.Streams.Byte_Array
                 (1 .. Natural (C2_Component.Component_Width) * Natural (C2_Component.Component_Height)) :=
                   [others => 128];
            begin
               Write_Two_Component_Blocks
                 (Blocks,
                  C1_Plane,
                  C2_Plane,
                  Internal.Frames.Mode (Header.Frame) in Progressive_DCT | Differential_Progressive_DCT
                  or else Internal.Scans.Components (Header.Scan) = 1);
            end;
         elsif Components = 3 then
            declare
               Y_Component : constant Internal.Frames.Frame_Component := Internal.Frames.Component (Header.Frame, 1);
               Cb_Component : constant Internal.Frames.Frame_Component := Internal.Frames.Component (Header.Frame, 2);
               Cr_Component : constant Internal.Frames.Frame_Component := Internal.Frames.Component (Header.Frame, 3);
               Y_Plane : Jpeglib.Streams.Byte_Array
                 (1 .. Natural (Y_Component.Component_Width) * Natural (Y_Component.Component_Height)) :=
                   [others => 128];
               Cb_Plane : Jpeglib.Streams.Byte_Array
                 (1 .. Natural (Cb_Component.Component_Width) * Natural (Cb_Component.Component_Height)) :=
                   [others => 128];
               Cr_Plane : Jpeglib.Streams.Byte_Array
                 (1 .. Natural (Cr_Component.Component_Width) * Natural (Cr_Component.Component_Height)) :=
                   [others => 128];
            begin
               Write_Three_Component_Blocks
                 (Blocks,
                  Y_Plane,
                  Cb_Plane,
                  Cr_Plane,
                  Internal.Frames.Mode (Header.Frame) in Progressive_DCT | Differential_Progressive_DCT
                  or else Internal.Scans.Components (Header.Scan) = 1);
            end;
         else
            declare
               C_Component : constant Internal.Frames.Frame_Component := Internal.Frames.Component (Header.Frame, 1);
               M_Component : constant Internal.Frames.Frame_Component := Internal.Frames.Component (Header.Frame, 2);
               Y_Component : constant Internal.Frames.Frame_Component := Internal.Frames.Component (Header.Frame, 3);
               K_Component : constant Internal.Frames.Frame_Component := Internal.Frames.Component (Header.Frame, 4);
               Width : constant Natural := Natural (Internal.Frames.Width (Header.Frame));
               Height : constant Natural := Natural (Internal.Frames.Height (Header.Frame));
               Component : Internal.Frames.Frame_Component;
               Dequantized : Internal.Transforms.Dequantized_Block;
               Samples : Internal.Transforms.Sample_Block;
               Placement : Internal.Sampling.Block_Placement;
               Block_Number : Positive := Blocks'First;
               C_Plane : Jpeglib.Streams.Byte_Array
                 (1 .. Natural (C_Component.Component_Width) * Natural (C_Component.Component_Height)) :=
                   [others => 128];
               M_Plane : Jpeglib.Streams.Byte_Array
                 (1 .. Natural (M_Component.Component_Width) * Natural (M_Component.Component_Height)) :=
                   [others => 128];
               Y_Plane : Jpeglib.Streams.Byte_Array
                 (1 .. Natural (Y_Component.Component_Width) * Natural (Y_Component.Component_Height)) :=
                   [others => 128];
               K_Plane : Jpeglib.Streams.Byte_Array
                 (1 .. Natural (K_Component.Component_Width) * Natural (K_Component.Component_Height)) :=
                   [others => 128];

               procedure Store_Component_Block
                 (Component_Index_Value : Component_Index;
                  Target : in out Jpeglib.Streams.Byte_Array;
                  Target_Width : Natural;
                  MCU_C : MCU_Column;
                  MCU_R : MCU_Row;
                  H : Internal.Sampling.Block_Offset;
                  V : Internal.Sampling.Block_Offset) is
               begin
                  Component := Internal.Frames.Component (Header.Frame, Component_Index_Value);
                  Table := Internal.Quantization.Table (Header.Quantization_State, Component.Quantization_Table);
                  Dequantized := Internal.Transforms.Dequantize (Blocks (Block_Number), Table);
                  Samples :=
                    Internal.Transforms.Reconstruct_Block
                      (Dequantized, Internal.Frames.Precision (Header.Frame));
                  Placement :=
                    Internal.Sampling.Placement
                      (Header.Frame, Component_Index_Value, MCU_C, MCU_R, H, V);
                  Store_Block_In_Plane (Target, Target_Width, Placement, Samples);
                  Block_Number := Block_Number + 1;
               end Store_Component_Block;

               procedure Store_Component
                 (Component_Index_Value : Component_Index;
                  Frame_Item : Internal.Frames.Frame_Component;
                  Target : in out Jpeglib.Streams.Byte_Array;
                  MCU_C : MCU_Column;
                  MCU_R : MCU_Row) is
               begin
                  for V in Internal.Sampling.Block_Offset range 0
                    .. Internal.Sampling.Block_Offset (Frame_Item.Vertical_Sampling - 1)
                  loop
                     for H in Internal.Sampling.Block_Offset range 0
                       .. Internal.Sampling.Block_Offset (Frame_Item.Horizontal_Sampling - 1)
                     loop
                        Store_Component_Block
                          (Component_Index_Value,
                           Target,
                           Natural (Frame_Item.Component_Width),
                           MCU_C,
                           MCU_R,
                           H,
                           V);
                     end loop;
                  end loop;
               end Store_Component;

               procedure Skip_Component (Frame_Item : Internal.Frames.Frame_Component) is
               begin
                  Block_Number :=
                    Block_Number
                    + Positive
                        (Natural (Frame_Item.Horizontal_Sampling) * Natural (Frame_Item.Vertical_Sampling));
               end Skip_Component;

               procedure Store_Separate_Component
                 (Component_Index_Value : Component_Index;
                  Frame_Item : Internal.Frames.Frame_Component;
                  Target : in out Jpeglib.Streams.Byte_Array) is
                  Padded_Order : constant Boolean :=
                    Header.Entropy = Arithmetic
                    and then Internal.Frames.Mode (Header.Frame) in Progressive_DCT | Differential_Progressive_DCT;
                  Block_Rows : constant Natural :=
                    (if Padded_Order
                     then Natural (Internal.Frames.Padded_Block_Rows (Header.Frame, Component_Index_Value))
                     else Natural (Frame_Item.Block_Rows));
                  Block_Columns : constant Natural :=
                    (if Padded_Order
                     then Natural (Internal.Frames.Padded_Block_Columns (Header.Frame, Component_Index_Value))
                     else Natural (Frame_Item.Block_Columns));
               begin
                  for Row in Natural range 0 .. Block_Rows - 1 loop
                     for Column in Natural range 0 .. Block_Columns - 1 loop
                        Store_Component_Block
                          (Component_Index_Value,
                           Target,
                           Natural (Frame_Item.Component_Width),
                           MCU_Column (Column / Natural (Frame_Item.Horizontal_Sampling)),
                           MCU_Row (Row / Natural (Frame_Item.Vertical_Sampling)),
                           Internal.Sampling.Block_Offset (Column mod Natural (Frame_Item.Horizontal_Sampling)),
                           Internal.Sampling.Block_Offset (Row mod Natural (Frame_Item.Vertical_Sampling)));
                     end loop;
                  end loop;
               end Store_Separate_Component;

               function Can_Write_Direct_Four_Component_Rows return Boolean is
                 (Header_Color_Model in CMYK | YCCK
                  and then Can_Write_Direct_Output_Rows (Width, Height)
                  and then Natural (C_Component.Component_Width) = Width
                  and then Natural (C_Component.Component_Height) = Height
                  and then Natural (M_Component.Component_Width) = Width
                  and then Natural (M_Component.Component_Height) = Height
                  and then Natural (Y_Component.Component_Width) = Width
                  and then Natural (Y_Component.Component_Height) = Height
                  and then Natural (K_Component.Component_Width) = Width
                  and then Natural (K_Component.Component_Height) = Height);
            begin
               if Internal.Scans.Components (Header.Scan) = 1 then
                  Store_Separate_Component (1, C_Component, C_Plane);
                  Store_Separate_Component (2, M_Component, M_Plane);
                  Store_Separate_Component (3, Y_Component, Y_Plane);
                  Store_Separate_Component (4, K_Component, K_Plane);
               else
                  for MCU_R in MCU_Row range 0 .. Internal.Frames.MCU_Rows (Header.Frame) - 1 loop
                     for MCU_C in MCU_Column range 0 .. Internal.Frames.MCU_Columns (Header.Frame) - 1 loop
                        Store_Component (1, C_Component, C_Plane, MCU_C, MCU_R);
                        Store_Component (2, M_Component, M_Plane, MCU_C, MCU_R);
                        Store_Component (3, Y_Component, Y_Plane, MCU_C, MCU_R);
                        Store_Component (4, K_Component, K_Plane, MCU_C, MCU_R);
                        for Extra_Component in Component_Index range 5 .. Component_Index (Components) loop
                           Skip_Component (Internal.Frames.Component (Header.Frame, Extra_Component));
                        end loop;
                     end loop;
                  end loop;
               end if;

               if Can_Write_Direct_Four_Component_Rows then
                  for Row in Natural range 0 .. Height - 1 loop
                     declare
                        Row_Offset : constant Natural := Row * Width;
                        Written : Natural;
                     begin
                        if Header_Color_Model = YCCK then
                           Internal.Colors.Write_YCCK_Row
                             (Output,
                              Row,
                              C_Plane,
                              M_Plane,
                              Y_Plane,
                              K_Plane,
                              Row_Offset,
                              Width,
                              Object.Decode_Options.Alpha_Fill,
                              Written);
                        else
                           Internal.Colors.Write_CMYK_Row
                             (Output,
                              Row,
                              C_Plane,
                              M_Plane,
                              Y_Plane,
                              K_Plane,
                              Row_Offset,
                              Width,
                              Object.Decode_Options.Alpha_Fill,
                              Written);
                        end if;

                        if Written /= Width then
                           for Column in Natural range 0 .. Width - 1 loop
                              Write_Four_Component_Pixel
                                (Column,
                                 Row,
                                 C_Plane (C_Plane'First + Row_Offset + Column),
                                 M_Plane (M_Plane'First + Row_Offset + Column),
                                 Y_Plane (Y_Plane'First + Row_Offset + Column),
                                 K_Plane (K_Plane'First + Row_Offset + Column));
                           end loop;
                        end if;
                     end;
                  end loop;
               elsif Header_Color_Model in CMYK | YCCK and then Can_Write_Direct_Output_Rows (Width, Height) then
                  for Row in Natural range 0 .. Height - 1 loop
                     declare
                        C_Row : Jpeglib.Streams.Byte_Array (1 .. Width);
                        M_Row : Jpeglib.Streams.Byte_Array (1 .. Width);
                        Y_Row : Jpeglib.Streams.Byte_Array (1 .. Width);
                        K_Row : Jpeglib.Streams.Byte_Array (1 .. Width);
                        Written : Natural;
                     begin
                        for Column in Natural range 0 .. Width - 1 loop
                           declare
                              C_C : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Column_For_Image
                                     (Header.Frame, 1, Internal.Sampling.Sample_Column (Column)));
                              C_R : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Row_For_Image
                                     (Header.Frame, 1, Internal.Sampling.Sample_Row (Row)));
                              M_C : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Column_For_Image
                                     (Header.Frame, 2, Internal.Sampling.Sample_Column (Column)));
                              M_R : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Row_For_Image
                                     (Header.Frame, 2, Internal.Sampling.Sample_Row (Row)));
                              Y_C : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Column_For_Image
                                     (Header.Frame, 3, Internal.Sampling.Sample_Column (Column)));
                              Y_R : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Row_For_Image
                                     (Header.Frame, 3, Internal.Sampling.Sample_Row (Row)));
                              K_C : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Column_For_Image
                                     (Header.Frame, 4, Internal.Sampling.Sample_Column (Column)));
                              K_R : constant Natural :=
                                Natural
                                  (Internal.Sampling.Component_Row_For_Image
                                     (Header.Frame, 4, Internal.Sampling.Sample_Row (Row)));
                           begin
                              C_Row (C_Row'First + Column) :=
                                C_Plane (C_Plane'First + C_R * Natural (C_Component.Component_Width) + C_C);
                              M_Row (M_Row'First + Column) :=
                                M_Plane (M_Plane'First + M_R * Natural (M_Component.Component_Width) + M_C);
                              Y_Row (Y_Row'First + Column) :=
                                Y_Plane (Y_Plane'First + Y_R * Natural (Y_Component.Component_Width) + Y_C);
                              K_Row (K_Row'First + Column) :=
                                K_Plane (K_Plane'First + K_R * Natural (K_Component.Component_Width) + K_C);
                           end;
                        end loop;

                        if Header_Color_Model = YCCK then
                           Internal.Colors.Write_YCCK_Row
                             (Output,
                              Row,
                              C_Row,
                              M_Row,
                              Y_Row,
                              K_Row,
                              0,
                              Width,
                              Object.Decode_Options.Alpha_Fill,
                              Written);
                        else
                           Internal.Colors.Write_CMYK_Row
                             (Output,
                              Row,
                              C_Row,
                              M_Row,
                              Y_Row,
                              K_Row,
                              0,
                              Width,
                              Object.Decode_Options.Alpha_Fill,
                              Written);
                        end if;

                        if Written /= Width then
                           for Column in Natural range 0 .. Width - 1 loop
                              Write_Four_Component_Pixel
                                (Column,
                                 Row,
                                 C_Row (C_Row'First + Column),
                                 M_Row (M_Row'First + Column),
                                 Y_Row (Y_Row'First + Column),
                                 K_Row (K_Row'First + Column));
                           end loop;
                        end if;
                     end;
                  end loop;
               else
                  for Row in Natural range 0 .. Height - 1 loop
                     for Column in Natural range 0 .. Width - 1 loop
                        declare
                           C_C : constant Natural :=
                             Natural
                               (Internal.Sampling.Component_Column_For_Image
                                  (Header.Frame, 1, Internal.Sampling.Sample_Column (Column)));
                           C_R : constant Natural :=
                             Natural
                               (Internal.Sampling.Component_Row_For_Image
                                  (Header.Frame, 1, Internal.Sampling.Sample_Row (Row)));
                           M_C : constant Natural :=
                             Natural
                               (Internal.Sampling.Component_Column_For_Image
                                  (Header.Frame, 2, Internal.Sampling.Sample_Column (Column)));
                           M_R : constant Natural :=
                             Natural
                               (Internal.Sampling.Component_Row_For_Image
                                  (Header.Frame, 2, Internal.Sampling.Sample_Row (Row)));
                           Y_C : constant Natural :=
                             Natural
                               (Internal.Sampling.Component_Column_For_Image
                                  (Header.Frame, 3, Internal.Sampling.Sample_Column (Column)));
                           Y_R : constant Natural :=
                             Natural
                               (Internal.Sampling.Component_Row_For_Image
                                  (Header.Frame, 3, Internal.Sampling.Sample_Row (Row)));
                           K_C : constant Natural :=
                             Natural
                               (Internal.Sampling.Component_Column_For_Image
                                  (Header.Frame, 4, Internal.Sampling.Sample_Column (Column)));
                           K_R : constant Natural :=
                             Natural
                               (Internal.Sampling.Component_Row_For_Image
                                  (Header.Frame, 4, Internal.Sampling.Sample_Row (Row)));
                        begin
                           if Header_Color_Model not in CMYK | YCCK then
                              Write_RGB_Pixel
                                (Column,
                                 Row,
                                 C_Plane (C_Plane'First + C_R * Natural (C_Component.Component_Width) + C_C),
                                 M_Plane (M_Plane'First + M_R * Natural (M_Component.Component_Width) + M_C),
                                 Y_Plane (Y_Plane'First + Y_R * Natural (Y_Component.Component_Width) + Y_C));
                              if Output.Descriptor.Format in Images.Gray_Alpha_16 | Images.RGBA_32 | Images.BGRA_32
                                and then Emits_Reduced_Pixel (Column, Row)
                              then
                                 declare
                                    Target_X : Natural;
                                    Target_Y : Natural;
                                 begin
                                    Map_Output_Coordinate (Column, Row, Target_X, Target_Y);
                                    Internal.Colors.Write_RGB
                                      (Output,
                                       Target_X,
                                       Target_Y,
                                       C_Plane (C_Plane'First + C_R * Natural (C_Component.Component_Width) + C_C),
                                       M_Plane (M_Plane'First + M_R * Natural (M_Component.Component_Width) + M_C),
                                       Y_Plane (Y_Plane'First + Y_R * Natural (Y_Component.Component_Width) + Y_C),
                                       K_Plane (K_Plane'First + K_R * Natural (K_Component.Component_Width) + K_C));
                                 end;
                              end if;
                           elsif Header_Color_Model = YCCK then
                              if Emits_Reduced_Pixel (Column, Row) then
                                 declare
                                    Target_X : Natural;
                                    Target_Y : Natural;
                                 begin
                                    Map_Output_Coordinate (Column, Row, Target_X, Target_Y);
                                    Internal.Colors.Write_YCCK
                                      (Output,
                                       Target_X,
                                       Target_Y,
                                       C_Plane (C_Plane'First + C_R * Natural (C_Component.Component_Width) + C_C),
                                       M_Plane (M_Plane'First + M_R * Natural (M_Component.Component_Width) + M_C),
                                       Y_Plane (Y_Plane'First + Y_R * Natural (Y_Component.Component_Width) + Y_C),
                                       K_Plane (K_Plane'First + K_R * Natural (K_Component.Component_Width) + K_C),
                                       Object.Decode_Options.Alpha_Fill);
                                 end;
                              end if;
                           else
                              Write_CMYK_Pixel
                                (Column,
                                 Row,
                                 C_Plane (C_Plane'First + C_R * Natural (C_Component.Component_Width) + C_C),
                                 M_Plane (M_Plane'First + M_R * Natural (M_Component.Component_Width) + M_C),
                                 Y_Plane (Y_Plane'First + Y_R * Natural (Y_Component.Component_Width) + Y_C),
                                 K_Plane (K_Plane'First + K_R * Natural (K_Component.Component_Width) + K_C));
                           end if;
                        end;
                     end loop;
                  end loop;
               end if;
            end;
         end if;
      end;

      Object.Current_State := Completed;
      return Results.Success;
   end Decode_Image;

   function Last_Error (Object : Decoder) return Errors.Error is
   begin
      return Object.First_Error;
   end Last_Error;

   procedure Cancel (Object : in out Decoder) is
   begin
      if not Errors.Is_Fatal (Object.First_Error) then
         Object.First_Error := Errors.Make (Errors.Operation_Cancelled);
      end if;
      Object.Current_State := Cancelled;
   end Cancel;

   procedure Finalize (Object : in out Decoder) is
   begin
      Object.Input := null;
      Object.Current_State := Finalized;
   end Finalize;
end Jpeglib.Decoding;

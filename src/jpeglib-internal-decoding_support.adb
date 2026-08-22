with Jpeglib.Errors;
with Jpeglib.Internal.Bytes;
with Jpeglib.Internal.Markers;
with Jpeglib.Internal.Segments;

package body Jpeglib.Internal.Decoding_Support is
   function Parse_Known_Height_DNL
     (Input : not null access Streams.Source'Class;
      Marker_Source : Source_Offset;
      Frame : Frames.Frame) return Results.Result
   is
      Segment : Segments.Segment_Reader := Segments.Open (Input, Markers.DNL, Marker_Source);
      Outcome : constant Results.Result := Segments.Status (Segment);
      High : Bytes.Read_Byte_Result;
      Low : Bytes.Read_Byte_Result;
      Lines : Natural;
   begin
      if not Results.Succeeded (Outcome) then
         return Outcome;
      elsif Segments.Descriptor (Segment).Payload_Length /= 2 then
         return
           Results.Failure
             (Errors.Make
                (Errors.Segment_Invalid_Length,
                 (Source => Segments.Descriptor (Segment).Length_Source,
                  Marker => Markers.DNL,
                  Detail => Long_Long_Integer (Segments.Descriptor (Segment).Declared_Length),
                  others => <>)));
      end if;

      High := Segments.Read_Byte (Segment);
      if not Results.Succeeded (High.Outcome) then
         return High.Outcome;
      end if;

      Low := Segments.Read_Byte (Segment);
      if not Results.Succeeded (Low.Outcome) then
         return Low.Outcome;
      end if;

      Lines := Natural (High.Value) * 256 + Natural (Low.Value);
      if Lines /= Natural (Frames.Height (Frame)) then
         return
           Results.Failure
             (Errors.Make
                (Errors.Frame_Invalid_Definition,
                 (Source => High.Source,
                  Marker => Markers.DNL,
                  Detail => Long_Long_Integer (Lines),
                  others => <>)));
      end if;

      return Results.Success;
   end Parse_Known_Height_DNL;

   function Infer_Color_Model (Frame : Frames.Frame) return Encoded_Color_Model is
      C1 : Frames.Frame_Component;
      C2 : Frames.Frame_Component;
      C3 : Frames.Frame_Component;
      C4 : Frames.Frame_Component;
   begin
      case Frames.Components (Frame) is
         when 1 =>
            return Grayscale;
         when 2 =>
            return Unknown;
         when 3 =>
            C1 := Frames.Component (Frame, 1);
            C2 := Frames.Component (Frame, 2);
            C3 := Frames.Component (Frame, 3);
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
            C1 := Frames.Component (Frame, 1);
            C2 := Frames.Component (Frame, 2);
            C3 := Frames.Component (Frame, 3);
            C4 := Frames.Component (Frame, 4);
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

   function Infer_Color_Model (Header_Result : Decoder.Header_Result) return Encoded_Color_Model is
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

   function Lossless_Coefficient_Blocks (Frame : Frames.Frame) return Block_Count is
      Result : Byte_Count := 0;
      Component : Frames.Frame_Component;
   begin
      for Index in Component_Index range 1 .. Component_Index (Frames.Components (Frame)) loop
         Component := Frames.Component (Frame, Index);
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
end Jpeglib.Internal.Decoding_Support;

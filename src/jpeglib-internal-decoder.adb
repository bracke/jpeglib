with Jpeglib.Errors;
with Jpeglib.Internal.Bit_Streams;
with Jpeglib.Internal.Bytes;
with Jpeglib.Internal.Markers;
with Jpeglib.Internal.Progressive;
with Jpeglib.Internal.Restarts;
with Jpeglib.Internal.Segments;

package body Jpeglib.Internal.Decoder is
   use type Bit_Streams.Entropy_Byte_Kind;
   use type Metadata.Callback_Access;
   use type Metadata.Exif_Orientation;
   use type Metadata.Metadata_Kind;
   use type Metadata.Metadata_Policy;
   use type Streams.Byte_Array_Access;

   Max_Metadata_Prefix : constant := 35;
   ICC_APP2_Header_Length : constant Byte_Count := 14;
   Exif_Header_Length : constant Natural := 6;
   Adobe_APP14_Header_Length : constant Natural := 12;
   subtype Metadata_Prefix_Index is Positive range 1 .. Max_Metadata_Prefix;
   type Metadata_Prefix is array (Metadata_Prefix_Index) of Byte;

   function Unexpected
     (Marker : Marker_Code;
      Source : Source_Offset;
      Detail : Long_Long_Integer := 0) return Results.Result
   is
   begin
      return
        Results.Failure
          (Errors.Make
             (Errors.Marker_Unexpected,
              (Source => Source, Marker => Marker, Detail => Detail, others => <>)));
   end Unexpected;

   function Skip_Length_Bearing
     (Input : not null access Streams.Source'Class;
      Marker : Marker_Code;
      Marker_Source : Source_Offset) return Results.Result
   is
      Segment : Segments.Segment_Reader := Segments.Open (Input, Marker, Marker_Source);
      Outcome : Results.Result := Segments.Status (Segment);
   begin
      if Results.Succeeded (Outcome) then
         Outcome := Segments.Skip_Remaining (Segment);
      end if;
      return Outcome;
   end Skip_Length_Bearing;

   function Read_Scan_Ending
     (Entropy : in out Bit_Streams.Entropy_Reader;
      Mode : Entropy_Mode) return Bit_Streams.Entropy_Read_Result
   is
      Ending : Bit_Streams.Entropy_Read_Result;
   begin
      loop
         Ending := Bit_Streams.Read_Byte (Entropy);
         exit when not Results.Succeeded (Ending.Outcome)
           or else Mode /= Jpeglib.Arithmetic
           or else Ending.Kind /= Bit_Streams.Entropy_Data;
      end loop;

      return Ending;
   end Read_Scan_Ending;

   function Parse_DNL
     (Input : not null access Streams.Source'Class;
      Marker_Source : Source_Offset;
      Frame : in out Frames.Frame) return Results.Result
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
      if Lines = 0
        or else (Frames.Height_Defined (Frame) and then Lines /= Natural (Frames.Height (Frame)))
      then
         return
           Results.Failure
             (Errors.Make
                (Errors.Frame_Invalid_Definition,
                 (Source => High.Source,
                  Marker => Markers.DNL,
                  Detail => Long_Long_Integer (Lines),
                  others => <>)));
      end if;

      if not Frames.Height_Defined (Frame) then
         declare
            Define_Outcome : constant Results.Result := Frames.Define_Height (Frame, Image_Height (Lines));
         begin
            if not Results.Succeeded (Define_Outcome) then
               return
                 Results.Failure
                   (Errors.Make
                      (Define_Outcome.First_Error.Code,
                       (Source => High.Source,
                        Marker => Markers.DNL,
                        Detail => Long_Long_Integer (Lines),
                        others => <>)));
            end if;
         end;
      end if;

      return Results.Success;
   end Parse_DNL;

   function Prefix_Matches
     (Prefix : Metadata_Prefix;
      Prefix_Length : Natural;
      Expected : String) return Boolean
   is
   begin
      if Prefix_Length < Expected'Length then
         return False;
      end if;

      for Index in Expected'Range loop
         if Prefix (Index - Expected'First + 1) /= Byte (Character'Pos (Expected (Index))) then
            return False;
         end if;
      end loop;

      return True;
   end Prefix_Matches;

   function Metadata_Kind_For
     (Marker : Marker_Code;
      Prefix : Metadata_Prefix;
      Prefix_Length : Natural) return Metadata.Metadata_Kind is
   begin
      if Marker = Markers.COM then
         return Metadata.Comment;
      elsif Marker = Markers.APP0
        and then Prefix_Matches (Prefix, Prefix_Length, "JFIF" & Character'Val (0))
      then
         return Metadata.JFIF;
      elsif Marker = Markers.APP0
        and then Prefix_Matches (Prefix, Prefix_Length, "JFXX" & Character'Val (0))
      then
         return Metadata.JFXX;
      elsif Marker = Markers.APP1
        and then Prefix_Matches (Prefix, Prefix_Length, "Exif" & Character'Val (0) & Character'Val (0))
      then
         return Metadata.Exif;
      elsif Marker = Markers.APP1
        and then Prefix_Matches (Prefix, Prefix_Length, "http://ns.adobe.com/xap/1.0/" & Character'Val (0))
      then
         return Metadata.XMP;
      elsif Marker = Markers.APP1
        and then Prefix_Matches (Prefix, Prefix_Length, "http://ns.adobe.com/xmp/extension/" & Character'Val (0))
      then
         return Metadata.Extended_XMP;
      elsif Marker = Markers.APP14 then
         return Metadata.Adobe_APP14;
      elsif Marker = Markers.APP2
        and then Prefix_Matches (Prefix, Prefix_Length, "ICC_PROFILE" & Character'Val (0))
      then
         return Metadata.ICC;
      else
         return Metadata.Unknown_APP;
      end if;
   end Metadata_Kind_For;

   function Retain_Metadata_Summary
     (Policy : Metadata.Metadata_Policy;
      Kind : Metadata.Metadata_Kind;
      Selected_Metadata : Metadata.Kind_Set) return Boolean is
   begin
      case Policy is
         when Metadata.Discard_All =>
            return False;
         when Metadata.Preserve_All_Bounded =>
            return True;
         when Metadata.Preserve_Selected =>
            return Selected_Metadata (Kind);
         when Metadata.Parse_Known_Without_Retention
            | Metadata.Preserve_Known
            | Metadata.Stream_To_Callback =>
            return Kind /= Metadata.Unknown_APP;
      end case;
   end Retain_Metadata_Summary;

   function Retain_Metadata_Payload
     (Policy : Metadata.Metadata_Policy;
      Kind : Metadata.Metadata_Kind;
      Selected_Metadata : Metadata.Kind_Set;
      Buffer : Streams.Byte_Array_Access) return Boolean is
   begin
      if Buffer = null then
         return False;
      end if;

      case Policy is
         when Metadata.Preserve_All_Bounded =>
            return True;
         when Metadata.Preserve_Known =>
            return Kind /= Metadata.Unknown_APP;
         when Metadata.Preserve_Selected =>
            return Selected_Metadata (Kind);
         when Metadata.Discard_All | Metadata.Parse_Known_Without_Retention | Metadata.Stream_To_Callback =>
            return False;
      end case;
   end Retain_Metadata_Payload;

   function Metadata_Limit
     (Source : Source_Offset;
      Marker : Marker_Code;
      Detail : Long_Long_Integer) return Results.Result
   is
   begin
      return
        Results.Failure
          (Errors.Make
           (Errors.Metadata_Limit_Exceeded,
              (Source => Source, Marker => Marker, Detail => Detail, others => <>)));
   end Metadata_Limit;

   function Validate_ICC_Fragment
     (Result : in out Header_Result;
      Descriptor : Segments.Segment_Descriptor;
      Prefix : Metadata_Prefix;
      Prefix_Length : Natural;
      Decode_Limits : Limits.Limit_Set) return Results.Result
   is
      Sequence : Natural;
      Fragment_Count : Natural;
      Profile_Length : Byte_Count;
      New_ICC_Total : Byte_Count;
   begin
      if Prefix_Length < Natural (ICC_APP2_Header_Length) then
         return Metadata_Limit
           (Descriptor.Payload_Source, Descriptor.Marker, Long_Long_Integer (Descriptor.Payload_Length));
      end if;

      Profile_Length := Descriptor.Payload_Length - ICC_APP2_Header_Length;

      if Profile_Length > Decode_Limits.Max_ICC_Profile_Bytes then
         return Metadata_Limit
           (Descriptor.Payload_Source, Descriptor.Marker, Long_Long_Integer (Profile_Length));
      elsif Result.ICC_Profile_Bytes > Decode_Limits.Max_ICC_Profile_Bytes - Profile_Length then
         return Metadata_Limit
           (Descriptor.Payload_Source, Descriptor.Marker, Long_Long_Integer (Decode_Limits.Max_ICC_Profile_Bytes));
      end if;

      Sequence := Natural (Prefix (13));
      Fragment_Count := Natural (Prefix (14));

      if Sequence = 0
        or else Fragment_Count = 0
        or else Sequence > Fragment_Count
        or else Result.ICC_Profile_Fragment_Seen (Sequence)
        or else Sequence /= Result.ICC_Profile_Fragments + 1
      then
         return Metadata_Limit
           (Descriptor.Payload_Source, Descriptor.Marker, Long_Long_Integer (Sequence));
      elsif Result.ICC_Profile_Fragment_Count /= 0
        and then Result.ICC_Profile_Fragment_Count /= Fragment_Count
      then
         return Metadata_Limit
           (Descriptor.Payload_Source, Descriptor.Marker, Long_Long_Integer (Fragment_Count));
      end if;

      Result.ICC_Profile_Fragment_Count := Fragment_Count;
      Result.ICC_Profile_Fragment_Seen (Sequence) := True;
      Result.ICC_Profile_Fragments := Result.ICC_Profile_Fragments + 1;
      New_ICC_Total := Result.ICC_Profile_Bytes + Profile_Length;
      Result.ICC_Profile_Bytes := New_ICC_Total;

      return Results.Success;
   end Validate_ICC_Fragment;

   function Validate_ICC_Complete (Result : Header_Result) return Results.Result is
   begin
      if Result.ICC_Profile_Fragment_Count = 0
        or else Result.ICC_Profile_Fragments = Result.ICC_Profile_Fragment_Count
      then
         return Results.Success;
      end if;

      return
        Results.Failure
          (Errors.Make
             (Errors.Metadata_Limit_Exceeded,
              (Detail => Long_Long_Integer (Result.ICC_Profile_Fragment_Count), others => <>)));
   end Validate_ICC_Complete;

   function Read_U16
     (Prefix : Metadata_Prefix;
      Offset : Natural;
      Little_Endian : Boolean) return Natural is
   begin
      if Little_Endian then
         return Natural (Prefix (Offset)) + Natural (Prefix (Offset + 1)) * 256;
      end if;
      return Natural (Prefix (Offset)) * 256 + Natural (Prefix (Offset + 1));
   end Read_U16;

   function Read_U32
     (Prefix : Metadata_Prefix;
      Offset : Natural;
      Little_Endian : Boolean) return Natural is
   begin
      if Little_Endian then
         return
           Natural (Prefix (Offset))
           + Natural (Prefix (Offset + 1)) * 256
           + Natural (Prefix (Offset + 2)) * 65_536
           + Natural (Prefix (Offset + 3)) * 16_777_216;
      end if;
      return
        Natural (Prefix (Offset)) * 16_777_216
        + Natural (Prefix (Offset + 1)) * 65_536
        + Natural (Prefix (Offset + 2)) * 256
        + Natural (Prefix (Offset + 3));
   end Read_U32;

   function Orientation_For (Value : Natural) return Metadata.Exif_Orientation is
   begin
      case Value is
         when 1 => return Metadata.Orientation_Normal;
         when 2 => return Metadata.Orientation_Mirror_Horizontal;
         when 3 => return Metadata.Orientation_Rotate_180;
         when 4 => return Metadata.Orientation_Mirror_Vertical;
         when 5 => return Metadata.Orientation_Transpose;
         when 6 => return Metadata.Orientation_Rotate_90;
         when 7 => return Metadata.Orientation_Transverse;
         when 8 => return Metadata.Orientation_Rotate_270;
         when others => return Metadata.Orientation_Unknown;
      end case;
   end Orientation_For;

   procedure Parse_Exif_Orientation
     (Result : in out Header_Result;
      Prefix : Metadata_Prefix;
      Prefix_Length : Natural)
   is
      TIFF_Start : constant Natural := Exif_Header_Length + 1;
      Little_Endian : Boolean;
      IFD_Offset : Natural;
      IFD_Start : Natural;
      Entry_Count : Natural;
      Entry_Start : Natural;
      Orientation_Value : Natural;
   begin
      if Prefix_Length < Exif_Header_Length + 14 then
         return;
      end if;

      if Prefix (TIFF_Start) = 16#49# and then Prefix (TIFF_Start + 1) = 16#49# then
         Little_Endian := True;
      elsif Prefix (TIFF_Start) = 16#4D# and then Prefix (TIFF_Start + 1) = 16#4D# then
         Little_Endian := False;
      else
         return;
      end if;

      if Read_U16 (Prefix, TIFF_Start + 2, Little_Endian) /= 42 then
         return;
      end if;

      IFD_Offset := Read_U32 (Prefix, TIFF_Start + 4, Little_Endian);
      if IFD_Offset > Max_Metadata_Prefix - Exif_Header_Length - 2 then
         return;
      end if;

      IFD_Start := TIFF_Start + IFD_Offset;
      if IFD_Start < TIFF_Start or else IFD_Start + 1 > Prefix_Length then
         return;
      end if;

      Entry_Count := Read_U16 (Prefix, IFD_Start, Little_Endian);
      if Entry_Count = 0 then
         return;
      end if;

      for Entry_Index in Natural range 0 .. Entry_Count - 1 loop
         Entry_Start := IFD_Start + 2 + Entry_Index * 12;
         exit when Entry_Start + 11 > Prefix_Length;

         if Read_U16 (Prefix, Entry_Start, Little_Endian) = 16#0112#
           and then Read_U16 (Prefix, Entry_Start + 2, Little_Endian) = 3
           and then Read_U32 (Prefix, Entry_Start + 4, Little_Endian) = 1
         then
            Orientation_Value := Read_U16 (Prefix, Entry_Start + 8, Little_Endian);
            Result.Exif_Orientation := Orientation_For (Orientation_Value);
            Result.Has_Exif_Orientation := Result.Exif_Orientation /= Metadata.Orientation_Unknown;
            return;
         end if;
      end loop;
   end Parse_Exif_Orientation;

   procedure Parse_Adobe_APP14_Transform
     (Result : in out Header_Result;
      Prefix : Metadata_Prefix;
      Prefix_Length : Natural) is
   begin
      if Prefix_Length >= Adobe_APP14_Header_Length
        and then Prefix_Matches (Prefix, Prefix_Length, "Adobe")
      then
         Result.Has_Adobe_APP14_Transform := True;
         Result.Adobe_APP14_Transform := Natural (Prefix (12));
      end if;
   end Parse_Adobe_APP14_Transform;

   function Emit_Metadata_Callback
     (Result : in out Header_Result;
      Descriptor : Segments.Segment_Descriptor;
      Kind : Metadata.Metadata_Kind;
      Event : Metadata.Callback_Event;
      Chunk_Offset : Byte_Count;
      Chunk : Streams.Const_Byte_Array_Access;
      Callback : Metadata.Callback_Access;
      Decode_Limits : Limits.Limit_Set) return Results.Result is
   begin
      if Callback = null then
         return Results.Success;
      elsif Result.Metadata_Callbacks >= Decode_Limits.Max_Metadata_Callbacks then
         return Metadata_Limit
           (Descriptor.Payload_Source, Descriptor.Marker, Long_Long_Integer (Result.Metadata_Callbacks + 1));
      end if;

      Result.Metadata_Callbacks := Result.Metadata_Callbacks + 1;
      Callback.all
        (Event,
         (Marker => Descriptor.Marker,
          Kind => Kind,
          Source => Descriptor.Marker_Source,
          Declared_Payload_Length => Descriptor.Payload_Length,
          Chunk_Offset => Chunk_Offset,
          Chunk => Chunk));

      return Results.Success;
   end Emit_Metadata_Callback;

   function Stream_Metadata_Callbacks
     (Result : in out Header_Result;
      Segment : in out Segments.Segment_Reader;
      Descriptor : Segments.Segment_Descriptor;
      Kind : Metadata.Metadata_Kind;
      Prefix : Metadata_Prefix;
      Prefix_Length : Natural;
      Callback : Metadata.Callback_Access;
      Decode_Limits : Limits.Limit_Set) return Results.Result
   is
      Outcome : Results.Result;
      Byte_Result : Bytes.Read_Byte_Result;
      Chunk : aliased Streams.Byte_Array := [1 => 0];
      Offset : Byte_Count := 0;
   begin
      Outcome :=
        Emit_Metadata_Callback
          (Result, Descriptor, Kind, Metadata.Segment_Begin, 0, null, Callback, Decode_Limits);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      for Index in 1 .. Prefix_Length loop
         Chunk (1) := Prefix (Index);
         Outcome :=
         Emit_Metadata_Callback
             (Result, Descriptor, Kind, Metadata.Segment_Data, Offset, Chunk'Unchecked_Access, Callback, Decode_Limits);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Offset := Offset + 1;
      end loop;

      while Segments.Remaining (Segment) > 0 loop
         Byte_Result := Segments.Read_Byte (Segment);
         if not Results.Succeeded (Byte_Result.Outcome) then
            return Byte_Result.Outcome;
         end if;

         Chunk (1) := Byte_Result.Value;
         Outcome :=
         Emit_Metadata_Callback
             (Result, Descriptor, Kind, Metadata.Segment_Data, Offset, Chunk'Unchecked_Access, Callback, Decode_Limits);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Offset := Offset + 1;
      end loop;

      return
        Emit_Metadata_Callback
          (Result, Descriptor, Kind, Metadata.Segment_End, Offset, null, Callback, Decode_Limits);
   end Stream_Metadata_Callbacks;

   function Record_Metadata_Segment
     (Result : in out Header_Result;
      Segment : in out Segments.Segment_Reader;
      Metadata_Policy : Metadata.Metadata_Policy;
      Selected_Metadata : Metadata.Kind_Set;
      Metadata_Callback : Metadata.Callback_Access;
      Metadata_Buffer : Streams.Byte_Array_Access;
      Decode_Limits : Limits.Limit_Set) return Results.Result
   is
      Descriptor : constant Segments.Segment_Descriptor := Segments.Descriptor (Segment);
      Prefix : Metadata_Prefix := [others => 0];
      Prefix_Length : Natural := 0;
      New_Total : Byte_Count;
      Byte_Result : Bytes.Read_Byte_Result;
      Kind : Metadata.Metadata_Kind;
      ICC_Outcome : Results.Result;
      Callback_Outcome : Results.Result;
      Skip_Outcome : Results.Result;
      Retained_Offset : Byte_Count := 0;
      Retained_Length : Byte_Count := 0;
      Retained_Length_To_Write : Byte_Count := 0;
   begin
      if Result.Metadata_Segments >= Decode_Limits.Max_Metadata_Segments then
         return Metadata_Limit
           (Descriptor.Marker_Source, Descriptor.Marker, Long_Long_Integer (Result.Metadata_Segments + 1));
      elsif Descriptor.Payload_Length > Decode_Limits.Max_Metadata_Segment_Bytes then
         return Metadata_Limit
           (Descriptor.Payload_Source, Descriptor.Marker, Long_Long_Integer (Descriptor.Payload_Length));
      elsif Descriptor.Payload_Length > Decode_Limits.Max_Metadata_Bytes then
         return Metadata_Limit
           (Descriptor.Payload_Source, Descriptor.Marker, Long_Long_Integer (Descriptor.Payload_Length));
      elsif Result.Metadata_Bytes > Decode_Limits.Max_Metadata_Bytes - Descriptor.Payload_Length then
         return Metadata_Limit
           (Descriptor.Payload_Source, Descriptor.Marker, Long_Long_Integer (Decode_Limits.Max_Metadata_Bytes));
      end if;

      Result.Metadata_Segments := Result.Metadata_Segments + 1;
      New_Total := Result.Metadata_Bytes + Descriptor.Payload_Length;
      Result.Metadata_Bytes := New_Total;

      while Prefix_Length < Max_Metadata_Prefix and then Segments.Remaining (Segment) > 0 loop
         Byte_Result := Segments.Read_Byte (Segment);
         if not Results.Succeeded (Byte_Result.Outcome) then
            return Byte_Result.Outcome;
         end if;
         Prefix_Length := Prefix_Length + 1;
         Prefix (Prefix_Length) := Byte_Result.Value;
      end loop;

      Kind := Metadata_Kind_For (Descriptor.Marker, Prefix, Prefix_Length);

      if Kind = Metadata.ICC then
         ICC_Outcome := Validate_ICC_Fragment (Result, Descriptor, Prefix, Prefix_Length, Decode_Limits);
         if not Results.Succeeded (ICC_Outcome) then
            return ICC_Outcome;
         end if;
      elsif Kind = Metadata.Exif then
         Parse_Exif_Orientation (Result, Prefix, Prefix_Length);
      elsif Kind = Metadata.Adobe_APP14 then
         Parse_Adobe_APP14_Transform (Result, Prefix, Prefix_Length);
      end if;

      if Retain_Metadata_Payload (Metadata_Policy, Kind, Selected_Metadata, Metadata_Buffer) then
         Retained_Length_To_Write :=
           (if Kind = Metadata.ICC then Descriptor.Payload_Length - ICC_APP2_Header_Length
            else Descriptor.Payload_Length);

         if Result.Retained_Metadata_Bytes > Byte_Count (Metadata_Buffer'Length)
           or else Retained_Length_To_Write > Byte_Count (Metadata_Buffer'Length) - Result.Retained_Metadata_Bytes
         then
            return Metadata_Limit
              (Descriptor.Payload_Source, Descriptor.Marker, Long_Long_Integer (Retained_Length_To_Write));
         end if;

         Retained_Offset := Result.Retained_Metadata_Bytes;
         if Kind = Metadata.ICC then
            for Index in Natural (ICC_APP2_Header_Length) + 1 .. Prefix_Length loop
               Metadata_Buffer (Metadata_Buffer'First + Natural (Result.Retained_Metadata_Bytes)) := Prefix (Index);
               Result.Retained_Metadata_Bytes := Result.Retained_Metadata_Bytes + 1;
            end loop;
         else
            for Index in 1 .. Prefix_Length loop
               Metadata_Buffer (Metadata_Buffer'First + Natural (Result.Retained_Metadata_Bytes)) := Prefix (Index);
               Result.Retained_Metadata_Bytes := Result.Retained_Metadata_Bytes + 1;
            end loop;
         end if;

         while Segments.Remaining (Segment) > 0 loop
            Byte_Result := Segments.Read_Byte (Segment);
            if not Results.Succeeded (Byte_Result.Outcome) then
               return Byte_Result.Outcome;
            end if;

            Metadata_Buffer (Metadata_Buffer'First + Natural (Result.Retained_Metadata_Bytes)) := Byte_Result.Value;
            Result.Retained_Metadata_Bytes := Result.Retained_Metadata_Bytes + 1;
         end loop;

         Retained_Length := Retained_Length_To_Write;
      end if;

      if Retain_Metadata_Summary (Metadata_Policy, Kind, Selected_Metadata)
        and then Result.Retained_Metadata_Summaries < Metadata.Max_Header_Summaries
      then
         Result.Retained_Metadata_Summaries := Result.Retained_Metadata_Summaries + 1;
         Result.Metadata_Summaries (Metadata.Segment_Summary_Index (Result.Retained_Metadata_Summaries)) :=
           (Marker => Descriptor.Marker,
            Kind => Kind,
            Source => Descriptor.Marker_Source,
            Payload_Length => Descriptor.Payload_Length,
            Payload_Offset => Retained_Offset,
            Retained_Length => Retained_Length);
      end if;

      if Retained_Length > 0 then
         return Results.Success;
      end if;

      if Metadata_Policy = Metadata.Stream_To_Callback then
         Callback_Outcome :=
           Stream_Metadata_Callbacks
             (Result,
              Segment,
              Descriptor,
              Kind,
              Prefix,
              Prefix_Length,
              Metadata_Callback,
              Decode_Limits);
         if not Results.Succeeded (Callback_Outcome) then
            return Callback_Outcome;
         end if;

         return Results.Success;
      end if;

      Skip_Outcome := Segments.Skip_Remaining (Segment);
      return Skip_Outcome;
   end Record_Metadata_Segment;

   function Read_Header
     (Input : not null access Streams.Source'Class;
      Metadata_Policy : Metadata.Metadata_Policy := Metadata.Parse_Known_Without_Retention;
      Selected_Metadata : Metadata.Kind_Set := [others => False];
      Metadata_Callback : Metadata.Callback_Access := null;
      Metadata_Buffer : Streams.Byte_Array_Access := null;
      Decode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Header_Result
   is
      Result : Header_Result;
      Marker : Markers.Marker_Result;
      Segment_Outcome : Results.Result;
      Have_Frame : Boolean := False;
      DRI : Restarts.DRI_Result;
   begin
      Marker := Markers.Read_Next (Input.all);
      if not Results.Succeeded (Marker.Outcome) then
         Result.Outcome := Marker.Outcome;
         return Result;
      elsif Marker.Marker /= Markers.SOI then
         Result.Outcome := Unexpected (Marker.Marker, Marker.Source);
         return Result;
      end if;

      loop
         Marker := Markers.Read_Next (Input.all);
         if not Results.Succeeded (Marker.Outcome) then
            Result.Outcome := Marker.Outcome;
            return Result;
         end if;

         if Marker.Marker = Markers.EOI then
            Result.Outcome := Unexpected (Marker.Marker, Marker.Source);
            return Result;
         elsif Markers.Is_Restart (Marker.Marker)
           or else Marker.Marker = Markers.SOI
         then
            Result.Outcome := Unexpected (Marker.Marker, Marker.Source);
            return Result;
         elsif Marker.Marker = Markers.TEM then
            null;
         elsif Marker.Marker = Markers.DQT then
            declare
               Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
            begin
               Result.Outcome := Segments.Status (Segment);
               if Results.Succeeded (Result.Outcome) then
                  Result.Outcome := Quantization.Parse_DQT (Result.Quantization_State, Segment);
               end if;
            end;
         elsif Marker.Marker = Markers.DHT then
            declare
               Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
            begin
               Result.Outcome := Segments.Status (Segment);
               if Results.Succeeded (Result.Outcome) then
                  Result.Outcome := Huffman.Parse_DHT (Result.Huffman_State, Segment);
               end if;
            end;
         elsif Marker.Marker = Markers.DAC then
            declare
               Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
            begin
               Result.Outcome := Segments.Status (Segment);
               if Results.Succeeded (Result.Outcome) then
                  Result.Outcome := Arithmetic.Parse_DAC (Result.Arithmetic_State, Segment);
               end if;
            end;
         elsif Marker.Marker = Markers.DRI then
            declare
               Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
            begin
               Result.Outcome := Segments.Status (Segment);
               if Results.Succeeded (Result.Outcome) then
                  DRI := Restarts.Read_DRI (Segment);
                  Result.Outcome := DRI.Outcome;
                  Result.Restart := DRI.Interval;
               end if;
            end;
         elsif Marker.Marker = Markers.DHP then
            Result.Hierarchical := True;
            Result.Outcome := Skip_Length_Bearing (Input, Marker.Marker, Marker.Source);
         elsif Marker.Marker = Markers.DNL
           or else Markers.Is_Reserved (Marker.Marker)
         then
            Result.Outcome :=
              Results.Failure
                (Errors.Make
                   (Errors.Unsupported_Feature,
                    (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            return Result;
         elsif Marker.Marker in Markers.SOF0 | Markers.SOF1 | Markers.SOF2 | Markers.SOF3 |
                                Markers.SOF5 | Markers.SOF6 | Markers.SOF7 |
                                Markers.SOF9 | Markers.SOF10 | Markers.SOF11 |
                                Markers.SOF13 | Markers.SOF14 | Markers.SOF15
         then
            if Have_Frame then
               Result.Outcome := Unexpected (Marker.Marker, Marker.Source);
               return Result;
            end if;

            declare
               Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
               Mode : constant Frame_Mode :=
                 (case Marker.Marker is
                    when Markers.SOF0 =>
                       Baseline_DCT,
                    when Markers.SOF1 | Markers.SOF9 =>
                       Extended_Sequential_DCT,
                    when Markers.SOF2 | Markers.SOF10 =>
                       Progressive_DCT,
                    when Markers.SOF3 | Markers.SOF11 =>
                       Lossless,
                    when Markers.SOF5 | Markers.SOF13 =>
                       Differential_Sequential_DCT,
                    when Markers.SOF6 | Markers.SOF14 =>
                       Differential_Progressive_DCT,
                    when Markers.SOF7 | Markers.SOF15 =>
                       Differential_Lossless,
                    when others =>
                       Unsupported_Frame);
            begin
               Result.Outcome := Segments.Status (Segment);
               if Results.Succeeded (Result.Outcome) then
                  Result.Frame := Frames.Parse_SOF (Segment, Mode);
                  Result.Outcome := Frames.Status (Result.Frame);
                  if Results.Succeeded (Result.Outcome)
                    and then Frames.Components (Result.Frame) > Decode_Limits.Max_Components
                  then
                     Result.Outcome :=
                       Results.Failure
                         (Errors.Make
                            (Errors.Output_Limit_Exceeded,
                             (Source => Marker.Source,
                              Marker => Marker.Marker,
                              Detail => Long_Long_Integer (Frames.Components (Result.Frame)),
                              others => <>)));
                  end if;
                  Have_Frame := Results.Succeeded (Result.Outcome);
                  if Have_Frame then
                     Result.Entropy :=
                       (if Marker.Marker in Markers.SOF9 | Markers.SOF10 | Markers.SOF11 |
                                           Markers.SOF13 | Markers.SOF14 | Markers.SOF15
                        then Entropy_Mode'Val (1)
                        else Entropy_Mode'Val (0));
                  end if;
               end if;
            end;
         elsif Markers.Is_Frame (Marker.Marker) then
            Result.Outcome :=
              Results.Failure
                (Errors.Make
                   (Errors.Unsupported_Feature,
                    (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            return Result;
         elsif Marker.Marker = Markers.SOS then
            if not Have_Frame then
               Result.Outcome := Unexpected (Marker.Marker, Marker.Source);
               return Result;
            end if;

            declare
               Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
            begin
               Result.Outcome := Segments.Status (Segment);
               if Results.Succeeded (Result.Outcome) then
                  Result.Scan :=
                    Scans.Parse_SOS
                      (Result.Frame,
                       Segment,
                       Progressive => Frames.Mode (Result.Frame) in Progressive_DCT | Differential_Progressive_DCT,
                       Lossless => Frames.Mode (Result.Frame) in Lossless | Differential_Lossless);
                  Result.Outcome := Scans.Status (Result.Scan);
               end if;
            end;

            if Results.Succeeded (Result.Outcome) then
               Result.Outcome := Validate_ICC_Complete (Result);
            end if;

            if Results.Succeeded (Result.Outcome) then
               Result.Saw_SOS := True;
            end if;
            return Result;
         elsif Markers.Is_APP (Marker.Marker) or else Marker.Marker = Markers.COM then
            declare
               Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
            begin
               Result.Outcome := Segments.Status (Segment);
               if Results.Succeeded (Result.Outcome) then
                  Result.Outcome :=
                    Record_Metadata_Segment
                      (Result,
                       Segment,
                       Metadata_Policy,
                       Selected_Metadata,
                       Metadata_Callback,
                       Metadata_Buffer,
                       Decode_Limits);
               end if;
            end;
         elsif Marker.Marker = Markers.DNL
           or else Markers.Is_Reserved (Marker.Marker)
         then
            Result.Outcome :=
              Results.Failure
                (Errors.Make
                   (Errors.Unsupported_Feature,
                    (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            return Result;
         elsif Markers.Has_Length (Marker.Marker) then
            Segment_Outcome := Skip_Length_Bearing (Input, Marker.Marker, Marker.Source);
            if not Results.Succeeded (Segment_Outcome) then
               Result.Outcome := Segment_Outcome;
               return Result;
            end if;
         else
            Result.Outcome := Unexpected (Marker.Marker, Marker.Source);
            return Result;
         end if;

         if not Results.Succeeded (Result.Outcome) then
            return Result;
         end if;
      end loop;
   end Read_Header;

   function Decode_Baseline_Coefficients
     (Input : not null access Streams.Source'Class;
      Blocks : in out Coefficients.Block_Array;
      Metadata_Policy : Metadata.Metadata_Policy := Metadata.Parse_Known_Without_Retention;
      Selected_Metadata : Metadata.Kind_Set := [others => False];
      Metadata_Callback : Metadata.Callback_Access := null;
      Metadata_Buffer : Streams.Byte_Array_Access := null;
      Decode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Coefficient_Result
   is
      Header : Header_Result;
   begin
      Header :=
        Read_Header
          (Input, Metadata_Policy, Selected_Metadata, Metadata_Callback, Metadata_Buffer, Decode_Limits);
      return Decode_Baseline_Coefficients (Header, Input, Blocks);
   end Decode_Baseline_Coefficients;

   function Decode_Baseline_Coefficients
     (Header : Header_Result;
      Input : not null access Streams.Source'Class;
      Blocks : in out Coefficients.Block_Array) return Coefficient_Result
   is
      Result : Coefficient_Result;
      Current_Header : Header_Result := Header;
      Entropy : aliased Bit_Streams.Entropy_Reader (Input);
      Scan : Coefficients.Scan_Result;
      Ending : Bit_Streams.Entropy_Read_Result;
      Pending : Markers.Marker_Result;
      Required_Blocks : Block_Count;
      Next_Block : Natural := Blocks'First;
      Predictors : Coefficients.Predictor_Array := [others => 0];
      Component_Seen : array (Component_Index) of Boolean := [others => False];

      procedure Mark_Scan_Components is
         Scan_Component : Scans.Scan_Component;
      begin
         for Index in Component_Index range 1 .. Component_Index (Scans.Components (Current_Header.Scan)) loop
            Scan_Component := Scans.Component (Current_Header.Scan, Index);
            Component_Seen (Scan_Component.Frame_Component) := True;
         end loop;
      end Mark_Scan_Components;

      function All_Frame_Components_Seen return Boolean is
      begin
         for Index in Component_Index range 1 .. Component_Index (Frames.Components (Current_Header.Frame)) loop
            if not Component_Seen (Index) then
               return False;
            end if;
         end loop;

         return True;
      end All_Frame_Components_Seen;

      function Incomplete_Scan_Data return Results.Result is
      begin
         for Index in Component_Index range 1 .. Component_Index (Frames.Components (Current_Header.Frame)) loop
            if not Component_Seen (Index) then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Scan_Invalid_Definition,
                       (Frame_Component => Index, Detail => Long_Long_Integer (Index), others => <>)));
            end if;
         end loop;

         return Results.Success;
      end Incomplete_Scan_Data;

      function Reject_Repeated_Scan_Components return Results.Result is
         Scan_Component : Scans.Scan_Component;
      begin
         for Index in Component_Index range 1 .. Component_Index (Scans.Components (Current_Header.Scan)) loop
            Scan_Component := Scans.Component (Current_Header.Scan, Index);
            if Component_Seen (Scan_Component.Frame_Component) then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Scan_Invalid_Definition,
                       (Frame_Component => Scan_Component.Frame_Component,
                        Detail => Long_Long_Integer (Scan_Component.Frame_Component),
                        others => <>)));
            end if;
         end loop;

         return Results.Success;
      end Reject_Repeated_Scan_Components;

      function Read_Following_Scan (First_Marker : Markers.Marker_Result) return Results.Result is
         Marker : Markers.Marker_Result := First_Marker;
         DRI : Restarts.DRI_Result;
      begin
         loop
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Marker.Marker = Markers.EOI then
               Current_Header.Saw_SOS := False;
               return Results.Success;
            elsif Markers.Is_Frame (Marker.Marker)
              and then Current_Header.Hierarchical
              and then All_Frame_Components_Seen
            then
               Current_Header.Saw_SOS := False;
               return Results.Success;
            elsif Markers.Is_Restart (Marker.Marker)
              or else Marker.Marker = Markers.SOI
              or else Markers.Is_Frame (Marker.Marker)
            then
               return Unexpected (Marker.Marker, Marker.Source);
            elsif Marker.Marker = Markers.TEM then
               null;
            elsif Marker.Marker = Markers.DQT then
               declare
                  Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                     Outcome := Quantization.Parse_DQT (Current_Header.Quantization_State, Segment);
                  end if;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            elsif Marker.Marker = Markers.DHT then
               declare
                  Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                     Outcome := Huffman.Parse_DHT (Current_Header.Huffman_State, Segment);
                  end if;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            elsif Marker.Marker = Markers.DAC then
               declare
                  Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                     Outcome := Arithmetic.Parse_DAC (Current_Header.Arithmetic_State, Segment);
                  end if;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            elsif Marker.Marker = Markers.DRI then
               declare
                  Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                     DRI := Restarts.Read_DRI (Segment);
                     Outcome := DRI.Outcome;
                     Current_Header.Restart := DRI.Interval;
                  end if;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            elsif Marker.Marker = Markers.SOS then
               declare
                  Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                     Current_Header.Scan :=
                       Scans.Parse_SOS
                         (Current_Header.Frame,
                          Segment,
                          Progressive => False);
                     Outcome := Scans.Status (Current_Header.Scan);
                  end if;
                  Current_Header.Saw_SOS := Results.Succeeded (Outcome);
                  return Outcome;
               end;
            elsif Marker.Marker = Markers.DNL then
               declare
                  Outcome : constant Results.Result := Parse_DNL (Input, Marker.Source, Current_Header.Frame);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            elsif Markers.Is_Reserved (Marker.Marker)
            then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Unsupported_Feature,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            elsif Markers.Has_Length (Marker.Marker) then
               declare
                  Outcome : constant Results.Result :=
                    Skip_Length_Bearing (Input, Marker.Marker, Marker.Source);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            else
               return Unexpected (Marker.Marker, Marker.Source);
            end if;

            Marker := Markers.Read_Next (Input.all);
         end loop;
      end Read_Following_Scan;
   begin
      Result.Header := Current_Header;
      if not Results.Succeeded (Current_Header.Outcome) then
         Result.Outcome := Current_Header.Outcome;
         return Result;
      elsif not Current_Header.Saw_SOS then
         Result.Outcome := Results.Failure (Errors.Invalid_State);
         return Result;
      elsif Frames.Mode (Current_Header.Frame)
        not in Baseline_DCT | Extended_Sequential_DCT | Differential_Sequential_DCT
      then
         Result.Outcome := Results.Failure (Errors.Unsupported_Feature);
         return Result;
      elsif Current_Header.Entropy = Entropy_Mode'Val (1) then
         Result.Outcome := Results.Failure (Errors.Unsupported_Feature);
         return Result;
      end if;

      Required_Blocks := Frames.Total_Blocks (Current_Header.Frame);
      if Block_Count (Blocks'Length) < Required_Blocks then
         Result.Outcome :=
           Results.Failure
             (Errors.Make
                (Errors.Output_Limit_Exceeded,
                 (Detail => Long_Long_Integer (Required_Blocks), others => <>)));
         return Result;
      end if;

      loop
         Result.Outcome := Reject_Repeated_Scan_Components;
         if not Results.Succeeded (Result.Outcome) then
            return Result;
         end if;

         Predictors := [others => 0];
         Scan :=
           Coefficients.Decode_Baseline_Scan
             (Current_Header.Frame,
              Current_Header.Scan,
              Current_Header.Huffman_State,
              Entropy'Access,
              Blocks,
              Next_Block,
              Predictors,
              Current_Header.Restart);
         if not Results.Succeeded (Scan.Outcome) then
            Result.Outcome := Scan.Outcome;
            return Result;
         end if;
         Mark_Scan_Components;

         Ending := Read_Scan_Ending (Entropy, Current_Header.Entropy);
         if not Results.Succeeded (Ending.Outcome) then
            Result.Outcome := Ending.Outcome;
            return Result;
         elsif Ending.Kind /= Bit_Streams.Scan_Ending_Marker then
            Result.Outcome :=
              Results.Failure
                (Errors.Make
                   (Errors.Marker_Unexpected,
                    (Source => Ending.Source, Marker => Ending.Marker, others => <>)));
            return Result;
         end if;

         Pending := Bit_Streams.Take_Pending_Marker (Entropy);
         if Pending.Marker = Markers.EOI then
            if not All_Frame_Components_Seen then
               Result.Outcome := Incomplete_Scan_Data;
               return Result;
            end if;
            exit;
         end if;

         Result.Outcome := Read_Following_Scan (Pending);
         if not Results.Succeeded (Result.Outcome) then
            return Result;
         elsif not Current_Header.Saw_SOS then
            if not All_Frame_Components_Seen then
               Result.Outcome := Incomplete_Scan_Data;
               return Result;
            end if;
            exit;
         end if;
      end loop;

      Result.Header := Current_Header;
      Result.Blocks_Decoded := Block_Count (Next_Block - Blocks'First);
      Result.Ending_Marker := Pending.Marker;
      Result.Ending_Source := Pending.Source;
      return Result;
   end Decode_Baseline_Coefficients;

   function Decode_Arithmetic_Coefficients
     (Header : Header_Result;
      Input : not null access Streams.Source'Class;
      Blocks : in out Coefficients.Block_Array) return Coefficient_Result
   is
      Result : Coefficient_Result;
      Current_Header : Header_Result := Header;
      Entropy : aliased Bit_Streams.Entropy_Reader (Input);
      Scan : Coefficients.Scan_Result;
      Ending : Bit_Streams.Entropy_Read_Result;
      Pending : Markers.Marker_Result;
      Required_Blocks : Block_Count;
      Next_Block : Natural := Blocks'First;
      Predictors : Coefficients.Predictor_Array := [others => 0];
      DC_Bins : Arithmetic.Probability_Bin_Array (0 .. 63) :=
        [others => Arithmetic.Initial_Probability_Bin];
      AC_Bins : Arithmetic.Probability_Bin_Array (0 .. 255) :=
        [others => Arithmetic.Initial_Probability_Bin];
      Fixed_Bin : Arithmetic.Probability_Bin := Arithmetic.Initial_Probability_Bin;
      DC_Contexts : Arithmetic.DC_Context_Array := [others => 0];

      Component_Seen : array (Component_Index) of Boolean := [others => False];

      procedure Mark_Scan_Components is
         Scan_Component : Scans.Scan_Component;
      begin
         for Index in Component_Index range 1 .. Component_Index (Scans.Components (Current_Header.Scan)) loop
            Scan_Component := Scans.Component (Current_Header.Scan, Index);
            Component_Seen (Scan_Component.Frame_Component) := True;
         end loop;
      end Mark_Scan_Components;

      function All_Frame_Components_Seen return Boolean is
      begin
         for Index in Component_Index range 1 .. Component_Index (Frames.Components (Current_Header.Frame)) loop
            if not Component_Seen (Index) then
               return False;
            end if;
         end loop;

         return True;
      end All_Frame_Components_Seen;

      function Incomplete_Scan_Data return Results.Result is
      begin
         for Index in Component_Index range 1 .. Component_Index (Frames.Components (Current_Header.Frame)) loop
            if not Component_Seen (Index) then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Scan_Invalid_Definition,
                       (Frame_Component => Index, Detail => Long_Long_Integer (Index), others => <>)));
            end if;
         end loop;

         return Results.Success;
      end Incomplete_Scan_Data;

      function Reject_Repeated_Scan_Components return Results.Result is
         Scan_Component : Scans.Scan_Component;
      begin
         for Index in Component_Index range 1 .. Component_Index (Scans.Components (Current_Header.Scan)) loop
            Scan_Component := Scans.Component (Current_Header.Scan, Index);
            if Component_Seen (Scan_Component.Frame_Component) then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Scan_Invalid_Definition,
                       (Frame_Component => Scan_Component.Frame_Component,
                        Detail => Long_Long_Integer (Scan_Component.Frame_Component),
                        others => <>)));
            end if;
         end loop;

         return Results.Success;
      end Reject_Repeated_Scan_Components;

      function Read_Following_Scan (First_Marker : Markers.Marker_Result) return Results.Result is
         Marker : Markers.Marker_Result := First_Marker;
         DRI : Restarts.DRI_Result;
      begin
         loop
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Marker.Marker = Markers.EOI then
               Current_Header.Saw_SOS := False;
               return Results.Success;
            elsif Markers.Is_Frame (Marker.Marker)
              and then Current_Header.Hierarchical
              and then All_Frame_Components_Seen
            then
               Current_Header.Saw_SOS := False;
               return Results.Success;
            elsif Markers.Is_Restart (Marker.Marker)
              or else Marker.Marker = Markers.SOI
              or else Markers.Is_Frame (Marker.Marker)
            then
               return Unexpected (Marker.Marker, Marker.Source);
            elsif Marker.Marker = Markers.TEM then
               null;
            elsif Marker.Marker = Markers.DAC then
               declare
                  Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                     Outcome := Arithmetic.Parse_DAC (Current_Header.Arithmetic_State, Segment);
                  end if;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            elsif Marker.Marker = Markers.DRI then
               declare
                  Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                     DRI := Restarts.Read_DRI (Segment);
                     Outcome := DRI.Outcome;
                     Current_Header.Restart := DRI.Interval;
                  end if;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            elsif Marker.Marker = Markers.SOS then
               declare
                  Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                     Current_Header.Scan :=
                       Scans.Parse_SOS
                         (Current_Header.Frame,
                          Segment,
                          Progressive => False);
                     Outcome := Scans.Status (Current_Header.Scan);
                  end if;
                  Current_Header.Saw_SOS := Results.Succeeded (Outcome);
                  return Outcome;
               end;
            elsif Marker.Marker = Markers.DNL then
               declare
                  Outcome : constant Results.Result := Parse_DNL (Input, Marker.Source, Current_Header.Frame);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            elsif Markers.Is_Reserved (Marker.Marker)
            then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Unsupported_Feature,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            elsif Markers.Has_Length (Marker.Marker) then
               declare
                  Outcome : constant Results.Result :=
                    Skip_Length_Bearing (Input, Marker.Marker, Marker.Source);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            else
               return Unexpected (Marker.Marker, Marker.Source);
            end if;

            Marker := Markers.Read_Next (Input.all);
         end loop;
      end Read_Following_Scan;
   begin
      Result.Header := Current_Header;
      if not Results.Succeeded (Current_Header.Outcome) then
         Result.Outcome := Current_Header.Outcome;
         return Result;
      elsif not Current_Header.Saw_SOS then
         Result.Outcome := Results.Failure (Errors.Invalid_State);
         return Result;
      elsif Frames.Mode (Current_Header.Frame)
        not in Baseline_DCT | Extended_Sequential_DCT | Differential_Sequential_DCT
        or else Current_Header.Entropy /= Entropy_Mode'Val (1)
      then
         Result.Outcome := Results.Failure (Errors.Unsupported_Feature);
         return Result;
      end if;

      Required_Blocks := Frames.Total_Blocks (Current_Header.Frame);
      if Block_Count (Blocks'Length) < Required_Blocks then
         Result.Outcome :=
           Results.Failure
             (Errors.Make
                (Errors.Output_Limit_Exceeded,
                 (Detail => Long_Long_Integer (Required_Blocks), others => <>)));
         return Result;
      end if;

      loop
         Result.Outcome := Reject_Repeated_Scan_Components;
         if not Results.Succeeded (Result.Outcome) then
            return Result;
         end if;

         Predictors := [others => 0];
         DC_Bins := [others => Arithmetic.Initial_Probability_Bin];
         AC_Bins := [others => Arithmetic.Initial_Probability_Bin];
         Fixed_Bin := Arithmetic.Initial_Probability_Bin;
         DC_Contexts := [others => 0];
         Scan :=
           Coefficients.Decode_Arithmetic_Sequential_Scan
             (Current_Header.Frame,
              Current_Header.Scan,
              Current_Header.Arithmetic_State,
              Entropy'Access,
              Blocks,
              Next_Block,
              Predictors,
              DC_Bins,
              AC_Bins,
              Fixed_Bin,
              DC_Contexts,
              Current_Header.Restart);
         if not Results.Succeeded (Scan.Outcome) then
            Result.Outcome := Scan.Outcome;
            return Result;
         end if;
         Mark_Scan_Components;

         Ending := Read_Scan_Ending (Entropy, Current_Header.Entropy);
         if not Results.Succeeded (Ending.Outcome) then
            Result.Outcome := Ending.Outcome;
            return Result;
         elsif Ending.Kind /= Bit_Streams.Scan_Ending_Marker then
            Result.Outcome :=
              Results.Failure
                (Errors.Make
                   (Errors.Marker_Unexpected,
                    (Source => Ending.Source, Marker => Ending.Marker, others => <>)));
            return Result;
         end if;

         Pending := Bit_Streams.Take_Pending_Marker (Entropy);
         if Pending.Marker = Markers.EOI then
            if not All_Frame_Components_Seen then
               Result.Outcome := Incomplete_Scan_Data;
               return Result;
            end if;
            exit;
         end if;

         Result.Outcome := Read_Following_Scan (Pending);
         if not Results.Succeeded (Result.Outcome) then
            return Result;
         elsif not Current_Header.Saw_SOS then
            if not All_Frame_Components_Seen then
               Result.Outcome := Incomplete_Scan_Data;
               return Result;
            end if;
            exit;
         end if;
      end loop;

      Current_Header.Saw_SOS := False;
      Result.Header := Current_Header;
      Result.Blocks_Decoded := Block_Count (Next_Block - Blocks'First);
      Result.Ending_Marker := Pending.Marker;
      Result.Ending_Source := Pending.Source;
      return Result;
   end Decode_Arithmetic_Coefficients;

   function Decode_Progressive_Coefficients
     (Input : not null access Streams.Source'Class;
      Blocks : in out Coefficients.Block_Array;
      Metadata_Policy : Metadata.Metadata_Policy := Metadata.Parse_Known_Without_Retention;
      Selected_Metadata : Metadata.Kind_Set := [others => False];
      Metadata_Callback : Metadata.Callback_Access := null;
      Metadata_Buffer : Streams.Byte_Array_Access := null;
      Decode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Coefficient_Result
   is
      Header : Header_Result;
   begin
      Header :=
        Read_Header
          (Input, Metadata_Policy, Selected_Metadata, Metadata_Callback, Metadata_Buffer, Decode_Limits);
      return Decode_Progressive_Coefficients (Header, Input, Blocks);
   end Decode_Progressive_Coefficients;

   function Decode_Progressive_Coefficients
     (Header : Header_Result;
      Input : not null access Streams.Source'Class;
      Blocks : in out Coefficients.Block_Array) return Coefficient_Result
   is
      Result : Coefficient_Result;
      Current_Header : Header_Result := Header;
      Entropy : aliased Bit_Streams.Entropy_Reader (Input);
      Scan : Coefficients.Scan_Result;
      Ending : Bit_Streams.Entropy_Read_Result;
      Pending : Markers.Marker_Result;
      Required_Blocks : Block_Count;
      State : Progressive.Scan_State;
      Predictors : Coefficients.Predictor_Array := [others => 0];
      DC_Bins : Arithmetic.Probability_Bin_Array (0 .. 63) :=
        [others => Arithmetic.Initial_Probability_Bin];
      AC_Bins : Arithmetic.Probability_Bin_Array (0 .. 245) :=
        [others => Arithmetic.Initial_Probability_Bin];
      DC_Contexts : Arithmetic.DC_Context_Array := [others => 0];
      Decoded_Coefficients : Arithmetic.Decoded_Coefficient_Map (Blocks'Range, Coefficient_Index) :=
        [others => [others => False]];

      function Read_Following_Scan (First_Marker : Markers.Marker_Result) return Results.Result is
         Marker : Markers.Marker_Result := First_Marker;
         DRI : Restarts.DRI_Result;
      begin
         loop
            if not Results.Succeeded (Marker.Outcome) then
               return Marker.Outcome;
            elsif Marker.Marker = Markers.EOI then
               Current_Header.Saw_SOS := False;
               return Results.Success;
            elsif Markers.Is_Restart (Marker.Marker)
              or else Marker.Marker = Markers.SOI
              or else Markers.Is_Frame (Marker.Marker)
            then
               return Unexpected (Marker.Marker, Marker.Source);
            elsif Marker.Marker = Markers.TEM then
               null;
            elsif Marker.Marker = Markers.DQT then
               declare
                  Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                     Outcome := Quantization.Parse_DQT (Current_Header.Quantization_State, Segment);
                  end if;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            elsif Marker.Marker = Markers.DHT then
               declare
                  Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                     Outcome := Huffman.Parse_DHT (Current_Header.Huffman_State, Segment);
                  end if;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            elsif Marker.Marker = Markers.DAC then
               declare
                  Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                     Outcome := Arithmetic.Parse_DAC (Current_Header.Arithmetic_State, Segment);
                  end if;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            elsif Marker.Marker = Markers.DRI then
               declare
                  Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                     DRI := Restarts.Read_DRI (Segment);
                     Outcome := DRI.Outcome;
                     Current_Header.Restart := DRI.Interval;
                  end if;
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            elsif Marker.Marker = Markers.SOS then
               declare
                  Segment : Segments.Segment_Reader := Segments.Open (Input, Marker.Marker, Marker.Source);
                  Outcome : Results.Result := Segments.Status (Segment);
               begin
                  if Results.Succeeded (Outcome) then
                     Current_Header.Scan :=
                       Scans.Parse_SOS
                         (Current_Header.Frame,
                          Segment,
                          Progressive => True);
                     Outcome := Scans.Status (Current_Header.Scan);
                  end if;
                  Current_Header.Saw_SOS := Results.Succeeded (Outcome);
                  return Outcome;
               end;
            elsif Marker.Marker = Markers.DNL then
               declare
                  Outcome : constant Results.Result := Parse_DNL (Input, Marker.Source, Current_Header.Frame);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            elsif Markers.Is_Reserved (Marker.Marker)
            then
               return
                 Results.Failure
                   (Errors.Make
                      (Errors.Unsupported_Feature,
                       (Source => Marker.Source, Marker => Marker.Marker, others => <>)));
            elsif Markers.Has_Length (Marker.Marker) then
               declare
                  Outcome : constant Results.Result :=
                    Skip_Length_Bearing (Input, Marker.Marker, Marker.Source);
               begin
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;
            else
               return Unexpected (Marker.Marker, Marker.Source);
            end if;

            Marker := Markers.Read_Next (Input.all);
         end loop;
      end Read_Following_Scan;
   begin
      Result.Header := Current_Header;
      Progressive.Reset (State);

      if not Results.Succeeded (Current_Header.Outcome) then
         Result.Outcome := Current_Header.Outcome;
         return Result;
      elsif not Current_Header.Saw_SOS then
         Result.Outcome := Results.Failure (Errors.Invalid_State);
         return Result;
      elsif Frames.Mode (Current_Header.Frame) not in Progressive_DCT | Differential_Progressive_DCT then
         Result.Outcome := Results.Failure (Errors.Unsupported_Feature);
         return Result;
      end if;

      Required_Blocks := Frames.Total_Blocks (Current_Header.Frame);
      if Block_Count (Blocks'Length) < Required_Blocks then
         Result.Outcome :=
           Results.Failure
             (Errors.Make
                (Errors.Output_Limit_Exceeded,
                 (Detail => Long_Long_Integer (Required_Blocks), others => <>)));
         return Result;
      end if;

      loop
         if Current_Header.Entropy = Entropy_Mode'Val (1) then
            declare
               Candidate_State : Progressive.Scan_State := State;
               Outcome : constant Results.Result :=
                 Progressive.Accept_Scan (Candidate_State, Current_Header.Frame, Current_Header.Scan);
            begin
               if not Results.Succeeded (Outcome) then
                  Result.Outcome := Outcome;
                  return Result;
               end if;

               if Scans.Spectral_Start (Current_Header.Scan) = 0
                 and then Scans.Successive_High (Current_Header.Scan) = 0
                 and then Scans.Components (Current_Header.Scan) = 1
               then
                  DC_Bins := [others => Arithmetic.Initial_Probability_Bin];
                  DC_Contexts := [others => 0];
               end if;
               Scan :=
                 Coefficients.Decode_Arithmetic_Progressive_Scan
                   (Current_Header.Frame,
                    Current_Header.Scan,
                    Current_Header.Arithmetic_State,
                    Entropy'Access,
                    Blocks,
                    Decoded_Coefficients,
                    Predictors,
                    DC_Bins,
                    AC_Bins,
                    DC_Contexts,
                    Current_Header.Restart);
               if Results.Succeeded (Scan.Outcome) then
                  State := Candidate_State;
               end if;
            end;
         else
            Scan :=
              Coefficients.Decode_Progressive_Scan
                (Current_Header.Frame,
                 Current_Header.Scan,
                 Current_Header.Huffman_State,
                 Entropy'Access,
                 Blocks,
                 State,
                 Current_Header.Restart);
         end if;
         if not Results.Succeeded (Scan.Outcome) then
            Result.Outcome := Scan.Outcome;
            return Result;
         end if;
         Result.Blocks_Decoded := Result.Blocks_Decoded + Scan.Blocks_Decoded;

         Ending := Read_Scan_Ending (Entropy, Current_Header.Entropy);
         if not Results.Succeeded (Ending.Outcome) then
            Result.Outcome := Ending.Outcome;
            return Result;
         elsif Ending.Kind /= Bit_Streams.Scan_Ending_Marker then
            Result.Outcome :=
              Results.Failure
                (Errors.Make
                   (Errors.Marker_Unexpected,
                    (Source => Ending.Source, Marker => Ending.Marker, others => <>)));
            return Result;
         end if;

         Pending := Bit_Streams.Take_Pending_Marker (Entropy);
         exit when Pending.Marker = Markers.EOI
           or else (Current_Header.Hierarchical and then Markers.Is_Frame (Pending.Marker));

         Result.Outcome := Read_Following_Scan (Pending);
         if not Results.Succeeded (Result.Outcome) then
            return Result;
         elsif not Current_Header.Saw_SOS then
            exit;
         end if;
      end loop;

      Result.Header := Current_Header;
      Result.Ending_Marker := Pending.Marker;
      Result.Ending_Source := Pending.Source;
      return Result;
   end Decode_Progressive_Coefficients;
end Jpeglib.Internal.Decoder;

with Jpeglib.Errors;

package body Jpeglib.Internal.Segments is
   function Decode_Payload_Length (Declared_Length : Byte_Count) return Payload_Length_Result is
   begin
      if Declared_Length < 2 then
         return (Valid => False, Payload_Length => 0);
      end if;

      return (Valid => True, Payload_Length => Declared_Length - 2);
   end Decode_Payload_Length;

   function Skip_Count_Is_Bounded (Remaining, Count : Byte_Count) return Boolean is
   begin
      return Count > 0 and then Count <= Remaining;
   end Skip_Count_Is_Bounded;

   function Remaining_After_Skip (Remaining, Count : Byte_Count) return Byte_Count is
   begin
      return Remaining - Count;
   end Remaining_After_Skip;

   function Open
     (Input : not null access Streams.Source'Class;
      Marker : Marker_Code;
      Marker_Source : Source_Offset) return Segment_Reader
   is
      Length : constant Bytes.Read_U16_Result := Bytes.Read_Big_Endian_U16 (Input.all);
      Item : Segment_Descriptor :=
        (Marker => Marker,
         Marker_Source => Marker_Source,
         Length_Source => Length.Source,
         Declared_Length => Byte_Count (Length.Value),
         Payload_Length => 0,
         Payload_Source => Streams.Offset (Input.all));
   begin
      if not Results.Succeeded (Length.Outcome) then
         return
           (Input => Input,
            Item => Item,
            Bytes_Remaining => 0,
            Outcome => Length.Outcome);
      elsif not Decode_Payload_Length (Byte_Count (Length.Value)).Valid then
         return
           (Input => Input,
            Item => Item,
            Bytes_Remaining => 0,
            Outcome =>
              Results.Failure
                (Errors.Make
                   (Errors.Segment_Invalid_Length,
                    (Source => Length.Source,
                     Marker => Marker,
                     Detail => Long_Long_Integer (Length.Value),
                     others => <>))));
      else
         Item.Payload_Length := Decode_Payload_Length (Byte_Count (Length.Value)).Payload_Length;
         return
           (Input => Input,
            Item => Item,
            Bytes_Remaining => Item.Payload_Length,
            Outcome => Results.Success);
      end if;
   end Open;

   function Descriptor (Object : Segment_Reader) return Segment_Descriptor is
   begin
      return Object.Item;
   end Descriptor;

   function Remaining (Object : Segment_Reader) return Byte_Count is
   begin
      return Object.Bytes_Remaining;
   end Remaining;

   function Status (Object : Segment_Reader) return Results.Result is
   begin
      return Object.Outcome;
   end Status;

   function Read_Byte (Object : in out Segment_Reader) return Bytes.Read_Byte_Result is
      Read_Result : Bytes.Read_Byte_Result;
   begin
      if not Results.Succeeded (Object.Outcome) then
         return
           (Outcome => Object.Outcome,
            Source => Streams.Offset (Object.Input.all),
            Value => 0,
            End_Of_Input => False);
      elsif Object.Bytes_Remaining = 0 then
         Object.Outcome :=
           Results.Failure
             (Errors.Make
                (Errors.Segment_Boundary_Exceeded,
                 (Source => Streams.Offset (Object.Input.all), Marker => Object.Item.Marker, others => <>)));
         return
           (Outcome => Object.Outcome,
            Source => Streams.Offset (Object.Input.all),
            Value => 0,
            End_Of_Input => False);
      end if;

      Read_Result := Bytes.Read_Byte (Object.Input.all);
      if Results.Succeeded (Read_Result.Outcome) then
         Object.Bytes_Remaining := Object.Bytes_Remaining - 1;
      else
         Object.Outcome := Read_Result.Outcome;
      end if;
      return Read_Result;
   end Read_Byte;

   function Skip_Remaining (Object : in out Segment_Reader) return Results.Result is
      Skip_Result : Streams.Source_Result;
   begin
      while Object.Bytes_Remaining > 0 loop
         Skip_Result := Streams.Skip (Object.Input.all, Object.Bytes_Remaining);
         if Errors.Is_Fatal (Skip_Result.Result) then
            Object.Outcome := Results.Failure (Skip_Result.Result);
            return Object.Outcome;
         elsif Skip_Result.Count = 0 then
            Object.Outcome :=
              Results.Failure
                (Errors.Make
                   (Errors.Source_Zero_Progress,
                    (Source => Streams.Offset (Object.Input.all), Marker => Object.Item.Marker, others => <>)));
            return Object.Outcome;
         elsif Skip_Result.Count > Object.Bytes_Remaining then
            Object.Outcome :=
              Results.Failure
                (Errors.Make
                   (Errors.Segment_Boundary_Exceeded,
                   (Source => Streams.Offset (Object.Input.all), Marker => Object.Item.Marker, others => <>)));
            return Object.Outcome;
         elsif Skip_Count_Is_Bounded (Object.Bytes_Remaining, Skip_Result.Count) then
            Object.Bytes_Remaining :=
              Remaining_After_Skip (Object.Bytes_Remaining, Skip_Result.Count);
         else
            Object.Outcome :=
              Results.Failure
                (Errors.Make
                   (Errors.Segment_Boundary_Exceeded,
                    (Source => Streams.Offset (Object.Input.all), Marker => Object.Item.Marker, others => <>)));
            return Object.Outcome;
         end if;
      end loop;

      return Object.Outcome;
   end Skip_Remaining;
end Jpeglib.Internal.Segments;

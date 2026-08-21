with Jpeglib.Errors;

package body Jpeglib.Internal.Bytes is
   function Read_Byte (Input : in out Streams.Source'Class) return Read_Byte_Result is
      Buffer : Streams.Byte_Array (1 .. 1);
      Start : constant Source_Offset := Streams.Offset (Input);
      Read_Result : constant Streams.Source_Result := Streams.Read (Input, Buffer);
   begin
      if Errors.Is_Fatal (Read_Result.Result) then
         return
           (Outcome => Results.Failure (Read_Result.Result),
            Source => Start,
            Value => 0,
            End_Of_Input => Read_Result.End_Of_Input);
      elsif Read_Result.Count = 1 then
         return (Outcome => Results.Success, Source => Start, Value => Buffer (1), End_Of_Input => False);
      elsif Read_Result.End_Of_Input then
         return
           (Outcome => Results.Failure (Errors.Make (Errors.Source_Unexpected_EOI, (Source => Start, others => <>))),
            Source => Start,
            Value => 0,
            End_Of_Input => True);
      else
         return
           (Outcome => Results.Failure (Errors.Make (Errors.Source_Zero_Progress, (Source => Start, others => <>))),
            Source => Start,
            Value => 0,
            End_Of_Input => False);
      end if;
   end Read_Byte;

   function Read_Big_Endian_U16 (Input : in out Streams.Source'Class) return Read_U16_Result is
      High : constant Read_Byte_Result := Read_Byte (Input);
      Low : Read_Byte_Result;
   begin
      if not Results.Succeeded (High.Outcome) then
         return (Outcome => High.Outcome, Source => High.Source, Value => 0, End_Of_Input => High.End_Of_Input);
      end if;

      Low := Read_Byte (Input);
      if not Results.Succeeded (Low.Outcome) then
         return (Outcome => Low.Outcome, Source => High.Source, Value => 0, End_Of_Input => Low.End_Of_Input);
      end if;

      return
        (Outcome => Results.Success,
         Source => High.Source,
         Value => Natural (High.Value) * 256 + Natural (Low.Value),
         End_Of_Input => False);
   end Read_Big_Endian_U16;
end Jpeglib.Internal.Bytes;

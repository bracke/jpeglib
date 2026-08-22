with Jpeglib.Errors;
with Jpeglib.Internal.Bytes;

package body Jpeglib.Internal.Restarts is
   function Invalid
     (Marker : Marker_Code;
      Source : Source_Offset;
      Detail : Long_Long_Integer := 0) return Results.Result
   is
      pragma SPARK_Mode (Off);
   begin
      return
        Results.Failure
          (Errors.Make
             (Errors.Restart_Invalid_State,
              (Source => Source, Marker => Marker, Detail => Detail, others => <>)));
   end Invalid;

   function Read_DRI (Segment : in out Segments.Segment_Reader) return DRI_Result is
      pragma SPARK_Mode (Off);
      High : constant Bytes.Read_Byte_Result := Segments.Read_Byte (Segment);
      Low : Bytes.Read_Byte_Result;
   begin
      if not Results.Succeeded (High.Outcome) then
         return (Outcome => High.Outcome, Interval => 0);
      end if;

      Low := Segments.Read_Byte (Segment);
      if not Results.Succeeded (Low.Outcome) then
         return (Outcome => Low.Outcome, Interval => 0);
      elsif Segments.Remaining (Segment) /= 0 then
         return
           (Outcome => Invalid (Segments.Descriptor (Segment).Marker, Segments.Descriptor (Segment).Payload_Source),
            Interval => 0);
      end if;

      return
        (Outcome => Results.Success,
         Interval => Restart_Interval (Natural (High.Value) * 256 + Natural (Low.Value)));
   end Read_DRI;

   function Parse_DRI (Segment : in out Segments.Segment_Reader) return Results.Result is
      pragma SPARK_Mode (Off);
      Result : constant DRI_Result := Read_DRI (Segment);
   begin
      return Result.Outcome;
   end Parse_DRI;

   function Interval_From_DRI (Segment : in out Segments.Segment_Reader) return Restart_Interval is
      pragma SPARK_Mode (Off);
      Result : constant DRI_Result := Read_DRI (Segment);
   begin
      return Result.Interval;
   end Interval_From_DRI;

   procedure Configure (State : out Restart_State; Interval : Restart_Interval) is
      pragma SPARK_Mode (On);
   begin
      State.Restart_Every := Interval;
      State.Remaining := Interval;
      State.Expected := Markers.RST0;
   end Configure;

   function Advance_MCU (State : in out Restart_State) return Results.Result is
      pragma SPARK_Mode (Off);
   begin
      if State.Restart_Every = 0 then
         return Results.Success;
      elsif State.Remaining = 0 then
         return Invalid (State.Expected, 0);
      else
         State.Remaining := State.Remaining - 1;
         return Results.Success;
      end if;
   end Advance_MCU;

   function Accept_Restart
     (State : in out Restart_State;
      Marker : Marker_Code;
      Source : Source_Offset := 0) return Results.Result
   is
      pragma SPARK_Mode (Off);
   begin
      if State.Restart_Every = 0 then
         return Invalid (Marker, Source);
      elsif Marker /= State.Expected then
         return Invalid (Marker, Source, Long_Long_Integer (Markers.Restart_Number (State.Expected)));
      end if;

      State.Remaining := State.Restart_Every;
      if State.Expected = Markers.RST7 then
         State.Expected := Markers.RST0;
      else
         State.Expected := Marker_Code'Succ (State.Expected);
      end if;

      return Results.Success;
   end Accept_Restart;
end Jpeglib.Internal.Restarts;

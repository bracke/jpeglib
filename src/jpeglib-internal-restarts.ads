with Jpeglib.Internal.Markers;
with Jpeglib.Internal.Segments;
with Jpeglib.Results;

package Jpeglib.Internal.Restarts is
   pragma Preelaborate;

   type Restart_State is private;

   type DRI_Result is record
      Outcome : Results.Result := Results.Success;
      Interval : Restart_Interval := 0;
   end record;

   function Read_DRI (Segment : in out Segments.Segment_Reader) return DRI_Result
     with SPARK_Mode => Off;
   function Parse_DRI (Segment : in out Segments.Segment_Reader) return Results.Result
     with SPARK_Mode => Off;
   function Interval_From_DRI (Segment : in out Segments.Segment_Reader) return Restart_Interval
     with SPARK_Mode => Off;

   procedure Configure (State : out Restart_State; Interval : Restart_Interval)
     with SPARK_Mode => On,
          Post =>
            Jpeglib.Internal.Restarts.Interval (State) = Interval
            and then MCUs_Until_Restart (State) = Interval
            and then Expected_Marker (State) = Markers.RST0;
   function Interval (State : Restart_State) return Restart_Interval
     with SPARK_Mode => On;
   function MCUs_Until_Restart (State : Restart_State) return Restart_Interval
     with SPARK_Mode => On;
   function Expected_Marker (State : Restart_State) return Marker_Code
     with SPARK_Mode => On,
          Post => Expected_Marker'Result in Markers.RST0 .. Markers.RST7;

   function Advance_MCU (State : in out Restart_State) return Results.Result
     with SPARK_Mode => Off;
   function Accept_Restart
     (State : in out Restart_State;
      Marker : Marker_Code;
      Source : Source_Offset := 0) return Results.Result
     with SPARK_Mode => Off;

private
   type Restart_State is record
      Restart_Every : Restart_Interval := 0;
      Remaining : Restart_Interval := 0;
      Expected : Marker_Code := Markers.RST0;
   end record
     with Type_Invariant => Restart_State.Expected in Markers.RST0 .. Markers.RST7;

   function Interval (State : Restart_State) return Restart_Interval is (State.Restart_Every)
     with SPARK_Mode => On;
   function MCUs_Until_Restart (State : Restart_State) return Restart_Interval is (State.Remaining)
     with SPARK_Mode => On;
   function Expected_Marker (State : Restart_State) return Marker_Code is (State.Expected)
     with SPARK_Mode => On;
end Jpeglib.Internal.Restarts;

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

   function Read_DRI (Segment : in out Segments.Segment_Reader) return DRI_Result;
   function Parse_DRI (Segment : in out Segments.Segment_Reader) return Results.Result;
   function Interval_From_DRI (Segment : in out Segments.Segment_Reader) return Restart_Interval;

   procedure Configure (State : in out Restart_State; Interval : Restart_Interval);
   function Interval (State : Restart_State) return Restart_Interval;
   function MCUs_Until_Restart (State : Restart_State) return Restart_Interval;
   function Expected_Marker (State : Restart_State) return Marker_Code;

   function Advance_MCU (State : in out Restart_State) return Results.Result;
   function Accept_Restart
     (State : in out Restart_State;
      Marker : Marker_Code;
      Source : Source_Offset := 0) return Results.Result;

private
   type Restart_State is record
      Restart_Every : Restart_Interval := 0;
      Remaining : Restart_Interval := 0;
      Expected : Marker_Code := Markers.RST0;
   end record;
end Jpeglib.Internal.Restarts;

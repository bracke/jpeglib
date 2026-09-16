with Jpeglib.Internal.Frames;
with Jpeglib.Internal.Scans;
with Jpeglib.Results;

package Jpeglib.Internal.Progressive is
   pragma Preelaborate;

   type Scan_State is private;

   --  Reset.
   --  @param State See package contract for this parameter.
   procedure Reset (State : out Scan_State);

   --  Accept scan.
   --  @param State See package contract for this parameter.
   --  @param Frame See package contract for this parameter.
   --  @param Scan See package contract for this parameter.
   --  @return Operation result.
   function Accept_Scan
     (State : in out Scan_State;
      Frame : Frames.Frame;
      Scan : Scans.Scan) return Results.Result;

   --  Coefficient seen.
   --  @param State See package contract for this parameter.
   --  @param Component See package contract for this parameter.
   --  @param Coefficient See package contract for this parameter.
   --  @return Operation result.
   function Coefficient_Seen
     (State : Scan_State;
      Component : Component_Index;
      Coefficient : Coefficient_Index) return Boolean;

private
   type Coefficient_Flag_Array is array (Component_Index, Coefficient_Index) of Boolean;
   type Approximation_Array is array (Component_Index, Coefficient_Index) of Successive_Approximation_Value;

   type Scan_State is record
      Seen : Coefficient_Flag_Array := [others => [others => False]];
      Last_Low : Approximation_Array := [others => [others => 0]];
   end record;
end Jpeglib.Internal.Progressive;

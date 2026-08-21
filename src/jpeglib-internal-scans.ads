with Jpeglib.Internal.Frames;
with Jpeglib.Internal.Segments;
with Jpeglib.Results;

package Jpeglib.Internal.Scans is
   pragma Preelaborate;

   type Scan_Component is record
      Frame_Component : Component_Index := Component_Index'First;
      DC_Table : Huffman_Table_Index := 0;
      AC_Table : Huffman_Table_Index := 0;
   end record;

   type Scan_Component_Array is array (Component_Index) of Scan_Component;

   type Scan is private;

   function Parse_SOS
     (Frame : Frames.Frame;
      Segment : in out Segments.Segment_Reader;
      Progressive : Boolean := False;
      Lossless : Boolean := False) return Scan;

   function Status (Item : Scan) return Results.Result;
   function Components (Item : Scan) return Component_Count;
   function Component (Item : Scan; Index : Component_Index) return Scan_Component
     with Pre => Index <= Component_Index (Components (Item));
   function Spectral_Start (Item : Scan) return Spectral_Selection_Index;
   function Spectral_End (Item : Scan) return Spectral_Selection_Index;
   function Successive_High (Item : Scan) return Successive_Approximation_Value;
   function Successive_Low (Item : Scan) return Successive_Approximation_Value;

private
   type Scan is record
      Outcome : Results.Result := Results.Success;
      Component_Total : Component_Count := 1;
      Component_Items : Scan_Component_Array := [others => (others => <>)];
      Ss : Spectral_Selection_Index := 0;
      Se : Spectral_Selection_Index := 63;
      Ah : Successive_Approximation_Value := 0;
      Al : Successive_Approximation_Value := 0;
   end record;
end Jpeglib.Internal.Scans;

with Jpeglib.Internal.Segments;
with Jpeglib.Results;

package Jpeglib.Internal.Quantization is
   pragma Preelaborate;

   type Quantization_Value is range 1 .. 65_535;
   type Quantization_Table is array (Coefficient_Index) of Quantization_Value;

   function Luma_Table_For_Quality (Quality : Positive) return Quantization_Table
     with Pre => Quality <= 100;
   function Chroma_Table_For_Quality (Quality : Positive) return Quantization_Table
     with Pre => Quality <= 100;

   type Quantization_State is private;

   function Has_Table (State : Quantization_State; Index : Quantization_Table_Index) return Boolean;
   function Table (State : Quantization_State; Index : Quantization_Table_Index) return Quantization_Table
     with Pre => Has_Table (State, Index);

   function Parse_DQT
     (State : in out Quantization_State;
      Segment : in out Segments.Segment_Reader) return Results.Result;

private
   type Table_Presence is array (Quantization_Table_Index) of Boolean;
   type Table_Store is array (Quantization_Table_Index) of Quantization_Table;

   type Quantization_State is record
      Present : Table_Presence := [others => False];
      Tables : Table_Store := [others => [others => 1]];
   end record;
end Jpeglib.Internal.Quantization;

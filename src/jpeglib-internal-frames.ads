with Jpeglib.Internal.Segments;
with Jpeglib.Results;

package Jpeglib.Internal.Frames is
   pragma Preelaborate;

   type Sampling_Factor is range 1 .. 4;

   type Frame_Component is record
      Identifier : Component_Identifier := 0;
      Horizontal_Sampling : Sampling_Factor := 1;
      Vertical_Sampling : Sampling_Factor := 1;
      Quantization_Table : Quantization_Table_Index := 0;
      Component_Width : Image_Width := Image_Width'First;
      Component_Height : Image_Height := Image_Height'First;
      Block_Columns : Block_Column := 0;
      Block_Rows : Block_Row := 0;
   end record;

   type Component_Array is array (Component_Index) of Frame_Component;

   type Frame is private;

   function Parse_SOF
     (Segment : in out Segments.Segment_Reader;
      Mode : Frame_Mode) return Frame;

   function Status (Item : Frame) return Results.Result;
   function Width (Item : Frame) return Image_Width;
   function Height (Item : Frame) return Image_Height;
   function Height_Defined (Item : Frame) return Boolean;
   function Define_Height (Item : in out Frame; Height : Image_Height) return Results.Result;
   function Precision (Item : Frame) return Sample_Precision;
   function Mode (Item : Frame) return Frame_Mode;
   function Components (Item : Frame) return Component_Count;
   function Component (Item : Frame; Index : Component_Index) return Frame_Component
     with Pre => Index <= Component_Index (Components (Item));
   function Maximum_Horizontal_Sampling (Item : Frame) return Sampling_Factor;
   function Maximum_Vertical_Sampling (Item : Frame) return Sampling_Factor;
   function MCU_Columns (Item : Frame) return MCU_Column;
   function MCU_Rows (Item : Frame) return MCU_Row;
   function Padded_Block_Columns
     (Item : Frame;
      Component : Component_Index) return Block_Column
     with Pre => Component <= Component_Index (Components (Item));
   function Padded_Block_Rows
     (Item : Frame;
      Component : Component_Index) return Block_Row
     with Pre => Component <= Component_Index (Components (Item));
   function Total_Blocks (Item : Frame) return Block_Count;

private
   type Frame is record
      Outcome : Results.Result := Results.Success;
      Frame_Mode_Value : Frame_Mode := Unsupported_Frame;
      Image_Precision : Sample_Precision := 8;
      Image_W : Image_Width := Image_Width'First;
      Image_H : Image_Height := Image_Height'First;
      Image_H_Defined : Boolean := True;
      Component_Total : Component_Count := 1;
      Max_H : Sampling_Factor := 1;
      Max_V : Sampling_Factor := 1;
      MCU_C : MCU_Column := 0;
      MCU_R : MCU_Row := 0;
      Component_Items : Component_Array := [others => (others => <>)];
   end record;
end Jpeglib.Internal.Frames;

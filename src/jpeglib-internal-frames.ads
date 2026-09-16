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

   --  Parse sof.
   --  @param Segment See package contract for this parameter.
   --  @param Mode See package contract for this parameter.
   --  @return Operation result.
   function Parse_SOF
     (Segment : in out Segments.Segment_Reader;
      Mode : Frame_Mode) return Frame;

   --  Status.
   --  @param Item See package contract for this parameter.
   --  @return Operation result.
   function Status (Item : Frame) return Results.Result;
   --  Width.
   --  @param Item See package contract for this parameter.
   --  @return Operation result.
   function Width (Item : Frame) return Image_Width;
   --  Height.
   --  @param Item See package contract for this parameter.
   --  @return Operation result.
   function Height (Item : Frame) return Image_Height;
   --  Height defined.
   --  @param Item See package contract for this parameter.
   --  @return Operation result.
   function Height_Defined (Item : Frame) return Boolean;
   --  Define height.
   --  @param Item See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @return Operation result.
   function Define_Height (Item : in out Frame; Height : Image_Height) return Results.Result;
   --  Precision.
   --  @param Item See package contract for this parameter.
   --  @return Operation result.
   function Precision (Item : Frame) return Sample_Precision;
   --  Mode.
   --  @param Item See package contract for this parameter.
   --  @return Operation result.
   function Mode (Item : Frame) return Frame_Mode;
   --  Components.
   --  @param Item See package contract for this parameter.
   --  @return Operation result.
   function Components (Item : Frame) return Component_Count;
   --  Component.
   --  @param Item See package contract for this parameter.
   --  @param Index See package contract for this parameter.
   --  @return Operation result.
   function Component (Item : Frame; Index : Component_Index) return Frame_Component
     with Pre => Index <= Component_Index (Components (Item));
   --  Maximum horizontal sampling.
   --  @param Item See package contract for this parameter.
   --  @return Operation result.
   function Maximum_Horizontal_Sampling (Item : Frame) return Sampling_Factor;
   --  Maximum vertical sampling.
   --  @param Item See package contract for this parameter.
   --  @return Operation result.
   function Maximum_Vertical_Sampling (Item : Frame) return Sampling_Factor;
   --  Mcu columns.
   --  @param Item See package contract for this parameter.
   --  @return Operation result.
   function MCU_Columns (Item : Frame) return MCU_Column;
   --  Mcu rows.
   --  @param Item See package contract for this parameter.
   --  @return Operation result.
   function MCU_Rows (Item : Frame) return MCU_Row;
   --  Padded block columns.
   --  @param Item See package contract for this parameter.
   --  @param Component See package contract for this parameter.
   --  @return Operation result.
   function Padded_Block_Columns
     (Item : Frame;
      Component : Component_Index) return Block_Column
     with Pre => Component <= Component_Index (Components (Item));
   --  Padded block rows.
   --  @param Item See package contract for this parameter.
   --  @param Component See package contract for this parameter.
   --  @return Operation result.
   function Padded_Block_Rows
     (Item : Frame;
      Component : Component_Index) return Block_Row
     with Pre => Component <= Component_Index (Components (Item));
   --  Total blocks.
   --  @param Item See package contract for this parameter.
   --  @return Operation result.
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

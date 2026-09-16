with Jpeglib.Internal.Frames;

package Jpeglib.Internal.Sampling is
   pragma Preelaborate;

   type Sample_Column is range 0 .. 2 ** 31 - 1;
   type Sample_Row is range 0 .. 2 ** 31 - 1;
   type Block_Offset is range 0 .. 3;
   type Visible_Sample_Count is range 0 .. 8;

   type Block_Placement is record
      Column : Sample_Column := 0;
      Row : Sample_Row := 0;
      Visible_Width : Visible_Sample_Count := 0;
      Visible_Height : Visible_Sample_Count := 0;
   end record;

   --  Placement.
   --  @param Frame See package contract for this parameter.
   --  @param Component See package contract for this parameter.
   --  @param MCU_C See package contract for this parameter.
   --  @param MCU_R See package contract for this parameter.
   --  @param Horizontal_Block See package contract for this parameter.
   --  @param Vertical_Block See package contract for this parameter.
   --  @return Operation result.
   function Placement
     (Frame : Frames.Frame;
      Component : Component_Index;
      MCU_C : MCU_Column;
      MCU_R : MCU_Row;
      Horizontal_Block : Block_Offset;
      Vertical_Block : Block_Offset) return Block_Placement;

   --  Component column for image.
   --  @param Frame See package contract for this parameter.
   --  @param Component See package contract for this parameter.
   --  @param Column See package contract for this parameter.
   --  @return Operation result.
   function Component_Column_For_Image
     (Frame : Frames.Frame;
      Component : Component_Index;
      Column : Sample_Column) return Sample_Column;

   --  Component row for image.
   --  @param Frame See package contract for this parameter.
   --  @param Component See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @return Operation result.
   function Component_Row_For_Image
     (Frame : Frames.Frame;
      Component : Component_Index;
      Row : Sample_Row) return Sample_Row;
end Jpeglib.Internal.Sampling;

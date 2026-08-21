package body Jpeglib.Internal.Sampling is
   function Min_Visible (Origin, Size : Natural) return Visible_Sample_Count is
   begin
      if Origin >= Size then
         return 0;
      elsif Size - Origin >= 8 then
         return 8;
      else
         return Visible_Sample_Count (Size - Origin);
      end if;
   end Min_Visible;

   function Placement
     (Frame : Frames.Frame;
      Component : Component_Index;
      MCU_C : MCU_Column;
      MCU_R : MCU_Row;
      Horizontal_Block : Block_Offset;
      Vertical_Block : Block_Offset) return Block_Placement
   is
      Item : constant Frames.Frame_Component := Frames.Component (Frame, Component);
      Origin_C : constant Natural :=
        (Natural (MCU_C) * Natural (Item.Horizontal_Sampling) + Natural (Horizontal_Block)) * 8;
      Origin_R : constant Natural :=
        (Natural (MCU_R) * Natural (Item.Vertical_Sampling) + Natural (Vertical_Block)) * 8;
   begin
      return
        (Column => Sample_Column (Origin_C),
         Row => Sample_Row (Origin_R),
         Visible_Width => Min_Visible (Origin_C, Natural (Item.Component_Width)),
         Visible_Height => Min_Visible (Origin_R, Natural (Item.Component_Height)));
   end Placement;

   function Component_Column_For_Image
     (Frame : Frames.Frame;
      Component : Component_Index;
      Column : Sample_Column) return Sample_Column
   is
      Item : constant Frames.Frame_Component := Frames.Component (Frame, Component);
      Mapped : constant Natural :=
        Natural (Column) * Natural (Item.Horizontal_Sampling) / Natural (Frames.Maximum_Horizontal_Sampling (Frame));
   begin
      return Sample_Column (Natural'Min (Mapped, Natural (Item.Component_Width) - 1));
   end Component_Column_For_Image;

   function Component_Row_For_Image
     (Frame : Frames.Frame;
      Component : Component_Index;
      Row : Sample_Row) return Sample_Row
   is
      Item : constant Frames.Frame_Component := Frames.Component (Frame, Component);
      Mapped : constant Natural :=
        Natural (Row) * Natural (Item.Vertical_Sampling) / Natural (Frames.Maximum_Vertical_Sampling (Frame));
   begin
      return Sample_Row (Natural'Min (Mapped, Natural (Item.Component_Height) - 1));
   end Component_Row_For_Image;
end Jpeglib.Internal.Sampling;

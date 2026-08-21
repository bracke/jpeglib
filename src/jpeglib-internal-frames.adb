with Jpeglib.Errors;
with Jpeglib.Internal.Bytes;

package body Jpeglib.Internal.Frames is
   function Invalid
     (Segment : Segments.Segment_Reader;
      Source : Source_Offset;
      Detail : Long_Long_Integer := 0) return Results.Result
   is
   begin
      return
        Results.Failure
          (Errors.Make
             (Errors.Frame_Invalid_Definition,
              (Source => Source,
               Marker => Segments.Descriptor (Segment).Marker,
               Detail => Detail,
               others => <>)));
   end Invalid;

   function Ceiling_Divide (Dividend, Divisor : Natural) return Natural is
   begin
      return (Dividend + Divisor - 1) / Divisor;
   end Ceiling_Divide;

   procedure Derive_Height_Geometry (Item : in out Frame) is
      Component_Width_Natural : Natural;
      Component_Height_Natural : Natural;
   begin
      Item.MCU_C := MCU_Column (Ceiling_Divide (Natural (Item.Image_W), Natural (Item.Max_H) * 8));
      Item.MCU_R := MCU_Row (Ceiling_Divide (Natural (Item.Image_H), Natural (Item.Max_V) * 8));

      for Index in Component_Index range 1 .. Component_Index (Item.Component_Total) loop
         Component_Width_Natural :=
           Ceiling_Divide
             (Natural (Item.Image_W) * Natural (Item.Component_Items (Index).Horizontal_Sampling),
              Natural (Item.Max_H));
         Component_Height_Natural :=
           Ceiling_Divide
             (Natural (Item.Image_H) * Natural (Item.Component_Items (Index).Vertical_Sampling),
              Natural (Item.Max_V));
         Item.Component_Items (Index).Component_Width := Image_Width (Component_Width_Natural);
         Item.Component_Items (Index).Component_Height := Image_Height (Component_Height_Natural);
         Item.Component_Items (Index).Block_Columns := Block_Column (Ceiling_Divide (Component_Width_Natural, 8));
         Item.Component_Items (Index).Block_Rows := Block_Row (Ceiling_Divide (Component_Height_Natural, 8));
      end loop;
   end Derive_Height_Geometry;

   function Valid_Precision
     (Mode : Frame_Mode;
      Precision : Byte) return Boolean
   is
   begin
      case Mode is
         when Baseline_DCT =>
            return Precision = 8;
         when Extended_Sequential_DCT | Progressive_DCT | Lossless |
              Differential_Sequential_DCT | Differential_Progressive_DCT |
              Differential_Lossless =>
            return Precision in 8 | 12;
         when Unsupported_Frame =>
            return False;
      end case;
   end Valid_Precision;

   function Read_U16 (Segment : in out Segments.Segment_Reader) return Bytes.Read_U16_Result is
      High : constant Bytes.Read_Byte_Result := Segments.Read_Byte (Segment);
      Low : Bytes.Read_Byte_Result;
   begin
      if not Results.Succeeded (High.Outcome) then
         return (Outcome => High.Outcome, Source => High.Source, Value => 0, End_Of_Input => High.End_Of_Input);
      end if;

      Low := Segments.Read_Byte (Segment);
      if not Results.Succeeded (Low.Outcome) then
         return (Outcome => Low.Outcome, Source => High.Source, Value => 0, End_Of_Input => Low.End_Of_Input);
      end if;

      return
        (Outcome => Results.Success,
         Source => High.Source,
         Value => Natural (High.Value) * 256 + Natural (Low.Value),
         End_Of_Input => False);
   end Read_U16;

   function Parse_SOF
     (Segment : in out Segments.Segment_Reader;
      Mode : Frame_Mode) return Frame
   is
      Precision_Byte : constant Bytes.Read_Byte_Result := Segments.Read_Byte (Segment);
      Height_Value : Bytes.Read_U16_Result;
      Width_Value : Bytes.Read_U16_Result;
      Count_Byte : Bytes.Read_Byte_Result;
      Component_Id : Bytes.Read_Byte_Result;
      Sampling : Bytes.Read_Byte_Result;
      Table_Id : Bytes.Read_Byte_Result;
      Result_Frame : Frame;
      Seen : array (Byte) of Boolean := [others => False];
      H : Natural;
      V : Natural;
      TQ : Natural;
   begin
      Result_Frame.Frame_Mode_Value := Mode;

      if not Results.Succeeded (Precision_Byte.Outcome) then
         Result_Frame.Outcome := Precision_Byte.Outcome;
         return Result_Frame;
      elsif not Valid_Precision (Mode, Precision_Byte.Value) then
         Result_Frame.Outcome := Invalid (Segment, Precision_Byte.Source, Long_Long_Integer (Precision_Byte.Value));
         return Result_Frame;
      end if;

      Result_Frame.Image_Precision := Sample_Precision (Precision_Byte.Value);

      Height_Value := Read_U16 (Segment);
      if not Results.Succeeded (Height_Value.Outcome) then
         Result_Frame.Outcome := Height_Value.Outcome;
         return Result_Frame;
      end if;

      Width_Value := Read_U16 (Segment);
      if not Results.Succeeded (Width_Value.Outcome) then
         Result_Frame.Outcome := Width_Value.Outcome;
         return Result_Frame;
      elsif Width_Value.Value = 0 then
         Result_Frame.Outcome := Invalid (Segment, Width_Value.Source, 0);
         return Result_Frame;
      end if;

      Count_Byte := Segments.Read_Byte (Segment);
      if not Results.Succeeded (Count_Byte.Outcome) then
         Result_Frame.Outcome := Count_Byte.Outcome;
         return Result_Frame;
      elsif Count_Byte.Value = 0 then
         Result_Frame.Outcome := Invalid (Segment, Count_Byte.Source, Long_Long_Integer (Count_Byte.Value));
         return Result_Frame;
      end if;

      Result_Frame.Image_W := Image_Width (Width_Value.Value);
      Result_Frame.Image_H_Defined := Height_Value.Value /= 0;
      Result_Frame.Image_H :=
        (if Result_Frame.Image_H_Defined
         then Image_Height (Height_Value.Value)
         else Image_Height'First);
      Result_Frame.Component_Total := Component_Count (Natural (Count_Byte.Value));

      for Index in Component_Index range 1 .. Component_Index (Result_Frame.Component_Total) loop
         Component_Id := Segments.Read_Byte (Segment);
         Sampling := Segments.Read_Byte (Segment);
         Table_Id := Segments.Read_Byte (Segment);

         if not Results.Succeeded (Component_Id.Outcome) then
            Result_Frame.Outcome := Component_Id.Outcome;
            return Result_Frame;
         elsif not Results.Succeeded (Sampling.Outcome) then
            Result_Frame.Outcome := Sampling.Outcome;
            return Result_Frame;
         elsif not Results.Succeeded (Table_Id.Outcome) then
            Result_Frame.Outcome := Table_Id.Outcome;
            return Result_Frame;
         elsif Seen (Component_Id.Value) then
            Result_Frame.Outcome := Invalid (Segment, Component_Id.Source, Long_Long_Integer (Component_Id.Value));
            return Result_Frame;
         end if;

         H := Natural (Sampling.Value) / 16;
         V := Natural (Sampling.Value) mod 16;
         TQ := Natural (Table_Id.Value);

         if H not in 1 .. 4 or else V not in 1 .. 4 or else TQ > Natural (Quantization_Table_Index'Last) then
            Result_Frame.Outcome := Invalid (Segment, Sampling.Source, Long_Long_Integer (Sampling.Value));
            return Result_Frame;
         end if;

         Seen (Component_Id.Value) := True;
         Result_Frame.Max_H := Sampling_Factor'Max (Result_Frame.Max_H, Sampling_Factor (H));
         Result_Frame.Max_V := Sampling_Factor'Max (Result_Frame.Max_V, Sampling_Factor (V));
         Result_Frame.Component_Items (Index) :=
           (Identifier => Component_Identifier (Component_Id.Value),
            Horizontal_Sampling => Sampling_Factor (H),
            Vertical_Sampling => Sampling_Factor (V),
            Quantization_Table => Quantization_Table_Index (TQ),
            Component_Width => Image_Width'First,
            Component_Height => Image_Height'First,
            Block_Columns => 0,
            Block_Rows => 0);
      end loop;

      if Segments.Remaining (Segment) /= 0 then
         Result_Frame.Outcome :=
           Invalid
             (Segment,
              Segments.Descriptor (Segment).Payload_Source,
              Long_Long_Integer (Segments.Remaining (Segment)));
         return Result_Frame;
      end if;

      Result_Frame.MCU_C :=
        MCU_Column (Ceiling_Divide (Natural (Result_Frame.Image_W), Natural (Result_Frame.Max_H) * 8));
      if not Result_Frame.Image_H_Defined then
         Result_Frame.MCU_R := 0;
         return Result_Frame;
      end if;

      Derive_Height_Geometry (Result_Frame);

      return Result_Frame;
   exception
      when Constraint_Error =>
         Result_Frame.Outcome :=
           Invalid (Segment, Segments.Descriptor (Segment).Payload_Source);
         return Result_Frame;
   end Parse_SOF;

   function Status (Item : Frame) return Results.Result is
   begin
      return Item.Outcome;
   end Status;

   function Width (Item : Frame) return Image_Width is
   begin
      return Item.Image_W;
   end Width;

   function Height (Item : Frame) return Image_Height is
   begin
      return Item.Image_H;
   end Height;

   function Height_Defined (Item : Frame) return Boolean is
   begin
      return Item.Image_H_Defined;
   end Height_Defined;

   function Define_Height (Item : in out Frame; Height : Image_Height) return Results.Result is
   begin
      if not Results.Succeeded (Item.Outcome) then
         return Item.Outcome;
      elsif Item.Image_H_Defined then
         if Item.Image_H = Height then
            return Results.Success;
         else
            return Results.Failure (Errors.Frame_Invalid_Definition);
         end if;
      end if;

      Item.Image_H := Height;
      Item.Image_H_Defined := True;
      Derive_Height_Geometry (Item);
      return Results.Success;
   exception
      when Constraint_Error =>
         Item.Outcome := Results.Failure (Errors.Internal_Invariant_Failed);
         return Item.Outcome;
   end Define_Height;

   function Precision (Item : Frame) return Sample_Precision is
   begin
      return Item.Image_Precision;
   end Precision;

   function Mode (Item : Frame) return Frame_Mode is
   begin
      return Item.Frame_Mode_Value;
   end Mode;

   function Components (Item : Frame) return Component_Count is
   begin
      return Item.Component_Total;
   end Components;

   function Component (Item : Frame; Index : Component_Index) return Frame_Component is
   begin
      return Item.Component_Items (Index);
   end Component;

   function Maximum_Horizontal_Sampling (Item : Frame) return Sampling_Factor is
   begin
      return Item.Max_H;
   end Maximum_Horizontal_Sampling;

   function Maximum_Vertical_Sampling (Item : Frame) return Sampling_Factor is
   begin
      return Item.Max_V;
   end Maximum_Vertical_Sampling;

   function MCU_Columns (Item : Frame) return MCU_Column is
   begin
      return Item.MCU_C;
   end MCU_Columns;

   function MCU_Rows (Item : Frame) return MCU_Row is
   begin
      return Item.MCU_R;
   end MCU_Rows;

   function Padded_Block_Columns
     (Item : Frame;
      Component : Component_Index) return Block_Column
   is
   begin
      return
        Block_Column
          (Natural (Item.MCU_C) * Natural (Item.Component_Items (Component).Horizontal_Sampling));
   end Padded_Block_Columns;

   function Padded_Block_Rows
     (Item : Frame;
      Component : Component_Index) return Block_Row
   is
   begin
      return
        Block_Row
          (Natural (Item.MCU_R) * Natural (Item.Component_Items (Component).Vertical_Sampling));
   end Padded_Block_Rows;

   function Total_Blocks (Item : Frame) return Block_Count is
      Result : Block_Count := 0;
   begin
      for Index in Component_Index range 1 .. Component_Index (Item.Component_Total) loop
         Result :=
           Result
           + Block_Count (Padded_Block_Columns (Item, Index))
             * Block_Count (Padded_Block_Rows (Item, Index));
      end loop;

      return Result;
   end Total_Blocks;
end Jpeglib.Internal.Frames;

with Jpeglib.Errors;
with Jpeglib.Internal.Colors;
with Jpeglib.Internal.Transforms;

package body Jpeglib.Internal.Image_Blocks is
   use type Images.Pixel_Format;

   function Ceil_Divide_By_8 (Value : Natural) return Natural is
     ((Value + 7) / 8);

   function Required_Block_Count (Descriptor : Images.Image_Descriptor) return Block_Count is
      Block_Columns : constant Natural := Ceil_Divide_By_8 (Natural (Descriptor.Width));
      Block_Rows : constant Natural := Ceil_Divide_By_8 (Natural (Descriptor.Height));
   begin
      return Block_Count (Block_Columns) * Block_Count (Block_Rows);
   end Required_Block_Count;

   function Required_Plane_Block_Count
     (Width : Image_Width;
      Height : Image_Height) return Block_Count
   is
      Block_Columns : constant Natural := Ceil_Divide_By_8 (Natural (Width));
      Block_Rows : constant Natural := Ceil_Divide_By_8 (Natural (Height));
   begin
      return Block_Count (Block_Columns) * Block_Count (Block_Rows);
   end Required_Plane_Block_Count;

   function Chroma_Width
     (Width : Image_Width;
      Layout : Subsampling_Layout) return Image_Width is
   begin
      return Image_Width ((Natural (Width) + Layout.Chroma_Horizontal_Factor - 1) / Layout.Chroma_Horizontal_Factor);
   end Chroma_Width;

   function Chroma_Height
     (Height : Image_Height;
      Layout : Subsampling_Layout) return Image_Height is
   begin
      return Image_Height ((Natural (Height) + Layout.Chroma_Vertical_Factor - 1) / Layout.Chroma_Vertical_Factor);
   end Chroma_Height;

   function Gray_Sample
     (Input : Images.Image_View;
      X : Natural;
      Y : Natural) return Byte
   is
      Clamped_X : constant Natural := Natural'Min (X, Natural (Input.Descriptor.Width) - 1);
      Clamped_Y : constant Natural := Natural'Min (Y, Natural (Input.Descriptor.Height) - 1);
      Offset : constant Natural := Clamped_Y * Natural (Input.Descriptor.Stride) + Clamped_X;
      Index : constant Positive := Input.Storage'First + Offset;
   begin
      return Input.Storage (Index);
   end Gray_Sample;

   procedure Fill_Gray_Sample_Block
     (Input : Images.Image_View;
      Block_X : Natural;
      Block_Y : Natural;
      Samples : out Transforms.Sample_Block)
   is
      Source_X : constant Natural := Block_X * 8;
      Source_Y : constant Natural := Block_Y * 8;
      Row_Base : Positive;
   begin
      if Source_X + 7 < Natural (Input.Descriptor.Width)
        and then Source_Y + 7 < Natural (Input.Descriptor.Height)
      then
         for Local_Y in 0 .. 7 loop
            Row_Base :=
              Input.Storage'First
              + Natural ((Row_Stride (Source_Y + Local_Y) * Input.Descriptor.Stride) + Row_Stride (Source_X));
            for Local_X in 0 .. 7 loop
               pragma Loop_Optimize (Vector);
               Samples (Coefficient_Index (Local_Y * 8 + Local_X)) := Input.Storage (Row_Base + Local_X);
            end loop;
         end loop;
      else
         for Local_Y in 0 .. 7 loop
            for Local_X in 0 .. 7 loop
               Samples (Coefficient_Index (Local_Y * 8 + Local_X)) :=
                 Gray_Sample (Input, Source_X + Local_X, Source_Y + Local_Y);
            end loop;
         end loop;
      end if;
   end Fill_Gray_Sample_Block;

   function Encode_Gray_Blocks
     (Input : Images.Image_View;
      Table : Quantization.Quantization_Table;
      Blocks : in out Jpeglib.Coefficients.DCT_Block_Array;
      Mode : Transform_Mode := Full_Forward) return Image_Block_Result
   is
      Needed : Block_Count;
      Samples : Transforms.Sample_Block;
      Next_Block : Positive := Blocks'First;
   begin
      if not Images.Is_Valid (Input) or else Input.Descriptor.Format /= Images.Gray_8 then
         return (Outcome => Results.Failure (Errors.Frame_Invalid_Definition), Blocks_Encoded => 0);
      end if;

      Needed := Required_Block_Count (Input.Descriptor);
      if Block_Count (Blocks'Length) < Needed then
         return (Outcome => Results.Failure (Errors.Output_Limit_Exceeded), Blocks_Encoded => 0);
      end if;

      for Block_Y in 0 .. Ceil_Divide_By_8 (Natural (Input.Descriptor.Height)) - 1 loop
         for Block_X in 0 .. Ceil_Divide_By_8 (Natural (Input.Descriptor.Width)) - 1 loop
            Fill_Gray_Sample_Block (Input, Block_X, Block_Y, Samples);

            case Mode is
               when DC_Only =>
                  Blocks (Next_Block) := Transforms.Forward_DC_Only (Samples, Table);
               when Full_Forward =>
                  Blocks (Next_Block) := Transforms.Forward_Block (Samples, Table);
            end case;
            Next_Block := Next_Block + 1;
         end loop;
      end loop;

      return (Outcome => Results.Success, Blocks_Encoded => Needed);
   end Encode_Gray_Blocks;

   function Encode_Gray_DC_Blocks
     (Input : Images.Image_View;
      Table : Quantization.Quantization_Table;
      Blocks : in out Jpeglib.Coefficients.DCT_Block_Array) return Image_Block_Result is
   begin
      return Encode_Gray_Blocks (Input, Table, Blocks, Mode => DC_Only);
   end Encode_Gray_DC_Blocks;

   function Plane_Sample
     (Plane : Streams.Byte_Array;
      Width : Image_Width;
      Height : Image_Height;
      X : Natural;
      Y : Natural) return Byte
   is
      Clamped_X : constant Natural := Natural'Min (X, Natural (Width) - 1);
      Clamped_Y : constant Natural := Natural'Min (Y, Natural (Height) - 1);
      Offset : constant Natural := Clamped_Y * Natural (Width) + Clamped_X;
      Index : constant Positive := Plane'First + Offset;
   begin
      return Plane (Index);
   end Plane_Sample;

   procedure Fill_Plane_Sample_Block
     (Plane : Streams.Byte_Array;
      Width : Image_Width;
      Height : Image_Height;
      Block_X : Natural;
      Block_Y : Natural;
      Samples : out Transforms.Sample_Block)
   is
      Source_X : constant Natural := Block_X * 8;
      Source_Y : constant Natural := Block_Y * 8;
      Row_Base : Positive;
   begin
      if Source_X + 7 < Natural (Width)
        and then Source_Y + 7 < Natural (Height)
      then
         for Local_Y in 0 .. 7 loop
            Row_Base := Plane'First + (Source_Y + Local_Y) * Natural (Width) + Source_X;
            for Local_X in 0 .. 7 loop
               pragma Loop_Optimize (Vector);
               Samples (Coefficient_Index (Local_Y * 8 + Local_X)) := Plane (Row_Base + Local_X);
            end loop;
         end loop;
      else
         for Local_Y in 0 .. 7 loop
            for Local_X in 0 .. 7 loop
               Samples (Coefficient_Index (Local_Y * 8 + Local_X)) :=
                 Plane_Sample (Plane, Width, Height, Source_X + Local_X, Source_Y + Local_Y);
            end loop;
         end loop;
      end if;
   end Fill_Plane_Sample_Block;

   function Encode_Plane_Blocks
     (Plane : Streams.Byte_Array;
      Width : Image_Width;
      Height : Image_Height;
      Table : Quantization.Quantization_Table;
      Blocks : in out Jpeglib.Coefficients.DCT_Block_Array;
      Mode : Transform_Mode := Full_Forward) return Image_Block_Result
   is
      Needed : Block_Count;
      Samples : Transforms.Sample_Block;
      Next_Block : Positive := Blocks'First;
   begin
      Needed := Required_Plane_Block_Count (Width, Height);
      if Byte_Count (Plane'Length) < Byte_Count (Width) * Byte_Count (Height) then
         return (Outcome => Results.Failure (Errors.Output_Limit_Exceeded), Blocks_Encoded => 0);
      elsif Block_Count (Blocks'Length) < Needed then
         return (Outcome => Results.Failure (Errors.Output_Limit_Exceeded), Blocks_Encoded => 0);
      end if;

      for Block_Y in 0 .. Ceil_Divide_By_8 (Natural (Height)) - 1 loop
         for Block_X in 0 .. Ceil_Divide_By_8 (Natural (Width)) - 1 loop
            Fill_Plane_Sample_Block (Plane, Width, Height, Block_X, Block_Y, Samples);

            case Mode is
               when DC_Only =>
                  Blocks (Next_Block) := Transforms.Forward_DC_Only (Samples, Table);
               when Full_Forward =>
                  Blocks (Next_Block) := Transforms.Forward_Block (Samples, Table);
            end case;
            Next_Block := Next_Block + 1;
         end loop;
      end loop;

      return (Outcome => Results.Success, Blocks_Encoded => Needed);
   exception
      when Constraint_Error =>
         return (Outcome => Results.Failure (Errors.Internal_Invariant_Failed), Blocks_Encoded => 0);
   end Encode_Plane_Blocks;

   function Fill_YCbCr_Planes
     (Input : Images.Image_View;
      Y_Plane : in out Streams.Byte_Array;
      Cb_Plane : in out Streams.Byte_Array;
      Cr_Plane : in out Streams.Byte_Array) return Plane_Result
   is
      Samples_Needed : constant Byte_Count :=
        Byte_Count (Input.Descriptor.Width) * Byte_Count (Input.Descriptor.Height);
      Offset : Natural := 0;
      Written : Natural;
   begin
      if not Images.Is_Valid (Input) then
         return (Outcome => Results.Failure (Errors.Frame_Invalid_Definition), Samples_Written => 0);
      elsif Byte_Count (Y_Plane'Length) < Samples_Needed
        or else Byte_Count (Cb_Plane'Length) < Samples_Needed
        or else Byte_Count (Cr_Plane'Length) < Samples_Needed
      then
         return (Outcome => Results.Failure (Errors.Output_Limit_Exceeded), Samples_Written => 0);
      end if;

      for Row in 0 .. Natural (Input.Descriptor.Height) - 1 loop
         Colors.Convert_RGB_Row_To_YCbCr_Planes
           (Input,
            Row,
            Y_Plane,
            Cb_Plane,
            Cr_Plane,
            Offset,
            Natural (Input.Descriptor.Width),
            Written);
         if Written /= Natural (Input.Descriptor.Width) then
            return (Outcome => Results.Failure (Errors.Internal_Invariant_Failed), Samples_Written => 0);
         end if;
         Offset := Offset + Written;
      end loop;

      return (Outcome => Results.Success, Samples_Written => Samples_Needed);
   exception
      when Constraint_Error =>
         return (Outcome => Results.Failure (Errors.Internal_Invariant_Failed), Samples_Written => 0);
   end Fill_YCbCr_Planes;

   function Fill_Gray_Alpha_Planes
     (Input : Images.Image_View;
      Gray_Plane : in out Streams.Byte_Array;
      Alpha_Plane : in out Streams.Byte_Array) return Plane_Result
   is
      Samples_Needed : constant Byte_Count :=
        Byte_Count (Input.Descriptor.Width) * Byte_Count (Input.Descriptor.Height);
      Offset : Natural := 0;
      Written : Natural;
      Base : Positive;
   begin
      if not Images.Is_Valid (Input) or else Input.Descriptor.Format /= Images.Gray_Alpha_16 then
         return (Outcome => Results.Failure (Errors.Frame_Invalid_Definition), Samples_Written => 0);
      elsif Byte_Count (Gray_Plane'Length) < Samples_Needed
        or else Byte_Count (Alpha_Plane'Length) < Samples_Needed
      then
         return (Outcome => Results.Failure (Errors.Output_Limit_Exceeded), Samples_Written => 0);
      end if;

      for Row in 0 .. Natural (Input.Descriptor.Height) - 1 loop
         Colors.Convert_Gray_Alpha_Row_To_Planes
           (Input,
            Row,
            Gray_Plane,
            Alpha_Plane,
            Offset,
            Natural (Input.Descriptor.Width),
            Written);

         if Written /= Natural (Input.Descriptor.Width) then
            for Column in 0 .. Natural (Input.Descriptor.Width) - 1 loop
               Base :=
                 Input.Storage'First
                 + Row * Natural (Input.Descriptor.Stride)
                 + Column * 2;
               Gray_Plane (Gray_Plane'First + Offset + Column) := Input.Storage (Base);
               Alpha_Plane (Alpha_Plane'First + Offset + Column) := Input.Storage (Base + 1);
            end loop;
            Written := Natural (Input.Descriptor.Width);
         end if;
         Offset := Offset + Written;
      end loop;

      return (Outcome => Results.Success, Samples_Written => Samples_Needed * 2);
   exception
      when Constraint_Error =>
         return (Outcome => Results.Failure (Errors.Internal_Invariant_Failed), Samples_Written => 0);
   end Fill_Gray_Alpha_Planes;

   function Downsample_Plane
     (Source : Streams.Byte_Array;
      Source_Width : Image_Width;
      Source_Height : Image_Height;
      Horizontal_Factor : Positive;
      Vertical_Factor : Positive;
      Target : in out Streams.Byte_Array) return Plane_Result
   is
      Target_Width : constant Natural := (Natural (Source_Width) + Horizontal_Factor - 1) / Horizontal_Factor;
      Target_Height : constant Natural := (Natural (Source_Height) + Vertical_Factor - 1) / Vertical_Factor;
      Samples_Needed : constant Byte_Count := Byte_Count (Target_Width) * Byte_Count (Target_Height);
      Target_Offset : Natural := 0;
      Source_X : Natural;
      Source_Y : Natural;
      Source_Index : Positive;
      Sum : Natural;
      Count : Natural;

      function Average_Sample
        (Target_X : Natural;
         Target_Y : Natural) return Byte
      is
         Local_Sum : Natural := 0;
         Local_Count : Natural := 0;
         Local_Source_X : Natural;
         Local_Source_Y : Natural;
         Local_Source_Index : Positive;
      begin
         for Local_Y in 0 .. Vertical_Factor - 1 loop
            Local_Source_Y := Target_Y * Vertical_Factor + Local_Y;
            if Local_Source_Y < Natural (Source_Height) then
               for Local_X in 0 .. Horizontal_Factor - 1 loop
                  Local_Source_X := Target_X * Horizontal_Factor + Local_X;
                  if Local_Source_X < Natural (Source_Width) then
                     Local_Source_Index := Source'First + Local_Source_Y * Natural (Source_Width) + Local_Source_X;
                     Local_Sum := Local_Sum + Natural (Source (Local_Source_Index));
                     Local_Count := Local_Count + 1;
                  end if;
               end loop;
            end if;
         end loop;

         return Byte ((Local_Sum + Local_Count / 2) / Local_Count);
      end Average_Sample;
   begin
      if Byte_Count (Source'Length) < Byte_Count (Source_Width) * Byte_Count (Source_Height)
        or else Byte_Count (Target'Length) < Samples_Needed
      then
         return (Outcome => Results.Failure (Errors.Output_Limit_Exceeded), Samples_Written => 0);
      end if;

      if Horizontal_Factor = 1 and then Vertical_Factor = 1 then
         for Index in 0 .. Natural (Samples_Needed) - 1 loop
            pragma Loop_Optimize (Vector);
            Target (Target'First + Index) := Source (Source'First + Index);
         end loop;

         return (Outcome => Results.Success, Samples_Written => Samples_Needed);
      elsif Horizontal_Factor = 2 and then Vertical_Factor = 1 then
         declare
            Full_Target_Width : constant Natural := Natural (Source_Width) / 2;
            Source_Row_Base : Positive;
            Target_Row_Base : Positive;
            Source_Base : Positive;
         begin
            for Target_Y in 0 .. Target_Height - 1 loop
               Source_Row_Base := Source'First + Target_Y * Natural (Source_Width);
               Target_Row_Base := Target'First + Target_Y * Target_Width;

               for Target_X in 0 .. Full_Target_Width - 1 loop
                  pragma Loop_Optimize (Vector);
                  Source_Base := Source_Row_Base + Target_X * 2;
                  Target (Target_Row_Base + Target_X) :=
                    Byte ((Natural (Source (Source_Base)) + Natural (Source (Source_Base + 1)) + 1) / 2);
               end loop;

               if Full_Target_Width < Target_Width then
                  Target (Target_Row_Base + Full_Target_Width) := Average_Sample (Full_Target_Width, Target_Y);
               end if;
            end loop;

            return (Outcome => Results.Success, Samples_Written => Samples_Needed);
         end;
      elsif Horizontal_Factor = 4 and then Vertical_Factor = 1 then
         declare
            Full_Target_Width : constant Natural := Natural (Source_Width) / 4;
            Source_Row_Base : Positive;
            Target_Row_Base : Positive;
            Source_Base : Positive;
         begin
            for Target_Y in 0 .. Target_Height - 1 loop
               Source_Row_Base := Source'First + Target_Y * Natural (Source_Width);
               Target_Row_Base := Target'First + Target_Y * Target_Width;

               for Target_X in 0 .. Full_Target_Width - 1 loop
                  pragma Loop_Optimize (Vector);
                  Source_Base := Source_Row_Base + Target_X * 4;
                  Target (Target_Row_Base + Target_X) :=
                    Byte
                      ((Natural (Source (Source_Base))
                        + Natural (Source (Source_Base + 1))
                        + Natural (Source (Source_Base + 2))
                        + Natural (Source (Source_Base + 3))
                        + 2)
                       / 4);
               end loop;

               if Full_Target_Width < Target_Width then
                  Target (Target_Row_Base + Full_Target_Width) := Average_Sample (Full_Target_Width, Target_Y);
               end if;
            end loop;

            return (Outcome => Results.Success, Samples_Written => Samples_Needed);
         end;
      elsif Horizontal_Factor = 2 and then Vertical_Factor = 2 then
         declare
            Full_Target_Width : constant Natural := Natural (Source_Width) / 2;
            Full_Target_Height : constant Natural := Natural (Source_Height) / 2;
            Top_Row_Base : Positive;
            Bottom_Row_Base : Positive;
            Target_Row_Base : Positive;
            Top_Base : Positive;
            Bottom_Base : Positive;
         begin
            for Target_Y in 0 .. Full_Target_Height - 1 loop
               Top_Row_Base := Source'First + Target_Y * 2 * Natural (Source_Width);
               Bottom_Row_Base := Top_Row_Base + Natural (Source_Width);
               Target_Row_Base := Target'First + Target_Y * Target_Width;

               for Target_X in 0 .. Full_Target_Width - 1 loop
                  pragma Loop_Optimize (Vector);
                  Top_Base := Top_Row_Base + Target_X * 2;
                  Bottom_Base := Bottom_Row_Base + Target_X * 2;
                  Target (Target_Row_Base + Target_X) :=
                    Byte
                      ((Natural (Source (Top_Base))
                        + Natural (Source (Top_Base + 1))
                        + Natural (Source (Bottom_Base))
                        + Natural (Source (Bottom_Base + 1))
                        + 2)
                       / 4);
               end loop;

               if Full_Target_Width < Target_Width then
                  Target (Target_Row_Base + Full_Target_Width) := Average_Sample (Full_Target_Width, Target_Y);
               end if;
            end loop;

            for Target_Y in Full_Target_Height .. Target_Height - 1 loop
               Target_Row_Base := Target'First + Target_Y * Target_Width;
               for Target_X in 0 .. Target_Width - 1 loop
                  Target (Target_Row_Base + Target_X) := Average_Sample (Target_X, Target_Y);
               end loop;
            end loop;

            return (Outcome => Results.Success, Samples_Written => Samples_Needed);
         end;
      end if;

      for Target_Y in 0 .. Target_Height - 1 loop
         for Target_X in 0 .. Target_Width - 1 loop
            Sum := 0;
            Count := 0;

            for Local_Y in 0 .. Vertical_Factor - 1 loop
               Source_Y := Target_Y * Vertical_Factor + Local_Y;
               if Source_Y < Natural (Source_Height) then
                  for Local_X in 0 .. Horizontal_Factor - 1 loop
                     Source_X := Target_X * Horizontal_Factor + Local_X;
                     if Source_X < Natural (Source_Width) then
                        Source_Index := Source'First + Source_Y * Natural (Source_Width) + Source_X;
                        Sum := Sum + Natural (Source (Source_Index));
                        Count := Count + 1;
                     end if;
                  end loop;
               end if;
            end loop;

            Target (Target'First + Target_Offset) := Byte ((Sum + Count / 2) / Count);
            Target_Offset := Target_Offset + 1;
         end loop;
      end loop;

      return (Outcome => Results.Success, Samples_Written => Samples_Needed);
   exception
      when Constraint_Error =>
         return (Outcome => Results.Failure (Errors.Internal_Invariant_Failed), Samples_Written => 0);
   end Downsample_Plane;

   function Subsample_Chroma_Planes
     (Cb_Source : Streams.Byte_Array;
      Cr_Source : Streams.Byte_Array;
      Source_Width : Image_Width;
      Source_Height : Image_Height;
      Layout : Subsampling_Layout;
      Cb_Target : in out Streams.Byte_Array;
      Cr_Target : in out Streams.Byte_Array) return Plane_Result
   is
      Cb_Result : Plane_Result;
      Cr_Result : Plane_Result;
   begin
      Cb_Result :=
        Downsample_Plane
          (Cb_Source,
           Source_Width,
           Source_Height,
           Layout.Chroma_Horizontal_Factor,
           Layout.Chroma_Vertical_Factor,
           Cb_Target);
      if not Results.Succeeded (Cb_Result.Outcome) then
         return Cb_Result;
      end if;

      Cr_Result :=
        Downsample_Plane
          (Cr_Source,
           Source_Width,
           Source_Height,
           Layout.Chroma_Horizontal_Factor,
           Layout.Chroma_Vertical_Factor,
           Cr_Target);
      if not Results.Succeeded (Cr_Result.Outcome) then
         return Cr_Result;
      end if;

      return (Outcome => Results.Success, Samples_Written => Cb_Result.Samples_Written + Cr_Result.Samples_Written);
   exception
      when Constraint_Error =>
         return (Outcome => Results.Failure (Errors.Internal_Invariant_Failed), Samples_Written => 0);
   end Subsample_Chroma_Planes;
end Jpeglib.Internal.Image_Blocks;

package body Jpeglib.Internal.Colors is
   use type Images.Pixel_Format;

   Scale : constant Integer := 65_536;

   function Clamp (Value : Integer) return Byte is
   begin
      if Value < 0 then
         return 0;
      elsif Value > Integer (Byte'Last) then
         return Byte'Last;
      else
         return Byte (Value);
      end if;
   end Clamp;

   function Rounded_Scaled (Value : Integer) return Integer is
   begin
      if Value >= 0 then
         return (Value + Scale / 2) / Scale;
      else
         return (Value - Scale / 2) / Scale;
      end if;
   end Rounded_Scaled;

   function Subtractive_Channel (Ink : Byte; Black : Byte) return Byte;

   function Active_Acceleration return Acceleration_Profile is
   begin
      return Compiler_Vectorized_SIMD;
   end Active_Acceleration;

   function RGB_Bytes_To_YCbCr (R_Byte, G_Byte, B_Byte : Byte) return YCbCr_Sample is
      R : constant Integer := Integer (R_Byte);
      G : constant Integer := Integer (G_Byte);
      B : constant Integer := Integer (B_Byte);
      Y : constant Integer := Rounded_Scaled (19_595 * R + 38_470 * G + 7_471 * B);
      Cb : constant Integer := 128 + Rounded_Scaled (-11_059 * R - 21_709 * G + 32_768 * B);
      Cr : constant Integer := 128 + Rounded_Scaled (32_768 * R - 27_439 * G - 5_329 * B);
   begin
      return (Y => Clamp (Y), Cb => Clamp (Cb), Cr => Clamp (Cr));
   end RGB_Bytes_To_YCbCr;

   function Read_RGB
     (Input : Images.Image_View;
      Column : Natural;
      Row : Natural) return RGB_Sample
   is
      Descriptor : constant Images.Image_Descriptor := Input.Descriptor;
      Base : constant Positive :=
        Input.Storage'First
        + Natural (Row_Stride (Row) * Descriptor.Stride)
        + Natural (Byte_Count (Column) * Images.Bytes_Per_Pixel (Descriptor.Format));
   begin
      case Descriptor.Format is
         when Images.Gray_8 =>
            return (R => Input.Storage (Base), G => Input.Storage (Base), B => Input.Storage (Base));
         when Images.Gray_Alpha_16 =>
            return (R => Input.Storage (Base), G => Input.Storage (Base), B => Input.Storage (Base));
         when Images.RGB_24 =>
            return (R => Input.Storage (Base), G => Input.Storage (Base + 1), B => Input.Storage (Base + 2));
         when Images.BGR_24 =>
            return (R => Input.Storage (Base + 2), G => Input.Storage (Base + 1), B => Input.Storage (Base));
         when Images.RGBA_32 =>
            return (R => Input.Storage (Base), G => Input.Storage (Base + 1), B => Input.Storage (Base + 2));
         when Images.BGRA_32 =>
            return (R => Input.Storage (Base + 2), G => Input.Storage (Base + 1), B => Input.Storage (Base));
         when Images.CMYK_32 =>
            return
              (R => Subtractive_Channel (Input.Storage (Base), Input.Storage (Base + 3)),
               G => Subtractive_Channel (Input.Storage (Base + 1), Input.Storage (Base + 3)),
               B => Subtractive_Channel (Input.Storage (Base + 2), Input.Storage (Base + 3)));
         when Images.YCCK_32 =>
            declare
               Y_Int : constant Integer := Integer (Input.Storage (Base));
               Cb_Delta : constant Integer := Integer (Input.Storage (Base + 1)) - 128;
               Cr_Delta : constant Integer := Integer (Input.Storage (Base + 2)) - 128;
               K : constant Byte := Input.Storage (Base + 3);
               R : constant Byte := Clamp (Y_Int + Rounded_Scaled (91_881 * Cr_Delta));
               G : constant Byte := Clamp (Y_Int - Rounded_Scaled (22_554 * Cb_Delta + 46_802 * Cr_Delta));
               B : constant Byte := Clamp (Y_Int + Rounded_Scaled (116_130 * Cb_Delta));
            begin
               return
                 (R => Subtractive_Channel (Byte'Last - R, K),
                  G => Subtractive_Channel (Byte'Last - G, K),
                  B => Subtractive_Channel (Byte'Last - B, K));
            end;
      end case;
   end Read_RGB;

   function Convert_RGB_To_YCbCr (Sample : RGB_Sample) return YCbCr_Sample is
   begin
      return RGB_Bytes_To_YCbCr (Sample.R, Sample.G, Sample.B);
   end Convert_RGB_To_YCbCr;

   procedure Store_YCbCr
     (Y_Plane : in out Streams.Byte_Array;
      Cb_Plane : in out Streams.Byte_Array;
      Cr_Plane : in out Streams.Byte_Array;
      Y_Index : Positive;
      Cb_Index : Positive;
      Cr_Index : Positive;
      R : Byte;
      G : Byte;
      B : Byte)
   is
      YCbCr : constant YCbCr_Sample := RGB_Bytes_To_YCbCr (R, G, B);
   begin
      Y_Plane (Y_Index) := YCbCr.Y;
      Cb_Plane (Cb_Index) := YCbCr.Cb;
      Cr_Plane (Cr_Index) := YCbCr.Cr;
   end Store_YCbCr;

   procedure Convert_RGB_Row_To_YCbCr_Planes
     (Input : Images.Image_View;
      Row : Natural;
      Y_Plane : in out Streams.Byte_Array;
      Cb_Plane : in out Streams.Byte_Array;
      Cr_Plane : in out Streams.Byte_Array;
      Output_Offset : Natural;
      Pixels : Natural;
      Written : out Natural)
   is
      Descriptor : constant Images.Image_Descriptor := Input.Descriptor;
      Input_Row_Base : constant Positive :=
        Input.Storage'First + Natural (Row_Stride (Row) * Descriptor.Stride);
      Y_Output_Base : constant Positive := Y_Plane'First + Output_Offset;
      Cb_Output_Base : constant Positive := Cb_Plane'First + Output_Offset;
      Cr_Output_Base : constant Positive := Cr_Plane'First + Output_Offset;
      Input_Index : Positive;
      Y_Index : Positive;
      Cb_Index : Positive;
      Cr_Index : Positive;
      RGB : RGB_Sample;
   begin
      Written := 0;
      if Pixels = 0
        or else Row >= Natural (Descriptor.Height)
        or else Output_Offset + Pixels > Natural (Y_Plane'Length)
        or else Output_Offset + Pixels > Natural (Cb_Plane'Length)
        or else Output_Offset + Pixels > Natural (Cr_Plane'Length)
      then
         return;
      end if;

      case Descriptor.Format is
         when Images.RGB_24 =>
            for Column in 0 .. Pixels - 1 loop
               pragma Loop_Optimize (Vector);
               Input_Index := Input_Row_Base + Column * 3;
               Y_Index := Y_Output_Base + Column;
               Cb_Index := Cb_Output_Base + Column;
               Cr_Index := Cr_Output_Base + Column;
               Store_YCbCr
                 (Y_Plane,
                  Cb_Plane,
                  Cr_Plane,
                  Y_Index,
                  Cb_Index,
                  Cr_Index,
                  Input.Storage (Input_Index),
                  Input.Storage (Input_Index + 1),
                  Input.Storage (Input_Index + 2));
            end loop;
         when Images.BGR_24 =>
            for Column in 0 .. Pixels - 1 loop
               pragma Loop_Optimize (Vector);
               Input_Index := Input_Row_Base + Column * 3;
               Y_Index := Y_Output_Base + Column;
               Cb_Index := Cb_Output_Base + Column;
               Cr_Index := Cr_Output_Base + Column;
               Store_YCbCr
                 (Y_Plane,
                  Cb_Plane,
                  Cr_Plane,
                  Y_Index,
                  Cb_Index,
                  Cr_Index,
                  Input.Storage (Input_Index + 2),
                  Input.Storage (Input_Index + 1),
                  Input.Storage (Input_Index));
            end loop;
         when Images.RGBA_32 =>
            for Column in 0 .. Pixels - 1 loop
               pragma Loop_Optimize (Vector);
               Input_Index := Input_Row_Base + Column * 4;
               Y_Index := Y_Output_Base + Column;
               Cb_Index := Cb_Output_Base + Column;
               Cr_Index := Cr_Output_Base + Column;
               Store_YCbCr
                 (Y_Plane,
                  Cb_Plane,
                  Cr_Plane,
                  Y_Index,
                  Cb_Index,
                  Cr_Index,
                  Input.Storage (Input_Index),
                  Input.Storage (Input_Index + 1),
                  Input.Storage (Input_Index + 2));
            end loop;
         when Images.BGRA_32 =>
            for Column in 0 .. Pixels - 1 loop
               pragma Loop_Optimize (Vector);
               Input_Index := Input_Row_Base + Column * 4;
               Y_Index := Y_Output_Base + Column;
               Cb_Index := Cb_Output_Base + Column;
               Cr_Index := Cr_Output_Base + Column;
               Store_YCbCr
                 (Y_Plane,
                  Cb_Plane,
                  Cr_Plane,
                  Y_Index,
                  Cb_Index,
                  Cr_Index,
                  Input.Storage (Input_Index + 2),
                  Input.Storage (Input_Index + 1),
                  Input.Storage (Input_Index));
            end loop;
         when others =>
            for Column in 0 .. Pixels - 1 loop
               pragma Loop_Optimize (Vector);
               RGB := Read_RGB (Input, Column, Row);
               Y_Index := Y_Output_Base + Column;
               Cb_Index := Cb_Output_Base + Column;
               Cr_Index := Cr_Output_Base + Column;
               Store_YCbCr (Y_Plane, Cb_Plane, Cr_Plane, Y_Index, Cb_Index, Cr_Index, RGB.R, RGB.G, RGB.B);
            end loop;
      end case;

      Written := Pixels;
   exception
      when Constraint_Error =>
         Written := 0;
   end Convert_RGB_Row_To_YCbCr_Planes;

   function Read_CMYK
     (Input : Images.Image_View;
      Column : Natural;
      Row : Natural) return CMYK_Sample
   is
      Descriptor : constant Images.Image_Descriptor := Input.Descriptor;
      Base : constant Positive :=
        Input.Storage'First
        + Natural (Row_Stride (Row) * Descriptor.Stride)
        + Natural (Byte_Count (Column) * Images.Bytes_Per_Pixel (Descriptor.Format));
      RGB : RGB_Sample;
   begin
      case Descriptor.Format is
         when Images.CMYK_32 | Images.YCCK_32 =>
            return
              (C => Input.Storage (Base),
               M => Input.Storage (Base + 1),
               Y => Input.Storage (Base + 2),
               K => Input.Storage (Base + 3));
         when others =>
            RGB := Read_RGB (Input, Column, Row);
            return
              (C => Byte'Last - RGB.R,
               M => Byte'Last - RGB.G,
               Y => Byte'Last - RGB.B,
               K => 0);
      end case;
   end Read_CMYK;

   function Read_YCCK
     (Input : Images.Image_View;
      Column : Natural;
      Row : Natural) return CMYK_Sample is
   begin
      return Read_CMYK (Input, Column, Row);
   end Read_YCCK;

   procedure Write_RGB_Channels
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      R : Byte;
      G : Byte;
      B : Byte;
      Alpha : Byte)
   is
      Descriptor : constant Images.Image_Descriptor := Output.Descriptor;
      Base : constant Positive :=
        Output.Storage'First
        + Natural (Row_Stride (Row) * Descriptor.Stride)
        + Natural (Byte_Count (Column) * Images.Bytes_Per_Pixel (Descriptor.Format));
   begin
      case Descriptor.Format is
         when Images.Gray_8 =>
            Output.Storage (Base) := R;
         when Images.Gray_Alpha_16 =>
            Output.Storage (Base) := R;
            Output.Storage (Base + 1) := Alpha;
         when Images.RGB_24 =>
            Output.Storage (Base) := R;
            Output.Storage (Base + 1) := G;
            Output.Storage (Base + 2) := B;
         when Images.BGR_24 =>
            Output.Storage (Base) := B;
            Output.Storage (Base + 1) := G;
            Output.Storage (Base + 2) := R;
         when Images.RGBA_32 =>
            Output.Storage (Base) := R;
            Output.Storage (Base + 1) := G;
            Output.Storage (Base + 2) := B;
            Output.Storage (Base + 3) := Alpha;
         when Images.BGRA_32 =>
            Output.Storage (Base) := B;
            Output.Storage (Base + 1) := G;
            Output.Storage (Base + 2) := R;
            Output.Storage (Base + 3) := Alpha;
         when Images.CMYK_32 =>
            Output.Storage (Base) := Byte'Last - R;
            Output.Storage (Base + 1) := Byte'Last - G;
            Output.Storage (Base + 2) := Byte'Last - B;
            Output.Storage (Base + 3) := 0;
         when Images.YCCK_32 =>
            declare
               YCbCr : constant YCbCr_Sample := Convert_RGB_To_YCbCr ((R => R, G => G, B => B));
            begin
               Output.Storage (Base) := YCbCr.Y;
               Output.Storage (Base + 1) := YCbCr.Cb;
               Output.Storage (Base + 2) := YCbCr.Cr;
               Output.Storage (Base + 3) := 0;
            end;
      end case;
   end Write_RGB_Channels;

   procedure Write_Gray
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      Gray : Byte;
      Alpha : Byte := Byte'Last) is
   begin
      Write_RGB_Channels (Output, Column, Row, Gray, Gray, Gray, Alpha);
   end Write_Gray;

   procedure Write_Gray_Alpha
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      Gray : Byte;
      Alpha : Byte) is
   begin
      Write_RGB_Channels (Output, Column, Row, Gray, Gray, Gray, Alpha);
   end Write_Gray_Alpha;

   procedure Write_YCbCr
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      Y : Byte;
      Cb : Byte;
      Cr : Byte;
      Alpha : Byte := Byte'Last)
   is
      Y_Int : constant Integer := Integer (Y);
      Cb_Delta : constant Integer := Integer (Cb) - 128;
      Cr_Delta : constant Integer := Integer (Cr) - 128;
      R : constant Byte := Clamp (Y_Int + Rounded_Scaled (91_881 * Cr_Delta));
      G : constant Byte := Clamp (Y_Int - Rounded_Scaled (22_554 * Cb_Delta + 46_802 * Cr_Delta));
      B : constant Byte := Clamp (Y_Int + Rounded_Scaled (116_130 * Cb_Delta));
   begin
      Write_RGB_Channels (Output, Column, Row, R, G, B, Alpha);
   end Write_YCbCr;

   procedure YCbCr_Bytes_To_RGB
     (Y : Byte;
      Cb : Byte;
      Cr : Byte;
      R : out Byte;
      G : out Byte;
      B : out Byte)
   is
      Y_Int : constant Integer := Integer (Y);
      Cb_Delta : constant Integer := Integer (Cb) - 128;
      Cr_Delta : constant Integer := Integer (Cr) - 128;
   begin
      R := Clamp (Y_Int + Rounded_Scaled (91_881 * Cr_Delta));
      G := Clamp (Y_Int - Rounded_Scaled (22_554 * Cb_Delta + 46_802 * Cr_Delta));
      B := Clamp (Y_Int + Rounded_Scaled (116_130 * Cb_Delta));
   end YCbCr_Bytes_To_RGB;

   procedure Write_YCbCr_Row
     (Output : in out Images.Mutable_Image_View;
      Row : Natural;
      Y_Plane : Streams.Byte_Array;
      Cb_Plane : Streams.Byte_Array;
      Cr_Plane : Streams.Byte_Array;
      Input_Offset : Natural;
      Pixels : Natural;
      Alpha : Byte := Byte'Last;
      Written : out Natural)
   is
      Descriptor : constant Images.Image_Descriptor := Output.Descriptor;
      Output_Row_Base : constant Positive :=
        Output.Storage'First + Natural (Row_Stride (Row) * Descriptor.Stride);
      Y_Input_Base : constant Positive := Y_Plane'First + Input_Offset;
      Cb_Input_Base : constant Positive := Cb_Plane'First + Input_Offset;
      Cr_Input_Base : constant Positive := Cr_Plane'First + Input_Offset;
      Output_Index : Positive;
      Y_Index : Positive;
      Cb_Index : Positive;
      Cr_Index : Positive;
      R : Byte;
      G : Byte;
      B : Byte;
   begin
      Written := 0;
      if Pixels = 0
        or else Row >= Natural (Descriptor.Height)
        or else Pixels > Natural (Descriptor.Width)
        or else Input_Offset + Pixels > Natural (Y_Plane'Length)
        or else Input_Offset + Pixels > Natural (Cb_Plane'Length)
        or else Input_Offset + Pixels > Natural (Cr_Plane'Length)
      then
         return;
      end if;

      case Descriptor.Format is
         when Images.RGB_24 =>
            for Column in 0 .. Pixels - 1 loop
               pragma Loop_Optimize (Vector);
               Y_Index := Y_Input_Base + Column;
               Cb_Index := Cb_Input_Base + Column;
               Cr_Index := Cr_Input_Base + Column;
               Output_Index := Output_Row_Base + Column * 3;
               YCbCr_Bytes_To_RGB (Y_Plane (Y_Index), Cb_Plane (Cb_Index), Cr_Plane (Cr_Index), R, G, B);
               Output.Storage (Output_Index) := R;
               Output.Storage (Output_Index + 1) := G;
               Output.Storage (Output_Index + 2) := B;
            end loop;
         when Images.BGR_24 =>
            for Column in 0 .. Pixels - 1 loop
               pragma Loop_Optimize (Vector);
               Y_Index := Y_Input_Base + Column;
               Cb_Index := Cb_Input_Base + Column;
               Cr_Index := Cr_Input_Base + Column;
               Output_Index := Output_Row_Base + Column * 3;
               YCbCr_Bytes_To_RGB (Y_Plane (Y_Index), Cb_Plane (Cb_Index), Cr_Plane (Cr_Index), R, G, B);
               Output.Storage (Output_Index) := B;
               Output.Storage (Output_Index + 1) := G;
               Output.Storage (Output_Index + 2) := R;
            end loop;
         when Images.RGBA_32 =>
            for Column in 0 .. Pixels - 1 loop
               pragma Loop_Optimize (Vector);
               Y_Index := Y_Input_Base + Column;
               Cb_Index := Cb_Input_Base + Column;
               Cr_Index := Cr_Input_Base + Column;
               Output_Index := Output_Row_Base + Column * 4;
               YCbCr_Bytes_To_RGB (Y_Plane (Y_Index), Cb_Plane (Cb_Index), Cr_Plane (Cr_Index), R, G, B);
               Output.Storage (Output_Index) := R;
               Output.Storage (Output_Index + 1) := G;
               Output.Storage (Output_Index + 2) := B;
               Output.Storage (Output_Index + 3) := Alpha;
            end loop;
         when Images.BGRA_32 =>
            for Column in 0 .. Pixels - 1 loop
               pragma Loop_Optimize (Vector);
               Y_Index := Y_Input_Base + Column;
               Cb_Index := Cb_Input_Base + Column;
               Cr_Index := Cr_Input_Base + Column;
               Output_Index := Output_Row_Base + Column * 4;
               YCbCr_Bytes_To_RGB (Y_Plane (Y_Index), Cb_Plane (Cb_Index), Cr_Plane (Cr_Index), R, G, B);
               Output.Storage (Output_Index) := B;
               Output.Storage (Output_Index + 1) := G;
               Output.Storage (Output_Index + 2) := R;
               Output.Storage (Output_Index + 3) := Alpha;
            end loop;
         when others =>
            for Column in 0 .. Pixels - 1 loop
               pragma Loop_Optimize (Vector);
               Y_Index := Y_Input_Base + Column;
               Cb_Index := Cb_Input_Base + Column;
               Cr_Index := Cr_Input_Base + Column;
               Write_YCbCr
                 (Output,
                  Column,
                  Row,
                  Y_Plane (Y_Index),
                  Cb_Plane (Cb_Index),
                  Cr_Plane (Cr_Index),
                  Alpha);
            end loop;
      end case;

      Written := Pixels;
   exception
      when Constraint_Error =>
         Written := 0;
   end Write_YCbCr_Row;

   procedure Write_RGB
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      R : Byte;
      G : Byte;
      B : Byte;
      Alpha : Byte := Byte'Last) is
   begin
      Write_RGB_Channels (Output, Column, Row, R, G, B, Alpha);
   end Write_RGB;

   procedure Write_RGB_Row
     (Output : in out Images.Mutable_Image_View;
      Row : Natural;
      R_Plane : Streams.Byte_Array;
      G_Plane : Streams.Byte_Array;
      B_Plane : Streams.Byte_Array;
      Input_Offset : Natural;
      Pixels : Natural;
      Alpha : Byte := Byte'Last;
      Written : out Natural)
   is
      Descriptor : constant Images.Image_Descriptor := Output.Descriptor;
      Output_Row_Base : constant Positive :=
        Output.Storage'First + Natural (Row_Stride (Row) * Descriptor.Stride);
      R_Input_Base : constant Positive := R_Plane'First + Input_Offset;
      G_Input_Base : constant Positive := G_Plane'First + Input_Offset;
      B_Input_Base : constant Positive := B_Plane'First + Input_Offset;
      Output_Index : Positive;
      R_Index : Positive;
      G_Index : Positive;
      B_Index : Positive;
      YCbCr : YCbCr_Sample;
   begin
      Written := 0;
      if Pixels = 0
        or else Row >= Natural (Descriptor.Height)
        or else Pixels > Natural (Descriptor.Width)
        or else Input_Offset + Pixels > Natural (R_Plane'Length)
        or else Input_Offset + Pixels > Natural (G_Plane'Length)
        or else Input_Offset + Pixels > Natural (B_Plane'Length)
      then
         return;
      end if;

      case Descriptor.Format is
         when Images.RGB_24 =>
            for Column in 0 .. Pixels - 1 loop
               pragma Loop_Optimize (Vector);
               R_Index := R_Input_Base + Column;
               G_Index := G_Input_Base + Column;
               B_Index := B_Input_Base + Column;
               Output_Index := Output_Row_Base + Column * 3;
               Output.Storage (Output_Index) := R_Plane (R_Index);
               Output.Storage (Output_Index + 1) := G_Plane (G_Index);
               Output.Storage (Output_Index + 2) := B_Plane (B_Index);
            end loop;
         when Images.BGR_24 =>
            for Column in 0 .. Pixels - 1 loop
               pragma Loop_Optimize (Vector);
               R_Index := R_Input_Base + Column;
               G_Index := G_Input_Base + Column;
               B_Index := B_Input_Base + Column;
               Output_Index := Output_Row_Base + Column * 3;
               Output.Storage (Output_Index) := B_Plane (B_Index);
               Output.Storage (Output_Index + 1) := G_Plane (G_Index);
               Output.Storage (Output_Index + 2) := R_Plane (R_Index);
            end loop;
         when Images.RGBA_32 =>
            for Column in 0 .. Pixels - 1 loop
               pragma Loop_Optimize (Vector);
               R_Index := R_Input_Base + Column;
               G_Index := G_Input_Base + Column;
               B_Index := B_Input_Base + Column;
               Output_Index := Output_Row_Base + Column * 4;
               Output.Storage (Output_Index) := R_Plane (R_Index);
               Output.Storage (Output_Index + 1) := G_Plane (G_Index);
               Output.Storage (Output_Index + 2) := B_Plane (B_Index);
               Output.Storage (Output_Index + 3) := Alpha;
            end loop;
         when Images.BGRA_32 =>
            for Column in 0 .. Pixels - 1 loop
               pragma Loop_Optimize (Vector);
               R_Index := R_Input_Base + Column;
               G_Index := G_Input_Base + Column;
               B_Index := B_Input_Base + Column;
               Output_Index := Output_Row_Base + Column * 4;
               Output.Storage (Output_Index) := B_Plane (B_Index);
               Output.Storage (Output_Index + 1) := G_Plane (G_Index);
               Output.Storage (Output_Index + 2) := R_Plane (R_Index);
               Output.Storage (Output_Index + 3) := Alpha;
            end loop;
         when Images.CMYK_32 =>
            for Column in 0 .. Pixels - 1 loop
               pragma Loop_Optimize (Vector);
               R_Index := R_Input_Base + Column;
               G_Index := G_Input_Base + Column;
               B_Index := B_Input_Base + Column;
               Output_Index := Output_Row_Base + Column * 4;
               Output.Storage (Output_Index) := Byte'Last - R_Plane (R_Index);
               Output.Storage (Output_Index + 1) := Byte'Last - G_Plane (G_Index);
               Output.Storage (Output_Index + 2) := Byte'Last - B_Plane (B_Index);
               Output.Storage (Output_Index + 3) := 0;
            end loop;
         when Images.YCCK_32 =>
            for Column in 0 .. Pixels - 1 loop
               pragma Loop_Optimize (Vector);
               R_Index := R_Input_Base + Column;
               G_Index := G_Input_Base + Column;
               B_Index := B_Input_Base + Column;
               Output_Index := Output_Row_Base + Column * 4;
               YCbCr :=
                 Convert_RGB_To_YCbCr
                   ((R => R_Plane (R_Index), G => G_Plane (G_Index), B => B_Plane (B_Index)));
               Output.Storage (Output_Index) := YCbCr.Y;
               Output.Storage (Output_Index + 1) := YCbCr.Cb;
               Output.Storage (Output_Index + 2) := YCbCr.Cr;
               Output.Storage (Output_Index + 3) := 0;
            end loop;
         when others =>
            for Column in 0 .. Pixels - 1 loop
               pragma Loop_Optimize (Vector);
               R_Index := R_Input_Base + Column;
               G_Index := G_Input_Base + Column;
               B_Index := B_Input_Base + Column;
               Write_RGB_Channels
                 (Output,
                  Column,
                  Row,
                  R_Plane (R_Index),
                  G_Plane (G_Index),
                  B_Plane (B_Index),
                  Alpha);
            end loop;
      end case;

      Written := Pixels;
   exception
      when Constraint_Error =>
         Written := 0;
   end Write_RGB_Row;

   function Subtractive_Channel (Ink : Byte; Black : Byte) return Byte is
      Sum : constant Natural := Natural (Ink) + Natural (Black);
   begin
      if Sum >= Natural (Byte'Last) then
         return 0;
      else
         return Byte (Natural (Byte'Last) - Sum);
      end if;
   end Subtractive_Channel;

   procedure Write_CMYK
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      C : Byte;
      M : Byte;
      Y : Byte;
      K : Byte;
      Alpha : Byte := Byte'Last)
   is
      R : constant Byte := Subtractive_Channel (C, K);
      G : constant Byte := Subtractive_Channel (M, K);
      B : constant Byte := Subtractive_Channel (Y, K);
      Descriptor : constant Images.Image_Descriptor := Output.Descriptor;
      Base : constant Positive :=
        Output.Storage'First
        + Natural (Row_Stride (Row) * Descriptor.Stride)
        + Natural (Byte_Count (Column) * Images.Bytes_Per_Pixel (Descriptor.Format));
   begin
      case Descriptor.Format is
         when Images.CMYK_32 =>
            Output.Storage (Base) := C;
            Output.Storage (Base + 1) := M;
            Output.Storage (Base + 2) := Y;
            Output.Storage (Base + 3) := K;
         when Images.YCCK_32 =>
            declare
               YCbCr : constant YCbCr_Sample := Convert_RGB_To_YCbCr ((R => R, G => G, B => B));
            begin
               Output.Storage (Base) := YCbCr.Y;
               Output.Storage (Base + 1) := YCbCr.Cb;
               Output.Storage (Base + 2) := YCbCr.Cr;
               Output.Storage (Base + 3) := K;
            end;
         when others =>
            Write_RGB_Channels (Output, Column, Row, R, G, B, Alpha);
      end case;
   end Write_CMYK;

   procedure Write_YCCK
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      Y : Byte;
      Cb : Byte;
      Cr : Byte;
      K : Byte;
      Alpha : Byte := Byte'Last)
   is
      Y_Int : constant Integer := Integer (Y);
      Cb_Delta : constant Integer := Integer (Cb) - 128;
      Cr_Delta : constant Integer := Integer (Cr) - 128;
      R : constant Byte := Clamp (Y_Int + Rounded_Scaled (91_881 * Cr_Delta));
      G : constant Byte := Clamp (Y_Int - Rounded_Scaled (22_554 * Cb_Delta + 46_802 * Cr_Delta));
      B : constant Byte := Clamp (Y_Int + Rounded_Scaled (116_130 * Cb_Delta));
      Descriptor : constant Images.Image_Descriptor := Output.Descriptor;
      Base : constant Positive :=
        Output.Storage'First
        + Natural (Row_Stride (Row) * Descriptor.Stride)
        + Natural (Byte_Count (Column) * Images.Bytes_Per_Pixel (Descriptor.Format));
   begin
      if Descriptor.Format = Images.YCCK_32 then
         Output.Storage (Base) := Y;
         Output.Storage (Base + 1) := Cb;
         Output.Storage (Base + 2) := Cr;
         Output.Storage (Base + 3) := K;
      else
         Write_CMYK
           (Output,
            Column,
            Row,
            Byte'Last - R,
            Byte'Last - G,
            Byte'Last - B,
            K,
            Alpha);
      end if;
   end Write_YCCK;
end Jpeglib.Internal.Colors;

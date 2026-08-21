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
      R : constant Integer := Integer (Sample.R);
      G : constant Integer := Integer (Sample.G);
      B : constant Integer := Integer (Sample.B);
      Y : constant Integer := Rounded_Scaled (19_595 * R + 38_470 * G + 7_471 * B);
      Cb : constant Integer := 128 + Rounded_Scaled (-11_059 * R - 21_709 * G + 32_768 * B);
      Cr : constant Integer := 128 + Rounded_Scaled (32_768 * R - 27_439 * G - 5_329 * B);
   begin
      return (Y => Clamp (Y), Cb => Clamp (Cb), Cr => Clamp (Cr));
   end Convert_RGB_To_YCbCr;

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

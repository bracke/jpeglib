package body Jpeglib.Images is
   function Bytes_Per_Pixel (Format : Pixel_Format) return Byte_Count is
      pragma SPARK_Mode (On);
   begin
      case Format is
         when Gray_8 =>
            return 1;
         when Gray_Alpha_16 =>
            return 2;
         when RGB_24 | BGR_24 =>
            return 3;
         when RGBA_32 | BGRA_32 | CMYK_32 | YCCK_32 =>
            return 4;
      end case;
   end Bytes_Per_Pixel;

   function Minimum_Row_Bytes (Width : Image_Width; Format : Pixel_Format) return Byte_Count is
      pragma SPARK_Mode (On);
   begin
      return Byte_Count (Width) * Bytes_Per_Pixel (Format);
   end Minimum_Row_Bytes;

   function Descriptor_Is_Valid
     (Descriptor : Image_Descriptor;
      Storage_Length : Natural) return Boolean
   is
      pragma SPARK_Mode (On);
      Row_Bytes : constant Byte_Count :=
        Minimum_Row_Bytes (Descriptor.Width, Descriptor.Format);
      Stride_Bytes : constant Byte_Count := Byte_Count (Descriptor.Stride);
      Rows_Before_Last : constant Byte_Count := Byte_Count (Descriptor.Height - 1);
   begin
      if Stride_Bytes < Row_Bytes then
         return False;
      end if;

      if Rows_Before_Last /= 0
        and then Stride_Bytes > (Byte_Count'Last - Row_Bytes) / Rows_Before_Last
      then
         return False;
      end if;

      declare
         Last_Row_End : constant Byte_Count := Stride_Bytes * Rows_Before_Last + Row_Bytes;
      begin
         return Descriptor.Accessible_Bytes >= Last_Row_End
           and then Byte_Count (Storage_Length) >= Descriptor.Accessible_Bytes;
      end;
   end Descriptor_Is_Valid;

   function Is_Valid (View : Image_View) return Boolean is
      pragma SPARK_Mode (Off);
   begin
      return View.Storage /= null
        and then Descriptor_Is_Valid (View.Descriptor, View.Storage'Length);
   end Is_Valid;

   function Is_Valid (View : Mutable_Image_View) return Boolean is
      pragma SPARK_Mode (Off);
   begin
      return View.Storage /= null
        and then Descriptor_Is_Valid (View.Descriptor, View.Storage'Length);
   end Is_Valid;
end Jpeglib.Images;

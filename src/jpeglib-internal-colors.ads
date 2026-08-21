with Jpeglib.Images;

package Jpeglib.Internal.Colors is
   pragma Preelaborate;

   type RGB_Sample is record
      R : Byte;
      G : Byte;
      B : Byte;
   end record;

   type YCbCr_Sample is record
      Y : Byte;
      Cb : Byte;
      Cr : Byte;
   end record;

   type CMYK_Sample is record
      C : Byte;
      M : Byte;
      Y : Byte;
      K : Byte;
   end record;

   function Read_RGB
     (Input : Images.Image_View;
      Column : Natural;
      Row : Natural) return RGB_Sample;

   function Convert_RGB_To_YCbCr (Sample : RGB_Sample) return YCbCr_Sample;

   function Read_CMYK
     (Input : Images.Image_View;
      Column : Natural;
      Row : Natural) return CMYK_Sample;

   function Read_YCCK
     (Input : Images.Image_View;
      Column : Natural;
      Row : Natural) return CMYK_Sample;

   procedure Write_Gray
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      Gray : Byte;
      Alpha : Byte := Byte'Last);

   procedure Write_Gray_Alpha
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      Gray : Byte;
      Alpha : Byte);

   procedure Write_YCbCr
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      Y : Byte;
      Cb : Byte;
      Cr : Byte;
      Alpha : Byte := Byte'Last);

   procedure Write_RGB
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      R : Byte;
      G : Byte;
      B : Byte;
      Alpha : Byte := Byte'Last);

   procedure Write_CMYK
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      C : Byte;
      M : Byte;
      Y : Byte;
      K : Byte;
      Alpha : Byte := Byte'Last);

   procedure Write_YCCK
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      Y : Byte;
      Cb : Byte;
      Cr : Byte;
      K : Byte;
      Alpha : Byte := Byte'Last);
end Jpeglib.Internal.Colors;

with Jpeglib.Streams;

package Jpeglib.Images is
   pragma Preelaborate;

   type Pixel_Format is
     (Gray_8,
      Gray_Alpha_16,
      RGB_24,
      BGR_24,
      RGBA_32,
      BGRA_32,
      CMYK_32,
      YCCK_32);

   function Bytes_Per_Pixel (Format : Pixel_Format) return Byte_Count
      with SPARK_Mode => On,
           Post => Bytes_Per_Pixel'Result in 1 .. 4;

   type Image_Descriptor is record
      Width : Image_Width;
      Height : Image_Height;
      Format : Pixel_Format;
      Stride : Row_Stride;
      Accessible_Bytes : Byte_Count;
   end record;

   type Image_View is record
      Descriptor : Image_Descriptor;
      Storage : access constant Streams.Byte_Array;
   end record;

   type Mutable_Image_View is record
      Descriptor : Image_Descriptor;
      Storage : access Streams.Byte_Array;
   end record;

   function Minimum_Row_Bytes (Width : Image_Width; Format : Pixel_Format) return Byte_Count
      with SPARK_Mode => On;
   function Descriptor_Is_Valid
     (Descriptor : Image_Descriptor;
      Storage_Length : Natural) return Boolean
      with SPARK_Mode => On;
   function Is_Valid (View : Image_View) return Boolean
      with SPARK_Mode => Off;
   function Is_Valid (View : Mutable_Image_View) return Boolean
      with SPARK_Mode => Off;
end Jpeglib.Images;

with Jpeglib.Images;
with Jpeglib.Streams;

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

   type Acceleration_Profile is (Scalar_Reference, Compiler_Vectorized_SIMD);

   function Active_Acceleration return Acceleration_Profile;

   function Read_RGB
     (Input : Images.Image_View;
      Column : Natural;
      Row : Natural) return RGB_Sample;

   function Convert_RGB_To_YCbCr (Sample : RGB_Sample) return YCbCr_Sample;

   procedure Convert_RGB_Row_To_YCbCr_Planes
     (Input : Images.Image_View;
      Row : Natural;
      Y_Plane : in out Streams.Byte_Array;
      Cb_Plane : in out Streams.Byte_Array;
      Cr_Plane : in out Streams.Byte_Array;
      Output_Offset : Natural;
      Pixels : Natural;
      Written : out Natural);

   function Read_CMYK
     (Input : Images.Image_View;
      Column : Natural;
      Row : Natural) return CMYK_Sample;

   function Read_YCCK
     (Input : Images.Image_View;
      Column : Natural;
      Row : Natural) return CMYK_Sample;

   procedure Convert_CMYK_Row_To_CMYK_Planes
     (Input : Images.Image_View;
      Row : Natural;
      C_Plane : in out Streams.Byte_Array;
      M_Plane : in out Streams.Byte_Array;
      Y_Plane : in out Streams.Byte_Array;
      K_Plane : in out Streams.Byte_Array;
      Output_Offset : Natural;
      Pixels : Natural;
      YCCK : Boolean := False;
      Written : out Natural);

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

   procedure Write_Gray_Row
     (Output : in out Images.Mutable_Image_View;
      Row : Natural;
      Gray_Plane : Streams.Byte_Array;
      Input_Offset : Natural;
      Pixels : Natural;
      Alpha : Byte := Byte'Last;
      Written : out Natural);

   procedure Write_Gray_Alpha_Row
     (Output : in out Images.Mutable_Image_View;
      Row : Natural;
      Gray_Plane : Streams.Byte_Array;
      Alpha_Plane : Streams.Byte_Array;
      Input_Offset : Natural;
      Pixels : Natural;
      Written : out Natural);

   procedure Write_YCbCr
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      Y : Byte;
      Cb : Byte;
      Cr : Byte;
      Alpha : Byte := Byte'Last);

   procedure Write_YCbCr_Row
     (Output : in out Images.Mutable_Image_View;
      Row : Natural;
      Y_Plane : Streams.Byte_Array;
      Cb_Plane : Streams.Byte_Array;
      Cr_Plane : Streams.Byte_Array;
      Input_Offset : Natural;
      Pixels : Natural;
      Alpha : Byte := Byte'Last;
      Written : out Natural);

   procedure Write_RGB
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      R : Byte;
      G : Byte;
      B : Byte;
      Alpha : Byte := Byte'Last);

   procedure Write_RGB_Row
     (Output : in out Images.Mutable_Image_View;
      Row : Natural;
      R_Plane : Streams.Byte_Array;
      G_Plane : Streams.Byte_Array;
      B_Plane : Streams.Byte_Array;
      Input_Offset : Natural;
      Pixels : Natural;
      Alpha : Byte := Byte'Last;
      Written : out Natural);

   procedure Write_CMYK
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      C : Byte;
      M : Byte;
      Y : Byte;
      K : Byte;
      Alpha : Byte := Byte'Last);

   procedure Write_CMYK_Row
     (Output : in out Images.Mutable_Image_View;
      Row : Natural;
      C_Plane : Streams.Byte_Array;
      M_Plane : Streams.Byte_Array;
      Y_Plane : Streams.Byte_Array;
      K_Plane : Streams.Byte_Array;
      Input_Offset : Natural;
      Pixels : Natural;
      Alpha : Byte := Byte'Last;
      Written : out Natural);

   procedure Write_YCCK
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      Y : Byte;
      Cb : Byte;
      Cr : Byte;
      K : Byte;
      Alpha : Byte := Byte'Last);

   procedure Write_YCCK_Row
     (Output : in out Images.Mutable_Image_View;
      Row : Natural;
      Y_Plane : Streams.Byte_Array;
      Cb_Plane : Streams.Byte_Array;
      Cr_Plane : Streams.Byte_Array;
      K_Plane : Streams.Byte_Array;
      Input_Offset : Natural;
      Pixels : Natural;
      Alpha : Byte := Byte'Last;
      Written : out Natural);
end Jpeglib.Internal.Colors;

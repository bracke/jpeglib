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

   --  Active acceleration.
   --  @return Operation result.
   function Active_Acceleration return Acceleration_Profile;
   --  Active acceleration backend.
   --  @return Operation result.
   function Active_Acceleration_Backend return String;
   --  Active acceleration detail.
   --  @return Operation result.
   function Active_Acceleration_Detail return String;

   --  Read rgb.
   --  @param Input See package contract for this parameter.
   --  @param Column See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @return Operation result.
   function Read_RGB
     (Input : Images.Image_View;
      Column : Natural;
      Row : Natural) return RGB_Sample;

   --  Convert rgb to ycbcr.
   --  @param Sample See package contract for this parameter.
   --  @return Operation result.
   function Convert_RGB_To_YCbCr (Sample : RGB_Sample) return YCbCr_Sample;

   --  Convert gray alpha row to planes.
   --  @param Input See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param Gray_Plane See package contract for this parameter.
   --  @param Alpha_Plane See package contract for this parameter.
   --  @param Output_Offset See package contract for this parameter.
   --  @param Pixels See package contract for this parameter.
   --  @param Written See package contract for this parameter.
   procedure Convert_Gray_Alpha_Row_To_Planes
     (Input : Images.Image_View;
      Row : Natural;
      Gray_Plane : in out Streams.Byte_Array;
      Alpha_Plane : in out Streams.Byte_Array;
      Output_Offset : Natural;
      Pixels : Natural;
      Written : out Natural);

   --  Convert rgb row to ycbcr planes.
   --  @param Input See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param Y_Plane See package contract for this parameter.
   --  @param Cb_Plane See package contract for this parameter.
   --  @param Cr_Plane See package contract for this parameter.
   --  @param Output_Offset See package contract for this parameter.
   --  @param Pixels See package contract for this parameter.
   --  @param Written See package contract for this parameter.
   procedure Convert_RGB_Row_To_YCbCr_Planes
     (Input : Images.Image_View;
      Row : Natural;
      Y_Plane : in out Streams.Byte_Array;
      Cb_Plane : in out Streams.Byte_Array;
      Cr_Plane : in out Streams.Byte_Array;
      Output_Offset : Natural;
      Pixels : Natural;
      Written : out Natural);

   --  Read cmyk.
   --  @param Input See package contract for this parameter.
   --  @param Column See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @return Operation result.
   function Read_CMYK
     (Input : Images.Image_View;
      Column : Natural;
      Row : Natural) return CMYK_Sample;

   --  Read ycck.
   --  @param Input See package contract for this parameter.
   --  @param Column See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @return Operation result.
   function Read_YCCK
     (Input : Images.Image_View;
      Column : Natural;
      Row : Natural) return CMYK_Sample;

   --  Convert cmyk row to cmyk planes.
   --  @param Input See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param C_Plane See package contract for this parameter.
   --  @param M_Plane See package contract for this parameter.
   --  @param Y_Plane See package contract for this parameter.
   --  @param K_Plane See package contract for this parameter.
   --  @param Output_Offset See package contract for this parameter.
   --  @param Pixels See package contract for this parameter.
   --  @param YCCK See package contract for this parameter.
   --  @param Written See package contract for this parameter.
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

   --  Write gray.
   --  @param Output See package contract for this parameter.
   --  @param Column See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param Gray See package contract for this parameter.
   --  @param Alpha See package contract for this parameter.
   procedure Write_Gray
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      Gray : Byte;
      Alpha : Byte := Byte'Last);

   --  Write gray alpha.
   --  @param Output See package contract for this parameter.
   --  @param Column See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param Gray See package contract for this parameter.
   --  @param Alpha See package contract for this parameter.
   procedure Write_Gray_Alpha
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      Gray : Byte;
      Alpha : Byte);

   --  Write gray row.
   --  @param Output See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param Gray_Plane See package contract for this parameter.
   --  @param Input_Offset See package contract for this parameter.
   --  @param Pixels See package contract for this parameter.
   --  @param Alpha See package contract for this parameter.
   --  @param Written See package contract for this parameter.
   procedure Write_Gray_Row
     (Output : in out Images.Mutable_Image_View;
      Row : Natural;
      Gray_Plane : Streams.Byte_Array;
      Input_Offset : Natural;
      Pixels : Natural;
      Alpha : Byte := Byte'Last;
      Written : out Natural);

   --  Write gray alpha row.
   --  @param Output See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param Gray_Plane See package contract for this parameter.
   --  @param Alpha_Plane See package contract for this parameter.
   --  @param Input_Offset See package contract for this parameter.
   --  @param Pixels See package contract for this parameter.
   --  @param Written See package contract for this parameter.
   procedure Write_Gray_Alpha_Row
     (Output : in out Images.Mutable_Image_View;
      Row : Natural;
      Gray_Plane : Streams.Byte_Array;
      Alpha_Plane : Streams.Byte_Array;
      Input_Offset : Natural;
      Pixels : Natural;
      Written : out Natural);

   --  Write ycbcr.
   --  @param Output See package contract for this parameter.
   --  @param Column See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param Y See package contract for this parameter.
   --  @param Cb See package contract for this parameter.
   --  @param Cr See package contract for this parameter.
   --  @param Alpha See package contract for this parameter.
   procedure Write_YCbCr
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      Y : Byte;
      Cb : Byte;
      Cr : Byte;
      Alpha : Byte := Byte'Last);

   --  Write ycbcr row.
   --  @param Output See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param Y_Plane See package contract for this parameter.
   --  @param Cb_Plane See package contract for this parameter.
   --  @param Cr_Plane See package contract for this parameter.
   --  @param Input_Offset See package contract for this parameter.
   --  @param Pixels See package contract for this parameter.
   --  @param Alpha See package contract for this parameter.
   --  @param Written See package contract for this parameter.
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

   --  Write rgb.
   --  @param Output See package contract for this parameter.
   --  @param Column See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param R See package contract for this parameter.
   --  @param G See package contract for this parameter.
   --  @param B See package contract for this parameter.
   --  @param Alpha See package contract for this parameter.
   procedure Write_RGB
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      R : Byte;
      G : Byte;
      B : Byte;
      Alpha : Byte := Byte'Last);

   --  Write rgb row.
   --  @param Output See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param R_Plane See package contract for this parameter.
   --  @param G_Plane See package contract for this parameter.
   --  @param B_Plane See package contract for this parameter.
   --  @param Input_Offset See package contract for this parameter.
   --  @param Pixels See package contract for this parameter.
   --  @param Alpha See package contract for this parameter.
   --  @param Written See package contract for this parameter.
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

   --  Write cmyk.
   --  @param Output See package contract for this parameter.
   --  @param Column See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param C See package contract for this parameter.
   --  @param M See package contract for this parameter.
   --  @param Y See package contract for this parameter.
   --  @param K See package contract for this parameter.
   --  @param Alpha See package contract for this parameter.
   procedure Write_CMYK
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      C : Byte;
      M : Byte;
      Y : Byte;
      K : Byte;
      Alpha : Byte := Byte'Last);

   --  Write cmyk row.
   --  @param Output See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param C_Plane See package contract for this parameter.
   --  @param M_Plane See package contract for this parameter.
   --  @param Y_Plane See package contract for this parameter.
   --  @param K_Plane See package contract for this parameter.
   --  @param Input_Offset See package contract for this parameter.
   --  @param Pixels See package contract for this parameter.
   --  @param Alpha See package contract for this parameter.
   --  @param Written See package contract for this parameter.
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

   --  Write ycck.
   --  @param Output See package contract for this parameter.
   --  @param Column See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param Y See package contract for this parameter.
   --  @param Cb See package contract for this parameter.
   --  @param Cr See package contract for this parameter.
   --  @param K See package contract for this parameter.
   --  @param Alpha See package contract for this parameter.
   procedure Write_YCCK
     (Output : in out Images.Mutable_Image_View;
      Column : Natural;
      Row : Natural;
      Y : Byte;
      Cb : Byte;
      Cr : Byte;
      K : Byte;
      Alpha : Byte := Byte'Last);

   --  Write ycck row.
   --  @param Output See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param Y_Plane See package contract for this parameter.
   --  @param Cb_Plane See package contract for this parameter.
   --  @param Cr_Plane See package contract for this parameter.
   --  @param K_Plane See package contract for this parameter.
   --  @param Input_Offset See package contract for this parameter.
   --  @param Pixels See package contract for this parameter.
   --  @param Alpha See package contract for this parameter.
   --  @param Written See package contract for this parameter.
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

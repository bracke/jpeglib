with Jpeglib.Images;
with Jpeglib.Internal.Image_Blocks;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Encoder_Planes is
   pragma Preelaborate;

   --  Ceiling divide.
   --  @param Dividend See package contract for this parameter.
   --  @param Divisor See package contract for this parameter.
   --  @return Operation result.
   function Ceiling_Divide (Dividend, Divisor : Natural) return Natural;
   --  Plane sample count.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @return Operation result.
   function Plane_Sample_Count (Width : Image_Width; Height : Image_Height) return Byte_Count;
   --  Fits positive range.
   --  @param Count See package contract for this parameter.
   --  @return Operation result.
   function Fits_Positive_Range (Count : Byte_Count) return Boolean;

   --  Pad plane.
   --  @param Source See package contract for this parameter.
   --  @param Source_Width See package contract for this parameter.
   --  @param Source_Height See package contract for this parameter.
   --  @param Target_Width See package contract for this parameter.
   --  @param Target_Height See package contract for this parameter.
   --  @param Target See package contract for this parameter.
   --  @return Operation result.
   function Pad_Plane
     (Source : Streams.Byte_Array;
      Source_Width : Image_Width;
      Source_Height : Image_Height;
      Target_Width : Image_Width;
      Target_Height : Image_Height;
      Target : in out Streams.Byte_Array) return Results.Result;

   --  Fill cmyk planes.
   --  @param Input See package contract for this parameter.
   --  @param C_Plane See package contract for this parameter.
   --  @param M_Plane See package contract for this parameter.
   --  @param Y_Plane See package contract for this parameter.
   --  @param K_Plane See package contract for this parameter.
   --  @param YCCK See package contract for this parameter.
   --  @return Operation result.
   function Fill_CMYK_Planes
     (Input : Images.Image_View;
      C_Plane : in out Streams.Byte_Array;
      M_Plane : in out Streams.Byte_Array;
      Y_Plane : in out Streams.Byte_Array;
      K_Plane : in out Streams.Byte_Array;
      YCCK : Boolean) return Image_Blocks.Plane_Result;
end Jpeglib.Internal.Encoder_Planes;

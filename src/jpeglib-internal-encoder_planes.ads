with Jpeglib.Images;
with Jpeglib.Internal.Image_Blocks;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Encoder_Planes is
   pragma Preelaborate;

   function Ceiling_Divide (Dividend, Divisor : Natural) return Natural;
   function Plane_Sample_Count (Width : Image_Width; Height : Image_Height) return Byte_Count;
   function Fits_Positive_Range (Count : Byte_Count) return Boolean;

   function Pad_Plane
     (Source : Streams.Byte_Array;
      Source_Width : Image_Width;
      Source_Height : Image_Height;
      Target_Width : Image_Width;
      Target_Height : Image_Height;
      Target : in out Streams.Byte_Array) return Results.Result;

   function Fill_CMYK_Planes
     (Input : Images.Image_View;
      C_Plane : in out Streams.Byte_Array;
      M_Plane : in out Streams.Byte_Array;
      Y_Plane : in out Streams.Byte_Array;
      K_Plane : in out Streams.Byte_Array;
      YCCK : Boolean) return Image_Blocks.Plane_Result;
end Jpeglib.Internal.Encoder_Planes;

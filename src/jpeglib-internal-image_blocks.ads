with Jpeglib.Coefficients;
with Jpeglib.Images;
with Jpeglib.Internal.Quantization;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Image_Blocks is
   pragma Preelaborate;

   type Image_Block_Result is record
      Outcome : Results.Result := Results.Success;
      Blocks_Encoded : Block_Count := 0;
   end record;

   type Plane_Result is record
      Outcome : Results.Result := Results.Success;
      Samples_Written : Byte_Count := 0;
   end record;

   type Subsampling_Layout is record
      Chroma_Horizontal_Factor : Positive range 1 .. 4 := 1;
      Chroma_Vertical_Factor : Positive range 1 .. 4 := 1;
   end record;

   Subsampling_444 : constant Subsampling_Layout :=
     (Chroma_Horizontal_Factor => 1, Chroma_Vertical_Factor => 1);
   Subsampling_422 : constant Subsampling_Layout :=
     (Chroma_Horizontal_Factor => 2, Chroma_Vertical_Factor => 1);
   Subsampling_420 : constant Subsampling_Layout :=
     (Chroma_Horizontal_Factor => 2, Chroma_Vertical_Factor => 2);
   Subsampling_411 : constant Subsampling_Layout :=
     (Chroma_Horizontal_Factor => 4, Chroma_Vertical_Factor => 1);

   function Required_Block_Count (Descriptor : Images.Image_Descriptor) return Block_Count;

   function Required_Plane_Block_Count
     (Width : Image_Width;
      Height : Image_Height) return Block_Count;

   function Chroma_Width
     (Width : Image_Width;
      Layout : Subsampling_Layout) return Image_Width;

   function Chroma_Height
     (Height : Image_Height;
      Layout : Subsampling_Layout) return Image_Height;

   type Transform_Mode is (DC_Only, Full_Forward);

   function Encode_Gray_Blocks
     (Input : Images.Image_View;
      Table : Quantization.Quantization_Table;
      Blocks : in out Jpeglib.Coefficients.DCT_Block_Array;
      Mode : Transform_Mode := Full_Forward) return Image_Block_Result;

   function Encode_Gray_DC_Blocks
     (Input : Images.Image_View;
      Table : Quantization.Quantization_Table;
      Blocks : in out Jpeglib.Coefficients.DCT_Block_Array) return Image_Block_Result;

   function Encode_Plane_Blocks
     (Plane : Streams.Byte_Array;
      Width : Image_Width;
      Height : Image_Height;
      Table : Quantization.Quantization_Table;
      Blocks : in out Jpeglib.Coefficients.DCT_Block_Array;
      Mode : Transform_Mode := Full_Forward) return Image_Block_Result;

   function Fill_YCbCr_Planes
     (Input : Images.Image_View;
      Y_Plane : in out Streams.Byte_Array;
      Cb_Plane : in out Streams.Byte_Array;
      Cr_Plane : in out Streams.Byte_Array) return Plane_Result;

   function Fill_Gray_Alpha_Planes
     (Input : Images.Image_View;
      Gray_Plane : in out Streams.Byte_Array;
      Alpha_Plane : in out Streams.Byte_Array) return Plane_Result;

   function Downsample_Plane
     (Source : Streams.Byte_Array;
      Source_Width : Image_Width;
      Source_Height : Image_Height;
      Horizontal_Factor : Positive;
      Vertical_Factor : Positive;
      Target : in out Streams.Byte_Array) return Plane_Result
     with Pre => Horizontal_Factor <= 4 and then Vertical_Factor <= 4;

   function Subsample_Chroma_Planes
     (Cb_Source : Streams.Byte_Array;
      Cr_Source : Streams.Byte_Array;
      Source_Width : Image_Width;
      Source_Height : Image_Height;
      Layout : Subsampling_Layout;
      Cb_Target : in out Streams.Byte_Array;
      Cr_Target : in out Streams.Byte_Array) return Plane_Result;
end Jpeglib.Internal.Image_Blocks;

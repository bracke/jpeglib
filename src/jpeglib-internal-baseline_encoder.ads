with Jpeglib.Coefficients;
with Jpeglib.Images;
with Jpeglib.Internal.Image_Blocks;
with Jpeglib.Metadata;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Baseline_Encoder is
   pragma Preelaborate;

   function Encode_Gray_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   function Encode_Grayscale_Coefficients
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   function Encode_Progressive_Grayscale_Coefficients
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   function Encode_YCbCr_Coefficients
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Layouts : Jpeglib.Coefficients.Component_Block_Layout_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   function Encode_Gray_Alpha_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   function Encode_Arithmetic_Gray_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   function Encode_Arithmetic_Gray_Alpha_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   function Encode_Arithmetic_Progressive_Gray_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   function Encode_Arithmetic_Progressive_Gray_Alpha_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   function Encode_Arithmetic_YCbCr_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Layout : Image_Blocks.Subsampling_Layout := Image_Blocks.Subsampling_444;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   function Encode_Arithmetic_CMYK_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      YCCK : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   function Encode_Arithmetic_Progressive_YCbCr_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Layout : Image_Blocks.Subsampling_Layout := Image_Blocks.Subsampling_420;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   function Encode_Arithmetic_Progressive_CMYK_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      YCCK : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   function Encode_Lossless_Gray_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result;

   function Encode_Lossless_Gray_Alpha_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result;

   function Encode_Arithmetic_Lossless_Gray_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result;

   function Encode_Arithmetic_Lossless_Gray_Alpha_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result;

   function Encode_Arithmetic_Lossless_RGB_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result;

   function Encode_Arithmetic_Lossless_CMYK_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      YCCK : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result;

   function Encode_Lossless_RGB_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result;

   function Encode_Lossless_CMYK_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      YCCK : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result;

   function Encode_Progressive_Gray_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   function Encode_Progressive_Gray_Alpha_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   function Encode_YCbCr_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Layout : Image_Blocks.Subsampling_Layout := Image_Blocks.Subsampling_420;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   function Encode_CMYK_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      YCCK : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   function Encode_Progressive_YCbCr_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Layout : Image_Blocks.Subsampling_Layout := Image_Blocks.Subsampling_420;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   function Encode_Progressive_CMYK_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      YCCK : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;
end Jpeglib.Internal.Baseline_Encoder;

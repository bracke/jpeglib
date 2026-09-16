with Jpeglib.Coefficients;
with Jpeglib.Images;
with Jpeglib.Internal.Image_Blocks;
with Jpeglib.Metadata;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Baseline_Encoder is
   pragma Preelaborate;

   --  Encode gray image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Optimize_Huffman See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_Gray_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Optimize_Huffman : Boolean := False;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   --  Encode grayscale coefficients.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Optimize_Huffman See package contract for this parameter.
   --  @param Precision See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_Grayscale_Coefficients
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Optimize_Huffman : Boolean := False;
      Precision : Sample_Precision := 8;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   --  Encode progressive grayscale coefficients.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Refine See package contract for this parameter.
   --  @param Optimize_Huffman See package contract for this parameter.
   --  @param Precision See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_Progressive_Grayscale_Coefficients
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Optimize_Huffman : Boolean := False;
      Precision : Sample_Precision := 8;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   --  Encode ycbcr coefficients.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Layouts See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Optimize_Huffman See package contract for this parameter.
   --  @param Precision See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_YCbCr_Coefficients
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Layouts : Jpeglib.Coefficients.Component_Block_Layout_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Optimize_Huffman : Boolean := False;
      Precision : Sample_Precision := 8;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   --  Encode cmyk coefficients.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Optimize_Huffman See package contract for this parameter.
   --  @param Precision See package contract for this parameter.
   --  @param Adobe_YCCK See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_CMYK_Coefficients
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Optimize_Huffman : Boolean := False;
      Precision : Sample_Precision := 8;
      Adobe_YCCK : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   --  Encode progressive ycbcr coefficients.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Layouts See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Refine See package contract for this parameter.
   --  @param Optimize_Huffman See package contract for this parameter.
   --  @param Precision See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_Progressive_YCbCr_Coefficients
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Layouts : Jpeglib.Coefficients.Component_Block_Layout_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Optimize_Huffman : Boolean := False;
      Precision : Sample_Precision := 8;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   --  Encode progressive cmyk coefficients.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Refine See package contract for this parameter.
   --  @param Optimize_Huffman See package contract for this parameter.
   --  @param Precision See package contract for this parameter.
   --  @param Adobe_YCCK See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_Progressive_CMYK_Coefficients
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Optimize_Huffman : Boolean := False;
      Precision : Sample_Precision := 8;
      Adobe_YCCK : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   --  Encode gray alpha image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_Gray_Alpha_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   --  Encode arithmetic gray image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_Arithmetic_Gray_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   --  Encode arithmetic gray alpha image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_Arithmetic_Gray_Alpha_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   --  Encode arithmetic progressive gray image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Refine See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
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

   --  Encode arithmetic progressive gray alpha image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Refine See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
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

   --  Encode arithmetic ycbcr image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Layout See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
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

   --  Encode arithmetic cmyk image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param YCCK See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
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

   --  Encode arithmetic progressive ycbcr image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Layout See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Refine See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
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

   --  Encode arithmetic progressive cmyk image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Refine See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param YCCK See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
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

   --  Encode lossless gray image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Predictor See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_Lossless_Gray_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result;

   --  Encode lossless gray alpha image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Predictor See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_Lossless_Gray_Alpha_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result;

   --  Encode arithmetic lossless gray image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Predictor See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_Arithmetic_Lossless_Gray_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result;

   --  Encode arithmetic lossless gray alpha image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Predictor See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_Arithmetic_Lossless_Gray_Alpha_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result;

   --  Encode arithmetic lossless rgb image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Predictor See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_Arithmetic_Lossless_RGB_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result;

   --  Encode arithmetic lossless cmyk image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Predictor See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param YCCK See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
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

   --  Encode lossless rgb image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Predictor See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_Lossless_RGB_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result;

   --  Encode lossless cmyk image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Predictor See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param YCCK See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
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

   --  Encode progressive gray image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Refine See package contract for this parameter.
   --  @param Optimize_Huffman See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_Progressive_Gray_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Optimize_Huffman : Boolean := False;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   --  Encode progressive gray alpha image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Refine See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
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

   --  Encode ycbcr image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Layout See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Optimize_Huffman See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_YCbCr_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Layout : Image_Blocks.Subsampling_Layout := Image_Blocks.Subsampling_420;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Optimize_Huffman : Boolean := False;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   --  Encode cmyk image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param YCCK See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
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

   --  Encode progressive ycbcr image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Layout See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Refine See package contract for this parameter.
   --  @param Optimize_Huffman See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Encode_Progressive_YCbCr_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Layout : Image_Blocks.Subsampling_Layout := Image_Blocks.Subsampling_420;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Optimize_Huffman : Boolean := False;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
     with Pre => Quality <= 100;

   --  Encode progressive cmyk image.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Refine See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param YCCK See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
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

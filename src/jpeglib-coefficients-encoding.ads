with Jpeglib.Limits;
with Jpeglib.Metadata;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Coefficients.Encoding is
   pragma Preelaborate;

   --  Encode grayscale baseline.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Optimize_Huffman See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @param Encode_Limits See package contract for this parameter.
   --  @return Operation result.
   function Encode_Grayscale_Baseline
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : DCT_Block_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Optimize_Huffman : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments;
     Encode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
     with Pre => Quality <= 100;

   --  Encode grayscale twelve bit.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Optimize_Huffman See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @param Encode_Limits See package contract for this parameter.
   --  @return Operation result.
   function Encode_Grayscale_Twelve_Bit
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : DCT_Block_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Optimize_Huffman : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments;
      Encode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
     with Pre => Quality <= 100;

   --  Encode grayscale progressive.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Refine See package contract for this parameter.
   --  @param Optimize_Huffman See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @param Encode_Limits See package contract for this parameter.
   --  @return Operation result.
   function Encode_Grayscale_Progressive
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : DCT_Block_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Optimize_Huffman : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments;
      Encode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
     with Pre => Quality <= 100;

   --  Encode ycbcr baseline.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Layouts See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Optimize_Huffman See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @param Encode_Limits See package contract for this parameter.
   --  @return Operation result.
   function Encode_YCbCr_Baseline
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : DCT_Block_Array;
      Layouts : Component_Block_Layout_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Optimize_Huffman : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments;
     Encode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
     with Pre => Quality <= 100;

   --  Encode ycbcr twelve bit.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Layouts See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Optimize_Huffman See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @param Encode_Limits See package contract for this parameter.
   --  @return Operation result.
   function Encode_YCbCr_Twelve_Bit
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : DCT_Block_Array;
      Layouts : Component_Block_Layout_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Optimize_Huffman : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments;
      Encode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
     with Pre => Quality <= 100;

   --  Encode cmyk twelve bit.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Optimize_Huffman See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @param Encode_Limits See package contract for this parameter.
   --  @return Operation result.
   function Encode_CMYK_Twelve_Bit
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : DCT_Block_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Optimize_Huffman : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments;
      Encode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
     with Pre => Quality <= 100;

   --  Encode ycck twelve bit.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Optimize_Huffman See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @param Encode_Limits See package contract for this parameter.
   --  @return Operation result.
   function Encode_YCCK_Twelve_Bit
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : DCT_Block_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Optimize_Huffman : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments;
      Encode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
     with Pre => Quality <= 100;

   --  Encode ycbcr progressive.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Layouts See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Quality See package contract for this parameter.
   --  @param Refine See package contract for this parameter.
   --  @param Optimize_Huffman See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @param Encode_Limits See package contract for this parameter.
   --  @return Operation result.
   function Encode_YCbCr_Progressive
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : DCT_Block_Array;
      Layouts : Component_Block_Layout_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Optimize_Huffman : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments;
      Encode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
     with Pre => Quality <= 100;
end Jpeglib.Coefficients.Encoding;

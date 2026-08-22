with Jpeglib.Limits;
with Jpeglib.Metadata;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Coefficients.Encoding is
   pragma Preelaborate;

   function Encode_Grayscale_Baseline
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : DCT_Block_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments;
      Encode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
     with Pre => Quality <= 100;

   function Encode_Grayscale_Progressive
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : DCT_Block_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments;
      Encode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
     with Pre => Quality <= 100;

   function Encode_YCbCr_Baseline
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : DCT_Block_Array;
      Layouts : Component_Block_Layout_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments;
      Encode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
     with Pre => Quality <= 100;
end Jpeglib.Coefficients.Encoding;

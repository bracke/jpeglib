with Jpeglib.Images;
with Jpeglib.Internal.Huffman;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Encoder_Lossless_Scans is
   pragma Preelaborate;

   function Encode_Lossless_Gray_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value) return Results.Result;

   function Encode_Lossless_RGB_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value) return Results.Result;

   function Encode_Lossless_CMYK_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value;
      YCCK : Boolean) return Results.Result;

   function Encode_Lossless_Gray_Alpha_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value) return Results.Result;

   function Encode_Huffman_Zero_Residual_Scan
     (Output : in out Streams.Destination'Class;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Width : Image_Width;
      Height : Image_Height;
      Components : Component_Index) return Results.Result;

   function Encode_Arithmetic_Zero_Residual_Scan
     (Output : in out Streams.Destination'Class;
      Restart : Restart_Interval;
      Width : Image_Width;
      Height : Image_Height;
      Components : Component_Index) return Results.Result;
end Jpeglib.Internal.Encoder_Lossless_Scans;

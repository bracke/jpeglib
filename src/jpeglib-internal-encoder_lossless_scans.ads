with Jpeglib.Images;
with Jpeglib.Internal.Huffman;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Encoder_Lossless_Scans is
   pragma Preelaborate;

   --  Encode lossless gray scan.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param DC_Definition See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Predictor_Selection See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @return Operation result.
   function Encode_Lossless_Gray_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value) return Results.Result;

   --  Encode lossless rgb scan.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param DC_Definition See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Predictor_Selection See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @return Operation result.
   function Encode_Lossless_RGB_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value) return Results.Result;

   --  Encode lossless cmyk scan.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param DC_Definition See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Predictor_Selection See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @param YCCK See package contract for this parameter.
   --  @return Operation result.
   function Encode_Lossless_CMYK_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value;
      YCCK : Boolean) return Results.Result;

   --  Encode lossless gray alpha scan.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param DC_Definition See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Predictor_Selection See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @return Operation result.
   function Encode_Lossless_Gray_Alpha_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value) return Results.Result;

   --  Encode arithmetic lossless gray scan.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Predictor_Selection See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @return Operation result.
   function Encode_Arithmetic_Lossless_Gray_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value) return Results.Result;

   --  Encode arithmetic lossless rgb scan.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Predictor_Selection See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @return Operation result.
   function Encode_Arithmetic_Lossless_RGB_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value) return Results.Result;

   --  Encode arithmetic lossless cmyk scan.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Predictor_Selection See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @param YCCK See package contract for this parameter.
   --  @return Operation result.
   function Encode_Arithmetic_Lossless_CMYK_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value;
      YCCK : Boolean) return Results.Result;

   --  Encode arithmetic lossless gray alpha scan.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Predictor_Selection See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @return Operation result.
   function Encode_Arithmetic_Lossless_Gray_Alpha_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value) return Results.Result;

   --  Encode huffman zero residual scan.
   --  @param Output See package contract for this parameter.
   --  @param DC_Definition See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Components See package contract for this parameter.
   --  @return Operation result.
   function Encode_Huffman_Zero_Residual_Scan
     (Output : in out Streams.Destination'Class;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Width : Image_Width;
      Height : Image_Height;
      Components : Component_Index) return Results.Result;

   --  Encode arithmetic zero residual scan.
   --  @param Output See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Components See package contract for this parameter.
   --  @return Operation result.
   function Encode_Arithmetic_Zero_Residual_Scan
     (Output : in out Streams.Destination'Class;
      Restart : Restart_Interval;
      Width : Image_Width;
      Height : Image_Height;
      Components : Component_Index) return Results.Result;
end Jpeglib.Internal.Encoder_Lossless_Scans;

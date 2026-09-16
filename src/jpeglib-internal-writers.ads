with Jpeglib.Results;
with Jpeglib.Streams;
with Jpeglib.Internal.Arithmetic;
with Jpeglib.Internal.Huffman;
with Jpeglib.Internal.Quantization;

package Jpeglib.Internal.Writers is
   pragma Preelaborate;

   --  Write marker.
   --  @param Output See package contract for this parameter.
   --  @param Marker See package contract for this parameter.
   --  @return Operation result.
   function Write_Marker
     (Output : in out Streams.Destination'Class;
      Marker : Marker_Code) return Results.Result;

   --  Write segment.
   --  @param Output See package contract for this parameter.
   --  @param Marker See package contract for this parameter.
   --  @param Payload See package contract for this parameter.
   --  @return Operation result.
   function Write_Segment
     (Output : in out Streams.Destination'Class;
      Marker : Marker_Code;
      Payload : Streams.Byte_Array) return Results.Result;

   --  Write jfif app0.
   --  @param Output See package contract for this parameter.
   --  @return Operation result.
   function Write_JFIF_APP0 (Output : in out Streams.Destination'Class) return Results.Result;

   --  Write adobe app14.
   --  @param Output See package contract for this parameter.
   --  @param Transform See package contract for this parameter.
   --  @return Operation result.
   function Write_Adobe_APP14
     (Output : in out Streams.Destination'Class;
      Transform : Byte) return Results.Result;

   --  Write dqt.
   --  @param Output See package contract for this parameter.
   --  @param Table_Index See package contract for this parameter.
   --  @param Table See package contract for this parameter.
   --  @return Operation result.
   function Write_DQT
     (Output : in out Streams.Destination'Class;
      Table_Index : Quantization_Table_Index;
      Table : Quantization.Quantization_Table) return Results.Result;

   --  Write dht.
   --  @param Output See package contract for this parameter.
   --  @param Class See package contract for this parameter.
   --  @param Table_Index See package contract for this parameter.
   --  @param Definition See package contract for this parameter.
   --  @return Operation result.
   function Write_DHT
     (Output : in out Streams.Destination'Class;
      Class : Huffman.Huffman_Class;
      Table_Index : Huffman_Table_Index;
      Definition : Huffman.Huffman_Definition) return Results.Result;

   --  Write dac.
   --  @param Output See package contract for this parameter.
   --  @param Class See package contract for this parameter.
   --  @param Index See package contract for this parameter.
   --  @param Conditioning See package contract for this parameter.
   --  @return Operation result.
   function Write_DAC
     (Output : in out Streams.Destination'Class;
      Class : Arithmetic.Conditioning_Class;
      Index : Table_Index;
      Conditioning : Arithmetic.Conditioning_Value) return Results.Result;

   --  Write dri.
   --  @param Output See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @return Operation result.
   function Write_DRI
     (Output : in out Streams.Destination'Class;
      Restart : Restart_Interval) return Results.Result;

   --  Write sof0 grayscale.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Quantization_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF0_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   --  Write sof0 gray alpha.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Quantization_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF0_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   --  Write sof2 grayscale.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Quantization_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF2_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   --  Write sof2 gray alpha.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Quantization_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF2_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   --  Write sof9 grayscale.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Quantization_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF9_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   --  Write sof9 gray alpha.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Quantization_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF9_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   --  Write sof10 grayscale.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Quantization_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF10_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   --  Write sof10 gray alpha.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Quantization_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF10_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   --  Write sof3 grayscale.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF3_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   --  Write sof7 grayscale.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF7_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   --  Write sof3 gray alpha.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF3_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   --  Write sof7 gray alpha.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF7_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   --  Write sof11 grayscale.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF11_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   --  Write sof15 grayscale.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF15_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   --  Write sof11 gray alpha.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF11_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   --  Write sof15 gray alpha.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF15_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   --  Write sof3 rgb.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF3_RGB
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   --  Write sof7 rgb.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF7_RGB
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   --  Write sof11 rgb.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF11_RGB
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   --  Write sof15 rgb.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF15_RGB
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   --  Write sof3 cmyk.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF3_CMYK
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   --  Write sof7 cmyk.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF7_CMYK
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   --  Write sof11 cmyk.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF11_CMYK
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   --  Write sof15 cmyk.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF15_CMYK
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   --  Write sof0 ycbcr.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Luma_Horizontal_Sampling See package contract for this parameter.
   --  @param Luma_Vertical_Sampling See package contract for this parameter.
   --  @param Luma_Quantization_Table See package contract for this parameter.
   --  @param Chroma_Quantization_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF0_YCbCr
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Luma_Horizontal_Sampling : Positive;
      Luma_Vertical_Sampling : Positive;
      Luma_Quantization_Table : Quantization_Table_Index := 0;
      Chroma_Quantization_Table : Quantization_Table_Index := 1) return Results.Result;

   --  Write sof2 ycbcr.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Luma_Horizontal_Sampling See package contract for this parameter.
   --  @param Luma_Vertical_Sampling See package contract for this parameter.
   --  @param Luma_Quantization_Table See package contract for this parameter.
   --  @param Chroma_Quantization_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF2_YCbCr
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Luma_Horizontal_Sampling : Positive;
      Luma_Vertical_Sampling : Positive;
      Luma_Quantization_Table : Quantization_Table_Index := 0;
      Chroma_Quantization_Table : Quantization_Table_Index := 1) return Results.Result;

   --  Write sof9 ycbcr.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Luma_Horizontal_Sampling See package contract for this parameter.
   --  @param Luma_Vertical_Sampling See package contract for this parameter.
   --  @param Luma_Quantization_Table See package contract for this parameter.
   --  @param Chroma_Quantization_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF9_YCbCr
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Luma_Horizontal_Sampling : Positive;
      Luma_Vertical_Sampling : Positive;
      Luma_Quantization_Table : Quantization_Table_Index := 0;
      Chroma_Quantization_Table : Quantization_Table_Index := 1) return Results.Result;

   --  Write sof10 ycbcr.
   --  @param Output See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Luma_Horizontal_Sampling See package contract for this parameter.
   --  @param Luma_Vertical_Sampling See package contract for this parameter.
   --  @param Luma_Quantization_Table See package contract for this parameter.
   --  @param Chroma_Quantization_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOF10_YCbCr
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Luma_Horizontal_Sampling : Positive;
      Luma_Vertical_Sampling : Positive;
      Luma_Quantization_Table : Quantization_Table_Index := 0;
      Chroma_Quantization_Table : Quantization_Table_Index := 1) return Results.Result;

   --  Write sos grayscale.
   --  @param Output See package contract for this parameter.
   --  @param DC_Table See package contract for this parameter.
   --  @param AC_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOS_Grayscale
     (Output : in out Streams.Destination'Class;
      DC_Table : Huffman_Table_Index := 0;
      AC_Table : Huffman_Table_Index := 0) return Results.Result;

   --  Write sos gray alpha.
   --  @param Output See package contract for this parameter.
   --  @param DC_Table See package contract for this parameter.
   --  @param AC_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOS_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      DC_Table : Huffman_Table_Index := 0;
      AC_Table : Huffman_Table_Index := 0) return Results.Result;

   --  Write sos lossless grayscale.
   --  @param Output See package contract for this parameter.
   --  @param Predictor See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @param DC_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOS_Lossless_Grayscale
     (Output : in out Streams.Destination'Class;
      Predictor : Spectral_Selection_Index := 1;
      Point_Transform : Successive_Approximation_Value := 0;
      DC_Table : Huffman_Table_Index := 0) return Results.Result;

   --  Write sos lossless gray alpha.
   --  @param Output See package contract for this parameter.
   --  @param Predictor See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @param DC_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOS_Lossless_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Predictor : Spectral_Selection_Index := 1;
      Point_Transform : Successive_Approximation_Value := 0;
      DC_Table : Huffman_Table_Index := 0) return Results.Result;

   --  Write sos lossless rgb.
   --  @param Output See package contract for this parameter.
   --  @param Predictor See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @param DC_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOS_Lossless_RGB
     (Output : in out Streams.Destination'Class;
      Predictor : Spectral_Selection_Index := 1;
      Point_Transform : Successive_Approximation_Value := 0;
      DC_Table : Huffman_Table_Index := 0) return Results.Result;

   --  Write sos lossless cmyk.
   --  @param Output See package contract for this parameter.
   --  @param Predictor See package contract for this parameter.
   --  @param Point_Transform See package contract for this parameter.
   --  @param DC_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOS_Lossless_CMYK
     (Output : in out Streams.Destination'Class;
      Predictor : Spectral_Selection_Index := 1;
      Point_Transform : Successive_Approximation_Value := 0;
      DC_Table : Huffman_Table_Index := 0) return Results.Result;

   --  Write sos grayscale progressive.
   --  @param Output See package contract for this parameter.
   --  @param Spectral_Start See package contract for this parameter.
   --  @param Spectral_End See package contract for this parameter.
   --  @param Ah See package contract for this parameter.
   --  @param Al See package contract for this parameter.
   --  @param DC_Table See package contract for this parameter.
   --  @param AC_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOS_Grayscale_Progressive
     (Output : in out Streams.Destination'Class;
      Spectral_Start : Spectral_Selection_Index;
      Spectral_End : Spectral_Selection_Index;
      Ah : Successive_Approximation_Value := 0;
      Al : Successive_Approximation_Value := 0;
      DC_Table : Huffman_Table_Index := 0;
      AC_Table : Huffman_Table_Index := 0) return Results.Result;

   --  Write sos ycbcr.
   --  @param Output See package contract for this parameter.
   --  @param Luma_DC_Table See package contract for this parameter.
   --  @param Luma_AC_Table See package contract for this parameter.
   --  @param Chroma_DC_Table See package contract for this parameter.
   --  @param Chroma_AC_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOS_YCbCr
     (Output : in out Streams.Destination'Class;
      Luma_DC_Table : Huffman_Table_Index := 0;
      Luma_AC_Table : Huffman_Table_Index := 0;
      Chroma_DC_Table : Huffman_Table_Index := 1;
      Chroma_AC_Table : Huffman_Table_Index := 1) return Results.Result;

   --  Write sos ycbcr progressive dc.
   --  @param Output See package contract for this parameter.
   --  @param Spectral_Start See package contract for this parameter.
   --  @param Spectral_End See package contract for this parameter.
   --  @param Ah See package contract for this parameter.
   --  @param Al See package contract for this parameter.
   --  @param Luma_DC_Table See package contract for this parameter.
   --  @param Chroma_DC_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOS_YCbCr_Progressive_DC
     (Output : in out Streams.Destination'Class;
      Spectral_Start : Spectral_Selection_Index := 0;
      Spectral_End : Spectral_Selection_Index := 0;
      Ah : Successive_Approximation_Value := 0;
      Al : Successive_Approximation_Value := 0;
      Luma_DC_Table : Huffman_Table_Index := 0;
      Chroma_DC_Table : Huffman_Table_Index := 1) return Results.Result;

   --  Write sos component progressive.
   --  @param Output See package contract for this parameter.
   --  @param Component See package contract for this parameter.
   --  @param Spectral_Start See package contract for this parameter.
   --  @param Spectral_End See package contract for this parameter.
   --  @param Ah See package contract for this parameter.
   --  @param Al See package contract for this parameter.
   --  @param DC_Table See package contract for this parameter.
   --  @param AC_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_SOS_Component_Progressive
     (Output : in out Streams.Destination'Class;
      Component : Component_Identifier;
      Spectral_Start : Spectral_Selection_Index;
      Spectral_End : Spectral_Selection_Index;
      Ah : Successive_Approximation_Value := 0;
      Al : Successive_Approximation_Value := 0;
      DC_Table : Huffman_Table_Index := 0;
      AC_Table : Huffman_Table_Index := 0) return Results.Result;

   --  Write entropy byte.
   --  @param Output See package contract for this parameter.
   --  @param Value See package contract for this parameter.
   --  @return Operation result.
   function Write_Entropy_Byte
     (Output : in out Streams.Destination'Class;
      Value : Byte) return Results.Result;
end Jpeglib.Internal.Writers;

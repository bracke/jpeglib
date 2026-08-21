with Jpeglib.Results;
with Jpeglib.Streams;
with Jpeglib.Internal.Arithmetic;
with Jpeglib.Internal.Huffman;
with Jpeglib.Internal.Quantization;

package Jpeglib.Internal.Writers is
   pragma Preelaborate;

   function Write_Marker
     (Output : in out Streams.Destination'Class;
      Marker : Marker_Code) return Results.Result;

   function Write_Segment
     (Output : in out Streams.Destination'Class;
      Marker : Marker_Code;
      Payload : Streams.Byte_Array) return Results.Result;

   function Write_JFIF_APP0 (Output : in out Streams.Destination'Class) return Results.Result;

   function Write_Adobe_APP14
     (Output : in out Streams.Destination'Class;
      Transform : Byte) return Results.Result;

   function Write_DQT
     (Output : in out Streams.Destination'Class;
      Table_Index : Quantization_Table_Index;
      Table : Quantization.Quantization_Table) return Results.Result;

   function Write_DHT
     (Output : in out Streams.Destination'Class;
      Class : Huffman.Huffman_Class;
      Table_Index : Huffman_Table_Index;
      Definition : Huffman.Huffman_Definition) return Results.Result;

   function Write_DAC
     (Output : in out Streams.Destination'Class;
      Class : Arithmetic.Conditioning_Class;
      Index : Table_Index;
      Conditioning : Arithmetic.Conditioning_Value) return Results.Result;

   function Write_DRI
     (Output : in out Streams.Destination'Class;
      Restart : Restart_Interval) return Results.Result;

   function Write_SOF0_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   function Write_SOF0_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   function Write_SOF2_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   function Write_SOF2_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   function Write_SOF9_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   function Write_SOF9_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   function Write_SOF10_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   function Write_SOF10_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   function Write_SOF3_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   function Write_SOF7_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   function Write_SOF3_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   function Write_SOF7_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   function Write_SOF11_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   function Write_SOF15_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   function Write_SOF11_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   function Write_SOF15_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   function Write_SOF3_RGB
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   function Write_SOF7_RGB
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   function Write_SOF11_RGB
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   function Write_SOF15_RGB
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   function Write_SOF3_CMYK
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   function Write_SOF7_CMYK
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   function Write_SOF11_CMYK
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   function Write_SOF15_CMYK
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result;

   function Write_SOF0_YCbCr
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Luma_Horizontal_Sampling : Positive;
      Luma_Vertical_Sampling : Positive;
      Luma_Quantization_Table : Quantization_Table_Index := 0;
      Chroma_Quantization_Table : Quantization_Table_Index := 1) return Results.Result;

   function Write_SOF2_YCbCr
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Luma_Horizontal_Sampling : Positive;
      Luma_Vertical_Sampling : Positive;
      Luma_Quantization_Table : Quantization_Table_Index := 0;
      Chroma_Quantization_Table : Quantization_Table_Index := 1) return Results.Result;

   function Write_SOF9_YCbCr
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Luma_Horizontal_Sampling : Positive;
      Luma_Vertical_Sampling : Positive;
      Luma_Quantization_Table : Quantization_Table_Index := 0;
      Chroma_Quantization_Table : Quantization_Table_Index := 1) return Results.Result;

   function Write_SOF10_YCbCr
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Luma_Horizontal_Sampling : Positive;
      Luma_Vertical_Sampling : Positive;
      Luma_Quantization_Table : Quantization_Table_Index := 0;
      Chroma_Quantization_Table : Quantization_Table_Index := 1) return Results.Result;

   function Write_SOS_Grayscale
     (Output : in out Streams.Destination'Class;
      DC_Table : Huffman_Table_Index := 0;
      AC_Table : Huffman_Table_Index := 0) return Results.Result;

   function Write_SOS_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      DC_Table : Huffman_Table_Index := 0;
      AC_Table : Huffman_Table_Index := 0) return Results.Result;

   function Write_SOS_Lossless_Grayscale
     (Output : in out Streams.Destination'Class;
      Predictor : Spectral_Selection_Index := 1;
      Point_Transform : Successive_Approximation_Value := 0;
      DC_Table : Huffman_Table_Index := 0) return Results.Result;

   function Write_SOS_Lossless_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Predictor : Spectral_Selection_Index := 1;
      Point_Transform : Successive_Approximation_Value := 0;
      DC_Table : Huffman_Table_Index := 0) return Results.Result;

   function Write_SOS_Lossless_RGB
     (Output : in out Streams.Destination'Class;
      Predictor : Spectral_Selection_Index := 1;
      Point_Transform : Successive_Approximation_Value := 0;
      DC_Table : Huffman_Table_Index := 0) return Results.Result;

   function Write_SOS_Lossless_CMYK
     (Output : in out Streams.Destination'Class;
      Predictor : Spectral_Selection_Index := 1;
      Point_Transform : Successive_Approximation_Value := 0;
      DC_Table : Huffman_Table_Index := 0) return Results.Result;

   function Write_SOS_Grayscale_Progressive
     (Output : in out Streams.Destination'Class;
      Spectral_Start : Spectral_Selection_Index;
      Spectral_End : Spectral_Selection_Index;
      Ah : Successive_Approximation_Value := 0;
      Al : Successive_Approximation_Value := 0;
      DC_Table : Huffman_Table_Index := 0;
      AC_Table : Huffman_Table_Index := 0) return Results.Result;

   function Write_SOS_YCbCr
     (Output : in out Streams.Destination'Class;
      Luma_DC_Table : Huffman_Table_Index := 0;
      Luma_AC_Table : Huffman_Table_Index := 0;
      Chroma_DC_Table : Huffman_Table_Index := 1;
      Chroma_AC_Table : Huffman_Table_Index := 1) return Results.Result;

   function Write_SOS_YCbCr_Progressive_DC
     (Output : in out Streams.Destination'Class;
      Spectral_Start : Spectral_Selection_Index := 0;
      Spectral_End : Spectral_Selection_Index := 0;
      Ah : Successive_Approximation_Value := 0;
      Al : Successive_Approximation_Value := 0;
      Luma_DC_Table : Huffman_Table_Index := 0;
      Chroma_DC_Table : Huffman_Table_Index := 1) return Results.Result;

   function Write_SOS_Component_Progressive
     (Output : in out Streams.Destination'Class;
      Component : Component_Identifier;
      Spectral_Start : Spectral_Selection_Index;
      Spectral_End : Spectral_Selection_Index;
      Ah : Successive_Approximation_Value := 0;
      Al : Successive_Approximation_Value := 0;
      DC_Table : Huffman_Table_Index := 0;
      AC_Table : Huffman_Table_Index := 0) return Results.Result;

   function Write_Entropy_Byte
     (Output : in out Streams.Destination'Class;
      Value : Byte) return Results.Result;
end Jpeglib.Internal.Writers;

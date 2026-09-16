with Jpeglib.Images;
with Jpeglib.Internal.Huffman;
with Jpeglib.Internal.Image_Blocks;
with Jpeglib.Internal.Quantization;
with Jpeglib.Metadata;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Encoder_Headers is
   pragma Preelaborate;

   --  Write soi and metadata.
   --  @param Output See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Write_SOI_And_Metadata
     (Output : in out Streams.Destination'Class;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result;

   --  Write dhp if hierarchical.
   --  @param Output See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @return Operation result.
   function Write_DHP_If_Hierarchical
     (Output : in out Streams.Destination'Class;
      Hierarchical : Boolean) return Results.Result;

   --  Write dct sof grayscale.
   --  @param Output See package contract for this parameter.
   --  @param Marker See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Precision See package contract for this parameter.
   --  @param Quantization_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_DCT_SOF_Grayscale
     (Output : in out Streams.Destination'Class;
      Marker : Marker_Code;
      Width : Image_Width;
      Height : Image_Height;
      Precision : Sample_Precision := 8;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   --  Write dct sof gray alpha.
   --  @param Output See package contract for this parameter.
   --  @param Marker See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Quantization_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_DCT_SOF_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Marker : Marker_Code;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   --  Write dct sof ycbcr.
   --  @param Output See package contract for this parameter.
   --  @param Marker See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Luma_Horizontal_Sampling See package contract for this parameter.
   --  @param Luma_Vertical_Sampling See package contract for this parameter.
   --  @param Precision See package contract for this parameter.
   --  @param Luma_Quantization_Table See package contract for this parameter.
   --  @param Chroma_Quantization_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_DCT_SOF_YCbCr
     (Output : in out Streams.Destination'Class;
      Marker : Marker_Code;
      Width : Image_Width;
      Height : Image_Height;
      Luma_Horizontal_Sampling : Positive;
      Luma_Vertical_Sampling : Positive;
      Precision : Sample_Precision := 8;
      Luma_Quantization_Table : Quantization_Table_Index := 0;
      Chroma_Quantization_Table : Quantization_Table_Index := 1) return Results.Result;

   --  Write dct sof cmyk.
   --  @param Output See package contract for this parameter.
   --  @param Marker See package contract for this parameter.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Precision See package contract for this parameter.
   --  @param Quantization_Table See package contract for this parameter.
   --  @return Operation result.
   function Write_DCT_SOF_CMYK
     (Output : in out Streams.Destination'Class;
      Marker : Marker_Code;
      Width : Image_Width;
      Height : Image_Height;
      Precision : Sample_Precision := 8;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result;

   --  Write headers.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param DC_Definition See package contract for this parameter.
   --  @param AC_Definition See package contract for this parameter.
   --  @param Luma_Quantization See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Write_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      Luma_Quantization : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result;
   --  Write gray alpha headers.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param DC_Definition See package contract for this parameter.
   --  @param AC_Definition See package contract for this parameter.
   --  @param Luma_Quantization See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Write_Gray_Alpha_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      Luma_Quantization : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result;
   --  Write progressive headers.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param DC_Definition See package contract for this parameter.
   --  @param AC_Definition See package contract for this parameter.
   --  @param Luma_Quantization See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Write_Progressive_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      Luma_Quantization : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result;
   --  Write progressive gray alpha headers.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param DC_Definition See package contract for this parameter.
   --  @param AC_Definition See package contract for this parameter.
   --  @param Luma_Quantization See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Write_Progressive_Gray_Alpha_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      Luma_Quantization : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result;
   --  Write arithmetic headers.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Luma_Quantization See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Write_Arithmetic_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Luma_Quantization : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result;
   --  Write arithmetic gray alpha headers.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Luma_Quantization See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Write_Arithmetic_Gray_Alpha_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Luma_Quantization : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result;
   --  Write arithmetic progressive headers.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Luma_Quantization See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Write_Arithmetic_Progressive_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Luma_Quantization : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result;
   --  Write arithmetic progressive gray alpha headers.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Luma_Quantization See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Write_Arithmetic_Progressive_Gray_Alpha_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Luma_Quantization : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result;
   --  Write arithmetic color headers.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Luma_Quantization See package contract for this parameter.
   --  @param Chroma_Quantization See package contract for this parameter.
   --  @param Layout See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Write_Arithmetic_Color_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Luma_Quantization : Quantization.Quantization_Table;
      Chroma_Quantization : Quantization.Quantization_Table;
      Layout : Image_Blocks.Subsampling_Layout;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result;
   --  Write arithmetic progressive color headers.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Luma_Quantization See package contract for this parameter.
   --  @param Chroma_Quantization See package contract for this parameter.
   --  @param Layout See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Write_Arithmetic_Progressive_Color_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Luma_Quantization : Quantization.Quantization_Table;
      Chroma_Quantization : Quantization.Quantization_Table;
      Layout : Image_Blocks.Subsampling_Layout;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result;
   --  Write color headers.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Luma_DC_Definition See package contract for this parameter.
   --  @param Luma_AC_Definition See package contract for this parameter.
   --  @param Chroma_DC_Definition See package contract for this parameter.
   --  @param Chroma_AC_Definition See package contract for this parameter.
   --  @param Luma_Quantization See package contract for this parameter.
   --  @param Chroma_Quantization See package contract for this parameter.
   --  @param Layout See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Write_Color_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Luma_DC_Definition : Huffman.Huffman_Definition;
      Luma_AC_Definition : Huffman.Huffman_Definition;
      Chroma_DC_Definition : Huffman.Huffman_Definition;
      Chroma_AC_Definition : Huffman.Huffman_Definition;
      Luma_Quantization : Quantization.Quantization_Table;
      Chroma_Quantization : Quantization.Quantization_Table;
      Layout : Image_Blocks.Subsampling_Layout;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result;
   --  Write cmyk headers.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param DC_Definition See package contract for this parameter.
   --  @param AC_Definition See package contract for this parameter.
   --  @param Quantization_Table See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param YCCK See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Write_CMYK_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      Quantization_Table : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      YCCK : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result;
   --  Write arithmetic cmyk headers.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Quantization_Table See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param YCCK See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Write_Arithmetic_CMYK_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Quantization_Table : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      YCCK : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result;
   --  Write progressive cmyk headers.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param DC_Definition See package contract for this parameter.
   --  @param AC_Definition See package contract for this parameter.
   --  @param Quantization_Table See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param YCCK See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Write_Progressive_CMYK_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      Quantization_Table : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      YCCK : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result;
   --  Write arithmetic progressive cmyk headers.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Quantization_Table See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param YCCK See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Write_Arithmetic_Progressive_CMYK_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Quantization_Table : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      YCCK : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result;
   --  Write progressive color headers.
   --  @param Output See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Luma_DC_Definition See package contract for this parameter.
   --  @param Luma_AC_Definition See package contract for this parameter.
   --  @param Chroma_DC_Definition See package contract for this parameter.
   --  @param Chroma_AC_Definition See package contract for this parameter.
   --  @param Luma_Quantization See package contract for this parameter.
   --  @param Chroma_Quantization See package contract for this parameter.
   --  @param Layout See package contract for this parameter.
   --  @param Restart See package contract for this parameter.
   --  @param Differential See package contract for this parameter.
   --  @param Hierarchical See package contract for this parameter.
   --  @param Encoded_Metadata See package contract for this parameter.
   --  @return Operation result.
   function Write_Progressive_Color_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Luma_DC_Definition : Huffman.Huffman_Definition;
      Luma_AC_Definition : Huffman.Huffman_Definition;
      Chroma_DC_Definition : Huffman.Huffman_Definition;
      Chroma_AC_Definition : Huffman.Huffman_Definition;
      Luma_Quantization : Quantization.Quantization_Table;
      Chroma_Quantization : Quantization.Quantization_Table;
      Layout : Image_Blocks.Subsampling_Layout;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result;
end Jpeglib.Internal.Encoder_Headers;

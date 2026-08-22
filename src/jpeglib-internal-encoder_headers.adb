with Jpeglib.Errors;
with Jpeglib.Internal.Arithmetic;
with Jpeglib.Internal.Markers;
with Jpeglib.Internal.Writers;

package body Jpeglib.Internal.Encoder_Headers is
   use type Streams.Const_Byte_Array_Access;

   function Write_SOI_And_Metadata
     (Output : in out Streams.Destination'Class;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Writers.Write_Marker (Output, Markers.SOI);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      for Segment of Encoded_Metadata loop
         if Segment.Payload = null then
            return Results.Failure (Errors.Internal_Invariant_Failed);
         end if;

         Outcome := Writers.Write_Segment (Output, Segment.Marker, Segment.Payload.all);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end loop;

      return Results.Success;
   end Write_SOI_And_Metadata;

   function Write_DHP_If_Hierarchical
     (Output : in out Streams.Destination'Class;
      Hierarchical : Boolean) return Results.Result
   is
   begin
      if not Hierarchical then
         return Results.Success;
      end if;

      return Writers.Write_Segment (Output, Markers.DHP, [0, 0]);
   end Write_DHP_If_Hierarchical;

   function Write_DCT_SOF_Grayscale
     (Output : in out Streams.Destination'Class;
      Marker : Marker_Code;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result
   is
      Payload : Streams.Byte_Array (1 .. 9);
   begin
      if Width > 65_535 or else Height > 65_535 then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      end if;

      Payload :=
        [8,
         Byte (Natural (Height) / 256),
         Byte (Natural (Height) mod 256),
         Byte (Natural (Width) / 256),
         Byte (Natural (Width) mod 256),
         1,
         1,
         16#11#,
         Byte (Quantization_Table)];
      return Writers.Write_Segment (Output, Marker, Payload);
   end Write_DCT_SOF_Grayscale;

   function Write_DCT_SOF_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Marker : Marker_Code;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result
   is
      Payload : Streams.Byte_Array (1 .. 12);
   begin
      if Width > 65_535 or else Height > 65_535 then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      end if;

      Payload :=
        [8,
         Byte (Natural (Height) / 256),
         Byte (Natural (Height) mod 256),
         Byte (Natural (Width) / 256),
         Byte (Natural (Width) mod 256),
         2,
         1,
         16#11#,
         Byte (Quantization_Table),
         2,
         16#11#,
         Byte (Quantization_Table)];
      return Writers.Write_Segment (Output, Marker, Payload);
   end Write_DCT_SOF_Gray_Alpha;

   function Write_DCT_SOF_YCbCr
     (Output : in out Streams.Destination'Class;
      Marker : Marker_Code;
      Width : Image_Width;
      Height : Image_Height;
      Luma_Horizontal_Sampling : Positive;
      Luma_Vertical_Sampling : Positive;
      Luma_Quantization_Table : Quantization_Table_Index := 0;
      Chroma_Quantization_Table : Quantization_Table_Index := 1) return Results.Result
   is
      Payload : Streams.Byte_Array (1 .. 15);
   begin
      if Width > 65_535
        or else Height > 65_535
        or else Luma_Horizontal_Sampling not in 1 .. 4
        or else Luma_Vertical_Sampling not in 1 .. 4
      then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      end if;

      Payload :=
        [8,
         Byte (Natural (Height) / 256),
         Byte (Natural (Height) mod 256),
         Byte (Natural (Width) / 256),
         Byte (Natural (Width) mod 256),
         3,
         1,
         Byte (Luma_Horizontal_Sampling * 16 + Luma_Vertical_Sampling),
         Byte (Luma_Quantization_Table),
         2,
         16#11#,
         Byte (Chroma_Quantization_Table),
         3,
         16#11#,
         Byte (Chroma_Quantization_Table)];
      return Writers.Write_Segment (Output, Marker, Payload);
   end Write_DCT_SOF_YCbCr;

   function Write_DCT_SOF_CMYK
     (Output : in out Streams.Destination'Class;
      Marker : Marker_Code;
      Width : Image_Width;
      Height : Image_Height;
      Quantization_Table : Quantization_Table_Index := 0) return Results.Result
   is
      Payload : Streams.Byte_Array (1 .. 18);
   begin
      if Width > 65_535 or else Height > 65_535 then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      end if;

      Payload :=
        [8,
         Byte (Natural (Height) / 256),
         Byte (Natural (Height) mod 256),
         Byte (Natural (Width) / 256),
         Byte (Natural (Width) mod 256),
         4,
         Byte (Character'Pos ('C')),
         16#11#,
         Byte (Quantization_Table),
         Byte (Character'Pos ('M')),
         16#11#,
         Byte (Quantization_Table),
         Byte (Character'Pos ('Y')),
         16#11#,
         Byte (Quantization_Table),
         Byte (Character'Pos ('K')),
         16#11#,
         Byte (Quantization_Table)];
      return Writers.Write_Segment (Output, Marker, Payload);
   end Write_DCT_SOF_CMYK;

   function Write_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      Luma_Quantization : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DQT (Output, 0, Luma_Quantization);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.DC, 0, DC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.AC, 0, AC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_DCT_SOF_Grayscale
          (Output,
           Marker => (if Differential then Markers.SOF5 else Markers.SOF0),
           Width => Input.Descriptor.Width,
           Height => Input.Descriptor.Height);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Writers.Write_SOS_Grayscale (Output);
   end Write_Headers;

   function Write_Gray_Alpha_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      Luma_Quantization : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DQT (Output, 0, Luma_Quantization);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.DC, 0, DC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.AC, 0, AC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_DCT_SOF_Gray_Alpha
          (Output,
           Marker => (if Differential then Markers.SOF5 else Markers.SOF0),
           Width => Input.Descriptor.Width,
           Height => Input.Descriptor.Height);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Writers.Write_SOS_Gray_Alpha (Output);
   end Write_Gray_Alpha_Headers;

   function Write_Progressive_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      Luma_Quantization : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DQT (Output, 0, Luma_Quantization);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.DC, 0, DC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.AC, 0, AC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_DCT_SOF_Grayscale
          (Output,
           Marker => (if Differential then Markers.SOF6 else Markers.SOF2),
           Width => Input.Descriptor.Width,
           Height => Input.Descriptor.Height);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Results.Success;
   end Write_Progressive_Headers;

   function Write_Progressive_Gray_Alpha_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      Luma_Quantization : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DQT (Output, 0, Luma_Quantization);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.DC, 0, DC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.AC, 0, AC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_DCT_SOF_Gray_Alpha
          (Output,
           Marker => (if Differential then Markers.SOF6 else Markers.SOF2),
           Width => Input.Descriptor.Width,
           Height => Input.Descriptor.Height);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Results.Success;
   end Write_Progressive_Gray_Alpha_Headers;

   function Write_Arithmetic_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Luma_Quantization : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DQT (Output, 0, Luma_Quantization);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Writers.Write_DAC
          (Output,
           Arithmetic.DC,
           Index => 0,
           Conditioning => 16#5A#);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Writers.Write_DAC
          (Output,
           Arithmetic.AC,
           Index => 0,
           Conditioning => 0);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_DCT_SOF_Grayscale
          (Output,
           Marker => (if Differential then Markers.SOF13 else Markers.SOF9),
           Width => Input.Descriptor.Width,
           Height => Input.Descriptor.Height);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Writers.Write_SOS_Grayscale (Output);
   end Write_Arithmetic_Headers;

   function Write_Arithmetic_Gray_Alpha_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Luma_Quantization : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DQT (Output, 0, Luma_Quantization);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DAC (Output, Arithmetic.DC, Index => 0, Conditioning => 16#5A#);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DAC (Output, Arithmetic.AC, Index => 0, Conditioning => 0);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_DCT_SOF_Gray_Alpha
          (Output,
           Marker => (if Differential then Markers.SOF13 else Markers.SOF9),
           Width => Input.Descriptor.Width,
           Height => Input.Descriptor.Height);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Results.Success;
   end Write_Arithmetic_Gray_Alpha_Headers;

   function Write_Arithmetic_Progressive_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Luma_Quantization : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DQT (Output, 0, Luma_Quantization);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DAC (Output, Arithmetic.DC, Index => 0, Conditioning => 16#5A#);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DAC (Output, Arithmetic.AC, Index => 0, Conditioning => 0);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_DCT_SOF_Grayscale
          (Output,
           Marker => (if Differential then Markers.SOF14 else Markers.SOF10),
           Width => Input.Descriptor.Width,
           Height => Input.Descriptor.Height);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Results.Success;
   end Write_Arithmetic_Progressive_Headers;

   function Write_Arithmetic_Progressive_Gray_Alpha_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Luma_Quantization : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DQT (Output, 0, Luma_Quantization);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DAC (Output, Arithmetic.DC, Index => 0, Conditioning => 16#5A#);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DAC (Output, Arithmetic.AC, Index => 0, Conditioning => 0);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_DCT_SOF_Gray_Alpha
          (Output,
           Marker => (if Differential then Markers.SOF14 else Markers.SOF10),
           Width => Input.Descriptor.Width,
           Height => Input.Descriptor.Height);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Results.Success;
   end Write_Arithmetic_Progressive_Gray_Alpha_Headers;

   function Write_Arithmetic_Color_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Luma_Quantization : Quantization.Quantization_Table;
      Chroma_Quantization : Quantization.Quantization_Table;
      Layout : Image_Blocks.Subsampling_Layout;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DQT (Output, 0, Luma_Quantization);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DQT (Output, 1, Chroma_Quantization);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DAC (Output, Arithmetic.DC, Index => 0, Conditioning => 16#5A#);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DAC (Output, Arithmetic.AC, Index => 0, Conditioning => 0);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DAC (Output, Arithmetic.DC, Index => 1, Conditioning => 16#5A#);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DAC (Output, Arithmetic.AC, Index => 1, Conditioning => 0);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_DCT_SOF_YCbCr
          (Output,
           Marker => (if Differential then Markers.SOF13 else Markers.SOF9),
           Width => Input.Descriptor.Width,
           Height => Input.Descriptor.Height,
           Luma_Horizontal_Sampling => Layout.Chroma_Horizontal_Factor,
           Luma_Vertical_Sampling => Layout.Chroma_Vertical_Factor);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Results.Success;
   end Write_Arithmetic_Color_Headers;

   function Write_Arithmetic_Progressive_Color_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Luma_Quantization : Quantization.Quantization_Table;
      Chroma_Quantization : Quantization.Quantization_Table;
      Layout : Image_Blocks.Subsampling_Layout;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DQT (Output, 0, Luma_Quantization);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DQT (Output, 1, Chroma_Quantization);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DAC (Output, Arithmetic.DC, Index => 0, Conditioning => 16#5A#);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DAC (Output, Arithmetic.AC, Index => 0, Conditioning => 0);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DAC (Output, Arithmetic.DC, Index => 1, Conditioning => 16#5A#);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DAC (Output, Arithmetic.AC, Index => 1, Conditioning => 0);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_DCT_SOF_YCbCr
          (Output,
           Marker => (if Differential then Markers.SOF14 else Markers.SOF10),
           Width => Input.Descriptor.Width,
           Height => Input.Descriptor.Height,
           Luma_Horizontal_Sampling => Layout.Chroma_Horizontal_Factor,
           Luma_Vertical_Sampling => Layout.Chroma_Vertical_Factor);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Results.Success;
   end Write_Arithmetic_Progressive_Color_Headers;

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
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DQT (Output, 0, Luma_Quantization);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DQT (Output, 1, Chroma_Quantization);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.DC, 0, Luma_DC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.AC, 0, Luma_AC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.DC, 1, Chroma_DC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.AC, 1, Chroma_AC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_DCT_SOF_YCbCr
          (Output,
           Marker => (if Differential then Markers.SOF5 else Markers.SOF0),
           Width => Input.Descriptor.Width,
           Height => Input.Descriptor.Height,
           Luma_Horizontal_Sampling => Layout.Chroma_Horizontal_Factor,
           Luma_Vertical_Sampling => Layout.Chroma_Vertical_Factor);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Writers.Write_SOS_YCbCr (Output);
   end Write_Color_Headers;

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
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result
   is
      Outcome : Results.Result;
      SOS_Payload : constant Streams.Byte_Array :=
        [4,
         Byte (Character'Pos ('C')),
         0,
         Byte (Character'Pos ('M')),
         0,
         Byte (Character'Pos ('Y')),
         0,
         Byte (Character'Pos ('K')),
         0,
         0,
         63,
         0];
   begin
      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if YCCK then
         Outcome := Writers.Write_Adobe_APP14 (Output, Transform => 2);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      Outcome := Writers.Write_DQT (Output, 0, Quantization_Table);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.DC, 0, DC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.AC, 0, AC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_DCT_SOF_CMYK
          (Output,
           Marker => (if Differential then Markers.SOF5 else Markers.SOF0),
           Width => Input.Descriptor.Width,
           Height => Input.Descriptor.Height);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Writers.Write_Segment (Output, Markers.SOS, SOS_Payload);
   end Write_CMYK_Headers;

   function Write_Arithmetic_CMYK_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Quantization_Table : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      YCCK : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if YCCK then
         Outcome := Writers.Write_Adobe_APP14 (Output, Transform => 2);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      Outcome := Writers.Write_DQT (Output, 0, Quantization_Table);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DAC (Output, Arithmetic.DC, Index => 0, Conditioning => 16#5A#);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DAC (Output, Arithmetic.AC, Index => 0, Conditioning => 0);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_DCT_SOF_CMYK
          (Output,
           Marker => (if Differential then Markers.SOF13 else Markers.SOF9),
           Width => Input.Descriptor.Width,
           Height => Input.Descriptor.Height);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Results.Success;
   end Write_Arithmetic_CMYK_Headers;

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
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if YCCK then
         Outcome := Writers.Write_Adobe_APP14 (Output, Transform => 2);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      Outcome := Writers.Write_DQT (Output, 0, Quantization_Table);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.DC, 0, DC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.AC, 0, AC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_DCT_SOF_CMYK
          (Output,
           Marker => (if Differential then Markers.SOF6 else Markers.SOF2),
           Width => Input.Descriptor.Width,
           Height => Input.Descriptor.Height);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Results.Success;
   end Write_Progressive_CMYK_Headers;

   function Write_Arithmetic_Progressive_CMYK_Headers
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Quantization_Table : Quantization.Quantization_Table;
      Restart : Restart_Interval;
      Differential : Boolean;
      Hierarchical : Boolean;
      YCCK : Boolean;
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if YCCK then
         Outcome := Writers.Write_Adobe_APP14 (Output, Transform => 2);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      Outcome := Writers.Write_DQT (Output, 0, Quantization_Table);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DAC (Output, Arithmetic.DC, Index => 0, Conditioning => 16#5A#);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DAC (Output, Arithmetic.AC, Index => 0, Conditioning => 0);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_DCT_SOF_CMYK
        (Output,
         Marker => (if Differential then Markers.SOF14 else Markers.SOF10),
         Width => Input.Descriptor.Width,
         Height => Input.Descriptor.Height);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Results.Success;
   end Write_Arithmetic_Progressive_CMYK_Headers;

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
      Encoded_Metadata : Metadata.Encode_Segment_Array) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DQT (Output, 0, Luma_Quantization);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DQT (Output, 1, Chroma_Quantization);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.DC, 0, Luma_DC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.AC, 0, Luma_AC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.DC, 1, Chroma_DC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.AC, 1, Chroma_AC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_DCT_SOF_YCbCr
          (Output,
           Marker => (if Differential then Markers.SOF6 else Markers.SOF2),
           Width => Input.Descriptor.Width,
           Height => Input.Descriptor.Height,
           Luma_Horizontal_Sampling => Layout.Chroma_Horizontal_Factor,
           Luma_Vertical_Sampling => Layout.Chroma_Vertical_Factor);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Results.Success;
   end Write_Progressive_Color_Headers;

end Jpeglib.Internal.Encoder_Headers;

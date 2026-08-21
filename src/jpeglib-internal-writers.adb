with Jpeglib.Errors;
with Jpeglib.Internal.Markers;

package body Jpeglib.Internal.Writers is
   use type Errors.Error_Code;
   use type Arithmetic.Conditioning_Class;
   use type Huffman.Huffman_Class;
   use type Quantization.Quantization_Value;

   Max_Segment_Payload : constant Natural := 65_533;
   Zigzag_To_Natural : constant array (Coefficient_Index) of Coefficient_Index :=
     [0, 1, 8, 16, 9, 2, 3, 10,
      17, 24, 32, 25, 18, 11, 4, 5,
      12, 19, 26, 33, 40, 48, 41, 34,
      27, 20, 13, 6, 7, 14, 21, 28,
      35, 42, 49, 56, 57, 50, 43, 36,
      29, 22, 15, 23, 30, 37, 44, 51,
      58, 59, 52, 45, 38, 31, 39, 46,
      53, 60, 61, 54, 47, 55, 62, 63];

   function Write_All
     (Output : in out Streams.Destination'Class;
      Buffer : Streams.Byte_Array) return Results.Result
   is
      Written : constant Streams.Destination_Result := Streams.Write (Output, Buffer);
   begin
      if Written.Result.Code /= Errors.No_Error then
         return Results.Failure (Written.Result);
      elsif Written.Count /= Byte_Count (Buffer'Length) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      return Results.Success;
   end Write_All;

   function Write_Marker
     (Output : in out Streams.Destination'Class;
      Marker : Marker_Code) return Results.Result
   is
   begin
      return Write_All (Output, [16#FF#, Byte (Marker)]);
   end Write_Marker;

   function Write_Segment
     (Output : in out Streams.Destination'Class;
      Marker : Marker_Code;
      Payload : Streams.Byte_Array) return Results.Result
   is
      Length : Natural;
      Header : Streams.Byte_Array (1 .. 4);
      Outcome : Results.Result;
   begin
      if not Markers.Has_Length (Marker) then
         return Results.Failure (Errors.Marker_Unexpected);
      elsif Payload'Length > Max_Segment_Payload then
         return Results.Failure (Errors.Segment_Invalid_Length);
      end if;

      Length := Payload'Length + 2;
      Header :=
        [16#FF#,
         Byte (Marker),
         Byte (Length / 256),
         Byte (Length mod 256)];
      Outcome := Write_All (Output, Header);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      return Write_All (Output, Payload);
   end Write_Segment;

   function Write_JFIF_APP0 (Output : in out Streams.Destination'Class) return Results.Result is
      Payload : constant Streams.Byte_Array :=
        [16#4A#, 16#46#, 16#49#, 16#46#, 0,
         1, 1,
         0,
         0, 1,
         0, 1,
         0, 0];
   begin
      return Write_Segment (Output, Markers.APP0, Payload);
   end Write_JFIF_APP0;

   function Write_Adobe_APP14
     (Output : in out Streams.Destination'Class;
      Transform : Byte) return Results.Result
   is
      Payload : constant Streams.Byte_Array :=
        [16#41#, 16#64#, 16#6F#, 16#62#, 16#65#, 0,
         100,
         0, 0,
         0, 0,
         Transform];
   begin
      return Write_Segment (Output, Markers.APP14, Payload);
   end Write_Adobe_APP14;

   function Write_DQT
     (Output : in out Streams.Destination'Class;
      Table_Index : Quantization_Table_Index;
      Table : Quantization.Quantization_Table) return Results.Result
   is
      Payload : Streams.Byte_Array (1 .. 65);
      Natural_Index : Coefficient_Index;
   begin
      Payload (1) := Byte (Table_Index);

      for Zigzag_Index in Coefficient_Index loop
         Natural_Index := Zigzag_To_Natural (Zigzag_Index);
         if Table (Natural_Index) > 255 then
            return Results.Failure (Errors.Table_Invalid_Definition);
         end if;

         Payload (2 + Natural (Zigzag_Index)) := Byte (Table (Natural_Index));
      end loop;

      return Write_Segment (Output, Markers.DQT, Payload);
   end Write_DQT;

   function Write_DHT
     (Output : in out Streams.Destination'Class;
      Class : Huffman.Huffman_Class;
      Table_Index : Huffman_Table_Index;
      Definition : Huffman.Huffman_Definition) return Results.Result
   is
      Compile : constant Huffman.Compile_Result := Huffman.Compile (Definition);
      Total : constant Natural := Natural (Huffman.Symbol_Total (Definition));
      Counts : constant Huffman.Length_Counts := Huffman.Counts (Definition);
      Payload : Streams.Byte_Array (1 .. 17 + Total);
      Position : Natural := 18;
   begin
      if not Results.Succeeded (Compile.Outcome) then
         return Compile.Outcome;
      end if;

      Payload (1) :=
        Byte ((if Class = Huffman.DC then 0 else 16) + Natural (Table_Index));

      for Length in Huffman.Code_Length loop
         Payload (1 + Natural (Length)) := Byte (Counts (Length));
      end loop;

      for Index in 1 .. Total loop
         Payload (Position) := Huffman.Symbol (Definition, Huffman.Symbol_Index (Index));
         Position := Position + 1;
      end loop;

      return Write_Segment (Output, Markers.DHT, Payload);
   end Write_DHT;

   function Write_DAC
     (Output : in out Streams.Destination'Class;
      Class : Arithmetic.Conditioning_Class;
      Index : Table_Index;
      Conditioning : Arithmetic.Conditioning_Value) return Results.Result
   is
      Payload : constant Streams.Byte_Array :=
        [Byte
           ((if Class = Arithmetic.Conditioning_Class'Val (0) then 0 else 16)
            + Natural (Index)),
         Byte (Conditioning)];
   begin
      return Write_Segment (Output, Markers.DAC, Payload);
   end Write_DAC;

   function Write_DRI
     (Output : in out Streams.Destination'Class;
      Restart : Restart_Interval) return Results.Result
   is
      Payload : constant Streams.Byte_Array :=
        [Byte (Natural (Restart) / 256),
         Byte (Natural (Restart) mod 256)];
   begin
      return Write_Segment (Output, Markers.DRI, Payload);
   end Write_DRI;

   function Write_SOF0_Grayscale
     (Output : in out Streams.Destination'Class;
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
      return Write_Segment (Output, Markers.SOF0, Payload);
   end Write_SOF0_Grayscale;

   function Write_SOF2_Grayscale
     (Output : in out Streams.Destination'Class;
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
      return Write_Segment (Output, Markers.SOF2, Payload);
   end Write_SOF2_Grayscale;

   function Write_SOF0_Gray_Alpha
     (Output : in out Streams.Destination'Class;
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
      return Write_Segment (Output, Markers.SOF0, Payload);
   end Write_SOF0_Gray_Alpha;

   function Write_SOF2_Gray_Alpha
     (Output : in out Streams.Destination'Class;
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
      return Write_Segment (Output, Markers.SOF2, Payload);
   end Write_SOF2_Gray_Alpha;

   function Write_SOF9_Grayscale
     (Output : in out Streams.Destination'Class;
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
      return Write_Segment (Output, Markers.SOF9, Payload);
   end Write_SOF9_Grayscale;

   function Write_SOF9_Gray_Alpha
     (Output : in out Streams.Destination'Class;
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
      return Write_Segment (Output, Markers.SOF9, Payload);
   end Write_SOF9_Gray_Alpha;

   function Write_SOF10_Grayscale
     (Output : in out Streams.Destination'Class;
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
      return Write_Segment (Output, Markers.SOF10, Payload);
   end Write_SOF10_Grayscale;

   function Write_SOF10_Gray_Alpha
     (Output : in out Streams.Destination'Class;
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
      return Write_Segment (Output, Markers.SOF10, Payload);
   end Write_SOF10_Gray_Alpha;

   function Write_SOF3_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result
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
         0];
      return Write_Segment (Output, Markers.SOF3, Payload);
   end Write_SOF3_Grayscale;

   function Write_SOF7_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result
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
         0];
      return Write_Segment (Output, Markers.SOF7, Payload);
   end Write_SOF7_Grayscale;

   function Write_SOF11_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result
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
         0];
      return Write_Segment (Output, Markers.SOF11, Payload);
   end Write_SOF11_Grayscale;

   function Write_SOF15_Grayscale
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result
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
         0];
      return Write_Segment (Output, Markers.SOF15, Payload);
   end Write_SOF15_Grayscale;

   function Write_SOF3_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result
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
         0,
         2,
         16#11#,
         0];
      return Write_Segment (Output, Markers.SOF3, Payload);
   end Write_SOF3_Gray_Alpha;

   function Write_SOF7_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result
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
         0,
         2,
         16#11#,
         0];
      return Write_Segment (Output, Markers.SOF7, Payload);
   end Write_SOF7_Gray_Alpha;

   function Write_SOF11_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result
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
         0,
         2,
         16#11#,
         0];
      return Write_Segment (Output, Markers.SOF11, Payload);
   end Write_SOF11_Gray_Alpha;

   function Write_SOF15_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result
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
         0,
         2,
         16#11#,
         0];
      return Write_Segment (Output, Markers.SOF15, Payload);
   end Write_SOF15_Gray_Alpha;

   function Write_SOF3_RGB
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result
   is
      Payload : Streams.Byte_Array (1 .. 15);
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
         3,
         Byte (Character'Pos ('R')),
         16#11#,
         0,
         Byte (Character'Pos ('G')),
         16#11#,
         0,
         Byte (Character'Pos ('B')),
         16#11#,
         0];
      return Write_Segment (Output, Markers.SOF3, Payload);
   end Write_SOF3_RGB;

   function Write_SOF7_RGB
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result
   is
      Payload : Streams.Byte_Array (1 .. 15);
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
         3,
         Byte (Character'Pos ('R')),
         16#11#,
         0,
         Byte (Character'Pos ('G')),
         16#11#,
         0,
         Byte (Character'Pos ('B')),
         16#11#,
         0];
      return Write_Segment (Output, Markers.SOF7, Payload);
   end Write_SOF7_RGB;

   function Write_SOF11_RGB
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result
   is
      Payload : Streams.Byte_Array (1 .. 15);
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
         3,
         Byte (Character'Pos ('R')),
         16#11#,
         0,
         Byte (Character'Pos ('G')),
         16#11#,
         0,
         Byte (Character'Pos ('B')),
         16#11#,
         0];
      return Write_Segment (Output, Markers.SOF11, Payload);
   end Write_SOF11_RGB;

   function Write_SOF15_RGB
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result
   is
      Payload : Streams.Byte_Array (1 .. 15);
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
         3,
         Byte (Character'Pos ('R')),
         16#11#,
         0,
         Byte (Character'Pos ('G')),
         16#11#,
         0,
         Byte (Character'Pos ('B')),
         16#11#,
         0];
      return Write_Segment (Output, Markers.SOF15, Payload);
   end Write_SOF15_RGB;

   function Write_SOF_CMYK
     (Output : in out Streams.Destination'Class;
      Marker : Marker_Code;
      Width : Image_Width;
      Height : Image_Height) return Results.Result
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
         0,
         Byte (Character'Pos ('M')),
         16#11#,
         0,
         Byte (Character'Pos ('Y')),
         16#11#,
         0,
         Byte (Character'Pos ('K')),
         16#11#,
         0];
      return Write_Segment (Output, Marker, Payload);
   end Write_SOF_CMYK;

   function Write_SOF3_CMYK
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result is
   begin
      return Write_SOF_CMYK (Output, Markers.SOF3, Width, Height);
   end Write_SOF3_CMYK;

   function Write_SOF7_CMYK
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result is
   begin
      return Write_SOF_CMYK (Output, Markers.SOF7, Width, Height);
   end Write_SOF7_CMYK;

   function Write_SOF11_CMYK
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result is
   begin
      return Write_SOF_CMYK (Output, Markers.SOF11, Width, Height);
   end Write_SOF11_CMYK;

   function Write_SOF15_CMYK
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height) return Results.Result is
   begin
      return Write_SOF_CMYK (Output, Markers.SOF15, Width, Height);
   end Write_SOF15_CMYK;

   function Write_SOF0_YCbCr
     (Output : in out Streams.Destination'Class;
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
        or else Luma_Horizontal_Sampling > 4
        or else Luma_Vertical_Sampling > 4
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
      return Write_Segment (Output, Markers.SOF0, Payload);
   end Write_SOF0_YCbCr;

   function Write_SOF2_YCbCr
     (Output : in out Streams.Destination'Class;
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
        or else Luma_Horizontal_Sampling > 4
        or else Luma_Vertical_Sampling > 4
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
      return Write_Segment (Output, Markers.SOF2, Payload);
   end Write_SOF2_YCbCr;

   function Write_SOF9_YCbCr
     (Output : in out Streams.Destination'Class;
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
        or else Luma_Horizontal_Sampling > 4
        or else Luma_Vertical_Sampling > 4
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
      return Write_Segment (Output, Markers.SOF9, Payload);
   end Write_SOF9_YCbCr;

   function Write_SOF10_YCbCr
     (Output : in out Streams.Destination'Class;
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
        or else Luma_Horizontal_Sampling > 4
        or else Luma_Vertical_Sampling > 4
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
      return Write_Segment (Output, Markers.SOF10, Payload);
   end Write_SOF10_YCbCr;

   function Write_SOS_Grayscale
     (Output : in out Streams.Destination'Class;
      DC_Table : Huffman_Table_Index := 0;
      AC_Table : Huffman_Table_Index := 0) return Results.Result
   is
      Payload : constant Streams.Byte_Array :=
        [1,
         1,
         Byte (Natural (DC_Table) * 16 + Natural (AC_Table)),
         0,
         63,
         0];
   begin
      return Write_Segment (Output, Markers.SOS, Payload);
   end Write_SOS_Grayscale;

   function Write_SOS_Lossless_Grayscale
     (Output : in out Streams.Destination'Class;
      Predictor : Spectral_Selection_Index := 1;
      Point_Transform : Successive_Approximation_Value := 0;
      DC_Table : Huffman_Table_Index := 0) return Results.Result
   is
      Payload : constant Streams.Byte_Array :=
        [1,
         1,
         Byte (Natural (DC_Table) * 16),
         Byte (Predictor),
         0,
         Byte (Point_Transform)];
   begin
      return Write_Segment (Output, Markers.SOS, Payload);
   end Write_SOS_Lossless_Grayscale;

   function Write_SOS_Lossless_RGB
     (Output : in out Streams.Destination'Class;
      Predictor : Spectral_Selection_Index := 1;
      Point_Transform : Successive_Approximation_Value := 0;
      DC_Table : Huffman_Table_Index := 0) return Results.Result
   is
      Payload : constant Streams.Byte_Array :=
        [3,
         Byte (Character'Pos ('R')),
         Byte (Natural (DC_Table) * 16),
         Byte (Character'Pos ('G')),
         Byte (Natural (DC_Table) * 16),
         Byte (Character'Pos ('B')),
         Byte (Natural (DC_Table) * 16),
         Byte (Predictor),
         0,
         Byte (Point_Transform)];
   begin
      return Write_Segment (Output, Markers.SOS, Payload);
   end Write_SOS_Lossless_RGB;

   function Write_SOS_Lossless_CMYK
     (Output : in out Streams.Destination'Class;
      Predictor : Spectral_Selection_Index := 1;
      Point_Transform : Successive_Approximation_Value := 0;
      DC_Table : Huffman_Table_Index := 0) return Results.Result
   is
      Payload : constant Streams.Byte_Array :=
        [4,
         Byte (Character'Pos ('C')),
         Byte (Natural (DC_Table) * 16),
         Byte (Character'Pos ('M')),
         Byte (Natural (DC_Table) * 16),
         Byte (Character'Pos ('Y')),
         Byte (Natural (DC_Table) * 16),
         Byte (Character'Pos ('K')),
         Byte (Natural (DC_Table) * 16),
         Byte (Predictor),
         0,
         Byte (Point_Transform)];
   begin
      return Write_Segment (Output, Markers.SOS, Payload);
   end Write_SOS_Lossless_CMYK;

   function Write_SOS_Lossless_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      Predictor : Spectral_Selection_Index := 1;
      Point_Transform : Successive_Approximation_Value := 0;
      DC_Table : Huffman_Table_Index := 0) return Results.Result
   is
      Payload : constant Streams.Byte_Array :=
        [2,
         1,
         Byte (Natural (DC_Table) * 16),
         2,
         Byte (Natural (DC_Table) * 16),
         Byte (Predictor),
         0,
         Byte (Point_Transform)];
   begin
      return Write_Segment (Output, Markers.SOS, Payload);
   end Write_SOS_Lossless_Gray_Alpha;

   function Write_SOS_Gray_Alpha
     (Output : in out Streams.Destination'Class;
      DC_Table : Huffman_Table_Index := 0;
      AC_Table : Huffman_Table_Index := 0) return Results.Result
   is
      Payload : constant Streams.Byte_Array :=
        [2,
         1,
         Byte (Natural (DC_Table) * 16 + Natural (AC_Table)),
         2,
         Byte (Natural (DC_Table) * 16 + Natural (AC_Table)),
         0,
         63,
         0];
   begin
      return Write_Segment (Output, Markers.SOS, Payload);
   end Write_SOS_Gray_Alpha;

   function Write_SOS_Grayscale_Progressive
     (Output : in out Streams.Destination'Class;
      Spectral_Start : Spectral_Selection_Index;
      Spectral_End : Spectral_Selection_Index;
      Ah : Successive_Approximation_Value := 0;
      Al : Successive_Approximation_Value := 0;
      DC_Table : Huffman_Table_Index := 0;
      AC_Table : Huffman_Table_Index := 0) return Results.Result
   is
      Payload : constant Streams.Byte_Array :=
        [1,
         1,
         Byte (Natural (DC_Table) * 16 + Natural (AC_Table)),
         Byte (Spectral_Start),
         Byte (Spectral_End),
         Byte (Natural (Ah) * 16 + Natural (Al))];
   begin
      return Write_Segment (Output, Markers.SOS, Payload);
   end Write_SOS_Grayscale_Progressive;

   function Write_SOS_YCbCr
     (Output : in out Streams.Destination'Class;
      Luma_DC_Table : Huffman_Table_Index := 0;
      Luma_AC_Table : Huffman_Table_Index := 0;
      Chroma_DC_Table : Huffman_Table_Index := 1;
      Chroma_AC_Table : Huffman_Table_Index := 1) return Results.Result
   is
      Payload : constant Streams.Byte_Array :=
        [3,
         1,
         Byte (Natural (Luma_DC_Table) * 16 + Natural (Luma_AC_Table)),
         2,
         Byte (Natural (Chroma_DC_Table) * 16 + Natural (Chroma_AC_Table)),
         3,
         Byte (Natural (Chroma_DC_Table) * 16 + Natural (Chroma_AC_Table)),
         0,
         63,
         0];
   begin
      return Write_Segment (Output, Markers.SOS, Payload);
   end Write_SOS_YCbCr;

   function Write_SOS_YCbCr_Progressive_DC
     (Output : in out Streams.Destination'Class;
      Spectral_Start : Spectral_Selection_Index := 0;
      Spectral_End : Spectral_Selection_Index := 0;
      Ah : Successive_Approximation_Value := 0;
      Al : Successive_Approximation_Value := 0;
      Luma_DC_Table : Huffman_Table_Index := 0;
      Chroma_DC_Table : Huffman_Table_Index := 1) return Results.Result
   is
      Payload : constant Streams.Byte_Array :=
        [3,
         1,
         Byte (Natural (Luma_DC_Table) * 16),
         2,
         Byte (Natural (Chroma_DC_Table) * 16),
         3,
         Byte (Natural (Chroma_DC_Table) * 16),
         Byte (Spectral_Start),
         Byte (Spectral_End),
         Byte (Natural (Ah) * 16 + Natural (Al))];
   begin
      return Write_Segment (Output, Markers.SOS, Payload);
   end Write_SOS_YCbCr_Progressive_DC;

   function Write_SOS_Component_Progressive
     (Output : in out Streams.Destination'Class;
      Component : Component_Identifier;
      Spectral_Start : Spectral_Selection_Index;
      Spectral_End : Spectral_Selection_Index;
      Ah : Successive_Approximation_Value := 0;
      Al : Successive_Approximation_Value := 0;
      DC_Table : Huffman_Table_Index := 0;
      AC_Table : Huffman_Table_Index := 0) return Results.Result
   is
      Payload : constant Streams.Byte_Array :=
        [1,
         Byte (Component),
         Byte (Natural (DC_Table) * 16 + Natural (AC_Table)),
         Byte (Spectral_Start),
         Byte (Spectral_End),
         Byte (Natural (Ah) * 16 + Natural (Al))];
   begin
      return Write_Segment (Output, Markers.SOS, Payload);
   end Write_SOS_Component_Progressive;

   function Write_Entropy_Byte
     (Output : in out Streams.Destination'Class;
      Value : Byte) return Results.Result
   is
   begin
      if Value = 16#FF# then
         return Write_All (Output, [16#FF#, 0]);
      end if;

      return Write_All (Output, [1 => Value]);
   end Write_Entropy_Byte;
end Jpeglib.Internal.Writers;

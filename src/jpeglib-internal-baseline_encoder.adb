with Interfaces;

with Jpeglib.Errors;
with Jpeglib.Internal.Bit_Streams;
with Jpeglib.Internal.Coefficients;
with Jpeglib.Internal.Colors;
with Jpeglib.Internal.Arithmetic;
with Jpeglib.Internal.Huffman;
with Jpeglib.Internal.Markers;
with Jpeglib.Internal.Quantization;
with Jpeglib.Internal.Restarts;
with Jpeglib.Internal.Writers;

package body Jpeglib.Internal.Baseline_Encoder is
   use type Errors.Error_Code;
   use type Jpeglib.Coefficients.Component_Block_Layout;
   use type Jpeglib.Coefficients.Quantized_Coefficient;
   use type Arithmetic.DC_Difference;
   use type Huffman.Symbol_Frequency;
   use type Huffman.Symbol_Count;
   use type Streams.Const_Byte_Array_Access;

   Zigzag_To_Natural : constant array (Coefficient_Index) of Coefficient_Index :=
     [0, 1, 8, 16, 9, 2, 3, 10,
      17, 24, 32, 25, 18, 11, 4, 5,
      12, 19, 26, 33, 40, 48, 41, 34,
      27, 20, 13, 6, 7, 14, 21, 28,
      35, 42, 49, 56, 57, 50, 43, 36,
      29, 22, 15, 23, 30, 37, 44, 51,
      58, 59, 52, 45, 38, 31, 39, 46,
      53, 60, 61, 54, 47, 55, 62, 63];

   function Entropy_Category_For
     (Value : Jpeglib.Coefficients.Quantized_Coefficient) return Natural
   is
      Magnitude : Long_Long_Integer := Long_Long_Integer (Value);
      Limit : Long_Long_Integer := 1;
      Category : Natural := 0;
   begin
      if Magnitude < 0 then
         Magnitude := -Magnitude;
      end if;

      while Limit <= Magnitude loop
         Category := Category + 1;
         Limit := Limit * 2;
      end loop;

      return Category;
   end Entropy_Category_For;

   procedure Count_Baseline_Block_Symbols
     (DC_Frequencies : in out Huffman.Symbol_Frequencies;
      AC_Frequencies : in out Huffman.Symbol_Frequencies;
      Predictor : in out Coefficients.DC_Predictor;
      Block : Jpeglib.Coefficients.DCT_Block)
   is
      Difference : constant Jpeglib.Coefficients.Quantized_Coefficient :=
        Block (0) - Jpeglib.Coefficients.Quantized_Coefficient (Predictor);
      Run : Natural := 0;
      Value : Jpeglib.Coefficients.Quantized_Coefficient;
      Category : Natural;
      Symbol : Byte;
   begin
      Category := Entropy_Category_For (Difference);
      if Category <= Natural (Byte'Last) then
         Symbol := Byte (Category);
         DC_Frequencies (Symbol) := DC_Frequencies (Symbol) + 1;
      end if;

      Predictor := Coefficients.DC_Predictor (Block (0));

      for Zigzag_Index in Coefficient_Index range 1 .. 63 loop
         Value := Block (Zigzag_To_Natural (Zigzag_Index));
         if Value = 0 then
            Run := Run + 1;
         else
            while Run >= 16 loop
               AC_Frequencies (16#F0#) := AC_Frequencies (16#F0#) + 1;
               Run := Run - 16;
            end loop;

            Category := Entropy_Category_For (Value);
            if Category /= 0 then
               Symbol := Byte (Run * 16 + Category);
               AC_Frequencies (Symbol) := AC_Frequencies (Symbol) + 1;
            end if;
            Run := 0;
         end if;
      end loop;

      if Run > 0 then
         AC_Frequencies (0) := AC_Frequencies (0) + 1;
      end if;
   end Count_Baseline_Block_Symbols;

   procedure Optimized_Definitions_For_Blocks
     (Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      DC_Definition : out Huffman.Huffman_Definition;
      AC_Definition : out Huffman.Huffman_Definition)
   is
      DC_Frequencies : Huffman.Symbol_Frequencies := [others => 0];
      AC_Frequencies : Huffman.Symbol_Frequencies := [others => 0];
      Predictor : Coefficients.DC_Predictor := 0;
      Restart_State : Restarts.Restart_State;
      Encoded : Block_Count := 0;
   begin
      Restarts.Configure (Restart_State, Restart);
      for Block of Blocks loop
         Count_Baseline_Block_Symbols (DC_Frequencies, AC_Frequencies, Predictor, Block);
         Encoded := Encoded + 1;
         if Restart /= 0 and then Encoded /= Block_Count (Blocks'Length) then
            declare
               Outcome : constant Results.Result := Restarts.Advance_MCU (Restart_State);
            begin
               if Results.Succeeded (Outcome) and then Restarts.MCUs_Until_Restart (Restart_State) = 0 then
                  Predictor := 0;
               end if;
            end;
         end if;
      end loop;

      DC_Definition := Huffman.Optimized_Definition (DC_Frequencies);
      AC_Definition := Huffman.Optimized_Definition (AC_Frequencies);
   end Optimized_Definitions_For_Blocks;

   procedure Optimized_Definitions_For_YCbCr_Blocks
     (Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Cb_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Cr_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Y_Block_Columns : Positive;
      C_Block_Columns : Positive;
      MCU_Columns : Positive;
      MCU_Rows : Positive;
      Layout : Image_Blocks.Subsampling_Layout;
      Restart : Restart_Interval;
      Luma_DC_Definition : out Huffman.Huffman_Definition;
      Luma_AC_Definition : out Huffman.Huffman_Definition;
      Chroma_DC_Definition : out Huffman.Huffman_Definition;
      Chroma_AC_Definition : out Huffman.Huffman_Definition)
   is
      Luma_DC_Frequencies : Huffman.Symbol_Frequencies := [others => 0];
      Luma_AC_Frequencies : Huffman.Symbol_Frequencies := [others => 0];
      Chroma_DC_Frequencies : Huffman.Symbol_Frequencies := [others => 0];
      Chroma_AC_Frequencies : Huffman.Symbol_Frequencies := [others => 0];
      Y_Predictor : Coefficients.DC_Predictor := 0;
      Cb_Predictor : Coefficients.DC_Predictor := 0;
      Cr_Predictor : Coefficients.DC_Predictor := 0;
      Restart_State : Restarts.Restart_State;
   begin
      Restarts.Configure (Restart_State, Restart);
      for MCU_Row in 0 .. MCU_Rows - 1 loop
         for MCU_Column in 0 .. MCU_Columns - 1 loop
            for V in 0 .. Layout.Chroma_Vertical_Factor - 1 loop
               for H in 0 .. Layout.Chroma_Horizontal_Factor - 1 loop
                  declare
                     Block_Index : constant Positive :=
                       Y_Blocks'First
                       + (MCU_Row * Layout.Chroma_Vertical_Factor + V) * Y_Block_Columns
                       + MCU_Column * Layout.Chroma_Horizontal_Factor
                       + H;
                  begin
                     Count_Baseline_Block_Symbols
                       (Luma_DC_Frequencies,
                        Luma_AC_Frequencies,
                        Y_Predictor,
                        Y_Blocks (Block_Index));
                  end;
               end loop;
            end loop;

            declare
               Chroma_Index : constant Positive := Cb_Blocks'First + MCU_Row * C_Block_Columns + MCU_Column;
            begin
               Count_Baseline_Block_Symbols
                 (Chroma_DC_Frequencies,
                  Chroma_AC_Frequencies,
                  Cb_Predictor,
                  Cb_Blocks (Chroma_Index));
            end;

            declare
               Chroma_Index : constant Positive := Cr_Blocks'First + MCU_Row * C_Block_Columns + MCU_Column;
            begin
               Count_Baseline_Block_Symbols
                 (Chroma_DC_Frequencies,
                  Chroma_AC_Frequencies,
                  Cr_Predictor,
                  Cr_Blocks (Chroma_Index));
            end;

            if Restart /= 0 and then (MCU_Row /= MCU_Rows - 1 or else MCU_Column /= MCU_Columns - 1) then
               declare
                  Outcome : constant Results.Result := Restarts.Advance_MCU (Restart_State);
               begin
                  if Results.Succeeded (Outcome) and then Restarts.MCUs_Until_Restart (Restart_State) = 0 then
                     Y_Predictor := 0;
                     Cb_Predictor := 0;
                     Cr_Predictor := 0;
                  end if;
               end;
            end if;
         end loop;
      end loop;

      Luma_DC_Definition := Huffman.Optimized_Definition (Luma_DC_Frequencies);
      Luma_AC_Definition := Huffman.Optimized_Definition (Luma_AC_Frequencies);
      Chroma_DC_Definition := Huffman.Optimized_Definition (Chroma_DC_Frequencies);
      Chroma_AC_Definition := Huffman.Optimized_Definition (Chroma_AC_Frequencies);
   end Optimized_Definitions_For_YCbCr_Blocks;

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

   function Ceiling_Divide (Dividend, Divisor : Natural) return Natural is
   begin
      return (Dividend + Divisor - 1) / Divisor;
   end Ceiling_Divide;

   function Plane_Sample_Count (Width : Image_Width; Height : Image_Height) return Byte_Count is
   begin
      return Byte_Count (Width) * Byte_Count (Height);
   end Plane_Sample_Count;

   function Fits_Positive_Range (Count : Byte_Count) return Boolean is
   begin
      return Count > 0 and then Count <= Byte_Count (Positive'Last);
   end Fits_Positive_Range;

   function Pad_Plane
     (Source : Streams.Byte_Array;
      Source_Width : Image_Width;
      Source_Height : Image_Height;
      Target_Width : Image_Width;
      Target_Height : Image_Height;
      Target : in out Streams.Byte_Array) return Results.Result
   is
      Source_Needed : constant Byte_Count := Plane_Sample_Count (Source_Width, Source_Height);
      Target_Needed : constant Byte_Count := Plane_Sample_Count (Target_Width, Target_Height);
      Source_Row : Natural;
      Source_Column : Natural;
      Source_Index : Positive;
      Target_Index : Positive;
   begin
      if Byte_Count (Source'Length) < Source_Needed or else Byte_Count (Target'Length) < Target_Needed then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      for Row in 0 .. Natural (Target_Height) - 1 loop
         Source_Row := Natural'Min (Row, Natural (Source_Height) - 1);
         for Column in 0 .. Natural (Target_Width) - 1 loop
            Source_Column := Natural'Min (Column, Natural (Source_Width) - 1);
            Source_Index := Source'First + Source_Row * Natural (Source_Width) + Source_Column;
            Target_Index := Target'First + Row * Natural (Target_Width) + Column;
            Target (Target_Index) := Source (Source_Index);
         end loop;
      end loop;

      return Results.Success;
   end Pad_Plane;

   function Fill_CMYK_Planes
     (Input : Images.Image_View;
      C_Plane : in out Streams.Byte_Array;
      M_Plane : in out Streams.Byte_Array;
      Y_Plane : in out Streams.Byte_Array;
      K_Plane : in out Streams.Byte_Array;
      YCCK : Boolean) return Image_Blocks.Plane_Result
   is
      Needed : constant Byte_Count := Plane_Sample_Count (Input.Descriptor.Width, Input.Descriptor.Height);
      Index : Positive;
      Sample : Colors.CMYK_Sample;
   begin
      if Byte_Count (C_Plane'Length) < Needed
        or else Byte_Count (M_Plane'Length) < Needed
        or else Byte_Count (Y_Plane'Length) < Needed
        or else Byte_Count (K_Plane'Length) < Needed
      then
         return (Outcome => Results.Failure (Errors.Output_Limit_Exceeded), Samples_Written => 0);
      end if;

      for Row in 0 .. Natural (Input.Descriptor.Height) - 1 loop
         for Column in 0 .. Natural (Input.Descriptor.Width) - 1 loop
            Index := C_Plane'First + Row * Natural (Input.Descriptor.Width) + Column;
            Sample := (if YCCK then Colors.Read_YCCK (Input, Column, Row) else Colors.Read_CMYK (Input, Column, Row));
            C_Plane (Index) := Sample.C;
            M_Plane (Index) := Sample.M;
            Y_Plane (Index) := Sample.Y;
            K_Plane (Index) := Sample.K;
         end loop;
      end loop;

      return (Outcome => Results.Success, Samples_Written => Needed);
   end Fill_CMYK_Planes;

   function Encode_Blocks
     (Output : in out Streams.Destination'Class;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval) return Results.Result
   is
      DC_Compile : constant Huffman.Compile_Result :=
        Huffman.Compile (DC_Definition);
      AC_Compile : constant Huffman.Compile_Result :=
        Huffman.Compile (AC_Definition);
      Predictor : Coefficients.DC_Predictor := 0;
      Restart_State : Restarts.Restart_State;
      Encoded : Block_Count := 0;
      Outcome : Results.Result;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_Blocks : Boolean) return Results.Result
      is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Predictor := 0;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Results.Succeeded (DC_Compile.Outcome) then
         return DC_Compile.Outcome;
      elsif not Results.Succeeded (AC_Compile.Outcome) then
         return AC_Compile.Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for Block of Blocks loop
            Outcome :=
              Coefficients.Encode_Baseline_Block
                (Bits, DC_Compile.Table, AC_Compile.Table, Predictor, Block);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Outcome := Write_Restart_When_Due (Bits, Encoded /= Block_Count (Blocks'Length));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;

         return Bit_Streams.Flush_Byte (Bits);
      end;
   end Encode_Blocks;

   function Encode_YCbCr_Blocks
     (Output : in out Streams.Destination'Class;
      Luma_DC_Definition : Huffman.Huffman_Definition;
      Luma_AC_Definition : Huffman.Huffman_Definition;
      Chroma_DC_Definition : Huffman.Huffman_Definition;
      Chroma_AC_Definition : Huffman.Huffman_Definition;
      Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Cb_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Cr_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Y_Block_Columns : Positive;
      C_Block_Columns : Positive;
      MCU_Columns : Positive;
      MCU_Rows : Positive;
      Layout : Image_Blocks.Subsampling_Layout;
      Restart : Restart_Interval) return Results.Result;

   function Encode_Progressive_YCbCr_Blocks
     (Output : in out Streams.Destination'Class;
      Luma_DC_Definition : Huffman.Huffman_Definition;
      Luma_AC_Definition : Huffman.Huffman_Definition;
      Chroma_DC_Definition : Huffman.Huffman_Definition;
      Chroma_AC_Definition : Huffman.Huffman_Definition;
      Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Cb_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Cr_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Y_Block_Columns : Positive;
      C_Block_Columns : Positive;
      Y_Component_Block_Columns : Positive;
      Y_Component_Block_Rows : Positive;
      Chroma_Component_Block_Columns : Positive;
      Chroma_Component_Block_Rows : Positive;
      MCU_Columns : Positive;
      MCU_Rows : Positive;
      Layout : Image_Blocks.Subsampling_Layout;
      Restart : Restart_Interval;
      Refine : Boolean) return Results.Result;

   function Encode_Grayscale_Coefficients
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Optimize_Huffman : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      DC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Luminance_DC;
      AC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Luminance_AC;
      Luma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Luma_Table_For_Quality (Quality);
      Block_Columns : constant Natural := (Natural (Width) + 7) / 8;
      Block_Rows : constant Natural := (Natural (Height) + 7) / 8;
      Needed : constant Block_Count := Block_Count (Block_Columns * Block_Rows);
      Outcome : Results.Result;
   begin
      if Huffman.Symbol_Total (DC_Definition) = 0 or else Huffman.Symbol_Total (AC_Definition) = 0 then
         return Results.Failure (Errors.Internal_Invariant_Failed);
      elsif Block_Count (Blocks'Length) /= Needed then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      if Optimize_Huffman then
         Optimized_Definitions_For_Blocks (Blocks, Restart, DC_Definition, AC_Definition);
      end if;

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

      Outcome := Write_DCT_SOF_Grayscale (Output, Markers.SOF0, Width, Height);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      Outcome := Writers.Write_SOS_Grayscale (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Encode_Blocks (Output, DC_Definition, AC_Definition, Blocks, Restart);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Grayscale_Coefficients;

   function Encode_YCbCr_Coefficients
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Layouts : Jpeglib.Coefficients.Component_Block_Layout_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Optimize_Huffman : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      Luma_DC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Luminance_DC;
      Luma_AC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Luminance_AC;
      Chroma_DC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Chrominance_DC;
      Chroma_AC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Chrominance_AC;
      Luma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Luma_Table_For_Quality (Quality);
      Chroma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Chroma_Table_For_Quality (Quality);
      Y_Layout : Jpeglib.Coefficients.Component_Block_Layout;
      Cb_Layout : Jpeglib.Coefficients.Component_Block_Layout;
      Cr_Layout : Jpeglib.Coefficients.Component_Block_Layout;
      Layout : Image_Blocks.Subsampling_Layout;
      Y_Count : Block_Count;
      Cb_Count : Block_Count;
      Cr_Count : Block_Count;
      H_Factor : Natural;
      V_Factor : Natural;
      C_Start : Positive;
      Cr_Start : Positive;
      Outcome : Results.Result;
   begin
      if Layouts'Length /= 3
        or else Layouts'First /= 1
        or else Blocks'Length = 0
      then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      end if;

      Y_Layout := Layouts (1);
      Cb_Layout := Layouts (2);
      Cr_Layout := Layouts (3);

      if Y_Layout.Width_In_Blocks = 0
        or else Y_Layout.Height_In_Blocks = 0
        or else Cb_Layout.Width_In_Blocks = 0
        or else Cb_Layout.Height_In_Blocks = 0
        or else Cb_Layout /= Cr_Layout
        or else Y_Layout.Width_In_Blocks mod Cb_Layout.Width_In_Blocks /= 0
        or else Y_Layout.Height_In_Blocks mod Cb_Layout.Height_In_Blocks /= 0
      then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      end if;

      H_Factor := Natural (Y_Layout.Width_In_Blocks / Cb_Layout.Width_In_Blocks);
      V_Factor := Natural (Y_Layout.Height_In_Blocks / Cb_Layout.Height_In_Blocks);

      if H_Factor not in 1 | 2 | 4
        or else V_Factor not in 1 | 2
      then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      end if;

      Layout :=
        (Chroma_Horizontal_Factor => H_Factor,
         Chroma_Vertical_Factor => V_Factor);

      Y_Count := Jpeglib.Coefficients.Block_Count_For (Y_Layout);
      Cb_Count := Jpeglib.Coefficients.Block_Count_For (Cb_Layout);
      Cr_Count := Jpeglib.Coefficients.Block_Count_For (Cr_Layout);

      if Block_Count (Blocks'Length) /= Y_Count + Cb_Count + Cr_Count then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      C_Start := Blocks'First + Positive (Y_Count);
      Cr_Start := C_Start + Positive (Cb_Count);
      if Optimize_Huffman then
         Optimized_Definitions_For_YCbCr_Blocks
           (Blocks (Blocks'First .. C_Start - 1),
            Blocks (C_Start .. Cr_Start - 1),
            Blocks (Cr_Start .. Blocks'Last),
            Positive (Y_Layout.Width_In_Blocks),
            Positive (Cb_Layout.Width_In_Blocks),
            Positive (Cb_Layout.Width_In_Blocks),
            Positive (Cb_Layout.Height_In_Blocks),
            Layout,
            Restart,
            Luma_DC_Definition,
            Luma_AC_Definition,
            Chroma_DC_Definition,
            Chroma_AC_Definition);
      end if;

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

      Outcome :=
        Write_DCT_SOF_YCbCr
          (Output,
           Marker => Markers.SOF0,
           Width => Width,
           Height => Height,
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

      Outcome := Writers.Write_SOS_YCbCr (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Encode_YCbCr_Blocks
          (Output,
           Luma_DC_Definition,
           Luma_AC_Definition,
           Chroma_DC_Definition,
           Chroma_AC_Definition,
           Blocks (Blocks'First .. C_Start - 1),
           Blocks (C_Start .. Cr_Start - 1),
           Blocks (Cr_Start .. Blocks'Last),
           Positive (Y_Layout.Width_In_Blocks),
           Positive (Cb_Layout.Width_In_Blocks),
           Positive (Cb_Layout.Width_In_Blocks),
           Positive (Cb_Layout.Height_In_Blocks),
           Layout,
           Restart);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_YCbCr_Coefficients;

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
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      Luma_DC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Luminance_DC;
      Luma_AC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Luminance_AC;
      Chroma_DC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Chrominance_DC;
      Chroma_AC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Chrominance_AC;
      Luma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Luma_Table_For_Quality (Quality);
      Chroma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Chroma_Table_For_Quality (Quality);
      Y_Layout : Jpeglib.Coefficients.Component_Block_Layout;
      Cb_Layout : Jpeglib.Coefficients.Component_Block_Layout;
      Cr_Layout : Jpeglib.Coefficients.Component_Block_Layout;
      Layout : Image_Blocks.Subsampling_Layout;
      Y_Count : Block_Count;
      Cb_Count : Block_Count;
      Cr_Count : Block_Count;
      H_Factor : Natural;
      V_Factor : Natural;
      C_Start : Positive;
      Cr_Start : Positive;
      Outcome : Results.Result;
   begin
      if Layouts'Length /= 3
        or else Layouts'First /= 1
        or else Blocks'Length = 0
      then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      end if;

      Y_Layout := Layouts (1);
      Cb_Layout := Layouts (2);
      Cr_Layout := Layouts (3);

      if Y_Layout.Width_In_Blocks = 0
        or else Y_Layout.Height_In_Blocks = 0
        or else Cb_Layout.Width_In_Blocks = 0
        or else Cb_Layout.Height_In_Blocks = 0
        or else Cb_Layout /= Cr_Layout
        or else Y_Layout.Width_In_Blocks mod Cb_Layout.Width_In_Blocks /= 0
        or else Y_Layout.Height_In_Blocks mod Cb_Layout.Height_In_Blocks /= 0
      then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      end if;

      H_Factor := Natural (Y_Layout.Width_In_Blocks / Cb_Layout.Width_In_Blocks);
      V_Factor := Natural (Y_Layout.Height_In_Blocks / Cb_Layout.Height_In_Blocks);

      if H_Factor not in 1 | 2 | 4
        or else V_Factor not in 1 | 2
      then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      end if;

      Layout :=
        (Chroma_Horizontal_Factor => H_Factor,
         Chroma_Vertical_Factor => V_Factor);

      Y_Count := Jpeglib.Coefficients.Block_Count_For (Y_Layout);
      Cb_Count := Jpeglib.Coefficients.Block_Count_For (Cb_Layout);
      Cr_Count := Jpeglib.Coefficients.Block_Count_For (Cr_Layout);

      if Block_Count (Blocks'Length) /= Y_Count + Cb_Count + Cr_Count then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      C_Start := Blocks'First + Positive (Y_Count);
      Cr_Start := C_Start + Positive (Cb_Count);
      if Optimize_Huffman and then not Refine then
         Optimized_Definitions_For_YCbCr_Blocks
           (Blocks (Blocks'First .. C_Start - 1),
            Blocks (C_Start .. Cr_Start - 1),
            Blocks (Cr_Start .. Blocks'Last),
            Positive (Y_Layout.Width_In_Blocks),
            Positive (Cb_Layout.Width_In_Blocks),
            Positive (Cb_Layout.Width_In_Blocks),
            Positive (Cb_Layout.Height_In_Blocks),
            Layout,
            Restart,
            Luma_DC_Definition,
            Luma_AC_Definition,
            Chroma_DC_Definition,
            Chroma_AC_Definition);
      end if;

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

      Outcome :=
        Write_DCT_SOF_YCbCr
          (Output,
           Marker => Markers.SOF2,
           Width => Width,
           Height => Height,
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

      Outcome :=
        Encode_Progressive_YCbCr_Blocks
          (Output,
           Luma_DC_Definition,
           Luma_AC_Definition,
           Chroma_DC_Definition,
           Chroma_AC_Definition,
           Blocks (Blocks'First .. C_Start - 1),
           Blocks (C_Start .. Cr_Start - 1),
           Blocks (Cr_Start .. Blocks'Last),
           Positive (Y_Layout.Width_In_Blocks),
           Positive (Cb_Layout.Width_In_Blocks),
           Positive (Y_Layout.Width_In_Blocks),
           Positive (Y_Layout.Height_In_Blocks),
           Positive (Cb_Layout.Width_In_Blocks),
           Positive (Cb_Layout.Height_In_Blocks),
           Positive (Cb_Layout.Width_In_Blocks),
           Positive (Cb_Layout.Height_In_Blocks),
           Layout,
           Restart,
           Refine);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Progressive_YCbCr_Coefficients;

   function Arithmetic_Blocks_Supported
     (Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval) return Boolean
   is
      pragma Unreferenced (Restart);
   begin
      for Block of Blocks loop
         for Coefficient of Block loop
            if Coefficient not in -16#7FFF# .. 16#7FFF# then
               return False;
            end if;
         end loop;
      end loop;

      return True;
   end Arithmetic_Blocks_Supported;

   function Encode_Arithmetic_Blocks
     (Output : in out Streams.Destination'Class;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval) return Results.Result
   is
      Restart_State : Restarts.Restart_State;
      Encoded : Block_Count := 0;
      Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
      DC_Bins : Arithmetic.Probability_Bin_Array (0 .. 63) :=
        [others => Arithmetic.Initial_Probability_Bin];
      AC_Bins : Arithmetic.Probability_Bin_Array (0 .. 255) :=
        [others => Arithmetic.Initial_Probability_Bin];
      Fixed_Bin : Arithmetic.Probability_Bin := Arithmetic.Initial_Probability_Bin;
      DC_Context : Arithmetic.DC_Context_Index := 0;
      Predictor : Arithmetic.DC_Difference := 0;
      Outcome : Results.Result;

      function Write_Restart_When_Due (More_Blocks : Boolean) return Results.Result is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Writers.Write_Marker (Output, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Arithmetic.Reset (Arithmetic_Encoder);
            DC_Bins := [others => Arithmetic.Initial_Probability_Bin];
            AC_Bins := [others => Arithmetic.Initial_Probability_Bin];
            Fixed_Bin := Arithmetic.Initial_Probability_Bin;
            DC_Context := 0;
            Predictor := 0;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Arithmetic_Blocks_Supported (Blocks, Restart) then
         return Results.Failure (Errors.Unsupported_Feature);
      end if;

      Restarts.Configure (Restart_State, Restart);
      for Block of Blocks loop
         Outcome :=
           Arithmetic.Encode_Sequential_Block
             (Arithmetic_Encoder,
              DC_Bins,
              AC_Bins,
              Fixed_Bin,
              DC_Context,
              Predictor,
              DC_Conditioning => 16#5A#,
              AC_Conditioning => 0,
              Block => Block);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Restarts.Advance_MCU (Restart_State);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Encoded := Encoded + 1;
         Outcome := Write_Restart_When_Due (Encoded /= Block_Count (Blocks'Length));
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end loop;

      return Arithmetic.Finish (Arithmetic_Encoder);
   end Encode_Arithmetic_Blocks;

   function Encode_Arithmetic_Progressive_Fast_Preview_Blocks
     (Output : in out Streams.Destination'Class;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      Refine : Boolean;
      Grayscale : Boolean := True;
      Component : Component_Identifier := 1;
      DC_Table : Huffman_Table_Index := 0;
      AC_Table : Huffman_Table_Index := 0;
      Shared_AC_Bins : in out Arithmetic.Probability_Bin_Array;
      Refinement_Bitplanes : Successive_Approximation_Value := 1) return Results.Result
   is
      First_Al : constant Successive_Approximation_Value := (if Refine then Refinement_Bitplanes else 0);
      Outcome : Results.Result;

      function Write_SOS
        (Spectral_Start : Spectral_Selection_Index;
         Spectral_End : Spectral_Selection_Index;
         Ah : Successive_Approximation_Value := 0;
         Al : Successive_Approximation_Value := 0) return Results.Result is
      begin
         if Grayscale then
            return
              Writers.Write_SOS_Grayscale_Progressive
                (Output,
                 Spectral_Start => Spectral_Start,
                 Spectral_End => Spectral_End,
                 Ah => Ah,
                 Al => Al,
                 DC_Table => DC_Table,
                 AC_Table => AC_Table);
         else
            return
              Writers.Write_SOS_Component_Progressive
                (Output,
                 Component => Component,
                 Spectral_Start => Spectral_Start,
                 Spectral_End => Spectral_End,
                 Ah => Ah,
                 Al => Al,
                 DC_Table => DC_Table,
                 AC_Table => AC_Table);
         end if;
      end Write_SOS;

      function Encode_DC_First_Scan return Results.Result is
         Restart_State : Restarts.Restart_State;
         Encoded : Block_Count := 0;
         Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
         DC_Bins : Arithmetic.Probability_Bin_Array (0 .. 63) :=
           [others => Arithmetic.Initial_Probability_Bin];
         DC_Context : Arithmetic.DC_Context_Index := 0;
         Predictor : Arithmetic.DC_Difference := 0;

         function Write_Restart_When_Due (More_Blocks : Boolean) return Results.Result is
            Marker : Marker_Code;
            Restart_Outcome : Results.Result;
         begin
            if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
               return Results.Success;
            end if;

            Marker := Restarts.Expected_Marker (Restart_State);
            Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Writers.Write_Marker (Output, Marker);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
            if Results.Succeeded (Restart_Outcome) then
               Arithmetic.Reset (Arithmetic_Encoder);
               DC_Bins := [others => Arithmetic.Initial_Probability_Bin];
               DC_Context := 0;
               Predictor := 0;
            end if;

            return Restart_Outcome;
         end Write_Restart_When_Due;
      begin
         Restarts.Configure (Restart_State, Restart);
         for Block of Blocks loop
            declare
               Scale : constant Arithmetic.DC_Difference := 2 ** Natural (First_Al);
               DC_Value : constant Arithmetic.DC_Difference :=
                 Arithmetic.DC_Difference (Block (0)) / Scale;
               Difference : constant Arithmetic.DC_Difference :=
                 DC_Value - Predictor;
            begin
               Outcome :=
                 Arithmetic.Encode_DC_Difference
                   (Arithmetic_Encoder,
                    DC_Bins,
                    DC_Context,
                    Conditioning => 16#5A#,
                    Difference => Difference);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Predictor := DC_Value;
            end;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Outcome := Write_Restart_When_Due (Encoded /= Block_Count (Blocks'Length));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;

         return Arithmetic.Finish (Arithmetic_Encoder);
      exception
         when Constraint_Error =>
            return Results.Failure (Errors.Internal_Invariant_Failed);
      end Encode_DC_First_Scan;

      function Encode_AC_First_Scan return Results.Result is
         Restart_State : Restarts.Restart_State;
         Encoded : Block_Count := 0;
         Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
         AC_Bins : Arithmetic.Probability_Bin_Array (0 .. 255) :=
           [others => Arithmetic.Initial_Probability_Bin];
         Fixed_Bin : Arithmetic.Probability_Bin := Arithmetic.Initial_Probability_Bin;

         function Write_Restart_When_Due (More_Blocks : Boolean) return Results.Result is
            Marker : Marker_Code;
            Restart_Outcome : Results.Result;
         begin
            if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
               return Results.Success;
            end if;

            Marker := Restarts.Expected_Marker (Restart_State);
            Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Writers.Write_Marker (Output, Marker);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
            if Results.Succeeded (Restart_Outcome) then
               Arithmetic.Reset (Arithmetic_Encoder);
               AC_Bins := [others => Arithmetic.Initial_Probability_Bin];
               Fixed_Bin := Arithmetic.Initial_Probability_Bin;
               Shared_AC_Bins := [others => Arithmetic.Initial_Probability_Bin];
            end if;

            return Restart_Outcome;
         end Write_Restart_When_Due;
      begin
         Restarts.Configure (Restart_State, Restart);
         for Block of Blocks loop
            if Restart = 0 then
               Outcome :=
                 Arithmetic.Encode_Progressive_AC_First
                   (Arithmetic_Encoder,
                    Shared_AC_Bins,
                    Fixed_Bin,
                    AC_Conditioning => 0,
                    Spectral_Start => 1,
                    Spectral_End => 63,
                    Successive_Low => Natural (First_Al),
                    Block => Block);
            else
               Outcome :=
                 Arithmetic.Encode_Progressive_AC_First
                   (Arithmetic_Encoder,
                    AC_Bins,
                    Fixed_Bin,
                    AC_Conditioning => 0,
                    Spectral_Start => 1,
                    Spectral_End => 63,
                    Successive_Low => Natural (First_Al),
                    Block => Block);
            end if;
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Outcome := Write_Restart_When_Due (Encoded /= Block_Count (Blocks'Length));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;

         return Arithmetic.Finish (Arithmetic_Encoder);
      end Encode_AC_First_Scan;

      function Encode_DC_Refine_Scan
        (Al : Successive_Approximation_Value) return Results.Result
      is
         Restart_State : Restarts.Restart_State;
         Encoded : Block_Count := 0;
         Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
         Bin : Arithmetic.Probability_Bin := Arithmetic.Initial_Probability_Bin;

         function Write_Restart_When_Due (More_Blocks : Boolean) return Results.Result is
            Marker : Marker_Code;
            Restart_Outcome : Results.Result;
         begin
            if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
               return Results.Success;
            end if;

            Marker := Restarts.Expected_Marker (Restart_State);
            Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Writers.Write_Marker (Output, Marker);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
            if Results.Succeeded (Restart_Outcome) then
               Arithmetic.Reset (Arithmetic_Encoder);
               Bin := Arithmetic.Initial_Probability_Bin;
            end if;

            return Restart_Outcome;
         end Write_Restart_When_Due;
      begin
         Restarts.Configure (Restart_State, Restart);
         for Block of Blocks loop
            Outcome := Arithmetic.Encode_Progressive_DC_Refine (Arithmetic_Encoder, Bin, Block, Natural (Al));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Outcome := Write_Restart_When_Due (Encoded /= Block_Count (Blocks'Length));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;

         return Arithmetic.Finish (Arithmetic_Encoder);
      end Encode_DC_Refine_Scan;

      function Encode_AC_Refine_Scan
        (Al : Successive_Approximation_Value) return Results.Result
      is
         Restart_State : Restarts.Restart_State;
         Encoded : Block_Count := 0;
         Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
         AC_Bins : Arithmetic.Probability_Bin_Array (0 .. 255) :=
           [others => Arithmetic.Initial_Probability_Bin];
         Fixed_Bin : Arithmetic.Probability_Bin := Arithmetic.Initial_Probability_Bin;
         Decoded : Arithmetic.Decoded_Coefficient_Map (Blocks'Range, Coefficient_Index) :=
           [others => [others => False]];

         function Write_Restart_When_Due (More_Blocks : Boolean) return Results.Result is
            Marker : Marker_Code;
            Restart_Outcome : Results.Result;
         begin
            if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
               return Results.Success;
            end if;

            Marker := Restarts.Expected_Marker (Restart_State);
            Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Writers.Write_Marker (Output, Marker);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
            if Results.Succeeded (Restart_Outcome) then
               Arithmetic.Reset (Arithmetic_Encoder);
               AC_Bins := [others => Arithmetic.Initial_Probability_Bin];
               Fixed_Bin := Arithmetic.Initial_Probability_Bin;
               Shared_AC_Bins := [others => Arithmetic.Initial_Probability_Bin];
            end if;

            return Restart_Outcome;
         end Write_Restart_When_Due;
      begin
         for Block_Index in Blocks'Range loop
            for Index in Coefficient_Index range 1 .. 63 loop
               Decoded (Block_Index, Index) := Blocks (Block_Index) (Index) / (2 ** Natural (Al + 1)) /= 0;
            end loop;
         end loop;

         Restarts.Configure (Restart_State, Restart);
         for Block_Index in Blocks'Range loop
            if Restart = 0 then
               Outcome :=
                 Arithmetic.Encode_Progressive_AC_Refine
                   (Arithmetic_Encoder,
                    Shared_AC_Bins,
                    Fixed_Bin,
                    AC_Conditioning => 0,
                    Spectral_Start => 1,
                    Spectral_End => 63,
                    Successive_Low => Natural (Al),
                    Decoded_Coefficients => Decoded,
                    Block_Number => Block_Index,
                    Block => Blocks (Block_Index));
            else
               Outcome :=
                 Arithmetic.Encode_Progressive_AC_Refine
                   (Arithmetic_Encoder,
                    AC_Bins,
                    Fixed_Bin,
                    AC_Conditioning => 0,
                    Spectral_Start => 1,
                    Spectral_End => 63,
                    Successive_Low => Natural (Al),
                    Decoded_Coefficients => Decoded,
                    Block_Number => Block_Index,
                    Block => Blocks (Block_Index));
            end if;
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Outcome := Write_Restart_When_Due (Encoded /= Block_Count (Blocks'Length));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;

         return Arithmetic.Finish (Arithmetic_Encoder);
      end Encode_AC_Refine_Scan;
   begin
      Outcome :=
        Write_SOS (Spectral_Start => 0, Spectral_End => 0, Al => First_Al);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Encode_DC_First_Scan;
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_SOS (Spectral_Start => 1, Spectral_End => 63, Al => First_Al);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Encode_AC_First_Scan;
      if not Results.Succeeded (Outcome) or else not Refine then
         return Outcome;
      end if;

      for Refinement_Al in reverse Successive_Approximation_Value range 0 .. First_Al - 1 loop
         Outcome :=
           Write_SOS
             (Spectral_Start => 0,
              Spectral_End => 0,
              Ah => Refinement_Al + 1,
              Al => Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_DC_Refine_Scan (Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Write_SOS
             (Spectral_Start => 1,
              Spectral_End => 63,
              Ah => Refinement_Al + 1,
              Al => Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_AC_Refine_Scan (Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end loop;

      return Results.Success;
   end Encode_Arithmetic_Progressive_Fast_Preview_Blocks;

   function Encode_Lossless_Gray_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value) return Results.Result
   is
      DC_Compile : constant Huffman.Compile_Result := Huffman.Compile (DC_Definition);
      Restart_State : Restarts.Restart_State;
      Restart_Base : Pixel_Count := 0;
      Encoded : Pixel_Count := 0;
      Total : constant Pixel_Count :=
        Pixel_Count (Input.Descriptor.Width) * Pixel_Count (Input.Descriptor.Height);
      Outcome : Results.Result;

      function Sample (Column, Row : Natural) return Integer is
         Index : constant Positive :=
           Input.Storage'First + Row * Natural (Input.Descriptor.Stride) + Column;
      begin
         return Integer (Input.Storage (Index)) / (2 ** Natural (Point_Transform));
      end Sample;

      function Predictor (Column, Row : Natural) return Integer is
         Ra : Integer;
         Rb : Integer;
         Rc : Integer;
      begin
         if Encoded = Restart_Base then
            return 2 ** (7 - Natural (Point_Transform));
         elsif Column = 0 then
            return Sample (Column, Row - 1);
         elsif Row = 0 then
            return Sample (Column - 1, Row);
         end if;

         Ra := Sample (Column - 1, Row);
         Rb := Sample (Column, Row - 1);
         Rc := Sample (Column - 1, Row - 1);

         case Predictor_Selection is
            when 1 =>
               return Ra;
            when 2 =>
               return Rb;
            when 3 =>
               return Rc;
            when 4 =>
               return Ra + Rb - Rc;
            when 5 =>
               return Ra + (Rb - Rc) / 2;
            when 6 =>
               return Rb + (Ra - Rc) / 2;
            when 7 =>
               return (Ra + Rb) / 2;
         end case;
      end Predictor;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_Samples : Boolean) return Results.Result
      is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Samples then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Restart_Base := Encoded;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Results.Succeeded (DC_Compile.Outcome) then
         return DC_Compile.Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for Row in Natural range 0 .. Natural (Input.Descriptor.Height) - 1 loop
            for Column in Natural range 0 .. Natural (Input.Descriptor.Width) - 1 loop
               Outcome :=
                 Coefficients.Encode_Lossless_Difference
                   (Bits,
                    DC_Compile.Table,
                    Interfaces.Integer_32 (Sample (Column, Row) - Predictor (Column, Row)));
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Encoded := Encoded + 1;
               Outcome := Write_Restart_When_Due (Bits, Encoded /= Total);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;
         end loop;

         return Bit_Streams.Flush_Byte (Bits);
      end;
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Lossless_Gray_Scan;

   function Encode_Lossless_RGB_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value) return Results.Result
   is
      DC_Compile : constant Huffman.Compile_Result := Huffman.Compile (DC_Definition);
      Restart_State : Restarts.Restart_State;
      Restart_Base : Pixel_Count := 0;
      Encoded : Pixel_Count := 0;
      Total : constant Pixel_Count :=
        Pixel_Count (Input.Descriptor.Width) * Pixel_Count (Input.Descriptor.Height);
      Outcome : Results.Result;

      function RGB_At (Column, Row : Natural) return Colors.RGB_Sample is
        (Colors.Read_RGB (Input, Column, Row));

      function Component_Sample
        (Sample : Colors.RGB_Sample;
         Component : Component_Index) return Integer
      is
      begin
         case Component is
            when 1 =>
               return Integer (Sample.R) / (2 ** Natural (Point_Transform));
            when 2 =>
               return Integer (Sample.G) / (2 ** Natural (Point_Transform));
            when 3 =>
               return Integer (Sample.B) / (2 ** Natural (Point_Transform));
            when others =>
               return 0;
         end case;
      end Component_Sample;

      function Sample (Component : Component_Index; Column, Row : Natural) return Integer is
        (Component_Sample (RGB_At (Column, Row), Component));

      function Predictor (Component : Component_Index; Column, Row : Natural) return Integer is
         Ra : Integer;
         Rb : Integer;
         Rc : Integer;
      begin
         if Encoded = Restart_Base then
            return 2 ** (7 - Natural (Point_Transform));
         elsif Column = 0 then
            return Sample (Component, Column, Row - 1);
         elsif Row = 0 then
            return Sample (Component, Column - 1, Row);
         end if;

         Ra := Sample (Component, Column - 1, Row);
         Rb := Sample (Component, Column, Row - 1);
         Rc := Sample (Component, Column - 1, Row - 1);

         case Predictor_Selection is
            when 1 =>
               return Ra;
            when 2 =>
               return Rb;
            when 3 =>
               return Rc;
            when 4 =>
               return Ra + Rb - Rc;
            when 5 =>
               return Ra + (Rb - Rc) / 2;
            when 6 =>
               return Rb + (Ra - Rc) / 2;
            when 7 =>
               return (Ra + Rb) / 2;
         end case;
      end Predictor;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_Samples : Boolean) return Results.Result
      is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Samples then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Restart_Base := Encoded;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Results.Succeeded (DC_Compile.Outcome) then
         return DC_Compile.Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for Row in Natural range 0 .. Natural (Input.Descriptor.Height) - 1 loop
            for Column in Natural range 0 .. Natural (Input.Descriptor.Width) - 1 loop
               for Component in Component_Index range 1 .. 3 loop
                  Outcome :=
                    Coefficients.Encode_Lossless_Difference
                      (Bits,
                       DC_Compile.Table,
                       Interfaces.Integer_32
                         (Sample (Component, Column, Row) - Predictor (Component, Column, Row)));
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end loop;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Encoded := Encoded + 1;
               Outcome := Write_Restart_When_Due (Bits, Encoded /= Total);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;
         end loop;

         return Bit_Streams.Flush_Byte (Bits);
      end;
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Lossless_RGB_Scan;

   function Encode_Lossless_CMYK_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value;
      YCCK : Boolean) return Results.Result
   is
      DC_Compile : constant Huffman.Compile_Result := Huffman.Compile (DC_Definition);
      Restart_State : Restarts.Restart_State;
      Restart_Base : Pixel_Count := 0;
      Encoded : Pixel_Count := 0;
      Total : constant Pixel_Count :=
        Pixel_Count (Input.Descriptor.Width) * Pixel_Count (Input.Descriptor.Height);
      Outcome : Results.Result;

      function CMYK_At (Column, Row : Natural) return Colors.CMYK_Sample is
        ((if YCCK then Colors.Read_YCCK (Input, Column, Row) else Colors.Read_CMYK (Input, Column, Row)));

      function Component_Sample
        (Sample : Colors.CMYK_Sample;
         Component : Component_Index) return Integer
      is
      begin
         case Component is
            when 1 =>
               return Integer (Sample.C) / (2 ** Natural (Point_Transform));
            when 2 =>
               return Integer (Sample.M) / (2 ** Natural (Point_Transform));
            when 3 =>
               return Integer (Sample.Y) / (2 ** Natural (Point_Transform));
            when 4 =>
               return Integer (Sample.K) / (2 ** Natural (Point_Transform));
            when others =>
               return 0;
         end case;
      end Component_Sample;

      function Sample (Component : Component_Index; Column, Row : Natural) return Integer is
        (Component_Sample (CMYK_At (Column, Row), Component));

      function Predictor (Component : Component_Index; Column, Row : Natural) return Integer is
         Ra : Integer;
         Rb : Integer;
         Rc : Integer;
      begin
         if Encoded = Restart_Base then
            return 2 ** (7 - Natural (Point_Transform));
         elsif Column = 0 then
            return Sample (Component, Column, Row - 1);
         elsif Row = 0 then
            return Sample (Component, Column - 1, Row);
         end if;

         Ra := Sample (Component, Column - 1, Row);
         Rb := Sample (Component, Column, Row - 1);
         Rc := Sample (Component, Column - 1, Row - 1);

         case Predictor_Selection is
            when 1 =>
               return Ra;
            when 2 =>
               return Rb;
            when 3 =>
               return Rc;
            when 4 =>
               return Ra + Rb - Rc;
            when 5 =>
               return Ra + (Rb - Rc) / 2;
            when 6 =>
               return Rb + (Ra - Rc) / 2;
            when 7 =>
               return (Ra + Rb) / 2;
         end case;
      end Predictor;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_Samples : Boolean) return Results.Result
      is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Samples then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Restart_Base := Encoded;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Results.Succeeded (DC_Compile.Outcome) then
         return DC_Compile.Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for Row in Natural range 0 .. Natural (Input.Descriptor.Height) - 1 loop
            for Column in Natural range 0 .. Natural (Input.Descriptor.Width) - 1 loop
               for Component in Component_Index range 1 .. 4 loop
                  Outcome :=
                    Coefficients.Encode_Lossless_Difference
                      (Bits,
                       DC_Compile.Table,
                       Interfaces.Integer_32
                         (Sample (Component, Column, Row) - Predictor (Component, Column, Row)));
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end loop;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Encoded := Encoded + 1;
               Outcome := Write_Restart_When_Due (Bits, Encoded /= Total);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;
         end loop;

         return Bit_Streams.Flush_Byte (Bits);
      end;
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Lossless_CMYK_Scan;

   function Encode_Lossless_Gray_Alpha_Scan
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Predictor_Selection : Lossless_Predictor_Selection;
      Point_Transform : Lossless_Point_Transform_Value) return Results.Result
   is
      DC_Compile : constant Huffman.Compile_Result := Huffman.Compile (DC_Definition);
      Restart_State : Restarts.Restart_State;
      Restart_Base : Pixel_Count := 0;
      Encoded : Pixel_Count := 0;
      Total : constant Pixel_Count :=
        Pixel_Count (Input.Descriptor.Width) * Pixel_Count (Input.Descriptor.Height);
      Outcome : Results.Result;

      function Component_Sample
        (Component : Component_Index;
         Column : Natural;
         Row : Natural) return Integer
      is
         Base : constant Positive :=
           Input.Storage'First
           + Row * Natural (Input.Descriptor.Stride)
           + Column * 2;
      begin
         case Component is
            when 1 =>
               return Integer (Input.Storage (Base)) / (2 ** Natural (Point_Transform));
            when 2 =>
               return Integer (Input.Storage (Base + 1)) / (2 ** Natural (Point_Transform));
            when others =>
               return 0;
         end case;
      end Component_Sample;

      function Predictor (Component : Component_Index; Column, Row : Natural) return Integer is
         Ra : Integer;
         Rb : Integer;
         Rc : Integer;
      begin
         if Encoded = Restart_Base then
            return 2 ** (7 - Natural (Point_Transform));
         elsif Column = 0 then
            return Component_Sample (Component, Column, Row - 1);
         elsif Row = 0 then
            return Component_Sample (Component, Column - 1, Row);
         end if;

         Ra := Component_Sample (Component, Column - 1, Row);
         Rb := Component_Sample (Component, Column, Row - 1);
         Rc := Component_Sample (Component, Column - 1, Row - 1);

         case Predictor_Selection is
            when 1 =>
               return Ra;
            when 2 =>
               return Rb;
            when 3 =>
               return Rc;
            when 4 =>
               return Ra + Rb - Rc;
            when 5 =>
               return Ra + (Rb - Rc) / 2;
            when 6 =>
               return Rb + (Ra - Rc) / 2;
            when 7 =>
               return (Ra + Rb) / 2;
         end case;
      end Predictor;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_Samples : Boolean) return Results.Result
      is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Samples then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Restart_Base := Encoded;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Results.Succeeded (DC_Compile.Outcome) then
         return DC_Compile.Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for Row in Natural range 0 .. Natural (Input.Descriptor.Height) - 1 loop
            for Column in Natural range 0 .. Natural (Input.Descriptor.Width) - 1 loop
               for Component in Component_Index range 1 .. 2 loop
                  Outcome :=
                    Coefficients.Encode_Lossless_Difference
                      (Bits,
                       DC_Compile.Table,
                       Interfaces.Integer_32
                         (Component_Sample (Component, Column, Row) - Predictor (Component, Column, Row)));
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end loop;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Encoded := Encoded + 1;
               Outcome := Write_Restart_When_Due (Bits, Encoded /= Total);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;
         end loop;

         return Bit_Streams.Flush_Byte (Bits);
      end;
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Lossless_Gray_Alpha_Scan;

   function Encode_Huffman_Zero_Residual_Scan
     (Output : in out Streams.Destination'Class;
      DC_Definition : Huffman.Huffman_Definition;
      Restart : Restart_Interval;
      Width : Image_Width;
      Height : Image_Height;
      Components : Component_Index) return Results.Result
   is
      DC_Compile : constant Huffman.Compile_Result := Huffman.Compile (DC_Definition);
      Restart_State : Restarts.Restart_State;
      Encoded : Pixel_Count := 0;
      Total : constant Pixel_Count := Pixel_Count (Width) * Pixel_Count (Height);
      Outcome : Results.Result;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_Samples : Boolean) return Results.Result
      is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Samples then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         return Restarts.Accept_Restart (Restart_State, Marker, 0);
      end Write_Restart_When_Due;
   begin
      if not Results.Succeeded (DC_Compile.Outcome) then
         return DC_Compile.Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for Row in Image_Height range 1 .. Height loop
            pragma Unreferenced (Row);
            for Column in Image_Width range 1 .. Width loop
               pragma Unreferenced (Column);
               for Component in Component_Index range 1 .. Components loop
                  pragma Unreferenced (Component);
                  Outcome :=
                    Coefficients.Encode_Lossless_Difference
                      (Bits, DC_Compile.Table, Interfaces.Integer_32 (0));
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end loop;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Encoded := Encoded + 1;
               Outcome := Write_Restart_When_Due (Bits, Encoded /= Total);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;
         end loop;

         return Bit_Streams.Flush_Byte (Bits);
      end;
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Huffman_Zero_Residual_Scan;

   function Encode_Arithmetic_Zero_Residual_Scan
     (Output : in out Streams.Destination'Class;
      Restart : Restart_Interval;
      Width : Image_Width;
      Height : Image_Height;
      Components : Component_Index) return Results.Result
   is
      type DC_Bin_By_Component is array (Component_Index range 1 .. Components) of
        Arithmetic.Probability_Bin_Array (0 .. 63);
      Restart_State : Restarts.Restart_State;
      Encoded : Pixel_Count := 0;
      Total : constant Pixel_Count := Pixel_Count (Width) * Pixel_Count (Height);
      Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
      DC_Bins : DC_Bin_By_Component := [others => [others => Arithmetic.Initial_Probability_Bin]];
      DC_Contexts : Arithmetic.DC_Context_Array := [others => 0];
      Outcome : Results.Result;

      function Write_Restart_When_Due (More_Samples : Boolean) return Results.Result is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Samples then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Writers.Write_Marker (Output, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Arithmetic.Reset (Arithmetic_Encoder);
            DC_Bins := [others => [others => Arithmetic.Initial_Probability_Bin]];
            DC_Contexts := [others => 0];
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      Restarts.Configure (Restart_State, Restart);
      for Row in Image_Height range 1 .. Height loop
         pragma Unreferenced (Row);
         for Column in Image_Width range 1 .. Width loop
            pragma Unreferenced (Column);
            for Component in Component_Index range 1 .. Components loop
               Outcome :=
                 Arithmetic.Encode_DC_Difference
                   (Arithmetic_Encoder,
                    DC_Bins (Component),
                    DC_Contexts (Component),
                    Conditioning => 16#5A#,
                    Difference => 0);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Outcome := Write_Restart_When_Due (Encoded /= Total);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;
      end loop;

      return Arithmetic.Finish (Arithmetic_Encoder);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Arithmetic_Zero_Residual_Scan;

   function Encode_Progressive_Blocks
     (Output : in out Streams.Destination'Class;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      Refine : Boolean) return Results.Result
   is
      DC_Compile : constant Huffman.Compile_Result :=
        Huffman.Compile (DC_Definition);
      AC_Compile : constant Huffman.Compile_Result :=
        Huffman.Compile (AC_Definition);
      First_Al : constant Successive_Approximation_Value := (if Refine then 2 else 0);
      Outcome : Results.Result;

      function Encode_DC_Scan
        (Refinement : Boolean;
         Al : Successive_Approximation_Value := 0) return Results.Result
      is
         Predictor : Coefficients.DC_Predictor := 0;
         Restart_State : Restarts.Restart_State;
         Encoded : Block_Count := 0;

         function Write_Restart_When_Due
           (Bits : in out Bit_Streams.Bit_Writer;
            More_Blocks : Boolean) return Results.Result
         is
            Marker : Marker_Code;
            Restart_Outcome : Results.Result;
         begin
            if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
               return Results.Success;
            end if;

            Marker := Restarts.Expected_Marker (Restart_State);
            Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
            if Results.Succeeded (Restart_Outcome) then
               Predictor := 0;
            end if;

            return Restart_Outcome;
         end Write_Restart_When_Due;
      begin
         Restarts.Configure (Restart_State, Restart);
         declare
            Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
         begin
            for Block of Blocks loop
               if Refinement then
                  Outcome := Coefficients.Encode_Progressive_DC_Refine_Block (Bits, Block, Al => Al);
               else
                  Outcome :=
                    Coefficients.Encode_Progressive_DC_First_Block
                      (Bits, DC_Compile.Table, Predictor, Block, Al => Al);
               end if;
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Encoded := Encoded + 1;
               Outcome := Write_Restart_When_Due (Bits, Encoded /= Block_Count (Blocks'Length));
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;

            return Bit_Streams.Flush_Byte (Bits);
         end;
      end Encode_DC_Scan;

      function Encode_AC_Scan
        (Refinement : Boolean;
         Al : Successive_Approximation_Value := 0) return Results.Result
      is
         Restart_State : Restarts.Restart_State;
         Encoded : Block_Count := 0;

         function Write_Restart_When_Due
           (Bits : in out Bit_Streams.Bit_Writer;
            More_Blocks : Boolean) return Results.Result
         is
            Marker : Marker_Code;
            Restart_Outcome : Results.Result;
         begin
            if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
               return Results.Success;
            end if;

            Marker := Restarts.Expected_Marker (Restart_State);
            Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            return Restarts.Accept_Restart (Restart_State, Marker, 0);
         end Write_Restart_When_Due;
      begin
         Restarts.Configure (Restart_State, Restart);
         declare
            Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
         begin
            for Block of Blocks loop
               if Refinement then
                  Outcome :=
                    Coefficients.Encode_Progressive_AC_Refine_Block
                      (Bits, AC_Compile.Table, Block, Al => Al);
               else
                  Outcome :=
                    Coefficients.Encode_Progressive_AC_First_Block
                      (Bits, AC_Compile.Table, Block, Al => Al);
               end if;
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Encoded := Encoded + 1;
               Outcome := Write_Restart_When_Due (Bits, Encoded /= Block_Count (Blocks'Length));
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;

            return Bit_Streams.Flush_Byte (Bits);
         end;
      end Encode_AC_Scan;
   begin
      if not Results.Succeeded (DC_Compile.Outcome) then
         return DC_Compile.Outcome;
      elsif not Results.Succeeded (AC_Compile.Outcome) then
         return AC_Compile.Outcome;
      end if;

      Outcome :=
        Writers.Write_SOS_Grayscale_Progressive
          (Output, Spectral_Start => 0, Spectral_End => 0, Al => First_Al, DC_Table => 0, AC_Table => 0);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Encode_DC_Scan (Refinement => False, Al => First_Al);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Writers.Write_SOS_Grayscale_Progressive
          (Output, Spectral_Start => 1, Spectral_End => 63, Al => First_Al, DC_Table => 0, AC_Table => 0);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Encode_AC_Scan (Refinement => False, Al => First_Al);
      if not Results.Succeeded (Outcome) or else not Refine then
         return Outcome;
      end if;

      for Refinement_Al in reverse Successive_Approximation_Value range 0 .. First_Al - 1 loop
         Outcome :=
           Writers.Write_SOS_Grayscale_Progressive
             (Output,
              Spectral_Start => 0,
              Spectral_End => 0,
              Ah => Refinement_Al + 1,
              Al => Refinement_Al,
              DC_Table => 0,
              AC_Table => 0);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_DC_Scan (Refinement => True, Al => Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Writers.Write_SOS_Grayscale_Progressive
             (Output,
              Spectral_Start => 1,
              Spectral_End => 63,
              Ah => Refinement_Al + 1,
              Al => Refinement_Al,
              DC_Table => 0,
              AC_Table => 0);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_AC_Scan (Refinement => True, Al => Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end loop;

      return Results.Success;
   end Encode_Progressive_Blocks;

   function Encode_Progressive_Grayscale_Coefficients
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Optimize_Huffman : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      DC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Luminance_DC;
      AC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Luminance_AC;
      Luma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Luma_Table_For_Quality (Quality);
      Block_Columns : constant Natural := (Natural (Width) + 7) / 8;
      Block_Rows : constant Natural := (Natural (Height) + 7) / 8;
      Needed : constant Block_Count := Block_Count (Block_Columns * Block_Rows);
      Outcome : Results.Result;
   begin
      if Huffman.Symbol_Total (DC_Definition) = 0 or else Huffman.Symbol_Total (AC_Definition) = 0 then
         return Results.Failure (Errors.Internal_Invariant_Failed);
      elsif Block_Count (Blocks'Length) /= Needed then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      if Optimize_Huffman and then not Refine then
         Optimized_Definitions_For_Blocks (Blocks, Restart, DC_Definition, AC_Definition);
      end if;

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

      Outcome := Write_DCT_SOF_Grayscale (Output, Markers.SOF2, Width, Height);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      Outcome := Encode_Progressive_Blocks (Output, DC_Definition, AC_Definition, Blocks, Restart, Refine);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Progressive_Grayscale_Coefficients;

   function Encode_Progressive_Component_Scan
     (Output : in out Streams.Destination'Class;
      Definition : Huffman.Huffman_Definition;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Restart : Restart_Interval;
      DC_Scan : Boolean;
      Refinement : Boolean;
      Al : Successive_Approximation_Value) return Results.Result
   is
      Compile : constant Huffman.Compile_Result := Huffman.Compile (Definition);
      Predictor : Coefficients.DC_Predictor := 0;
      Restart_State : Restarts.Restart_State;
      Encoded : Block_Count := 0;
      Outcome : Results.Result;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_Blocks : Boolean) return Results.Result
      is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Predictor := 0;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Refinement and then not Results.Succeeded (Compile.Outcome) then
         return Compile.Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for Block of Blocks loop
            if DC_Scan and then Refinement then
               Outcome := Coefficients.Encode_Progressive_DC_Refine_Block (Bits, Block, Al);
            elsif DC_Scan then
               Outcome :=
                 Coefficients.Encode_Progressive_DC_First_Block
                   (Bits, Compile.Table, Predictor, Block, Al);
            elsif Refinement then
               Outcome :=
                 Coefficients.Encode_Progressive_AC_Refine_Block
                   (Bits, Compile.Table, Block, Al => Al);
            else
               Outcome :=
                 Coefficients.Encode_Progressive_AC_First_Block
                   (Bits, Compile.Table, Block, Al);
            end if;
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Outcome := Write_Restart_When_Due (Bits, Encoded /= Block_Count (Blocks'Length));
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;

         return Bit_Streams.Flush_Byte (Bits);
      end;
   end Encode_Progressive_Component_Scan;

   function Encode_Progressive_Component_Grid
     (Output : in out Streams.Destination'Class;
      Definition : Huffman.Huffman_Definition;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Block_Columns : Positive;
      Block_Rows : Positive;
      Source_Block_Columns : Positive;
      Restart : Restart_Interval;
      DC_Scan : Boolean;
      Refinement : Boolean;
      Al : Successive_Approximation_Value) return Results.Result
   is
      Compile : constant Huffman.Compile_Result := Huffman.Compile (Definition);
      Predictor : Coefficients.DC_Predictor := 0;
      Restart_State : Restarts.Restart_State;
      Encoded : Block_Count := 0;
      Total : constant Block_Count := Block_Count (Block_Columns) * Block_Count (Block_Rows);
      Outcome : Results.Result;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_Blocks : Boolean) return Results.Result
      is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Predictor := 0;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Refinement and then not Results.Succeeded (Compile.Outcome) then
         return Compile.Outcome;
      elsif Total > Block_Count (Positive'Last) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for Row in 0 .. Block_Rows - 1 loop
            for Column in 0 .. Block_Columns - 1 loop
               declare
                  Block_Index : constant Positive := Blocks'First + Row * Source_Block_Columns + Column;
               begin
                  if Block_Index > Blocks'Last then
                     return Results.Failure (Errors.Internal_Invariant_Failed);
                  elsif DC_Scan and then Refinement then
                     Outcome := Coefficients.Encode_Progressive_DC_Refine_Block (Bits, Blocks (Block_Index), Al);
                  elsif DC_Scan then
                     Outcome :=
                       Coefficients.Encode_Progressive_DC_First_Block
                         (Bits, Compile.Table, Predictor, Blocks (Block_Index), Al);
                  elsif Refinement then
                     Outcome :=
                       Coefficients.Encode_Progressive_AC_Refine_Block
                         (Bits, Compile.Table, Blocks (Block_Index), Al => Al);
                  else
                     Outcome :=
                       Coefficients.Encode_Progressive_AC_First_Block
                         (Bits, Compile.Table, Blocks (Block_Index), Al);
                  end if;
               end;
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Encoded := Encoded + 1;
               Outcome := Write_Restart_When_Due (Bits, Encoded /= Total);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;
         end loop;

         return Bit_Streams.Flush_Byte (Bits);
      end;
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Progressive_Component_Grid;

   function Encode_Progressive_YCbCr_Blocks
     (Output : in out Streams.Destination'Class;
      Luma_DC_Definition : Huffman.Huffman_Definition;
      Luma_AC_Definition : Huffman.Huffman_Definition;
      Chroma_DC_Definition : Huffman.Huffman_Definition;
      Chroma_AC_Definition : Huffman.Huffman_Definition;
      Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Cb_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Cr_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Y_Block_Columns : Positive;
      C_Block_Columns : Positive;
      Y_Component_Block_Columns : Positive;
      Y_Component_Block_Rows : Positive;
      Chroma_Component_Block_Columns : Positive;
      Chroma_Component_Block_Rows : Positive;
      MCU_Columns : Positive;
      MCU_Rows : Positive;
      Layout : Image_Blocks.Subsampling_Layout;
      Restart : Restart_Interval;
      Refine : Boolean) return Results.Result
   is
      Luma_DC_Compile : constant Huffman.Compile_Result := Huffman.Compile (Luma_DC_Definition);
      Chroma_DC_Compile : constant Huffman.Compile_Result := Huffman.Compile (Chroma_DC_Definition);
      First_Al : constant Successive_Approximation_Value := (if Refine then 2 else 0);
      Y_Predictor : Coefficients.DC_Predictor := 0;
      Cb_Predictor : Coefficients.DC_Predictor := 0;
      Cr_Predictor : Coefficients.DC_Predictor := 0;
      Restart_State : Restarts.Restart_State;
      Outcome : Results.Result;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_MCUs : Boolean) return Results.Result
      is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_MCUs then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Y_Predictor := 0;
            Cb_Predictor := 0;
            Cr_Predictor := 0;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;

      function Write_Component_AC
        (Component : Component_Identifier;
         Definition : Huffman.Huffman_Definition;
         Blocks : Jpeglib.Coefficients.DCT_Block_Array;
         Block_Columns : Positive;
         Block_Rows : Positive;
         Source_Block_Columns : Positive;
         AC_Table : Huffman_Table_Index;
         Refinement : Boolean;
         Al : Successive_Approximation_Value) return Results.Result
      is
         Scan_Outcome : Results.Result;
      begin
         Scan_Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output,
              Component => Component,
              Spectral_Start => 1,
              Spectral_End => 63,
              Ah => (if Refinement then Al + 1 else 0),
              Al => Al,
              DC_Table => 0,
              AC_Table => AC_Table);
         if not Results.Succeeded (Scan_Outcome) then
            return Scan_Outcome;
         end if;

         return
           Encode_Progressive_Component_Grid
             (Output,
              Definition,
              Blocks,
              Block_Columns,
              Block_Rows,
              Source_Block_Columns,
              Restart,
              DC_Scan => False,
              Refinement => Refinement,
              Al => Al);
      end Write_Component_AC;

      function Write_Component_DC_Refine
        (Component : Component_Identifier;
         Blocks : Jpeglib.Coefficients.DCT_Block_Array;
         Block_Columns : Positive;
         Block_Rows : Positive;
         Source_Block_Columns : Positive;
         DC_Table : Huffman_Table_Index;
         Al : Successive_Approximation_Value) return Results.Result
      is
         Scan_Outcome : Results.Result;
      begin
         Scan_Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output,
              Component => Component,
              Spectral_Start => 0,
              Spectral_End => 0,
              Ah => Al + 1,
              Al => Al,
              DC_Table => DC_Table,
              AC_Table => 0);
         if not Results.Succeeded (Scan_Outcome) then
            return Scan_Outcome;
         end if;

         return
           Encode_Progressive_Component_Grid
             (Output,
              Luma_DC_Definition,
              Blocks,
              Block_Columns,
              Block_Rows,
              Source_Block_Columns,
              Restart,
              DC_Scan => True,
              Refinement => True,
              Al => Al);
      end Write_Component_DC_Refine;
   begin
      if not Results.Succeeded (Luma_DC_Compile.Outcome) then
         return Luma_DC_Compile.Outcome;
      elsif not Results.Succeeded (Chroma_DC_Compile.Outcome) then
         return Chroma_DC_Compile.Outcome;
      end if;

      Outcome := Writers.Write_SOS_YCbCr_Progressive_DC (Output, Al => First_Al);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for MCU_Row in 0 .. MCU_Rows - 1 loop
            for MCU_Column in 0 .. MCU_Columns - 1 loop
               for V in 0 .. Layout.Chroma_Vertical_Factor - 1 loop
                  for H in 0 .. Layout.Chroma_Horizontal_Factor - 1 loop
                     declare
                        Block_Index : constant Positive :=
                          Y_Blocks'First
                          + (MCU_Row * Layout.Chroma_Vertical_Factor + V) * Y_Block_Columns
                          + MCU_Column * Layout.Chroma_Horizontal_Factor
                          + H;
                     begin
                        Outcome :=
                          Coefficients.Encode_Progressive_DC_First_Block
                            (Bits, Luma_DC_Compile.Table, Y_Predictor, Y_Blocks (Block_Index), Al => First_Al);
                     end;
                     if not Results.Succeeded (Outcome) then
                        return Outcome;
                     end if;
                  end loop;
               end loop;

               declare
                  Chroma_Index : constant Positive := Cb_Blocks'First + MCU_Row * C_Block_Columns + MCU_Column;
               begin
                  Outcome :=
                    Coefficients.Encode_Progressive_DC_First_Block
                      (Bits, Chroma_DC_Compile.Table, Cb_Predictor, Cb_Blocks (Chroma_Index), Al => First_Al);
               end;
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               declare
                  Chroma_Index : constant Positive := Cr_Blocks'First + MCU_Row * C_Block_Columns + MCU_Column;
               begin
                  Outcome :=
                    Coefficients.Encode_Progressive_DC_First_Block
                      (Bits, Chroma_DC_Compile.Table, Cr_Predictor, Cr_Blocks (Chroma_Index), Al => First_Al);
               end;
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome :=
                 Write_Restart_When_Due (Bits, MCU_Row /= MCU_Rows - 1 or else MCU_Column /= MCU_Columns - 1);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;
         end loop;

         Outcome := Bit_Streams.Flush_Byte (Bits);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end;

      Outcome :=
        Write_Component_AC
          (1,
           Luma_AC_Definition,
           Y_Blocks,
           Y_Component_Block_Columns,
           Y_Component_Block_Rows,
           Y_Block_Columns,
           0,
           Refinement => False,
           Al => First_Al);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_Component_AC
          (2,
           Chroma_AC_Definition,
           Cb_Blocks,
           Chroma_Component_Block_Columns,
           Chroma_Component_Block_Rows,
           C_Block_Columns,
           1,
           Refinement => False,
           Al => First_Al);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Write_Component_AC
          (3,
           Chroma_AC_Definition,
           Cr_Blocks,
           Chroma_Component_Block_Columns,
           Chroma_Component_Block_Rows,
           C_Block_Columns,
           1,
           Refinement => False,
           Al => First_Al);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if not Refine then
         return Results.Success;
      end if;

      for Refinement_Al in reverse Successive_Approximation_Value range 0 .. First_Al - 1 loop
         Outcome :=
           Write_Component_DC_Refine
             (1, Y_Blocks, Y_Component_Block_Columns, Y_Component_Block_Rows, Y_Block_Columns, 0, Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Write_Component_DC_Refine
             (2,
              Cb_Blocks,
              Chroma_Component_Block_Columns,
              Chroma_Component_Block_Rows,
              C_Block_Columns,
              1,
              Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Write_Component_DC_Refine
             (3,
              Cr_Blocks,
              Chroma_Component_Block_Columns,
              Chroma_Component_Block_Rows,
              C_Block_Columns,
              1,
              Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Write_Component_AC
             (1,
              Luma_AC_Definition,
              Y_Blocks,
              Y_Component_Block_Columns,
              Y_Component_Block_Rows,
              Y_Block_Columns,
              0,
              Refinement => True,
              Al => Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Write_Component_AC
             (2,
              Chroma_AC_Definition,
              Cb_Blocks,
              Chroma_Component_Block_Columns,
              Chroma_Component_Block_Rows,
              C_Block_Columns,
              1,
              Refinement => True,
              Al => Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Write_Component_AC
             (3,
              Chroma_AC_Definition,
              Cr_Blocks,
              Chroma_Component_Block_Columns,
              Chroma_Component_Block_Rows,
              C_Block_Columns,
              1,
              Refinement => True,
              Al => Refinement_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end loop;

      return Results.Success;
   end Encode_Progressive_YCbCr_Blocks;

   function Encode_YCbCr_Blocks
     (Output : in out Streams.Destination'Class;
      Luma_DC_Definition : Huffman.Huffman_Definition;
      Luma_AC_Definition : Huffman.Huffman_Definition;
      Chroma_DC_Definition : Huffman.Huffman_Definition;
      Chroma_AC_Definition : Huffman.Huffman_Definition;
      Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Cb_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Cr_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Y_Block_Columns : Positive;
      C_Block_Columns : Positive;
      MCU_Columns : Positive;
      MCU_Rows : Positive;
      Layout : Image_Blocks.Subsampling_Layout;
      Restart : Restart_Interval) return Results.Result
   is
      Luma_DC_Compile : constant Huffman.Compile_Result :=
        Huffman.Compile (Luma_DC_Definition);
      Luma_AC_Compile : constant Huffman.Compile_Result :=
        Huffman.Compile (Luma_AC_Definition);
      Chroma_DC_Compile : constant Huffman.Compile_Result :=
        Huffman.Compile (Chroma_DC_Definition);
      Chroma_AC_Compile : constant Huffman.Compile_Result :=
        Huffman.Compile (Chroma_AC_Definition);
      Y_Predictor : Coefficients.DC_Predictor := 0;
      Cb_Predictor : Coefficients.DC_Predictor := 0;
      Cr_Predictor : Coefficients.DC_Predictor := 0;
      Restart_State : Restarts.Restart_State;
      Outcome : Results.Result;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_MCUs : Boolean) return Results.Result
      is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_MCUs then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Y_Predictor := 0;
            Cb_Predictor := 0;
            Cr_Predictor := 0;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Results.Succeeded (Luma_DC_Compile.Outcome) then
         return Luma_DC_Compile.Outcome;
      elsif not Results.Succeeded (Luma_AC_Compile.Outcome) then
         return Luma_AC_Compile.Outcome;
      elsif not Results.Succeeded (Chroma_DC_Compile.Outcome) then
         return Chroma_DC_Compile.Outcome;
      elsif not Results.Succeeded (Chroma_AC_Compile.Outcome) then
         return Chroma_AC_Compile.Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for MCU_Row in 0 .. MCU_Rows - 1 loop
            for MCU_Column in 0 .. MCU_Columns - 1 loop
               for V in 0 .. Layout.Chroma_Vertical_Factor - 1 loop
                  for H in 0 .. Layout.Chroma_Horizontal_Factor - 1 loop
                     declare
                        Block_Index : constant Positive :=
                          Y_Blocks'First
                          + (MCU_Row * Layout.Chroma_Vertical_Factor + V) * Y_Block_Columns
                          + MCU_Column * Layout.Chroma_Horizontal_Factor
                          + H;
                     begin
                        Outcome :=
                          Coefficients.Encode_Baseline_Block
                            (Bits,
                             Luma_DC_Compile.Table,
                             Luma_AC_Compile.Table,
                             Y_Predictor,
                             Y_Blocks (Block_Index));
                     end;
                     if not Results.Succeeded (Outcome) then
                        return Outcome;
                     end if;
                  end loop;
               end loop;

               declare
                  Chroma_Index : constant Positive := Cb_Blocks'First + MCU_Row * C_Block_Columns + MCU_Column;
               begin
                  Outcome :=
                    Coefficients.Encode_Baseline_Block
                      (Bits,
                       Chroma_DC_Compile.Table,
                       Chroma_AC_Compile.Table,
                       Cb_Predictor,
                       Cb_Blocks (Chroma_Index));
               end;
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               declare
                  Chroma_Index : constant Positive := Cr_Blocks'First + MCU_Row * C_Block_Columns + MCU_Column;
               begin
                  Outcome :=
                    Coefficients.Encode_Baseline_Block
                      (Bits,
                       Chroma_DC_Compile.Table,
                       Chroma_AC_Compile.Table,
                       Cr_Predictor,
                       Cr_Blocks (Chroma_Index));
               end;
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome :=
                 Write_Restart_When_Due (Bits, MCU_Row /= MCU_Rows - 1 or else MCU_Column /= MCU_Columns - 1);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;
         end loop;

         return Bit_Streams.Flush_Byte (Bits);
      end;
   end Encode_YCbCr_Blocks;

   function Encode_CMYK_Blocks
     (Output : in out Streams.Destination'Class;
      DC_Definition : Huffman.Huffman_Definition;
      AC_Definition : Huffman.Huffman_Definition;
      C_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      M_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      K_Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Block_Columns : Positive;
      Block_Rows : Positive;
      Restart : Restart_Interval) return Results.Result
   is
      DC_Compile : constant Huffman.Compile_Result := Huffman.Compile (DC_Definition);
      AC_Compile : constant Huffman.Compile_Result := Huffman.Compile (AC_Definition);
      C_Predictor : Coefficients.DC_Predictor := 0;
      M_Predictor : Coefficients.DC_Predictor := 0;
      Y_Predictor : Coefficients.DC_Predictor := 0;
      K_Predictor : Coefficients.DC_Predictor := 0;
      Restart_State : Restarts.Restart_State;
      Outcome : Results.Result;

      function Write_Restart_When_Due
        (Bits : in out Bit_Streams.Bit_Writer;
         More_MCUs : Boolean) return Results.Result
      is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_MCUs then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Bit_Streams.Write_Restart_Marker (Bits, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            C_Predictor := 0;
            M_Predictor := 0;
            Y_Predictor := 0;
            K_Predictor := 0;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;
   begin
      if not Results.Succeeded (DC_Compile.Outcome) then
         return DC_Compile.Outcome;
      elsif not Results.Succeeded (AC_Compile.Outcome) then
         return AC_Compile.Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      declare
         Bits : Bit_Streams.Bit_Writer (Output'Unchecked_Access);
      begin
         for Block_Row in 0 .. Block_Rows - 1 loop
            for Block_Column in 0 .. Block_Columns - 1 loop
               declare
                  Block_Index : constant Positive := C_Blocks'First + Block_Row * Block_Columns + Block_Column;
               begin
                  Outcome :=
                    Coefficients.Encode_Baseline_Block
                      (Bits, DC_Compile.Table, AC_Compile.Table, C_Predictor, C_Blocks (Block_Index));
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome :=
                    Coefficients.Encode_Baseline_Block
                      (Bits, DC_Compile.Table, AC_Compile.Table, M_Predictor, M_Blocks (Block_Index));
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome :=
                    Coefficients.Encode_Baseline_Block
                      (Bits, DC_Compile.Table, AC_Compile.Table, Y_Predictor, Y_Blocks (Block_Index));
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Outcome :=
                    Coefficients.Encode_Baseline_Block
                      (Bits, DC_Compile.Table, AC_Compile.Table, K_Predictor, K_Blocks (Block_Index));
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;
               end;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome :=
                 Write_Restart_When_Due (Bits, Block_Row /= Block_Rows - 1 or else Block_Column /= Block_Columns - 1);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;
         end loop;

         return Bit_Streams.Flush_Byte (Bits);
      end;
   end Encode_CMYK_Blocks;

   function Encode_Gray_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Optimize_Huffman : Boolean := False;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      DC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Luminance_DC;
      AC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Luminance_AC;
      Luma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Luma_Table_For_Quality (Quality);
      Needed : Block_Count;
      Outcome : Results.Result;
   begin
      if Huffman.Symbol_Total (DC_Definition) = 0 or else Huffman.Symbol_Total (AC_Definition) = 0 then
         return Results.Failure (Errors.Internal_Invariant_Failed);
      end if;

      Needed := Image_Blocks.Required_Block_Count (Input.Descriptor);
      if Needed > Block_Count (Positive'Last) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      declare
         Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Needed)) := [others => [others => 0]];
         Image_Result : constant Image_Blocks.Image_Block_Result :=
           Image_Blocks.Encode_Gray_Blocks
             (Input, Luma_Quantization, Blocks, Mode => Image_Blocks.Full_Forward);
      begin
         if not Results.Succeeded (Image_Result.Outcome) then
            return Image_Result.Outcome;
         end if;

         if Optimize_Huffman then
            Optimized_Definitions_For_Blocks (Blocks, Restart, DC_Definition, AC_Definition);
         end if;

         Outcome :=
           Write_Headers
             (Output,
              Input,
              DC_Definition,
              AC_Definition,
              Luma_Quantization,
              Restart,
              Differential,
              Hierarchical,
              Encoded_Metadata);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_Blocks (Output, DC_Definition, AC_Definition, Blocks, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         if Hierarchical and then not Differential then
            Outcome :=
              Write_DCT_SOF_Grayscale
                (Output,
                 Marker => Markers.SOF5,
                 Width => Input.Descriptor.Width,
                 Height => Input.Descriptor.Height);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Writers.Write_SOS_Grayscale (Output);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            declare
               Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (Blocks'Range) :=
                 [others => [others => 0]];
            begin
               Outcome := Encode_Blocks (Output, DC_Definition, AC_Definition, Residual_Blocks, Restart);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end;
         end if;
      end;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Gray_Image;

   function Encode_Gray_Alpha_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      DC_Definition : constant Huffman.Huffman_Definition := Huffman.Standard_Luminance_DC;
      AC_Definition : constant Huffman.Huffman_Definition := Huffman.Standard_Luminance_AC;
      Luma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Luma_Table_For_Quality (Quality);
      Needed : Block_Count;
      Samples_Needed : Byte_Count;
      Outcome : Results.Result;
   begin
      if Huffman.Symbol_Total (DC_Definition) = 0 or else Huffman.Symbol_Total (AC_Definition) = 0 then
         return Results.Failure (Errors.Internal_Invariant_Failed);
      end if;

      Needed := Image_Blocks.Required_Block_Count (Input.Descriptor);
      if Needed > Block_Count (Positive'Last / 2) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      Samples_Needed := Byte_Count (Input.Descriptor.Width) * Byte_Count (Input.Descriptor.Height);
      if Samples_Needed > Byte_Count (Positive'Last) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      declare
         Gray_Plane : Streams.Byte_Array (1 .. Positive (Samples_Needed)) := [others => 0];
         Alpha_Plane : Streams.Byte_Array (1 .. Positive (Samples_Needed)) := [others => 0];
         Gray_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Needed)) := [others => [others => 0]];
         Alpha_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Needed)) := [others => [others => 0]];
         Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Needed * 2)) := [others => [others => 0]];
         Plane_Result : constant Image_Blocks.Plane_Result :=
           Image_Blocks.Fill_Gray_Alpha_Planes (Input, Gray_Plane, Alpha_Plane);
         Gray_Result : Image_Blocks.Image_Block_Result;
         Alpha_Result : Image_Blocks.Image_Block_Result;
      begin
         if not Results.Succeeded (Plane_Result.Outcome) then
            return Plane_Result.Outcome;
         end if;

         Gray_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Gray_Plane,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Luma_Quantization,
              Gray_Blocks,
              Mode => Image_Blocks.Full_Forward);
         if not Results.Succeeded (Gray_Result.Outcome) then
            return Gray_Result.Outcome;
         end if;

         Alpha_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Alpha_Plane,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Luma_Quantization,
              Alpha_Blocks,
              Mode => Image_Blocks.Full_Forward);
         if not Results.Succeeded (Alpha_Result.Outcome) then
            return Alpha_Result.Outcome;
         end if;

         for Index in Positive range 1 .. Positive (Needed) loop
            Blocks (1 + (Index - 1) * 2) := Gray_Blocks (Index);
            Blocks (2 + (Index - 1) * 2) := Alpha_Blocks (Index);
         end loop;

         Outcome :=
           Write_Gray_Alpha_Headers
             (Output,
              Input,
              DC_Definition,
              AC_Definition,
              Luma_Quantization,
              Restart,
              Differential,
              Hierarchical,
              Encoded_Metadata);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_Blocks (Output, DC_Definition, AC_Definition, Blocks, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         if Hierarchical and then not Differential then
            Outcome :=
              Write_DCT_SOF_Gray_Alpha
                (Output,
                 Marker => Markers.SOF5,
                 Width => Input.Descriptor.Width,
                 Height => Input.Descriptor.Height);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Writers.Write_SOS_Gray_Alpha (Output);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            declare
               Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (Blocks'Range) :=
                 [others => [others => 0]];
            begin
               Outcome := Encode_Blocks (Output, DC_Definition, AC_Definition, Residual_Blocks, Restart);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end;
         end if;
      end;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Gray_Alpha_Image;

   function Encode_Arithmetic_Gray_Alpha_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      Luma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Luma_Table_For_Quality (Quality);
      Needed : Block_Count;
      Samples_Needed : Byte_Count;
      Outcome : Results.Result;
   begin
      Needed := Image_Blocks.Required_Block_Count (Input.Descriptor);
      if Needed > Block_Count (Positive'Last) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      Samples_Needed := Byte_Count (Input.Descriptor.Width) * Byte_Count (Input.Descriptor.Height);
      if Samples_Needed > Byte_Count (Positive'Last) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      declare
         Gray_Plane : Streams.Byte_Array (1 .. Positive (Samples_Needed)) := [others => 0];
         Alpha_Plane : Streams.Byte_Array (1 .. Positive (Samples_Needed)) := [others => 0];
         Gray_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Needed)) := [others => [others => 0]];
         Alpha_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Needed)) := [others => [others => 0]];
         Plane_Result : constant Image_Blocks.Plane_Result :=
           Image_Blocks.Fill_Gray_Alpha_Planes (Input, Gray_Plane, Alpha_Plane);
         Gray_Result : Image_Blocks.Image_Block_Result;
         Alpha_Result : Image_Blocks.Image_Block_Result;
      begin
         if not Results.Succeeded (Plane_Result.Outcome) then
            return Plane_Result.Outcome;
         end if;

         Gray_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Gray_Plane,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Luma_Quantization,
              Gray_Blocks,
              Mode => Image_Blocks.Full_Forward);
         if not Results.Succeeded (Gray_Result.Outcome) then
            return Gray_Result.Outcome;
         end if;

         Alpha_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Alpha_Plane,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Luma_Quantization,
              Alpha_Blocks,
              Mode => Image_Blocks.Full_Forward);
         if not Results.Succeeded (Alpha_Result.Outcome) then
            return Alpha_Result.Outcome;
         end if;

         if not Arithmetic_Blocks_Supported (Gray_Blocks, Restart)
           or else not Arithmetic_Blocks_Supported (Alpha_Blocks, Restart)
         then
            return Results.Failure (Errors.Unsupported_Feature);
         end if;

         Outcome :=
           Write_Arithmetic_Gray_Alpha_Headers
             (Output, Input, Luma_Quantization, Restart, Differential, Hierarchical, Encoded_Metadata);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output, Component => 1, Spectral_Start => 0, Spectral_End => 63, DC_Table => 0, AC_Table => 0);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_Arithmetic_Blocks (Output, Gray_Blocks, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output, Component => 2, Spectral_Start => 0, Spectral_End => 63, DC_Table => 0, AC_Table => 0);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_Arithmetic_Blocks (Output, Alpha_Blocks, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         if Hierarchical and then not Differential then
            Outcome :=
              Write_DCT_SOF_Gray_Alpha
                (Output,
                 Marker => Markers.SOF13,
                 Width => Input.Descriptor.Width,
                 Height => Input.Descriptor.Height);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            declare
               Gray_Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (Gray_Blocks'Range) :=
                 [others => [others => 0]];
               Alpha_Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (Alpha_Blocks'Range) :=
                 [others => [others => 0]];
            begin
               Outcome :=
                 Writers.Write_SOS_Component_Progressive
                   (Output, Component => 1, Spectral_Start => 0, Spectral_End => 63, DC_Table => 0, AC_Table => 0);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Encode_Arithmetic_Blocks (Output, Gray_Residual_Blocks, Restart);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome :=
                 Writers.Write_SOS_Component_Progressive
                   (Output, Component => 2, Spectral_Start => 0, Spectral_End => 63, DC_Table => 0, AC_Table => 0);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Encode_Arithmetic_Blocks (Output, Alpha_Residual_Blocks, Restart);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end;
         end if;
      end;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Arithmetic_Gray_Alpha_Image;

   function Encode_Arithmetic_Gray_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      Luma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Luma_Table_For_Quality (Quality);
      Needed : Block_Count;
      Outcome : Results.Result;
   begin
      Needed := Image_Blocks.Required_Block_Count (Input.Descriptor);
      if Needed > Block_Count (Positive'Last) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      declare
         Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Needed)) := [others => [others => 0]];
         Image_Result : constant Image_Blocks.Image_Block_Result :=
           Image_Blocks.Encode_Gray_Blocks
             (Input, Luma_Quantization, Blocks, Mode => Image_Blocks.Full_Forward);
      begin
         if not Results.Succeeded (Image_Result.Outcome) then
            return Image_Result.Outcome;
         end if;

         if not Arithmetic_Blocks_Supported (Blocks, Restart) then
            return Results.Failure (Errors.Unsupported_Feature);
         end if;

         Outcome :=
           Write_Arithmetic_Headers
             (Output, Input, Luma_Quantization, Restart, Differential, Hierarchical, Encoded_Metadata);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_Arithmetic_Blocks (Output, Blocks, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         if Hierarchical and then not Differential then
            Outcome :=
              Write_DCT_SOF_Grayscale
                (Output,
                 Marker => Markers.SOF13,
                 Width => Input.Descriptor.Width,
                 Height => Input.Descriptor.Height);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome :=
              Writers.Write_SOS_Component_Progressive
                (Output, Component => 1, Spectral_Start => 0, Spectral_End => 63, DC_Table => 0, AC_Table => 0);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            declare
               Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (Blocks'Range) :=
                 [others => [others => 0]];
            begin
               Outcome := Encode_Arithmetic_Blocks (Output, Residual_Blocks, Restart);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end;
         end if;
      end;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Arithmetic_Gray_Image;

   function Encode_Lossless_Gray_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      DC_Definition : constant Huffman.Huffman_Definition := Huffman.Standard_Luminance_DC;
      Outcome : Results.Result;
   begin
      if Huffman.Symbol_Total (DC_Definition) = 0 then
         return Results.Failure (Errors.Internal_Invariant_Failed);
      end if;

      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.DC, 0, DC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        (if Differential then
            Writers.Write_SOF7_Grayscale (Output, Input.Descriptor.Width, Input.Descriptor.Height)
         else
            Writers.Write_SOF3_Grayscale (Output, Input.Descriptor.Width, Input.Descriptor.Height));
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      Outcome :=
        Writers.Write_SOS_Lossless_Grayscale
          (Output, Predictor => Predictor, Point_Transform => Point_Transform);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Encode_Lossless_Gray_Scan
          (Output, Input, DC_Definition, Restart, Predictor, Point_Transform);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Hierarchical and then not Differential then
         Outcome := Writers.Write_SOF7_Grayscale (Output, Input.Descriptor.Width, Input.Descriptor.Height);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Writers.Write_SOS_Lossless_Grayscale (Output);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Encode_Huffman_Zero_Residual_Scan
             (Output,
              DC_Definition,
              Restart,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Components => 1);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Lossless_Gray_Image;

   function Encode_Lossless_Gray_Alpha_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      DC_Definition : constant Huffman.Huffman_Definition := Huffman.Standard_Luminance_DC;
      Outcome : Results.Result;
   begin
      if Huffman.Symbol_Total (DC_Definition) = 0 then
         return Results.Failure (Errors.Internal_Invariant_Failed);
      end if;

      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.DC, 0, DC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        (if Differential then
            Writers.Write_SOF7_Gray_Alpha (Output, Input.Descriptor.Width, Input.Descriptor.Height)
         else
            Writers.Write_SOF3_Gray_Alpha (Output, Input.Descriptor.Width, Input.Descriptor.Height));
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      Outcome :=
        Writers.Write_SOS_Lossless_Gray_Alpha
          (Output, Predictor => Predictor, Point_Transform => Point_Transform);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Encode_Lossless_Gray_Alpha_Scan
          (Output, Input, DC_Definition, Restart, Predictor, Point_Transform);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Hierarchical and then not Differential then
         Outcome := Writers.Write_SOF7_Gray_Alpha (Output, Input.Descriptor.Width, Input.Descriptor.Height);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Writers.Write_SOS_Lossless_Gray_Alpha (Output);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Encode_Huffman_Zero_Residual_Scan
             (Output,
              DC_Definition,
              Restart,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Components => 2);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Lossless_Gray_Alpha_Image;

   function Encode_Arithmetic_Lossless_Gray_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      Restart_State : Restarts.Restart_State;
      Restart_Base : Pixel_Count := 0;
      Encoded : Pixel_Count := 0;
      Total : constant Pixel_Count :=
        Pixel_Count (Input.Descriptor.Width) * Pixel_Count (Input.Descriptor.Height);
      Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
      DC_Bins : Arithmetic.Probability_Bin_Array (0 .. 63) :=
        [others => Arithmetic.Initial_Probability_Bin];
      DC_Context : Arithmetic.DC_Context_Index := 0;
      Outcome : Results.Result;

      function Sample (Column, Row : Natural) return Integer is
         Index : constant Positive :=
           Input.Storage'First + Row * Natural (Input.Descriptor.Stride) + Column;
      begin
         return Integer (Input.Storage (Index)) / (2 ** Natural (Point_Transform));
      end Sample;

      function Predicted (Column, Row : Natural) return Integer is
         Ra : Integer;
         Rb : Integer;
         Rc : Integer;
      begin
         if Encoded = Restart_Base then
            return 2 ** (7 - Natural (Point_Transform));
         elsif Column = 0 then
            return Sample (Column, Row - 1);
         elsif Row = 0 then
            return Sample (Column - 1, Row);
         end if;

         Ra := Sample (Column - 1, Row);
         Rb := Sample (Column, Row - 1);
         Rc := Sample (Column - 1, Row - 1);

         case Predictor is
            when 1 =>
               return Ra;
            when 2 =>
               return Rb;
            when 3 =>
               return Rc;
            when 4 =>
               return Ra + Rb - Rc;
            when 5 =>
               return Ra + (Rb - Rc) / 2;
            when 6 =>
               return Rb + (Ra - Rc) / 2;
            when 7 =>
               return (Ra + Rb) / 2;
         end case;
      end Predicted;

      function Write_Restart_When_Due (More_Samples : Boolean) return Results.Result is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Samples then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Writers.Write_Marker (Output, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Arithmetic.Reset (Arithmetic_Encoder);
            DC_Bins := [others => Arithmetic.Initial_Probability_Bin];
            DC_Context := 0;
            Restart_Base := Encoded;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;

      function Difference_Supported (Difference : Integer) return Boolean is
         pragma Unreferenced (Difference);
      begin
         return True;
      end Difference_Supported;

      function Write_Difference (Difference : Integer) return Results.Result is
         Events : Arithmetic.DC_Difference_Event_Result;
      begin
         Events :=
           Arithmetic.Encode_DC_Difference_Events
             (Arithmetic.DC_Difference (Difference),
              DC_Context,
              16#5A#);
         if not Results.Succeeded (Events.Outcome) then
            return Events.Outcome;
         end if;

         for Event_Index in 1 .. Events.Length loop
            Outcome :=
              Arithmetic.Encode_Bit
                (Arithmetic_Encoder,
                 DC_Bins (Events.Events (Event_Index).Bin_Index),
                 Events.Events (Event_Index).Decision);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;

         DC_Context := Events.Final_Context;
         return Results.Success;
      end Write_Difference;

      function Validate_Differences return Results.Result is
         Marker : Marker_Code;
      begin
         Restarts.Configure (Restart_State, Restart);
         for Row in Natural range 0 .. Natural (Input.Descriptor.Height) - 1 loop
            for Column in Natural range 0 .. Natural (Input.Descriptor.Width) - 1 loop
               declare
                  Difference : constant Integer := Sample (Column, Row) - Predicted (Column, Row);
               begin
                  if not Difference_Supported (Difference) then
                     return Results.Failure (Errors.Unsupported_Feature);
                  end if;

               end;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Encoded := Encoded + 1;
               if Restart /= 0
                 and then Restarts.MCUs_Until_Restart (Restart_State) = 0
                 and then Encoded /= Total
               then
                  Marker := Restarts.Expected_Marker (Restart_State);
                  Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Restart_Base := Encoded;
               end if;
            end loop;
         end loop;

         return Results.Success;
      end Validate_Differences;
   begin
      Outcome := Validate_Differences;
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Restart_Base := 0;
      Encoded := 0;
      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
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

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        (if Differential then
            Writers.Write_SOF15_Grayscale (Output, Input.Descriptor.Width, Input.Descriptor.Height)
         else
            Writers.Write_SOF11_Grayscale (Output, Input.Descriptor.Width, Input.Descriptor.Height));
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      Outcome :=
        Writers.Write_SOS_Lossless_Grayscale
          (Output, Predictor => Predictor, Point_Transform => Point_Transform);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      for Row in Natural range 0 .. Natural (Input.Descriptor.Height) - 1 loop
         for Column in Natural range 0 .. Natural (Input.Descriptor.Width) - 1 loop
            declare
               Difference : constant Integer := Sample (Column, Row) - Predicted (Column, Row);
            begin
               Outcome := Write_Difference (Difference);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

            end;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Outcome := Write_Restart_When_Due (Encoded /= Total);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;
      end loop;

      Outcome := Arithmetic.Finish (Arithmetic_Encoder);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Hierarchical and then not Differential then
         Outcome := Writers.Write_SOF15_Grayscale (Output, Input.Descriptor.Width, Input.Descriptor.Height);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Writers.Write_SOS_Lossless_Grayscale (Output);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Encode_Arithmetic_Zero_Residual_Scan
             (Output,
              Restart,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Components => 1);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Arithmetic_Lossless_Gray_Image;

   function Encode_Arithmetic_Lossless_Gray_Alpha_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      type Difference_Array is array (Component_Index range 1 .. 2) of Integer;
      Restart_State : Restarts.Restart_State;
      Restart_Base : Pixel_Count := 0;
      Encoded : Pixel_Count := 0;
      Total : constant Pixel_Count :=
        Pixel_Count (Input.Descriptor.Width) * Pixel_Count (Input.Descriptor.Height);
      Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
      type DC_Bin_By_Component is array (Component_Index range 1 .. 2) of
        Arithmetic.Probability_Bin_Array (0 .. 63);
      DC_Bins : DC_Bin_By_Component := [others => [others => Arithmetic.Initial_Probability_Bin]];
      DC_Contexts : Arithmetic.DC_Context_Array := [others => 0];
      Outcome : Results.Result;

      function Sample (Component : Component_Index; Column, Row : Natural) return Integer is
         Base : constant Positive :=
           Input.Storage'First
           + Row * Natural (Input.Descriptor.Stride)
           + Column * 2;
      begin
         case Component is
            when 1 =>
               return Integer (Input.Storage (Base)) / (2 ** Natural (Point_Transform));
            when 2 =>
               return Integer (Input.Storage (Base + 1)) / (2 ** Natural (Point_Transform));
            when others =>
               return 0;
         end case;
      end Sample;

      function Predicted (Component : Component_Index; Column, Row : Natural) return Integer is
         Ra : Integer;
         Rb : Integer;
         Rc : Integer;
      begin
         if Encoded = Restart_Base then
            return 2 ** (7 - Natural (Point_Transform));
         elsif Column = 0 then
            return Sample (Component, Column, Row - 1);
         elsif Row = 0 then
            return Sample (Component, Column - 1, Row);
         end if;

         Ra := Sample (Component, Column - 1, Row);
         Rb := Sample (Component, Column, Row - 1);
         Rc := Sample (Component, Column - 1, Row - 1);

         case Predictor is
            when 1 =>
               return Ra;
            when 2 =>
               return Rb;
            when 3 =>
               return Rc;
            when 4 =>
               return Ra + Rb - Rc;
            when 5 =>
               return Ra + (Rb - Rc) / 2;
            when 6 =>
               return Rb + (Ra - Rc) / 2;
            when 7 =>
               return (Ra + Rb) / 2;
         end case;
      end Predicted;

      function Write_Restart_When_Due (More_Samples : Boolean) return Results.Result is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Samples then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Writers.Write_Marker (Output, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Arithmetic.Reset (Arithmetic_Encoder);
            DC_Bins := [others => [others => Arithmetic.Initial_Probability_Bin]];
            DC_Contexts := [others => 0];
            Restart_Base := Encoded;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;

      function Differences_Supported (Differences : Difference_Array) return Boolean is
         pragma Unreferenced (Differences);
      begin
         return True;
      end Differences_Supported;

      function Write_Differences (Differences : Difference_Array) return Results.Result is
         Outcome : Results.Result;
         Events : Arithmetic.DC_Difference_Event_Result;
      begin
         for Component in Component_Index range 1 .. 2 loop
            Events :=
              Arithmetic.Encode_DC_Difference_Events
                (Arithmetic.DC_Difference (Differences (Component)),
                 DC_Contexts (Component),
                 16#5A#);
            if not Results.Succeeded (Events.Outcome) then
               return Events.Outcome;
            end if;

            for Event_Index in 1 .. Events.Length loop
               Outcome :=
                 Arithmetic.Encode_Bit
                   (Arithmetic_Encoder,
                    DC_Bins (Component) (Events.Events (Event_Index).Bin_Index),
                    Events.Events (Event_Index).Decision);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;

            DC_Contexts (Component) := Events.Final_Context;
         end loop;

         return Results.Success;
      end Write_Differences;

      function Validate_Differences return Results.Result is
         Marker : Marker_Code;
      begin
         Restarts.Configure (Restart_State, Restart);
         for Row in Natural range 0 .. Natural (Input.Descriptor.Height) - 1 loop
            for Column in Natural range 0 .. Natural (Input.Descriptor.Width) - 1 loop
               declare
                  Differences : Difference_Array;
               begin
                  for Component in Component_Index range 1 .. 2 loop
                     Differences (Component) :=
                       Sample (Component, Column, Row) - Predicted (Component, Column, Row);
                  end loop;

                  if not Differences_Supported (Differences) then
                     return Results.Failure (Errors.Unsupported_Feature);
                  end if;
               end;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Encoded := Encoded + 1;
               if Restart /= 0
                 and then Restarts.MCUs_Until_Restart (Restart_State) = 0
                 and then Encoded /= Total
               then
                  Marker := Restarts.Expected_Marker (Restart_State);
                  Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Restart_Base := Encoded;
               end if;
            end loop;
         end loop;

         return Results.Success;
      end Validate_Differences;
   begin
      Outcome := Validate_Differences;
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Restart_Base := 0;
      Encoded := 0;

      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
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

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        (if Differential then
            Writers.Write_SOF15_Gray_Alpha (Output, Input.Descriptor.Width, Input.Descriptor.Height)
         else
            Writers.Write_SOF11_Gray_Alpha (Output, Input.Descriptor.Width, Input.Descriptor.Height));
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      Outcome :=
        Writers.Write_SOS_Lossless_Gray_Alpha
          (Output, Predictor => Predictor, Point_Transform => Point_Transform);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      for Row in Natural range 0 .. Natural (Input.Descriptor.Height) - 1 loop
         for Column in Natural range 0 .. Natural (Input.Descriptor.Width) - 1 loop
            declare
               Differences : Difference_Array;
            begin
               for Component in Component_Index range 1 .. 2 loop
                  Differences (Component) := Sample (Component, Column, Row) - Predicted (Component, Column, Row);
               end loop;

               Outcome := Write_Differences (Differences);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Outcome := Write_Restart_When_Due (Encoded /= Total);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;
      end loop;

      Outcome := Arithmetic.Finish (Arithmetic_Encoder);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Hierarchical and then not Differential then
         Outcome := Writers.Write_SOF15_Gray_Alpha (Output, Input.Descriptor.Width, Input.Descriptor.Height);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Writers.Write_SOS_Lossless_Gray_Alpha (Output);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Encode_Arithmetic_Zero_Residual_Scan
             (Output,
              Restart,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Components => 2);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Arithmetic_Lossless_Gray_Alpha_Image;

   function Encode_Arithmetic_Lossless_RGB_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      type Difference_Array is array (Component_Index range 1 .. 3) of Integer;
      Restart_State : Restarts.Restart_State;
      Restart_Base : Pixel_Count := 0;
      Encoded : Pixel_Count := 0;
      Total : constant Pixel_Count :=
        Pixel_Count (Input.Descriptor.Width) * Pixel_Count (Input.Descriptor.Height);
      Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
      type DC_Bin_By_Component is array (Component_Index range 1 .. 3) of
        Arithmetic.Probability_Bin_Array (0 .. 63);
      DC_Bins : DC_Bin_By_Component := [others => [others => Arithmetic.Initial_Probability_Bin]];
      DC_Contexts : Arithmetic.DC_Context_Array := [others => 0];
      Outcome : Results.Result;

      function RGB_At (Column, Row : Natural) return Colors.RGB_Sample is
        (Colors.Read_RGB (Input, Column, Row));

      function Component_Sample
        (Sample : Colors.RGB_Sample;
         Component : Component_Index) return Integer
      is
      begin
         case Component is
            when 1 =>
               return Integer (Sample.R) / (2 ** Natural (Point_Transform));
            when 2 =>
               return Integer (Sample.G) / (2 ** Natural (Point_Transform));
            when 3 =>
               return Integer (Sample.B) / (2 ** Natural (Point_Transform));
            when others =>
               return 0;
         end case;
      end Component_Sample;

      function Sample (Component : Component_Index; Column, Row : Natural) return Integer is
        (Component_Sample (RGB_At (Column, Row), Component));

      function Predicted (Component : Component_Index; Column, Row : Natural) return Integer is
         Ra : Integer;
         Rb : Integer;
         Rc : Integer;
      begin
         if Encoded = Restart_Base then
            return 2 ** (7 - Natural (Point_Transform));
         elsif Column = 0 then
            return Sample (Component, Column, Row - 1);
         elsif Row = 0 then
            return Sample (Component, Column - 1, Row);
         end if;

         Ra := Sample (Component, Column - 1, Row);
         Rb := Sample (Component, Column, Row - 1);
         Rc := Sample (Component, Column - 1, Row - 1);

         case Predictor is
            when 1 =>
               return Ra;
            when 2 =>
               return Rb;
            when 3 =>
               return Rc;
            when 4 =>
               return Ra + Rb - Rc;
            when 5 =>
               return Ra + (Rb - Rc) / 2;
            when 6 =>
               return Rb + (Ra - Rc) / 2;
            when 7 =>
               return (Ra + Rb) / 2;
         end case;
      end Predicted;

      function Write_Restart_When_Due (More_Samples : Boolean) return Results.Result is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Samples then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Writers.Write_Marker (Output, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Arithmetic.Reset (Arithmetic_Encoder);
            DC_Bins := [others => [others => Arithmetic.Initial_Probability_Bin]];
            DC_Contexts := [others => 0];
            Restart_Base := Encoded;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;

      function Differences_Supported (Differences : Difference_Array) return Boolean is
         pragma Unreferenced (Differences);
      begin
         return True;
      end Differences_Supported;

      function Write_Differences (Differences : Difference_Array) return Results.Result is
         Outcome : Results.Result;
         Events : Arithmetic.DC_Difference_Event_Result;
      begin
         for Component in Component_Index range 1 .. 3 loop
            Events :=
              Arithmetic.Encode_DC_Difference_Events
                (Arithmetic.DC_Difference (Differences (Component)),
                 DC_Contexts (Component),
                 16#5A#);
            if not Results.Succeeded (Events.Outcome) then
               return Events.Outcome;
            end if;

            for Event_Index in 1 .. Events.Length loop
               Outcome :=
                 Arithmetic.Encode_Bit
                   (Arithmetic_Encoder,
                    DC_Bins (Component) (Events.Events (Event_Index).Bin_Index),
                    Events.Events (Event_Index).Decision);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;

            DC_Contexts (Component) := Events.Final_Context;
         end loop;

         return Results.Success;
      end Write_Differences;

      function Validate_Differences return Results.Result is
         Marker : Marker_Code;
      begin
         Restarts.Configure (Restart_State, Restart);
         for Row in Natural range 0 .. Natural (Input.Descriptor.Height) - 1 loop
            for Column in Natural range 0 .. Natural (Input.Descriptor.Width) - 1 loop
               declare
                  Differences : Difference_Array;
               begin
                  for Component in Component_Index range 1 .. 3 loop
                     Differences (Component) :=
                       Sample (Component, Column, Row) - Predicted (Component, Column, Row);
                  end loop;

                  if not Differences_Supported (Differences) then
                     return Results.Failure (Errors.Unsupported_Feature);
                  end if;
               end;

               Outcome := Restarts.Advance_MCU (Restart_State);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Encoded := Encoded + 1;
               if Restart /= 0
                 and then Restarts.MCUs_Until_Restart (Restart_State) = 0
                 and then Encoded /= Total
               then
                  Marker := Restarts.Expected_Marker (Restart_State);
                  Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
                  if not Results.Succeeded (Outcome) then
                     return Outcome;
                  end if;

                  Restart_Base := Encoded;
               end if;
            end loop;
         end loop;

         return Results.Success;
      end Validate_Differences;
   begin
      Outcome := Validate_Differences;
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Restart_Base := 0;
      Encoded := 0;

      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
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

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        (if Differential then
            Writers.Write_SOF15_RGB (Output, Input.Descriptor.Width, Input.Descriptor.Height)
         else
            Writers.Write_SOF11_RGB (Output, Input.Descriptor.Width, Input.Descriptor.Height));
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      Outcome :=
        Writers.Write_SOS_Lossless_RGB
          (Output, Predictor => Predictor, Point_Transform => Point_Transform);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      for Row in Natural range 0 .. Natural (Input.Descriptor.Height) - 1 loop
         for Column in Natural range 0 .. Natural (Input.Descriptor.Width) - 1 loop
            declare
               Differences : Difference_Array;
            begin
            for Component in Component_Index range 1 .. 3 loop
               Differences (Component) := Sample (Component, Column, Row) - Predicted (Component, Column, Row);
            end loop;

            Outcome := Write_Differences (Differences);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
            end;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Outcome := Write_Restart_When_Due (Encoded /= Total);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;
      end loop;

      Outcome := Arithmetic.Finish (Arithmetic_Encoder);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Hierarchical and then not Differential then
         Outcome := Writers.Write_SOF15_RGB (Output, Input.Descriptor.Width, Input.Descriptor.Height);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Writers.Write_SOS_Lossless_RGB (Output);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Encode_Arithmetic_Zero_Residual_Scan
             (Output,
              Restart,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Components => 3);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Arithmetic_Lossless_RGB_Image;

   function Encode_Arithmetic_Lossless_CMYK_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      YCCK : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      type Difference_Array is array (Component_Index range 1 .. 4) of Integer;
      Restart_State : Restarts.Restart_State;
      Restart_Base : Pixel_Count := 0;
      Encoded : Pixel_Count := 0;
      Total : constant Pixel_Count :=
        Pixel_Count (Input.Descriptor.Width) * Pixel_Count (Input.Descriptor.Height);
      Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
      type DC_Bin_By_Component is array (Component_Index range 1 .. 4) of
        Arithmetic.Probability_Bin_Array (0 .. 63);
      DC_Bins : DC_Bin_By_Component := [others => [others => Arithmetic.Initial_Probability_Bin]];
      DC_Contexts : Arithmetic.DC_Context_Array := [others => 0];
      Outcome : Results.Result;

      function CMYK_At (Column, Row : Natural) return Colors.CMYK_Sample is
        ((if YCCK then Colors.Read_YCCK (Input, Column, Row) else Colors.Read_CMYK (Input, Column, Row)));

      function Component_Sample
        (Sample : Colors.CMYK_Sample;
         Component : Component_Index) return Integer
      is
      begin
         case Component is
            when 1 =>
               return Integer (Sample.C) / (2 ** Natural (Point_Transform));
            when 2 =>
               return Integer (Sample.M) / (2 ** Natural (Point_Transform));
            when 3 =>
               return Integer (Sample.Y) / (2 ** Natural (Point_Transform));
            when 4 =>
               return Integer (Sample.K) / (2 ** Natural (Point_Transform));
            when others =>
               return 0;
         end case;
      end Component_Sample;

      function Sample (Component : Component_Index; Column, Row : Natural) return Integer is
        (Component_Sample (CMYK_At (Column, Row), Component));

      function Predicted (Component : Component_Index; Column, Row : Natural) return Integer is
         Ra : Integer;
         Rb : Integer;
         Rc : Integer;
      begin
         if Encoded = Restart_Base then
            return 2 ** (7 - Natural (Point_Transform));
         elsif Column = 0 then
            return Sample (Component, Column, Row - 1);
         elsif Row = 0 then
            return Sample (Component, Column - 1, Row);
         end if;

         Ra := Sample (Component, Column - 1, Row);
         Rb := Sample (Component, Column, Row - 1);
         Rc := Sample (Component, Column - 1, Row - 1);

         case Predictor is
            when 1 =>
               return Ra;
            when 2 =>
               return Rb;
            when 3 =>
               return Rc;
            when 4 =>
               return Ra + Rb - Rc;
            when 5 =>
               return Ra + (Rb - Rc) / 2;
            when 6 =>
               return Rb + (Ra - Rc) / 2;
            when 7 =>
               return (Ra + Rb) / 2;
         end case;
      end Predicted;

      function Write_Restart_When_Due (More_Samples : Boolean) return Results.Result is
         Marker : Marker_Code;
         Restart_Outcome : Results.Result;
      begin
         if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Samples then
            return Results.Success;
         end if;

         Marker := Restarts.Expected_Marker (Restart_State);
         Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Writers.Write_Marker (Output, Marker);
         if not Results.Succeeded (Restart_Outcome) then
            return Restart_Outcome;
         end if;

         Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
         if Results.Succeeded (Restart_Outcome) then
            Arithmetic.Reset (Arithmetic_Encoder);
            DC_Bins := [others => [others => Arithmetic.Initial_Probability_Bin]];
            DC_Contexts := [others => 0];
            Restart_Base := Encoded;
         end if;

         return Restart_Outcome;
      end Write_Restart_When_Due;

      function Write_Differences (Differences : Difference_Array) return Results.Result is
         Outcome : Results.Result;
         Events : Arithmetic.DC_Difference_Event_Result;
      begin
         for Component in Component_Index range 1 .. 4 loop
            Events :=
              Arithmetic.Encode_DC_Difference_Events
                (Arithmetic.DC_Difference (Differences (Component)),
                 DC_Contexts (Component),
                 16#5A#);
            if not Results.Succeeded (Events.Outcome) then
               return Events.Outcome;
            end if;

            for Event_Index in 1 .. Events.Length loop
               Outcome :=
                 Arithmetic.Encode_Bit
                   (Arithmetic_Encoder,
                    DC_Bins (Component) (Events.Events (Event_Index).Bin_Index),
                    Events.Events (Event_Index).Decision);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;

            DC_Contexts (Component) := Events.Final_Context;
         end loop;

         return Results.Success;
      end Write_Differences;
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

      Outcome :=
        Writers.Write_DAC
          (Output,
           Arithmetic.DC,
           Index => 0,
           Conditioning => 16#5A#);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        (if Differential then
            Writers.Write_SOF15_CMYK (Output, Input.Descriptor.Width, Input.Descriptor.Height)
         else
            Writers.Write_SOF11_CMYK (Output, Input.Descriptor.Width, Input.Descriptor.Height));
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      Outcome :=
        Writers.Write_SOS_Lossless_CMYK
          (Output, Predictor => Predictor, Point_Transform => Point_Transform);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Restarts.Configure (Restart_State, Restart);
      for Row in Natural range 0 .. Natural (Input.Descriptor.Height) - 1 loop
         for Column in Natural range 0 .. Natural (Input.Descriptor.Width) - 1 loop
            declare
               Differences : Difference_Array;
            begin
               for Component in Component_Index range 1 .. 4 loop
                  Differences (Component) := Sample (Component, Column, Row) - Predicted (Component, Column, Row);
               end loop;

               Outcome := Write_Differences (Differences);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end;

            Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Encoded := Encoded + 1;
            Outcome := Write_Restart_When_Due (Encoded /= Total);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end loop;
      end loop;

      Outcome := Arithmetic.Finish (Arithmetic_Encoder);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Hierarchical and then not Differential then
         Outcome := Writers.Write_SOF15_CMYK (Output, Input.Descriptor.Width, Input.Descriptor.Height);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Writers.Write_SOS_Lossless_CMYK (Output);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Encode_Arithmetic_Zero_Residual_Scan
             (Output,
              Restart,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Components => 4);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Arithmetic_Lossless_CMYK_Image;

   function Encode_Lossless_RGB_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      DC_Definition : constant Huffman.Huffman_Definition := Huffman.Standard_Luminance_DC;
      Outcome : Results.Result;
   begin
      if Huffman.Symbol_Total (DC_Definition) = 0 then
         return Results.Failure (Errors.Internal_Invariant_Failed);
      end if;

      Outcome := Write_SOI_And_Metadata (Output, Encoded_Metadata);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_JFIF_APP0 (Output);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Writers.Write_DHT (Output, Huffman.DC, 0, DC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        (if Differential then
            Writers.Write_SOF7_RGB (Output, Input.Descriptor.Width, Input.Descriptor.Height)
         else
            Writers.Write_SOF3_RGB (Output, Input.Descriptor.Width, Input.Descriptor.Height));
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      Outcome :=
        Writers.Write_SOS_Lossless_RGB
          (Output, Predictor => Predictor, Point_Transform => Point_Transform);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Encode_Lossless_RGB_Scan
          (Output, Input, DC_Definition, Restart, Predictor, Point_Transform);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Hierarchical and then not Differential then
         Outcome := Writers.Write_SOF7_RGB (Output, Input.Descriptor.Width, Input.Descriptor.Height);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Writers.Write_SOS_Lossless_RGB (Output);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Encode_Huffman_Zero_Residual_Scan
             (Output,
              DC_Definition,
              Restart,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Components => 3);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Lossless_RGB_Image;

   function Encode_Lossless_CMYK_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Predictor : Lossless_Predictor_Selection := 1;
      Point_Transform : Lossless_Point_Transform_Value := 0;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      YCCK : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      DC_Definition : constant Huffman.Huffman_Definition := Huffman.Standard_Luminance_DC;
      Outcome : Results.Result;
   begin
      if Huffman.Symbol_Total (DC_Definition) = 0 then
         return Results.Failure (Errors.Internal_Invariant_Failed);
      end if;

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

      Outcome := Writers.Write_DHT (Output, Huffman.DC, 0, DC_Definition);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome := Write_DHP_If_Hierarchical (Output, Hierarchical);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        (if Differential then
            Writers.Write_SOF7_CMYK (Output, Input.Descriptor.Width, Input.Descriptor.Height)
         else
            Writers.Write_SOF3_CMYK (Output, Input.Descriptor.Width, Input.Descriptor.Height));
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Restart /= 0 then
         Outcome := Writers.Write_DRI (Output, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      Outcome :=
        Writers.Write_SOS_Lossless_CMYK
          (Output, Predictor => Predictor, Point_Transform => Point_Transform);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      Outcome :=
        Encode_Lossless_CMYK_Scan
          (Output, Input, DC_Definition, Restart, Predictor, Point_Transform, YCCK);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      if Hierarchical and then not Differential then
         Outcome := Writers.Write_SOF7_CMYK (Output, Input.Descriptor.Width, Input.Descriptor.Height);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Writers.Write_SOS_Lossless_CMYK (Output);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Encode_Huffman_Zero_Residual_Scan
             (Output,
              DC_Definition,
              Restart,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Components => 4);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end if;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Lossless_CMYK_Image;

   function Encode_Arithmetic_CMYK_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      YCCK : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      Quantization_Table : constant Quantization.Quantization_Table := Quantization.Luma_Table_For_Quality (Quality);
      Width_N : constant Natural := Natural (Input.Descriptor.Width);
      Height_N : constant Natural := Natural (Input.Descriptor.Height);
      Padded_Width : constant Image_Width := Image_Width (Ceiling_Divide (Width_N, 8) * 8);
      Padded_Height : constant Image_Height := Image_Height (Ceiling_Divide (Height_N, 8) * 8);
      Full_Count : constant Byte_Count := Plane_Sample_Count (Input.Descriptor.Width, Input.Descriptor.Height);
      Padded_Count : constant Byte_Count := Plane_Sample_Count (Padded_Width, Padded_Height);
      Block_Total : constant Block_Count :=
        Block_Count (Positive (Natural (Padded_Width) / 8)) * Block_Count (Positive (Natural (Padded_Height) / 8));
      Outcome : Results.Result;
   begin
      if not Fits_Positive_Range (Full_Count)
        or else not Fits_Positive_Range (Padded_Count)
        or else Block_Total > Block_Count (Positive'Last)
      then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      declare
         C_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         M_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         Y_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         K_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         C_Padded : Streams.Byte_Array (1 .. Positive (Padded_Count)) := [others => 0];
         M_Padded : Streams.Byte_Array (1 .. Positive (Padded_Count)) := [others => 0];
         Y_Padded : Streams.Byte_Array (1 .. Positive (Padded_Count)) := [others => 0];
         K_Padded : Streams.Byte_Array (1 .. Positive (Padded_Count)) := [others => 0];
         C_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Block_Total)) := [others => [others => 0]];
         M_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Block_Total)) := [others => [others => 0]];
         Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Block_Total)) := [others => [others => 0]];
         K_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Block_Total)) := [others => [others => 0]];
         Plane_Result : Image_Blocks.Plane_Result;
         Block_Result : Image_Blocks.Image_Block_Result;
      begin
         Plane_Result := Fill_CMYK_Planes (Input, C_Full, M_Full, Y_Full, K_Full, YCCK);
         if not Results.Succeeded (Plane_Result.Outcome) then
            return Plane_Result.Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (C_Full, Input.Descriptor.Width, Input.Descriptor.Height, Padded_Width, Padded_Height, C_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (M_Full, Input.Descriptor.Width, Input.Descriptor.Height, Padded_Width, Padded_Height, M_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (Y_Full, Input.Descriptor.Width, Input.Descriptor.Height, Padded_Width, Padded_Height, Y_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (K_Full, Input.Descriptor.Width, Input.Descriptor.Height, Padded_Width, Padded_Height, K_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (C_Padded, Padded_Width, Padded_Height, Quantization_Table, C_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (M_Padded, Padded_Width, Padded_Height, Quantization_Table, M_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Y_Padded, Padded_Width, Padded_Height, Quantization_Table, Y_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (K_Padded, Padded_Width, Padded_Height, Quantization_Table, K_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         if not Arithmetic_Blocks_Supported (C_Blocks, Restart)
           or else not Arithmetic_Blocks_Supported (M_Blocks, Restart)
           or else not Arithmetic_Blocks_Supported (Y_Blocks, Restart)
           or else not Arithmetic_Blocks_Supported (K_Blocks, Restart)
         then
            return Results.Failure (Errors.Unsupported_Feature);
         end if;

         Outcome :=
           Write_Arithmetic_CMYK_Headers
             (Output, Input, Quantization_Table, Restart, Differential, Hierarchical, YCCK, Encoded_Metadata);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output,
              Component => Component_Identifier (Character'Pos ('C')),
              Spectral_Start => 0,
              Spectral_End => 63,
              DC_Table => 0,
              AC_Table => 0);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_Arithmetic_Blocks (Output, C_Blocks, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output,
              Component => Component_Identifier (Character'Pos ('M')),
              Spectral_Start => 0,
              Spectral_End => 63,
              DC_Table => 0,
              AC_Table => 0);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_Arithmetic_Blocks (Output, M_Blocks, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output,
              Component => Component_Identifier (Character'Pos ('Y')),
              Spectral_Start => 0,
              Spectral_End => 63,
              DC_Table => 0,
              AC_Table => 0);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_Arithmetic_Blocks (Output, Y_Blocks, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output,
              Component => Component_Identifier (Character'Pos ('K')),
              Spectral_Start => 0,
              Spectral_End => 63,
              DC_Table => 0,
              AC_Table => 0);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_Arithmetic_Blocks (Output, K_Blocks, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         if Hierarchical and then not Differential then
            Outcome :=
              Write_DCT_SOF_CMYK
                (Output,
                 Marker => Markers.SOF13,
                 Width => Input.Descriptor.Width,
                 Height => Input.Descriptor.Height);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            declare
               C_Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (C_Blocks'Range) :=
                 [others => [others => 0]];
               M_Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (M_Blocks'Range) :=
                 [others => [others => 0]];
               Y_Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (Y_Blocks'Range) :=
                 [others => [others => 0]];
               K_Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (K_Blocks'Range) :=
                 [others => [others => 0]];
            begin
               Outcome :=
                 Writers.Write_SOS_Component_Progressive
                   (Output,
                    Component => Component_Identifier (Character'Pos ('C')),
                    Spectral_Start => 0,
                    Spectral_End => 63,
                    DC_Table => 0,
                    AC_Table => 0);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Encode_Arithmetic_Blocks (Output, C_Residual_Blocks, Restart);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome :=
                 Writers.Write_SOS_Component_Progressive
                   (Output,
                    Component => Component_Identifier (Character'Pos ('M')),
                    Spectral_Start => 0,
                    Spectral_End => 63,
                    DC_Table => 0,
                    AC_Table => 0);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Encode_Arithmetic_Blocks (Output, M_Residual_Blocks, Restart);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome :=
                 Writers.Write_SOS_Component_Progressive
                   (Output,
                    Component => Component_Identifier (Character'Pos ('Y')),
                    Spectral_Start => 0,
                    Spectral_End => 63,
                    DC_Table => 0,
                    AC_Table => 0);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Encode_Arithmetic_Blocks (Output, Y_Residual_Blocks, Restart);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome :=
                 Writers.Write_SOS_Component_Progressive
                   (Output,
                    Component => Component_Identifier (Character'Pos ('K')),
                    Spectral_Start => 0,
                    Spectral_End => 63,
                    DC_Table => 0,
                    AC_Table => 0);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Encode_Arithmetic_Blocks (Output, K_Residual_Blocks, Restart);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end;
         end if;
      end;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Arithmetic_CMYK_Image;

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
   is
      Quantization_Table : constant Quantization.Quantization_Table := Quantization.Luma_Table_For_Quality (Quality);
      Width_N : constant Natural := Natural (Input.Descriptor.Width);
      Height_N : constant Natural := Natural (Input.Descriptor.Height);
      Padded_Width : constant Image_Width := Image_Width (Ceiling_Divide (Width_N, 8) * 8);
      Padded_Height : constant Image_Height := Image_Height (Ceiling_Divide (Height_N, 8) * 8);
      Full_Count : constant Byte_Count := Plane_Sample_Count (Input.Descriptor.Width, Input.Descriptor.Height);
      Padded_Count : constant Byte_Count := Plane_Sample_Count (Padded_Width, Padded_Height);
      Block_Total : constant Block_Count :=
        Block_Count (Positive (Natural (Padded_Width) / 8)) * Block_Count (Positive (Natural (Padded_Height) / 8));
      Outcome : Results.Result;
   begin
      if not Fits_Positive_Range (Full_Count)
        or else not Fits_Positive_Range (Padded_Count)
        or else Block_Total > Block_Count (Positive'Last)
      then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      declare
         C_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         M_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         Y_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         K_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         C_Padded : Streams.Byte_Array (1 .. Positive (Padded_Count)) := [others => 0];
         M_Padded : Streams.Byte_Array (1 .. Positive (Padded_Count)) := [others => 0];
         Y_Padded : Streams.Byte_Array (1 .. Positive (Padded_Count)) := [others => 0];
         K_Padded : Streams.Byte_Array (1 .. Positive (Padded_Count)) := [others => 0];
         C_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Block_Total)) := [others => [others => 0]];
         M_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Block_Total)) := [others => [others => 0]];
         Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Block_Total)) := [others => [others => 0]];
         K_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Block_Total)) := [others => [others => 0]];
         Shared_AC_Bins : Arithmetic.Probability_Bin_Array (0 .. 255) :=
           [others => Arithmetic.Initial_Probability_Bin];
         Plane_Result : Image_Blocks.Plane_Result;
         Block_Result : Image_Blocks.Image_Block_Result;
      begin
         Plane_Result := Fill_CMYK_Planes (Input, C_Full, M_Full, Y_Full, K_Full, YCCK);
         if not Results.Succeeded (Plane_Result.Outcome) then
            return Plane_Result.Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (C_Full, Input.Descriptor.Width, Input.Descriptor.Height, Padded_Width, Padded_Height, C_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Outcome :=
           Pad_Plane
             (M_Full, Input.Descriptor.Width, Input.Descriptor.Height, Padded_Width, Padded_Height, M_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Outcome :=
           Pad_Plane
             (Y_Full, Input.Descriptor.Width, Input.Descriptor.Height, Padded_Width, Padded_Height, Y_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Outcome :=
           Pad_Plane
             (K_Full, Input.Descriptor.Width, Input.Descriptor.Height, Padded_Width, Padded_Height, K_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (C_Padded, Padded_Width, Padded_Height, Quantization_Table, C_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;
         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (M_Padded, Padded_Width, Padded_Height, Quantization_Table, M_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;
         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Y_Padded, Padded_Width, Padded_Height, Quantization_Table, Y_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;
         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (K_Padded, Padded_Width, Padded_Height, Quantization_Table, K_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         if not Arithmetic_Blocks_Supported (C_Blocks, Restart)
           or else not Arithmetic_Blocks_Supported (M_Blocks, Restart)
           or else not Arithmetic_Blocks_Supported (Y_Blocks, Restart)
           or else not Arithmetic_Blocks_Supported (K_Blocks, Restart)
         then
            return Results.Failure (Errors.Unsupported_Feature);
         end if;

         Outcome :=
           Write_Arithmetic_Progressive_CMYK_Headers
             (Output, Input, Quantization_Table, Restart, Differential, Hierarchical, YCCK, Encoded_Metadata);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Encode_Arithmetic_Progressive_Fast_Preview_Blocks
             (Output, C_Blocks, Restart, Refine, Grayscale => False,
              Component => Component_Identifier (Character'Pos ('C')),
              Shared_AC_Bins => Shared_AC_Bins,
              Refinement_Bitplanes => 2);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Outcome :=
           Encode_Arithmetic_Progressive_Fast_Preview_Blocks
             (Output, M_Blocks, Restart, Refine, Grayscale => False,
              Component => Component_Identifier (Character'Pos ('M')),
              Shared_AC_Bins => Shared_AC_Bins,
              Refinement_Bitplanes => 2);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Outcome :=
           Encode_Arithmetic_Progressive_Fast_Preview_Blocks
             (Output, Y_Blocks, Restart, Refine, Grayscale => False,
              Component => Component_Identifier (Character'Pos ('Y')),
              Shared_AC_Bins => Shared_AC_Bins,
              Refinement_Bitplanes => 2);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Outcome :=
           Encode_Arithmetic_Progressive_Fast_Preview_Blocks
             (Output, K_Blocks, Restart, Refine, Grayscale => False,
              Component => Component_Identifier (Character'Pos ('K')),
              Shared_AC_Bins => Shared_AC_Bins,
              Refinement_Bitplanes => 2);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Arithmetic_Progressive_CMYK_Image;

   function Encode_Arithmetic_YCbCr_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Layout : Image_Blocks.Subsampling_Layout := Image_Blocks.Subsampling_444;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      Luma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Luma_Table_For_Quality (Quality);
      Chroma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Chroma_Table_For_Quality (Quality);
      Width_N : constant Natural := Natural (Input.Descriptor.Width);
      Height_N : constant Natural := Natural (Input.Descriptor.Height);
      H_Factor : constant Natural := Layout.Chroma_Horizontal_Factor;
      V_Factor : constant Natural := Layout.Chroma_Vertical_Factor;
      MCU_Columns_N : constant Natural := Ceiling_Divide (Width_N, H_Factor * 8);
      MCU_Rows_N : constant Natural := Ceiling_Divide (Height_N, V_Factor * 8);
      Chroma_Actual_Width : constant Image_Width := Image_Blocks.Chroma_Width (Input.Descriptor.Width, Layout);
      Chroma_Actual_Height : constant Image_Height := Image_Blocks.Chroma_Height (Input.Descriptor.Height, Layout);
      Y_Padded_Width : constant Image_Width := Image_Width (MCU_Columns_N * H_Factor * 8);
      Y_Padded_Height : constant Image_Height := Image_Height (MCU_Rows_N * V_Factor * 8);
      Chroma_Padded_Width : constant Image_Width :=
        Image_Width (MCU_Columns_N * 8);
      Chroma_Padded_Height : constant Image_Height :=
        Image_Height (MCU_Rows_N * 8);
      Full_Count : constant Byte_Count := Plane_Sample_Count (Input.Descriptor.Width, Input.Descriptor.Height);
      Chroma_Actual_Count : constant Byte_Count := Plane_Sample_Count (Chroma_Actual_Width, Chroma_Actual_Height);
      Y_Padded_Count : constant Byte_Count := Plane_Sample_Count (Y_Padded_Width, Y_Padded_Height);
      Chroma_Padded_Count : constant Byte_Count := Plane_Sample_Count (Chroma_Padded_Width, Chroma_Padded_Height);
      Y_Block_Columns : constant Positive := Positive (Natural (Y_Padded_Width) / 8);
      Y_Block_Rows : constant Positive := Positive (Natural (Y_Padded_Height) / 8);
      Chroma_Block_Columns : constant Positive := Positive (Natural (Chroma_Padded_Width) / 8);
      Chroma_Block_Rows : constant Positive := Positive (Natural (Chroma_Padded_Height) / 8);
      Y_Block_Total : constant Block_Count := Block_Count (Y_Block_Columns) * Block_Count (Y_Block_Rows);
      Chroma_Block_Total : constant Block_Count := Block_Count (Chroma_Block_Columns) * Block_Count (Chroma_Block_Rows);
      Outcome : Results.Result;
   begin
      if not Fits_Positive_Range (Full_Count)
        or else not Fits_Positive_Range (Chroma_Actual_Count)
        or else not Fits_Positive_Range (Y_Padded_Count)
        or else not Fits_Positive_Range (Chroma_Padded_Count)
        or else Y_Block_Total > Block_Count (Positive'Last)
        or else Chroma_Block_Total > Block_Count (Positive'Last)
      then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      declare
         Y_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         Cb_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         Cr_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         Cb_Actual : Streams.Byte_Array (1 .. Positive (Chroma_Actual_Count)) := [others => 0];
         Cr_Actual : Streams.Byte_Array (1 .. Positive (Chroma_Actual_Count)) := [others => 0];
         Y_Padded : Streams.Byte_Array (1 .. Positive (Y_Padded_Count)) := [others => 0];
         Cb_Padded : Streams.Byte_Array (1 .. Positive (Chroma_Padded_Count)) := [others => 0];
         Cr_Padded : Streams.Byte_Array (1 .. Positive (Chroma_Padded_Count)) := [others => 0];
         Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Y_Block_Total)) :=
           [others => [others => 0]];
         Cb_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Chroma_Block_Total)) :=
           [others => [others => 0]];
         Cr_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Chroma_Block_Total)) :=
           [others => [others => 0]];
         Plane_Result : Image_Blocks.Plane_Result;
         Block_Result : Image_Blocks.Image_Block_Result;
      begin
         Plane_Result := Image_Blocks.Fill_YCbCr_Planes (Input, Y_Full, Cb_Full, Cr_Full);
         if not Results.Succeeded (Plane_Result.Outcome) then
            return Plane_Result.Outcome;
         end if;

         Plane_Result :=
           Image_Blocks.Subsample_Chroma_Planes
             (Cb_Full,
              Cr_Full,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Layout,
              Cb_Actual,
              Cr_Actual);
         if not Results.Succeeded (Plane_Result.Outcome) then
            return Plane_Result.Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (Y_Full,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Y_Padded_Width,
              Y_Padded_Height,
              Y_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (Cb_Actual,
              Chroma_Actual_Width,
              Chroma_Actual_Height,
              Chroma_Padded_Width,
              Chroma_Padded_Height,
              Cb_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (Cr_Actual,
              Chroma_Actual_Width,
              Chroma_Actual_Height,
              Chroma_Padded_Width,
              Chroma_Padded_Height,
              Cr_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Y_Padded,
              Y_Padded_Width,
              Y_Padded_Height,
              Luma_Quantization,
              Y_Blocks,
              Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Cb_Padded,
              Chroma_Padded_Width,
              Chroma_Padded_Height,
              Chroma_Quantization,
              Cb_Blocks,
              Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Cr_Padded,
              Chroma_Padded_Width,
              Chroma_Padded_Height,
              Chroma_Quantization,
              Cr_Blocks,
              Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         if not Arithmetic_Blocks_Supported (Y_Blocks, Restart)
           or else not Arithmetic_Blocks_Supported (Cb_Blocks, Restart)
           or else not Arithmetic_Blocks_Supported (Cr_Blocks, Restart)
         then
            return Results.Failure (Errors.Unsupported_Feature);
         end if;

         Outcome :=
           Write_Arithmetic_Color_Headers
             (Output,
              Input,
              Luma_Quantization,
              Chroma_Quantization,
              Layout,
              Restart,
              Differential,
              Hierarchical,
              Encoded_Metadata);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output, Component => 1, Spectral_Start => 0, Spectral_End => 63, DC_Table => 0, AC_Table => 0);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_Arithmetic_Blocks (Output, Y_Blocks, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output, Component => 2, Spectral_Start => 0, Spectral_End => 63, DC_Table => 1, AC_Table => 1);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_Arithmetic_Blocks (Output, Cb_Blocks, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output, Component => 3, Spectral_Start => 0, Spectral_End => 63, DC_Table => 1, AC_Table => 1);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_Arithmetic_Blocks (Output, Cr_Blocks, Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         if Hierarchical and then not Differential then
            Outcome :=
              Write_DCT_SOF_YCbCr
                (Output,
                 Marker => Markers.SOF13,
                 Width => Input.Descriptor.Width,
                 Height => Input.Descriptor.Height,
                 Luma_Horizontal_Sampling => Layout.Chroma_Horizontal_Factor,
                 Luma_Vertical_Sampling => Layout.Chroma_Vertical_Factor);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            declare
               Y_Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (Y_Blocks'Range) :=
                 [others => [others => 0]];
               Cb_Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (Cb_Blocks'Range) :=
                 [others => [others => 0]];
               Cr_Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (Cr_Blocks'Range) :=
                 [others => [others => 0]];
            begin
               Outcome :=
                 Writers.Write_SOS_Component_Progressive
                   (Output, Component => 1, Spectral_Start => 0, Spectral_End => 63, DC_Table => 0, AC_Table => 0);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Encode_Arithmetic_Blocks (Output, Y_Residual_Blocks, Restart);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome :=
                 Writers.Write_SOS_Component_Progressive
                   (Output, Component => 2, Spectral_Start => 0, Spectral_End => 63, DC_Table => 1, AC_Table => 1);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Encode_Arithmetic_Blocks (Output, Cb_Residual_Blocks, Restart);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome :=
                 Writers.Write_SOS_Component_Progressive
                   (Output, Component => 3, Spectral_Start => 0, Spectral_End => 63, DC_Table => 1, AC_Table => 1);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Encode_Arithmetic_Blocks (Output, Cr_Residual_Blocks, Restart);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end;
         end if;
      end;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Arithmetic_YCbCr_Image;

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
   is
      Luma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Luma_Table_For_Quality (Quality);
      Chroma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Chroma_Table_For_Quality (Quality);
      Width_N : constant Natural := Natural (Input.Descriptor.Width);
      Height_N : constant Natural := Natural (Input.Descriptor.Height);
      H_Factor : constant Natural := Layout.Chroma_Horizontal_Factor;
      V_Factor : constant Natural := Layout.Chroma_Vertical_Factor;
      MCU_Columns_N : constant Natural := Ceiling_Divide (Width_N, H_Factor * 8);
      MCU_Rows_N : constant Natural := Ceiling_Divide (Height_N, V_Factor * 8);
      Y_Padded_Width : constant Image_Width := Image_Width (MCU_Columns_N * H_Factor * 8);
      Y_Padded_Height : constant Image_Height := Image_Height (MCU_Rows_N * V_Factor * 8);
      Chroma_Actual_Width : constant Image_Width := Image_Blocks.Chroma_Width (Input.Descriptor.Width, Layout);
      Chroma_Actual_Height : constant Image_Height := Image_Blocks.Chroma_Height (Input.Descriptor.Height, Layout);
      Chroma_Padded_Width : constant Image_Width := Image_Width (MCU_Columns_N * 8);
      Chroma_Padded_Height : constant Image_Height := Image_Height (MCU_Rows_N * 8);
      Full_Count : constant Byte_Count := Plane_Sample_Count (Input.Descriptor.Width, Input.Descriptor.Height);
      Chroma_Actual_Count : constant Byte_Count := Plane_Sample_Count (Chroma_Actual_Width, Chroma_Actual_Height);
      Y_Padded_Count : constant Byte_Count := Plane_Sample_Count (Y_Padded_Width, Y_Padded_Height);
      Chroma_Padded_Count : constant Byte_Count := Plane_Sample_Count (Chroma_Padded_Width, Chroma_Padded_Height);
      Y_Block_Columns : constant Positive := Positive (Natural (Y_Padded_Width) / 8);
      Y_Block_Rows : constant Positive := Positive (Natural (Y_Padded_Height) / 8);
      Chroma_Block_Columns : constant Positive := Positive (Natural (Chroma_Padded_Width) / 8);
      Chroma_Block_Rows : constant Positive := Positive (Natural (Chroma_Padded_Height) / 8);
      Y_Block_Total : constant Block_Count := Block_Count (Y_Block_Columns) * Block_Count (Y_Block_Rows);
      Chroma_Block_Total : constant Block_Count := Block_Count (Chroma_Block_Columns) * Block_Count (Chroma_Block_Rows);
      Outcome : Results.Result;
   begin
      if not Fits_Positive_Range (Full_Count)
        or else not Fits_Positive_Range (Chroma_Actual_Count)
        or else not Fits_Positive_Range (Y_Padded_Count)
        or else not Fits_Positive_Range (Chroma_Padded_Count)
        or else Y_Block_Total > Block_Count (Positive'Last)
        or else Chroma_Block_Total > Block_Count (Positive'Last)
      then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      declare
         Y_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         Cb_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         Cr_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         Cb_Actual : Streams.Byte_Array (1 .. Positive (Chroma_Actual_Count)) := [others => 0];
         Cr_Actual : Streams.Byte_Array (1 .. Positive (Chroma_Actual_Count)) := [others => 0];
         Y_Padded : Streams.Byte_Array (1 .. Positive (Y_Padded_Count)) := [others => 0];
         Cb_Padded : Streams.Byte_Array (1 .. Positive (Chroma_Padded_Count)) := [others => 0];
         Cr_Padded : Streams.Byte_Array (1 .. Positive (Chroma_Padded_Count)) := [others => 0];
         Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Y_Block_Total)) :=
           [others => [others => 0]];
         Cb_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Chroma_Block_Total)) :=
           [others => [others => 0]];
         Cr_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Chroma_Block_Total)) :=
           [others => [others => 0]];
         Shared_AC_Bins : Arithmetic.Probability_Bin_Array (0 .. 255) :=
           [others => Arithmetic.Initial_Probability_Bin];
         Plane_Result : Image_Blocks.Plane_Result;
         Block_Result : Image_Blocks.Image_Block_Result;
      begin
         Plane_Result := Image_Blocks.Fill_YCbCr_Planes (Input, Y_Full, Cb_Full, Cr_Full);
         if not Results.Succeeded (Plane_Result.Outcome) then
            return Plane_Result.Outcome;
         end if;

         Plane_Result :=
           Image_Blocks.Subsample_Chroma_Planes
             (Cb_Full,
              Cr_Full,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Layout,
              Cb_Actual,
              Cr_Actual);
         if not Results.Succeeded (Plane_Result.Outcome) then
            return Plane_Result.Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (Y_Full,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Y_Padded_Width,
              Y_Padded_Height,
              Y_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (Cb_Actual,
              Chroma_Actual_Width,
              Chroma_Actual_Height,
              Chroma_Padded_Width,
              Chroma_Padded_Height,
              Cb_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (Cr_Actual,
              Chroma_Actual_Width,
              Chroma_Actual_Height,
              Chroma_Padded_Width,
              Chroma_Padded_Height,
              Cr_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Y_Padded, Y_Padded_Width, Y_Padded_Height, Luma_Quantization, Y_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Cb_Padded,
              Chroma_Padded_Width,
              Chroma_Padded_Height,
              Chroma_Quantization,
              Cb_Blocks,
              Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Cr_Padded,
              Chroma_Padded_Width,
              Chroma_Padded_Height,
              Chroma_Quantization,
              Cr_Blocks,
              Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         if not Arithmetic_Blocks_Supported (Y_Blocks, Restart)
           or else not Arithmetic_Blocks_Supported (Cb_Blocks, Restart)
           or else not Arithmetic_Blocks_Supported (Cr_Blocks, Restart)
         then
            return Results.Failure (Errors.Unsupported_Feature);
         end if;

         Outcome :=
           Write_Arithmetic_Progressive_Color_Headers
             (Output,
              Input,
              Luma_Quantization,
              Chroma_Quantization,
              Layout,
              Restart,
              Differential,
              Hierarchical,
              Encoded_Metadata);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Encode_Arithmetic_Progressive_Fast_Preview_Blocks
             (Output,
              Y_Blocks,
              Restart,
              Refine,
              Grayscale => False,
              Component => 1,
              DC_Table => 0,
              AC_Table => 0,
              Shared_AC_Bins => Shared_AC_Bins,
              Refinement_Bitplanes => 2);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Encode_Arithmetic_Progressive_Fast_Preview_Blocks
             (Output,
              Cb_Blocks,
              Restart,
              Refine,
              Grayscale => False,
              Component => 2,
              DC_Table => 1,
              AC_Table => 1,
              Shared_AC_Bins => Shared_AC_Bins,
              Refinement_Bitplanes => 2);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Encode_Arithmetic_Progressive_Fast_Preview_Blocks
             (Output,
              Cr_Blocks,
              Restart,
              Refine,
              Grayscale => False,
              Component => 3,
              DC_Table => 1,
              AC_Table => 1,
              Shared_AC_Bins => Shared_AC_Bins,
              Refinement_Bitplanes => 2);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Arithmetic_Progressive_YCbCr_Image;

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
   is
      DC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Luminance_DC;
      AC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Luminance_AC;
      Luma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Luma_Table_For_Quality (Quality);
      Needed : Block_Count;
      Outcome : Results.Result;
   begin
      if Huffman.Symbol_Total (DC_Definition) = 0 or else Huffman.Symbol_Total (AC_Definition) = 0 then
         return Results.Failure (Errors.Internal_Invariant_Failed);
      end if;

      Needed := Image_Blocks.Required_Block_Count (Input.Descriptor);
      if Needed > Block_Count (Positive'Last) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      declare
         Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Needed)) := [others => [others => 0]];
         Image_Result : constant Image_Blocks.Image_Block_Result :=
           Image_Blocks.Encode_Gray_Blocks
             (Input, Luma_Quantization, Blocks, Mode => Image_Blocks.Full_Forward);
      begin
         if not Results.Succeeded (Image_Result.Outcome) then
            return Image_Result.Outcome;
         end if;

         if Optimize_Huffman and then not Refine then
            Optimized_Definitions_For_Blocks (Blocks, Restart, DC_Definition, AC_Definition);
         end if;

         Outcome :=
           Write_Progressive_Headers
             (Output,
              Input,
              DC_Definition,
              AC_Definition,
              Luma_Quantization,
              Restart,
              Differential,
              Hierarchical,
              Encoded_Metadata);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_Progressive_Blocks (Output, DC_Definition, AC_Definition, Blocks, Restart, Refine);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Progressive_Gray_Image;

   function Encode_Progressive_Gray_Alpha_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      DC_Definition : constant Huffman.Huffman_Definition := Huffman.Standard_Luminance_DC;
      AC_Definition : constant Huffman.Huffman_Definition := Huffman.Standard_Luminance_AC;
      Luma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Luma_Table_For_Quality (Quality);
      First_Al : constant Successive_Approximation_Value := (if Refine then 2 else 0);
      Needed : Block_Count;
      Samples_Needed : Byte_Count;
      Outcome : Results.Result;

      function Write_Component_DC
        (Component : Component_Identifier;
         Blocks : Jpeglib.Coefficients.DCT_Block_Array;
         Refinement : Boolean;
         Al : Successive_Approximation_Value) return Results.Result
      is
         Scan_Outcome : Results.Result;
      begin
         Scan_Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output,
              Component => Component,
              Spectral_Start => 0,
              Spectral_End => 0,
              Ah => (if Refinement then Al + 1 else 0),
              Al => Al,
              DC_Table => 0,
              AC_Table => 0);
         if not Results.Succeeded (Scan_Outcome) then
            return Scan_Outcome;
         end if;

         return
           Encode_Progressive_Component_Scan
             (Output,
              DC_Definition,
              Blocks,
              Restart,
              DC_Scan => True,
              Refinement => Refinement,
              Al => Al);
      end Write_Component_DC;

      function Write_Component_AC
        (Component : Component_Identifier;
         Blocks : Jpeglib.Coefficients.DCT_Block_Array;
         Refinement : Boolean;
         Al : Successive_Approximation_Value) return Results.Result
      is
         Scan_Outcome : Results.Result;
      begin
         Scan_Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output,
              Component => Component,
              Spectral_Start => 1,
              Spectral_End => 63,
              Ah => (if Refinement then Al + 1 else 0),
              Al => Al,
              DC_Table => 0,
              AC_Table => 0);
         if not Results.Succeeded (Scan_Outcome) then
            return Scan_Outcome;
         end if;

         return
           Encode_Progressive_Component_Scan
             (Output,
              AC_Definition,
              Blocks,
              Restart,
              DC_Scan => False,
              Refinement => Refinement,
              Al => Al);
      end Write_Component_AC;

   begin
      Needed := Image_Blocks.Required_Block_Count (Input.Descriptor);
      if Needed > Block_Count (Positive'Last) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      Samples_Needed := Byte_Count (Input.Descriptor.Width) * Byte_Count (Input.Descriptor.Height);
      if Samples_Needed > Byte_Count (Positive'Last) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      declare
         Gray_Plane : Streams.Byte_Array (1 .. Positive (Samples_Needed)) := [others => 0];
         Alpha_Plane : Streams.Byte_Array (1 .. Positive (Samples_Needed)) := [others => 0];
         Gray_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Needed)) := [others => [others => 0]];
         Alpha_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Needed)) := [others => [others => 0]];
         Plane_Result : constant Image_Blocks.Plane_Result :=
           Image_Blocks.Fill_Gray_Alpha_Planes (Input, Gray_Plane, Alpha_Plane);
         Gray_Result : Image_Blocks.Image_Block_Result;
         Alpha_Result : Image_Blocks.Image_Block_Result;
      begin
         if not Results.Succeeded (Plane_Result.Outcome) then
            return Plane_Result.Outcome;
         end if;

         Gray_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Gray_Plane,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Luma_Quantization,
              Gray_Blocks,
              Mode => Image_Blocks.Full_Forward);
         if not Results.Succeeded (Gray_Result.Outcome) then
            return Gray_Result.Outcome;
         end if;

         Alpha_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Alpha_Plane,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Luma_Quantization,
              Alpha_Blocks,
              Mode => Image_Blocks.Full_Forward);
         if not Results.Succeeded (Alpha_Result.Outcome) then
            return Alpha_Result.Outcome;
         end if;

         Outcome :=
           Write_Progressive_Gray_Alpha_Headers
             (Output,
              Input,
              DC_Definition,
              AC_Definition,
              Luma_Quantization,
              Restart,
              Differential,
              Hierarchical,
              Encoded_Metadata);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Write_Component_DC (1, Gray_Blocks, Refinement => False, Al => First_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Write_Component_DC (2, Alpha_Blocks, Refinement => False, Al => First_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Write_Component_AC (1, Gray_Blocks, Refinement => False, Al => First_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Write_Component_AC (2, Alpha_Blocks, Refinement => False, Al => First_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         if Refine then
            for Refinement_Al in reverse Successive_Approximation_Value range 0 .. First_Al - 1 loop
               Outcome := Write_Component_DC (1, Gray_Blocks, Refinement => True, Al => Refinement_Al);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Write_Component_DC (2, Alpha_Blocks, Refinement => True, Al => Refinement_Al);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Write_Component_AC (1, Gray_Blocks, Refinement => True, Al => Refinement_Al);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Write_Component_AC (2, Alpha_Blocks, Refinement => True, Al => Refinement_Al);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;
         end if;

      end;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Progressive_Gray_Alpha_Image;

   function Encode_Arithmetic_Progressive_Gray_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      Luma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Luma_Table_For_Quality (Quality);
      Needed : Block_Count;
      Outcome : Results.Result;
   begin
      Needed := Image_Blocks.Required_Block_Count (Input.Descriptor);
      if Needed > Block_Count (Positive'Last) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      declare
         Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Needed)) := [others => [others => 0]];
         Shared_AC_Bins : Arithmetic.Probability_Bin_Array (0 .. 255) :=
           [others => Arithmetic.Initial_Probability_Bin];
         Image_Result : constant Image_Blocks.Image_Block_Result :=
           Image_Blocks.Encode_Gray_Blocks
             (Input, Luma_Quantization, Blocks, Mode => Image_Blocks.Full_Forward);
      begin
         if not Results.Succeeded (Image_Result.Outcome) then
            return Image_Result.Outcome;
         end if;

         Outcome :=
           Write_Arithmetic_Progressive_Headers
             (Output, Input, Luma_Quantization, Restart, Differential, Hierarchical, Encoded_Metadata);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Encode_Arithmetic_Progressive_Fast_Preview_Blocks
             (Output,
              Blocks,
              Restart,
              Refine,
              Shared_AC_Bins => Shared_AC_Bins,
              Refinement_Bitplanes => 2);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Arithmetic_Progressive_Gray_Image;

   function Encode_Arithmetic_Progressive_Gray_Alpha_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      Luma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Luma_Table_For_Quality (Quality);
      First_Al : constant Successive_Approximation_Value := (if Refine then 2 else 0);
      Needed : Block_Count;
      Samples_Needed : Byte_Count;
      DC_Bins : Arithmetic.Probability_Bin_Array (0 .. 63) :=
        [others => Arithmetic.Initial_Probability_Bin];
      AC_Bins : Arithmetic.Probability_Bin_Array (0 .. 255) :=
        [others => Arithmetic.Initial_Probability_Bin];
      DC_Contexts : Arithmetic.DC_Context_Array := [others => 0];
      Predictors : array (Component_Index) of Arithmetic.DC_Difference := [others => 0];
      Outcome : Results.Result;

      function Write_Component_DC
        (Component : Component_Identifier;
         Blocks : Jpeglib.Coefficients.DCT_Block_Array;
         Refinement : Boolean;
         Al : Successive_Approximation_Value) return Results.Result
      is
         Component_Index_Value : constant Component_Index := Component_Index (Component);
         Restart_State : Restarts.Restart_State;
         Encoded : Block_Count := 0;
         Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
         DC_Refinement_Bin : Arithmetic.Probability_Bin := Arithmetic.Initial_Probability_Bin;
         Scan_Outcome : Results.Result;

         function Write_Restart_When_Due (More_Blocks : Boolean) return Results.Result is
            Marker : Marker_Code;
            Restart_Outcome : Results.Result;
         begin
            if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
               return Results.Success;
            end if;

            Marker := Restarts.Expected_Marker (Restart_State);
            Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Writers.Write_Marker (Output, Marker);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
            if Results.Succeeded (Restart_Outcome) then
               Arithmetic.Reset (Arithmetic_Encoder);
               DC_Bins := [others => Arithmetic.Initial_Probability_Bin];
               AC_Bins := [others => Arithmetic.Initial_Probability_Bin];
               DC_Contexts := [others => 0];
               Predictors := [others => 0];
               DC_Refinement_Bin := Arithmetic.Initial_Probability_Bin;
            end if;

            return Restart_Outcome;
         end Write_Restart_When_Due;
      begin
         Scan_Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output,
              Component => Component,
              Spectral_Start => 0,
              Spectral_End => 0,
              Ah => (if Refinement then Al + 1 else 0),
              Al => Al,
              DC_Table => 0,
              AC_Table => 0);
         if not Results.Succeeded (Scan_Outcome) then
            return Scan_Outcome;
         end if;

         Restarts.Configure (Restart_State, Restart);
         for Block of Blocks loop
            if Refinement then
               Scan_Outcome :=
                 Arithmetic.Encode_Progressive_DC_Refine
                    (Arithmetic_Encoder,
                     DC_Refinement_Bin,
                     Block,
                    Natural (Al));
            else
               declare
                  Scale : constant Arithmetic.DC_Difference := 2 ** Natural (First_Al);
                  DC_Value : constant Arithmetic.DC_Difference :=
                    Arithmetic.DC_Difference (Block (0)) / Scale;
                  Difference : constant Arithmetic.DC_Difference :=
                    DC_Value - Predictors (Component_Index_Value);
               begin
                  Scan_Outcome :=
                    Arithmetic.Encode_DC_Difference
                      (Arithmetic_Encoder,
                       DC_Bins,
                       DC_Contexts (Component_Index_Value),
                       Conditioning => 16#5A#,
                       Difference => Difference);
                  if Results.Succeeded (Scan_Outcome) then
                     Predictors (Component_Index_Value) := DC_Value;
                  end if;
               end;
            end if;
            if not Results.Succeeded (Scan_Outcome) then
               return Scan_Outcome;
            end if;

            Scan_Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Scan_Outcome) then
               return Scan_Outcome;
            end if;

            Encoded := Encoded + 1;
            Scan_Outcome := Write_Restart_When_Due (Encoded /= Block_Count (Blocks'Length));
            if not Results.Succeeded (Scan_Outcome) then
               return Scan_Outcome;
            end if;
         end loop;

         return Arithmetic.Finish (Arithmetic_Encoder);
      exception
         when Constraint_Error =>
            return Results.Failure (Errors.Internal_Invariant_Failed);
      end Write_Component_DC;

      function Write_Component_AC
        (Component : Component_Identifier;
         Blocks : Jpeglib.Coefficients.DCT_Block_Array;
         Block_Start : Positive;
         Decoded : in out Arithmetic.Decoded_Coefficient_Map;
         Refinement : Boolean;
         Al : Successive_Approximation_Value) return Results.Result
      is
         Restart_State : Restarts.Restart_State;
         Encoded : Block_Count := 0;
         Arithmetic_Encoder : Arithmetic.Encoder (Output'Unchecked_Access);
         Fixed_Bin : Arithmetic.Probability_Bin := Arithmetic.Initial_Probability_Bin;
         Scan_Outcome : Results.Result;

         function Write_Restart_When_Due (More_Blocks : Boolean) return Results.Result is
            Marker : Marker_Code;
            Restart_Outcome : Results.Result;
         begin
            if Restart = 0 or else Restarts.MCUs_Until_Restart (Restart_State) /= 0 or else not More_Blocks then
               return Results.Success;
            end if;

            Marker := Restarts.Expected_Marker (Restart_State);
            Restart_Outcome := Arithmetic.Finish (Arithmetic_Encoder);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Writers.Write_Marker (Output, Marker);
            if not Results.Succeeded (Restart_Outcome) then
               return Restart_Outcome;
            end if;

            Restart_Outcome := Restarts.Accept_Restart (Restart_State, Marker, 0);
            if Results.Succeeded (Restart_Outcome) then
               Arithmetic.Reset (Arithmetic_Encoder);
               DC_Bins := [others => Arithmetic.Initial_Probability_Bin];
               AC_Bins := [others => Arithmetic.Initial_Probability_Bin];
               DC_Contexts := [others => 0];
               Predictors := [others => 0];
               Fixed_Bin := Arithmetic.Initial_Probability_Bin;
            end if;

            return Restart_Outcome;
         end Write_Restart_When_Due;
      begin
         Scan_Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output,
              Component => Component,
              Spectral_Start => 1,
              Spectral_End => 63,
              Ah => (if Refinement then Al + 1 else 0),
              Al => Al,
              DC_Table => 0,
              AC_Table => 0);
         if not Results.Succeeded (Scan_Outcome) then
            return Scan_Outcome;
         end if;

         Restarts.Configure (Restart_State, Restart);
         for Block_Index in Blocks'Range loop
            declare
               Global_Block : constant Positive :=
                 Positive (Block_Start + Block_Index - Blocks'First);
            begin
               if Refinement then
                  Scan_Outcome :=
                    Arithmetic.Encode_Progressive_AC_Refine
                      (Arithmetic_Encoder,
                       AC_Bins,
                       Fixed_Bin,
                       AC_Conditioning => 0,
                       Spectral_Start => 1,
                       Spectral_End => 63,
                       Successive_Low => Natural (Al),
                       Decoded_Coefficients => Decoded,
                       Block_Number => Global_Block,
                       Block => Blocks (Block_Index));
               else
                  Scan_Outcome :=
                    Arithmetic.Encode_Progressive_AC_First
                      (Arithmetic_Encoder,
                       AC_Bins,
                       Fixed_Bin,
                       AC_Conditioning => 0,
                       Spectral_Start => 1,
                       Spectral_End => 63,
                       Successive_Low => Natural (Al),
                       Block => Blocks (Block_Index));
               end if;
            end;
            if not Results.Succeeded (Scan_Outcome) then
               return Scan_Outcome;
            end if;

            Scan_Outcome := Restarts.Advance_MCU (Restart_State);
            if not Results.Succeeded (Scan_Outcome) then
               return Scan_Outcome;
            end if;

            Encoded := Encoded + 1;
            Scan_Outcome := Write_Restart_When_Due (Encoded /= Block_Count (Blocks'Length));
            if not Results.Succeeded (Scan_Outcome) then
               return Scan_Outcome;
            end if;
         end loop;

         return Arithmetic.Finish (Arithmetic_Encoder);
      exception
         when Constraint_Error =>
            return Results.Failure (Errors.Internal_Invariant_Failed);
      end Write_Component_AC;
   begin
      Needed := Image_Blocks.Required_Block_Count (Input.Descriptor);
      if Needed > Block_Count (Positive'Last) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      Samples_Needed := Byte_Count (Input.Descriptor.Width) * Byte_Count (Input.Descriptor.Height);
      if Samples_Needed > Byte_Count (Positive'Last) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      declare
         Gray_Plane : Streams.Byte_Array (1 .. Positive (Samples_Needed)) := [others => 0];
         Alpha_Plane : Streams.Byte_Array (1 .. Positive (Samples_Needed)) := [others => 0];
         Gray_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Needed)) := [others => [others => 0]];
         Alpha_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Needed)) := [others => [others => 0]];
         Decoded : Arithmetic.Decoded_Coefficient_Map (1 .. Positive (Needed) * 2, Coefficient_Index) :=
           [others => [others => False]];
         Plane_Result : constant Image_Blocks.Plane_Result :=
           Image_Blocks.Fill_Gray_Alpha_Planes (Input, Gray_Plane, Alpha_Plane);
         Gray_Result : Image_Blocks.Image_Block_Result;
         Alpha_Result : Image_Blocks.Image_Block_Result;
      begin
         if not Results.Succeeded (Plane_Result.Outcome) then
            return Plane_Result.Outcome;
         end if;

         Gray_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Gray_Plane,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Luma_Quantization,
              Gray_Blocks,
              Mode => Image_Blocks.Full_Forward);
         if not Results.Succeeded (Gray_Result.Outcome) then
            return Gray_Result.Outcome;
         end if;

         Alpha_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Alpha_Plane,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Luma_Quantization,
              Alpha_Blocks,
              Mode => Image_Blocks.Full_Forward);
         if not Results.Succeeded (Alpha_Result.Outcome) then
            return Alpha_Result.Outcome;
         end if;

         if not Arithmetic_Blocks_Supported (Gray_Blocks, Restart)
           or else not Arithmetic_Blocks_Supported (Alpha_Blocks, Restart)
         then
            return Results.Failure (Errors.Unsupported_Feature);
         end if;

         for Block_Index in Gray_Blocks'Range loop
            for Index in Coefficient_Index range 1 .. 63 loop
               Decoded (Block_Index, Index) :=
                 Gray_Blocks (Block_Index) (Index) / (2 ** Natural (First_Al)) /= 0;
            end loop;
         end loop;

         for Block_Index in Alpha_Blocks'Range loop
            for Index in Coefficient_Index range 1 .. 63 loop
               Decoded (Positive (Needed) + Block_Index, Index) :=
                 Alpha_Blocks (Block_Index) (Index) / (2 ** Natural (First_Al)) /= 0;
            end loop;
         end loop;

         Outcome :=
           Write_Arithmetic_Progressive_Gray_Alpha_Headers
             (Output, Input, Luma_Quantization, Restart, Differential, Hierarchical, Encoded_Metadata);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Write_Component_DC (1, Gray_Blocks, Refinement => False, Al => First_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Write_Component_DC (2, Alpha_Blocks, Refinement => False, Al => First_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Write_Component_AC
             (1, Gray_Blocks, Block_Start => 1, Decoded => Decoded, Refinement => False, Al => First_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Write_Component_AC
             (2,
              Alpha_Blocks,
              Block_Start => Positive (Needed) + 1,
              Decoded => Decoded,
              Refinement => False,
              Al => First_Al);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         if Refine then
            for Refinement_Al in reverse Successive_Approximation_Value range 0 .. First_Al - 1 loop
               Outcome := Write_Component_DC (1, Gray_Blocks, Refinement => True, Al => Refinement_Al);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome := Write_Component_DC (2, Alpha_Blocks, Refinement => True, Al => Refinement_Al);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome :=
                 Write_Component_AC
                   (1,
                    Gray_Blocks,
                    Block_Start => 1,
                    Decoded => Decoded,
                    Refinement => True,
                    Al => Refinement_Al);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;

               Outcome :=
                 Write_Component_AC
                   (2,
                    Alpha_Blocks,
                    Block_Start => Positive (Needed) + 1,
                    Decoded => Decoded,
                    Refinement => True,
                    Al => Refinement_Al);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end loop;
         end if;
      end;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Arithmetic_Progressive_Gray_Alpha_Image;

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
   is
      Luma_DC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Luminance_DC;
      Luma_AC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Luminance_AC;
      Chroma_DC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Chrominance_DC;
      Chroma_AC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Chrominance_AC;
      Luma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Luma_Table_For_Quality (Quality);
      Chroma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Chroma_Table_For_Quality (Quality);
      Width_N : constant Natural := Natural (Input.Descriptor.Width);
      Height_N : constant Natural := Natural (Input.Descriptor.Height);
      H_Factor : constant Natural := Layout.Chroma_Horizontal_Factor;
      V_Factor : constant Natural := Layout.Chroma_Vertical_Factor;
      MCU_Columns_N : constant Natural := Ceiling_Divide (Width_N, H_Factor * 8);
      MCU_Rows_N : constant Natural := Ceiling_Divide (Height_N, V_Factor * 8);
      Y_Padded_Width : constant Image_Width := Image_Width (MCU_Columns_N * H_Factor * 8);
      Y_Padded_Height : constant Image_Height := Image_Height (MCU_Rows_N * V_Factor * 8);
      Chroma_Actual_Width : constant Image_Width := Image_Blocks.Chroma_Width (Input.Descriptor.Width, Layout);
      Chroma_Actual_Height : constant Image_Height := Image_Blocks.Chroma_Height (Input.Descriptor.Height, Layout);
      Chroma_Padded_Width : constant Image_Width := Image_Width (MCU_Columns_N * 8);
      Chroma_Padded_Height : constant Image_Height := Image_Height (MCU_Rows_N * 8);
      Full_Count : constant Byte_Count := Plane_Sample_Count (Input.Descriptor.Width, Input.Descriptor.Height);
      Chroma_Actual_Count : constant Byte_Count := Plane_Sample_Count (Chroma_Actual_Width, Chroma_Actual_Height);
      Y_Padded_Count : constant Byte_Count := Plane_Sample_Count (Y_Padded_Width, Y_Padded_Height);
      Chroma_Padded_Count : constant Byte_Count := Plane_Sample_Count (Chroma_Padded_Width, Chroma_Padded_Height);
      Y_Block_Columns : constant Positive := Positive (Natural (Y_Padded_Width) / 8);
      Y_Block_Rows : constant Positive := Positive (Natural (Y_Padded_Height) / 8);
      Chroma_Block_Columns : constant Positive := Positive (Natural (Chroma_Padded_Width) / 8);
      Chroma_Block_Rows : constant Positive := Positive (Natural (Chroma_Padded_Height) / 8);
      Y_Block_Total : constant Block_Count := Block_Count (Y_Block_Columns) * Block_Count (Y_Block_Rows);
      Chroma_Block_Total : constant Block_Count := Block_Count (Chroma_Block_Columns) * Block_Count (Chroma_Block_Rows);
      Outcome : Results.Result;
   begin
      if Huffman.Symbol_Total (Luma_DC_Definition) = 0
        or else Huffman.Symbol_Total (Luma_AC_Definition) = 0
        or else Huffman.Symbol_Total (Chroma_DC_Definition) = 0
        or else Huffman.Symbol_Total (Chroma_AC_Definition) = 0
      then
         return Results.Failure (Errors.Internal_Invariant_Failed);
      elsif not Fits_Positive_Range (Full_Count)
        or else not Fits_Positive_Range (Chroma_Actual_Count)
        or else not Fits_Positive_Range (Y_Padded_Count)
        or else not Fits_Positive_Range (Chroma_Padded_Count)
        or else Y_Block_Total > Block_Count (Positive'Last)
        or else Chroma_Block_Total > Block_Count (Positive'Last)
      then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      declare
         Y_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         Cb_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         Cr_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         Cb_Actual : Streams.Byte_Array (1 .. Positive (Chroma_Actual_Count)) := [others => 0];
         Cr_Actual : Streams.Byte_Array (1 .. Positive (Chroma_Actual_Count)) := [others => 0];
         Y_Padded : Streams.Byte_Array (1 .. Positive (Y_Padded_Count)) := [others => 0];
         Cb_Padded : Streams.Byte_Array (1 .. Positive (Chroma_Padded_Count)) := [others => 0];
         Cr_Padded : Streams.Byte_Array (1 .. Positive (Chroma_Padded_Count)) := [others => 0];
         Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Y_Block_Total)) :=
           [others => [others => 0]];
         Cb_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Chroma_Block_Total)) :=
           [others => [others => 0]];
         Cr_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Chroma_Block_Total)) :=
           [others => [others => 0]];
         Plane_Result : Image_Blocks.Plane_Result;
         Block_Result : Image_Blocks.Image_Block_Result;
      begin
         Plane_Result := Image_Blocks.Fill_YCbCr_Planes (Input, Y_Full, Cb_Full, Cr_Full);
         if not Results.Succeeded (Plane_Result.Outcome) then
            return Plane_Result.Outcome;
         end if;

         Plane_Result :=
           Image_Blocks.Subsample_Chroma_Planes
             (Cb_Full,
              Cr_Full,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Layout,
              Cb_Actual,
              Cr_Actual);
         if not Results.Succeeded (Plane_Result.Outcome) then
            return Plane_Result.Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (Y_Full,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Y_Padded_Width,
              Y_Padded_Height,
              Y_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (Cb_Actual,
              Chroma_Actual_Width,
              Chroma_Actual_Height,
              Chroma_Padded_Width,
              Chroma_Padded_Height,
              Cb_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (Cr_Actual,
              Chroma_Actual_Width,
              Chroma_Actual_Height,
              Chroma_Padded_Width,
              Chroma_Padded_Height,
              Cr_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Y_Padded, Y_Padded_Width, Y_Padded_Height, Luma_Quantization, Y_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Cb_Padded,
              Chroma_Padded_Width,
              Chroma_Padded_Height,
              Chroma_Quantization,
              Cb_Blocks,
              Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Cr_Padded,
              Chroma_Padded_Width,
              Chroma_Padded_Height,
              Chroma_Quantization,
              Cr_Blocks,
              Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         if Optimize_Huffman then
            Optimized_Definitions_For_YCbCr_Blocks
              (Y_Blocks,
               Cb_Blocks,
               Cr_Blocks,
               Y_Block_Columns,
               Chroma_Block_Columns,
               MCU_Columns_N,
               MCU_Rows_N,
               Layout,
               Restart,
               Luma_DC_Definition,
               Luma_AC_Definition,
               Chroma_DC_Definition,
               Chroma_AC_Definition);
         end if;

         Outcome :=
           Write_Color_Headers
             (Output,
              Input,
              Luma_DC_Definition,
              Luma_AC_Definition,
              Chroma_DC_Definition,
              Chroma_AC_Definition,
              Luma_Quantization,
              Chroma_Quantization,
              Layout,
              Restart,
              Differential,
              Hierarchical,
              Encoded_Metadata);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Encode_YCbCr_Blocks
             (Output,
              Luma_DC_Definition,
              Luma_AC_Definition,
              Chroma_DC_Definition,
              Chroma_AC_Definition,
              Y_Blocks,
              Cb_Blocks,
              Cr_Blocks,
              Y_Block_Columns,
              Chroma_Block_Columns,
              MCU_Columns_N,
              MCU_Rows_N,
              Layout,
              Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         if Hierarchical and then not Differential then
            Outcome :=
              Write_DCT_SOF_YCbCr
                (Output,
                 Marker => Markers.SOF5,
                 Width => Input.Descriptor.Width,
                 Height => Input.Descriptor.Height,
                 Luma_Horizontal_Sampling => Layout.Chroma_Horizontal_Factor,
                 Luma_Vertical_Sampling => Layout.Chroma_Vertical_Factor);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome := Writers.Write_SOS_YCbCr (Output);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            declare
               Y_Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (Y_Blocks'Range) :=
                 [others => [others => 0]];
               Cb_Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (Cb_Blocks'Range) :=
                 [others => [others => 0]];
               Cr_Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (Cr_Blocks'Range) :=
                 [others => [others => 0]];
            begin
               Outcome :=
                 Encode_YCbCr_Blocks
                   (Output,
                    Luma_DC_Definition,
                    Luma_AC_Definition,
                    Chroma_DC_Definition,
                    Chroma_AC_Definition,
                    Y_Residual_Blocks,
                    Cb_Residual_Blocks,
                    Cr_Residual_Blocks,
                    Y_Block_Columns,
                    Chroma_Block_Columns,
                    MCU_Columns_N,
                    MCU_Rows_N,
                    Layout,
                    Restart);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end;
         end if;
      end;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_YCbCr_Image;

   function Encode_CMYK_Image
     (Output : in out Streams.Destination'Class;
      Input : Images.Image_View;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Differential : Boolean := False;
      Hierarchical : Boolean := False;
      YCCK : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments) return Results.Result
   is
      DC_Definition : constant Huffman.Huffman_Definition := Huffman.Standard_Luminance_DC;
      AC_Definition : constant Huffman.Huffman_Definition := Huffman.Standard_Luminance_AC;
      Quantization_Table : constant Quantization.Quantization_Table := Quantization.Luma_Table_For_Quality (Quality);
      Width_N : constant Natural := Natural (Input.Descriptor.Width);
      Height_N : constant Natural := Natural (Input.Descriptor.Height);
      Padded_Width : constant Image_Width := Image_Width (Ceiling_Divide (Width_N, 8) * 8);
      Padded_Height : constant Image_Height := Image_Height (Ceiling_Divide (Height_N, 8) * 8);
      Full_Count : constant Byte_Count := Plane_Sample_Count (Input.Descriptor.Width, Input.Descriptor.Height);
      Padded_Count : constant Byte_Count := Plane_Sample_Count (Padded_Width, Padded_Height);
      Block_Columns : constant Positive := Positive (Natural (Padded_Width) / 8);
      Block_Rows : constant Positive := Positive (Natural (Padded_Height) / 8);
      Block_Total : constant Block_Count := Block_Count (Block_Columns) * Block_Count (Block_Rows);
      Outcome : Results.Result;
   begin
      if Huffman.Symbol_Total (DC_Definition) = 0 or else Huffman.Symbol_Total (AC_Definition) = 0 then
         return Results.Failure (Errors.Internal_Invariant_Failed);
      elsif not Fits_Positive_Range (Full_Count)
        or else not Fits_Positive_Range (Padded_Count)
        or else Block_Total > Block_Count (Positive'Last)
      then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      declare
         C_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         M_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         Y_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         K_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         C_Padded : Streams.Byte_Array (1 .. Positive (Padded_Count)) := [others => 0];
         M_Padded : Streams.Byte_Array (1 .. Positive (Padded_Count)) := [others => 0];
         Y_Padded : Streams.Byte_Array (1 .. Positive (Padded_Count)) := [others => 0];
         K_Padded : Streams.Byte_Array (1 .. Positive (Padded_Count)) := [others => 0];
         C_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Block_Total)) := [others => [others => 0]];
         M_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Block_Total)) := [others => [others => 0]];
         Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Block_Total)) := [others => [others => 0]];
         K_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Block_Total)) := [others => [others => 0]];
         Plane_Result : Image_Blocks.Plane_Result;
         Block_Result : Image_Blocks.Image_Block_Result;
      begin
         Plane_Result := Fill_CMYK_Planes (Input, C_Full, M_Full, Y_Full, K_Full, YCCK);
         if not Results.Succeeded (Plane_Result.Outcome) then
            return Plane_Result.Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (C_Full, Input.Descriptor.Width, Input.Descriptor.Height, Padded_Width, Padded_Height, C_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (M_Full, Input.Descriptor.Width, Input.Descriptor.Height, Padded_Width, Padded_Height, M_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (Y_Full, Input.Descriptor.Width, Input.Descriptor.Height, Padded_Width, Padded_Height, Y_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (K_Full, Input.Descriptor.Width, Input.Descriptor.Height, Padded_Width, Padded_Height, K_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (C_Padded, Padded_Width, Padded_Height, Quantization_Table, C_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (M_Padded, Padded_Width, Padded_Height, Quantization_Table, M_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Y_Padded, Padded_Width, Padded_Height, Quantization_Table, Y_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (K_Padded, Padded_Width, Padded_Height, Quantization_Table, K_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         Outcome :=
           Write_CMYK_Headers
             (Output,
              Input,
              DC_Definition,
              AC_Definition,
              Quantization_Table,
              Restart,
              Differential,
              Hierarchical,
              YCCK,
              Encoded_Metadata);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Encode_CMYK_Blocks
             (Output,
              DC_Definition,
              AC_Definition,
              C_Blocks,
              M_Blocks,
              Y_Blocks,
              K_Blocks,
              Block_Columns,
              Block_Rows,
              Restart);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         if Hierarchical and then not Differential then
            Outcome :=
              Write_DCT_SOF_CMYK
                (Output,
                 Marker => Markers.SOF5,
                 Width => Input.Descriptor.Width,
                 Height => Input.Descriptor.Height);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            Outcome :=
              Writers.Write_Segment
                (Output,
                 Markers.SOS,
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
                  0]);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;

            declare
               C_Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (C_Blocks'Range) :=
                 [others => [others => 0]];
               M_Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (M_Blocks'Range) :=
                 [others => [others => 0]];
               Y_Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (Y_Blocks'Range) :=
                 [others => [others => 0]];
               K_Residual_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (K_Blocks'Range) :=
                 [others => [others => 0]];
            begin
               Outcome :=
                 Encode_CMYK_Blocks
                   (Output,
                    DC_Definition,
                    AC_Definition,
                    C_Residual_Blocks,
                    M_Residual_Blocks,
                    Y_Residual_Blocks,
                    K_Residual_Blocks,
                    Block_Columns,
                    Block_Rows,
                    Restart);
               if not Results.Succeeded (Outcome) then
                  return Outcome;
               end if;
            end;
         end if;
      end;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_CMYK_Image;

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
   is
      DC_Definition : constant Huffman.Huffman_Definition := Huffman.Standard_Luminance_DC;
      AC_Definition : constant Huffman.Huffman_Definition := Huffman.Standard_Luminance_AC;
      Quantization_Table : constant Quantization.Quantization_Table := Quantization.Luma_Table_For_Quality (Quality);
      Width_N : constant Natural := Natural (Input.Descriptor.Width);
      Height_N : constant Natural := Natural (Input.Descriptor.Height);
      Padded_Width : constant Image_Width := Image_Width (Ceiling_Divide (Width_N, 8) * 8);
      Padded_Height : constant Image_Height := Image_Height (Ceiling_Divide (Height_N, 8) * 8);
      Full_Count : constant Byte_Count := Plane_Sample_Count (Input.Descriptor.Width, Input.Descriptor.Height);
      Padded_Count : constant Byte_Count := Plane_Sample_Count (Padded_Width, Padded_Height);
      Block_Total : constant Block_Count :=
        Block_Count (Positive (Natural (Padded_Width) / 8)) * Block_Count (Positive (Natural (Padded_Height) / 8));
      First_Al : constant Successive_Approximation_Value := (if Refine then 2 else 0);
      Outcome : Results.Result;

      function Encode_Component
        (Component : Component_Identifier;
         Blocks : Jpeglib.Coefficients.DCT_Block_Array) return Results.Result
      is
         Component_Outcome : Results.Result;
      begin
         Component_Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output, Component, Spectral_Start => 0, Spectral_End => 0, Al => First_Al);
         if not Results.Succeeded (Component_Outcome) then
            return Component_Outcome;
         end if;

         Component_Outcome :=
           Encode_Progressive_Component_Scan
             (Output, DC_Definition, Blocks, Restart, DC_Scan => True, Refinement => False, Al => First_Al);
         if not Results.Succeeded (Component_Outcome) then
            return Component_Outcome;
         end if;

         Component_Outcome :=
           Writers.Write_SOS_Component_Progressive
             (Output, Component, Spectral_Start => 1, Spectral_End => 63, Al => First_Al);
         if not Results.Succeeded (Component_Outcome) then
            return Component_Outcome;
         end if;

         Component_Outcome :=
           Encode_Progressive_Component_Scan
             (Output, AC_Definition, Blocks, Restart, DC_Scan => False, Refinement => False, Al => First_Al);
         if not Results.Succeeded (Component_Outcome) or else not Refine then
            return Component_Outcome;
         end if;

         for Refinement_Al in reverse Successive_Approximation_Value range 0 .. First_Al - 1 loop
            Component_Outcome :=
              Writers.Write_SOS_Component_Progressive
                (Output,
                 Component,
                 Spectral_Start => 0,
                 Spectral_End => 0,
                 Ah => Refinement_Al + 1,
                 Al => Refinement_Al);
            if not Results.Succeeded (Component_Outcome) then
               return Component_Outcome;
            end if;

            Component_Outcome :=
              Encode_Progressive_Component_Scan
                (Output, DC_Definition, Blocks, Restart, DC_Scan => True, Refinement => True, Al => Refinement_Al);
            if not Results.Succeeded (Component_Outcome) then
               return Component_Outcome;
            end if;

            Component_Outcome :=
              Writers.Write_SOS_Component_Progressive
                (Output,
                 Component,
                 Spectral_Start => 1,
                 Spectral_End => 63,
                 Ah => Refinement_Al + 1,
                 Al => Refinement_Al);
            if not Results.Succeeded (Component_Outcome) then
               return Component_Outcome;
            end if;

            Component_Outcome :=
              Encode_Progressive_Component_Scan
                (Output, AC_Definition, Blocks, Restart, DC_Scan => False, Refinement => True, Al => Refinement_Al);
            if not Results.Succeeded (Component_Outcome) then
               return Component_Outcome;
            end if;
         end loop;

         return Results.Success;
      end Encode_Component;
   begin
      if Huffman.Symbol_Total (DC_Definition) = 0 or else Huffman.Symbol_Total (AC_Definition) = 0 then
         return Results.Failure (Errors.Internal_Invariant_Failed);
      elsif not Fits_Positive_Range (Full_Count)
        or else not Fits_Positive_Range (Padded_Count)
        or else Block_Total > Block_Count (Positive'Last)
      then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      declare
         C_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         M_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         Y_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         K_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         C_Padded : Streams.Byte_Array (1 .. Positive (Padded_Count)) := [others => 0];
         M_Padded : Streams.Byte_Array (1 .. Positive (Padded_Count)) := [others => 0];
         Y_Padded : Streams.Byte_Array (1 .. Positive (Padded_Count)) := [others => 0];
         K_Padded : Streams.Byte_Array (1 .. Positive (Padded_Count)) := [others => 0];
         C_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Block_Total)) := [others => [others => 0]];
         M_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Block_Total)) := [others => [others => 0]];
         Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Block_Total)) := [others => [others => 0]];
         K_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Block_Total)) := [others => [others => 0]];
         Plane_Result : Image_Blocks.Plane_Result;
         Block_Result : Image_Blocks.Image_Block_Result;
      begin
         Plane_Result := Fill_CMYK_Planes (Input, C_Full, M_Full, Y_Full, K_Full, YCCK);
         if not Results.Succeeded (Plane_Result.Outcome) then
            return Plane_Result.Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (C_Full, Input.Descriptor.Width, Input.Descriptor.Height, Padded_Width, Padded_Height, C_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Outcome :=
           Pad_Plane
             (M_Full, Input.Descriptor.Width, Input.Descriptor.Height, Padded_Width, Padded_Height, M_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Outcome :=
           Pad_Plane
             (Y_Full, Input.Descriptor.Width, Input.Descriptor.Height, Padded_Width, Padded_Height, Y_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Outcome :=
           Pad_Plane
             (K_Full, Input.Descriptor.Width, Input.Descriptor.Height, Padded_Width, Padded_Height, K_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (C_Padded, Padded_Width, Padded_Height, Quantization_Table, C_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;
         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (M_Padded, Padded_Width, Padded_Height, Quantization_Table, M_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;
         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Y_Padded, Padded_Width, Padded_Height, Quantization_Table, Y_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;
         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (K_Padded, Padded_Width, Padded_Height, Quantization_Table, K_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         Outcome :=
           Write_Progressive_CMYK_Headers
             (Output, Input, DC_Definition, AC_Definition, Quantization_Table, Restart, Differential, Hierarchical,
              YCCK, Encoded_Metadata);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome := Encode_Component (Component_Identifier (Character'Pos ('C')), C_Blocks);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Outcome := Encode_Component (Component_Identifier (Character'Pos ('M')), M_Blocks);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Outcome := Encode_Component (Component_Identifier (Character'Pos ('Y')), Y_Blocks);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
         Outcome := Encode_Component (Component_Identifier (Character'Pos ('K')), K_Blocks);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Progressive_CMYK_Image;

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
   is
      Luma_DC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Luminance_DC;
      Luma_AC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Luminance_AC;
      Chroma_DC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Chrominance_DC;
      Chroma_AC_Definition : Huffman.Huffman_Definition := Huffman.Standard_Chrominance_AC;
      Luma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Luma_Table_For_Quality (Quality);
      Chroma_Quantization : constant Quantization.Quantization_Table :=
        Quantization.Chroma_Table_For_Quality (Quality);
      Width_N : constant Natural := Natural (Input.Descriptor.Width);
      Height_N : constant Natural := Natural (Input.Descriptor.Height);
      H_Factor : constant Natural := Layout.Chroma_Horizontal_Factor;
      V_Factor : constant Natural := Layout.Chroma_Vertical_Factor;
      MCU_Columns_N : constant Natural := Ceiling_Divide (Width_N, H_Factor * 8);
      MCU_Rows_N : constant Natural := Ceiling_Divide (Height_N, V_Factor * 8);
      Y_Padded_Width : constant Image_Width := Image_Width (MCU_Columns_N * H_Factor * 8);
      Y_Padded_Height : constant Image_Height := Image_Height (MCU_Rows_N * V_Factor * 8);
      Chroma_Actual_Width : constant Image_Width := Image_Blocks.Chroma_Width (Input.Descriptor.Width, Layout);
      Chroma_Actual_Height : constant Image_Height := Image_Blocks.Chroma_Height (Input.Descriptor.Height, Layout);
      Chroma_Padded_Width : constant Image_Width := Image_Width (MCU_Columns_N * 8);
      Chroma_Padded_Height : constant Image_Height := Image_Height (MCU_Rows_N * 8);
      Full_Count : constant Byte_Count := Plane_Sample_Count (Input.Descriptor.Width, Input.Descriptor.Height);
      Chroma_Actual_Count : constant Byte_Count := Plane_Sample_Count (Chroma_Actual_Width, Chroma_Actual_Height);
      Y_Padded_Count : constant Byte_Count := Plane_Sample_Count (Y_Padded_Width, Y_Padded_Height);
      Chroma_Padded_Count : constant Byte_Count := Plane_Sample_Count (Chroma_Padded_Width, Chroma_Padded_Height);
      Y_Component_Block_Columns : constant Positive := Positive (Ceiling_Divide (Width_N, 8));
      Y_Component_Block_Rows : constant Positive := Positive (Ceiling_Divide (Height_N, 8));
      Chroma_Component_Block_Columns : constant Positive :=
        Positive (Ceiling_Divide (Natural (Chroma_Actual_Width), 8));
      Chroma_Component_Block_Rows : constant Positive :=
        Positive (Ceiling_Divide (Natural (Chroma_Actual_Height), 8));
      Y_Block_Columns : constant Positive := Positive (Natural (Y_Padded_Width) / 8);
      Y_Block_Rows : constant Positive := Positive (Natural (Y_Padded_Height) / 8);
      Chroma_Block_Columns : constant Positive := Positive (Natural (Chroma_Padded_Width) / 8);
      Chroma_Block_Rows : constant Positive := Positive (Natural (Chroma_Padded_Height) / 8);
      Y_Block_Total : constant Block_Count := Block_Count (Y_Block_Columns) * Block_Count (Y_Block_Rows);
      Chroma_Block_Total : constant Block_Count := Block_Count (Chroma_Block_Columns) * Block_Count (Chroma_Block_Rows);
      Outcome : Results.Result;
   begin
      if Huffman.Symbol_Total (Luma_DC_Definition) = 0
        or else Huffman.Symbol_Total (Luma_AC_Definition) = 0
        or else Huffman.Symbol_Total (Chroma_DC_Definition) = 0
        or else Huffman.Symbol_Total (Chroma_AC_Definition) = 0
      then
         return Results.Failure (Errors.Internal_Invariant_Failed);
      elsif not Fits_Positive_Range (Full_Count)
        or else not Fits_Positive_Range (Chroma_Actual_Count)
        or else not Fits_Positive_Range (Y_Padded_Count)
        or else not Fits_Positive_Range (Chroma_Padded_Count)
        or else Y_Block_Total > Block_Count (Positive'Last)
        or else Chroma_Block_Total > Block_Count (Positive'Last)
      then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      declare
         Y_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         Cb_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         Cr_Full : Streams.Byte_Array (1 .. Positive (Full_Count)) := [others => 0];
         Cb_Actual : Streams.Byte_Array (1 .. Positive (Chroma_Actual_Count)) := [others => 0];
         Cr_Actual : Streams.Byte_Array (1 .. Positive (Chroma_Actual_Count)) := [others => 0];
         Y_Padded : Streams.Byte_Array (1 .. Positive (Y_Padded_Count)) := [others => 0];
         Cb_Padded : Streams.Byte_Array (1 .. Positive (Chroma_Padded_Count)) := [others => 0];
         Cr_Padded : Streams.Byte_Array (1 .. Positive (Chroma_Padded_Count)) := [others => 0];
         Y_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Y_Block_Total)) :=
           [others => [others => 0]];
         Cb_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Chroma_Block_Total)) :=
           [others => [others => 0]];
         Cr_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. Positive (Chroma_Block_Total)) :=
           [others => [others => 0]];
         Plane_Result : Image_Blocks.Plane_Result;
         Block_Result : Image_Blocks.Image_Block_Result;
      begin
         Plane_Result := Image_Blocks.Fill_YCbCr_Planes (Input, Y_Full, Cb_Full, Cr_Full);
         if not Results.Succeeded (Plane_Result.Outcome) then
            return Plane_Result.Outcome;
         end if;

         Plane_Result :=
           Image_Blocks.Subsample_Chroma_Planes
             (Cb_Full,
              Cr_Full,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Layout,
              Cb_Actual,
              Cr_Actual);
         if not Results.Succeeded (Plane_Result.Outcome) then
            return Plane_Result.Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (Y_Full,
              Input.Descriptor.Width,
              Input.Descriptor.Height,
              Y_Padded_Width,
              Y_Padded_Height,
              Y_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (Cb_Actual,
              Chroma_Actual_Width,
              Chroma_Actual_Height,
              Chroma_Padded_Width,
              Chroma_Padded_Height,
              Cb_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Pad_Plane
             (Cr_Actual,
              Chroma_Actual_Width,
              Chroma_Actual_Height,
              Chroma_Padded_Width,
              Chroma_Padded_Height,
              Cr_Padded);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Y_Padded, Y_Padded_Width, Y_Padded_Height, Luma_Quantization, Y_Blocks, Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Cb_Padded,
              Chroma_Padded_Width,
              Chroma_Padded_Height,
              Chroma_Quantization,
              Cb_Blocks,
              Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         Block_Result :=
           Image_Blocks.Encode_Plane_Blocks
             (Cr_Padded,
              Chroma_Padded_Width,
              Chroma_Padded_Height,
              Chroma_Quantization,
              Cr_Blocks,
              Image_Blocks.Full_Forward);
         if not Results.Succeeded (Block_Result.Outcome) then
            return Block_Result.Outcome;
         end if;

         if Optimize_Huffman and then not Refine then
            Optimized_Definitions_For_YCbCr_Blocks
              (Y_Blocks,
               Cb_Blocks,
               Cr_Blocks,
               Y_Block_Columns,
               Chroma_Block_Columns,
               MCU_Columns_N,
               MCU_Rows_N,
               Layout,
               Restart,
               Luma_DC_Definition,
               Luma_AC_Definition,
               Chroma_DC_Definition,
               Chroma_AC_Definition);
         end if;

         Outcome :=
           Write_Progressive_Color_Headers
             (Output,
              Input,
              Luma_DC_Definition,
              Luma_AC_Definition,
              Chroma_DC_Definition,
              Chroma_AC_Definition,
              Luma_Quantization,
              Chroma_Quantization,
              Layout,
              Restart,
              Differential,
              Hierarchical,
              Encoded_Metadata);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Encode_Progressive_YCbCr_Blocks
             (Output,
              Luma_DC_Definition,
              Luma_AC_Definition,
              Chroma_DC_Definition,
              Chroma_AC_Definition,
              Y_Blocks,
              Cb_Blocks,
              Cr_Blocks,
              Y_Block_Columns,
              Chroma_Block_Columns,
              Y_Component_Block_Columns,
              Y_Component_Block_Rows,
              Chroma_Component_Block_Columns,
              Chroma_Component_Block_Rows,
              MCU_Columns_N,
              MCU_Rows_N,
              Layout,
              Restart,
              Refine);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;
      end;

      return Writers.Write_Marker (Output, Markers.EOI);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Progressive_YCbCr_Image;
end Jpeglib.Internal.Baseline_Encoder;

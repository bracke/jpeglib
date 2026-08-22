with Jpeglib.Errors;
with Jpeglib.Internal.Encoder_Headers;
with Jpeglib.Internal.Encoder_Arithmetic_Scans;
with Jpeglib.Internal.Encoder_Baseline_Scans;
with Jpeglib.Internal.Encoder_Huffman_Optimization;
with Jpeglib.Internal.Encoder_Lossless_Scans;
with Jpeglib.Internal.Encoder_Progressive_Scans;
with Jpeglib.Internal.Encoder_Planes;
with Jpeglib.Internal.Arithmetic;
with Jpeglib.Internal.Huffman;
with Jpeglib.Internal.Markers;
with Jpeglib.Internal.Quantization;
with Jpeglib.Internal.Writers;

package body Jpeglib.Internal.Baseline_Encoder is
   use type Errors.Error_Code;
   use type Jpeglib.Coefficients.Component_Block_Layout;
   use type Huffman.Symbol_Count;
   use Jpeglib.Internal.Encoder_Headers;
   use Jpeglib.Internal.Encoder_Arithmetic_Scans;
   use Jpeglib.Internal.Encoder_Baseline_Scans;
   use Jpeglib.Internal.Encoder_Lossless_Scans;
   use Jpeglib.Internal.Encoder_Progressive_Scans;
   use Jpeglib.Internal.Encoder_Planes;

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
         Encoder_Huffman_Optimization.Optimized_Definitions_For_Blocks
           (Blocks, Restart, DC_Definition, AC_Definition);
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
         Encoder_Huffman_Optimization.Optimized_Definitions_For_YCbCr_Blocks
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
         Encoder_Huffman_Optimization.Optimized_Definitions_For_YCbCr_Blocks
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
         Encoder_Huffman_Optimization.Optimized_Definitions_For_Blocks
           (Blocks, Restart, DC_Definition, AC_Definition);
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
            Encoder_Huffman_Optimization.Optimized_Definitions_For_Blocks
              (Blocks, Restart, DC_Definition, AC_Definition);
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

      Outcome :=
        Encode_Arithmetic_Lossless_Gray_Scan
          (Output, Input, Restart, Predictor, Point_Transform);
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

      Outcome :=
        Encode_Arithmetic_Lossless_Gray_Alpha_Scan
          (Output, Input, Restart, Predictor, Point_Transform);
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

      Outcome :=
        Encode_Arithmetic_Lossless_RGB_Scan
          (Output, Input, Restart, Predictor, Point_Transform);
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

      Outcome :=
        Encode_Arithmetic_Lossless_CMYK_Scan
          (Output, Input, Restart, Predictor, Point_Transform, YCCK);
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
            Encoder_Huffman_Optimization.Optimized_Definitions_For_Blocks
              (Blocks, Restart, DC_Definition, AC_Definition);
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

         Outcome :=
           Write_Arithmetic_Progressive_Gray_Alpha_Headers
             (Output, Input, Luma_Quantization, Restart, Differential, Hierarchical, Encoded_Metadata);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         Outcome :=
           Encode_Arithmetic_Progressive_Gray_Alpha_Blocks
             (Output, Gray_Blocks, Alpha_Blocks, Restart, Refine);
         if not Results.Succeeded (Outcome) then
            return Outcome;
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
            Encoder_Huffman_Optimization.Optimized_Definitions_For_YCbCr_Blocks
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
            Encoder_Huffman_Optimization.Optimized_Definitions_For_YCbCr_Blocks
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

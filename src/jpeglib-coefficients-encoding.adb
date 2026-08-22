with Jpeglib.Errors;
with Jpeglib.Internal.Baseline_Encoder;

package body Jpeglib.Coefficients.Encoding is

   function Required_Blocks
     (Width : Image_Width;
      Height : Image_Height) return Block_Count
   is
      Block_Columns : constant Natural := (Natural (Width) + 7) / 8;
      Block_Rows : constant Natural := (Natural (Height) + 7) / 8;
   begin
      return Block_Count (Block_Columns * Block_Rows);
   end Required_Blocks;

   function Coefficients_Are_In_Baseline_Range
     (Blocks : DCT_Block_Array) return Boolean is
   begin
      for Block of Blocks loop
         for Coefficient of Block loop
            if Coefficient not in -16#7FFF# .. 16#7FFF# then
               return False;
            end if;
         end loop;
      end loop;

      return True;
   end Coefficients_Are_In_Baseline_Range;

   function Encode_Grayscale_Baseline
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : DCT_Block_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Optimize_Huffman : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments;
      Encode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is
      pragma Unreferenced (Encode_Limits);
   begin
      if Width > 65_535 or else Height > 65_535 then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      elsif Block_Count (Blocks'Length) /= Required_Blocks (Width, Height) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      elsif not Coefficients_Are_In_Baseline_Range (Blocks) then
         return Results.Failure (Errors.Coefficient_Invalid_Encoding);
      end if;

      return Jpeglib.Internal.Baseline_Encoder.Encode_Grayscale_Coefficients
        (Output,
         Width,
         Height,
         Blocks,
         Restart,
         Quality,
         Optimize_Huffman,
         Encoded_Metadata);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Grayscale_Baseline;

   function Encode_Grayscale_Progressive
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : DCT_Block_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Optimize_Huffman : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments;
      Encode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is
      pragma Unreferenced (Encode_Limits);
   begin
      if Width > 65_535 or else Height > 65_535 then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      elsif Block_Count (Blocks'Length) /= Required_Blocks (Width, Height) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      elsif not Coefficients_Are_In_Baseline_Range (Blocks) then
         return Results.Failure (Errors.Coefficient_Invalid_Encoding);
      end if;

      return Jpeglib.Internal.Baseline_Encoder.Encode_Progressive_Grayscale_Coefficients
        (Output,
         Width,
         Height,
         Blocks,
         Restart,
         Quality,
         Refine,
         Optimize_Huffman,
         Encoded_Metadata);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_Grayscale_Progressive;

   function Encode_YCbCr_Baseline
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : DCT_Block_Array;
      Layouts : Component_Block_Layout_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Optimize_Huffman : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments;
      Encode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is
      pragma Unreferenced (Encode_Limits);
   begin
      if Width > 65_535 or else Height > 65_535 then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      elsif Layouts'Length /= 3 or else Layouts'First /= 1 then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      elsif Total_Block_Count (Layouts) /= Block_Count (Blocks'Length) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      elsif not Coefficients_Are_In_Baseline_Range (Blocks) then
         return Results.Failure (Errors.Coefficient_Invalid_Encoding);
      end if;

      return Jpeglib.Internal.Baseline_Encoder.Encode_YCbCr_Coefficients
        (Output,
         Width,
         Height,
         Blocks,
         Layouts,
         Restart,
         Quality,
         Optimize_Huffman,
         Encoded_Metadata);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_YCbCr_Baseline;

   function Encode_YCbCr_Progressive
     (Output : in out Streams.Destination'Class;
      Width : Image_Width;
      Height : Image_Height;
      Blocks : DCT_Block_Array;
      Layouts : Component_Block_Layout_Array;
      Restart : Restart_Interval := 0;
      Quality : Positive := 75;
      Refine : Boolean := False;
      Optimize_Huffman : Boolean := False;
      Encoded_Metadata : Metadata.Encode_Segment_Array := Metadata.No_Encode_Segments;
      Encode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Results.Result
   is
      pragma Unreferenced (Encode_Limits);
   begin
      if Width > 65_535 or else Height > 65_535 then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      elsif Layouts'Length /= 3 or else Layouts'First /= 1 then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      elsif Total_Block_Count (Layouts) /= Block_Count (Blocks'Length) then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      elsif not Coefficients_Are_In_Baseline_Range (Blocks) then
         return Results.Failure (Errors.Coefficient_Invalid_Encoding);
      end if;

      return Jpeglib.Internal.Baseline_Encoder.Encode_Progressive_YCbCr_Coefficients
        (Output,
         Width,
         Height,
         Blocks,
         Layouts,
         Restart,
         Quality,
         Refine,
         Optimize_Huffman,
         Encoded_Metadata);
   exception
      when Constraint_Error =>
         return Results.Failure (Errors.Internal_Invariant_Failed);
   end Encode_YCbCr_Progressive;

end Jpeglib.Coefficients.Encoding;

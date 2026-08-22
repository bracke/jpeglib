package Jpeglib.Capabilities is
   pragma Pure;
   pragma SPARK_Mode (On);

   Baseline_Decode : constant Boolean := True;
   Baseline_Encode : constant Boolean := True;
   Progressive_Decode : constant Boolean := True;
   Progressive_Encode : constant Boolean := True;
   Huffman_Coding : constant Boolean := True;
   Arithmetic_Coding : constant Boolean := True;
   Twelve_Bit_DCT : constant Boolean := True;
   Lossless_JPEG : constant Boolean := True;
   Hierarchical_JPEG : constant Boolean := True;
   Grayscale : constant Boolean := True;
   YCbCr : constant Boolean := True;
   RGB_JPEG : constant Boolean := True;
   CMYK : constant Boolean := True;
   YCCK : constant Boolean := True;
   Restart_Intervals : constant Boolean := True;
   Raw_Components : constant Boolean := True;
   Coefficients : constant Boolean := True;
   Reduced_IDCT : constant Boolean := True;
   Exif_Orientation : constant Boolean := True;
   ICC_Preservation : constant Boolean := True;
   Coefficient_Transforms : constant Boolean := True;
end Jpeglib.Capabilities;

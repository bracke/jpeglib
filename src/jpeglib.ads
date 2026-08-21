with Interfaces;

package Jpeglib is
   pragma Pure;

   type Byte is new Interfaces.Unsigned_8;
   type Source_Offset is range 0 .. 2 ** 63 - 1;
   type Destination_Offset is range 0 .. 2 ** 63 - 1;
   type Byte_Count is range 0 .. 2 ** 63 - 1;

   type Image_Width is range 1 .. 2 ** 31 - 1;
   type Image_Height is range 1 .. 2 ** 31 - 1;
   type Pixel_Count is range 0 .. 2 ** 63 - 1;
   type Row_Stride is range 0 .. 2 ** 63 - 1;

   type Component_Count is range 1 .. 255;
   type Component_Index is range 1 .. 255;
   type Component_Identifier is new Byte;
   type Table_Index is range 0 .. 3;
   subtype Quantization_Table_Index is Table_Index;
   subtype Huffman_Table_Index is Table_Index;

   type Scan_Number is range 0 .. 4096;
   type MCU_Count is range 0 .. 2 ** 63 - 1;
   type MCU_Row is range 0 .. 2 ** 31 - 1;
   type MCU_Column is range 0 .. 2 ** 31 - 1;
   type Block_Count is range 0 .. 2 ** 63 - 1;
   type Block_Row is range 0 .. 2 ** 31 - 1;
   type Block_Column is range 0 .. 2 ** 31 - 1;
   type Block_Index is range 0 .. 2 ** 63 - 1;
   type Coefficient_Index is range 0 .. 63;
   type Spectral_Selection_Index is range 0 .. 63;
   subtype Lossless_Predictor_Selection is Spectral_Selection_Index range 1 .. 7;
   type Successive_Approximation_Value is range 0 .. 13;
   subtype Lossless_Point_Transform_Value is Successive_Approximation_Value range 0 .. 7;
   type Restart_Interval is range 0 .. 65535;
   type Marker_Code is new Interfaces.Unsigned_8;
   type Sample_Precision is range 8 .. 12;

   type Strictness_Mode is (Strict, Compatible, Recover_When_Safe);
   type Entropy_Mode is (Huffman, Arithmetic);
   type Frame_Mode is
     (Baseline_DCT,
      Extended_Sequential_DCT,
      Progressive_DCT,
      Lossless,
      Differential_Sequential_DCT,
      Differential_Progressive_DCT,
      Differential_Lossless,
      Unsupported_Frame);
   type Encoded_Color_Model is (Unknown, Grayscale, YCbCr, RGB, CMYK, YCCK);
   type Image_Completeness is (Complete_Image, Complete_Row_Prefix, Progressive_Preview, No_Usable_Output);
end Jpeglib;

with Interfaces;

with Jpeglib.Coefficients;
with Jpeglib.Internal.Quantization;

package Jpeglib.Internal.Transforms is
   pragma Preelaborate;

   type Dequantized_Coefficient is new Interfaces.Integer_32;
   type Dequantized_Block is array (Coefficient_Index) of Dequantized_Coefficient;
   type Sample_Block is array (Coefficient_Index) of Byte;

   function Dequantize
     (Block : Jpeglib.Coefficients.DCT_Block;
      Table : Quantization.Quantization_Table) return Dequantized_Block;

   function Forward_DC_Only
     (Samples : Sample_Block;
      Table : Quantization.Quantization_Table) return Jpeglib.Coefficients.DCT_Block;

   function Forward_Block
     (Samples : Sample_Block;
      Table : Quantization.Quantization_Table) return Jpeglib.Coefficients.DCT_Block;

   function Reconstruct_Block
     (Block : Dequantized_Block;
      Precision : Sample_Precision := 8) return Sample_Block;
   function Reconstruct_DC_Only
     (Block : Dequantized_Block;
      Precision : Sample_Precision := 8) return Sample_Block;
end Jpeglib.Internal.Transforms;

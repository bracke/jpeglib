with Interfaces;

with Jpeglib.Coefficients;
with Jpeglib.Internal.Quantization;

package Jpeglib.Internal.Transforms is
   pragma Preelaborate;

   type Dequantized_Coefficient is new Interfaces.Integer_32;
   type Dequantized_Block is array (Coefficient_Index) of Dequantized_Coefficient;
   subtype Sample_Value is Natural range 0 .. 4095;
   type Sample_Value_Block is array (Coefficient_Index) of Sample_Value;
   type Sample_Block is array (Coefficient_Index) of Byte;

   --  Dequantize.
   --  @param Block See package contract for this parameter.
   --  @param Table See package contract for this parameter.
   --  @return Operation result.
   function Dequantize
     (Block : Jpeglib.Coefficients.DCT_Block;
      Table : Quantization.Quantization_Table) return Dequantized_Block;

   --  Forward dc only.
   --  @param Samples See package contract for this parameter.
   --  @param Table See package contract for this parameter.
   --  @return Operation result.
   function Forward_DC_Only
     (Samples : Sample_Block;
      Table : Quantization.Quantization_Table) return Jpeglib.Coefficients.DCT_Block;

   --  Forward block.
   --  @param Samples See package contract for this parameter.
   --  @param Table See package contract for this parameter.
   --  @return Operation result.
   function Forward_Block
     (Samples : Sample_Block;
      Table : Quantization.Quantization_Table) return Jpeglib.Coefficients.DCT_Block;

   --  Forward dc only values.
   --  @param Samples See package contract for this parameter.
   --  @param Table See package contract for this parameter.
   --  @param Precision See package contract for this parameter.
   --  @return Operation result.
   function Forward_DC_Only_Values
     (Samples : Sample_Value_Block;
      Table : Quantization.Quantization_Table;
      Precision : Sample_Precision := 8) return Jpeglib.Coefficients.DCT_Block;

   --  Forward block values.
   --  @param Samples See package contract for this parameter.
   --  @param Table See package contract for this parameter.
   --  @param Precision See package contract for this parameter.
   --  @return Operation result.
   function Forward_Block_Values
     (Samples : Sample_Value_Block;
      Table : Quantization.Quantization_Table;
      Precision : Sample_Precision := 8) return Jpeglib.Coefficients.DCT_Block;

   --  Reconstruct block.
   --  @param Block See package contract for this parameter.
   --  @param Precision See package contract for this parameter.
   --  @return Operation result.
   function Reconstruct_Block
     (Block : Dequantized_Block;
      Precision : Sample_Precision := 8) return Sample_Block;
   --  Reconstruct dc only.
   --  @param Block See package contract for this parameter.
   --  @param Precision See package contract for this parameter.
   --  @return Operation result.
   function Reconstruct_DC_Only
     (Block : Dequantized_Block;
      Precision : Sample_Precision := 8) return Sample_Block;

   --  Reconstruct block values.
   --  @param Block See package contract for this parameter.
   --  @param Precision See package contract for this parameter.
   --  @return Operation result.
   function Reconstruct_Block_Values
     (Block : Dequantized_Block;
      Precision : Sample_Precision := 8) return Sample_Value_Block;
   --  Reconstruct dc only values.
   --  @param Block See package contract for this parameter.
   --  @param Precision See package contract for this parameter.
   --  @return Operation result.
   function Reconstruct_DC_Only_Values
     (Block : Dequantized_Block;
      Precision : Sample_Precision := 8) return Sample_Value_Block;
end Jpeglib.Internal.Transforms;

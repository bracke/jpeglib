with Interfaces;

package Jpeglib.Coefficients is
   pragma Pure;

   type Quantized_Coefficient is new Interfaces.Integer_32;
   type DCT_Block is array (Coefficient_Index) of Quantized_Coefficient;
   type DCT_Block_Array is array (Positive range <>) of DCT_Block;

   Natural_Order_Length : constant := 64;

   type Block_Transform is
     (Identity,
      Flip_Horizontal,
      Flip_Vertical,
      Rotate_180,
      Transpose,
      Rotate_90,
      Rotate_270,
      Transverse);

   function Transform
     (Block : DCT_Block;
      Operation : Block_Transform) return DCT_Block;

   procedure Apply_Transform
     (Block : in out DCT_Block;
      Operation : Block_Transform);
end Jpeglib.Coefficients;

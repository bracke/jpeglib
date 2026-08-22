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

   subtype Component_Block_Count is Block_Count;

   type Component_Block_Layout is record
      Width_In_Blocks : Component_Block_Count := 0;
      Height_In_Blocks : Component_Block_Count := 0;
   end record;

   type Component_Block_Layout_Array is
     array (Component_Index range <>) of Component_Block_Layout;

   type Component_Block_Window is record
      Left : Component_Block_Count := 0;
      Top : Component_Block_Count := 0;
      Width_In_Blocks : Component_Block_Count := 0;
      Height_In_Blocks : Component_Block_Count := 0;
   end record;

   type Component_Block_Window_Array is
     array (Component_Index range <>) of Component_Block_Window;

   type Transform_Status is
     (Transform_Ok,
      Layout_Range_Mismatch,
      Invalid_Layout,
      Invalid_Window,
      Output_Too_Small);

   function Transform
     (Block : DCT_Block;
      Operation : Block_Transform) return DCT_Block;

   procedure Apply_Transform
     (Block : in out DCT_Block;
      Operation : Block_Transform);

   function Block_Count_For
     (Layout : Component_Block_Layout) return Component_Block_Count;

   function Total_Block_Count
     (Layouts : Component_Block_Layout_Array) return Component_Block_Count;

   function Full_Windows
     (Layouts : Component_Block_Layout_Array) return Component_Block_Window_Array;

   function Transformed_Layout
     (Window : Component_Block_Window;
      Operation : Block_Transform) return Component_Block_Layout;

   function Transformed_Layouts
     (Windows : Component_Block_Window_Array;
      Operation : Block_Transform) return Component_Block_Layout_Array;

   function Validate_Windows
     (Layouts : Component_Block_Layout_Array;
      Windows : Component_Block_Window_Array) return Transform_Status;

   procedure Transform_Image
     (Input_Blocks : DCT_Block_Array;
      Input_Layouts : Component_Block_Layout_Array;
      Windows : Component_Block_Window_Array;
      Operation : Block_Transform;
      Output_Blocks : in out DCT_Block_Array;
      Output_Layouts : out Component_Block_Layout_Array;
      Blocks_Written : out Component_Block_Count;
      Status : out Transform_Status);
end Jpeglib.Coefficients;

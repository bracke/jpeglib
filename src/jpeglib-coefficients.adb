package body Jpeglib.Coefficients is

   function To_Index (U, V : Natural) return Coefficient_Index is
   begin
      return Coefficient_Index (V * 8 + U);
   end To_Index;

   function Maybe_Negate
     (Value : Quantized_Coefficient;
      Negate : Boolean) return Quantized_Coefficient is
   begin
      if Negate then
         return -Value;
      else
         return Value;
      end if;
   end Maybe_Negate;

   function Transform
     (Block : DCT_Block;
      Operation : Block_Transform) return DCT_Block
   is
      Result : DCT_Block := [others => 0];
      Source_U : Natural;
      Source_V : Natural;
      Negate : Boolean;
   begin
      for V in 0 .. 7 loop
         for U in 0 .. 7 loop
            Source_U := U;
            Source_V := V;
            Negate := False;

            case Operation is
               when Identity =>
                  null;
               when Flip_Horizontal =>
                  Negate := U mod 2 = 1;
               when Flip_Vertical =>
                  Negate := V mod 2 = 1;
               when Rotate_180 =>
                  Negate := (U + V) mod 2 = 1;
               when Transpose =>
                  Source_U := V;
                  Source_V := U;
               when Rotate_90 =>
                  Source_U := V;
                  Source_V := U;
                  Negate := U mod 2 = 1;
               when Rotate_270 =>
                  Source_U := V;
                  Source_V := U;
                  Negate := V mod 2 = 1;
               when Transverse =>
                  Source_U := V;
                  Source_V := U;
                  Negate := (U + V) mod 2 = 1;
            end case;

            Result (To_Index (U, V)) :=
              Maybe_Negate (Block (To_Index (Source_U, Source_V)), Negate);
         end loop;
      end loop;

      return Result;
   end Transform;

   procedure Apply_Transform
     (Block : in out DCT_Block;
      Operation : Block_Transform) is
   begin
      Block := Transform (Block, Operation);
   end Apply_Transform;

end Jpeglib.Coefficients;

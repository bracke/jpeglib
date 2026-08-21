with Jpeglib.Errors;

package body Jpeglib.Internal.Checked_Arithmetic is
   pragma SPARK_Mode (On);

   function Overflow return Count_Result is
   begin
      return (Outcome => Results.Failure (Errors.Integer_Overflow), Count => 0);
   end Overflow;

   function Add (Left, Right : Byte_Count) return Count_Result is
   begin
      if Left > Byte_Count'Last - Right then
         return Overflow;
      end if;
      return (Outcome => Results.Success, Count => Left + Right);
   end Add;

   function Multiply (Left, Right : Byte_Count) return Count_Result is
   begin
      if Left /= 0 and then Right > Byte_Count'Last / Left then
         return Overflow;
      end if;
      return (Outcome => Results.Success, Count => Left * Right);
   end Multiply;

   function Ceiling_Divide (Dividend, Divisor : Byte_Count) return Count_Result is
   begin
      if Divisor = 0 then
         return Overflow;
      elsif Dividend = 0 then
         return (Outcome => Results.Success, Count => 0);
      else
         return Add ((Dividend - 1) / Divisor, 1);
      end if;
   end Ceiling_Divide;

   function Align_Up (Value, Alignment : Byte_Count) return Count_Result is
      Units : Count_Result;
   begin
      if Alignment = 0 then
         return Overflow;
      end if;
      Units := Ceiling_Divide (Value, Alignment);
      if not Results.Succeeded (Units.Outcome) then
         return Units;
      end if;
      return Multiply (Units.Count, Alignment);
   end Align_Up;
end Jpeglib.Internal.Checked_Arithmetic;

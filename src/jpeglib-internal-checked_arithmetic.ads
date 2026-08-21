with Jpeglib.Results;

package Jpeglib.Internal.Checked_Arithmetic is
   pragma Preelaborate;
   pragma SPARK_Mode (On);

   type Count_Result is record
      Outcome : Results.Result := Results.Success;
      Count : Byte_Count := 0;
   end record;

   function Add (Left, Right : Byte_Count) return Count_Result;
   function Multiply (Left, Right : Byte_Count) return Count_Result;
   function Ceiling_Divide (Dividend, Divisor : Byte_Count) return Count_Result;
   function Align_Up (Value, Alignment : Byte_Count) return Count_Result;
end Jpeglib.Internal.Checked_Arithmetic;

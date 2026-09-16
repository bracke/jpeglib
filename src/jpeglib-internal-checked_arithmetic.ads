with Jpeglib.Results;

package Jpeglib.Internal.Checked_Arithmetic is
   pragma Preelaborate;
   pragma SPARK_Mode (On);

   type Count_Result is record
      Outcome : Results.Result := Results.Success;
      Count : Byte_Count := 0;
   end record;

   --  Add.
   --  @param Left See package contract for this parameter.
   --  @param Right See package contract for this parameter.
   --  @return Operation result.
   function Add (Left, Right : Byte_Count) return Count_Result;
   --  Multiply.
   --  @param Left See package contract for this parameter.
   --  @param Right See package contract for this parameter.
   --  @return Operation result.
   function Multiply (Left, Right : Byte_Count) return Count_Result;
   --  Ceiling divide.
   --  @param Dividend See package contract for this parameter.
   --  @param Divisor See package contract for this parameter.
   --  @return Operation result.
   function Ceiling_Divide (Dividend, Divisor : Byte_Count) return Count_Result;
   --  Align up.
   --  @param Value See package contract for this parameter.
   --  @param Alignment See package contract for this parameter.
   --  @return Operation result.
   function Align_Up (Value, Alignment : Byte_Count) return Count_Result;
end Jpeglib.Internal.Checked_Arithmetic;

with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Bytes is
   pragma Preelaborate;

   type Read_Byte_Result is record
      Outcome : Results.Result := Results.Success;
      Source : Source_Offset := 0;
      Value : Byte := 0;
      End_Of_Input : Boolean := False;
   end record;

   type Read_U16_Result is record
      Outcome : Results.Result := Results.Success;
      Source : Source_Offset := 0;
      Value : Natural range 0 .. 65_535 := 0;
      End_Of_Input : Boolean := False;
   end record;

   function Read_Byte (Input : in out Streams.Source'Class) return Read_Byte_Result;
   function Read_Big_Endian_U16 (Input : in out Streams.Source'Class) return Read_U16_Result;
end Jpeglib.Internal.Bytes;

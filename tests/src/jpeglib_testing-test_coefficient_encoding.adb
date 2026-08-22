with AUnit.Assertions;

with Jpeglib.Coefficients;
with Jpeglib.Coefficients.Encoding;
with Jpeglib.Errors;
with Jpeglib.Limits;
with Jpeglib.Results;
with Jpeglib.Streams;

package body Jpeglib_Testing.Test_Coefficient_Encoding is
   use AUnit.Assertions;
   use type Jpeglib.Errors.Error_Code;

   procedure Coefficient_Encode_Rejects_Width_Limit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Coefficient_Encode_Rejects_Coefficient_Bytes (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("coefficient encoding");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Coefficient_Encode_Rejects_Width_Limit'Access,
         "coefficient_encoding.limits.width");
      Register_Routine
        (T,
         Coefficient_Encode_Rejects_Coefficient_Bytes'Access,
         "coefficient_encoding.limits.coefficient_bytes");
   end Register_Tests;

   procedure Coefficient_Encode_Rejects_Width_Limit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 512 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (1 .. 1) := [others => [others => 0]];
      Limits : constant Jpeglib.Limits.Limit_Set :=
        (Max_Width => 7,
         others => <>);
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Outcome :=
        Jpeglib.Coefficients.Encoding.Encode_Grayscale_Baseline
          (Destination,
           Width => 8,
           Height => 8,
           Blocks => Blocks,
           Encode_Limits => Limits);

      Assert (not Jpeglib.Results.Succeeded (Outcome), "coefficient encode accepted width over caller limit");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Frame_Invalid_Definition,
         "coefficient encode width limit used wrong error");
   end Coefficient_Encode_Rejects_Width_Limit;

   procedure Coefficient_Encode_Rejects_Coefficient_Bytes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 512 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (1 .. 1) := [others => [others => 0]];
      Limits : constant Jpeglib.Limits.Limit_Set :=
        (Max_Coefficient_Bytes => 127,
         others => <>);
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Output_Storage'Unchecked_Access);
      Outcome :=
        Jpeglib.Coefficients.Encoding.Encode_Grayscale_Progressive
          (Destination,
           Width => 8,
           Height => 8,
           Blocks => Blocks,
           Encode_Limits => Limits);

      Assert (not Jpeglib.Results.Succeeded (Outcome), "coefficient encode accepted coefficient storage over limit");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Output_Limit_Exceeded,
         "coefficient encode storage limit used wrong error");
   end Coefficient_Encode_Rejects_Coefficient_Bytes;
end Jpeglib_Testing.Test_Coefficient_Encoding;

with Ada.Command_Line;
with Ada.Text_IO;

with Jpeglib.Coefficients;
with Jpeglib.Coefficients.Encoding;
with Jpeglib.Decoding;
with Jpeglib.Results;
with Jpeglib.Streams;

with Jpeglib_Tools;

procedure Jpeglib_Transform is
   use type Jpeglib.Block_Count;
   use type Jpeglib.Coefficients.Component_Block_Layout_Array;
   use type Jpeglib.Coefficients.DCT_Block;
   use type Jpeglib.Coefficients.DCT_Block_Array;
   use type Jpeglib.Coefficients.Quantized_Coefficient;
   use type Jpeglib.Coefficients.Transform_Status;
   use type Jpeglib.Decoding.Decoder_State;

   subtype QC is Jpeglib.Coefficients.Quantized_Coefficient;

   function Make_Block (DC : QC) return Jpeglib.Coefficients.DCT_Block is
   begin
      return [0 => DC, 1 => DC + 10, 8 => DC + 20, others => 0];
   end Make_Block;

   function Block_At
     (Blocks : Jpeglib.Coefficients.DCT_Block_Array;
      Index : Natural) return Jpeglib.Coefficients.DCT_Block is
   begin
      return Blocks (Positive (Natural (Blocks'First) + Index));
   end Block_At;

   procedure Fail (Message : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_transform: " & Message);
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Test_Failure)));
   end Fail;

   procedure Self_Test is
      Input_Layouts : constant Jpeglib.Coefficients.Component_Block_Layout_Array (1 .. 2) :=
        [1 => (Width_In_Blocks => 2, Height_In_Blocks => 2),
         2 => (Width_In_Blocks => 1, Height_In_Blocks => 2)];
      Windows : constant Jpeglib.Coefficients.Component_Block_Window_Array (1 .. 2) :=
        Jpeglib.Coefficients.Full_Windows (Input_Layouts);
      Input : constant Jpeglib.Coefficients.DCT_Block_Array (1 .. 6) :=
        [1 => Make_Block (1),
         2 => Make_Block (2),
         3 => Make_Block (3),
         4 => Make_Block (4),
         5 => Make_Block (101),
         6 => Make_Block (102)];
      Output : Jpeglib.Coefficients.DCT_Block_Array (1 .. 6) := [others => [others => -1]];
      Output_Layouts : Jpeglib.Coefficients.Component_Block_Layout_Array (1 .. 2);
      Blocks_Written : Jpeglib.Coefficients.Component_Block_Count;
      Status : Jpeglib.Coefficients.Transform_Status;
      Encoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 4096 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Decoded_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. 2) := [others => [others => 0]];
      Progressive_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (1 .. 2) :=
        [1 => [0 => 7, others => 0],
         2 => [0 => 9, others => 0]];
      Decoded_Progressive_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. 2) := [others => [others => 0]];
      Color_Blocks : constant Jpeglib.Coefficients.DCT_Block_Array (1 .. 3) :=
        [1 => Make_Block (2),
         2 => Make_Block (-1),
         3 => Make_Block (4)];
      Color_Layouts : constant Jpeglib.Coefficients.Component_Block_Layout_Array (1 .. 3) :=
        [others => (Width_In_Blocks => 1, Height_In_Blocks => 1)];
      Decoded_Color_Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. 3) := [others => [others => 0]];
      Blocks_Decoded : Jpeglib.Block_Count := 0;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Coefficients.Transform_Image
        (Input,
         Input_Layouts,
         Windows,
         Jpeglib.Coefficients.Transpose,
         Output,
         Output_Layouts,
         Blocks_Written,
         Status);

      if Status /= Jpeglib.Coefficients.Transform_Ok then
         Fail ("transpose returned " & Jpeglib.Coefficients.Transform_Status'Image (Status));
         return;
      elsif Blocks_Written /= 6 then
         Fail ("transpose wrote wrong block count");
         return;
      elsif Output_Layouts /=
        [1 => (Width_In_Blocks => 2, Height_In_Blocks => 2),
         2 => (Width_In_Blocks => 2, Height_In_Blocks => 1)]
      then
         Fail ("transpose returned wrong layouts");
         return;
      elsif Block_At (Output, 0) /=
        Jpeglib.Coefficients.Transform (Input (1), Jpeglib.Coefficients.Transpose)
      then
         Fail ("component 1 first block mismatch");
         return;
      elsif Block_At (Output, 1) /=
        Jpeglib.Coefficients.Transform (Input (3), Jpeglib.Coefficients.Transpose)
      then
         Fail ("component 1 transposed block mismatch");
         return;
      elsif Block_At (Output, 4) /=
        Jpeglib.Coefficients.Transform (Input (5), Jpeglib.Coefficients.Transpose)
      then
         Fail ("component 2 first block mismatch");
         return;
      elsif Block_At (Output, 5) /=
        Jpeglib.Coefficients.Transform (Input (6), Jpeglib.Coefficients.Transpose)
      then
         Fail ("component 2 second block mismatch");
         return;
      end if;

      Jpeglib.Streams.Open (Destination, Encoded_Storage'Unchecked_Access);
      Outcome :=
        Jpeglib.Coefficients.Encoding.Encode_Grayscale_Baseline
          (Destination,
           Width => 16,
           Height => 8,
           Blocks => Input (1 .. 2),
           Restart => 1,
           Quality => 75);
      if not Jpeglib.Results.Succeeded (Outcome) then
         Fail ("coefficient JPEG output failed");
         return;
      end if;

      Jpeglib.Streams.Open (Source, Encoded_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Decode_Coefficients (Decoder, Decoded_Blocks, Blocks_Decoded);
      if not Jpeglib.Results.Succeeded (Outcome) then
         Fail ("coefficient JPEG output did not decode");
         return;
      elsif Jpeglib.Decoding.State (Decoder) /= Jpeglib.Decoding.Completed then
         Fail ("coefficient JPEG output decoder did not complete");
         return;
      elsif Blocks_Decoded /= 2 then
         Fail ("coefficient JPEG output decoded wrong block count");
         return;
      elsif Decoded_Blocks /= Input (1 .. 2) then
         Fail ("coefficient JPEG output changed coefficients");
         return;
      end if;

      Jpeglib.Streams.Open (Destination, Encoded_Storage'Unchecked_Access);
      Outcome :=
        Jpeglib.Coefficients.Encoding.Encode_Grayscale_Progressive
          (Destination,
           Width => 16,
           Height => 8,
           Blocks => Progressive_Blocks,
           Restart => 1,
           Quality => 75,
           Refine => False);
      if not Jpeglib.Results.Succeeded (Outcome) then
         Fail ("progressive coefficient JPEG output failed");
         return;
      end if;

      Jpeglib.Streams.Open (Source, Encoded_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome :=
        Jpeglib.Decoding.Decode_Coefficients
          (Decoder, Decoded_Progressive_Blocks, Blocks_Decoded);
      if not Jpeglib.Results.Succeeded (Outcome) then
         Fail ("progressive coefficient JPEG output did not decode");
         return;
      elsif Decoded_Progressive_Blocks /= Progressive_Blocks then
         Fail ("progressive DC-only coefficient JPEG output changed coefficients");
         return;
      end if;

      Jpeglib.Streams.Open (Destination, Encoded_Storage'Unchecked_Access);
      Outcome :=
        Jpeglib.Coefficients.Encoding.Encode_YCbCr_Baseline
          (Destination,
           Width => 8,
           Height => 8,
           Blocks => Color_Blocks,
           Layouts => Color_Layouts,
           Restart => 0,
           Quality => 75);
      if not Jpeglib.Results.Succeeded (Outcome) then
         Fail ("YCbCr coefficient JPEG output failed");
         return;
      end if;

      Jpeglib.Streams.Open (Source, Encoded_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Decode_Coefficients (Decoder, Decoded_Color_Blocks, Blocks_Decoded);
      if not Jpeglib.Results.Succeeded (Outcome) then
         Fail ("YCbCr coefficient JPEG output did not decode");
         return;
      elsif Blocks_Decoded /= 3 then
         Fail ("YCbCr coefficient JPEG output decoded wrong block count");
         return;
      elsif Decoded_Color_Blocks /= Color_Blocks then
         Fail ("YCbCr coefficient JPEG output changed coefficients");
         return;
      end if;

      Ada.Text_IO.Put_Line ("jpeglib_transform: coefficient transform self-test passed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   end Self_Test;

   procedure Usage is
   begin
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: jpeglib_transform --self-test");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
   end Usage;
begin
   if Ada.Command_Line.Argument_Count = 1
     and then Ada.Command_Line.Argument (1) = "--self-test"
   then
      Self_Test;
   else
      Usage;
   end if;
end Jpeglib_Transform;

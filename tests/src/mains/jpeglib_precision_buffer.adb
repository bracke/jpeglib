with Ada.Command_Line;
with Ada.Text_IO;

with Jpeglib.Decoding;
with Jpeglib.Errors;
with Jpeglib.Results;
with Jpeglib.Streams;

with Jpeglib_Tools;

procedure Jpeglib_Precision_Buffer is
   use type Jpeglib.Byte;
   use type Jpeglib.Errors.Error_Code;

   Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#C4#,
      0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#C7#,
      0, 11,
      12, 0, 1, 0, 1, 1,
      1, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      1, 0, 0,
      0,
      16#FF#, 16#D9#];
   Failures : Natural := 0;

   procedure Fail (Message : String; Error : Jpeglib.Errors.Error_Code := Jpeglib.Errors.No_Error) is
   begin
      if Error = Jpeglib.Errors.No_Error then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_precision_buffer: " & Message);
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "jpeglib_precision_buffer: " & Message & ": " & Jpeglib.Errors.Error_Code'Image (Error));
      end if;
      Failures := Failures + 1;
   end Fail;

   function Decode_One
     (Policy : Jpeglib.Decoding.Raw_Precision_Policy;
      Precision : Jpeglib.Sample_Precision;
      Output : not null Jpeglib.Streams.Byte_Array_Access;
      Stride : Jpeglib.Row_Stride;
      Accessible : Jpeglib.Byte_Count) return Jpeglib.Results.Result
   is
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Raw : Jpeglib.Decoding.Raw_Component_View_Array (1 .. 1) :=
        [1 =>
           (Width => 1,
            Height => 1,
            Stride => Stride,
            Accessible_Bytes => Accessible,
            Storage => Output)];
   begin
      Jpeglib.Streams.Open (Source, Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         (Raw_Output_Precision => Precision,
          Raw_Precision => Policy,
          others => <>));
      return Jpeglib.Decoding.Decode_Raw_Components (Decoder, Raw);
   end Decode_One;

   Scaled : aliased Jpeglib.Streams.Byte_Array := [1 .. 1 => 0];
   Clamped : aliased Jpeglib.Streams.Byte_Array := [1 .. 1 => 0];
   Preserved : aliased Jpeglib.Streams.Byte_Array := [1 .. 2 => 0];
   Rejected : aliased Jpeglib.Streams.Byte_Array := [1 .. 1 => 0];
   Outcome : Jpeglib.Results.Result;
begin
   Outcome :=
     Decode_One
       (Jpeglib.Decoding.Scale_To_Output_Precision,
        8,
        Scaled'Unchecked_Access,
        1,
        1);
   if not Jpeglib.Results.Succeeded (Outcome) then
      Fail ("scale policy decode failed", Outcome.First_Error.Code);
   elsif Scaled (Scaled'First) /= 128 then
      Fail ("scale policy did not map 12-bit midpoint to 8-bit midpoint");
   end if;

   Outcome :=
     Decode_One
       (Jpeglib.Decoding.Clamp_To_Output_Precision,
        8,
        Clamped'Unchecked_Access,
        1,
        1);
   if not Jpeglib.Results.Succeeded (Outcome) then
      Fail ("clamp policy decode failed", Outcome.First_Error.Code);
   elsif Clamped (Clamped'First) /= 255 then
      Fail ("clamp policy did not clamp 12-bit midpoint to 8-bit max");
   end if;

   Outcome :=
     Decode_One
       (Jpeglib.Decoding.Preserve_Source_Precision,
        8,
        Preserved'Unchecked_Access,
        2,
        2);
   if not Jpeglib.Results.Succeeded (Outcome) then
      Fail ("preserve policy decode failed", Outcome.First_Error.Code);
   elsif Preserved (Preserved'First) /= 8 or else Preserved (Preserved'First + 1) /= 0 then
      Fail ("preserve policy did not emit big-endian 12-bit sample bytes");
   end if;

   Outcome :=
     Decode_One
       (Jpeglib.Decoding.Reject_Precision_Mismatch,
        8,
        Rejected'Unchecked_Access,
        1,
        1);
   if Jpeglib.Results.Succeeded (Outcome) then
      Fail ("reject policy accepted precision mismatch");
   elsif Outcome.First_Error.Code /= Jpeglib.Errors.Unsupported_Feature then
      Fail ("reject policy used wrong error", Outcome.First_Error.Code);
   end if;

   if Failures = 0 then
      Ada.Text_IO.Put_Line ("jpeglib_precision_buffer: precision policy matrix passed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Test_Failure)));
   end if;
end Jpeglib_Precision_Buffer;

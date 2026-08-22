with Ada.Command_Line;
with Ada.Text_IO;

with Jpeglib.Encoding;
with Jpeglib.Errors;
with Jpeglib.Images;
with Jpeglib.Results;
with Jpeglib.Streams;

with Jpeglib_Tools;

procedure Jpeglib_Encoder_Optimization is
   use type Jpeglib.Destination_Offset;
   use type Jpeglib.Errors.Error_Code;

   Width : constant Jpeglib.Image_Width := 64;
   Height : constant Jpeglib.Image_Height := 64;
   Input_Bytes : constant Natural := Natural (Width) * Natural (Height) * 3;

   Input_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. Input_Bytes => 0];
   Encoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 262_144 => 0];
   Failures : Natural := 0;

   procedure Fail (Message : String; Error : Jpeglib.Errors.Error_Code := Jpeglib.Errors.No_Error) is
   begin
      if Error = Jpeglib.Errors.No_Error then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_encoder_optimization: " & Message);
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "jpeglib_encoder_optimization: "
            & Message
            & ": "
            & Jpeglib.Errors.Error_Code'Image (Error));
      end if;

      Failures := Failures + 1;
   end Fail;

   procedure Fill_Input is
      Cursor : Positive := Input_Storage'First;
   begin
      for Row in 0 .. Natural (Height) - 1 loop
         for Column in 0 .. Natural (Width) - 1 loop
            Input_Storage (Cursor) := Jpeglib.Byte ((Column * 13 + Row * 7) mod 256);
            Input_Storage (Cursor + 1) := Jpeglib.Byte ((Column * 5 + Row * 19) mod 256);
            Input_Storage (Cursor + 2) := Jpeglib.Byte ((Column * Row + Column * 3) mod 256);
            Cursor := Cursor + 3;
         end loop;
      end loop;
   end Fill_Input;

   function Input_View return Jpeglib.Images.Image_View is
   begin
      return
        (Descriptor =>
           (Width => Width,
            Height => Height,
            Format => Jpeglib.Images.RGB_24,
            Stride => Jpeglib.Row_Stride (Natural (Width) * 3),
            Accessible_Bytes => Jpeglib.Byte_Count (Input_Bytes)),
         Storage => Input_Storage'Unchecked_Access);
   end Input_View;

   function Encoded_Size (Options : Jpeglib.Encoding.Options) return Natural is
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Encoder : Jpeglib.Encoding.Encoder;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Encoded_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize (Encoder, Destination'Access, Options);
      Outcome := Jpeglib.Encoding.Encode_Image (Encoder, Input_View);
      if not Jpeglib.Results.Succeeded (Outcome) then
         Fail ("encode failed", Outcome.First_Error.Code);
         return 0;
      elsif Jpeglib.Streams.Offset (Destination) = 0 then
         Fail ("encode produced no bytes");
         return 0;
      end if;

      return Natural (Jpeglib.Streams.Offset (Destination));
   end Encoded_Size;

   Default_Size : Natural;
   Optimized_Size : Natural;
   Progressive_Size : Natural;
   Photo_Size : Natural;
   Graphic_Size : Natural;
   Small_File_Size : Natural;
   Target_Size : Natural;
begin
   Fill_Input;

   Default_Size :=
     Encoded_Size
       ((Quality => 82,
         Subsampling => Jpeglib.Encoding.Subsampling_420,
         others => <>));
   Optimized_Size :=
     Encoded_Size
       ((Quality => 82,
         Optimize_Huffman => True,
         Subsampling => Jpeglib.Encoding.Subsampling_420,
         others => <>));
   Progressive_Size :=
     Encoded_Size
       ((Quality => 82,
         Progressive => Jpeglib.Encoding.Fast_Preview_Progressive,
         Optimize_Huffman => True,
         Subsampling => Jpeglib.Encoding.Subsampling_420,
         others => <>));
   Photo_Size := Encoded_Size ((Preset => Jpeglib.Encoding.Photo_Preset, others => <>));
   Graphic_Size := Encoded_Size ((Preset => Jpeglib.Encoding.Graphic_Preset, others => <>));
   Small_File_Size := Encoded_Size ((Preset => Jpeglib.Encoding.Small_File_Preset, others => <>));
   Target_Size :=
     Encoded_Size
       ((Quality => 82,
         Target_Bytes => 1_500,
         Subsampling => Jpeglib.Encoding.Subsampling_444,
         others => <>));

   if Optimized_Size = 0
     or else Progressive_Size = 0
     or else Photo_Size = 0
     or else Graphic_Size = 0
     or else Small_File_Size = 0
     or else Target_Size = 0
   then
      null;
   elsif Optimized_Size > Default_Size then
      Fail ("optimized Huffman output grew versus default");
   elsif Progressive_Size > Default_Size then
      Fail ("optimized progressive output grew versus default");
   elsif Small_File_Size >= Photo_Size then
      Fail ("small-file preset is not smaller than photo preset");
   elsif Small_File_Size >= Graphic_Size then
      Fail ("small-file preset is not smaller than graphic preset");
   elsif Target_Size >= Default_Size then
      Fail ("target-byte encode is not smaller than default");
   end if;

   Ada.Text_IO.Put_Line
     ("jpeglib_encoder_optimization:"
      & " default="
      & Natural'Image (Default_Size)
      & " optimized="
      & Natural'Image (Optimized_Size)
      & " progressive="
      & Natural'Image (Progressive_Size)
      & " photo="
      & Natural'Image (Photo_Size)
      & " graphic="
      & Natural'Image (Graphic_Size)
      & " small="
      & Natural'Image (Small_File_Size)
      & " target="
      & Natural'Image (Target_Size));

   if Failures = 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Test_Failure)));
   end if;
end Jpeglib_Encoder_Optimization;

with Ada.Calendar;
with Ada.Command_Line;
with Ada.Text_IO;

with Jpeglib.Decoding;
with Jpeglib.Encoding;
with Jpeglib.Errors;
with Jpeglib.Images;
with Jpeglib.Results;
with Jpeglib.Streams;

with Jpeglib_Tools;

procedure Jpeglib_Benchmark is
   use type Ada.Calendar.Time;
   use type Jpeglib.Errors.Error_Code;

   Max_Width : constant Jpeglib.Image_Width := 16;
   Max_Height : constant Jpeglib.Image_Height := 16;
   Max_Input_Bytes : constant Natural := Natural (Max_Width) * Natural (Max_Height) * 4;

   Input_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. Max_Input_Bytes => 0];
   Encoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 65_536 => 0];
   Decoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. Max_Input_Bytes => 0];

   procedure Fail (Message : String; Error : Jpeglib.Errors.Error_Code := Jpeglib.Errors.No_Error) is
   begin
      if Error = Jpeglib.Errors.No_Error then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_benchmark: " & Message);
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "jpeglib_benchmark: " & Message & ": " & Jpeglib.Errors.Error_Code'Image (Error));
      end if;

      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Test_Failure)));
   end Fail;

   function Bytes_Per_Pixel (Format : Jpeglib.Images.Pixel_Format) return Natural is
     (Natural (Jpeglib.Images.Bytes_Per_Pixel (Format)));

   function Byte_Count_For
     (Width : Jpeglib.Image_Width;
      Height : Jpeglib.Image_Height;
      Format : Jpeglib.Images.Pixel_Format) return Jpeglib.Byte_Count
   is
     (Jpeglib.Byte_Count (Natural (Width) * Natural (Height) * Bytes_Per_Pixel (Format)));

   procedure Fill_Input
     (Width : Jpeglib.Image_Width;
      Height : Jpeglib.Image_Height;
      Format : Jpeglib.Images.Pixel_Format)
   is
      Pixel_Bytes : constant Natural := Bytes_Per_Pixel (Format);
      Cursor : Positive := Input_Storage'First;
   begin
      for Row in 0 .. Natural (Height) - 1 loop
         for Column in 0 .. Natural (Width) - 1 loop
            Input_Storage (Cursor) := Jpeglib.Byte ((Column * 17 + Row) mod 256);
            if Pixel_Bytes >= 2 then
               Input_Storage (Cursor + 1) := Jpeglib.Byte ((Row * 17 + Column) mod 256);
            end if;
            if Pixel_Bytes >= 3 then
               Input_Storage (Cursor + 2) := Jpeglib.Byte (((Row + Column) * 9) mod 256);
            end if;
            if Pixel_Bytes >= 4 then
               Input_Storage (Cursor + 3) := Jpeglib.Byte (128 + ((Row * 3 + Column) mod 64));
            end if;
            Cursor := Cursor + Pixel_Bytes;
         end loop;
      end loop;
   end Fill_Input;

   function Input_View
     (Width : Jpeglib.Image_Width;
      Height : Jpeglib.Image_Height;
      Format : Jpeglib.Images.Pixel_Format) return Jpeglib.Images.Image_View
   is
      Row_Bytes : constant Natural := Natural (Width) * Bytes_Per_Pixel (Format);
   begin
      return
        (Descriptor =>
           (Width => Width,
            Height => Height,
            Format => Format,
            Stride => Jpeglib.Row_Stride (Row_Bytes),
            Accessible_Bytes => Byte_Count_For (Width, Height, Format)),
         Storage => Input_Storage'Unchecked_Access);
   end Input_View;

   function Output_View
     (Width : Jpeglib.Image_Width;
      Height : Jpeglib.Image_Height;
      Format : Jpeglib.Images.Pixel_Format) return Jpeglib.Images.Mutable_Image_View
   is
      Row_Bytes : constant Natural := Natural (Width) * Bytes_Per_Pixel (Format);
   begin
      return
        (Descriptor =>
           (Width => Width,
            Height => Height,
            Format => Format,
            Stride => Jpeglib.Row_Stride (Row_Bytes),
            Accessible_Bytes => Byte_Count_For (Width, Height, Format)),
         Storage => Decoded_Storage'Unchecked_Access);
   end Output_View;

   procedure Run_Case
     (Label : String;
      Width : Jpeglib.Image_Width;
      Height : Jpeglib.Image_Height;
      Format : Jpeglib.Images.Pixel_Format;
      Options : Jpeglib.Encoding.Options;
      Iterations : Positive)
   is
      Encoded_Length : Natural := 0;

      function Encode_Once return Jpeglib.Results.Result is
         Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
         Encoder : Jpeglib.Encoding.Encoder;
         Outcome : Jpeglib.Results.Result;
      begin
         Jpeglib.Streams.Open (Destination, Encoded_Storage'Unchecked_Access);
         Jpeglib.Encoding.Initialize (Encoder, Destination'Access, Options);
         Outcome := Jpeglib.Encoding.Encode_Image (Encoder, Input_View (Width, Height, Format));
         if Jpeglib.Results.Succeeded (Outcome) then
            Encoded_Length := Natural (Jpeglib.Streams.Offset (Destination));
         end if;
         return Outcome;
      end Encode_Once;

      function Decode_Once return Jpeglib.Results.Result is
         Encoded_Copy : aliased constant Jpeglib.Streams.Byte_Array := Encoded_Storage (1 .. Encoded_Length);
         Source : aliased Jpeglib.Streams.Memory_Source;
         Decoder : Jpeglib.Decoding.Decoder;
         Output : Jpeglib.Images.Mutable_Image_View := Output_View (Width, Height, Format);
      begin
         Jpeglib.Streams.Open (Source, Encoded_Copy'Unchecked_Access);
         Jpeglib.Decoding.Initialize
           (Decoder,
            Source'Access,
            (Output_Format => Format, others => <>));
         return Jpeglib.Decoding.Decode_Image (Decoder, Output);
      end Decode_Once;

      Outcome : Jpeglib.Results.Result;
      Started : Ada.Calendar.Time;
      Encode_Elapsed : Duration;
      Decode_Elapsed : Duration;
   begin
      Fill_Input (Width, Height, Format);

      Outcome := Encode_Once;
      if not Jpeglib.Results.Succeeded (Outcome) then
         Fail (Label & " initial encode failed", Outcome.First_Error.Code);
         return;
      elsif Encoded_Length = 0 then
         Fail (Label & " initial encode produced no bytes");
         return;
      end if;

      Outcome := Decode_Once;
      if not Jpeglib.Results.Succeeded (Outcome) then
         Fail (Label & " initial decode failed", Outcome.First_Error.Code);
         return;
      end if;

      Started := Ada.Calendar.Clock;
      for Iteration in 1 .. Iterations loop
         Outcome := Encode_Once;
         if not Jpeglib.Results.Succeeded (Outcome) then
            Fail (Label & " encode iteration" & Positive'Image (Iteration) & " failed", Outcome.First_Error.Code);
            return;
         end if;
      end loop;
      Encode_Elapsed := Ada.Calendar.Clock - Started;

      Started := Ada.Calendar.Clock;
      for Iteration in 1 .. Iterations loop
         Outcome := Decode_Once;
         if not Jpeglib.Results.Succeeded (Outcome) then
            Fail (Label & " decode iteration" & Positive'Image (Iteration) & " failed", Outcome.First_Error.Code);
            return;
         end if;
      end loop;
      Decode_Elapsed := Ada.Calendar.Clock - Started;

      Ada.Text_IO.Put_Line
        ("jpeglib_benchmark: "
         & Label
         & " bytes="
         & Natural'Image (Encoded_Length)
         & " iterations="
         & Positive'Image (Iterations)
         & " encode="
         & Duration'Image (Encode_Elapsed)
         & "s decode="
         & Duration'Image (Decode_Elapsed)
         & "s");
   end Run_Case;
begin
   Run_Case
     ("rgb-baseline-420-16x16",
      16,
      16,
      Jpeglib.Images.RGB_24,
      (Quality => 90, Subsampling => Jpeglib.Encoding.Subsampling_420, others => <>),
      100);

   Run_Case
     ("rgb-progressive-444-16x16",
      16,
      16,
      Jpeglib.Images.RGB_24,
      (Quality => 90,
       Progressive => Jpeglib.Encoding.Balanced_Progressive,
       Subsampling => Jpeglib.Encoding.Subsampling_444,
       others => <>),
      50);

   Run_Case
     ("rgb-arithmetic-444-16x16",
      16,
      16,
      Jpeglib.Images.RGB_24,
      (Quality => 90,
       Mode => Jpeglib.Encoding.Arithmetic_Sequential_DCT,
       Subsampling => Jpeglib.Encoding.Subsampling_444,
       others => <>),
      50);

   Run_Case
     ("rgb-lossless-16x16",
      16,
      16,
      Jpeglib.Images.RGB_24,
      (Mode => Jpeglib.Encoding.Lossless_Huffman,
       Lossless_Predictor => 1,
       others => <>),
      50);

   Run_Case
     ("cmyk-baseline-16x16",
      16,
      16,
      Jpeglib.Images.CMYK_32,
      (Quality => 90, others => <>),
      50);

   Run_Case
     ("cmyk-lossless-16x16",
      16,
      16,
      Jpeglib.Images.CMYK_32,
      (Mode => Jpeglib.Encoding.Lossless_Huffman,
       Lossless_Predictor => 1,
       others => <>),
      50);

   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
end Jpeglib_Benchmark;

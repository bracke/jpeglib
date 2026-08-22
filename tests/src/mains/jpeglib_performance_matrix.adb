with Ada.Calendar;
with Ada.Command_Line;
with Ada.Text_IO;

with Hostkit.Host;

with Jpeglib.Decoding;
with Jpeglib.Encoding;
with Jpeglib.Errors;
with Jpeglib.Images;
with Jpeglib.Internal.Colors;
with Jpeglib.Results;
with Jpeglib.Streams;

with Jpeglib_Tools;

procedure Jpeglib_Performance_Matrix is
   use type Ada.Calendar.Time;
   use type Jpeglib.Errors.Error_Code;
   use type Jpeglib.Streams.Byte_Array;

   Width : constant Jpeglib.Image_Width := 32;
   Height : constant Jpeglib.Image_Height := 32;
   Input_Bytes : constant Natural := Natural (Width) * Natural (Height) * 3;
   Iterations : constant Positive := 25;
   Max_Total_Seconds : constant Duration := 10.0;

   Input_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. Input_Bytes => 0];
   First_Encoded : aliased Jpeglib.Streams.Byte_Array := [1 .. 262_144 => 0];
   Second_Encoded : aliased Jpeglib.Streams.Byte_Array := [1 .. 262_144 => 0];
   Decoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. Input_Bytes => 0];
   Failures : Natural := 0;

   procedure Fail (Message : String; Error : Jpeglib.Errors.Error_Code := Jpeglib.Errors.No_Error) is
   begin
      if Error = Jpeglib.Errors.No_Error then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_performance_matrix: " & Message);
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "jpeglib_performance_matrix: " & Message & ": " & Jpeglib.Errors.Error_Code'Image (Error));
      end if;
      Failures := Failures + 1;
   end Fail;

   procedure Fill_Input is
      Cursor : Positive := Input_Storage'First;
   begin
      for Row in 0 .. Natural (Height) - 1 loop
         for Column in 0 .. Natural (Width) - 1 loop
            Input_Storage (Cursor) := Jpeglib.Byte ((Row * 11 + Column * 17) mod 256);
            Input_Storage (Cursor + 1) := Jpeglib.Byte ((Row * 29 + Column * 3) mod 256);
            Input_Storage (Cursor + 2) := Jpeglib.Byte ((Row * Column + 97) mod 256);
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

   function Output_View return Jpeglib.Images.Mutable_Image_View is
   begin
      return
        (Descriptor =>
           (Width => Width,
            Height => Height,
            Format => Jpeglib.Images.RGB_24,
            Stride => Jpeglib.Row_Stride (Natural (Width) * 3),
            Accessible_Bytes => Jpeglib.Byte_Count (Input_Bytes)),
         Storage => Decoded_Storage'Unchecked_Access);
   end Output_View;

   function Encode_Once
     (Options : Jpeglib.Encoding.Options;
      Storage : not null Jpeglib.Streams.Byte_Array_Access) return Natural
   is
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Encoder : Jpeglib.Encoding.Encoder;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Storage);
      Jpeglib.Encoding.Initialize (Encoder, Destination'Access, Options);
      Outcome := Jpeglib.Encoding.Encode_Image (Encoder, Input_View);
      if not Jpeglib.Results.Succeeded (Outcome) then
         Fail ("encode failed", Outcome.First_Error.Code);
         return 0;
      end if;
      return Natural (Jpeglib.Streams.Offset (Destination));
   end Encode_Once;

   function Decode_Once
     (Storage : Jpeglib.Streams.Byte_Array;
      Length : Natural) return Jpeglib.Results.Result
   is
      Encoded_Copy : aliased constant Jpeglib.Streams.Byte_Array :=
        Storage (Storage'First .. Storage'First + Length - 1);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Output : Jpeglib.Images.Mutable_Image_View := Output_View;
   begin
      Jpeglib.Streams.Open (Source, Encoded_Copy'Unchecked_Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         (Output_Format => Jpeglib.Images.RGB_24, others => <>));
      return Jpeglib.Decoding.Decode_Image (Decoder, Output);
   end Decode_Once;

   procedure Run_Case
     (Label : String;
      Options : Jpeglib.Encoding.Options)
   is
      First_Length : Natural;
      Second_Length : Natural;
      Outcome : Jpeglib.Results.Result;
      Started : Ada.Calendar.Time;
      Elapsed : Duration;
   begin
      First_Length := Encode_Once (Options, First_Encoded'Unchecked_Access);
      Second_Length := Encode_Once (Options, Second_Encoded'Unchecked_Access);
      if First_Length = 0 or else Second_Length = 0 then
         return;
      elsif First_Length /= Second_Length then
         Fail (Label & " scalar output length is not deterministic");
      elsif First_Encoded (1 .. First_Length) /= Second_Encoded (1 .. Second_Length) then
         Fail (Label & " scalar output bytes are not deterministic");
      end if;

      Outcome := Decode_Once (First_Encoded, First_Length);
      if not Jpeglib.Results.Succeeded (Outcome) then
         Fail (Label & " decode failed", Outcome.First_Error.Code);
         return;
      end if;

      Started := Ada.Calendar.Clock;
      for Iteration in 1 .. Iterations loop
         First_Length := Encode_Once (Options, First_Encoded'Unchecked_Access);
         if First_Length = 0 then
            return;
         end if;
         Outcome := Decode_Once (First_Encoded, First_Length);
         if not Jpeglib.Results.Succeeded (Outcome) then
            Fail (Label & " loop decode failed", Outcome.First_Error.Code);
            return;
         end if;
      end loop;
      Elapsed := Ada.Calendar.Clock - Started;

      if Elapsed > Max_Total_Seconds then
         Fail (Label & " exceeded scalar threshold:" & Duration'Image (Elapsed));
      end if;

      Ada.Text_IO.Put_Line
        ("jpeglib_performance_matrix: "
         & Label
         & " bytes="
         & Natural'Image (First_Length)
         & " iterations="
         & Positive'Image (Iterations)
         & " elapsed="
         & Duration'Image (Elapsed)
         & "s");
   end Run_Case;
begin
   Fill_Input;
   Ada.Text_IO.Put_Line
     ("jpeglib_performance_matrix: host="
      & Hostkit.Host.Kind'Image (Hostkit.Host.Current)
      & " machine="
      & Hostkit.Host.Machine_Name
      & " acceleration="
      & Jpeglib.Internal.Colors.Acceleration_Profile'Image (Jpeglib.Internal.Colors.Active_Acceleration));

   Run_Case
     ("accelerated-baseline-420",
      (Quality => 85,
       Subsampling => Jpeglib.Encoding.Subsampling_420,
       others => <>));
   Run_Case
     ("accelerated-progressive-444",
      (Quality => 85,
       Progressive => Jpeglib.Encoding.Fast_Preview_Progressive,
       Subsampling => Jpeglib.Encoding.Subsampling_444,
       Optimize_Huffman => True,
       others => <>));
   Run_Case
     ("accelerated-arithmetic-444",
      (Quality => 85,
       Mode => Jpeglib.Encoding.Arithmetic_Sequential_DCT,
       Subsampling => Jpeglib.Encoding.Subsampling_444,
       others => <>));

   if Failures = 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Test_Failure)));
   end if;
end Jpeglib_Performance_Matrix;

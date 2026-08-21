with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;

with Jpeglib.Decoding;
with Jpeglib.Encoding;
with Jpeglib.Errors;
with Jpeglib.Images;
with Jpeglib.Results;
with Jpeglib.Streams;

with Jpeglib_Tools;

procedure Jpeglib_Fuzz is
   use type Jpeglib.Byte_Count;
   use type Jpeglib.Errors.Error_Code;

   Failures : Natural := 0;
   Cases_Run : Natural := 0;

   type Prefix_Array is array (Positive range <>) of Natural;

   procedure Fail (Label : String; Message : String) is
   begin
      Failures := Failures + 1;
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_fuzz: " & Label & ": " & Message);
   end Fail;

   procedure Fuzz_Header
     (Label : String;
      Data : Jpeglib.Streams.Byte_Array;
      Should_Succeed : Boolean := False)
   is
      Copy : aliased constant Jpeglib.Streams.Byte_Array := Data;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
   begin
      Cases_Run := Cases_Run + 1;
      Jpeglib.Streams.Open (Source, Copy'Unchecked_Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);

      if Should_Succeed and then not Jpeglib.Results.Succeeded (Outcome) then
         Fail (Label, "header rejected valid input");
      elsif not Should_Succeed and then Jpeglib.Results.Succeeded (Outcome) then
         Fail (Label, "malformed header unexpectedly succeeded");
      elsif not Should_Succeed and then Outcome.First_Error.Code = Jpeglib.Errors.No_Error then
         Fail (Label, "malformed header failed without an error code");
      end if;
   exception
      when Error : others =>
         Fail (Label, "raised " & Ada.Exceptions.Exception_Name (Error));
   end Fuzz_Header;

   procedure Fuzz_Image
     (Label : String;
      Data : Jpeglib.Streams.Byte_Array;
      Should_Succeed : Boolean := False;
      Width : Jpeglib.Image_Width := 16;
      Height : Jpeglib.Image_Height := 16)
   is
      Copy : aliased constant Jpeglib.Streams.Byte_Array := Data;
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 16 * 16 * 3 => 0];
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Output : Jpeglib.Images.Mutable_Image_View :=
        (Descriptor =>
           (Width => Width,
            Height => Height,
            Format => Jpeglib.Images.RGB_24,
            Stride => Jpeglib.Row_Stride (Natural (Width) * 3),
            Accessible_Bytes => Jpeglib.Byte_Count (Width) * Jpeglib.Byte_Count (Height) * 3),
         Storage => Output_Storage'Unchecked_Access);
      Outcome : Jpeglib.Results.Result;
   begin
      Cases_Run := Cases_Run + 1;
      Jpeglib.Streams.Open (Source, Copy'Unchecked_Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         (Output_Format => Jpeglib.Images.RGB_24, others => <>));
      Outcome := Jpeglib.Decoding.Decode_Image (Decoder, Output);

      if Should_Succeed and then not Jpeglib.Results.Succeeded (Outcome) then
         Fail (Label, "image decode rejected valid input");
      elsif not Should_Succeed and then Jpeglib.Results.Succeeded (Outcome) then
         Fail (Label, "malformed image unexpectedly decoded");
      elsif not Should_Succeed and then Outcome.First_Error.Code = Jpeglib.Errors.No_Error then
         Fail (Label, "malformed image failed without an error code");
      end if;
   exception
      when Error : others =>
         Fail (Label, "raised " & Ada.Exceptions.Exception_Name (Error));
   end Fuzz_Image;

   procedure Generate_Valid_JPEG
     (Label : String;
      Options : Jpeglib.Encoding.Options;
      Storage : aliased in out Jpeglib.Streams.Byte_Array;
      Last : out Natural)
   is
      Input_Storage : aliased Jpeglib.Streams.Byte_Array :=
        [255, 0, 0,
         0, 255, 0,
         0, 0, 255,
         255, 255, 255];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Encoder : Jpeglib.Encoding.Encoder;
      Input : constant Jpeglib.Images.Image_View :=
        (Descriptor =>
           (Width => 2,
            Height => 2,
            Format => Jpeglib.Images.RGB_24,
            Stride => 6,
            Accessible_Bytes => 12),
         Storage => Input_Storage'Unchecked_Access);
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Destination, Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize (Encoder, Destination'Access, Options);
      Outcome := Jpeglib.Encoding.Encode_Image (Encoder, Input);
      if not Jpeglib.Results.Succeeded (Outcome) then
         Fail (Label, "valid JPEG seed generation failed");
         Last := 0;
      else
         Last := Natural (Jpeglib.Streams.Offset (Destination));
      end if;
   exception
      when Error : others =>
         Fail (Label, "raised " & Ada.Exceptions.Exception_Name (Error));
         Last := 0;
   end Generate_Valid_JPEG;

   procedure Run_Generated_Seed
     (Label : String;
      Options : Jpeglib.Encoding.Options)
   is
      Seed_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 8192 => 0];
      Seed_Last : Natural := 0;
   begin
      Generate_Valid_JPEG (Label & "-generation", Options, Seed_Storage, Seed_Last);
      if Seed_Last > 0 then
         Fuzz_Header (Label & "-header", Seed_Storage (1 .. Seed_Last), Should_Succeed => True);
         Fuzz_Image
           (Label & "-image",
            Seed_Storage (1 .. Seed_Last),
            Should_Succeed => True,
            Width => 2,
            Height => 2);

         declare
            Prefixes : constant Prefix_Array :=
              [1, 2, 3, 7, 16, 32, Natural'Max (1, Seed_Last / 2), Natural'Max (1, Seed_Last - 2)];
         begin
            for Prefix of Prefixes loop
               if Prefix < Seed_Last then
                  Fuzz_Image
                    (Label & "-prefix-" & Natural'Image (Prefix),
                     Seed_Storage (1 .. Prefix));
               end if;
            end loop;
         end;
      end if;
   end Run_Generated_Seed;

   One_Byte : constant Jpeglib.Streams.Byte_Array := [1 => 16#FF#];
   Not_JPEG : constant Jpeglib.Streams.Byte_Array := [16#00#, 16#11#, 16#22#, 16#33#];
   SOI_Only : constant Jpeglib.Streams.Byte_Array := [16#FF#, 16#D8#];
   Truncated_APP0 : constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#, 16#FF#, 16#E0#, 16#00#, 16#10#, 16#4A#, 16#46#];
   Bad_DQT_Zero : constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#, 16#FF#, 16#DB#, 16#00#, 16#43#, 16#00#,
      16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#];
   Bad_Segment_Length_One : constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#, 16#FF#, 16#E1#, 16#00#, 16#01#];
   Truncated_DHT : constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#, 16#FF#, 16#C4#, 16#00#, 16#1F#, 16#00#, 0, 1, 2];
   Invalid_Progressive_SOS : constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#C2#, 0, 11, 8, 0, 8, 0, 8, 1, 1, 16#11#, 0,
      16#FF#, 16#DA#, 0, 8, 1, 1, 0, 1, 0, 0];
   Unsupported_Advanced_SOF : constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#CB#,
      0, 11,
      8, 0, 8, 0, 8, 1,
      1, 16#11#, 0];
begin
   Fuzz_Header ("one-byte", One_Byte);
   Fuzz_Header ("not-jpeg", Not_JPEG);
   Fuzz_Header ("soi-only", SOI_Only);
   Fuzz_Header ("truncated-app0", Truncated_APP0);
   Fuzz_Header ("bad-dqt-zero", Bad_DQT_Zero);
   Fuzz_Header ("bad-segment-length-one", Bad_Segment_Length_One);
   Fuzz_Header ("truncated-dht", Truncated_DHT);
   Fuzz_Header ("invalid-progressive-sos", Invalid_Progressive_SOS);
   Fuzz_Header ("unsupported-advanced-sof", Unsupported_Advanced_SOF);
   Fuzz_Image ("not-jpeg-image", Not_JPEG);
   Fuzz_Image ("soi-only-image", SOI_Only);

   Run_Generated_Seed
     ("valid-generated-baseline",
      (Quality => 100, Subsampling => Jpeglib.Encoding.Subsampling_420, others => <>));
   Run_Generated_Seed
     ("valid-generated-restart",
      (Quality => 100, Restart => 1, Subsampling => Jpeglib.Encoding.Subsampling_444, others => <>));
   Run_Generated_Seed
     ("valid-generated-progressive",
      (Quality => 100,
       Progressive => Jpeglib.Encoding.Balanced_Progressive,
       Subsampling => Jpeglib.Encoding.Subsampling_444,
       others => <>));
   Run_Generated_Seed
     ("valid-generated-arithmetic",
      (Quality => 100,
       Mode => Jpeglib.Encoding.Arithmetic_Sequential_DCT,
       Subsampling => Jpeglib.Encoding.Subsampling_444,
       others => <>));
   Run_Generated_Seed
     ("valid-generated-arithmetic-progressive",
      (Quality => 100,
       Mode => Jpeglib.Encoding.Arithmetic_Sequential_DCT,
       Progressive => Jpeglib.Encoding.Balanced_Progressive,
       Subsampling => Jpeglib.Encoding.Subsampling_444,
       others => <>));
   Run_Generated_Seed
     ("valid-generated-lossless",
      (Mode => Jpeglib.Encoding.Lossless_Huffman,
       Lossless_Predictor => 1,
       others => <>));
   Run_Generated_Seed
     ("valid-generated-arithmetic-lossless",
      (Mode => Jpeglib.Encoding.Arithmetic_Lossless,
       Lossless_Predictor => 1,
       others => <>));

   if Failures = 0 then
      Ada.Text_IO.Put_Line ("jpeglib_fuzz: " & Natural'Image (Cases_Run) & " deterministic cases passed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "jpeglib_fuzz: " & Natural'Image (Failures) & " failure(s) across " & Natural'Image (Cases_Run) & " cases");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Test_Failure)));
   end if;
end Jpeglib_Fuzz;

with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;

with Jpeglib.Decoding;
with Jpeglib.Encoding;
with Jpeglib.Errors;
with Jpeglib.Images;
with Jpeglib.Results;
with Jpeglib.Streams;

with Jpeglib_Tools;
with Project_Tools.Files;
with Project_Tools.Processes;

procedure Jpeglib_Conformance is
   use type Jpeglib.Images.Pixel_Format;

   function To_String (Data : Jpeglib.Streams.Byte_Array; Last : Natural) return String is
      Result : String (1 .. Last);
   begin
      for Index in Result'Range loop
         Result (Index) := Character'Val (Natural (Data (Data'First + Index - 1)));
      end loop;

      return Result;
   end To_String;

   function Byte_At (Data : String; Index : Positive) return Natural is
     (Character'Pos (Data (Index)));

   procedure Fail (Message : String; Detail : String := "") is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_conformance: " & Message);
      if Detail /= "" then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_conformance: " & Detail);
      end if;
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Conformance_Failure)));
   end Fail;

   Root : constant String :=
     Project_Tools.Files.Find_Root_Upward
       (Ada.Directories.Current_Directory, "alire.toml");
   Decode_Raw : constant String :=
     (if Root = "" then "" else Project_Tools.Files.Join (Root, "tests/bin/jpeglib_decode_raw"));
   FFMPEG : constant String := Project_Tools.Processes.Locate_Command ("ffmpeg");

   function Image (Value : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Both));

   function Generated_RGB_Input
     (Width  : Jpeglib.Image_Width;
      Height : Jpeglib.Image_Height) return Jpeglib.Streams.Byte_Array
   is
      Result : Jpeglib.Streams.Byte_Array (1 .. Natural (Width) * Natural (Height) * 3);
      Cursor : Positive := Result'First;
   begin
      for Y in 0 .. Natural (Height) - 1 loop
         for X in 0 .. Natural (Width) - 1 loop
            Result (Cursor) := Jpeglib.Byte (24 + X * 5 + Y * 3);
            Result (Cursor + 1) := Jpeglib.Byte (48 + X * 4 + Y * 6);
            Result (Cursor + 2) := Jpeglib.Byte (72 + X * 3 + Y * 2);
            Cursor := Cursor + 3;
         end loop;
      end loop;

      return Result;
   end Generated_RGB_Input;

   function Generated_Gray_Input
     (Width  : Jpeglib.Image_Width;
      Height : Jpeglib.Image_Height) return Jpeglib.Streams.Byte_Array
   is
      Result : Jpeglib.Streams.Byte_Array (1 .. Natural (Width) * Natural (Height));
      Cursor : Positive := Result'First;
   begin
      for Y in 0 .. Natural (Height) - 1 loop
         for X in 0 .. Natural (Width) - 1 loop
            Result (Cursor) := Jpeglib.Byte (20 + X * 7 + Y * 5);
            Cursor := Cursor + 1;
         end loop;
      end loop;

      return Result;
   end Generated_Gray_Input;

   procedure Run_Process_Raw_Oracle
     (Label         : String;
      Artifact_Path : String;
      Format        : String;
      Width         : Jpeglib.Image_Width;
      Height        : Jpeglib.Image_Height;
      Expected      : Jpeglib.Streams.Byte_Array;
      Tolerance     : Natural;
      Failed        : in out Boolean)
   is
      Status : aliased Integer := -1;
      Output : constant String :=
        Project_Tools.Processes.Command_Output
          (Decode_Raw,
           Project_Tools.Processes.Arguments
             ([Project_Tools.Processes.Argument (Format),
               Project_Tools.Processes.Argument (Image (Natural (Width))),
               Project_Tools.Processes.Argument (Image (Natural (Height))),
               Project_Tools.Processes.Argument (Artifact_Path)]),
           Status => Status'Access,
           Err_To_Out => False);
      Difference : Natural;
   begin
      if Status /= 0 then
         Failed := True;
         Fail (Label & " jpeglib_decode_raw oracle failed", "artifact: " & Artifact_Path);
         return;
      elsif Output'Length /= Expected'Length then
         Failed := True;
         Fail (Label & " jpeglib_decode_raw oracle length mismatch", "artifact: " & Artifact_Path);
         return;
      end if;

      for Index in Expected'Range loop
         if Byte_At (Output, Index - Expected'First + Output'First) > Natural (Expected (Index)) then
            Difference := Byte_At (Output, Index - Expected'First + Output'First) - Natural (Expected (Index));
         else
            Difference := Natural (Expected (Index)) - Byte_At (Output, Index - Expected'First + Output'First);
         end if;

         if Difference > Tolerance then
            Failed := True;
            Fail (Label & " jpeglib_decode_raw oracle sample mismatch", "artifact: " & Artifact_Path);
            return;
         end if;
      end loop;
   end Run_Process_Raw_Oracle;

   procedure Run_FFMPEG_RGB_Oracle
     (Label         : String;
      Artifact_Path : String;
      Expected      : Jpeglib.Streams.Byte_Array;
      Tolerance     : Natural;
      Failed        : in out Boolean)
   is
      Status : aliased Integer := -1;
   begin
      if FFMPEG = "" then
         Failed := True;
         Fail (Label & " ffmpeg oracle not found", "artifact: " & Artifact_Path);
         return;
      end if;

      declare
         Output : constant String :=
           Project_Tools.Processes.Command_Output
             (FFMPEG,
              Project_Tools.Processes.Arguments
                ([Project_Tools.Processes.Argument ("-v"),
                  Project_Tools.Processes.Argument ("error"),
                  Project_Tools.Processes.Argument ("-i"),
                  Project_Tools.Processes.Argument (Artifact_Path),
                  Project_Tools.Processes.Argument ("-f"),
                  Project_Tools.Processes.Argument ("rawvideo"),
                  Project_Tools.Processes.Argument ("-pix_fmt"),
                  Project_Tools.Processes.Argument ("rgb24"),
                  Project_Tools.Processes.Argument ("pipe:1")]),
              Status => Status'Access,
              Err_To_Out => False);
         Difference : Natural;
      begin
         if Status /= 0 then
            Failed := True;
            Fail (Label & " ffmpeg reference decode failed", "artifact: " & Artifact_Path);
            return;
         elsif Output'Length /= Expected'Length then
            Failed := True;
            Fail (Label & " ffmpeg reference output length mismatch", "artifact: " & Artifact_Path);
            return;
         end if;

         for Index in Expected'Range loop
            if Byte_At (Output, Index - Expected'First + Output'First) > Natural (Expected (Index)) then
               Difference := Byte_At (Output, Index - Expected'First + Output'First) - Natural (Expected (Index));
            else
               Difference := Natural (Expected (Index)) - Byte_At (Output, Index - Expected'First + Output'First);
            end if;

            if Difference > Tolerance then
               Failed := True;
               Fail (Label & " ffmpeg reference pixel mismatch", "artifact: " & Artifact_Path);
               return;
            end if;
         end loop;
      end;
   end Run_FFMPEG_RGB_Oracle;

   procedure Run_FFMPEG_Gray_Oracle
     (Label         : String;
      Artifact_Path : String;
      Expected      : Jpeglib.Streams.Byte_Array;
      Tolerance     : Natural;
      Failed        : in out Boolean)
   is
      Status : aliased Integer := -1;
   begin
      if FFMPEG = "" then
         Failed := True;
         Fail (Label & " ffmpeg oracle not found", "artifact: " & Artifact_Path);
         return;
      end if;

      declare
         Output : constant String :=
           Project_Tools.Processes.Command_Output
             (FFMPEG,
              Project_Tools.Processes.Arguments
                ([Project_Tools.Processes.Argument ("-v"),
                  Project_Tools.Processes.Argument ("error"),
                  Project_Tools.Processes.Argument ("-i"),
                  Project_Tools.Processes.Argument (Artifact_Path),
                  Project_Tools.Processes.Argument ("-f"),
                  Project_Tools.Processes.Argument ("rawvideo"),
                  Project_Tools.Processes.Argument ("-pix_fmt"),
                  Project_Tools.Processes.Argument ("gray"),
                  Project_Tools.Processes.Argument ("pipe:1")]),
              Status => Status'Access,
              Err_To_Out => False);
         Difference : Natural;
      begin
         if Status /= 0 then
            Failed := True;
            Fail (Label & " ffmpeg grayscale reference decode failed", "artifact: " & Artifact_Path);
            return;
         elsif Output'Length /= Expected'Length then
            Failed := True;
            Fail (Label & " ffmpeg grayscale output length mismatch", "artifact: " & Artifact_Path);
            return;
         end if;

         for Index in Expected'Range loop
            if Byte_At (Output, Index - Expected'First + Output'First) > Natural (Expected (Index)) then
               Difference := Byte_At (Output, Index - Expected'First + Output'First) - Natural (Expected (Index));
            else
               Difference := Natural (Expected (Index)) - Byte_At (Output, Index - Expected'First + Output'First);
            end if;

            if Difference > Tolerance then
               Failed := True;
               Fail (Label & " ffmpeg grayscale sample mismatch", "artifact: " & Artifact_Path);
               return;
            end if;
         end loop;
      end;
   end Run_FFMPEG_Gray_Oracle;

   procedure Run_FFMPEG_CMYK_RGB_Oracle
     (Label         : String;
      Artifact_Path : String;
      Expected_CMYK : Jpeglib.Streams.Byte_Array;
      Tolerance     : Natural;
      Failed        : in out Boolean)
   is
      Status : aliased Integer := -1;
      Expected_Length : constant Natural := (Expected_CMYK'Length / 4) * 3;
      Output : constant String :=
        (if FFMPEG = "" then ""
         else
           Project_Tools.Processes.Command_Output
             (FFMPEG,
              Project_Tools.Processes.Arguments
                ([Project_Tools.Processes.Argument ("-v"),
                  Project_Tools.Processes.Argument ("error"),
                  Project_Tools.Processes.Argument ("-i"),
                  Project_Tools.Processes.Argument (Artifact_Path),
                  Project_Tools.Processes.Argument ("-f"),
                  Project_Tools.Processes.Argument ("rawvideo"),
                  Project_Tools.Processes.Argument ("-pix_fmt"),
                  Project_Tools.Processes.Argument ("rgb24"),
                  Project_Tools.Processes.Argument ("pipe:1")]),
              Status => Status'Access,
              Err_To_Out => False));
      Expected_Sample : Natural;
      Difference : Natural;
      Pixel_First : Positive;
   begin
      if FFMPEG = "" then
         Failed := True;
         Fail (Label & " ffmpeg oracle not found", "artifact: " & Artifact_Path);
         return;
      elsif Status /= 0 then
         Failed := True;
         Fail (Label & " ffmpeg CMYK/YCCK RGB reference decode failed", "artifact: " & Artifact_Path);
         return;
      elsif Output'Length /= Expected_Length then
         Failed := True;
         Fail (Label & " ffmpeg CMYK/YCCK RGB output length mismatch", "artifact: " & Artifact_Path);
         return;
      end if;

      for Pixel in 0 .. Expected_CMYK'Length / 4 - 1 loop
         Pixel_First := Expected_CMYK'First + Pixel * 4;
         for Channel in 0 .. 2 loop
            Expected_Sample :=
              Natural (Expected_CMYK (Pixel_First + Channel))
              * Natural (Expected_CMYK (Pixel_First + 3))
              / 255;
            if Byte_At (Output, Output'First + Pixel * 3 + Channel) > Expected_Sample then
               Difference := Byte_At (Output, Output'First + Pixel * 3 + Channel) - Expected_Sample;
            else
               Difference := Expected_Sample - Byte_At (Output, Output'First + Pixel * 3 + Channel);
            end if;

            if Difference > Tolerance then
               Failed := True;
               Fail (Label & " ffmpeg CMYK/YCCK RGB sample mismatch", "artifact: " & Artifact_Path);
               return;
            end if;
         end loop;
      end loop;
   end Run_FFMPEG_CMYK_RGB_Oracle;

   procedure Run_Magick_Generated_RGB_Case
     (Label         : String;
      Artifact_Name : String;
      Magick        : String;
      Failed        : in out Boolean;
      Progressive   : Boolean := False)
   is
      Input_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
        [0, 32, 64,
         96, 128, 160,
         192, 224, 240,
         255, 16, 48];
      Decoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 12 => 0];
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Output : Jpeglib.Images.Mutable_Image_View :=
        (Descriptor =>
           (Width => 2,
            Height => 2,
            Format => Jpeglib.Images.RGB_24,
            Stride => 6,
            Accessible_Bytes => 12),
         Storage => Decoded_Storage'Unchecked_Access);
      Artifact_Path : constant String :=
        Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, Artifact_Name);
      Magick_Status : aliased Integer := -1;
      Difference : Natural;
      Outcome : Jpeglib.Results.Result;
   begin
      declare
         Encoded : constant String :=
           Project_Tools.Processes.Command_Output
             (Magick,
              Project_Tools.Processes.Arguments
                ((if Progressive then
                    [Project_Tools.Processes.Argument ("-size"),
                     Project_Tools.Processes.Argument ("2x2"),
                     Project_Tools.Processes.Argument ("-depth"),
                     Project_Tools.Processes.Argument ("8"),
                     Project_Tools.Processes.Argument ("rgb:-"),
                     Project_Tools.Processes.Argument ("-quality"),
                     Project_Tools.Processes.Argument ("100"),
                     Project_Tools.Processes.Argument ("-sampling-factor"),
                     Project_Tools.Processes.Argument ("1x1"),
                     Project_Tools.Processes.Argument ("-interlace"),
                     Project_Tools.Processes.Argument ("Plane"),
                     Project_Tools.Processes.Argument ("jpeg:-")]
                  else
                    [Project_Tools.Processes.Argument ("-size"),
                     Project_Tools.Processes.Argument ("2x2"),
                     Project_Tools.Processes.Argument ("-depth"),
                     Project_Tools.Processes.Argument ("8"),
                     Project_Tools.Processes.Argument ("rgb:-"),
                     Project_Tools.Processes.Argument ("-quality"),
                     Project_Tools.Processes.Argument ("100"),
                     Project_Tools.Processes.Argument ("-sampling-factor"),
                     Project_Tools.Processes.Argument ("1x1"),
                     Project_Tools.Processes.Argument ("jpeg:-")])),
              Input => To_String (Input_Storage, Input_Storage'Length),
              Status => Magick_Status'Access,
              Err_To_Out => True);
         Encoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. Encoded'Length => 0];
      begin
         if Magick_Status /= 0 or else Encoded'Length = 0 then
            Failed := True;
            Fail (Label & " ImageMagick encode failed", "artifact: " & Artifact_Path);
            return;
         end if;

         Project_Tools.Files.Write_Raw_File (Artifact_Path, Encoded);
         for Index in Encoded'Range loop
            Encoded_Storage (Index - Encoded'First + 1) := Jpeglib.Byte (Character'Pos (Encoded (Index)));
         end loop;

         Jpeglib.Streams.Open (Source, Encoded_Storage'Unchecked_Access);
         Jpeglib.Decoding.Initialize
           (Decoder,
            Source'Access,
            (Output_Format => Jpeglib.Images.RGB_24, others => <>));
         Outcome := Jpeglib.Decoding.Decode_Image (Decoder, Output);
      end;

      if not Jpeglib.Results.Succeeded (Outcome) then
         Failed := True;
         Fail (Label & " jpeglib decode of ImageMagick artifact failed", "artifact: " & Artifact_Path);
         return;
      end if;

      for Index in Input_Storage'Range loop
         if Natural (Decoded_Storage (Index)) > Natural (Input_Storage (Index)) then
            Difference := Natural (Decoded_Storage (Index)) - Natural (Input_Storage (Index));
         else
            Difference := Natural (Input_Storage (Index)) - Natural (Decoded_Storage (Index));
         end if;

         if Difference > 3 then
            Failed := True;
            Fail (Label & " jpeglib decode of ImageMagick artifact mismatched", "artifact: " & Artifact_Path);
            return;
         end if;
      end loop;

      Ada.Text_IO.Put_Line ("jpeglib_conformance: " & Label & " passed external-generated decode check");
   end Run_Magick_Generated_RGB_Case;

   procedure Run_Magick_Generated_Gray_Case
     (Label         : String;
      Artifact_Name : String;
      Magick        : String;
      Failed        : in out Boolean;
      Progressive   : Boolean := False)
   is
      Input_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
        [16, 96,
         160, 240];
      Decoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 4 => 0];
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Output : Jpeglib.Images.Mutable_Image_View :=
        (Descriptor =>
           (Width => 2,
            Height => 2,
            Format => Jpeglib.Images.Gray_8,
            Stride => 2,
            Accessible_Bytes => 4),
         Storage => Decoded_Storage'Unchecked_Access);
      Artifact_Path : constant String :=
        Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, Artifact_Name);
      Magick_Status : aliased Integer := -1;
      Difference : Natural;
      Outcome : Jpeglib.Results.Result;
   begin
      declare
         Encoded : constant String :=
           Project_Tools.Processes.Command_Output
             (Magick,
              Project_Tools.Processes.Arguments
                ((if Progressive then
                    [Project_Tools.Processes.Argument ("-size"),
                     Project_Tools.Processes.Argument ("2x2"),
                     Project_Tools.Processes.Argument ("-depth"),
                     Project_Tools.Processes.Argument ("8"),
                     Project_Tools.Processes.Argument ("gray:-"),
                     Project_Tools.Processes.Argument ("-quality"),
                     Project_Tools.Processes.Argument ("100"),
                     Project_Tools.Processes.Argument ("-interlace"),
                     Project_Tools.Processes.Argument ("Plane"),
                     Project_Tools.Processes.Argument ("jpeg:-")]
                  else
                    [Project_Tools.Processes.Argument ("-size"),
                     Project_Tools.Processes.Argument ("2x2"),
                     Project_Tools.Processes.Argument ("-depth"),
                     Project_Tools.Processes.Argument ("8"),
                     Project_Tools.Processes.Argument ("gray:-"),
                     Project_Tools.Processes.Argument ("-quality"),
                     Project_Tools.Processes.Argument ("100"),
                     Project_Tools.Processes.Argument ("jpeg:-")])),
              Input => To_String (Input_Storage, Input_Storage'Length),
              Status => Magick_Status'Access,
              Err_To_Out => True);
         Encoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. Encoded'Length => 0];
      begin
         if Magick_Status /= 0 or else Encoded'Length = 0 then
            Failed := True;
            Fail (Label & " ImageMagick encode failed", "artifact: " & Artifact_Path);
            return;
         end if;

         Project_Tools.Files.Write_Raw_File (Artifact_Path, Encoded);
         for Index in Encoded'Range loop
            Encoded_Storage (Index - Encoded'First + 1) := Jpeglib.Byte (Character'Pos (Encoded (Index)));
         end loop;

         Jpeglib.Streams.Open (Source, Encoded_Storage'Unchecked_Access);
         Jpeglib.Decoding.Initialize
           (Decoder,
            Source'Access,
            (Output_Format => Jpeglib.Images.Gray_8, others => <>));
         Outcome := Jpeglib.Decoding.Decode_Image (Decoder, Output);
      end;

      if not Jpeglib.Results.Succeeded (Outcome) then
         Failed := True;
         Fail (Label & " jpeglib decode of ImageMagick artifact failed", "artifact: " & Artifact_Path);
         return;
      end if;

      for Index in Input_Storage'Range loop
         if Natural (Decoded_Storage (Index)) > Natural (Input_Storage (Index)) then
            Difference := Natural (Decoded_Storage (Index)) - Natural (Input_Storage (Index));
         else
            Difference := Natural (Input_Storage (Index)) - Natural (Decoded_Storage (Index));
         end if;

         if Difference > 3 then
            Failed := True;
            Fail (Label & " jpeglib decode of ImageMagick artifact mismatched", "artifact: " & Artifact_Path);
            return;
         end if;
      end loop;

      Ada.Text_IO.Put_Line ("jpeglib_conformance: " & Label & " passed external-generated decode check");
   end Run_Magick_Generated_Gray_Case;

   procedure Run_Magick_Generated_RGB_Corpus_Case
     (Label           : String;
      Artifact_Name   : String;
      Magick          : String;
      Width           : Jpeglib.Image_Width;
      Height          : Jpeglib.Image_Height;
      Input_Storage   : Jpeglib.Streams.Byte_Array;
      Quality         : Natural;
      Sampling_Factor : String;
      Tolerance       : Natural;
      Failed          : in out Boolean;
      Progressive     : Boolean := False)
   is
      Decoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. Input_Storage'Length => 0];
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Output : Jpeglib.Images.Mutable_Image_View :=
        (Descriptor =>
           (Width => Width,
            Height => Height,
            Format => Jpeglib.Images.RGB_24,
            Stride => Jpeglib.Row_Stride (Natural (Width) * 3),
            Accessible_Bytes => Jpeglib.Byte_Count (Input_Storage'Length)),
         Storage => Decoded_Storage'Unchecked_Access);
      Artifact_Path : constant String :=
        Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, Artifact_Name);
      Magick_Status : aliased Integer := -1;
      Difference : Natural;
      Outcome : Jpeglib.Results.Result;
   begin
      declare
         Encoded : constant String :=
           Project_Tools.Processes.Command_Output
             (Magick,
              Project_Tools.Processes.Arguments
                ((if Progressive then
                    [Project_Tools.Processes.Argument ("-size"),
                     Project_Tools.Processes.Argument
                       (Image (Natural (Width)) & "x" & Image (Natural (Height))),
                     Project_Tools.Processes.Argument ("-depth"),
                     Project_Tools.Processes.Argument ("8"),
                     Project_Tools.Processes.Argument ("rgb:-"),
                     Project_Tools.Processes.Argument ("-quality"),
                     Project_Tools.Processes.Argument (Image (Quality)),
                     Project_Tools.Processes.Argument ("-sampling-factor"),
                     Project_Tools.Processes.Argument (Sampling_Factor),
                     Project_Tools.Processes.Argument ("-interlace"),
                     Project_Tools.Processes.Argument ("Plane"),
                     Project_Tools.Processes.Argument ("jpeg:-")]
                  else
                    [Project_Tools.Processes.Argument ("-size"),
                     Project_Tools.Processes.Argument
                       (Image (Natural (Width)) & "x" & Image (Natural (Height))),
                     Project_Tools.Processes.Argument ("-depth"),
                     Project_Tools.Processes.Argument ("8"),
                     Project_Tools.Processes.Argument ("rgb:-"),
                     Project_Tools.Processes.Argument ("-quality"),
                     Project_Tools.Processes.Argument (Image (Quality)),
                     Project_Tools.Processes.Argument ("-sampling-factor"),
                     Project_Tools.Processes.Argument (Sampling_Factor),
                     Project_Tools.Processes.Argument ("jpeg:-")])),
              Input => To_String (Input_Storage, Input_Storage'Length),
              Status => Magick_Status'Access,
              Err_To_Out => True);
         Encoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. Encoded'Length => 0];
      begin
         if Magick_Status /= 0 or else Encoded'Length = 0 then
            Failed := True;
            Fail (Label & " ImageMagick encode failed", "artifact: " & Artifact_Path);
            return;
         end if;

         Project_Tools.Files.Write_Raw_File (Artifact_Path, Encoded);
         for Index in Encoded'Range loop
            Encoded_Storage (Index - Encoded'First + 1) :=
              Jpeglib.Byte (Character'Pos (Encoded (Index)));
         end loop;

         Jpeglib.Streams.Open (Source, Encoded_Storage'Unchecked_Access);
         Jpeglib.Decoding.Initialize
           (Decoder,
            Source'Access,
            (Output_Format => Jpeglib.Images.RGB_24, others => <>));
         Outcome := Jpeglib.Decoding.Decode_Image (Decoder, Output);
      end;

      if not Jpeglib.Results.Succeeded (Outcome) then
         Failed := True;
         Fail (Label & " jpeglib decode of ImageMagick artifact failed", "artifact: " & Artifact_Path);
         return;
      end if;

      for Index in Input_Storage'Range loop
         if Natural (Decoded_Storage (Index)) > Natural (Input_Storage (Index)) then
            Difference := Natural (Decoded_Storage (Index)) - Natural (Input_Storage (Index));
         else
            Difference := Natural (Input_Storage (Index)) - Natural (Decoded_Storage (Index));
         end if;

         if Difference > Tolerance then
            Failed := True;
            Fail (Label & " jpeglib decode of ImageMagick artifact mismatched", "artifact: " & Artifact_Path);
            return;
         end if;
      end loop;

      Ada.Text_IO.Put_Line ("jpeglib_conformance: " & Label & " passed external-generated decode check");
   end Run_Magick_Generated_RGB_Corpus_Case;

   procedure Run_Magick_Generated_Gray_Corpus_Case
     (Label         : String;
      Artifact_Name : String;
      Magick        : String;
      Width         : Jpeglib.Image_Width;
      Height        : Jpeglib.Image_Height;
      Input_Storage : Jpeglib.Streams.Byte_Array;
      Quality       : Natural;
      Tolerance     : Natural;
      Failed        : in out Boolean;
      Progressive   : Boolean := False)
   is
      Decoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. Input_Storage'Length => 0];
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Output : Jpeglib.Images.Mutable_Image_View :=
        (Descriptor =>
           (Width => Width,
            Height => Height,
            Format => Jpeglib.Images.Gray_8,
            Stride => Jpeglib.Row_Stride (Width),
            Accessible_Bytes => Jpeglib.Byte_Count (Input_Storage'Length)),
         Storage => Decoded_Storage'Unchecked_Access);
      Artifact_Path : constant String :=
        Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, Artifact_Name);
      Magick_Status : aliased Integer := -1;
      Difference : Natural;
      Outcome : Jpeglib.Results.Result;
   begin
      declare
         Encoded : constant String :=
           Project_Tools.Processes.Command_Output
             (Magick,
              Project_Tools.Processes.Arguments
                ((if Progressive then
                    [Project_Tools.Processes.Argument ("-size"),
                     Project_Tools.Processes.Argument
                       (Image (Natural (Width)) & "x" & Image (Natural (Height))),
                     Project_Tools.Processes.Argument ("-depth"),
                     Project_Tools.Processes.Argument ("8"),
                     Project_Tools.Processes.Argument ("gray:-"),
                     Project_Tools.Processes.Argument ("-quality"),
                     Project_Tools.Processes.Argument (Image (Quality)),
                     Project_Tools.Processes.Argument ("-interlace"),
                     Project_Tools.Processes.Argument ("Plane"),
                     Project_Tools.Processes.Argument ("jpeg:-")]
                  else
                    [Project_Tools.Processes.Argument ("-size"),
                     Project_Tools.Processes.Argument
                       (Image (Natural (Width)) & "x" & Image (Natural (Height))),
                     Project_Tools.Processes.Argument ("-depth"),
                     Project_Tools.Processes.Argument ("8"),
                     Project_Tools.Processes.Argument ("gray:-"),
                     Project_Tools.Processes.Argument ("-quality"),
                     Project_Tools.Processes.Argument (Image (Quality)),
                     Project_Tools.Processes.Argument ("jpeg:-")])),
              Input => To_String (Input_Storage, Input_Storage'Length),
              Status => Magick_Status'Access,
              Err_To_Out => True);
         Encoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. Encoded'Length => 0];
      begin
         if Magick_Status /= 0 or else Encoded'Length = 0 then
            Failed := True;
            Fail (Label & " ImageMagick encode failed", "artifact: " & Artifact_Path);
            return;
         end if;

         Project_Tools.Files.Write_Raw_File (Artifact_Path, Encoded);
         for Index in Encoded'Range loop
            Encoded_Storage (Index - Encoded'First + 1) :=
              Jpeglib.Byte (Character'Pos (Encoded (Index)));
         end loop;

         Jpeglib.Streams.Open (Source, Encoded_Storage'Unchecked_Access);
         Jpeglib.Decoding.Initialize
           (Decoder,
            Source'Access,
            (Output_Format => Jpeglib.Images.Gray_8, others => <>));
         Outcome := Jpeglib.Decoding.Decode_Image (Decoder, Output);
      end;

      if not Jpeglib.Results.Succeeded (Outcome) then
         Failed := True;
         Fail (Label & " jpeglib decode of ImageMagick artifact failed", "artifact: " & Artifact_Path);
         return;
      end if;

      for Index in Input_Storage'Range loop
         if Natural (Decoded_Storage (Index)) > Natural (Input_Storage (Index)) then
            Difference := Natural (Decoded_Storage (Index)) - Natural (Input_Storage (Index));
         else
            Difference := Natural (Input_Storage (Index)) - Natural (Decoded_Storage (Index));
         end if;

         if Difference > Tolerance then
            Failed := True;
            Fail (Label & " jpeglib decode of ImageMagick artifact mismatched", "artifact: " & Artifact_Path);
            return;
         end if;
      end loop;

      Ada.Text_IO.Put_Line ("jpeglib_conformance: " & Label & " passed external-generated decode check");
   end Run_Magick_Generated_Gray_Corpus_Case;

   procedure Run_RGB_Encode_Case
     (Label         : String;
      Artifact_Name : String;
      Options       : Jpeglib.Encoding.Options;
      Magick        : String;
      Failed        : in out Boolean;
      Require_External_Decode : Boolean := True;
      Require_FFMPEG_Decode   : Boolean := False)
   is
      Input_Storage : aliased Jpeglib.Streams.Byte_Array :=
        [255, 0, 0,
         255, 0, 0,
         255, 0, 0,
         255, 0, 0];
      Encoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 4096 => 0];
      Jpeglib_Decoded : aliased Jpeglib.Streams.Byte_Array := [1 .. 12 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Encoder : Jpeglib.Encoding.Encoder;
      Decoder : Jpeglib.Decoding.Decoder;
      Input : constant Jpeglib.Images.Image_View :=
        (Descriptor =>
           (Width => 2,
            Height => 2,
            Format => Jpeglib.Images.RGB_24,
            Stride => 6,
            Accessible_Bytes => 12),
         Storage => Input_Storage'Unchecked_Access);
      Output : Jpeglib.Images.Mutable_Image_View :=
        (Descriptor =>
           (Width => 2,
            Height => 2,
            Format => Jpeglib.Images.RGB_24,
            Stride => 6,
            Accessible_Bytes => 12),
         Storage => Jpeglib_Decoded'Unchecked_Access);
      Outcome : Jpeglib.Results.Result;
      Artifact_Path : constant String :=
        Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, Artifact_Name);
      Magick_Status : aliased Integer := -1;
      Difference : Natural;
      Encoded_Last : Natural;
   begin
      Jpeglib.Streams.Open (Destination, Encoded_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize (Encoder, Destination'Access, Options);
      Outcome := Jpeglib.Encoding.Encode_Image (Encoder, Input);
      if not Jpeglib.Results.Succeeded (Outcome) then
         Failed := True;
         Fail (Label & " encode failed", Jpeglib.Errors.Error_Code'Image (Outcome.First_Error.Code));
         return;
      end if;

      Encoded_Last := Natural (Jpeglib.Streams.Offset (Destination));
      Project_Tools.Files.Write_Raw_File (Artifact_Path, To_String (Encoded_Storage, Encoded_Last));

      Jpeglib.Streams.Open (Source, Encoded_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         (Output_Format => Jpeglib.Images.RGB_24, others => <>));
      Outcome := Jpeglib.Decoding.Decode_Image (Decoder, Output);
      if not Jpeglib.Results.Succeeded (Outcome) then
         Failed := True;
         Fail (Label & " self-decode failed", "artifact: " & Artifact_Path);
         return;
      end if;

      Run_Process_Raw_Oracle
        (Label,
         Artifact_Path,
         "rgb",
         2,
         2,
         Input_Storage,
         3,
         Failed);
      if Failed then
         return;
      end if;

      if Require_FFMPEG_Decode then
         Run_FFMPEG_RGB_Oracle
           (Label,
            Artifact_Path,
            Input_Storage,
            0,
            Failed);
         if Failed then
            return;
         end if;
      end if;

      declare
         Magick_Output : constant String :=
           Project_Tools.Processes.Command_Output
             (Magick,
              Project_Tools.Processes.Arguments
                ([Project_Tools.Processes.Argument ("jpeg:-"),
                  Project_Tools.Processes.Argument ("-depth"),
                  Project_Tools.Processes.Argument ("8"),
                  Project_Tools.Processes.Argument ("rgb:-")]),
              Input => To_String (Encoded_Storage, Encoded_Last),
              Status => Magick_Status'Access,
              Err_To_Out => True);
      begin
         if Magick_Status /= 0 then
            if Require_External_Decode then
               Failed := True;
               Fail (Label & " ImageMagick reference decode failed", "artifact: " & Artifact_Path);
            else
               Ada.Text_IO.Put_Line
                 ("jpeglib_conformance: " & Label
                  & (if Require_FFMPEG_Decode then
                       " passed native process and ffmpeg oracles; ImageMagick rejected optional external decode"
                     else
                       " passed native process oracle; ImageMagick rejected optional external decode"));
            end if;
            return;
         elsif Magick_Output'Length /= Input_Storage'Length then
            if Require_External_Decode then
               Failed := True;
               Fail (Label & " ImageMagick reference output length mismatch", "artifact: " & Artifact_Path);
            else
               Ada.Text_IO.Put_Line
                 ("jpeglib_conformance: " & Label
                  & (if Require_FFMPEG_Decode then
                       " passed native process and ffmpeg oracles; ImageMagick optional external output length differed"
                     else
                       " passed native process oracle; ImageMagick optional external output length differed"));
            end if;
            return;
         end if;

         for Index in Input_Storage'Range loop
            if Byte_At (Magick_Output, Index) > Natural (Input_Storage (Index)) then
               Difference := Byte_At (Magick_Output, Index) - Natural (Input_Storage (Index));
            else
               Difference := Natural (Input_Storage (Index)) - Byte_At (Magick_Output, Index);
            end if;

            if Difference > 3 then
               Failed := True;
               Fail (Label & " ImageMagick reference pixel mismatch", "artifact: " & Artifact_Path);
               return;
            end if;

            if Natural (Jpeglib_Decoded (Index)) > Natural (Input_Storage (Index)) then
               Difference := Natural (Jpeglib_Decoded (Index)) - Natural (Input_Storage (Index));
            else
               Difference := Natural (Input_Storage (Index)) - Natural (Jpeglib_Decoded (Index));
            end if;

            if Difference > 3 then
               Failed := True;
               Fail (Label & " self-decode pixel mismatch", "artifact: " & Artifact_Path);
               return;
            end if;
         end loop;
      end;

      Ada.Text_IO.Put_Line
        ("jpeglib_conformance: " & Label & " passed native process and external decode checks");
   end Run_RGB_Encode_Case;

   procedure Run_Gray_Encode_Case
     (Label         : String;
      Artifact_Name : String;
      Options       : Jpeglib.Encoding.Options;
      Magick        : String;
      Failed        : in out Boolean;
      Require_External_Decode : Boolean := True;
      Require_FFMPEG_Decode   : Boolean := False)
   is
      Input_Storage : aliased Jpeglib.Streams.Byte_Array :=
        [16, 96,
         160, 240];
      Encoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 2048 => 0];
      Jpeglib_Decoded : aliased Jpeglib.Streams.Byte_Array := [1 .. 4 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Encoder : Jpeglib.Encoding.Encoder;
      Decoder : Jpeglib.Decoding.Decoder;
      Input : constant Jpeglib.Images.Image_View :=
        (Descriptor =>
           (Width => 2,
            Height => 2,
            Format => Jpeglib.Images.Gray_8,
            Stride => 2,
            Accessible_Bytes => 4),
         Storage => Input_Storage'Unchecked_Access);
      Output : Jpeglib.Images.Mutable_Image_View :=
        (Descriptor =>
           (Width => 2,
            Height => 2,
            Format => Jpeglib.Images.Gray_8,
            Stride => 2,
            Accessible_Bytes => 4),
         Storage => Jpeglib_Decoded'Unchecked_Access);
      Outcome : Jpeglib.Results.Result;
      Artifact_Path : constant String :=
        Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, Artifact_Name);
      Magick_Status : aliased Integer := -1;
      Difference : Natural;
      Encoded_Last : Natural;
   begin
      Jpeglib.Streams.Open (Destination, Encoded_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize (Encoder, Destination'Access, Options);
      Outcome := Jpeglib.Encoding.Encode_Image (Encoder, Input);
      if not Jpeglib.Results.Succeeded (Outcome) then
         Failed := True;
         Fail (Label & " encode failed", Jpeglib.Errors.Error_Code'Image (Outcome.First_Error.Code));
         return;
      end if;

      Encoded_Last := Natural (Jpeglib.Streams.Offset (Destination));
      Project_Tools.Files.Write_Raw_File (Artifact_Path, To_String (Encoded_Storage, Encoded_Last));

      Jpeglib.Streams.Open (Source, Encoded_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         (Output_Format => Jpeglib.Images.Gray_8, others => <>));
      Outcome := Jpeglib.Decoding.Decode_Image (Decoder, Output);
      if not Jpeglib.Results.Succeeded (Outcome) then
         Failed := True;
         Fail (Label & " self-decode failed", "artifact: " & Artifact_Path);
         return;
      end if;

      Run_Process_Raw_Oracle
        (Label,
         Artifact_Path,
         "gray",
         2,
         2,
         Input_Storage,
         2,
         Failed);
      if Failed then
         return;
      end if;

      if Require_FFMPEG_Decode then
         Run_FFMPEG_Gray_Oracle
           (Label,
            Artifact_Path,
            Input_Storage,
            0,
            Failed);
         if Failed then
            return;
         end if;
      end if;

      declare
         Magick_Output : constant String :=
           Project_Tools.Processes.Command_Output
             (Magick,
              Project_Tools.Processes.Arguments
                ([Project_Tools.Processes.Argument ("jpeg:-"),
                  Project_Tools.Processes.Argument ("-depth"),
                  Project_Tools.Processes.Argument ("8"),
                  Project_Tools.Processes.Argument ("gray:-")]),
              Input => To_String (Encoded_Storage, Encoded_Last),
              Status => Magick_Status'Access,
              Err_To_Out => True);
      begin
         if Magick_Status /= 0 then
            if Require_External_Decode then
               Failed := True;
               Fail (Label & " ImageMagick reference decode failed", "artifact: " & Artifact_Path);
            else
               Ada.Text_IO.Put_Line
                 ("jpeglib_conformance: " & Label
                  & (if Require_FFMPEG_Decode then
                       " passed native process and ffmpeg oracles; ImageMagick rejected optional external decode"
                     else
                       " passed native process oracle; ImageMagick rejected optional external decode"));
            end if;
            return;
         elsif Magick_Output'Length /= Input_Storage'Length then
            if Require_External_Decode then
               Failed := True;
               Fail (Label & " ImageMagick reference output length mismatch", "artifact: " & Artifact_Path);
            else
               Ada.Text_IO.Put_Line
                 ("jpeglib_conformance: " & Label
                  & (if Require_FFMPEG_Decode then
                       " passed native process and ffmpeg oracles; ImageMagick optional external output length differed"
                     else
                       " passed native process oracle; ImageMagick optional external output length differed"));
            end if;
            return;
         end if;

         for Index in Input_Storage'Range loop
            if Byte_At (Magick_Output, Index) > Natural (Input_Storage (Index)) then
               Difference := Byte_At (Magick_Output, Index) - Natural (Input_Storage (Index));
            else
               Difference := Natural (Input_Storage (Index)) - Byte_At (Magick_Output, Index);
            end if;

            if Difference > 2 then
               Failed := True;
               Fail (Label & " ImageMagick reference sample mismatch", "artifact: " & Artifact_Path);
               return;
            end if;

            if Natural (Jpeglib_Decoded (Index)) > Natural (Input_Storage (Index)) then
               Difference := Natural (Jpeglib_Decoded (Index)) - Natural (Input_Storage (Index));
            else
               Difference := Natural (Input_Storage (Index)) - Natural (Jpeglib_Decoded (Index));
            end if;

            if Difference > 2 then
               Failed := True;
               Fail (Label & " self-decode sample mismatch", "artifact: " & Artifact_Path);
               return;
            end if;
         end loop;
      end;

      Ada.Text_IO.Put_Line
        ("jpeglib_conformance: " & Label
         & (if Require_FFMPEG_Decode then
              " passed native process, ffmpeg, and external decode checks"
            else
              " passed native process and external decode checks"));
   end Run_Gray_Encode_Case;

   procedure Run_Four_Channel_Encode_Case
     (Label         : String;
      Artifact_Name : String;
      Format        : Jpeglib.Images.Pixel_Format;
      Options       : Jpeglib.Encoding.Options;
      Magick        : String;
      Failed        : in out Boolean;
      Require_External_Decode : Boolean := True;
      Require_FFMPEG_RGB_Decode : Boolean := False)
   is
      Input_Storage : aliased Jpeglib.Streams.Byte_Array :=
        [126, 127, 128, 129,
         127, 128, 129, 130,
         128, 129, 130, 131,
         129, 130, 131, 132];
      Encoded_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. 8192 => 0];
      Jpeglib_Decoded : aliased Jpeglib.Streams.Byte_Array := [1 .. 16 => 0];
      Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
      Source : aliased Jpeglib.Streams.Memory_Source;
      Encoder : Jpeglib.Encoding.Encoder;
      Decoder : Jpeglib.Decoding.Decoder;
      Input : constant Jpeglib.Images.Image_View :=
        (Descriptor =>
           (Width => 2,
            Height => 2,
            Format => Format,
            Stride => 8,
            Accessible_Bytes => 16),
         Storage => Input_Storage'Unchecked_Access);
      Output : Jpeglib.Images.Mutable_Image_View :=
        (Descriptor =>
           (Width => 2,
            Height => 2,
            Format => Format,
            Stride => 8,
            Accessible_Bytes => 16),
         Storage => Jpeglib_Decoded'Unchecked_Access);
      Outcome : Jpeglib.Results.Result;
      Artifact_Path : constant String :=
        Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, Artifact_Name);
      Magick_Status : aliased Integer := -1;
      Difference : Natural;
      Encoded_Last : Natural;
   begin
      Jpeglib.Streams.Open (Destination, Encoded_Storage'Unchecked_Access);
      Jpeglib.Encoding.Initialize (Encoder, Destination'Access, Options);
      Outcome := Jpeglib.Encoding.Encode_Image (Encoder, Input);
      if not Jpeglib.Results.Succeeded (Outcome) then
         Failed := True;
         Fail (Label & " encode failed", Jpeglib.Errors.Error_Code'Image (Outcome.First_Error.Code));
         return;
      end if;

      Encoded_Last := Natural (Jpeglib.Streams.Offset (Destination));
      Project_Tools.Files.Write_Raw_File (Artifact_Path, To_String (Encoded_Storage, Encoded_Last));

      Jpeglib.Streams.Open (Source, Encoded_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         (Output_Format => Format, others => <>));
      Outcome := Jpeglib.Decoding.Decode_Image (Decoder, Output);
      if not Jpeglib.Results.Succeeded (Outcome) then
         Failed := True;
         Fail (Label & " self-decode failed", "artifact: " & Artifact_Path);
         return;
      end if;

      Run_Process_Raw_Oracle
        (Label,
         Artifact_Path,
         (if Format = Jpeglib.Images.YCCK_32 then "ycck" else "cmyk"),
         2,
         2,
         Input_Storage,
         4,
         Failed);
      if Failed then
         return;
      end if;

      if Require_FFMPEG_RGB_Decode then
         Run_FFMPEG_CMYK_RGB_Oracle
           (Label,
            Artifact_Path,
            Input_Storage,
            1,
            Failed);
         if Failed then
            return;
         end if;
      end if;

      declare
         Magick_Output : constant String :=
           Project_Tools.Processes.Command_Output
             (Magick,
              Project_Tools.Processes.Arguments
                ([Project_Tools.Processes.Argument ("jpeg:-"),
                  Project_Tools.Processes.Argument ("-depth"),
                  Project_Tools.Processes.Argument ("8"),
                  Project_Tools.Processes.Argument ("cmyk:-")]),
              Input => To_String (Encoded_Storage, Encoded_Last),
              Status => Magick_Status'Access,
              Err_To_Out => True);
      begin
         if Magick_Status /= 0 then
            if Require_External_Decode then
               Failed := True;
               Fail (Label & " ImageMagick reference decode failed", "artifact: " & Artifact_Path);
            else
               Ada.Text_IO.Put_Line
                 ("jpeglib_conformance: " & Label
                  & (if Require_FFMPEG_RGB_Decode then
                       " passed native process and ffmpeg RGB oracles; ImageMagick rejected optional external decode"
                     else
                       " passed native process oracle; ImageMagick rejected optional external decode"));
            end if;
            return;
         elsif Magick_Output'Length /= Input_Storage'Length then
            Failed := True;
            Fail (Label & " ImageMagick reference output length mismatch", "artifact: " & Artifact_Path);
            return;
         end if;

         for Index in Input_Storage'Range loop
            if Byte_At (Magick_Output, Index) > Natural (Input_Storage (Index)) then
               Difference := Byte_At (Magick_Output, Index) - Natural (Input_Storage (Index));
            else
               Difference := Natural (Input_Storage (Index)) - Byte_At (Magick_Output, Index);
            end if;

            if Difference > 4 then
               if Require_External_Decode then
                  Failed := True;
                  Fail (Label & " ImageMagick reference channel mismatch", "artifact: " & Artifact_Path);
               else
                  Ada.Text_IO.Put_Line
                    ("jpeglib_conformance: " & Label
                     & (if Require_FFMPEG_RGB_Decode then
                          " passed native process and ffmpeg RGB oracles; "
                          & "ImageMagick optional external channels differed"
                        else
                          " passed native process oracle; ImageMagick optional external channels differed"));
               end if;
               return;
            end if;

            if Natural (Jpeglib_Decoded (Index)) > Natural (Input_Storage (Index)) then
               Difference := Natural (Jpeglib_Decoded (Index)) - Natural (Input_Storage (Index));
            else
               Difference := Natural (Input_Storage (Index)) - Natural (Jpeglib_Decoded (Index));
            end if;

            if Difference > 4 then
               Failed := True;
               Fail (Label & " self-decode channel mismatch", "artifact: " & Artifact_Path);
               return;
            end if;
         end loop;
      end;

      Ada.Text_IO.Put_Line
        ("jpeglib_conformance: " & Label
         & (if Require_FFMPEG_RGB_Decode then
              " passed native process, ffmpeg RGB, and external decode checks"
            else
              " passed native process and external decode checks"));
   end Run_Four_Channel_Encode_Case;

   Magick : constant String := Project_Tools.Processes.Locate_Command ("magick");
   Failed : Boolean := False;
begin
   if Root = "" then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_conformance: run below the jpeglib tree");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
      return;
   elsif not Project_Tools.Files.File_Exists (Decode_Raw) then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "jpeglib_conformance: jpeglib_decode_raw oracle not found; run alr --chdir tests build");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
      return;
   end if;

   if Magick = "" then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_conformance: ImageMagick 'magick' not found");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
      return;
   end if;

   Run_Magick_Generated_RGB_Case
     ("ImageMagick-generated baseline RGB decode",
      "jpeglib-conformance-magick-rgb-2x2.jpg",
      Magick,
      Failed);

   Run_Magick_Generated_RGB_Case
     ("ImageMagick-generated progressive RGB decode",
      "jpeglib-conformance-magick-progressive-rgb-2x2.jpg",
      Magick,
      Failed,
      Progressive => True);

   Run_Magick_Generated_Gray_Case
     ("ImageMagick-generated baseline grayscale decode",
      "jpeglib-conformance-magick-gray-2x2.jpg",
      Magick,
      Failed);

   Run_Magick_Generated_Gray_Case
     ("ImageMagick-generated progressive grayscale decode",
      "jpeglib-conformance-magick-progressive-gray-2x2.jpg",
      Magick,
      Failed,
      Progressive => True);

   Run_Magick_Generated_RGB_Corpus_Case
     ("ImageMagick-generated baseline RGB 4x3 q90 4:2:0 decode",
      "jpeglib-conformance-magick-rgb-4x3-q90-420.jpg",
      Magick,
      4,
      3,
      [12, 28, 44, 52, 68, 84, 92, 108, 124, 132, 148, 164,
       32, 48, 64, 72, 88, 104, 112, 128, 144, 152, 168, 184,
       52, 68, 84, 92, 108, 124, 132, 148, 164, 172, 188, 204],
      90,
      "2x2",
      16,
      Failed);

   Run_Magick_Generated_RGB_Corpus_Case
     ("ImageMagick-generated progressive RGB 5x2 q85 4:4:4 decode",
      "jpeglib-conformance-magick-progressive-rgb-5x2-q85-444.jpg",
      Magick,
      5,
      2,
      [18, 42, 66, 48, 72, 96, 78, 102, 126, 108, 132, 156, 138, 162, 186,
       38, 62, 86, 68, 92, 116, 98, 122, 146, 128, 152, 176, 158, 182, 206],
      85,
      "1x1",
      18,
      Failed,
      Progressive => True);

   Run_Magick_Generated_Gray_Corpus_Case
     ("ImageMagick-generated baseline grayscale 5x3 q75 decode",
      "jpeglib-conformance-magick-gray-5x3-q75.jpg",
      Magick,
      5,
      3,
      [8, 32, 56, 80, 104,
       40, 64, 88, 112, 136,
       72, 96, 120, 144, 168],
      75,
      10,
      Failed);

   Run_Magick_Generated_Gray_Corpus_Case
     ("ImageMagick-generated progressive grayscale 4x4 q80 decode",
      "jpeglib-conformance-magick-progressive-gray-4x4-q80.jpg",
      Magick,
      4,
      4,
      [12, 36, 60, 84,
       44, 68, 92, 116,
       76, 100, 124, 148,
       108, 132, 156, 180],
      80,
      10,
      Failed,
      Progressive => True);

   Run_Magick_Generated_RGB_Corpus_Case
     ("ImageMagick-generated baseline RGB 17x9 q92 4:2:2 decode",
      "jpeglib-conformance-magick-rgb-17x9-q92-422.jpg",
      Magick,
      17,
      9,
      Generated_RGB_Input (17, 9),
      92,
      "2x1",
      24,
      Failed);

   Run_Magick_Generated_RGB_Corpus_Case
     ("ImageMagick-generated baseline RGB 9x17 q90 4:4:4 decode",
      "jpeglib-conformance-magick-rgb-9x17-q90-444.jpg",
      Magick,
      9,
      17,
      Generated_RGB_Input (9, 17),
      90,
      "1x1",
      20,
      Failed);

   Run_Magick_Generated_Gray_Corpus_Case
     ("ImageMagick-generated baseline grayscale 17x1 q88 decode",
      "jpeglib-conformance-magick-gray-17x1-q88.jpg",
      Magick,
      17,
      1,
      Generated_Gray_Input (17, 1),
      88,
      12,
      Failed);

   Run_Magick_Generated_Gray_Corpus_Case
     ("ImageMagick-generated baseline grayscale 2x17 q86 decode",
      "jpeglib-conformance-magick-gray-2x17-q86.jpg",
      Magick,
      2,
      17,
      Generated_Gray_Input (2, 17),
      86,
      12,
      Failed);

   Run_Magick_Generated_Gray_Corpus_Case
     ("ImageMagick-generated progressive grayscale 17x9 q84 decode",
      "jpeglib-conformance-magick-progressive-gray-17x9-q84.jpg",
      Magick,
      17,
      9,
      Generated_Gray_Input (17, 9),
      84,
      14,
      Failed,
      Progressive => True);

   Run_RGB_Encode_Case
     ("baseline RGB 4:2:0 encode",
      "jpeglib-conformance-rgb-2x2.jpg",
      (Quality => 100, Subsampling => Jpeglib.Encoding.Subsampling_420, others => <>),
      Magick,
      Failed);

   Run_RGB_Encode_Case
     ("baseline RGB 4:4:4 encode",
      "jpeglib-conformance-rgb-444-2x2.jpg",
      (Quality => 100, Subsampling => Jpeglib.Encoding.Subsampling_444, others => <>),
      Magick,
      Failed);

   Run_RGB_Encode_Case
     ("baseline RGB 4:2:2 encode",
      "jpeglib-conformance-rgb-422-2x2.jpg",
      (Quality => 100, Subsampling => Jpeglib.Encoding.Subsampling_422, others => <>),
      Magick,
      Failed);

   Run_RGB_Encode_Case
     ("baseline RGB 4:1:1 encode",
      "jpeglib-conformance-rgb-411-2x2.jpg",
      (Quality => 100, Subsampling => Jpeglib.Encoding.Subsampling_411, others => <>),
      Magick,
      Failed);

   Run_Gray_Encode_Case
     ("baseline grayscale encode",
      "jpeglib-conformance-gray-2x2.jpg",
      (Quality => 100, others => <>),
      Magick,
      Failed);

   Run_Four_Channel_Encode_Case
     ("baseline CMYK encode",
      "jpeglib-conformance-cmyk-2x2.jpg",
      Jpeglib.Images.CMYK_32,
      (Quality => 100, others => <>),
      Magick,
      Failed,
      Require_External_Decode => False,
      Require_FFMPEG_RGB_Decode => True);

   Run_Four_Channel_Encode_Case
     ("baseline YCCK encode",
      "jpeglib-conformance-ycck-2x2.jpg",
      Jpeglib.Images.YCCK_32,
      (Quality => 100, others => <>),
      Magick,
      Failed,
      Require_External_Decode => False,
      Require_FFMPEG_RGB_Decode => True);

   Run_RGB_Encode_Case
     ("arithmetic sequential RGB 4:4:4 encode",
      "jpeglib-conformance-arithmetic-rgb-444-2x2.jpg",
      (Quality => 100,
       Mode => Jpeglib.Encoding.Arithmetic_Sequential_DCT,
       Subsampling => Jpeglib.Encoding.Subsampling_444,
       others => <>),
      Magick,
      Failed,
      Require_External_Decode => False);

   Run_Gray_Encode_Case
     ("arithmetic sequential grayscale encode",
      "jpeglib-conformance-arithmetic-gray-2x2.jpg",
      (Quality => 100,
       Mode => Jpeglib.Encoding.Arithmetic_Sequential_DCT,
       others => <>),
      Magick,
      Failed,
      Require_External_Decode => False);

   Run_RGB_Encode_Case
     ("differential DCT RGB 4:4:4 encode",
      "jpeglib-conformance-differential-rgb-444-2x2.jpg",
      (Quality => 100,
       Mode => Jpeglib.Encoding.Differential_Sequential_DCT,
       Subsampling => Jpeglib.Encoding.Subsampling_444,
       others => <>),
      Magick,
      Failed,
      Require_External_Decode => False);

   Run_RGB_Encode_Case
     ("hierarchical DCT RGB 4:4:4 encode",
      "jpeglib-conformance-hierarchical-rgb-444-2x2.jpg",
      (Quality => 100,
       Mode => Jpeglib.Encoding.Hierarchical_Sequential_DCT,
       Subsampling => Jpeglib.Encoding.Subsampling_444,
       others => <>),
      Magick,
      Failed,
      Require_External_Decode => False);

   Run_RGB_Encode_Case
     ("lossless Huffman RGB encode",
      "jpeglib-conformance-lossless-rgb-2x2.jpg",
      (Mode => Jpeglib.Encoding.Lossless_Huffman,
       Lossless_Predictor => 1,
       others => <>),
      Magick,
      Failed,
      Require_External_Decode => False,
      Require_FFMPEG_Decode => True);

   Run_Gray_Encode_Case
     ("lossless Huffman grayscale encode",
      "jpeglib-conformance-lossless-gray-2x2.jpg",
      (Mode => Jpeglib.Encoding.Lossless_Huffman,
       Lossless_Predictor => 1,
       others => <>),
      Magick,
      Failed,
      Require_External_Decode => False,
      Require_FFMPEG_Decode => True);

   Run_RGB_Encode_Case
     ("hierarchical lossless RGB encode",
      "jpeglib-conformance-hierarchical-lossless-rgb-2x2.jpg",
      (Mode => Jpeglib.Encoding.Hierarchical_Lossless_Huffman,
       Lossless_Predictor => 1,
       others => <>),
      Magick,
      Failed,
      Require_External_Decode => False);

   Run_RGB_Encode_Case
     ("progressive RGB 4:2:0 encode",
      "jpeglib-conformance-progressive-rgb-2x2.jpg",
      (Quality => 100,
       Progressive => Jpeglib.Encoding.Balanced_Progressive,
       Subsampling => Jpeglib.Encoding.Subsampling_420,
       others => <>),
      Magick,
      Failed);

   Run_RGB_Encode_Case
     ("progressive RGB 4:4:4 encode",
      "jpeglib-conformance-progressive-rgb-444-2x2.jpg",
      (Quality => 100,
       Progressive => Jpeglib.Encoding.Balanced_Progressive,
       Subsampling => Jpeglib.Encoding.Subsampling_444,
       others => <>),
      Magick,
      Failed);

   Run_RGB_Encode_Case
     ("progressive RGB 4:2:2 encode",
      "jpeglib-conformance-progressive-rgb-422-2x2.jpg",
      (Quality => 100,
       Progressive => Jpeglib.Encoding.Balanced_Progressive,
       Subsampling => Jpeglib.Encoding.Subsampling_422,
       others => <>),
      Magick,
      Failed);

   Run_RGB_Encode_Case
     ("progressive RGB 4:1:1 encode",
      "jpeglib-conformance-progressive-rgb-411-2x2.jpg",
      (Quality => 100,
       Progressive => Jpeglib.Encoding.Balanced_Progressive,
       Subsampling => Jpeglib.Encoding.Subsampling_411,
       others => <>),
      Magick,
      Failed);

   Run_Gray_Encode_Case
     ("progressive grayscale encode",
      "jpeglib-conformance-progressive-gray-2x2.jpg",
      (Quality => 100,
       Progressive => Jpeglib.Encoding.Balanced_Progressive,
       others => <>),
      Magick,
      Failed);

   Run_Four_Channel_Encode_Case
     ("progressive CMYK encode",
      "jpeglib-conformance-progressive-cmyk-2x2.jpg",
      Jpeglib.Images.CMYK_32,
      (Quality => 100,
       Progressive => Jpeglib.Encoding.Balanced_Progressive,
       others => <>),
      Magick,
      Failed,
      Require_External_Decode => False,
      Require_FFMPEG_RGB_Decode => True);

   Run_Four_Channel_Encode_Case
     ("progressive YCCK encode",
      "jpeglib-conformance-progressive-ycck-2x2.jpg",
      Jpeglib.Images.YCCK_32,
      (Quality => 100,
       Progressive => Jpeglib.Encoding.Balanced_Progressive,
       others => <>),
      Magick,
      Failed,
      Require_External_Decode => False,
      Require_FFMPEG_RGB_Decode => True);

   Run_RGB_Encode_Case
     ("arithmetic progressive RGB 4:4:4 encode",
      "jpeglib-conformance-arithmetic-progressive-rgb-444-2x2.jpg",
      (Quality => 100,
       Mode => Jpeglib.Encoding.Arithmetic_Sequential_DCT,
       Progressive => Jpeglib.Encoding.Balanced_Progressive,
       Subsampling => Jpeglib.Encoding.Subsampling_444,
       others => <>),
      Magick,
      Failed,
      Require_External_Decode => False);

   Run_Gray_Encode_Case
     ("arithmetic progressive grayscale encode",
      "jpeglib-conformance-arithmetic-progressive-gray-2x2.jpg",
      (Quality => 100,
       Mode => Jpeglib.Encoding.Arithmetic_Sequential_DCT,
       Progressive => Jpeglib.Encoding.Balanced_Progressive,
       others => <>),
      Magick,
      Failed,
      Require_External_Decode => False);

   if not Failed then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   end if;
end Jpeglib_Conformance;

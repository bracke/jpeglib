with Ada.Command_Line;
with Ada.Text_IO;

with Jpeglib.Decoding;
with Jpeglib.Errors;
with Jpeglib.Images;
with Jpeglib.Results;
with Jpeglib.Streams;

with Jpeglib_Tools;
with Project_Tools.Files;

procedure Jpeglib_Decode_Raw is
   function Format_Of (Name : String) return Jpeglib.Images.Pixel_Format is
   begin
      if Name = "gray" then
         return Jpeglib.Images.Gray_8;
      elsif Name = "rgb" then
         return Jpeglib.Images.RGB_24;
      elsif Name = "cmyk" then
         return Jpeglib.Images.CMYK_32;
      elsif Name = "ycck" then
         return Jpeglib.Images.YCCK_32;
      else
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_decode_raw: unknown format " & Name);
         Ada.Command_Line.Set_Exit_Status
           (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
         return Jpeglib.Images.RGB_24;
      end if;
   end Format_Of;

   function To_Bytes (Data : String) return Jpeglib.Streams.Byte_Array is
      Result : Jpeglib.Streams.Byte_Array (1 .. Data'Length);
   begin
      for Index in Data'Range loop
         Result (Index - Data'First + 1) := Jpeglib.Byte (Character'Pos (Data (Index)));
      end loop;

      return Result;
   end To_Bytes;

   function To_String (Data : Jpeglib.Streams.Byte_Array) return String is
      Result : String (1 .. Data'Length);
   begin
      for Index in Data'Range loop
         Result (Index - Data'First + 1) := Character'Val (Natural (Data (Index)));
      end loop;

      return Result;
   end To_String;
begin
   if Ada.Command_Line.Argument_Count not in 4 .. 5 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: jpeglib_decode_raw FORMAT WIDTH HEIGHT JPEG_PATH [RAW_OUTPUT_PATH]");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
      return;
   end if;

   declare
      Format : constant Jpeglib.Images.Pixel_Format := Format_Of (Ada.Command_Line.Argument (1));
      Width  : constant Jpeglib.Image_Width := Jpeglib.Image_Width'Value (Ada.Command_Line.Argument (2));
      Height : constant Jpeglib.Image_Height := Jpeglib.Image_Height'Value (Ada.Command_Line.Argument (3));
      Path        : constant String := Ada.Command_Line.Argument (4);
      Output_Path : constant String :=
        (if Ada.Command_Line.Argument_Count = 5 then Ada.Command_Line.Argument (5) else "");
      Raw         : constant String := Project_Tools.Files.Read_Raw_File (Path);
   begin
      if Raw = "" then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_decode_raw: empty or unreadable input");
         Ada.Command_Line.Set_Exit_Status
           (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
         return;
      end if;

      declare
         Input_Storage  : aliased Jpeglib.Streams.Byte_Array := To_Bytes (Raw);
         Row_Bytes      : constant Natural := Natural (Jpeglib.Images.Minimum_Row_Bytes (Width, Format));
         Output_Length  : constant Natural := Row_Bytes * Natural (Height);
         Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. Output_Length => 0];
         Source         : aliased Jpeglib.Streams.Memory_Source;
         Decoder        : Jpeglib.Decoding.Decoder;
         Output         : Jpeglib.Images.Mutable_Image_View :=
           (Descriptor =>
              (Width => Width,
               Height => Height,
               Format => Format,
               Stride => Jpeglib.Row_Stride (Row_Bytes),
               Accessible_Bytes => Jpeglib.Byte_Count (Output_Length)),
            Storage => Output_Storage'Unchecked_Access);
         Outcome        : Jpeglib.Results.Result;
      begin
         Jpeglib.Streams.Open (Source, Input_Storage'Unchecked_Access);
         Jpeglib.Decoding.Initialize (Decoder, Source'Access, (Output_Format => Format, others => <>));
         Outcome := Jpeglib.Decoding.Decode_Image (Decoder, Output);

         if not Jpeglib.Results.Succeeded (Outcome) then
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "jpeglib_decode_raw: decode failed "
               & Jpeglib.Errors.Error_Code'Image (Outcome.First_Error.Code));
            Ada.Command_Line.Set_Exit_Status
              (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Conformance_Failure)));
            return;
         end if;

         if Output_Path = "" then
            Ada.Text_IO.Put (To_String (Output_Storage));
         else
            Project_Tools.Files.Write_Raw_File (Output_Path, To_String (Output_Storage));
         end if;

         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
      end;
   end;
exception
   when Constraint_Error =>
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_decode_raw: invalid numeric argument");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
end Jpeglib_Decode_Raw;

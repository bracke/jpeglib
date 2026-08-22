with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;

with Jpeglib;
with Jpeglib.Coefficients;
with Jpeglib.Decoding;
with Jpeglib.Errors;
with Jpeglib.Images;
with Jpeglib.Metadata;
with Jpeglib.Results;
with Jpeglib.Streams;
with Jpeglib_Tools;
with Jpeglib_Tools.Release_Digests;
with Project_Tools.Files;

procedure Jpeglib_Real_World is
   use type Jpeglib.Image_Width;
   use type Jpeglib.Image_Height;
   use type Jpeglib.Component_Count;
   use type Jpeglib.Encoded_Color_Model;
   use type Jpeglib.Frame_Mode;
   use type Jpeglib.Entropy_Mode;
   use type Jpeglib.Restart_Interval;
   use type Jpeglib.Errors.Error_Code;

   Root : constant String :=
     Project_Tools.Files.Find_Root_Upward
       (Ada.Directories.Current_Directory, "alire.toml");
   Allow_Empty : constant Boolean :=
     Ada.Command_Line.Argument_Count = 1 and then Ada.Command_Line.Argument (1) = "--allow-empty";
   Manifest_Relative : constant String := "tests/fixtures/real_world/manifest.txt";
   Manifest_Header : constant String :=
     "# id|path|source|license|category|mode|entry_points|outcome"
     & "|width|height|format|components|color_model|frame_mode|entropy"
     & "|progressive|hierarchical|restart|metadata_segments|expected_error"
     & "|file_sha256|decoded_sha256";
   Errors : Natural := 0;
   Entries : Natural := 0;
   Valid_Entries : Natural := 0;
   Reject_Entries : Natural := 0;

   procedure Fail (Message : String) is
   begin
      Errors := Errors + 1;
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_real_world: " & Message);
   end Fail;

   function Separator_Count (Line : String) return Natural is
      Count : Natural := 0;
   begin
      for Ch of Line loop
         if Ch = '|' then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Separator_Count;

   function Field (Line : String; Index : Positive) return String is
      Start : Positive := Line'First;
      Current : Positive := 1;
   begin
      for I in Line'Range loop
         if Line (I) = '|' then
            if Current = Index then
               return Line (Start .. I - 1);
            end if;
            Current := Current + 1;
            Start := I + 1;
         end if;
      end loop;
      if Current = Index then
         return Line (Start .. Line'Last);
      end if;
      return "";
   end Field;

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

   function Bool_Image (Value : Boolean) return String is
     (if Value then "true" else "false");

   function Is_True (Text : String) return Boolean is
     (Text = "true");

   function Natural_Image (Value : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Both));

   procedure Check_Decoded_Image
     (Id              : String;
      Path            : String;
      Content         : String;
      Expected_Width  : Jpeglib.Image_Width;
      Expected_Height : Jpeglib.Image_Height;
      Expected_Format : Jpeglib.Images.Pixel_Format;
      Expected_SHA256 : String)
   is
      Bytes_Per_Pixel : constant Jpeglib.Byte_Count :=
        Jpeglib.Images.Bytes_Per_Pixel (Expected_Format);
      Row_Bytes : constant Jpeglib.Byte_Count :=
        Jpeglib.Images.Minimum_Row_Bytes (Expected_Width, Expected_Format);
      Output_Bytes : constant Jpeglib.Byte_Count :=
        Jpeglib.Byte_Count (Natural (Row_Bytes) * Natural (Expected_Height));
      Input_Storage : aliased Jpeglib.Streams.Byte_Array := To_Bytes (Content);
      Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. Natural (Output_Bytes) => 0];
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      View : Jpeglib.Images.Mutable_Image_View :=
        (Descriptor =>
           (Width => Expected_Width,
            Height => Expected_Height,
            Format => Expected_Format,
            Stride => Jpeglib.Row_Stride (Row_Bytes),
            Accessible_Bytes => Output_Bytes),
         Storage => Output_Storage'Unchecked_Access);
      Outcome : Jpeglib.Results.Result;
      pragma Unreferenced (Bytes_Per_Pixel);
   begin
      Jpeglib.Streams.Open (Source, Input_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         (Output_Format => Expected_Format, Alpha_Fill => 0, others => <>));
      Outcome := Jpeglib.Decoding.Decode_Image (Decoder, View);
      if not Jpeglib.Results.Succeeded (Outcome) then
         Fail
           ("valid corpus image did not decode: "
            & Id
            & " path="
            & Path
            & " error="
            & Jpeglib.Errors.Error_Code'Image (Outcome.First_Error.Code));
      else
         declare
            Actual_SHA256 : constant String :=
              Jpeglib_Tools.Release_Digests.SHA256_Hex (To_String (Output_Storage));
         begin
            if Actual_SHA256 /= Expected_SHA256 then
               Fail
                 ("valid corpus image sha256 mismatch: "
                  & Id
                  & " expected="
                  & Expected_SHA256
                  & " got="
                  & Actual_SHA256);
            end if;
         end;
      end if;
   end Check_Decoded_Image;

   procedure Check_Header
     (Id                         : String;
      Content                    : String;
      Expected_Width             : Jpeglib.Image_Width;
      Expected_Height            : Jpeglib.Image_Height;
      Expected_Components        : Jpeglib.Component_Count;
      Expected_Color_Model       : Jpeglib.Encoded_Color_Model;
      Expected_Mode              : Jpeglib.Frame_Mode;
      Expected_Entropy           : Jpeglib.Entropy_Mode;
      Expected_Progressive       : Boolean;
      Expected_Hierarchical      : Boolean;
      Expected_Restart           : Jpeglib.Restart_Interval;
      Expected_Metadata_Segments : Natural)
   is
      Input_Storage : aliased Jpeglib.Streams.Byte_Array := To_Bytes (Content);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Outcome : Jpeglib.Results.Result;
      Info : Jpeglib.Decoding.Image_Info;
   begin
      Jpeglib.Streams.Open (Source, Input_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         (Metadata => Jpeglib.Metadata.Preserve_All_Bounded, others => <>));
      Outcome := Jpeglib.Decoding.Read_Header (Decoder);
      if not Jpeglib.Results.Succeeded (Outcome) then
         Fail ("valid corpus header did not decode: " & Id);
         return;
      end if;

      Info := Jpeglib.Decoding.Header (Decoder);
      if Info.Width /= Expected_Width
        or else Info.Height /= Expected_Height
        or else Info.Components /= Expected_Components
        or else Info.Color_Model /= Expected_Color_Model
        or else Info.Mode /= Expected_Mode
        or else Info.Entropy /= Expected_Entropy
        or else Info.Progressive /= Expected_Progressive
        or else Info.Hierarchical /= Expected_Hierarchical
        or else Info.Restart /= Expected_Restart
        or else Info.Metadata_Segments /= Expected_Metadata_Segments
      then
         Fail
           ("valid corpus header mismatch: "
            & Id
            & " got="
            & Natural_Image (Natural (Info.Width))
            & "x"
            & Natural_Image (Natural (Info.Height))
            & " components="
            & Natural_Image (Natural (Info.Components))
            & " color="
            & Jpeglib.Encoded_Color_Model'Image (Info.Color_Model)
            & " mode="
            & Jpeglib.Frame_Mode'Image (Info.Mode)
            & " entropy="
            & Jpeglib.Entropy_Mode'Image (Info.Entropy)
            & " progressive="
            & Bool_Image (Info.Progressive)
            & " hierarchical="
            & Bool_Image (Info.Hierarchical)
            & " restart="
            & Natural_Image (Natural (Info.Restart))
            & " metadata="
            & Natural_Image (Info.Metadata_Segments));
      end if;
   end Check_Header;

   procedure Check_Coefficient_Reject
     (Id             : String;
      Content        : String;
      Expected_Error : Jpeglib.Errors.Error_Code)
   is
      Input_Storage : aliased Jpeglib.Streams.Byte_Array := To_Bytes (Content);
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Blocks : Jpeglib.Coefficients.DCT_Block_Array (1 .. 1024) := [others => [others => 0]];
      Blocks_Decoded : Jpeglib.Block_Count := 0;
      Outcome : Jpeglib.Results.Result;
   begin
      Jpeglib.Streams.Open (Source, Input_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize (Decoder, Source'Access);
      Outcome := Jpeglib.Decoding.Decode_Coefficients (Decoder, Blocks, Blocks_Decoded);
      if Jpeglib.Results.Succeeded (Outcome) then
         Fail ("malformed corpus entry decoded successfully: " & Id);
      elsif Outcome.First_Error.Code /= Expected_Error then
         Fail
           ("malformed corpus error mismatch: "
            & Id
            & " expected="
            & Jpeglib.Errors.Error_Code'Image (Expected_Error)
            & " got="
            & Jpeglib.Errors.Error_Code'Image (Outcome.First_Error.Code));
      end if;
   end Check_Coefficient_Reject;

   procedure Check_Manifest is
      Path : constant String := Project_Tools.Files.Join (Root, Manifest_Relative);
      File : Ada.Text_IO.File_Type;
      Line : String (1 .. 4096);
      Last : Natural;
      Header_Found : Boolean := False;
   begin
      if not Project_Tools.Files.File_Exists (Path) then
         Fail ("missing " & Manifest_Relative);
         return;
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Line, Last);
         declare
            Text : constant String :=
              Ada.Strings.Fixed.Trim (Line (1 .. Last), Ada.Strings.Both);
         begin
            if Text = Manifest_Header then
               Header_Found := True;
            elsif Text'Length > 0 and then Text (Text'First) /= '#' then
               Entries := Entries + 1;
               if Separator_Count (Text) /= 21 then
                  Fail ("manifest entry has wrong column count: " & Text);
               else
                  declare
                     Id : constant String := Field (Text, 1);
                     Relative_Path : constant String := Field (Text, 2);
                     Outcome : constant String := Field (Text, 8);
                     Expected_Width : constant Jpeglib.Image_Width :=
                       Jpeglib.Image_Width'Value (Field (Text, 9));
                     Expected_Height : constant Jpeglib.Image_Height :=
                       Jpeglib.Image_Height'Value (Field (Text, 10));
                     Expected_Format : constant Jpeglib.Images.Pixel_Format :=
                       Jpeglib.Images.Pixel_Format'Value (Field (Text, 11));
                     Expected_Components : constant Jpeglib.Component_Count :=
                       Jpeglib.Component_Count'Value (Field (Text, 12));
                     Expected_Color_Model : constant Jpeglib.Encoded_Color_Model :=
                       Jpeglib.Encoded_Color_Model'Value (Field (Text, 13));
                     Expected_Mode : constant Jpeglib.Frame_Mode :=
                       Jpeglib.Frame_Mode'Value (Field (Text, 14));
                     Expected_Entropy : constant Jpeglib.Entropy_Mode :=
                       Jpeglib.Entropy_Mode'Value (Field (Text, 15));
                     Expected_Progressive : constant Boolean := Is_True (Field (Text, 16));
                     Expected_Hierarchical : constant Boolean := Is_True (Field (Text, 17));
                     Expected_Restart : constant Jpeglib.Restart_Interval :=
                       Jpeglib.Restart_Interval'Value (Field (Text, 18));
                     Expected_Metadata_Segments : constant Natural :=
                       Natural'Value (Field (Text, 19));
                     Expected_Error : constant Jpeglib.Errors.Error_Code :=
                       Jpeglib.Errors.Error_Code'Value (Field (Text, 20));
                     Expected_File_SHA256 : constant String := Field (Text, 21);
                     Expected_Decoded_SHA256 : constant String := Field (Text, 22);
                     Path : constant String := Project_Tools.Files.Join (Root, Relative_Path);
	                  begin
                     if Relative_Path = "" then
                        Fail ("manifest entry has empty path: " & Id);
                     elsif not Project_Tools.Files.File_Exists (Path) then
                        Fail ("manifest entry path is missing: " & Relative_Path);
                     elsif Expected_File_SHA256'Length /= 64 then
                        Fail ("manifest entry has invalid file sha256 length: " & Id);
                     elsif Jpeglib_Tools.Release_Digests.File_SHA256_Hex (Path) /= Expected_File_SHA256 then
                        Fail ("manifest entry file sha256 mismatch: " & Id);
                     elsif Outcome = "valid" then
                        if Expected_Decoded_SHA256'Length /= 64 then
                           Fail ("valid manifest entry has invalid decoded sha256 length: " & Id);
                        else
                           declare
                              Content : constant String := Project_Tools.Files.Read_Raw_File (Path);
                           begin
                              Valid_Entries := Valid_Entries + 1;
                              Check_Header
                                (Id,
                                 Content,
                                 Expected_Width,
                                 Expected_Height,
                                 Expected_Components,
                                 Expected_Color_Model,
                                 Expected_Mode,
                                 Expected_Entropy,
                                 Expected_Progressive,
                                 Expected_Hierarchical,
                                 Expected_Restart,
                                 Expected_Metadata_Segments);
                              Check_Decoded_Image
                                (Id,
                                 Path,
                                 Content,
                                 Expected_Width,
                                 Expected_Height,
                                 Expected_Format,
                                 Expected_Decoded_SHA256);
                           end;
                        end if;
                     elsif Outcome = "coeff-reject" then
                        Reject_Entries := Reject_Entries + 1;
                        Check_Coefficient_Reject
                          (Id,
                           Project_Tools.Files.Read_Raw_File (Path),
                           Expected_Error);
                     else
                        Fail ("manifest entry has invalid outcome: " & Id);
	                     end if;
	                  exception
	                     when Constraint_Error =>
	                        Fail ("manifest entry has invalid typed field: " & Text);
	                  end;
	               end if;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);

      if not Header_Found then
         Fail ("manifest header is missing required columns");
      end if;

      if Entries = 0 and then not Allow_Empty then
         Fail ("real-world corpus has no manifest entries");
      end if;

      if Entries > 0 and then Valid_Entries = 0 then
         Fail ("real-world corpus has no valid decode entries");
      end if;

      if Entries > 0 and then Reject_Entries = 0 then
         Fail ("real-world corpus has no malformed rejection entries");
      end if;
   exception
      when Ada.Text_IO.Name_Error | Ada.Text_IO.Use_Error =>
         Fail ("cannot read " & Manifest_Relative);
   end Check_Manifest;
begin
   if Root = "" then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_real_world: run below the jpeglib tree");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
      return;
   end if;

   if Ada.Command_Line.Argument_Count > 1
     or else (Ada.Command_Line.Argument_Count = 1 and then not Allow_Empty)
   then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: jpeglib_real_world [--allow-empty]");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
      return;
   end if;

   Check_Manifest;

   if Errors = 0 then
      Ada.Text_IO.Put_Line
        ("jpeglib_real_world: manifest passed with"
         & Natural'Image (Entries)
         & " entries,"
         & Natural'Image (Valid_Entries)
         & " valid decodes,"
         & Natural'Image (Reject_Entries)
         & " malformed rejections");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "jpeglib_real_world: " & Natural'Image (Errors) & " corpus issue(s)");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Fixture_Integrity_Failure)));
   end if;
end Jpeglib_Real_World;

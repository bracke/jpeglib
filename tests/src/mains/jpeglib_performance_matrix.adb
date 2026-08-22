with Ada.Calendar;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
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
with Project_Tools.Files;

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
   Root : constant String :=
     Project_Tools.Files.Find_Root_Upward
       (Ada.Directories.Current_Directory, "jpeglib.gpr");
   History_Relative : constant String := "tests/fixtures/performance/history.txt";
   Failures : Natural := 0;
   Baseline_Observed : Boolean := False;
   Progressive_Observed : Boolean := False;
   Arithmetic_Observed : Boolean := False;

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

   function Field
     (Line : String;
      Index : Positive) return String
   is
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

   procedure Mark_Observed (Label : String) is
   begin
      if Label = "accelerated-baseline-420" then
         Baseline_Observed := True;
      elsif Label = "accelerated-progressive-444" then
         Progressive_Observed := True;
      elsif Label = "accelerated-arithmetic-444" then
         Arithmetic_Observed := True;
      end if;
   end Mark_Observed;

   function Was_Observed (Label : String) return Boolean is
     (if Label = "accelerated-baseline-420" then Baseline_Observed
      elsif Label = "accelerated-progressive-444" then Progressive_Observed
      elsif Label = "accelerated-arithmetic-444" then Arithmetic_Observed
      else False);

   procedure Check_History
     (Label : String;
      Actual_Bytes : Natural;
      Actual_Iterations : Positive;
      Actual_Elapsed : Duration)
   is
      Path : constant String := Project_Tools.Files.Join (Root, History_Relative);
      File : Ada.Text_IO.File_Type;
      Line : String (1 .. 1024);
      Last : Natural;
      Found : Boolean := False;
   begin
      if Root = "" then
         Fail ("run below the jpeglib tree");
         return;
      elsif not Project_Tools.Files.File_Exists (Path) then
         Fail ("missing performance history fixture: " & History_Relative);
         return;
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Line, Last);
         declare
            Text : constant String :=
              Ada.Strings.Fixed.Trim (Line (1 .. Last), Ada.Strings.Both);
         begin
            if Text'Length > 0 and then Text (Text'First) /= '#' then
               if Separator_Count (Text) /= 3 then
                  Fail ("performance history row has wrong column count: " & Text);
               elsif Field (Text, 1) = Label then
                  declare
                     Expected_Bytes : constant Natural := Natural'Value (Field (Text, 2));
                     Expected_Iterations : constant Positive := Positive'Value (Field (Text, 3));
                     Max_Seconds : constant Duration := Duration'Value (Field (Text, 4));
                  begin
                     Found := True;
                     Mark_Observed (Label);
                     if Actual_Bytes /= Expected_Bytes then
                        Fail
                          (Label & " byte count changed: expected"
                           & Natural'Image (Expected_Bytes)
                           & " actual"
                           & Natural'Image (Actual_Bytes));
                     end if;
                     if Actual_Iterations /= Expected_Iterations then
                        Fail
                          (Label & " iteration count changed: expected"
                           & Positive'Image (Expected_Iterations)
                           & " actual"
                           & Positive'Image (Actual_Iterations));
                     end if;
                     if Actual_Elapsed > Max_Seconds then
                        Fail
                          (Label & " exceeded history threshold:"
                           & Duration'Image (Actual_Elapsed)
                           & " >"
                           & Duration'Image (Max_Seconds));
                     end if;
                  exception
                     when Constraint_Error =>
                        Fail ("performance history row has invalid numeric field: " & Text);
                  end;
               end if;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);

      if not Found then
         Fail ("missing performance history row for " & Label);
      end if;
   exception
      when Ada.Text_IO.Name_Error | Ada.Text_IO.Use_Error =>
         Fail ("cannot read performance history fixture: " & History_Relative);
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         Fail ("cannot parse performance history fixture");
   end Check_History;

   procedure Check_History_Coverage is
      Path : constant String := Project_Tools.Files.Join (Root, History_Relative);
      File : Ada.Text_IO.File_Type;
      Line : String (1 .. 1024);
      Last : Natural;
      Rows : Natural := 0;
   begin
      if Root = "" or else not Project_Tools.Files.File_Exists (Path) then
         return;
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Line, Last);
         declare
            Text : constant String :=
              Ada.Strings.Fixed.Trim (Line (1 .. Last), Ada.Strings.Both);
         begin
            if Text = "# case|bytes|iterations|max_total_seconds" then
               null;
            elsif Text'Length > 0 and then Text (Text'First) /= '#' then
               Rows := Rows + 1;
               if Separator_Count (Text) = 3 and then not Was_Observed (Field (Text, 1)) then
                  Fail ("performance history row was not exercised: " & Field (Text, 1));
               end if;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);

      if Rows = 0 then
         Fail ("performance history fixture has no rows");
      end if;
   exception
      when Ada.Text_IO.Name_Error | Ada.Text_IO.Use_Error =>
         Fail ("cannot read performance history fixture: " & History_Relative);
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         Fail ("cannot parse performance history fixture");
   end Check_History_Coverage;

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
      Check_History (Label, First_Length, Iterations, Elapsed);

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
      Ada.Text_IO.Put_Line
        ("jpeglib_performance_matrix_json: {""case"":"""
         & Label
         & """,""bytes"":"
         & Natural'Image (First_Length)
         & ",""iterations"":"
         & Positive'Image (Iterations)
         & ",""elapsed_seconds"":"
         & Duration'Image (Elapsed)
         & ",""max_total_seconds"":"
         & Duration'Image (Max_Total_Seconds)
         & ",""deterministic"":true}");
   end Run_Case;
begin
   Fill_Input;
   Ada.Text_IO.Put_Line
     ("jpeglib_performance_matrix: host="
      & Hostkit.Host.Kind'Image (Hostkit.Host.Current)
      & " machine="
      & Hostkit.Host.Machine_Name
      & " acceleration="
      & Jpeglib.Internal.Colors.Acceleration_Profile'Image (Jpeglib.Internal.Colors.Active_Acceleration)
      & " backend="
      & Jpeglib.Internal.Colors.Active_Acceleration_Backend
      & " detail="""
      & Jpeglib.Internal.Colors.Active_Acceleration_Detail
      & """");
   Ada.Text_IO.Put_Line
     ("jpeglib_performance_matrix_json: {""host"":"""
      & Hostkit.Host.Kind'Image (Hostkit.Host.Current)
      & """,""machine"":"""
      & Hostkit.Host.Machine_Name
      & """,""acceleration"":"""
      & Jpeglib.Internal.Colors.Acceleration_Profile'Image (Jpeglib.Internal.Colors.Active_Acceleration)
      & """,""backend"":"""
      & Jpeglib.Internal.Colors.Active_Acceleration_Backend
      & """,""detail"":"""
      & Jpeglib.Internal.Colors.Active_Acceleration_Detail
      & """}");

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
   Check_History_Coverage;

   if Failures = 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Test_Failure)));
   end if;
end Jpeglib_Performance_Matrix;

with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;

with Jpeglib_Tools;
with Project_Tools.Files;
with Project_Tools.Processes;

procedure Jpeglib_Complete_Plus is
   Root : constant String :=
     Project_Tools.Files.Find_Root_Upward
       (Ada.Directories.Current_Directory, "jpeglib.gpr");
   Allow_Open : constant Boolean :=
     Ada.Command_Line.Argument_Count = 1 and then Ada.Command_Line.Argument (1) = "--allow-open";
   Manifest_Relative : constant String := "tests/fixtures/complete_plus/gap_matrix.txt";
   Errors : Natural := 0;
   Entries : Natural := 0;
   Open_Rows : Natural := 0;

   procedure Fail (Message : String) is
   begin
      Errors := Errors + 1;
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_complete_plus: " & Message);
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

   procedure Run_Complete_Gate is
      Status : constant Integer :=
        Project_Tools.Processes.Run_Status
          ("complete-plus release baseline",
           Root,
           Project_Tools.Files.Join (Root, "tests/bin/jpeglib_complete"),
           Project_Tools.Processes.No_Arguments);
   begin
      if Status /= 0 then
         Fail ("library-complete baseline failed with status" & Integer'Image (Status));
      end if;
   end Run_Complete_Gate;

   procedure Run_Lossless_Transform_Gate is
      Status : constant Integer :=
        Project_Tools.Processes.Run_Status
          ("complete-plus lossless coefficient transforms",
           Root,
           Project_Tools.Files.Join (Root, "tests/bin/jpeglib_transform"),
           Project_Tools.Processes.Arguments
             ([Project_Tools.Processes.Argument ("--self-test")]));
   begin
      if Status /= 0 then
         Fail ("CP3 lossless transform gate failed with status" & Integer'Image (Status));
      end if;
   end Run_Lossless_Transform_Gate;

   procedure Run_Encoder_Optimization_Gate is
      Status : constant Integer :=
        Project_Tools.Processes.Run_Status
          ("complete-plus encoder optimization matrix",
           Root,
           Project_Tools.Files.Join (Root, "tests/bin/jpeglib_encoder_optimization"),
           Project_Tools.Processes.No_Arguments);
   begin
      if Status /= 0 then
         Fail ("encoder optimization gate failed with status" & Integer'Image (Status));
      end if;
   end Run_Encoder_Optimization_Gate;

   procedure Run_Precision_Buffer_Gate is
      Status : constant Integer :=
        Project_Tools.Processes.Run_Status
          ("complete-plus precision buffer matrix",
           Root,
           Project_Tools.Files.Join (Root, "tests/bin/jpeglib_precision_buffer"),
           Project_Tools.Processes.No_Arguments);
   begin
      if Status /= 0 then
         Fail ("precision buffer gate failed with status" & Integer'Image (Status));
      end if;
   end Run_Precision_Buffer_Gate;

   procedure Run_Performance_Gate is
      Status : constant Integer :=
        Project_Tools.Processes.Run_Status
          ("complete-plus performance architecture matrix",
           Root,
           Project_Tools.Files.Join (Root, "tests/bin/jpeglib_performance_matrix"),
           Project_Tools.Processes.No_Arguments);
   begin
      if Status /= 0 then
         Fail ("performance architecture gate failed with status" & Integer'Image (Status));
      end if;
   end Run_Performance_Gate;

   procedure Run_SIMD_Gate is
      Status : constant Integer :=
        Project_Tools.Processes.Run_Status
          ("complete-plus SIMD acceleration matrix",
           Root,
           Project_Tools.Files.Join (Root, "tests/bin/jpeglib_simd_matrix"),
           Project_Tools.Processes.No_Arguments);
   begin
      if Status /= 0 then
         Fail ("SIMD acceleration gate failed with status" & Integer'Image (Status));
      end if;
   end Run_SIMD_Gate;

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
            if Text = "# id|scope|target|closure_policy|status|evidence" then
               Header_Found := True;
            elsif Text'Length > 0 and then Text (Text'First) /= '#' then
               Entries := Entries + 1;
               if Separator_Count (Text) /= 5 then
                  Fail ("complete-plus row has wrong column count: " & Text);
               elsif Field (Text, 5) = "open" then
                  Open_Rows := Open_Rows + 1;
                  if not Allow_Open then
                     Fail ("complete-plus row remains open: " & Field (Text, 1));
                  end if;
               elsif Field (Text, 5) /= "closed" then
                  Fail ("complete-plus row has invalid status: " & Text);
               elsif Field (Text, 6) = "" then
                  Fail ("closed row lacks evidence: " & Field (Text, 1));
               end if;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);

      if not Header_Found then
         Fail ("complete-plus matrix header is missing required columns");
      end if;
      if Entries = 0 then
         Fail ("complete-plus matrix has no entries");
      end if;
   exception
      when Ada.Text_IO.Name_Error | Ada.Text_IO.Use_Error =>
         Fail ("cannot read " & Manifest_Relative);
   end Check_Manifest;
begin
   if Root = "" then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_complete_plus: run below the jpeglib tree");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
      return;
   end if;

   if Ada.Command_Line.Argument_Count > 1
     or else (Ada.Command_Line.Argument_Count = 1 and then not Allow_Open)
   then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: jpeglib_complete_plus [--allow-open]");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Invalid_Command)));
      return;
   end if;

   Run_Complete_Gate;
   Run_Lossless_Transform_Gate;
   Run_Encoder_Optimization_Gate;
   Run_Precision_Buffer_Gate;
   Run_Performance_Gate;
   Run_SIMD_Gate;
   Check_Manifest;

   if Errors = 0 then
      Ada.Text_IO.Put_Line
        ("jpeglib_complete_plus: matrix passed with"
         & Natural'Image (Entries) & " rows and"
         & Natural'Image (Open_Rows) & " open rows");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "jpeglib_complete_plus: " & Natural'Image (Errors) & " complete-plus issue(s)");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Policy_Failure)));
   end if;
end Jpeglib_Complete_Plus;

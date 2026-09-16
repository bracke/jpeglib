with Ada.Command_Line;
with Ada.Text_IO;

with Jpeglib.Decoding;
with Jpeglib.Errors;
with Jpeglib.Results;
with Jpeglib.Streams;

with Jpeglib_Tools;

procedure Jpeglib_Precision_Buffer is
   use type Jpeglib.Byte;
   use type Jpeglib.Byte_Count;
   use type Jpeglib.Errors.Error_Code;
   use type Jpeglib.Sample_Precision;

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
   DCT_Storage : aliased constant Jpeglib.Streams.Byte_Array :=
     [16#FF#, 16#D8#,
      16#FF#, 16#DB#,
      0, 67, 0,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      16#FF#, 16#C4#,
      0, 20, 0,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      2,
      16#FF#, 16#C4#,
      0, 20, 16#10#,
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0,
      16#FF#, 16#C1#,
      0, 11,
      12, 0, 8, 0, 8, 1,
      1, 16#11#, 0,
      16#FF#, 16#DA#,
      0, 8,
      1,
      1, 16#00#,
      0, 63, 0,
      16#44#,
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
      Accessible : Jpeglib.Byte_Count;
      Byte_Order : Jpeglib.Decoding.Raw_Sample_Byte_Order :=
        Jpeglib.Decoding.Most_Significant_Byte_First) return Jpeglib.Results.Result
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
          Raw_Byte_Order => Byte_Order,
          others => <>));
      return Jpeglib.Decoding.Decode_Raw_Components (Decoder, Raw);
   end Decode_One;

   function Decode_DCT
     (Output : not null Jpeglib.Streams.Byte_Array_Access;
      Byte_Order : Jpeglib.Decoding.Raw_Sample_Byte_Order;
      Policy : Jpeglib.Decoding.Raw_Precision_Policy :=
        Jpeglib.Decoding.Preserve_Source_Precision;
      Precision : Jpeglib.Sample_Precision := 8;
      Stride : Jpeglib.Row_Stride := 16;
      Accessible : Jpeglib.Byte_Count := 128) return Jpeglib.Results.Result
   is
      Source : aliased Jpeglib.Streams.Memory_Source;
      Decoder : Jpeglib.Decoding.Decoder;
      Raw : Jpeglib.Decoding.Raw_Component_View_Array (1 .. 1) :=
        [1 =>
           (Width => 8,
            Height => 8,
            Stride => Stride,
            Accessible_Bytes => Accessible,
            Storage => Output)];
   begin
      Jpeglib.Streams.Open (Source, DCT_Storage'Unchecked_Access);
      Jpeglib.Decoding.Initialize
        (Decoder,
         Source'Access,
         (Raw_Output_Precision => Precision,
          Raw_Precision => Policy,
          Raw_Byte_Order => Byte_Order,
          others => <>));
      return Jpeglib.Decoding.Decode_Raw_Components (Decoder, Raw);
   end Decode_DCT;

   Scaled : aliased Jpeglib.Streams.Byte_Array := [1 .. 1 => 0];
   Clamped : aliased Jpeglib.Streams.Byte_Array := [1 .. 1 => 0];
   Preserved : aliased Jpeglib.Streams.Byte_Array := [1 .. 2 => 0];
   Preserved_Wide_Stride : aliased Jpeglib.Streams.Byte_Array := [1 .. 2 => 0];
   Preserved_LE : aliased Jpeglib.Streams.Byte_Array := [1 .. 2 => 0];
   DCT_Preserved_LE : aliased Jpeglib.Streams.Byte_Array := [1 .. 128 => 0];
   Rejected : aliased Jpeglib.Streams.Byte_Array := [1 .. 1 => 0];
   DCT_Rejected : aliased Jpeglib.Streams.Byte_Array := [1 .. 64 => 77];
   Preserve_LE_Options : constant Jpeglib.Decoding.Options :=
     (Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision,
      Raw_Byte_Order => Jpeglib.Decoding.Least_Significant_Byte_First,
      others => <>);
   Preserved_View : constant Jpeglib.Decoding.Raw_Component_View :=
     (Width => 1,
      Height => 1,
      Stride => 2,
      Accessible_Bytes => 2,
      Storage => Preserved'Unchecked_Access);
   Wide_Stride_View : constant Jpeglib.Decoding.Raw_Component_View :=
     (Width => 1,
      Height => 1,
      Stride => Jpeglib.Row_Stride'Last,
      Accessible_Bytes => 2,
      Storage => Preserved'Unchecked_Access);
   Preserved_LE_View : constant Jpeglib.Decoding.Raw_Component_View :=
     (Width => 1,
      Height => 1,
      Stride => 2,
      Accessible_Bytes => 2,
      Storage => Preserved_LE'Unchecked_Access);
   DCT_Preserved_LE_View : constant Jpeglib.Decoding.Raw_Component_View :=
     (Width => 8,
      Height => 8,
      Stride => 16,
      Accessible_Bytes => 128,
      Storage => DCT_Preserved_LE'Unchecked_Access);
   Too_Short_View : constant Jpeglib.Decoding.Raw_Component_View :=
     (Width => 8,
      Height => 8,
      Stride => 15,
      Accessible_Bytes => 120,
      Storage => DCT_Preserved_LE'Unchecked_Access);
   Null_View : constant Jpeglib.Decoding.Raw_Component_View :=
     (Width => 1,
      Height => 1,
      Stride => 2,
      Accessible_Bytes => 2,
      Storage => null);
   Overflow_View : constant Jpeglib.Decoding.Raw_Component_View :=
     (Width => 1,
      Height => 2,
      Stride => Jpeglib.Row_Stride'Last,
      Accessible_Bytes => Jpeglib.Byte_Count'Last,
      Storage => DCT_Preserved_LE'Unchecked_Access);
   Outcome : Jpeglib.Results.Result;
   Sample_Outcome : Jpeglib.Decoding.Raw_Sample_Result;
begin
   if Jpeglib.Decoding.Effective_Raw_Output_Precision
        ((Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision,
          others => <>),
         12)
     /= 12
   then
      Fail ("effective raw precision did not preserve 12-bit source precision");
   end if;

   if Jpeglib.Decoding.Raw_Bytes_Per_Sample (12) /= 2 then
      Fail ("12-bit raw sample byte count mismatch");
   end if;

   if Jpeglib.Decoding.Raw_Minimum_Row_Bytes
        (8,
         (Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision,
          others => <>),
         12)
     /= 16
   then
      Fail ("12-bit raw row byte helper mismatch");
   end if;

   if Jpeglib.Decoding.Raw_Minimum_Row_Bytes
        (8,
         (Raw_Output_Precision => 8,
          Raw_Precision => Jpeglib.Decoding.Scale_To_Output_Precision,
          others => <>),
         12)
     /= 8
   then
      Fail ("scaled 8-bit raw row byte helper mismatch");
   end if;

   if Jpeglib.Decoding.Raw_Accessible_Bytes
        (8,
         8,
         16,
         (Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision,
          others => <>),
         12)
     /= 128
   then
      Fail ("12-bit raw accessible byte helper mismatch");
   end if;

   if Jpeglib.Decoding.Raw_Minimum_Row_Bytes
        (Natural'Last,
         (Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision,
          others => <>),
         12)
     /= Jpeglib.Byte_Count (Natural'Last) * 2
   then
      Fail ("12-bit raw row byte helper mishandled maximum width");
   end if;

   if Jpeglib.Decoding.Raw_Accessible_Bytes
        (1,
         2,
         Jpeglib.Row_Stride'Last,
         (Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision,
          others => <>),
         12)
     /= Jpeglib.Byte_Count'Last
   then
      Fail ("12-bit raw accessible byte helper did not saturate oversized stride");
   end if;

   if Jpeglib.Decoding.Raw_Accessible_Bytes
        (8,
         0,
         16,
         (Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision,
          others => <>),
         12)
     /= 0
   then
      Fail ("12-bit raw accessible byte helper mishandled zero-height view");
   end if;

   if not Jpeglib.Decoding.Raw_Component_View_Is_Valid
       (DCT_Preserved_LE_View,
        8,
        8,
        (Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision,
         others => <>),
        12)
   then
      Fail ("12-bit raw component view helper rejected valid view");
   end if;

   if Jpeglib.Decoding.Raw_Component_View_Is_Valid
       (Too_Short_View,
        8,
        8,
        (Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision,
         others => <>),
        12)
   then
      Fail ("12-bit raw component view helper accepted undersized view");
   end if;

   if Jpeglib.Decoding.Raw_Component_View_Is_Valid
       (Null_View,
        1,
        1,
        (Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision,
         others => <>),
        12)
   then
      Fail ("12-bit raw component view helper accepted null storage");
   end if;

   if Jpeglib.Decoding.Raw_Component_View_Is_Valid
       (Overflow_View,
        1,
        2,
        (Raw_Precision => Jpeglib.Decoding.Preserve_Source_Precision,
         others => <>),
        12)
   then
      Fail ("12-bit raw component view helper accepted overflowing view");
   end if;

   if not Jpeglib.Decoding.Raw_Sample_Position_Is_Valid
       (DCT_Preserved_LE_View,
        7,
        7,
        Preserve_LE_Options,
        12)
   then
      Fail ("12-bit raw sample position helper rejected valid packed sample");
   end if;

   if Jpeglib.Decoding.Raw_Sample_Position_Is_Valid
       (DCT_Preserved_LE_View,
        8,
        0,
        Preserve_LE_Options,
        12)
   then
      Fail ("12-bit raw sample position helper accepted out-of-range row");
   end if;

   if Jpeglib.Decoding.Raw_Sample_Position_Is_Valid
       (DCT_Preserved_LE_View,
        0,
        8,
        Preserve_LE_Options,
        12)
   then
      Fail ("12-bit raw sample position helper accepted out-of-range column");
   end if;

   if Jpeglib.Decoding.Raw_Sample_Position_Is_Valid
       (Too_Short_View,
        7,
        7,
        Preserve_LE_Options,
        12)
   then
      Fail ("12-bit raw sample position helper accepted truncated sample storage");
   end if;

   if Jpeglib.Decoding.Raw_Sample_Position_Is_Valid
       (Null_View,
        0,
        0,
        Preserve_LE_Options,
        12)
   then
      Fail ("12-bit raw sample position helper accepted null storage");
   end if;

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
   elsif Jpeglib.Decoding.Raw_Sample_At (Preserved_View, 0, 0, 12) /= 2048 then
      Fail ("preserve policy raw sample helper did not read big-endian 12-bit sample");
   end if;

   Sample_Outcome := Jpeglib.Decoding.Try_Raw_Sample_At (Preserved_View, 0, 0, 12);
   if not Jpeglib.Results.Succeeded (Sample_Outcome.Outcome) then
      Fail ("try raw sample helper rejected valid big-endian 12-bit sample",
            Sample_Outcome.Outcome.First_Error.Code);
   elsif Sample_Outcome.Sample /= 2048 then
      Fail ("try raw sample helper read wrong big-endian 12-bit sample");
   end if;

   Sample_Outcome := Jpeglib.Decoding.Try_Raw_Sample_At (Preserved_View, 1, 0, 12);
   if Jpeglib.Results.Succeeded (Sample_Outcome.Outcome) then
      Fail ("try raw sample helper accepted out-of-range row");
   elsif Sample_Outcome.Outcome.First_Error.Code /= Jpeglib.Errors.Output_Limit_Exceeded then
      Fail ("try raw sample helper used wrong out-of-range error",
            Sample_Outcome.Outcome.First_Error.Code);
   end if;

   Sample_Outcome := Jpeglib.Decoding.Try_Raw_Sample_At (Too_Short_View, 7, 7, 12);
   if Jpeglib.Results.Succeeded (Sample_Outcome.Outcome) then
      Fail ("try raw sample helper accepted truncated 12-bit storage");
   elsif Sample_Outcome.Outcome.First_Error.Code /= Jpeglib.Errors.Output_Limit_Exceeded then
      Fail ("try raw sample helper used wrong truncated-storage error",
            Sample_Outcome.Outcome.First_Error.Code);
   end if;

   Sample_Outcome := Jpeglib.Decoding.Try_Raw_Sample_At (Wide_Stride_View, 0, 0, 12);
   if not Jpeglib.Results.Succeeded (Sample_Outcome.Outcome) then
      Fail ("try raw sample helper rejected large-stride first sample",
            Sample_Outcome.Outcome.First_Error.Code);
   elsif Sample_Outcome.Sample /= 2048 then
      Fail ("try raw sample helper read wrong large-stride first sample");
   end if;

   Sample_Outcome := Jpeglib.Decoding.Try_Raw_Sample_At (Null_View, 0, 0, 12);
   if Jpeglib.Results.Succeeded (Sample_Outcome.Outcome) then
      Fail ("try raw sample helper accepted null storage");
   elsif Sample_Outcome.Outcome.First_Error.Code /= Jpeglib.Errors.Output_Limit_Exceeded then
      Fail ("try raw sample helper used wrong null-storage error",
            Sample_Outcome.Outcome.First_Error.Code);
   end if;

   Outcome :=
     Decode_One
       (Jpeglib.Decoding.Preserve_Source_Precision,
        8,
        Preserved_Wide_Stride'Unchecked_Access,
        Jpeglib.Row_Stride'Last,
        2);
   if not Jpeglib.Results.Succeeded (Outcome) then
      Fail ("wide-stride single-row preserve policy decode failed", Outcome.First_Error.Code);
   elsif Preserved_Wide_Stride (Preserved_Wide_Stride'First) /= 8
     or else Preserved_Wide_Stride (Preserved_Wide_Stride'First + 1) /= 0
   then
      Fail ("wide-stride single-row preserve policy wrote wrong sample bytes");
   end if;

   Outcome :=
     Decode_One
       (Jpeglib.Decoding.Preserve_Source_Precision,
        8,
        Preserved_LE'Unchecked_Access,
        2,
        2,
        Jpeglib.Decoding.Least_Significant_Byte_First);
   if not Jpeglib.Results.Succeeded (Outcome) then
      Fail ("little-endian preserve policy decode failed", Outcome.First_Error.Code);
   elsif Preserved_LE (Preserved_LE'First) /= 0
     or else Preserved_LE (Preserved_LE'First + 1) /= 8
   then
      Fail ("preserve policy did not emit little-endian 12-bit sample bytes");
   elsif Jpeglib.Decoding.Raw_Sample_At
       (Preserved_LE_View,
        0,
        0,
        Preserve_LE_Options,
        12)
     /= 2048
   then
      Fail ("preserve policy raw sample helper did not read little-endian 12-bit sample");
   end if;

   Sample_Outcome :=
     Jpeglib.Decoding.Try_Raw_Sample_At
       (Preserved_LE_View,
        0,
        0,
        Preserve_LE_Options,
        12);
   if not Jpeglib.Results.Succeeded (Sample_Outcome.Outcome) then
      Fail ("try raw sample helper rejected options-based little-endian 12-bit sample",
            Sample_Outcome.Outcome.First_Error.Code);
   elsif Sample_Outcome.Sample /= 2048 then
      Fail ("try raw sample helper read wrong options-based little-endian 12-bit sample");
   end if;

   Outcome :=
     Decode_DCT
       (DCT_Preserved_LE'Unchecked_Access,
        Jpeglib.Decoding.Least_Significant_Byte_First);
   if not Jpeglib.Results.Succeeded (Outcome) then
      Fail ("little-endian DCT preserve policy decode failed", Outcome.First_Error.Code);
   elsif DCT_Preserved_LE (DCT_Preserved_LE'First) /= 0
     or else DCT_Preserved_LE (DCT_Preserved_LE'First + 1) /= 8
   then
      Fail ("DCT raw preserve policy did not emit little-endian 12-bit sample bytes");
   elsif Jpeglib.Decoding.Raw_Sample_At
       (DCT_Preserved_LE_View,
        0,
        0,
        Preserve_LE_Options,
        12)
     /= 2048
   then
      Fail ("DCT raw sample helper did not read little-endian 12-bit sample");
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

   Outcome :=
     Decode_DCT
       (DCT_Rejected'Unchecked_Access,
        Jpeglib.Decoding.Most_Significant_Byte_First,
        Jpeglib.Decoding.Reject_Precision_Mismatch,
        8,
        8,
        64);
   if Jpeglib.Results.Succeeded (Outcome) then
      Fail ("DCT reject policy accepted precision mismatch");
   elsif Outcome.First_Error.Code /= Jpeglib.Errors.Unsupported_Feature then
      Fail ("DCT reject policy used wrong error", Outcome.First_Error.Code);
   elsif DCT_Rejected (DCT_Rejected'First) /= 77 then
      Fail ("DCT reject policy wrote partial output");
   end if;

   if Failures = 0 then
      Ada.Text_IO.Put_Line ("jpeglib_precision_buffer: precision policy matrix passed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Test_Failure)));
   end if;
end Jpeglib_Precision_Buffer;

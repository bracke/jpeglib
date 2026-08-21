with Jpeglib.Errors;
with Jpeglib.Internal.Bytes;

package body Jpeglib.Internal.Scans is
   function Invalid
     (Segment : Segments.Segment_Reader;
      Source : Source_Offset;
      Detail : Long_Long_Integer := 0) return Results.Result
   is
   begin
      return
        Results.Failure
          (Errors.Make
             (Errors.Scan_Invalid_Definition,
              (Source => Source,
               Marker => Segments.Descriptor (Segment).Marker,
               Detail => Detail,
               others => <>)));
   end Invalid;

   function Resolve_Component
     (Frame : Frames.Frame;
      Identifier : Component_Identifier) return Component_Index
   is
   begin
      for Index in Component_Index range 1 .. Component_Index (Frames.Components (Frame)) loop
         if Frames.Component (Frame, Index).Identifier = Identifier then
            return Index;
         end if;
      end loop;
      return Component_Index'First;
   end Resolve_Component;

   function Has_Component
     (Frame : Frames.Frame;
      Identifier : Component_Identifier) return Boolean
   is
   begin
      for Index in Component_Index range 1 .. Component_Index (Frames.Components (Frame)) loop
         if Frames.Component (Frame, Index).Identifier = Identifier then
            return True;
         end if;
      end loop;
      return False;
   end Has_Component;

   function Valid_Progressive_Parameters
     (Component_Total : Component_Count;
      Ss : Spectral_Selection_Index;
      Se : Spectral_Selection_Index;
      Ah : Successive_Approximation_Value;
      Al : Successive_Approximation_Value) return Boolean
   is
   begin
      if Ss > Se then
         return False;
      elsif Ah /= 0 and then Ah /= Al + 1 then
         return False;
      elsif Ss = 0 then
         return Se = 0;
      else
         return Component_Total = 1;
      end if;
   end Valid_Progressive_Parameters;

   function Parse_SOS
     (Frame : Frames.Frame;
      Segment : in out Segments.Segment_Reader;
      Progressive : Boolean := False;
      Lossless : Boolean := False) return Scan
   is
      Count_Byte : constant Bytes.Read_Byte_Result := Segments.Read_Byte (Segment);
      Component_Id : Bytes.Read_Byte_Result;
      Table_Selector : Bytes.Read_Byte_Result;
      Spectral_Start_Byte : Bytes.Read_Byte_Result;
      Spectral_End_Byte : Bytes.Read_Byte_Result;
      Approximation_Byte : Bytes.Read_Byte_Result;
      Result_Scan : Scan;
      Seen : array (Component_Index) of Boolean := [others => False];
      Frame_Index : Component_Index;
      TD : Natural;
      TA : Natural;
      AH : Natural;
      AL : Natural;
   begin
      if not Results.Succeeded (Frames.Status (Frame)) then
         Result_Scan.Outcome := Frames.Status (Frame);
         return Result_Scan;
      elsif not Results.Succeeded (Count_Byte.Outcome) then
         Result_Scan.Outcome := Count_Byte.Outcome;
         return Result_Scan;
      elsif Count_Byte.Value not in 1 .. Byte (Frames.Components (Frame)) then
         Result_Scan.Outcome := Invalid (Segment, Count_Byte.Source, Long_Long_Integer (Count_Byte.Value));
         return Result_Scan;
      end if;

      Result_Scan.Component_Total := Component_Count (Natural (Count_Byte.Value));

      for Index in Component_Index range 1 .. Component_Index (Result_Scan.Component_Total) loop
         Component_Id := Segments.Read_Byte (Segment);
         Table_Selector := Segments.Read_Byte (Segment);

         if not Results.Succeeded (Component_Id.Outcome) then
            Result_Scan.Outcome := Component_Id.Outcome;
            return Result_Scan;
         elsif not Results.Succeeded (Table_Selector.Outcome) then
            Result_Scan.Outcome := Table_Selector.Outcome;
            return Result_Scan;
         elsif not Has_Component (Frame, Component_Identifier (Component_Id.Value)) then
            Result_Scan.Outcome := Invalid (Segment, Component_Id.Source, Long_Long_Integer (Component_Id.Value));
            return Result_Scan;
         end if;

         Frame_Index := Resolve_Component (Frame, Component_Identifier (Component_Id.Value));
         if Seen (Frame_Index) then
            Result_Scan.Outcome := Invalid (Segment, Component_Id.Source, Long_Long_Integer (Component_Id.Value));
            return Result_Scan;
         end if;

         TD := Natural (Table_Selector.Value) / 16;
         TA := Natural (Table_Selector.Value) mod 16;
         if TD > Natural (Huffman_Table_Index'Last) or else TA > Natural (Huffman_Table_Index'Last) then
            Result_Scan.Outcome := Invalid (Segment, Table_Selector.Source, Long_Long_Integer (Table_Selector.Value));
            return Result_Scan;
         end if;

         Seen (Frame_Index) := True;
         Result_Scan.Component_Items (Index) :=
           (Frame_Component => Frame_Index,
            DC_Table => Huffman_Table_Index (TD),
            AC_Table => Huffman_Table_Index (TA));
      end loop;

      Spectral_Start_Byte := Segments.Read_Byte (Segment);
      Spectral_End_Byte := Segments.Read_Byte (Segment);
      Approximation_Byte := Segments.Read_Byte (Segment);

      if not Results.Succeeded (Spectral_Start_Byte.Outcome) then
         Result_Scan.Outcome := Spectral_Start_Byte.Outcome;
         return Result_Scan;
      elsif not Results.Succeeded (Spectral_End_Byte.Outcome) then
         Result_Scan.Outcome := Spectral_End_Byte.Outcome;
         return Result_Scan;
      elsif not Results.Succeeded (Approximation_Byte.Outcome) then
         Result_Scan.Outcome := Approximation_Byte.Outcome;
         return Result_Scan;
      elsif (not Lossless and then (Spectral_Start_Byte.Value > 63 or else Spectral_End_Byte.Value > 63))
        or else (Lossless and then (Spectral_Start_Byte.Value not in 1 .. 7 or else Spectral_End_Byte.Value /= 0))
      then
         Result_Scan.Outcome := Invalid (Segment, Spectral_Start_Byte.Source);
         return Result_Scan;
      end if;

      AH := Natural (Approximation_Byte.Value) / 16;
      AL := Natural (Approximation_Byte.Value) mod 16;
      if AH > 13 or else AL > 13 then
         Result_Scan.Outcome :=
           Invalid
             (Segment,
              Approximation_Byte.Source,
              Long_Long_Integer (Approximation_Byte.Value));
         return Result_Scan;
      end if;

      Result_Scan.Ss := Spectral_Selection_Index (Natural (Spectral_Start_Byte.Value));
      Result_Scan.Se := Spectral_Selection_Index (Natural (Spectral_End_Byte.Value));
      Result_Scan.Ah := Successive_Approximation_Value (AH);
      Result_Scan.Al := Successive_Approximation_Value (AL);

      if Lossless then
         if Progressive then
            Result_Scan.Outcome := Invalid (Segment, Spectral_Start_Byte.Source);
            return Result_Scan;
         end if;
      elsif not Progressive
        and then (Result_Scan.Ss /= 0
                  or else Result_Scan.Se /= 63
                  or else Result_Scan.Ah /= 0
                  or else Result_Scan.Al /= 0)
      then
         Result_Scan.Outcome := Invalid (Segment, Spectral_Start_Byte.Source);
         return Result_Scan;
      elsif Progressive
        and then not
          Valid_Progressive_Parameters
            (Result_Scan.Component_Total,
             Result_Scan.Ss,
             Result_Scan.Se,
             Result_Scan.Ah,
             Result_Scan.Al)
      then
         Result_Scan.Outcome := Invalid (Segment, Spectral_Start_Byte.Source);
         return Result_Scan;
      elsif Segments.Remaining (Segment) /= 0 then
         Result_Scan.Outcome :=
           Invalid
             (Segment,
              Segments.Descriptor (Segment).Payload_Source,
              Long_Long_Integer (Segments.Remaining (Segment)));
         return Result_Scan;
      end if;

      return Result_Scan;
   exception
      when Constraint_Error =>
         Result_Scan.Outcome := Invalid (Segment, Segments.Descriptor (Segment).Payload_Source);
         return Result_Scan;
   end Parse_SOS;

   function Status (Item : Scan) return Results.Result is
   begin
      return Item.Outcome;
   end Status;

   function Components (Item : Scan) return Component_Count is
   begin
      return Item.Component_Total;
   end Components;

   function Component (Item : Scan; Index : Component_Index) return Scan_Component is
   begin
      return Item.Component_Items (Index);
   end Component;

   function Spectral_Start (Item : Scan) return Spectral_Selection_Index is
   begin
      return Item.Ss;
   end Spectral_Start;

   function Spectral_End (Item : Scan) return Spectral_Selection_Index is
   begin
      return Item.Se;
   end Spectral_End;

   function Successive_High (Item : Scan) return Successive_Approximation_Value is
   begin
      return Item.Ah;
   end Successive_High;

   function Successive_Low (Item : Scan) return Successive_Approximation_Value is
   begin
      return Item.Al;
   end Successive_Low;
end Jpeglib.Internal.Scans;

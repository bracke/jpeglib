with Jpeglib.Errors;
with Jpeglib.Internal.Bytes;
with Jpeglib.Internal.Writers;

package body Jpeglib.Internal.Bit_Streams is
   function Sign_Extend (Category : Entropy_Category; Bits : Entropy_Bits) return Sign_Extend_Result is
      Width : constant Natural := Natural (Category);
      Limit : Entropy_Bits;
      Sign_Bit : Entropy_Bits;
      Raw : Natural;
   begin
      if Width = 0 then
         if Bits = 0 then
            return (Outcome => Results.Success, Value => 0);
         else
            return
              (Outcome =>
                 Results.Failure
                   (Errors.Make (Errors.Entropy_Invalid_Category, (Detail => Long_Long_Integer (Bits), others => <>))),
               Value => 0);
         end if;
      end if;

      Limit := Entropy_Bits (2 ** Width);
      if Bits >= Limit then
         return
           (Outcome =>
              Results.Failure
                (Errors.Make (Errors.Entropy_Invalid_Category, (Detail => Long_Long_Integer (Bits), others => <>))),
            Value => 0);
      end if;

      Sign_Bit := Entropy_Bits (2 ** (Width - 1));
      Raw := Natural (Bits);
      if Bits >= Sign_Bit then
         return (Outcome => Results.Success, Value => Entropy_Value (Raw));
      else
         return
           (Outcome => Results.Success,
            Value => Entropy_Value (Integer (Raw) + 1 - Integer (Limit)));
      end if;
   end Sign_Extend;

   function Read_Byte (Reader : in out Entropy_Reader) return Entropy_Read_Result is
      First : Bytes.Read_Byte_Result;
      Next : Bytes.Read_Byte_Result;
      Marker_Source : Source_Offset := 0;
   begin
      if Reader.Pending then
         if Markers.Is_Restart (Reader.Pending_Marker) then
            Reader.Pending := False;
            return
              (Outcome => Results.Success,
               Kind => Restart_Marker,
               Source => Reader.Pending_Source,
               Value => 0,
               Marker => Reader.Pending_Marker);
         end if;

         return
           (Outcome => Results.Success,
            Kind => Scan_Ending_Marker,
            Source => Reader.Pending_Source,
            Value => 0,
            Marker => Reader.Pending_Marker);
      end if;

      First := Bytes.Read_Byte (Reader.Input.all);
      if not Results.Succeeded (First.Outcome) then
         if First.End_Of_Input then
            return
              (Outcome => Results.Success,
               Kind => Physical_End_Of_Input,
               Source => First.Source,
               Value => 0,
               Marker => 0);
         end if;

         return
           (Outcome => First.Outcome,
            Kind => Entropy_Data,
            Source => First.Source,
            Value => 0,
            Marker => 0);
      elsif First.Value /= 16#FF# then
         return
           (Outcome => Results.Success,
            Kind => Entropy_Data,
            Source => First.Source,
            Value => First.Value,
            Marker => 0);
      end if;

      Marker_Source := First.Source;
      loop
         Next := Bytes.Read_Byte (Reader.Input.all);
         if not Results.Succeeded (Next.Outcome) then
            if Next.End_Of_Input then
               return
                 (Outcome => Results.Success,
                  Kind => Physical_End_Of_Input,
                  Source => Marker_Source,
                  Value => 0,
                  Marker => 0);
            end if;

            return
              (Outcome => Next.Outcome,
               Kind => Entropy_Data,
               Source => Marker_Source,
               Value => 0,
               Marker => 0);
         elsif Next.Value = 16#FF# then
            null;
         elsif Next.Value = 0 then
            return
              (Outcome => Results.Success,
               Kind => Entropy_Data,
               Source => Marker_Source,
               Value => 16#FF#,
               Marker => 0);
         elsif Markers.Is_Restart (Marker_Code (Next.Value)) then
            return
              (Outcome => Results.Success,
               Kind => Restart_Marker,
               Source => Marker_Source,
               Value => 0,
               Marker => Marker_Code (Next.Value));
         else
            Reader.Pending := True;
            Reader.Pending_Source := Marker_Source;
            Reader.Pending_Marker := Marker_Code (Next.Value);
            return
              (Outcome => Results.Success,
               Kind => Scan_Ending_Marker,
               Source => Marker_Source,
               Value => 0,
               Marker => Marker_Code (Next.Value));
         end if;
      end loop;
   end Read_Byte;

   function Has_Pending_Marker (Reader : Entropy_Reader) return Boolean is
   begin
      return Reader.Pending;
   end Has_Pending_Marker;

   procedure Put_Back_Marker
     (Reader : in out Entropy_Reader;
      Source : Source_Offset;
      Marker : Marker_Code) is
   begin
      Reader.Pending := True;
      Reader.Pending_Source := Source;
      Reader.Pending_Marker := Marker;
   end Put_Back_Marker;

   function Take_Pending_Marker (Reader : in out Entropy_Reader) return Markers.Marker_Result is
   begin
      Reader.Pending := False;
      return
        (Outcome => Results.Success,
         Source => Reader.Pending_Source,
         Marker => Reader.Pending_Marker);
   end Take_Pending_Marker;

   function Unexpected_Marker (Item : Entropy_Read_Result) return Results.Result is
   begin
      return
        Results.Failure
          (Errors.Make
             (Errors.Entropy_Unexpected_Marker,
              (Source => Item.Source, Marker => Item.Marker, others => <>)));
   end Unexpected_Marker;

   function Read_Bit (Reader : in out Bit_Reader) return Bit_Result is
      Entropy_Result : Entropy_Read_Result;
      Shift : Natural;
      Bit : Bit_Value;
   begin
      if Reader.Bits_Remaining = 0 then
         Entropy_Result := Read_Byte (Reader.Entropy.all);
         if not Results.Succeeded (Entropy_Result.Outcome) then
            return (Outcome => Entropy_Result.Outcome, Source => Entropy_Result.Source, Value => 0);
         elsif Entropy_Result.Kind /= Entropy_Data then
            return (Outcome => Unexpected_Marker (Entropy_Result), Source => Entropy_Result.Source, Value => 0);
         end if;

         Reader.Buffered_Byte := Entropy_Result.Value;
         Reader.Byte_Source := Entropy_Result.Source;
         Reader.Bits_Remaining := 8;
      end if;

      Shift := Reader.Bits_Remaining - 1;
      if (Natural (Reader.Buffered_Byte) / (2 ** Shift)) mod 2 = 0 then
         Bit := 0;
      else
         Bit := 1;
      end if;
      Reader.Bits_Remaining := Reader.Bits_Remaining - 1;

      return (Outcome => Results.Success, Source => Reader.Byte_Source, Value => Bit);
   end Read_Bit;

   procedure Byte_Align (Reader : in out Bit_Reader) is
   begin
      Reader.Bits_Remaining := 0;
   end Byte_Align;

   function Emit_Buffered_Byte (Writer : in out Bit_Writer) return Results.Result is
      Outcome : constant Results.Result :=
        Writers.Write_Entropy_Byte (Writer.Output.all, Writer.Buffered_Byte);
   begin
      if Results.Succeeded (Outcome) then
         Writer.Buffered_Byte := 0;
         Writer.Bits_Filled := 0;
      end if;

      return Outcome;
   end Emit_Buffered_Byte;

   function Write_Bits
     (Writer : in out Bit_Writer;
      Width : Entropy_Category;
      Bits : Entropy_Bits) return Results.Result
   is
      Count : constant Natural := Natural (Width);
      Limit : Entropy_Bits;
      Shift : Natural;
      Bit : Natural;
      Outcome : Results.Result;
   begin
      if Count = 0 then
         if Bits = 0 then
            return Results.Success;
         end if;

         return
           Results.Failure
             (Errors.Make (Errors.Entropy_Invalid_Category, (Detail => Long_Long_Integer (Bits), others => <>)));
      end if;

      Limit := Entropy_Bits (2 ** Count);
      if Bits >= Limit then
         return
           Results.Failure
             (Errors.Make (Errors.Entropy_Invalid_Category, (Detail => Long_Long_Integer (Bits), others => <>)));
      end if;

      for Offset in reverse 0 .. Count - 1 loop
         Shift := Offset;
         Bit := Natural (Bits / Entropy_Bits (2 ** Shift)) mod 2;
         Writer.Buffered_Byte :=
           Byte (Natural (Writer.Buffered_Byte) * 2 + Bit);
         Writer.Bits_Filled := Writer.Bits_Filled + 1;

         if Writer.Bits_Filled = 8 then
            Outcome := Emit_Buffered_Byte (Writer);
            if not Results.Succeeded (Outcome) then
               return Outcome;
            end if;
         end if;
      end loop;

      return Results.Success;
   end Write_Bits;

   function Flush_Byte
     (Writer : in out Bit_Writer;
      Pad : Bit_Value := 1) return Results.Result
   is
   begin
      if Writer.Bits_Filled = 0 then
         return Results.Success;
      end if;

      while Writer.Bits_Filled < 8 loop
         Writer.Buffered_Byte :=
           Byte (Natural (Writer.Buffered_Byte) * 2 + Natural (Pad));
         Writer.Bits_Filled := Writer.Bits_Filled + 1;
      end loop;

      return Emit_Buffered_Byte (Writer);
   end Flush_Byte;

   function Write_Restart_Marker
     (Writer : in out Bit_Writer;
      Marker : Marker_Code) return Results.Result
   is
      Outcome : Results.Result;
   begin
      Outcome := Flush_Byte (Writer);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      return Writers.Write_Marker (Writer.Output.all, Marker);
   end Write_Restart_Marker;
end Jpeglib.Internal.Bit_Streams;

with Jpeglib.Errors;
with Jpeglib.Internal.Bytes;

package body Jpeglib.Internal.Markers is
   function Restart_Number (Marker : Marker_Code) return Natural is
   begin
      return Natural (Marker - RST0);
   end Restart_Number;

   function Is_Frame (Marker : Marker_Code) return Boolean is
   begin
      case Marker is
         when SOF0 | SOF1 | SOF2 | SOF3 | SOF5 | SOF6 | SOF7 |
              SOF9 | SOF10 | SOF11 | SOF13 | SOF14 | SOF15 =>
            return True;
         when others =>
            return False;
      end case;
   end Is_Frame;

   function Is_Standalone (Marker : Marker_Code) return Boolean is
   begin
      return Marker = SOI or else Marker = EOI or else Marker = TEM or else Is_Restart (Marker);
   end Is_Standalone;

   function Has_Length (Marker : Marker_Code) return Boolean is
   begin
      return Marker /= 0 and then Marker /= 16#FF# and then not Is_Standalone (Marker);
   end Has_Length;

   function Is_Reserved (Marker : Marker_Code) return Boolean is
   begin
      return Marker = 0
        or else Marker = 16#FF#
        or else Marker = JPG
        or else Is_JPG_Extension (Marker);
   end Is_Reserved;

   function Read_Next (Input : in out Streams.Source'Class) return Marker_Result is
      Prefix : Bytes.Read_Byte_Result;
      Code : Bytes.Read_Byte_Result;
      Marker_Source : Source_Offset := 0;
   begin
      loop
         Prefix := Bytes.Read_Byte (Input);
         if not Results.Succeeded (Prefix.Outcome) then
            return (Outcome => Prefix.Outcome, Source => Prefix.Source, Marker => 0);
         elsif Prefix.Value = 16#FF# then
            Marker_Source := Prefix.Source;
            exit;
         end if;
      end loop;

      loop
         Code := Bytes.Read_Byte (Input);
         if not Results.Succeeded (Code.Outcome) then
            return (Outcome => Code.Outcome, Source => Marker_Source, Marker => 0);
         elsif Code.Value = 16#FF# then
            null;
         elsif Code.Value = 0 then
            return
              (Outcome =>
                 Results.Failure
                   (Errors.Make (Errors.Marker_Expected, (Source => Marker_Source, Detail => 0, others => <>))),
               Source => Marker_Source,
               Marker => 0);
         else
            return (Outcome => Results.Success, Source => Marker_Source, Marker => Marker_Code (Code.Value));
         end if;
      end loop;
   end Read_Next;
end Jpeglib.Internal.Markers;

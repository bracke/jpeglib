with Ada.Directories;
with Ada.Streams;

with CryptoLib.Hashes;
with Project_Tools.Files;

package body Jpeglib_Tools.Release_Digests is
   use type Ada.Streams.Stream_Element_Offset;

   function Trimmed_Natural_Image (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      if Image'Length > 0 and then Image (Image'First) = ' ' then
         return Image (Image'First + 1 .. Image'Last);
      end if;

      return Image;
   end Trimmed_Natural_Image;

   function SHA256_Hex (Content : String) return String is
      Hex    : constant String := "0123456789abcdef";
      Bytes  : Ada.Streams.Stream_Element_Array
        (1 .. Ada.Streams.Stream_Element_Offset (Content'Length));
      Cursor : Ada.Streams.Stream_Element_Offset := Bytes'First;
      Digest : CryptoLib.Hashes.SHA256_Digest;
      Result : String (1 .. 64);
      Value  : Natural;
   begin
      for Item of Content loop
         Bytes (Cursor) := Ada.Streams.Stream_Element (Character'Pos (Item));
         Cursor := Cursor + 1;
      end loop;

      Digest := CryptoLib.Hashes.SHA256 (Bytes);
      for Index in Digest'Range loop
         Value := Natural (Digest (Index));
         Result (Index * 2 - 1) := Hex (Value / 16 + 1);
         Result (Index * 2) := Hex (Value mod 16 + 1);
      end loop;

      return Result;
   end SHA256_Hex;

   function File_SHA256_Hex (Path : String) return String is
     (SHA256_Hex (Project_Tools.Files.Read_Raw_File (Path)));

   function Manifest_Line (Root : String; Relative_Path : String) return String is
      Path : constant String := Project_Tools.Files.Join (Root, Relative_Path);
   begin
      return Relative_Path
        & " bytes=" & Trimmed_Natural_Image (Natural (Ada.Directories.Size (Path)))
        & " sha256=" & File_SHA256_Hex (Path);
   end Manifest_Line;
end Jpeglib_Tools.Release_Digests;

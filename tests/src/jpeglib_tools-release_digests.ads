package Jpeglib_Tools.Release_Digests is
   function SHA256_Hex (Content : String) return String;
   function File_SHA256_Hex (Path : String) return String;
   function Manifest_Line (Root : String; Relative_Path : String) return String;
end Jpeglib_Tools.Release_Digests;

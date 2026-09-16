package Jpeglib_Tools.Release_Digests is
   --  Sha256 hex.
   --  @param Content See package contract for this parameter.
   --  @return Operation result.
   function SHA256_Hex (Content : String) return String;
   --  File sha256 hex.
   --  @param Path See package contract for this parameter.
   --  @return Operation result.
   function File_SHA256_Hex (Path : String) return String;
   --  Manifest line.
   --  @param Root See package contract for this parameter.
   --  @param Relative_Path See package contract for this parameter.
   --  @return Operation result.
   function Manifest_Line (Root : String; Relative_Path : String) return String;
end Jpeglib_Tools.Release_Digests;

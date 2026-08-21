package body Jpeglib.Version is
   function Current return String is
   begin
      return Semantic_Version;
   end Current;
end Jpeglib.Version;

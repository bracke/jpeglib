package Jpeglib.Version is
   pragma Pure;

   Major : constant Natural := 0;
   Minor : constant Natural := 1;
   Patch : constant Natural := 0;
   Pre_Release : constant String := "dev";
   Semantic_Version : constant String := "0.1.0-dev";

   function Current return String;
end Jpeglib.Version;

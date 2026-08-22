with AUnit.Test_Cases;
with Jpeglib_Testing.Test_Arithmetic;
with Jpeglib_Testing.Test_Capabilities_Release;
with Jpeglib_Testing.Test_Coefficient_Scans;
with Jpeglib_Testing.Test_Coefficient_Encoding;
with Jpeglib_Testing.Test_Core;
with Jpeglib_Testing.Test_Entropy_Tables;
with Jpeglib_Testing.Test_Foundation;
with Jpeglib_Testing.Test_Headers_Metadata;
with Jpeglib_Testing.Test_Image_Pipeline;
with Jpeglib_Testing.Test_Writers_Streams;

package body Jpeglib_Testing.Suite is
   function All_Tests return AUnit.Test_Suites.Access_Test_Suite is
      Suite : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
      Arithmetic : constant AUnit.Test_Cases.Test_Case_Access := new Jpeglib_Testing.Test_Arithmetic.Test;
      Capabilities_Release : constant AUnit.Test_Cases.Test_Case_Access :=
        new Jpeglib_Testing.Test_Capabilities_Release.Test;
      Coefficient_Scans : constant AUnit.Test_Cases.Test_Case_Access :=
        new Jpeglib_Testing.Test_Coefficient_Scans.Test;
      Coefficient_Encoding : constant AUnit.Test_Cases.Test_Case_Access :=
        new Jpeglib_Testing.Test_Coefficient_Encoding.Test;
      Core : constant AUnit.Test_Cases.Test_Case_Access := new Jpeglib_Testing.Test_Core.Test;
      Entropy_Tables : constant AUnit.Test_Cases.Test_Case_Access :=
        new Jpeglib_Testing.Test_Entropy_Tables.Test;
      Foundation : constant AUnit.Test_Cases.Test_Case_Access := new Jpeglib_Testing.Test_Foundation.Test;
      Headers_Metadata : constant AUnit.Test_Cases.Test_Case_Access :=
        new Jpeglib_Testing.Test_Headers_Metadata.Test;
      Image_Pipeline : constant AUnit.Test_Cases.Test_Case_Access :=
        new Jpeglib_Testing.Test_Image_Pipeline.Test;
      Writers_Streams : constant AUnit.Test_Cases.Test_Case_Access :=
        new Jpeglib_Testing.Test_Writers_Streams.Test;
   begin
      Suite.Add_Test (Arithmetic);
      Suite.Add_Test (Capabilities_Release);
      Suite.Add_Test (Coefficient_Scans);
      Suite.Add_Test (Coefficient_Encoding);
      Suite.Add_Test (Core);
      Suite.Add_Test (Entropy_Tables);
      Suite.Add_Test (Headers_Metadata);
      Suite.Add_Test (Image_Pipeline);
      Suite.Add_Test (Writers_Streams);
      Suite.Add_Test (Foundation);
      return Suite;
   end All_Tests;
end Jpeglib_Testing.Suite;

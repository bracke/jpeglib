with AUnit.Test_Cases;
with Jpeglib_Testing.Test_Foundation;

package body Jpeglib_Testing.Suite is
   function All_Tests return AUnit.Test_Suites.Access_Test_Suite is
      Suite : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
      Foundation : constant AUnit.Test_Cases.Test_Case_Access := new Jpeglib_Testing.Test_Foundation.Test;
   begin
      Suite.Add_Test (Foundation);
      return Suite;
   end All_Tests;
end Jpeglib_Testing.Suite;

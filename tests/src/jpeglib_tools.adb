package body Jpeglib_Tools is
   function Code (Item : Exit_Code) return Integer is
   begin
      case Item is
         when Success =>
            return 0;
         when Operational_Failure =>
            return 1;
         when Invalid_Command =>
            return 2;
         when Build_Failure =>
            return 3;
         when Test_Failure =>
            return 4;
         when Conformance_Failure =>
            return 5;
         when Proof_Failure =>
            return 6;
         when Policy_Failure =>
            return 7;
         when Fixture_Integrity_Failure =>
            return 8;
         when Documentation_Failure =>
            return 9;
         when Release_Reproducibility_Failure =>
            return 10;
      end case;
   end Code;
end Jpeglib_Tools;

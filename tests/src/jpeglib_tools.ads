package Jpeglib_Tools is
   type Exit_Code is
     (Success,
      Operational_Failure,
      Invalid_Command,
      Build_Failure,
      Test_Failure,
      Conformance_Failure,
      Proof_Failure,
      Policy_Failure,
      Fixture_Integrity_Failure,
      Documentation_Failure,
      Release_Reproducibility_Failure);

   function Code (Item : Exit_Code) return Integer;
end Jpeglib_Tools;

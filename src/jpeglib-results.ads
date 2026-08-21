with Jpeglib.Errors;

package Jpeglib.Results is
   pragma Preelaborate;

   type Status is (Ok, Failed);

   type Result is record
      State : Status := Ok;
      First_Error : Errors.Error := Errors.Make (Errors.No_Error);
   end record;

   function Success return Result is ((State => Ok, First_Error => Errors.Make (Errors.No_Error)));
   function Failure (Code : Errors.Error_Code) return Result is
     ((State => Failed, First_Error => Errors.Make (Code)));
   function Failure (Item : Errors.Error) return Result is ((State => Failed, First_Error => Item));
   function Succeeded (Item : Result) return Boolean is (Item.State = Ok);
end Jpeglib.Results;

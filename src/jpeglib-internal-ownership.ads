with Jpeglib.Results;

package Jpeglib.Internal.Ownership is
   pragma Preelaborate;

   type Byte_Budget is private;
   type Byte_Lease is private;

   function Used (Budget : Byte_Budget) return Byte_Count;
   function Is_Active (Lease : Byte_Lease) return Boolean;
   function Size (Lease : Byte_Lease) return Byte_Count;

   function Reserve
     (Budget : in out Byte_Budget;
      Limit : Byte_Count;
      Amount : Byte_Count;
      Lease : out Byte_Lease) return Results.Result;

   function Release
     (Budget : in out Byte_Budget;
      Lease : in out Byte_Lease) return Results.Result;

private
   type Byte_Budget is record
      Used_Bytes : Byte_Count := 0;
   end record;

   type Byte_Lease is record
      Active : Boolean := False;
      Charged_Bytes : Byte_Count := 0;
   end record;
end Jpeglib.Internal.Ownership;

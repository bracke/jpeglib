with Jpeglib.Errors;
with Jpeglib.Internal.Checked_Arithmetic;

package body Jpeglib.Internal.Ownership is
   function Used (Budget : Byte_Budget) return Byte_Count is
   begin
      return Budget.Used_Bytes;
   end Used;

   function Is_Active (Lease : Byte_Lease) return Boolean is
   begin
      return Lease.Active;
   end Is_Active;

   function Size (Lease : Byte_Lease) return Byte_Count is
   begin
      if Lease.Active then
         return Lease.Charged_Bytes;
      end if;
      return 0;
   end Size;

   function Reserve
     (Budget : in out Byte_Budget;
      Limit : Byte_Count;
      Amount : Byte_Count;
      Lease : out Byte_Lease) return Results.Result
   is
      Next : constant Checked_Arithmetic.Count_Result :=
        Checked_Arithmetic.Add (Budget.Used_Bytes, Amount);
   begin
      Lease := (Active => False, Charged_Bytes => 0);

      if not Results.Succeeded (Next.Outcome) then
         return Next.Outcome;
      elsif Next.Count > Limit then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      Budget.Used_Bytes := Next.Count;
      Lease := (Active => True, Charged_Bytes => Amount);
      return Results.Success;
   end Reserve;

   function Release
     (Budget : in out Byte_Budget;
      Lease : in out Byte_Lease) return Results.Result
   is
   begin
      if not Lease.Active then
         return Results.Success;
      elsif Budget.Used_Bytes < Lease.Charged_Bytes then
         return Results.Failure (Errors.Internal_Invariant_Failed);
      end if;

      Budget.Used_Bytes := Budget.Used_Bytes - Lease.Charged_Bytes;
      Lease := (Active => False, Charged_Bytes => 0);
      return Results.Success;
   end Release;
end Jpeglib.Internal.Ownership;

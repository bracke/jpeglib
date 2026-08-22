with Jpeglib.Errors;

package body Jpeglib.Internal.Ownership is
   pragma SPARK_Mode (On);

   procedure Reserve_State
     (Budget : in out Byte_Budget;
      Limit : Byte_Count;
      Amount : Byte_Count;
      Lease : out Byte_Lease;
      Outcome : out Results.Result)
   is
   begin
      Lease := (Active => False, Charged_Bytes => 0);

      if Budget.Used_Bytes > Byte_Count'Last - Amount then
         Outcome := Results.Failure (Errors.Integer_Overflow);
         return;
      elsif Budget.Used_Bytes + Amount > Limit then
         Outcome := Results.Failure (Errors.Output_Limit_Exceeded);
         return;
      end if;

      Budget.Used_Bytes := Budget.Used_Bytes + Amount;
      Lease := (Active => True, Charged_Bytes => Amount);
      Outcome := Results.Success;
   end Reserve_State;

   function Reserve
     (Budget : in out Byte_Budget;
      Limit : Byte_Count;
      Amount : Byte_Count;
      Lease : out Byte_Lease) return Results.Result
   is
      pragma SPARK_Mode (Off);
      Outcome : Results.Result;
   begin
      Reserve_State (Budget, Limit, Amount, Lease, Outcome);
      return Outcome;
   end Reserve;

   procedure Release_State
     (Budget : in out Byte_Budget;
      Lease : in out Byte_Lease;
      Outcome : out Results.Result)
   is
   begin
      if not Lease.Active then
         Outcome := Results.Success;
         return;
      elsif Budget.Used_Bytes < Lease.Charged_Bytes then
         Outcome := Results.Failure (Errors.Internal_Invariant_Failed);
         return;
      end if;

      Budget.Used_Bytes := Budget.Used_Bytes - Lease.Charged_Bytes;
      Lease := (Active => False, Charged_Bytes => 0);
      Outcome := Results.Success;
   end Release_State;

   function Release
     (Budget : in out Byte_Budget;
      Lease : in out Byte_Lease) return Results.Result
   is
      pragma SPARK_Mode (Off);
      Outcome : Results.Result;
   begin
      Release_State (Budget, Lease, Outcome);
      return Outcome;
   end Release;
end Jpeglib.Internal.Ownership;

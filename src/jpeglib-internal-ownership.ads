with Jpeglib.Results;

package Jpeglib.Internal.Ownership is
   pragma Preelaborate;
   pragma SPARK_Mode (On);

   type Byte_Budget is private;
   type Byte_Lease is private;

   --  Used.
   --  @param Budget See package contract for this parameter.
   --  @return Operation result.
   function Used (Budget : Byte_Budget) return Byte_Count;
   --  Is active.
   --  @param Lease See package contract for this parameter.
   --  @return Operation result.
   function Is_Active (Lease : Byte_Lease) return Boolean;
   --  Size.
   --  @param Lease See package contract for this parameter.
   --  @return Operation result.
   function Size (Lease : Byte_Lease) return Byte_Count;

   --  Reserve state.
   --  @param Budget See package contract for this parameter.
   --  @param Limit See package contract for this parameter.
   --  @param Amount See package contract for this parameter.
   --  @param Lease See package contract for this parameter.
   --  @param Outcome See package contract for this parameter.
   procedure Reserve_State
     (Budget : in out Byte_Budget;
      Limit : Byte_Count;
      Amount : Byte_Count;
      Lease : out Byte_Lease;
      Outcome : out Results.Result)
      with Post =>
        (if Results.Succeeded (Outcome) then
           Used (Budget'Old) <= Byte_Count'Last - Amount
           and then Used (Budget) = Used (Budget'Old) + Amount
           and then Is_Active (Lease)
           and then Size (Lease) = Amount
         else
           Used (Budget) = Used (Budget'Old)
           and then not Is_Active (Lease)
           and then Size (Lease) = 0);

   --  Reserve.
   --  @param Budget See package contract for this parameter.
   --  @param Limit See package contract for this parameter.
   --  @param Amount See package contract for this parameter.
   --  @param Lease See package contract for this parameter.
   --  @return Operation result.
   function Reserve
     (Budget : in out Byte_Budget;
      Limit : Byte_Count;
      Amount : Byte_Count;
      Lease : out Byte_Lease) return Results.Result
      with SPARK_Mode => Off;

   --  Release state.
   --  @param Budget See package contract for this parameter.
   --  @param Lease See package contract for this parameter.
   --  @param Outcome See package contract for this parameter.
   procedure Release_State
     (Budget : in out Byte_Budget;
      Lease : in out Byte_Lease;
      Outcome : out Results.Result)
      with Post =>
        (if Results.Succeeded (Outcome) then
           not Is_Active (Lease)
           and then Size (Lease) = 0
           and then
             (if Is_Active (Lease'Old) then
                Used (Budget) = Used (Budget'Old) - Size (Lease'Old)
              else
                Used (Budget) = Used (Budget'Old))
         else
           Used (Budget) = Used (Budget'Old)
           and then Is_Active (Lease) = Is_Active (Lease'Old)
           and then Size (Lease) = Size (Lease'Old));

   --  Release.
   --  @param Budget See package contract for this parameter.
   --  @param Lease See package contract for this parameter.
   --  @return Operation result.
   function Release
     (Budget : in out Byte_Budget;
      Lease : in out Byte_Lease) return Results.Result
      with SPARK_Mode => Off;

private
   type Byte_Budget is record
      Used_Bytes : Byte_Count := 0;
   end record;

   type Byte_Lease is record
      Active : Boolean := False;
      Charged_Bytes : Byte_Count := 0;
   end record;

   --  Used.
   --  @param Budget See package contract for this parameter.
   --  @return Operation result.
   function Used (Budget : Byte_Budget) return Byte_Count is (Budget.Used_Bytes);
   --  Is active.
   --  @param Lease See package contract for this parameter.
   --  @return Operation result.
   function Is_Active (Lease : Byte_Lease) return Boolean is (Lease.Active);
   --  Size.
   --  @param Lease See package contract for this parameter.
   --  @return Operation result.
   function Size (Lease : Byte_Lease) return Byte_Count is
     (if Lease.Active then Lease.Charged_Bytes else 0);
end Jpeglib.Internal.Ownership;

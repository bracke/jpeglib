with Ada.Unchecked_Deallocation;

package body Jpeglib.Internal.Block_Heap is

   procedure Free is new Ada.Unchecked_Deallocation
     (Jpeglib.Coefficients.DCT_Block_Array, Block_Array_Access);

   overriding procedure Initialize (Item : in out Holder) is
   begin
      --  Allocated and then cleared a block at a time: an aggregate for the
      --  whole may be built on the stack first, which is what this avoids.
      Item.Data := new Jpeglib.Coefficients.DCT_Block_Array (1 .. Item.Count);
      for Block of Item.Data.all loop
         Block := [others => 0];
      end loop;
   end Initialize;

   overriding procedure Finalize (Item : in out Holder) is
   begin
      Free (Item.Data);
   end Finalize;

end Jpeglib.Internal.Block_Heap;

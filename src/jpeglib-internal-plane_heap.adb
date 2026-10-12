with Ada.Unchecked_Deallocation;

package body Jpeglib.Internal.Plane_Heap is

   procedure Free is new Ada.Unchecked_Deallocation
     (Jpeglib.Streams.Byte_Array, Plane_Access);

   overriding procedure Initialize (Item : in out Holder) is
   begin
      Item.Data := new Jpeglib.Streams.Byte_Array (1 .. Item.Count);
      for Sample of Item.Data.all loop
         Sample := Item.Fill;
      end loop;
   end Initialize;

   overriding procedure Finalize (Item : in out Holder) is
   begin
      Free (Item.Data);
   end Finalize;

end Jpeglib.Internal.Plane_Heap;

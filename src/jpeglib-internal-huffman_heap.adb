with Ada.Unchecked_Deallocation;

package body Jpeglib.Internal.Huffman_Heap is

   procedure Free is new Ada.Unchecked_Deallocation (Compiled_Array, Compiled_Array_Access);

   overriding procedure Initialize (Item : in out Holder) is
   begin
      Item.Data := new Compiled_Array (1 .. Component_Index'Base (Item.Count));
   end Initialize;

   overriding procedure Finalize (Item : in out Holder) is
   begin
      Free (Item.Data);
   end Finalize;

end Jpeglib.Internal.Huffman_Heap;

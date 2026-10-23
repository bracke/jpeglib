with Ada.Finalization;
with Jpeglib.Internal.Huffman;

--  A scan's compiled Huffman tables, one for each component, kept on the heap
--  rather than the stack.
--
--  A compiled table is about two hundred kilobytes, and a lossless scan held
--  one for each of up to four components in its frame: three quarters of a
--  megabyte, a third of a thread's stack of the default size. Held here,
--  they are allocated when the holder is elaborated and given back when it
--  goes out of scope.
package Jpeglib.Internal.Huffman_Heap is
   pragma Preelaborate;

   type Compiled_Array is array (Component_Index range <>) of Jpeglib.Internal.Huffman.Compiled_Huffman;
   type Compiled_Array_Access is access Compiled_Array;

   --  @field Count How many tables.
   --  @field Data The tables, numbered from one.
   type Holder (Count : Natural) is new Ada.Finalization.Limited_Controlled with record
      Data : Compiled_Array_Access := null;
   end record;

   overriding procedure Initialize (Item : in out Holder);
   overriding procedure Finalize (Item : in out Holder);

end Jpeglib.Internal.Huffman_Heap;

with Ada.Finalization;
with Jpeglib.Coefficients;

--  A run of coefficient blocks kept on the heap rather than the stack.
--
--  A picture's blocks are 256 bytes each, one for every 64 samples of every
--  component: 100 MB for a 3840 by 2160 picture in full colour, which is
--  more than a thread's stack holds. Held here, they are allocated zeroed
--  when the holder is elaborated and given back when it goes out of scope.
package Jpeglib.Internal.Block_Heap is
   pragma Preelaborate;

   type Block_Array_Access is access Jpeglib.Coefficients.DCT_Block_Array;

   --  @field Count How many blocks.
   --  @field Data The blocks, numbered from one, all nought to begin with.
   type Holder (Count : Natural) is new Ada.Finalization.Limited_Controlled with record
      Data : Block_Array_Access := null;
   end record;

   overriding procedure Initialize (Item : in out Holder);
   overriding procedure Finalize (Item : in out Holder);

end Jpeglib.Internal.Block_Heap;

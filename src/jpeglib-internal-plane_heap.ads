with Ada.Finalization;
with Jpeglib.Streams;

--  A plane of samples kept on the heap rather than the stack: a picture's
--  component planes are a byte a sample, eight megabytes each for a 3840 by
--  2160 picture, and several are live at once. Allocated filled with Fill
--  when the holder is elaborated, given back when it goes out of scope.
package Jpeglib.Internal.Plane_Heap is
   pragma Preelaborate;

   type Plane_Access is access Jpeglib.Streams.Byte_Array;

   --  @field Count How many samples.
   --  @field Fill What every sample holds to begin with.
   --  @field Data The samples, numbered from one.
   type Holder (Count : Natural; Fill : Jpeglib.Byte) is
     new Ada.Finalization.Limited_Controlled with record
      Data : Plane_Access := null;
   end record;

   overriding procedure Initialize (Item : in out Holder);
   overriding procedure Finalize (Item : in out Holder);

end Jpeglib.Internal.Plane_Heap;

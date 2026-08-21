with Jpeglib.Errors;

package Jpeglib.Streams is
   pragma Preelaborate;

   type Byte_Array is array (Positive range <>) of Byte;
   type Byte_Array_Access is access all Byte_Array;
   type Const_Byte_Array_Access is access constant Byte_Array;

   type Source_Result is record
      Result : Errors.Error := Errors.Make (Errors.No_Error);
      Count : Byte_Count := 0;
      End_Of_Input : Boolean := False;
   end record;

   type Destination_Result is record
      Result : Errors.Error := Errors.Make (Errors.No_Error);
      Count : Byte_Count := 0;
   end record;

   type Source is limited interface;
   function Read (Object : in out Source; Buffer : out Byte_Array) return Source_Result is abstract;
   function Offset (Object : Source) return Source_Offset is abstract;
   function Skip (Object : in out Source; Count : Byte_Count) return Source_Result is abstract;

   type Destination is limited interface;
   function Write (Object : in out Destination; Buffer : Byte_Array) return Destination_Result is abstract;
   function Offset (Object : Destination) return Destination_Offset is abstract;
   function Flush (Object : in out Destination) return Errors.Error is abstract;

   type Memory_Source is limited new Source with private;
   procedure Open (Object : in out Memory_Source; Storage : not null Const_Byte_Array_Access);
   overriding function Read (Object : in out Memory_Source; Buffer : out Byte_Array) return Source_Result;
   overriding function Offset (Object : Memory_Source) return Source_Offset;
   overriding function Skip (Object : in out Memory_Source; Count : Byte_Count) return Source_Result;

   type Fixed_Buffer_Destination is limited new Destination with private;
   procedure Open (Object : in out Fixed_Buffer_Destination; Storage : not null Byte_Array_Access);
   overriding function Write
     (Object : in out Fixed_Buffer_Destination; Buffer : Byte_Array) return Destination_Result;
   overriding function Offset (Object : Fixed_Buffer_Destination) return Destination_Offset;
   overriding function Flush (Object : in out Fixed_Buffer_Destination) return Errors.Error;

private
   type Memory_Source is limited new Source with record
      Storage : Const_Byte_Array_Access := null;
      Position : Natural := 0;
   end record;

   type Fixed_Buffer_Destination is limited new Destination with record
      Storage : Byte_Array_Access := null;
      Position : Natural := 0;
   end record;
end Jpeglib.Streams;

package body Jpeglib.Streams is
   procedure Open (Object : in out Memory_Source; Storage : not null Const_Byte_Array_Access) is
   begin
      Object.Storage := Storage;
      Object.Position := 0;
   end Open;

   overriding function Read (Object : in out Memory_Source; Buffer : out Byte_Array) return Source_Result is
      Available : Natural;
      To_Copy : Natural;
   begin
      if Object.Storage = null then
         return (Result => Errors.Make (Errors.Source_Read_Failed), Count => 0, End_Of_Input => False);
      end if;

      Available := Object.Storage'Length - Object.Position;
      To_Copy := Natural'Min (Buffer'Length, Available);

      if To_Copy > 0 then
         for I in 0 .. To_Copy - 1 loop
            Buffer (Buffer'First + I) := Object.Storage (Object.Storage'First + Object.Position + I);
         end loop;
      end if;

      Object.Position := Object.Position + To_Copy;
      return (Result => Errors.Make (Errors.No_Error), Count => Byte_Count (To_Copy), End_Of_Input => To_Copy = 0);
   end Read;

   overriding function Offset (Object : Memory_Source) return Source_Offset is
   begin
      return Source_Offset (Object.Position);
   end Offset;

   overriding function Skip (Object : in out Memory_Source; Count : Byte_Count) return Source_Result is
      Available : Natural;
      To_Skip : Natural;
   begin
      if Object.Storage = null then
         return (Result => Errors.Make (Errors.Source_Read_Failed), Count => 0, End_Of_Input => False);
      end if;

      Available := Object.Storage'Length - Object.Position;
      if Count > Byte_Count (Natural'Last) then
         To_Skip := Available;
      else
         To_Skip := Natural'Min (Natural (Count), Available);
      end if;
      Object.Position := Object.Position + To_Skip;
      return (Result => Errors.Make (Errors.No_Error), Count => Byte_Count (To_Skip), End_Of_Input => To_Skip = 0);
   end Skip;

   procedure Open (Object : in out Fixed_Buffer_Destination; Storage : not null Byte_Array_Access) is
   begin
      Object.Storage := Storage;
      Object.Position := 0;
   end Open;

   overriding function Write
     (Object : in out Fixed_Buffer_Destination; Buffer : Byte_Array) return Destination_Result
   is
      Available : Natural;
      To_Copy : Natural;
   begin
      if Object.Storage = null then
         return (Result => Errors.Make (Errors.Destination_Write_Failed), Count => 0);
      end if;

      Available := Object.Storage'Length - Object.Position;
      To_Copy := Natural'Min (Buffer'Length, Available);

      if To_Copy > 0 then
         for I in 0 .. To_Copy - 1 loop
            Object.Storage (Object.Storage'First + Object.Position + I) := Buffer (Buffer'First + I);
         end loop;
      end if;

      Object.Position := Object.Position + To_Copy;

      if To_Copy /= Buffer'Length then
         return (Result => Errors.Make (Errors.Output_Limit_Exceeded), Count => Byte_Count (To_Copy));
      end if;

      return (Result => Errors.Make (Errors.No_Error), Count => Byte_Count (To_Copy));
   end Write;

   overriding function Offset (Object : Fixed_Buffer_Destination) return Destination_Offset is
   begin
      return Destination_Offset (Object.Position);
   end Offset;

   overriding function Flush (Object : in out Fixed_Buffer_Destination) return Errors.Error is
      pragma Unreferenced (Object);
   begin
      return Errors.Make (Errors.No_Error);
   end Flush;
end Jpeglib.Streams;

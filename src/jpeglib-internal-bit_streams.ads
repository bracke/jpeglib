with Interfaces;
with Jpeglib.Internal.Markers;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Bit_Streams is
   pragma Preelaborate;

   type Entropy_Category is range 0 .. 16;
   type Entropy_Bits is new Interfaces.Unsigned_32;
   type Entropy_Value is new Interfaces.Integer_32;
   type Bit_Value is range 0 .. 1;

   type Sign_Extend_Result is record
      Outcome : Results.Result := Results.Success;
      Value : Entropy_Value := 0;
   end record;

   function Sign_Extend (Category : Entropy_Category; Bits : Entropy_Bits) return Sign_Extend_Result;

   type Entropy_Byte_Kind is
     (Entropy_Data,
      Restart_Marker,
      Scan_Ending_Marker,
      Physical_End_Of_Input);

   type Entropy_Read_Result is record
      Outcome : Results.Result := Results.Success;
      Kind : Entropy_Byte_Kind := Entropy_Data;
      Source : Source_Offset := 0;
      Value : Byte := 0;
      Marker : Marker_Code := 0;
   end record;

   type Entropy_Reader (Input : not null access Streams.Source'Class) is limited private;

   function Read_Byte (Reader : in out Entropy_Reader) return Entropy_Read_Result;
   function Has_Pending_Marker (Reader : Entropy_Reader) return Boolean;
   procedure Put_Back_Marker
     (Reader : in out Entropy_Reader;
      Source : Source_Offset;
      Marker : Marker_Code);
   function Take_Pending_Marker (Reader : in out Entropy_Reader) return Markers.Marker_Result
     with Pre => Has_Pending_Marker (Reader);

   type Bit_Result is record
      Outcome : Results.Result := Results.Success;
      Source : Source_Offset := 0;
      Value : Bit_Value := 0;
   end record;

   type Bit_Reader (Entropy : not null access Entropy_Reader) is limited private;

   function Read_Bit (Reader : in out Bit_Reader) return Bit_Result;
   procedure Byte_Align (Reader : in out Bit_Reader);

   type Bit_Writer (Output : not null access Streams.Destination'Class) is limited private;

   function Write_Bits
     (Writer : in out Bit_Writer;
      Width : Entropy_Category;
      Bits : Entropy_Bits) return Results.Result;

   function Flush_Byte
     (Writer : in out Bit_Writer;
      Pad : Bit_Value := 1) return Results.Result;

   function Write_Restart_Marker
     (Writer : in out Bit_Writer;
      Marker : Marker_Code) return Results.Result
     with Pre => Markers.Is_Restart (Marker);

private
   type Entropy_Reader (Input : not null access Streams.Source'Class) is limited record
      Pending : Boolean := False;
      Pending_Source : Source_Offset := 0;
      Pending_Marker : Marker_Code := 0;
   end record;

   type Bit_Reader (Entropy : not null access Entropy_Reader) is limited record
      Buffered_Byte : Byte := 0;
      Bits_Remaining : Natural range 0 .. 8 := 0;
      Byte_Source : Source_Offset := 0;
   end record;

   type Bit_Writer (Output : not null access Streams.Destination'Class) is limited record
      Buffered_Byte : Byte := 0;
      Bits_Filled : Natural range 0 .. 8 := 0;
   end record;
end Jpeglib.Internal.Bit_Streams;

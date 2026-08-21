with Jpeglib.Internal.Segments;
with Jpeglib.Internal.Bit_Streams;
with Jpeglib.Results;

package Jpeglib.Internal.Huffman is
   pragma Preelaborate;

   type Huffman_Class is (DC, AC);
   type Code_Length is range 1 .. 16;
   type Symbol_Count is range 0 .. 256;
   type Symbol_Index is range 1 .. 256;
   type Symbol_Array is array (Symbol_Index) of Byte;
   type Length_Counts is array (Code_Length) of Symbol_Count;

   type Huffman_Definition is private;
   type Compiled_Huffman is private;
   type Huffman_State is private;

   function Has_Table
     (State : Huffman_State;
      Class : Huffman_Class;
      Index : Huffman_Table_Index) return Boolean;

   function Definition
     (State : Huffman_State;
      Class : Huffman_Class;
      Index : Huffman_Table_Index) return Huffman_Definition
     with Pre => Has_Table (State, Class, Index);

   function Counts (Definition : Huffman_Definition) return Length_Counts;
   function Symbol_Total (Definition : Huffman_Definition) return Symbol_Count;
   function Symbol (Definition : Huffman_Definition; Index : Symbol_Index) return Byte
     with Pre => Natural (Index) <= Natural (Symbol_Total (Definition));

   function Standard_Luminance_DC return Huffman_Definition;
   function Standard_Luminance_AC return Huffman_Definition;
   function Standard_Chrominance_DC return Huffman_Definition;
   function Standard_Chrominance_AC return Huffman_Definition;

   function Parse_DHT
     (State : in out Huffman_State;
      Segment : in out Segments.Segment_Reader) return Results.Result;

   type Compile_Result is record
      Outcome : Results.Result := Results.Success;
      Table : Compiled_Huffman;
   end record;

   type Decode_Result is record
      Outcome : Results.Result := Results.Success;
      Source : Source_Offset := 0;
      Symbol : Byte := 0;
   end record;

   function Compile (Definition : Huffman_Definition) return Compile_Result;
   function Decode
     (Table : Compiled_Huffman;
      Bits : in out Bit_Streams.Bit_Reader) return Decode_Result;
   function Encode
     (Table : Compiled_Huffman;
      Bits : in out Bit_Streams.Bit_Writer;
      Symbol : Byte) return Results.Result;

private
   type Huffman_Code is range 0 .. 65_535;

   type Huffman_Definition is record
      Lengths : Length_Counts := [others => 0];
      Symbols : Symbol_Array := [others => 0];
      Total : Symbol_Count := 0;
   end record;

   type Compiled_Entry is record
      Length : Code_Length := Code_Length'First;
      Code : Huffman_Code := 0;
      Symbol : Byte := 0;
   end record;

   type Compiled_Entries is array (Symbol_Index) of Compiled_Entry;

   type Compiled_Huffman is record
      Entries : Compiled_Entries := [others => (others => <>)];
      Total : Symbol_Count := 0;
   end record;

   type Presence_By_Index is array (Huffman_Table_Index) of Boolean;
   type Definition_By_Index is array (Huffman_Table_Index) of Huffman_Definition;
   type Presence_By_Class is array (Huffman_Class) of Presence_By_Index;
   type Definition_By_Class is array (Huffman_Class) of Definition_By_Index;

   type Huffman_State is record
      Present : Presence_By_Class := [others => [others => False]];
      Tables : Definition_By_Class := [others => [others => (others => <>)]];
   end record;
end Jpeglib.Internal.Huffman;

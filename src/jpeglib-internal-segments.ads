with Jpeglib.Internal.Bytes;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Segments is
   pragma Preelaborate;

   type Payload_Length_Result is record
      Valid : Boolean := False;
      Payload_Length : Byte_Count := 0;
   end record;

   function Decode_Payload_Length (Declared_Length : Byte_Count) return Payload_Length_Result
     with SPARK_Mode => On,
          Post =>
            (if Decode_Payload_Length'Result.Valid then
               Declared_Length >= 2
               and then Decode_Payload_Length'Result.Payload_Length = Declared_Length - 2
             else
               Declared_Length < 2
               and then Decode_Payload_Length'Result.Payload_Length = 0);

   function Skip_Count_Is_Bounded (Remaining, Count : Byte_Count) return Boolean
     with SPARK_Mode => On,
          Post =>
            Skip_Count_Is_Bounded'Result =
              (Count > 0 and then Count <= Remaining);

   function Remaining_After_Skip (Remaining, Count : Byte_Count) return Byte_Count
     with SPARK_Mode => On,
          Pre => Skip_Count_Is_Bounded (Remaining, Count),
          Post => Remaining_After_Skip'Result = Remaining - Count;

   type Segment_Descriptor is record
      Marker : Marker_Code := 0;
      Marker_Source : Source_Offset := 0;
      Length_Source : Source_Offset := 0;
      Declared_Length : Byte_Count := 0;
      Payload_Length : Byte_Count := 0;
      Payload_Source : Source_Offset := 0;
   end record;

   type Segment_Reader (Input : not null access Streams.Source'Class) is limited private;

   function Open
     (Input : not null access Streams.Source'Class;
      Marker : Marker_Code;
      Marker_Source : Source_Offset) return Segment_Reader;

   function Descriptor (Object : Segment_Reader) return Segment_Descriptor;
   function Remaining (Object : Segment_Reader) return Byte_Count;
   function Status (Object : Segment_Reader) return Results.Result;
   function Read_Byte (Object : in out Segment_Reader) return Bytes.Read_Byte_Result;
   function Skip_Remaining (Object : in out Segment_Reader) return Results.Result;

private
   type Segment_Reader (Input : not null access Streams.Source'Class) is limited record
      Item : Segment_Descriptor;
      Bytes_Remaining : Byte_Count := 0;
      Outcome : Results.Result := Results.Success;
   end record;
end Jpeglib.Internal.Segments;

with Jpeglib.Streams;

package Jpeglib.Metadata is
   pragma Preelaborate;

   type Metadata_Policy is
     (Discard_All,
      Parse_Known_Without_Retention,
      Preserve_Known,
      Preserve_Selected,
      Preserve_All_Bounded,
      Stream_To_Callback);

   type Metadata_Kind is
     (JFIF,
      JFXX,
      Adobe_APP14,
      Photoshop_APP13,
      ICC,
      Exif,
      XMP,
      Extended_XMP,
      Comment,
      Unknown_APP);
   type Kind_Set is array (Metadata_Kind) of Boolean;

   type Exif_Orientation is
     (Orientation_Unknown,
      Orientation_Normal,
      Orientation_Mirror_Horizontal,
      Orientation_Rotate_180,
      Orientation_Mirror_Vertical,
      Orientation_Transpose,
      Orientation_Rotate_90,
      Orientation_Transverse,
      Orientation_Rotate_270);

   type Segment_Summary is record
      Marker : Marker_Code := 0;
      Kind : Metadata_Kind := Unknown_APP;
      Source : Source_Offset := 0;
      Payload_Length : Byte_Count := 0;
      Payload_Offset : Byte_Count := 0;
      Retained_Length : Byte_Count := 0;
   end record;

   Max_Header_Summaries : constant := 16;
   type Segment_Summary_Index is range 1 .. Max_Header_Summaries;
   type Segment_Summary_Array is array (Segment_Summary_Index) of Segment_Summary;

   type Encode_Segment is record
      Marker : Marker_Code := 0;
      Payload : Streams.Const_Byte_Array_Access := null;
   end record;

   type Encode_Segment_Array is array (Positive range <>) of Encode_Segment;
   No_Encode_Segments : constant Encode_Segment_Array (1 .. 0) := [];

   type Callback_Event is (Segment_Begin, Segment_Data, Segment_End);

   type Callback_View is record
      Marker : Marker_Code;
      Kind : Metadata_Kind;
      Source : Source_Offset;
      Declared_Payload_Length : Byte_Count;
      Chunk_Offset : Byte_Count;
      Chunk : Streams.Const_Byte_Array_Access;
   end record;

   type Callback_Access is access procedure (Event : Callback_Event; View : Callback_View);
end Jpeglib.Metadata;

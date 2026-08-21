with Jpeglib.Internal.Arithmetic;
with Jpeglib.Internal.Frames;
with Jpeglib.Internal.Coefficients;
with Jpeglib.Internal.Huffman;
with Jpeglib.Internal.Quantization;
with Jpeglib.Internal.Scans;
with Jpeglib.Limits;
with Jpeglib.Metadata;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Decoder is
   pragma Preelaborate;

   subtype ICC_Fragment_Index is Natural range 1 .. 255;
   type ICC_Fragment_Seen_Array is array (ICC_Fragment_Index) of Boolean;

   type Header_Result is record
      Outcome : Results.Result := Results.Success;
      Frame : Frames.Frame;
      Scan : Scans.Scan;
      Quantization_State : Quantization.Quantization_State;
      Huffman_State : Huffman.Huffman_State;
      Arithmetic_State : Arithmetic.Arithmetic_State;
      Entropy : Entropy_Mode := Entropy_Mode'Val (0);
      Restart : Restart_Interval := 0;
      Metadata_Segments : Natural := 0;
      Metadata_Bytes : Byte_Count := 0;
      Retained_Metadata_Bytes : Byte_Count := 0;
      Metadata_Callbacks : Natural := 0;
      ICC_Profile_Bytes : Byte_Count := 0;
      ICC_Profile_Fragments : Natural := 0;
      ICC_Profile_Fragment_Count : Natural := 0;
      ICC_Profile_Fragment_Seen : ICC_Fragment_Seen_Array := [others => False];
      Has_Exif_Orientation : Boolean := False;
      Exif_Orientation : Metadata.Exif_Orientation := Metadata.Orientation_Normal;
      Has_Adobe_APP14_Transform : Boolean := False;
      Adobe_APP14_Transform : Natural range 0 .. 255 := 0;
      Hierarchical : Boolean := False;
      Retained_Metadata_Summaries : Natural range 0 .. Metadata.Max_Header_Summaries := 0;
      Metadata_Summaries : Metadata.Segment_Summary_Array := [others => (others => <>)];
      Saw_SOS : Boolean := False;
   end record;

   function Read_Header
     (Input : not null access Streams.Source'Class;
      Metadata_Policy : Metadata.Metadata_Policy := Metadata.Parse_Known_Without_Retention;
      Selected_Metadata : Metadata.Kind_Set := [others => False];
      Metadata_Callback : Metadata.Callback_Access := null;
      Metadata_Buffer : Streams.Byte_Array_Access := null;
      Decode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Header_Result;

   type Coefficient_Result is record
      Outcome : Results.Result := Results.Success;
      Header : Header_Result;
      Blocks_Decoded : Block_Count := 0;
      Ending_Marker : Marker_Code := 0;
      Ending_Source : Source_Offset := 0;
   end record;

   function Decode_Baseline_Coefficients
     (Input : not null access Streams.Source'Class;
      Blocks : in out Coefficients.Block_Array;
      Metadata_Policy : Metadata.Metadata_Policy := Metadata.Parse_Known_Without_Retention;
      Selected_Metadata : Metadata.Kind_Set := [others => False];
      Metadata_Callback : Metadata.Callback_Access := null;
      Metadata_Buffer : Streams.Byte_Array_Access := null;
      Decode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Coefficient_Result;

   function Decode_Baseline_Coefficients
     (Header : Header_Result;
      Input : not null access Streams.Source'Class;
      Blocks : in out Coefficients.Block_Array) return Coefficient_Result;

   function Decode_Arithmetic_Coefficients
     (Header : Header_Result;
      Input : not null access Streams.Source'Class;
      Blocks : in out Coefficients.Block_Array) return Coefficient_Result;

   function Decode_Progressive_Coefficients
     (Input : not null access Streams.Source'Class;
      Blocks : in out Coefficients.Block_Array;
      Metadata_Policy : Metadata.Metadata_Policy := Metadata.Parse_Known_Without_Retention;
      Selected_Metadata : Metadata.Kind_Set := [others => False];
      Metadata_Callback : Metadata.Callback_Access := null;
      Metadata_Buffer : Streams.Byte_Array_Access := null;
      Decode_Limits : Limits.Limit_Set := Limits.Default_Limits) return Coefficient_Result;

   function Decode_Progressive_Coefficients
     (Header : Header_Result;
      Input : not null access Streams.Source'Class;
      Blocks : in out Coefficients.Block_Array) return Coefficient_Result;
end Jpeglib.Internal.Decoder;

with Jpeglib.Errors;
with Jpeglib.Images;
with Jpeglib.Limits;
with Jpeglib.Metadata;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Encoding is
   pragma Preelaborate;

   type Encoder_State is
     (Uninitialized,
      Initialized,
      Image_Defined,
      Accepting_Metadata,
      Accepting_Input,
      Preparing_Scans,
      Writing_Scans,
      Completed,
      Cancelled,
      Failed,
      Finalized);

   type Chroma_Subsampling is (Subsampling_444, Subsampling_422, Subsampling_420, Subsampling_411);
   type Progressive_Script is (No_Progressive, Balanced_Progressive, Fast_Preview_Progressive);
   type Encoding_Mode is
     (Sequential_DCT,
      Arithmetic_Sequential_DCT,
      Differential_Sequential_DCT,
      Arithmetic_Differential_Sequential_DCT,
      Hierarchical_Sequential_DCT,
      Hierarchical_Arithmetic_Sequential_DCT,
      Hierarchical_Differential_Sequential_DCT,
      Hierarchical_Arithmetic_Differential_Sequential_DCT,
      Lossless_Huffman,
      Arithmetic_Lossless,
      Differential_Lossless_Huffman,
      Arithmetic_Differential_Lossless,
      Hierarchical_Lossless_Huffman,
      Hierarchical_Arithmetic_Lossless,
      Hierarchical_Differential_Lossless_Huffman,
      Hierarchical_Arithmetic_Differential_Lossless);

   type Options is record
      Quality : Positive range 1 .. 100 := 75;
      Mode : Encoding_Mode := Sequential_DCT;
      Progressive : Progressive_Script := No_Progressive;
      Lossless_Predictor : Lossless_Predictor_Selection := 1;
      Lossless_Point_Transform : Lossless_Point_Transform_Value := 0;
      Subsampling : Chroma_Subsampling := Subsampling_420;
      Restart : Restart_Interval := 0;
      Metadata : Jpeglib.Metadata.Metadata_Policy := Jpeglib.Metadata.Discard_All;
   end record;

   type Encoder is limited private;

   procedure Initialize
     (Object : in out Encoder;
      Output : not null access Streams.Destination'Class;
      Encode_Options : Options := (others => <>);
      Encode_Limits : Limits.Limit_Set := Limits.Default_Limits);

   procedure Reset (Object : in out Encoder; Output : not null access Streams.Destination'Class);
   function State (Object : Encoder) return Encoder_State;
   function Define_Image (Object : in out Encoder; Descriptor : Images.Image_Descriptor) return Results.Result;
   function Add_Metadata_Segment
     (Object : in out Encoder;
      Marker : Marker_Code;
      Payload : not null Streams.Const_Byte_Array_Access) return Results.Result;
   function Encode_Image (Object : in out Encoder; Input : Images.Image_View) return Results.Result;
   function Finish (Object : in out Encoder) return Results.Result;
   function Last_Error (Object : Encoder) return Errors.Error;
   procedure Cancel (Object : in out Encoder);
   procedure Finalize (Object : in out Encoder);

private
   type Destination_Access is access all Streams.Destination'Class;

   type Encoder is limited record
      Current_State : Encoder_State := Uninitialized;
      Output : Destination_Access := null;
      Encode_Options : Options := (others => <>);
      Encode_Limits : Limits.Limit_Set := Limits.Default_Limits;
      First_Error : Errors.Error := Errors.Make (Errors.No_Error);
      Image_Is_Defined : Boolean := False;
      Metadata_Segment_Count : Natural range 0 .. Metadata.Max_Header_Summaries := 0;
      Metadata_Segments : Metadata.Encode_Segment_Array (1 .. Metadata.Max_Header_Summaries) :=
        [others => (others => <>)];
      Metadata_Bytes : Byte_Count := 0;
      Descriptor : Images.Image_Descriptor :=
        (Width => 1,
         Height => 1,
         Format => Images.Gray_8,
         Stride => 1,
         Accessible_Bytes => 1);
   end record;
end Jpeglib.Encoding;

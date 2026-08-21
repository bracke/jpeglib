with Jpeglib.Errors;
with Jpeglib.Coefficients;
with Jpeglib.Images;
with Jpeglib.Internal.Decoder;
with Jpeglib.Limits;
with Jpeglib.Metadata;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Decoding is
   pragma Preelaborate;

   type Decoder_State is
     (Uninitialized,
      Initialized,
      Header_Reading,
      Header_Ready,
      Decoding,
      Completed,
      Cancelled,
      Failed,
      Finalized);

   type IDCT_Scaling_Mode is (Full_Size, Half_Size, Quarter_Size, Eighth_Size);

   type Options is record
      Strictness : Strictness_Mode := Strict;
      Metadata : Jpeglib.Metadata.Metadata_Policy := Jpeglib.Metadata.Parse_Known_Without_Retention;
      Selected_Metadata : Jpeglib.Metadata.Kind_Set := [others => False];
      Metadata_Callback : Jpeglib.Metadata.Callback_Access := null;
      Metadata_Buffer : Streams.Byte_Array_Access := null;
      Apply_Exif_Orientation : Boolean := False;
      IDCT_Scaling : IDCT_Scaling_Mode := Full_Size;
      Output_Format : Images.Pixel_Format := Images.RGB_24;
      Alpha_Fill : Byte := 255;
   end record;

   type Image_Info is record
      Width : Image_Width := Image_Width'First;
      Height : Image_Height := Image_Height'First;
      Height_Defined : Boolean := True;
      Precision : Sample_Precision := 8;
      Mode : Frame_Mode := Unsupported_Frame;
      Entropy : Entropy_Mode := Huffman;
      Components : Component_Count := 1;
      Progressive : Boolean := False;
      Hierarchical : Boolean := False;
      Lossless_Predictor : Lossless_Predictor_Selection := 1;
      Lossless_Point_Transform : Successive_Approximation_Value := 0;
      Color_Model : Encoded_Color_Model := Unknown;
      Restart : Restart_Interval := 0;
      Coefficient_Blocks : Block_Count := 0;
      Metadata_Segments : Natural := 0;
      Metadata_Bytes : Byte_Count := 0;
      Retained_Metadata_Bytes : Byte_Count := 0;
      ICC_Profile_Bytes : Byte_Count := 0;
      ICC_Profile_Fragments : Natural := 0;
      ICC_Profile_Fragment_Count : Natural := 0;
      Has_Exif_Orientation : Boolean := False;
      Exif_Orientation : Metadata.Exif_Orientation := Metadata.Orientation_Normal;
      Retained_Metadata_Summaries : Natural range 0 .. Metadata.Max_Header_Summaries := 0;
      Metadata_Summaries : Metadata.Segment_Summary_Array := [others => (others => <>)];
   end record;

   type Raw_Component_View is record
      Width : Natural := 0;
      Height : Natural := 0;
      Stride : Row_Stride := 0;
      Accessible_Bytes : Byte_Count := 0;
      Storage : Streams.Byte_Array_Access := null;
   end record;

   type Raw_Component_View_Array is array (Component_Index range <>) of Raw_Component_View;

   type Decoder is limited private;

   procedure Initialize
     (Object : in out Decoder;
      Input : not null access Streams.Source'Class;
      Decode_Options : Options := (others => <>);
      Decode_Limits : Limits.Limit_Set := Limits.Default_Limits);

   procedure Reset (Object : in out Decoder; Input : not null access Streams.Source'Class);
   function State (Object : Decoder) return Decoder_State;
   function Read_Header (Object : in out Decoder) return Results.Result;
   function Header (Object : Decoder) return Image_Info;
   function Decode_Coefficients
     (Object : in out Decoder;
      Blocks : in out Jpeglib.Coefficients.DCT_Block_Array;
      Blocks_Decoded : out Block_Count) return Results.Result;
   function Decode_Raw_Components
     (Object : in out Decoder;
      Components : in out Raw_Component_View_Array) return Results.Result;
   function Decode_Image (Object : in out Decoder; Output : in out Images.Mutable_Image_View) return Results.Result;
   function Last_Error (Object : Decoder) return Errors.Error;
   procedure Cancel (Object : in out Decoder);
   procedure Finalize (Object : in out Decoder);

private
   type Source_Access is access all Streams.Source'Class;

   type Decoder is limited record
      Current_State : Decoder_State := Uninitialized;
      Input : Source_Access := null;
      Decode_Options : Options := (others => <>);
      Decode_Limits : Limits.Limit_Set := Limits.Default_Limits;
      Header_Info : Image_Info;
      Saved_Header : Internal.Decoder.Header_Result;
      First_Error : Errors.Error := Errors.Make (Errors.No_Error);
   end record;
end Jpeglib.Decoding;

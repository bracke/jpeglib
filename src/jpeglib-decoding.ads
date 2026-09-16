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
   --  Raw component output precision handling. Byte-oriented image decode always
   --  returns public image formats, but Decode_Raw_Components can either scale,
   --  clamp, preserve, or reject source/output precision mismatches.
   type Raw_Precision_Policy is
     (Scale_To_Output_Precision,
      Clamp_To_Output_Precision,
      Preserve_Source_Precision,
      Reject_Precision_Mismatch);
   --  Byte order used for two-byte raw component samples. One-byte output is
   --  unaffected by this setting.
   type Raw_Sample_Byte_Order is
     (Most_Significant_Byte_First,
      Least_Significant_Byte_First);

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
      --  Requested raw output precision when Raw_Precision does not preserve
      --  the source precision. Precision 8 uses one byte per raw sample; wider
      --  supported precision uses two bytes per raw sample.
      Raw_Output_Precision : Sample_Precision := 8;
      --  Policy applied by Decode_Raw_Components when source precision and
      --  Raw_Output_Precision differ.
      Raw_Precision : Raw_Precision_Policy := Scale_To_Output_Precision;
      --  Byte order for two-byte raw component samples written by
      --  Decode_Raw_Components and read by the options-based raw sample helpers.
      Raw_Byte_Order : Raw_Sample_Byte_Order := Most_Significant_Byte_First;
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
   --  Decoded raw component sample value after reading the caller buffer. The
   --  current JPEG precision range is 8 through 12 bits.
   subtype Raw_Sample_Value is Natural range 0 .. 4095;
   --  Non-raising raw sample read result. Sample is zero when Outcome is a
   --  failure.
   type Raw_Sample_Result is record
      Outcome : Results.Result := Results.Success;
      Sample : Raw_Sample_Value := 0;
   end record;

   type Raw_Component_View_Array is array (Component_Index range <>) of Raw_Component_View;

   --  Effective raw output precision.
   --  @param Decode_Options See package contract for this parameter.
   --  @param Source_Precision See package contract for this parameter.
   --  @return Operation result.
   function Effective_Raw_Output_Precision
     (Decode_Options : Options;
      Source_Precision : Sample_Precision) return Sample_Precision;
   --  Return the precision Decode_Raw_Components will write for a source image.

   --  Raw bytes per sample.
   --  @param Output_Precision See package contract for this parameter.
   --  @return Operation result.
   function Raw_Bytes_Per_Sample (Output_Precision : Sample_Precision) return Byte_Count;
   --  Return 1 for 8-bit raw output and 2 for wider supported raw output.

   --  Raw minimum row bytes.
   --  @param Width See package contract for this parameter.
   --  @param Decode_Options See package contract for this parameter.
   --  @param Source_Precision See package contract for this parameter.
   --  @return Operation result.
   function Raw_Minimum_Row_Bytes
     (Width : Natural;
      Decode_Options : Options;
      Source_Precision : Sample_Precision) return Byte_Count;
   --  Minimum bytes required for one raw component row under Decode_Options.
   --  Returns Byte_Count'Last if the requested row cannot be represented.

   --  Raw accessible bytes.
   --  @param Width See package contract for this parameter.
   --  @param Height See package contract for this parameter.
   --  @param Stride See package contract for this parameter.
   --  @param Decode_Options See package contract for this parameter.
   --  @param Source_Precision See package contract for this parameter.
   --  @return Operation result.
   function Raw_Accessible_Bytes
     (Width : Natural;
      Height : Natural;
      Stride : Row_Stride;
      Decode_Options : Options;
      Source_Precision : Sample_Precision) return Byte_Count;
   --  Minimum accessible bytes required for a raw component view. This includes
   --  row stride and the final row width, and saturates at Byte_Count'Last for
   --  impossible dimensions.

   --  Raw component view is valid.
   --  @param View See package contract for this parameter.
   --  @param Expected_Width See package contract for this parameter.
   --  @param Expected_Height See package contract for this parameter.
   --  @param Decode_Options See package contract for this parameter.
   --  @param Source_Precision See package contract for this parameter.
   --  @return Operation result.
   function Raw_Component_View_Is_Valid
     (View : Raw_Component_View;
      Expected_Width : Natural;
      Expected_Height : Natural;
      Decode_Options : Options;
      Source_Precision : Sample_Precision) return Boolean;
   --  Check the same raw component width, height, stride, accessible byte, and
   --  storage-length contract enforced by Decode_Raw_Components.

   --  Raw sample position is valid.
   --  @param View See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param Column See package contract for this parameter.
   --  @param Output_Precision See package contract for this parameter.
   --  @return Operation result.
   function Raw_Sample_Position_Is_Valid
     (View : Raw_Component_View;
      Row : Natural;
      Column : Natural;
      Output_Precision : Sample_Precision) return Boolean;
   --  Raw sample position is valid.
   --  @param View See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param Column See package contract for this parameter.
   --  @param Decode_Options See package contract for this parameter.
   --  @param Source_Precision See package contract for this parameter.
   --  @return Operation result.
   function Raw_Sample_Position_Is_Valid
     (View : Raw_Component_View;
      Row : Natural;
      Column : Natural;
      Decode_Options : Options;
      Source_Precision : Sample_Precision) return Boolean;
   --  Check whether a packed raw sample can be read at Row and Column without
   --  exceeding View.Accessible_Bytes or View.Storage'Length.

   --  Try raw sample at.
   --  @param View See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param Column See package contract for this parameter.
   --  @param Output_Precision See package contract for this parameter.
   --  @param Byte_Order See package contract for this parameter.
   --  @return Operation result.
   function Try_Raw_Sample_At
     (View : Raw_Component_View;
      Row : Natural;
      Column : Natural;
      Output_Precision : Sample_Precision;
      Byte_Order : Raw_Sample_Byte_Order := Most_Significant_Byte_First) return Raw_Sample_Result;
   --  Try raw sample at.
   --  @param View See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param Column See package contract for this parameter.
   --  @param Decode_Options See package contract for this parameter.
   --  @param Source_Precision See package contract for this parameter.
   --  @return Operation result.
   function Try_Raw_Sample_At
     (View : Raw_Component_View;
      Row : Natural;
      Column : Natural;
      Decode_Options : Options;
      Source_Precision : Sample_Precision) return Raw_Sample_Result;
   --  Read a packed raw sample, returning Output_Limit_Exceeded instead of
   --  raising or indexing invalid caller storage.

   --  Raw sample at.
   --  @param View See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param Column See package contract for this parameter.
   --  @param Output_Precision See package contract for this parameter.
   --  @param Byte_Order See package contract for this parameter.
   --  @return Operation result.
   function Raw_Sample_At
     (View : Raw_Component_View;
      Row : Natural;
      Column : Natural;
      Output_Precision : Sample_Precision;
      Byte_Order : Raw_Sample_Byte_Order := Most_Significant_Byte_First) return Raw_Sample_Value;
   --  Raw sample at.
   --  @param View See package contract for this parameter.
   --  @param Row See package contract for this parameter.
   --  @param Column See package contract for this parameter.
   --  @param Decode_Options See package contract for this parameter.
   --  @param Source_Precision See package contract for this parameter.
   --  @return Operation result.
   function Raw_Sample_At
     (View : Raw_Component_View;
      Row : Natural;
      Column : Natural;
      Decode_Options : Options;
      Source_Precision : Sample_Precision) return Raw_Sample_Value;
   --  Read a packed raw sample from a valid view. Invalid positions return zero;
   --  callers that need an error should use Try_Raw_Sample_At.

   type Decoder is limited private;

   --  Initialize.
   --  @param Object See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   --  @param Decode_Options See package contract for this parameter.
   --  @param Decode_Limits See package contract for this parameter.
   procedure Initialize
     (Object : in out Decoder;
      Input : not null access Streams.Source'Class;
      Decode_Options : Options := (others => <>);
      Decode_Limits : Limits.Limit_Set := Limits.Default_Limits);

   --  Reset.
   --  @param Object See package contract for this parameter.
   --  @param Input See package contract for this parameter.
   procedure Reset (Object : in out Decoder; Input : not null access Streams.Source'Class);
   --  State.
   --  @param Object See package contract for this parameter.
   --  @return Operation result.
   function State (Object : Decoder) return Decoder_State;
   --  Read header.
   --  @param Object See package contract for this parameter.
   --  @return Operation result.
   function Read_Header (Object : in out Decoder) return Results.Result;
   --  Header.
   --  @param Object See package contract for this parameter.
   --  @return Operation result.
   function Header (Object : Decoder) return Image_Info;
   --  Decode coefficients.
   --  @param Object See package contract for this parameter.
   --  @param Blocks See package contract for this parameter.
   --  @param Blocks_Decoded See package contract for this parameter.
   --  @return Operation result.
   function Decode_Coefficients
     (Object : in out Decoder;
      Blocks : in out Jpeglib.Coefficients.DCT_Block_Array;
      Blocks_Decoded : out Block_Count) return Results.Result;
   --  Decode raw components.
   --  @param Object See package contract for this parameter.
   --  @param Components See package contract for this parameter.
   --  @return Operation result.
   function Decode_Raw_Components
     (Object : in out Decoder;
      Components : in out Raw_Component_View_Array) return Results.Result;
   --  Decode image.
   --  @param Object See package contract for this parameter.
   --  @param Output See package contract for this parameter.
   --  @return Operation result.
   function Decode_Image (Object : in out Decoder; Output : in out Images.Mutable_Image_View) return Results.Result;
   --  Last error.
   --  @param Object See package contract for this parameter.
   --  @return Operation result.
   function Last_Error (Object : Decoder) return Errors.Error;
   --  Cancel.
   --  @param Object See package contract for this parameter.
   procedure Cancel (Object : in out Decoder);
   --  Finalize.
   --  @param Object See package contract for this parameter.
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

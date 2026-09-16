with Jpeglib.Decoding;
with Jpeglib.Encoding;
with Jpeglib.Metadata;

package Jpeglib.Internal.Library_Policy is
   pragma Preelaborate;
   pragma SPARK_Mode (On);
   use type Metadata.Metadata_Kind;

   --  Decode entry allowed.
   --  @param State See package contract for this parameter.
   --  @return Operation result.
   function Decode_Entry_Allowed
     (State : Decoding.Decoder_State) return Boolean is
     (State in Decoding.Initialized | Decoding.Header_Ready)
     with Post =>
       (if State in Decoding.Cancelled | Decoding.Failed | Decoding.Finalized
        then not Decode_Entry_Allowed'Result);

   --  Encode entry allowed.
   --  @param State See package contract for this parameter.
   --  @return Operation result.
   function Encode_Entry_Allowed
     (State : Encoding.Encoder_State) return Boolean is
     (State in Encoding.Image_Defined | Encoding.Accepting_Metadata | Encoding.Accepting_Input)
     with Post =>
       (if State in Encoding.Cancelled | Encoding.Failed | Encoding.Finalized
        then not Encode_Entry_Allowed'Result);

   --  Metadata total is bounded.
   --  @param Current See package contract for this parameter.
   --  @param Payload See package contract for this parameter.
   --  @param Limit See package contract for this parameter.
   --  @return Operation result.
   function Metadata_Total_Is_Bounded
     (Current : Byte_Count;
      Payload : Byte_Count;
      Limit : Byte_Count) return Boolean is
     (Current <= Limit and then Payload <= Limit - Current)
     with Post =>
       (if Metadata_Total_Is_Bounded'Result then Current + Payload <= Limit);

   --  Metadata segment is bounded.
   --  @param Payload See package contract for this parameter.
   --  @param Segment_Limit See package contract for this parameter.
   --  @return Operation result.
   function Metadata_Segment_Is_Bounded
     (Payload : Byte_Count;
      Segment_Limit : Byte_Count) return Boolean is
     (Payload <= Segment_Limit);

   --  Metadata callback is bounded.
   --  @param Current_Callbacks See package contract for this parameter.
   --  @param Callback_Limit See package contract for this parameter.
   --  @return Operation result.
   function Metadata_Callback_Is_Bounded
     (Current_Callbacks : Natural;
      Callback_Limit : Natural) return Boolean is
     (Current_Callbacks < Callback_Limit)
     with Post =>
       (if Metadata_Callback_Is_Bounded'Result then Current_Callbacks + 1 <= Callback_Limit);

   --  Retains metadata.
   --  @param Policy See package contract for this parameter.
   --  @param Kind See package contract for this parameter.
   --  @param Selected See package contract for this parameter.
   --  @return Operation result.
   function Retains_Metadata
     (Policy : Metadata.Metadata_Policy;
      Kind : Metadata.Metadata_Kind;
      Selected : Metadata.Kind_Set) return Boolean is
     (case Policy is
        when Metadata.Preserve_All_Bounded => True,
        when Metadata.Preserve_Known => Kind /= Metadata.Unknown_APP,
        when Metadata.Preserve_Selected => Selected (Kind),
        when others => False);

   --  Scan header is legal.
   --  @param Mode See package contract for this parameter.
   --  @param Component_Total See package contract for this parameter.
   --  @param Scan_Components See package contract for this parameter.
   --  @param Spectral_Start See package contract for this parameter.
   --  @param Spectral_End See package contract for this parameter.
   --  @param Successive_High See package contract for this parameter.
   --  @param Successive_Low See package contract for this parameter.
   --  @return Operation result.
   function Scan_Header_Is_Legal
     (Mode : Frame_Mode;
      Component_Total : Component_Count;
      Scan_Components : Component_Count;
      Spectral_Start : Spectral_Selection_Index;
      Spectral_End : Spectral_Selection_Index;
      Successive_High : Successive_Approximation_Value;
      Successive_Low : Successive_Approximation_Value) return Boolean is
     (case Mode is
        when Baseline_DCT =>
         Scan_Components <= Component_Total
         and then Spectral_Start = 0
         and then Spectral_End = 63
         and then Successive_High = 0
         and then Successive_Low = 0,
        when Progressive_DCT | Differential_Progressive_DCT =>
         Scan_Components <= Component_Total
         and then Spectral_Start <= Spectral_End
         and then
           ((Spectral_Start = 0 and then Spectral_End = 0)
            or else (Spectral_Start in 1 .. 63 and then Spectral_End in Spectral_Start .. 63)),
        when Lossless | Differential_Lossless =>
         Scan_Components <= Component_Total
         and then Spectral_Start in 1 .. 7
         and then Spectral_End = 0
         and then Successive_High = 0
         and then Successive_Low <= 7,
        when others =>
          False)
     with Post =>
       (if Scan_Header_Is_Legal'Result
        then Scan_Components <= Component_Total and then Spectral_Start <= 63 and then Spectral_End <= 63);

   --  Output span is bounded.
   --  @param Height See package contract for this parameter.
   --  @param Row_Bytes See package contract for this parameter.
   --  @param Stride See package contract for this parameter.
   --  @param Accessible See package contract for this parameter.
   --  @param Limit See package contract for this parameter.
   --  @return Operation result.
   function Output_Span_Is_Bounded
     (Height : Image_Height;
      Row_Bytes : Byte_Count;
     Stride : Row_Stride;
     Accessible : Byte_Count;
     Limit : Byte_Count) return Boolean is
     (Byte_Count (Stride) > 0
      and then Row_Bytes <= Byte_Count (Stride)
      and then Byte_Count (Height - 1) <= Byte_Count'Last / Byte_Count (Stride)
      and then Byte_Count (Stride) * Byte_Count (Height - 1) <= Byte_Count'Last - Row_Bytes
      and then Byte_Count (Stride) * Byte_Count (Height - 1) + Row_Bytes <= Accessible
      and then Accessible <= Limit)
     with Post =>
       (if Output_Span_Is_Bounded'Result then
          Row_Bytes <= Byte_Count (Stride)
          and then Byte_Count (Stride) * Byte_Count (Height - 1) + Row_Bytes <= Limit);
end Jpeglib.Internal.Library_Policy;

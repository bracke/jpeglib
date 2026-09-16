with Jpeglib.Internal.Decoder;
with Jpeglib.Internal.Frames;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Decoding_Support is
   pragma Preelaborate;

   --  Parse known height dnl.
   --  @param Input See package contract for this parameter.
   --  @param Marker_Source See package contract for this parameter.
   --  @param Frame See package contract for this parameter.
   --  @return Operation result.
   function Parse_Known_Height_DNL
     (Input : not null access Streams.Source'Class;
      Marker_Source : Source_Offset;
      Frame : Frames.Frame) return Results.Result;

   --  Infer color model.
   --  @param Frame See package contract for this parameter.
   --  @return Operation result.
   function Infer_Color_Model (Frame : Frames.Frame) return Encoded_Color_Model;
   --  Infer color model.
   --  @param Header_Result See package contract for this parameter.
   --  @return Operation result.
   function Infer_Color_Model (Header_Result : Decoder.Header_Result) return Encoded_Color_Model;

   --  Lossless coefficient blocks.
   --  @param Frame See package contract for this parameter.
   --  @return Operation result.
   function Lossless_Coefficient_Blocks (Frame : Frames.Frame) return Block_Count;
end Jpeglib.Internal.Decoding_Support;

with Jpeglib.Internal.Decoder;
with Jpeglib.Internal.Frames;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Decoding_Support is
   pragma Preelaborate;

   function Parse_Known_Height_DNL
     (Input : not null access Streams.Source'Class;
      Marker_Source : Source_Offset;
      Frame : Frames.Frame) return Results.Result;

   function Infer_Color_Model (Frame : Frames.Frame) return Encoded_Color_Model;
   function Infer_Color_Model (Header_Result : Decoder.Header_Result) return Encoded_Color_Model;

   function Lossless_Coefficient_Blocks (Frame : Frames.Frame) return Block_Count;
end Jpeglib.Internal.Decoding_Support;

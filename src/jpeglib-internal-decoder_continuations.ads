with Jpeglib.Internal.Bit_Streams;
with Jpeglib.Internal.Decoder;
with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Decoder_Continuations is
   pragma Preelaborate;

   type Lossless_Sample_Array is array (Component_Index range <>, Positive range <>) of Integer;

   function Decode_Hierarchical_Lossless_Continuation
     (Header : in out Internal.Decoder.Header_Result;
      Input : not null access Streams.Source'Class;
      Ending : Internal.Bit_Streams.Entropy_Read_Result;
      Samples : access Lossless_Sample_Array := null) return Results.Result;
end Jpeglib.Internal.Decoder_Continuations;

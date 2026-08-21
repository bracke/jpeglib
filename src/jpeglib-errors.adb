package body Jpeglib.Errors is
   function Identifier_For (Code : Error_Code) return String is
   begin
      case Code is
         when No_Error =>
            return "jpeg.ok";
         when Source_Read_Failed =>
            return "jpeg.source.read_failed";
         when Source_Unexpected_EOI =>
            return "jpeg.source.unexpected_eoi";
         when Source_Zero_Progress =>
            return "jpeg.source.zero_progress";
         when Destination_Write_Failed =>
            return "jpeg.destination.write_failed";
         when Marker_Expected =>
            return "jpeg.marker.expected";
         when Marker_Unexpected =>
            return "jpeg.marker.unexpected";
         when Segment_Invalid_Length =>
            return "jpeg.segment.invalid_length";
         when Segment_Boundary_Exceeded =>
            return "jpeg.segment.boundary_exceeded";
         when Table_Invalid_Definition =>
            return "jpeg.table.invalid_definition";
         when Huffman_Invalid_Definition =>
            return "jpeg.huffman.invalid_definition";
         when Frame_Invalid_Definition =>
            return "jpeg.frame.invalid_definition";
         when Scan_Invalid_Definition =>
            return "jpeg.scan.invalid_definition";
         when Entropy_Invalid_Category =>
            return "jpeg.entropy.invalid_category";
         when Entropy_Unexpected_Marker =>
            return "jpeg.entropy.unexpected_marker";
         when Coefficient_Invalid_Encoding =>
            return "jpeg.coefficient.invalid_encoding";
         when Restart_Invalid_State =>
            return "jpeg.restart.invalid_state";
         when Unsupported_Feature =>
            return "jpeg.feature.unsupported";
         when Invalid_State =>
            return "jpeg.state.invalid";
         when Integer_Overflow =>
            return "jpeg.security.integer_overflow";
         when Pixel_Count_Exceeded =>
            return "jpeg.limit.pixel_count_exceeded";
         when Metadata_Limit_Exceeded =>
            return "jpeg.limit.metadata_bytes_exceeded";
         when Output_Limit_Exceeded =>
            return "jpeg.limit.output_bytes_exceeded";
         when Operation_Cancelled =>
            return "jpeg.operation.cancelled";
         when Internal_Invariant_Failed =>
            return "jpeg.internal.invariant_failed";
      end case;
   end Identifier_For;

   function Make (Code : Error_Code; Context : Diagnostic_Context := (others => <>)) return Error is
   begin
      return
        (Code => Code,
         Identifier => Identifiers.To_Bounded_String (Identifier_For (Code)),
         Context => Context);
   end Make;
end Jpeglib.Errors;

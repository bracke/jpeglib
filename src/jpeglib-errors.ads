with Ada.Strings.Bounded;
package Jpeglib.Errors is
   pragma Preelaborate;

   package Identifiers is new Ada.Strings.Bounded.Generic_Bounded_Length (Max => 96);

   type Error_Code is
     (No_Error,
      Source_Read_Failed,
      Source_Unexpected_EOI,
      Source_Zero_Progress,
      Destination_Write_Failed,
      Marker_Expected,
      Marker_Unexpected,
      Segment_Invalid_Length,
      Segment_Boundary_Exceeded,
      Table_Invalid_Definition,
      Huffman_Invalid_Definition,
      Frame_Invalid_Definition,
      Scan_Invalid_Definition,
      Entropy_Invalid_Category,
      Entropy_Unexpected_Marker,
      Coefficient_Invalid_Encoding,
      Restart_Invalid_State,
      Unsupported_Feature,
      Invalid_State,
      Integer_Overflow,
      Pixel_Count_Exceeded,
      Metadata_Limit_Exceeded,
      Output_Limit_Exceeded,
      Operation_Cancelled,
      Internal_Invariant_Failed);

   type Warning_Code is
     (Generic_Warning,
      Compatibility_Issue,
      Recovery_Applied,
      Data_Loss,
      Warnings_Suppressed);

   type Warning_Severity is (Informational, Compatibility, Recovery, Data_Loss);

   type Diagnostic_Context is record
      Source : Source_Offset := 0;
      Destination : Destination_Offset := 0;
      Marker : Marker_Code := 0;
      Frame_Component : Component_Index := Component_Index'First;
      Scan_Component : Component_Index := Component_Index'First;
      Scan : Scan_Number := 0;
      MCU_R : MCU_Row := 0;
      MCU_C : MCU_Column := 0;
      Block : Block_Index := 0;
      Coefficient : Coefficient_Index := 0;
      Detail : Long_Long_Integer := 0;
      Underlying_Code : Long_Long_Integer := 0;
      Has_Underlying_Code : Boolean := False;
   end record;

   type Error is record
      Code : Error_Code := No_Error;
      Identifier : Identifiers.Bounded_String := Identifiers.To_Bounded_String ("jpeg.ok");
      Context : Diagnostic_Context;
   end record;

   type Warning is record
      Code : Warning_Code := Generic_Warning;
      Identifier : Identifiers.Bounded_String := Identifiers.To_Bounded_String ("jpeg.warning");
      Severity : Warning_Severity := Informational;
      Context : Diagnostic_Context;
   end record;

   function Identifier_For (Code : Error_Code) return String;
   function Make (Code : Error_Code; Context : Diagnostic_Context := (others => <>)) return Error;
   function Is_Fatal (Item : Error) return Boolean is (Item.Code /= No_Error);
end Jpeglib.Errors;

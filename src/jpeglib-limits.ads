package Jpeglib.Limits is
   pragma Preelaborate;

   type Limit_Set is record
      Max_Width : Image_Width := 65_535;
      Max_Height : Image_Height := 65_535;
      Max_Pixels : Pixel_Count := 268_435_456;
      Max_Components : Component_Count := 4;
      Max_Markers : Natural := 1_000_000;
      Max_Segments : Natural := 1_000_000;
      Max_Scans : Scan_Number := 4_096;
      Max_Metadata_Segments : Natural := 65_536;
      Max_Metadata_Bytes : Byte_Count := 64 * 1024 * 1024;
      Max_Metadata_Segment_Bytes : Byte_Count := 65_533;
      Max_ICC_Profile_Bytes : Byte_Count := 64 * 1024 * 1024;
      Max_Coefficient_Bytes : Byte_Count := 512 * 1024 * 1024;
      Max_Output_Bytes : Byte_Count := 1024 * 1024 * 1024;
      Max_Allocation_Bytes : Byte_Count := 1024 * 1024 * 1024;
      Max_MCUs : MCU_Count := 2 ** 31 - 1;
      Max_Warning_Records : Natural := 256;
      Max_Metadata_Callbacks : Natural := 65_536;
      Max_Diagnostic_Events : Natural := 4_096;
      Max_Recovery_Attempts : Natural := 64;
      Max_Restart_Resync_Bytes : Byte_Count := 1 * 1024 * 1024;
      Max_Progressive_Scan_Work : MCU_Count := 2 ** 40;
   end record;

   Default_Limits : constant Limit_Set := (others => <>);
end Jpeglib.Limits;

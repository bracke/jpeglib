with Jpeglib.Results;
with Jpeglib.Streams;

package Jpeglib.Internal.Markers is
   pragma Preelaborate;

   SOF0 : constant Marker_Code := 16#C0#;
   SOF1 : constant Marker_Code := 16#C1#;
   SOF2 : constant Marker_Code := 16#C2#;
   SOF3 : constant Marker_Code := 16#C3#;
   DHT : constant Marker_Code := 16#C4#;
   SOF5 : constant Marker_Code := 16#C5#;
   SOF6 : constant Marker_Code := 16#C6#;
   SOF7 : constant Marker_Code := 16#C7#;
   JPG : constant Marker_Code := 16#C8#;
   SOF9 : constant Marker_Code := 16#C9#;
   SOF10 : constant Marker_Code := 16#CA#;
   SOF11 : constant Marker_Code := 16#CB#;
   DAC : constant Marker_Code := 16#CC#;
   SOF13 : constant Marker_Code := 16#CD#;
   SOF14 : constant Marker_Code := 16#CE#;
   SOF15 : constant Marker_Code := 16#CF#;

   RST0 : constant Marker_Code := 16#D0#;
   RST1 : constant Marker_Code := 16#D1#;
   RST2 : constant Marker_Code := 16#D2#;
   RST3 : constant Marker_Code := 16#D3#;
   RST4 : constant Marker_Code := 16#D4#;
   RST5 : constant Marker_Code := 16#D5#;
   RST6 : constant Marker_Code := 16#D6#;
   RST7 : constant Marker_Code := 16#D7#;
   SOI : constant Marker_Code := 16#D8#;
   EOI : constant Marker_Code := 16#D9#;
   SOS : constant Marker_Code := 16#DA#;
   DQT : constant Marker_Code := 16#DB#;
   DNL : constant Marker_Code := 16#DC#;
   DRI : constant Marker_Code := 16#DD#;
   DHP : constant Marker_Code := 16#DE#;
   EXP : constant Marker_Code := 16#DF#;

   APP0 : constant Marker_Code := 16#E0#;
   APP1 : constant Marker_Code := 16#E1#;
   APP2 : constant Marker_Code := 16#E2#;
   APP13 : constant Marker_Code := 16#ED#;
   APP14 : constant Marker_Code := 16#EE#;
   APP15 : constant Marker_Code := 16#EF#;
   JPG0 : constant Marker_Code := 16#F0#;
   JPG13 : constant Marker_Code := 16#FD#;
   COM : constant Marker_Code := 16#FE#;
   TEM : constant Marker_Code := 16#01#;

   function Is_Restart (Marker : Marker_Code) return Boolean is (Marker in RST0 .. RST7)
     with SPARK_Mode => On;
   function Restart_Number (Marker : Marker_Code) return Natural
     with Pre => Is_Restart (Marker),
          Post => Restart_Number'Result <= 7,
          SPARK_Mode => On;

   function Is_APP (Marker : Marker_Code) return Boolean is (Marker in APP0 .. APP15)
     with SPARK_Mode => On;
   function Is_JPG_Extension (Marker : Marker_Code) return Boolean is (Marker in JPG0 .. JPG13)
     with SPARK_Mode => On;
   function Is_Frame (Marker : Marker_Code) return Boolean
     with SPARK_Mode => On;
   function Is_Standalone (Marker : Marker_Code) return Boolean
     with SPARK_Mode => On;
   function Has_Length (Marker : Marker_Code) return Boolean
     with SPARK_Mode => On;
   function Is_Reserved (Marker : Marker_Code) return Boolean
     with SPARK_Mode => On;

   type Marker_Result is record
      Outcome : Results.Result := Results.Success;
      Source : Source_Offset := 0;
      Marker : Marker_Code := 0;
   end record;

   function Read_Next (Input : in out Streams.Source'Class) return Marker_Result;
end Jpeglib.Internal.Markers;

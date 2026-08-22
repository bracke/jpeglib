with Jpeglib.Errors;
with Jpeglib.Internal.Colors;

package body Jpeglib.Internal.Encoder_Planes is
   function Ceiling_Divide (Dividend, Divisor : Natural) return Natural is
   begin
      return (Dividend + Divisor - 1) / Divisor;
   end Ceiling_Divide;

   function Plane_Sample_Count (Width : Image_Width; Height : Image_Height) return Byte_Count is
   begin
      return Byte_Count (Width) * Byte_Count (Height);
   end Plane_Sample_Count;

   function Fits_Positive_Range (Count : Byte_Count) return Boolean is
   begin
      return Count > 0 and then Count <= Byte_Count (Positive'Last);
   end Fits_Positive_Range;

   function Pad_Plane
     (Source : Streams.Byte_Array;
      Source_Width : Image_Width;
      Source_Height : Image_Height;
      Target_Width : Image_Width;
      Target_Height : Image_Height;
      Target : in out Streams.Byte_Array) return Results.Result
   is
      Source_Needed : constant Byte_Count := Plane_Sample_Count (Source_Width, Source_Height);
      Target_Needed : constant Byte_Count := Plane_Sample_Count (Target_Width, Target_Height);
      Source_Row : Natural;
      Source_Column : Natural;
      Source_Index : Positive;
      Target_Index : Positive;
   begin
      if Byte_Count (Source'Length) < Source_Needed or else Byte_Count (Target'Length) < Target_Needed then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      for Row in 0 .. Natural (Target_Height) - 1 loop
         Source_Row := Natural'Min (Row, Natural (Source_Height) - 1);
         for Column in 0 .. Natural (Target_Width) - 1 loop
            Source_Column := Natural'Min (Column, Natural (Source_Width) - 1);
            Source_Index := Source'First + Source_Row * Natural (Source_Width) + Source_Column;
            Target_Index := Target'First + Row * Natural (Target_Width) + Column;
            Target (Target_Index) := Source (Source_Index);
         end loop;
      end loop;

      return Results.Success;
   end Pad_Plane;

   function Fill_CMYK_Planes
     (Input : Images.Image_View;
      C_Plane : in out Streams.Byte_Array;
      M_Plane : in out Streams.Byte_Array;
      Y_Plane : in out Streams.Byte_Array;
      K_Plane : in out Streams.Byte_Array;
      YCCK : Boolean) return Image_Blocks.Plane_Result
   is
      Needed : constant Byte_Count := Plane_Sample_Count (Input.Descriptor.Width, Input.Descriptor.Height);
      Index : Positive;
      Sample : Colors.CMYK_Sample;
      Offset : Natural := 0;
      Written : Natural;
   begin
      if Byte_Count (C_Plane'Length) < Needed
        or else Byte_Count (M_Plane'Length) < Needed
        or else Byte_Count (Y_Plane'Length) < Needed
        or else Byte_Count (K_Plane'Length) < Needed
      then
         return (Outcome => Results.Failure (Errors.Output_Limit_Exceeded), Samples_Written => 0);
      end if;

      for Row in 0 .. Natural (Input.Descriptor.Height) - 1 loop
         Colors.Convert_CMYK_Row_To_CMYK_Planes
           (Input,
            Row,
            C_Plane,
            M_Plane,
            Y_Plane,
            K_Plane,
            Offset,
            Natural (Input.Descriptor.Width),
            YCCK,
            Written);

         if Written /= Natural (Input.Descriptor.Width) then
            for Column in 0 .. Natural (Input.Descriptor.Width) - 1 loop
               Index := C_Plane'First + Row * Natural (Input.Descriptor.Width) + Column;
               Sample :=
                 (if YCCK
                  then Colors.Read_YCCK (Input, Column, Row)
                  else Colors.Read_CMYK (Input, Column, Row));
               C_Plane (Index) := Sample.C;
               M_Plane (Index) := Sample.M;
               Y_Plane (Index) := Sample.Y;
               K_Plane (Index) := Sample.K;
            end loop;
         end if;

         Offset := Offset + Natural (Input.Descriptor.Width);
      end loop;

      return (Outcome => Results.Success, Samples_Written => Needed);
   end Fill_CMYK_Planes;
end Jpeglib.Internal.Encoder_Planes;

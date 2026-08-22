with Ada.Command_Line;
with Ada.Text_IO;

with Hostkit.Host;

with Jpeglib.Capabilities;
with Jpeglib.Errors;
with Jpeglib.Images;
with Jpeglib.Internal.Colors;
with Jpeglib.Streams;

with Jpeglib_Tools;

procedure Jpeglib_SIMD_Matrix is
   use type Jpeglib.Images.Pixel_Format;
   use type Jpeglib.Internal.Colors.Acceleration_Profile;
   use type Jpeglib.Streams.Byte_Array;

   Width : constant Jpeglib.Image_Width := 31;
   Height : constant Jpeglib.Image_Height := 5;
   Max_Input_Bytes : constant Natural := Natural (Width) * Natural (Height) * 4;
   Plane_Bytes : constant Natural := Natural (Width) * Natural (Height);

   Input_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. Max_Input_Bytes => 0];
   Y_Plane : aliased Jpeglib.Streams.Byte_Array := [1 .. Plane_Bytes => 0];
   Cb_Plane : aliased Jpeglib.Streams.Byte_Array := [1 .. Plane_Bytes => 0];
   Cr_Plane : aliased Jpeglib.Streams.Byte_Array := [1 .. Plane_Bytes => 0];
   Expected_Y : aliased Jpeglib.Streams.Byte_Array := [1 .. Plane_Bytes => 0];
   Expected_Cb : aliased Jpeglib.Streams.Byte_Array := [1 .. Plane_Bytes => 0];
   Expected_Cr : aliased Jpeglib.Streams.Byte_Array := [1 .. Plane_Bytes => 0];
   Failures : Natural := 0;

   procedure Fail (Message : String) is
   begin
      Failures := Failures + 1;
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "jpeglib_simd_matrix: " & Message);
   end Fail;

   function Bytes_Per_Pixel (Format : Jpeglib.Images.Pixel_Format) return Natural is
     (Natural (Jpeglib.Images.Bytes_Per_Pixel (Format)));

   procedure Fill_Input (Format : Jpeglib.Images.Pixel_Format) is
      Step : constant Natural := Bytes_Per_Pixel (Format);
      Cursor : Positive;
      R : Jpeglib.Byte;
      G : Jpeglib.Byte;
      B : Jpeglib.Byte;
   begin
      Input_Storage := [others => 0];
      for Row in 0 .. Natural (Height) - 1 loop
         for Column in 0 .. Natural (Width) - 1 loop
            Cursor := Input_Storage'First + (Row * Natural (Width) + Column) * Step;
            R := Jpeglib.Byte ((Row * 17 + Column * 11 + 3) mod 256);
            G := Jpeglib.Byte ((Row * 7 + Column * 23 + 91) mod 256);
            B := Jpeglib.Byte ((Row * 29 + Column * 5 + 177) mod 256);
            case Format is
               when Jpeglib.Images.RGB_24 =>
                  Input_Storage (Cursor) := R;
                  Input_Storage (Cursor + 1) := G;
                  Input_Storage (Cursor + 2) := B;
               when Jpeglib.Images.BGR_24 =>
                  Input_Storage (Cursor) := B;
                  Input_Storage (Cursor + 1) := G;
                  Input_Storage (Cursor + 2) := R;
               when Jpeglib.Images.RGBA_32 =>
                  Input_Storage (Cursor) := R;
                  Input_Storage (Cursor + 1) := G;
                  Input_Storage (Cursor + 2) := B;
                  Input_Storage (Cursor + 3) := Jpeglib.Byte ((Row + Column) mod 256);
               when Jpeglib.Images.BGRA_32 =>
                  Input_Storage (Cursor) := B;
                  Input_Storage (Cursor + 1) := G;
                  Input_Storage (Cursor + 2) := R;
                  Input_Storage (Cursor + 3) := Jpeglib.Byte ((Row + Column) mod 256);
               when others =>
                  null;
            end case;
         end loop;
      end loop;
   end Fill_Input;

   function View (Format : Jpeglib.Images.Pixel_Format) return Jpeglib.Images.Image_View is
      Step : constant Natural := Bytes_Per_Pixel (Format);
   begin
      return
        (Descriptor =>
           (Width => Width,
            Height => Height,
            Format => Format,
            Stride => Jpeglib.Row_Stride (Natural (Width) * Step),
            Accessible_Bytes => Jpeglib.Byte_Count (Natural (Width) * Natural (Height) * Step)),
         Storage => Input_Storage'Unchecked_Access);
   end View;

   procedure Build_Expected (Input : Jpeglib.Images.Image_View) is
      Offset : Natural := 0;
      RGB : Jpeglib.Internal.Colors.RGB_Sample;
      YCbCr : Jpeglib.Internal.Colors.YCbCr_Sample;
   begin
      Expected_Y := [others => 0];
      Expected_Cb := [others => 0];
      Expected_Cr := [others => 0];
      for Row in 0 .. Natural (Height) - 1 loop
         for Column in 0 .. Natural (Width) - 1 loop
            RGB := Jpeglib.Internal.Colors.Read_RGB (Input, Column, Row);
            YCbCr := Jpeglib.Internal.Colors.Convert_RGB_To_YCbCr (RGB);
            Expected_Y (Expected_Y'First + Offset) := YCbCr.Y;
            Expected_Cb (Expected_Cb'First + Offset) := YCbCr.Cb;
            Expected_Cr (Expected_Cr'First + Offset) := YCbCr.Cr;
            Offset := Offset + 1;
         end loop;
      end loop;
   end Build_Expected;

   procedure Run_Format (Format : Jpeglib.Images.Pixel_Format) is
      Input : Jpeglib.Images.Image_View;
      Written : Natural;
      Offset : Natural := 0;
   begin
      Fill_Input (Format);
      Input := View (Format);
      Build_Expected (Input);
      Y_Plane := [others => 0];
      Cb_Plane := [others => 0];
      Cr_Plane := [others => 0];

      for Row in 0 .. Natural (Height) - 1 loop
         Jpeglib.Internal.Colors.Convert_RGB_Row_To_YCbCr_Planes
           (Input,
            Row,
            Y_Plane,
            Cb_Plane,
            Cr_Plane,
            Offset,
            Natural (Width),
            Written);
         if Written /= Natural (Width) then
            Fail (Jpeglib.Images.Pixel_Format'Image (Format) & " row conversion wrote wrong count");
         end if;
         Offset := Offset + Written;
      end loop;

      if Y_Plane /= Expected_Y then
         Fail (Jpeglib.Images.Pixel_Format'Image (Format) & " Y plane differs from scalar reference");
      end if;
      if Cb_Plane /= Expected_Cb then
         Fail (Jpeglib.Images.Pixel_Format'Image (Format) & " Cb plane differs from scalar reference");
      end if;
      if Cr_Plane /= Expected_Cr then
         Fail (Jpeglib.Images.Pixel_Format'Image (Format) & " Cr plane differs from scalar reference");
      end if;
   end Run_Format;
begin
   if not Jpeglib.Capabilities.SIMD_Acceleration then
      Fail ("SIMD acceleration capability is not advertised");
   end if;

   if Jpeglib.Internal.Colors.Active_Acceleration /= Jpeglib.Internal.Colors.Compiler_Vectorized_SIMD then
      Fail ("compiler-vectorized SIMD profile is not active");
   end if;

   Run_Format (Jpeglib.Images.RGB_24);
   Run_Format (Jpeglib.Images.BGR_24);
   Run_Format (Jpeglib.Images.RGBA_32);
   Run_Format (Jpeglib.Images.BGRA_32);

   Ada.Text_IO.Put_Line
     ("jpeglib_simd_matrix: host="
      & Hostkit.Host.Kind'Image (Hostkit.Host.Current)
      & " machine="
      & Hostkit.Host.Machine_Name
      & " acceleration="
      & Jpeglib.Internal.Colors.Acceleration_Profile'Image (Jpeglib.Internal.Colors.Active_Acceleration));

   if Failures = 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Test_Failure)));
   end if;
exception
   when Constraint_Error =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "jpeglib_simd_matrix: " & Jpeglib.Errors.Error_Code'Image (Jpeglib.Errors.Internal_Invariant_Failed));
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Jpeglib_Tools.Code (Jpeglib_Tools.Test_Failure)));
end Jpeglib_SIMD_Matrix;

with Ada.Command_Line;
with Ada.Text_IO;

with Hostkit.Host;

with Jpeglib.Capabilities;
with Jpeglib.Errors;
with Jpeglib.Images;
with Jpeglib.Internal.Colors;
with Jpeglib.Internal.Image_Blocks;
with Jpeglib.Results;
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
   Output_Storage : aliased Jpeglib.Streams.Byte_Array := [1 .. Max_Input_Bytes => 0];
   Expected_Output : aliased Jpeglib.Streams.Byte_Array := [1 .. Max_Input_Bytes => 0];
   Y_Plane : aliased Jpeglib.Streams.Byte_Array := [1 .. Plane_Bytes => 0];
   Cb_Plane : aliased Jpeglib.Streams.Byte_Array := [1 .. Plane_Bytes => 0];
   Cr_Plane : aliased Jpeglib.Streams.Byte_Array := [1 .. Plane_Bytes => 0];
   K_Plane : aliased Jpeglib.Streams.Byte_Array := [1 .. Plane_Bytes => 0];
   Expected_Y : aliased Jpeglib.Streams.Byte_Array := [1 .. Plane_Bytes => 0];
   Expected_Cb : aliased Jpeglib.Streams.Byte_Array := [1 .. Plane_Bytes => 0];
   Expected_Cr : aliased Jpeglib.Streams.Byte_Array := [1 .. Plane_Bytes => 0];
   Expected_K : aliased Jpeglib.Streams.Byte_Array := [1 .. Plane_Bytes => 0];
   Expected_Alpha : aliased Jpeglib.Streams.Byte_Array := [1 .. Plane_Bytes => 0];
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
      K : Jpeglib.Byte;
   begin
      Input_Storage := [others => 0];
      for Row in 0 .. Natural (Height) - 1 loop
         for Column in 0 .. Natural (Width) - 1 loop
            Cursor := Input_Storage'First + (Row * Natural (Width) + Column) * Step;
            R := Jpeglib.Byte ((Row * 17 + Column * 11 + 3) mod 256);
            G := Jpeglib.Byte ((Row * 7 + Column * 23 + 91) mod 256);
            B := Jpeglib.Byte ((Row * 29 + Column * 5 + 177) mod 256);
            K := Jpeglib.Byte ((Row * 13 + Column * 31 + 59) mod 256);
            case Format is
               when Jpeglib.Images.Gray_8 =>
                  Input_Storage (Cursor) := R;
               when Jpeglib.Images.Gray_Alpha_16 =>
                  Input_Storage (Cursor) := R;
                  Input_Storage (Cursor + 1) := K;
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
               when Jpeglib.Images.CMYK_32 | Jpeglib.Images.YCCK_32 =>
                  Input_Storage (Cursor) := R;
                  Input_Storage (Cursor + 1) := G;
                  Input_Storage (Cursor + 2) := B;
                  Input_Storage (Cursor + 3) := K;
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

   function Output_View
     (Format : Jpeglib.Images.Pixel_Format;
      Storage : access Jpeglib.Streams.Byte_Array) return Jpeglib.Images.Mutable_Image_View
   is
      Step : constant Natural := Bytes_Per_Pixel (Format);
   begin
      return
        (Descriptor =>
           (Width => Width,
            Height => Height,
            Format => Format,
            Stride => Jpeglib.Row_Stride (Natural (Width) * Step),
            Accessible_Bytes => Jpeglib.Byte_Count (Natural (Width) * Natural (Height) * Step)),
         Storage => Storage);
   end Output_View;

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

   procedure Build_Expected_CMYK_Input (Input : Jpeglib.Images.Image_View; YCCK : Boolean) is
      Offset : Natural := 0;
      Sample : Jpeglib.Internal.Colors.CMYK_Sample;
   begin
      Expected_Y := [others => 0];
      Expected_Cb := [others => 0];
      Expected_Cr := [others => 0];
      Expected_K := [others => 0];
      for Row in 0 .. Natural (Height) - 1 loop
         for Column in 0 .. Natural (Width) - 1 loop
            Sample :=
              (if YCCK
               then Jpeglib.Internal.Colors.Read_YCCK (Input, Column, Row)
               else Jpeglib.Internal.Colors.Read_CMYK (Input, Column, Row));
            Expected_Y (Expected_Y'First + Offset) := Sample.C;
            Expected_Cb (Expected_Cb'First + Offset) := Sample.M;
            Expected_Cr (Expected_Cr'First + Offset) := Sample.Y;
            Expected_K (Expected_K'First + Offset) := Sample.K;
            Offset := Offset + 1;
         end loop;
      end loop;
   end Build_Expected_CMYK_Input;

   procedure Build_Expected_Gray_Alpha_Input (Input : Jpeglib.Images.Image_View) is
      Offset : Natural := 0;
      Base : Positive;
   begin
      Expected_Y := [others => 0];
      Expected_Alpha := [others => 0];
      for Row in 0 .. Natural (Height) - 1 loop
         for Column in 0 .. Natural (Width) - 1 loop
            Base :=
              Input.Storage'First
              + Row * Natural (Input.Descriptor.Stride)
              + Column * 2;
            Expected_Y (Expected_Y'First + Offset) := Input.Storage (Base);
            Expected_Alpha (Expected_Alpha'First + Offset) := Input.Storage (Base + 1);
            Offset := Offset + 1;
         end loop;
      end loop;
   end Build_Expected_Gray_Alpha_Input;

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

   procedure Run_CMYK_Input_Format (Format : Jpeglib.Images.Pixel_Format; YCCK : Boolean) is
      Input : Jpeglib.Images.Image_View;
      Written : Natural;
      Offset : Natural := 0;
      Label : constant String :=
        (if YCCK then " YCCK input row conversion" else " CMYK input row conversion");
   begin
      Fill_Input (Format);
      Input := View (Format);
      Build_Expected_CMYK_Input (Input, YCCK);
      Y_Plane := [others => 0];
      Cb_Plane := [others => 0];
      Cr_Plane := [others => 0];
      K_Plane := [others => 0];

      for Row in 0 .. Natural (Height) - 1 loop
         Jpeglib.Internal.Colors.Convert_CMYK_Row_To_CMYK_Planes
           (Input,
            Row,
            Y_Plane,
            Cb_Plane,
            Cr_Plane,
            K_Plane,
            Offset,
            Natural (Width),
            YCCK,
            Written);
         if Written /= Natural (Width) then
            Fail (Jpeglib.Images.Pixel_Format'Image (Format) & Label & " wrote wrong count");
         end if;
         Offset := Offset + Written;
      end loop;

      if Y_Plane /= Expected_Y then
         Fail (Jpeglib.Images.Pixel_Format'Image (Format) & Label & " C plane differs from scalar reference");
      end if;
      if Cb_Plane /= Expected_Cb then
         Fail (Jpeglib.Images.Pixel_Format'Image (Format) & Label & " M plane differs from scalar reference");
      end if;
      if Cr_Plane /= Expected_Cr then
         Fail (Jpeglib.Images.Pixel_Format'Image (Format) & Label & " Y plane differs from scalar reference");
      end if;
      if K_Plane /= Expected_K then
         Fail (Jpeglib.Images.Pixel_Format'Image (Format) & Label & " K plane differs from scalar reference");
      end if;
   end Run_CMYK_Input_Format;

   procedure Run_Gray_Alpha_Input_Format is
      Input : Jpeglib.Images.Image_View;
      Written : Natural;
      Offset : Natural := 0;
   begin
      Fill_Input (Jpeglib.Images.Gray_Alpha_16);
      Input := View (Jpeglib.Images.Gray_Alpha_16);
      Build_Expected_Gray_Alpha_Input (Input);
      Y_Plane := [others => 0];
      K_Plane := [others => 0];

      for Row in 0 .. Natural (Height) - 1 loop
         Jpeglib.Internal.Colors.Convert_Gray_Alpha_Row_To_Planes
           (Input,
            Row,
            Y_Plane,
            K_Plane,
            Offset,
            Natural (Width),
            Written);
         if Written /= Natural (Width) then
            Fail ("GRAY_ALPHA_16 gray-alpha input row conversion wrote wrong count");
         end if;
         Offset := Offset + Written;
      end loop;

      if Y_Plane /= Expected_Y then
         Fail ("GRAY_ALPHA_16 gray plane differs from scalar reference");
      end if;
      if K_Plane /= Expected_Alpha then
         Fail ("GRAY_ALPHA_16 alpha plane differs from scalar reference");
      end if;
   end Run_Gray_Alpha_Input_Format;

   procedure Fill_YCbCr_Planes is
      Offset : Natural := 0;
   begin
      for Row in 0 .. Natural (Height) - 1 loop
         for Column in 0 .. Natural (Width) - 1 loop
            Y_Plane (Y_Plane'First + Offset) := Jpeglib.Byte ((Row * 19 + Column * 13 + 41) mod 256);
            Cb_Plane (Cb_Plane'First + Offset) := Jpeglib.Byte ((Row * 5 + Column * 29 + 97) mod 256);
            Cr_Plane (Cr_Plane'First + Offset) := Jpeglib.Byte ((Row * 31 + Column * 7 + 149) mod 256);
            K_Plane (K_Plane'First + Offset) := Jpeglib.Byte ((Row * 11 + Column * 37 + 211) mod 256);
            Offset := Offset + 1;
         end loop;
      end loop;
   end Fill_YCbCr_Planes;

   procedure Build_Expected_Output (Output : in out Jpeglib.Images.Mutable_Image_View) is
      Offset : Natural := 0;
   begin
      for Row in 0 .. Natural (Height) - 1 loop
         for Column in 0 .. Natural (Width) - 1 loop
            Jpeglib.Internal.Colors.Write_YCbCr
              (Output,
               Column,
               Row,
               Y_Plane (Y_Plane'First + Offset),
               Cb_Plane (Cb_Plane'First + Offset),
               Cr_Plane (Cr_Plane'First + Offset),
               Alpha => 213);
            Offset := Offset + 1;
         end loop;
      end loop;
   end Build_Expected_Output;

   procedure Build_Expected_RGB_Output (Output : in out Jpeglib.Images.Mutable_Image_View) is
      Offset : Natural := 0;
   begin
      for Row in 0 .. Natural (Height) - 1 loop
         for Column in 0 .. Natural (Width) - 1 loop
            Jpeglib.Internal.Colors.Write_RGB
              (Output,
               Column,
               Row,
               Y_Plane (Y_Plane'First + Offset),
               Cb_Plane (Cb_Plane'First + Offset),
               Cr_Plane (Cr_Plane'First + Offset),
               Alpha => 213);
            Offset := Offset + 1;
         end loop;
      end loop;
   end Build_Expected_RGB_Output;

   procedure Build_Expected_Gray_Output (Output : in out Jpeglib.Images.Mutable_Image_View) is
      Offset : Natural := 0;
   begin
      for Row in 0 .. Natural (Height) - 1 loop
         for Column in 0 .. Natural (Width) - 1 loop
            Jpeglib.Internal.Colors.Write_Gray
              (Output,
               Column,
               Row,
               Y_Plane (Y_Plane'First + Offset),
               Alpha => 213);
            Offset := Offset + 1;
         end loop;
      end loop;
   end Build_Expected_Gray_Output;

   procedure Build_Expected_Gray_Alpha_Output (Output : in out Jpeglib.Images.Mutable_Image_View) is
      Offset : Natural := 0;
   begin
      for Row in 0 .. Natural (Height) - 1 loop
         for Column in 0 .. Natural (Width) - 1 loop
            Jpeglib.Internal.Colors.Write_Gray_Alpha
              (Output,
               Column,
               Row,
               Y_Plane (Y_Plane'First + Offset),
               Cb_Plane (Cb_Plane'First + Offset));
            Offset := Offset + 1;
         end loop;
      end loop;
   end Build_Expected_Gray_Alpha_Output;

   procedure Build_Expected_CMYK_Output (Output : in out Jpeglib.Images.Mutable_Image_View) is
      Offset : Natural := 0;
   begin
      for Row in 0 .. Natural (Height) - 1 loop
         for Column in 0 .. Natural (Width) - 1 loop
            Jpeglib.Internal.Colors.Write_CMYK
              (Output,
               Column,
               Row,
               Y_Plane (Y_Plane'First + Offset),
               Cb_Plane (Cb_Plane'First + Offset),
               Cr_Plane (Cr_Plane'First + Offset),
               K_Plane (K_Plane'First + Offset),
               Alpha => 213);
            Offset := Offset + 1;
         end loop;
      end loop;
   end Build_Expected_CMYK_Output;

   procedure Build_Expected_YCCK_Output (Output : in out Jpeglib.Images.Mutable_Image_View) is
      Offset : Natural := 0;
   begin
      for Row in 0 .. Natural (Height) - 1 loop
         for Column in 0 .. Natural (Width) - 1 loop
            Jpeglib.Internal.Colors.Write_YCCK
              (Output,
               Column,
               Row,
               Y_Plane (Y_Plane'First + Offset),
               Cb_Plane (Cb_Plane'First + Offset),
               Cr_Plane (Cr_Plane'First + Offset),
               K_Plane (K_Plane'First + Offset),
               Alpha => 213);
            Offset := Offset + 1;
         end loop;
      end loop;
   end Build_Expected_YCCK_Output;

   procedure Run_Output_Format (Format : Jpeglib.Images.Pixel_Format) is
      Output : Jpeglib.Images.Mutable_Image_View := Output_View (Format, Output_Storage'Unchecked_Access);
      Expected : Jpeglib.Images.Mutable_Image_View := Output_View (Format, Expected_Output'Unchecked_Access);
      Written : Natural;
      Offset : Natural := 0;
      Used_Bytes : constant Natural := Natural (Width) * Natural (Height) * Bytes_Per_Pixel (Format);
   begin
      Fill_YCbCr_Planes;
      Output_Storage := [others => 0];
      Expected_Output := [others => 0];
      Build_Expected_Output (Expected);

      for Row in 0 .. Natural (Height) - 1 loop
         Jpeglib.Internal.Colors.Write_YCbCr_Row
           (Output,
            Row,
            Y_Plane,
            Cb_Plane,
            Cr_Plane,
            Offset,
            Natural (Width),
            Alpha => 213,
            Written => Written);
         if Written /= Natural (Width) then
            Fail (Jpeglib.Images.Pixel_Format'Image (Format) & " output row wrote wrong count");
         end if;
         Offset := Offset + Written;
      end loop;

      if Output_Storage (1 .. Used_Bytes) /= Expected_Output (1 .. Used_Bytes) then
         Fail (Jpeglib.Images.Pixel_Format'Image (Format) & " output row differs from scalar reference");
      end if;
   end Run_Output_Format;

   procedure Run_RGB_Output_Format (Format : Jpeglib.Images.Pixel_Format) is
      Output : Jpeglib.Images.Mutable_Image_View := Output_View (Format, Output_Storage'Unchecked_Access);
      Expected : Jpeglib.Images.Mutable_Image_View := Output_View (Format, Expected_Output'Unchecked_Access);
      Written : Natural;
      Offset : Natural := 0;
      Used_Bytes : constant Natural := Natural (Width) * Natural (Height) * Bytes_Per_Pixel (Format);
   begin
      Fill_YCbCr_Planes;
      Output_Storage := [others => 0];
      Expected_Output := [others => 0];
      Build_Expected_RGB_Output (Expected);

      for Row in 0 .. Natural (Height) - 1 loop
         Jpeglib.Internal.Colors.Write_RGB_Row
           (Output,
            Row,
            Y_Plane,
            Cb_Plane,
            Cr_Plane,
            Offset,
            Natural (Width),
            Alpha => 213,
            Written => Written);
         if Written /= Natural (Width) then
            Fail (Jpeglib.Images.Pixel_Format'Image (Format) & " RGB output row wrote wrong count");
         end if;
         Offset := Offset + Written;
      end loop;

      if Output_Storage (1 .. Used_Bytes) /= Expected_Output (1 .. Used_Bytes) then
         Fail (Jpeglib.Images.Pixel_Format'Image (Format) & " RGB output row differs from scalar reference");
      end if;
   end Run_RGB_Output_Format;

   procedure Run_Gray_Output_Format (Format : Jpeglib.Images.Pixel_Format) is
      Output : Jpeglib.Images.Mutable_Image_View := Output_View (Format, Output_Storage'Unchecked_Access);
      Expected : Jpeglib.Images.Mutable_Image_View := Output_View (Format, Expected_Output'Unchecked_Access);
      Written : Natural;
      Offset : Natural := 0;
      Used_Bytes : constant Natural := Natural (Width) * Natural (Height) * Bytes_Per_Pixel (Format);
   begin
      Fill_YCbCr_Planes;
      Output_Storage := [others => 0];
      Expected_Output := [others => 0];
      Build_Expected_Gray_Output (Expected);

      for Row in 0 .. Natural (Height) - 1 loop
         Jpeglib.Internal.Colors.Write_Gray_Row
           (Output,
            Row,
            Y_Plane,
            Offset,
            Natural (Width),
            Alpha => 213,
            Written => Written);
         if Written /= Natural (Width) then
            Fail (Jpeglib.Images.Pixel_Format'Image (Format) & " gray output row wrote wrong count");
         end if;
         Offset := Offset + Written;
      end loop;

      if Output_Storage (1 .. Used_Bytes) /= Expected_Output (1 .. Used_Bytes) then
         Fail (Jpeglib.Images.Pixel_Format'Image (Format) & " gray output row differs from scalar reference");
      end if;
   end Run_Gray_Output_Format;

   procedure Run_Gray_Alpha_Output_Format (Format : Jpeglib.Images.Pixel_Format) is
      Output : Jpeglib.Images.Mutable_Image_View := Output_View (Format, Output_Storage'Unchecked_Access);
      Expected : Jpeglib.Images.Mutable_Image_View := Output_View (Format, Expected_Output'Unchecked_Access);
      Written : Natural;
      Offset : Natural := 0;
      Used_Bytes : constant Natural := Natural (Width) * Natural (Height) * Bytes_Per_Pixel (Format);
   begin
      Fill_YCbCr_Planes;
      Output_Storage := [others => 0];
      Expected_Output := [others => 0];
      Build_Expected_Gray_Alpha_Output (Expected);

      for Row in 0 .. Natural (Height) - 1 loop
         Jpeglib.Internal.Colors.Write_Gray_Alpha_Row
           (Output,
            Row,
            Y_Plane,
            Cb_Plane,
            Offset,
            Natural (Width),
            Written);
         if Written /= Natural (Width) then
            Fail (Jpeglib.Images.Pixel_Format'Image (Format) & " gray-alpha output row wrote wrong count");
         end if;
         Offset := Offset + Written;
      end loop;

      if Output_Storage (1 .. Used_Bytes) /= Expected_Output (1 .. Used_Bytes) then
         Fail (Jpeglib.Images.Pixel_Format'Image (Format) & " gray-alpha output row differs from scalar reference");
      end if;
   end Run_Gray_Alpha_Output_Format;

   procedure Run_CMYK_Output_Format (Format : Jpeglib.Images.Pixel_Format) is
      Output : Jpeglib.Images.Mutable_Image_View := Output_View (Format, Output_Storage'Unchecked_Access);
      Expected : Jpeglib.Images.Mutable_Image_View := Output_View (Format, Expected_Output'Unchecked_Access);
      Written : Natural;
      Offset : Natural := 0;
      Used_Bytes : constant Natural := Natural (Width) * Natural (Height) * Bytes_Per_Pixel (Format);
   begin
      Fill_YCbCr_Planes;
      Output_Storage := [others => 0];
      Expected_Output := [others => 0];
      Build_Expected_CMYK_Output (Expected);

      for Row in 0 .. Natural (Height) - 1 loop
         Jpeglib.Internal.Colors.Write_CMYK_Row
           (Output,
            Row,
            Y_Plane,
            Cb_Plane,
            Cr_Plane,
            K_Plane,
            Offset,
            Natural (Width),
            Alpha => 213,
            Written => Written);
         if Written /= Natural (Width) then
            Fail (Jpeglib.Images.Pixel_Format'Image (Format) & " CMYK output row wrote wrong count");
         end if;
         Offset := Offset + Written;
      end loop;

      if Output_Storage (1 .. Used_Bytes) /= Expected_Output (1 .. Used_Bytes) then
         Fail (Jpeglib.Images.Pixel_Format'Image (Format) & " CMYK output row differs from scalar reference");
      end if;
   end Run_CMYK_Output_Format;

   procedure Run_YCCK_Output_Format (Format : Jpeglib.Images.Pixel_Format) is
      Output : Jpeglib.Images.Mutable_Image_View := Output_View (Format, Output_Storage'Unchecked_Access);
      Expected : Jpeglib.Images.Mutable_Image_View := Output_View (Format, Expected_Output'Unchecked_Access);
      Written : Natural;
      Offset : Natural := 0;
      Used_Bytes : constant Natural := Natural (Width) * Natural (Height) * Bytes_Per_Pixel (Format);
   begin
      Fill_YCbCr_Planes;
      Output_Storage := [others => 0];
      Expected_Output := [others => 0];
      Build_Expected_YCCK_Output (Expected);

      for Row in 0 .. Natural (Height) - 1 loop
         Jpeglib.Internal.Colors.Write_YCCK_Row
           (Output,
            Row,
            Y_Plane,
            Cb_Plane,
            Cr_Plane,
            K_Plane,
            Offset,
            Natural (Width),
            Alpha => 213,
            Written => Written);
         if Written /= Natural (Width) then
            Fail (Jpeglib.Images.Pixel_Format'Image (Format) & " YCCK output row wrote wrong count");
         end if;
         Offset := Offset + Written;
      end loop;

      if Output_Storage (1 .. Used_Bytes) /= Expected_Output (1 .. Used_Bytes) then
         Fail (Jpeglib.Images.Pixel_Format'Image (Format) & " YCCK output row differs from scalar reference");
      end if;
   end Run_YCCK_Output_Format;

   procedure Build_Source_Plane is
      Offset : Natural := 0;
   begin
      Y_Plane := [others => 0];
      for Row in 0 .. Natural (Height) - 1 loop
         for Column in 0 .. Natural (Width) - 1 loop
            Y_Plane (Y_Plane'First + Offset) := Jpeglib.Byte ((Row * 43 + Column * 17 + Row * Column + 29) mod 256);
            Offset := Offset + 1;
         end loop;
      end loop;
   end Build_Source_Plane;

   function Scalar_Downsample_Sample
     (Source : Jpeglib.Streams.Byte_Array;
      Source_Width : Jpeglib.Image_Width;
      Source_Height : Jpeglib.Image_Height;
      Horizontal_Factor : Positive;
      Vertical_Factor : Positive;
      Target_X : Natural;
      Target_Y : Natural) return Jpeglib.Byte
   is
      Sum : Natural := 0;
      Count : Natural := 0;
      Source_X : Natural;
      Source_Y : Natural;
   begin
      for Local_Y in 0 .. Vertical_Factor - 1 loop
         Source_Y := Target_Y * Vertical_Factor + Local_Y;
         if Source_Y < Natural (Source_Height) then
            for Local_X in 0 .. Horizontal_Factor - 1 loop
               Source_X := Target_X * Horizontal_Factor + Local_X;
               if Source_X < Natural (Source_Width) then
                  Sum := Sum + Natural (Source (Source'First + Source_Y * Natural (Source_Width) + Source_X));
                  Count := Count + 1;
               end if;
            end loop;
         end if;
      end loop;

      return Jpeglib.Byte ((Sum + Count / 2) / Count);
   end Scalar_Downsample_Sample;

   procedure Run_Downsample_Format
     (Horizontal_Factor : Positive;
      Vertical_Factor : Positive;
      Label : String)
   is
      Target_Width : constant Natural := (Natural (Width) + Horizontal_Factor - 1) / Horizontal_Factor;
      Target_Height : constant Natural := (Natural (Height) + Vertical_Factor - 1) / Vertical_Factor;
      Target_Samples : constant Natural := Target_Width * Target_Height;
      Result : Jpeglib.Internal.Image_Blocks.Plane_Result;
      Offset : Natural := 0;
   begin
      Build_Source_Plane;
      Cb_Plane := [others => 0];
      Expected_Cb := [others => 0];

      Result :=
        Jpeglib.Internal.Image_Blocks.Downsample_Plane
          (Y_Plane,
           Source_Width => Width,
           Source_Height => Height,
           Horizontal_Factor => Horizontal_Factor,
           Vertical_Factor => Vertical_Factor,
           Target => Cb_Plane);

      if not Jpeglib.Results.Succeeded (Result.Outcome) then
         Fail (Label & " downsample row kernel failed");
      elsif Natural (Result.Samples_Written) /= Target_Samples then
         Fail (Label & " downsample row kernel wrote wrong count");
      end if;

      for Target_Y in 0 .. Target_Height - 1 loop
         for Target_X in 0 .. Target_Width - 1 loop
            Expected_Cb (Expected_Cb'First + Offset) :=
              Scalar_Downsample_Sample
                (Y_Plane,
                 Source_Width => Width,
                 Source_Height => Height,
                 Horizontal_Factor => Horizontal_Factor,
                 Vertical_Factor => Vertical_Factor,
                 Target_X => Target_X,
                 Target_Y => Target_Y);
            Offset := Offset + 1;
         end loop;
      end loop;

      if Cb_Plane (Cb_Plane'First .. Cb_Plane'First + Target_Samples - 1)
        /= Expected_Cb (Expected_Cb'First .. Expected_Cb'First + Target_Samples - 1)
      then
         Fail (Label & " downsample row kernel differs from scalar reference");
      end if;
   end Run_Downsample_Format;
begin
   if not Jpeglib.Capabilities.SIMD_Acceleration then
      Fail ("SIMD acceleration capability is not advertised");
   end if;

   if Jpeglib.Internal.Colors.Active_Acceleration /= Jpeglib.Internal.Colors.Compiler_Vectorized_SIMD then
      Fail ("compiler-vectorized SIMD profile is not active");
   end if;
   if Jpeglib.Internal.Colors.Active_Acceleration_Backend /= "compiler-vectorized" then
      Fail ("compiler-vectorized SIMD backend is not reported precisely");
   end if;

   Run_Format (Jpeglib.Images.RGB_24);
   Run_Format (Jpeglib.Images.BGR_24);
   Run_Format (Jpeglib.Images.RGBA_32);
   Run_Format (Jpeglib.Images.BGRA_32);
   Run_Gray_Alpha_Input_Format;
   Run_CMYK_Input_Format (Jpeglib.Images.Gray_8, False);
   Run_CMYK_Input_Format (Jpeglib.Images.Gray_Alpha_16, False);
   Run_CMYK_Input_Format (Jpeglib.Images.RGB_24, False);
   Run_CMYK_Input_Format (Jpeglib.Images.BGR_24, False);
   Run_CMYK_Input_Format (Jpeglib.Images.RGBA_32, False);
   Run_CMYK_Input_Format (Jpeglib.Images.BGRA_32, False);
   Run_CMYK_Input_Format (Jpeglib.Images.CMYK_32, False);
   Run_CMYK_Input_Format (Jpeglib.Images.YCCK_32, False);
   Run_CMYK_Input_Format (Jpeglib.Images.Gray_8, True);
   Run_CMYK_Input_Format (Jpeglib.Images.Gray_Alpha_16, True);
   Run_CMYK_Input_Format (Jpeglib.Images.RGB_24, True);
   Run_CMYK_Input_Format (Jpeglib.Images.BGR_24, True);
   Run_CMYK_Input_Format (Jpeglib.Images.RGBA_32, True);
   Run_CMYK_Input_Format (Jpeglib.Images.BGRA_32, True);
   Run_CMYK_Input_Format (Jpeglib.Images.CMYK_32, True);
   Run_CMYK_Input_Format (Jpeglib.Images.YCCK_32, True);
   Run_Output_Format (Jpeglib.Images.Gray_8);
   Run_Output_Format (Jpeglib.Images.Gray_Alpha_16);
   Run_Output_Format (Jpeglib.Images.RGB_24);
   Run_Output_Format (Jpeglib.Images.BGR_24);
   Run_Output_Format (Jpeglib.Images.RGBA_32);
   Run_Output_Format (Jpeglib.Images.BGRA_32);
   Run_Output_Format (Jpeglib.Images.CMYK_32);
   Run_Output_Format (Jpeglib.Images.YCCK_32);
   Run_RGB_Output_Format (Jpeglib.Images.Gray_8);
   Run_RGB_Output_Format (Jpeglib.Images.Gray_Alpha_16);
   Run_RGB_Output_Format (Jpeglib.Images.RGB_24);
   Run_RGB_Output_Format (Jpeglib.Images.BGR_24);
   Run_RGB_Output_Format (Jpeglib.Images.RGBA_32);
   Run_RGB_Output_Format (Jpeglib.Images.BGRA_32);
   Run_RGB_Output_Format (Jpeglib.Images.CMYK_32);
   Run_RGB_Output_Format (Jpeglib.Images.YCCK_32);
   Run_Gray_Output_Format (Jpeglib.Images.Gray_8);
   Run_Gray_Output_Format (Jpeglib.Images.Gray_Alpha_16);
   Run_Gray_Output_Format (Jpeglib.Images.RGB_24);
   Run_Gray_Output_Format (Jpeglib.Images.BGR_24);
   Run_Gray_Output_Format (Jpeglib.Images.RGBA_32);
   Run_Gray_Output_Format (Jpeglib.Images.BGRA_32);
   Run_Gray_Output_Format (Jpeglib.Images.CMYK_32);
   Run_Gray_Output_Format (Jpeglib.Images.YCCK_32);
   Run_Gray_Alpha_Output_Format (Jpeglib.Images.Gray_8);
   Run_Gray_Alpha_Output_Format (Jpeglib.Images.Gray_Alpha_16);
   Run_Gray_Alpha_Output_Format (Jpeglib.Images.RGB_24);
   Run_Gray_Alpha_Output_Format (Jpeglib.Images.BGR_24);
   Run_Gray_Alpha_Output_Format (Jpeglib.Images.RGBA_32);
   Run_Gray_Alpha_Output_Format (Jpeglib.Images.BGRA_32);
   Run_Gray_Alpha_Output_Format (Jpeglib.Images.CMYK_32);
   Run_Gray_Alpha_Output_Format (Jpeglib.Images.YCCK_32);
   Run_CMYK_Output_Format (Jpeglib.Images.Gray_8);
   Run_CMYK_Output_Format (Jpeglib.Images.Gray_Alpha_16);
   Run_CMYK_Output_Format (Jpeglib.Images.RGB_24);
   Run_CMYK_Output_Format (Jpeglib.Images.BGR_24);
   Run_CMYK_Output_Format (Jpeglib.Images.RGBA_32);
   Run_CMYK_Output_Format (Jpeglib.Images.BGRA_32);
   Run_CMYK_Output_Format (Jpeglib.Images.CMYK_32);
   Run_CMYK_Output_Format (Jpeglib.Images.YCCK_32);
   Run_YCCK_Output_Format (Jpeglib.Images.Gray_8);
   Run_YCCK_Output_Format (Jpeglib.Images.Gray_Alpha_16);
   Run_YCCK_Output_Format (Jpeglib.Images.RGB_24);
   Run_YCCK_Output_Format (Jpeglib.Images.BGR_24);
   Run_YCCK_Output_Format (Jpeglib.Images.RGBA_32);
   Run_YCCK_Output_Format (Jpeglib.Images.BGRA_32);
   Run_YCCK_Output_Format (Jpeglib.Images.CMYK_32);
   Run_YCCK_Output_Format (Jpeglib.Images.YCCK_32);
   Run_Downsample_Format (1, 1, "4:4:4");
   Run_Downsample_Format (2, 1, "4:2:2");
   Run_Downsample_Format (4, 1, "4:1:1");
   Run_Downsample_Format (2, 2, "4:2:0");

   Ada.Text_IO.Put_Line
     ("jpeglib_simd_matrix: host="
      & Hostkit.Host.Kind'Image (Hostkit.Host.Current)
      & " machine="
      & Hostkit.Host.Machine_Name
      & " acceleration="
      & Jpeglib.Internal.Colors.Acceleration_Profile'Image (Jpeglib.Internal.Colors.Active_Acceleration)
      & " backend="
      & Jpeglib.Internal.Colors.Active_Acceleration_Backend
      & " detail="""
      & Jpeglib.Internal.Colors.Active_Acceleration_Detail
      & """");

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

package body Jpeglib.Coefficients is

   function To_Index (U, V : Natural) return Coefficient_Index is
   begin
      return Coefficient_Index (V * 8 + U);
   end To_Index;

   function Maybe_Negate
     (Value : Quantized_Coefficient;
      Negate : Boolean) return Quantized_Coefficient is
   begin
      if Negate then
         return -Value;
      else
         return Value;
      end if;
   end Maybe_Negate;

   function Transform
     (Block : DCT_Block;
      Operation : Block_Transform) return DCT_Block
   is
      Result : DCT_Block := [others => 0];
      Source_U : Natural;
      Source_V : Natural;
      Negate : Boolean;
   begin
      for V in 0 .. 7 loop
         for U in 0 .. 7 loop
            Source_U := U;
            Source_V := V;
            Negate := False;

            case Operation is
               when Identity =>
                  null;
               when Flip_Horizontal =>
                  Negate := U mod 2 = 1;
               when Flip_Vertical =>
                  Negate := V mod 2 = 1;
               when Rotate_180 =>
                  Negate := (U + V) mod 2 = 1;
               when Transpose =>
                  Source_U := V;
                  Source_V := U;
               when Rotate_90 =>
                  Source_U := V;
                  Source_V := U;
                  Negate := U mod 2 = 1;
               when Rotate_270 =>
                  Source_U := V;
                  Source_V := U;
                  Negate := V mod 2 = 1;
               when Transverse =>
                  Source_U := V;
                  Source_V := U;
                  Negate := (U + V) mod 2 = 1;
            end case;

            Result (To_Index (U, V)) :=
              Maybe_Negate (Block (To_Index (Source_U, Source_V)), Negate);
         end loop;
      end loop;

      return Result;
   end Transform;

   procedure Apply_Transform
     (Block : in out DCT_Block;
      Operation : Block_Transform) is
   begin
      Block := Transform (Block, Operation);
   end Apply_Transform;

   function Block_Count_For
     (Layout : Component_Block_Layout) return Component_Block_Count is
   begin
      return Layout.Width_In_Blocks * Layout.Height_In_Blocks;
   end Block_Count_For;

   function Total_Block_Count
     (Layouts : Component_Block_Layout_Array) return Component_Block_Count
   is
      Total : Component_Block_Count := 0;
   begin
      for Layout of Layouts loop
         Total := Total + Block_Count_For (Layout);
      end loop;

      return Total;
   end Total_Block_Count;

   function Full_Windows
     (Layouts : Component_Block_Layout_Array) return Component_Block_Window_Array
   is
      Result : Component_Block_Window_Array (Layouts'Range);
   begin
      for Component in Layouts'Range loop
         Result (Component) :=
           (Left => 0,
            Top => 0,
            Width_In_Blocks => Layouts (Component).Width_In_Blocks,
            Height_In_Blocks => Layouts (Component).Height_In_Blocks);
      end loop;

      return Result;
   end Full_Windows;

   function Transformed_Layout
     (Window : Component_Block_Window;
      Operation : Block_Transform) return Component_Block_Layout is
   begin
      case Operation is
         when Identity | Flip_Horizontal | Flip_Vertical | Rotate_180 =>
            return
              (Width_In_Blocks => Window.Width_In_Blocks,
               Height_In_Blocks => Window.Height_In_Blocks);
         when Transpose | Rotate_90 | Rotate_270 | Transverse =>
            return
              (Width_In_Blocks => Window.Height_In_Blocks,
               Height_In_Blocks => Window.Width_In_Blocks);
      end case;
   end Transformed_Layout;

   function Transformed_Layouts
     (Windows : Component_Block_Window_Array;
      Operation : Block_Transform) return Component_Block_Layout_Array
   is
      Result : Component_Block_Layout_Array (Windows'Range);
   begin
      for Component in Windows'Range loop
         Result (Component) := Transformed_Layout (Windows (Component), Operation);
      end loop;

      return Result;
   end Transformed_Layouts;

   function Validate_Windows
     (Layouts : Component_Block_Layout_Array;
      Windows : Component_Block_Window_Array) return Transform_Status is
   begin
      if Layouts'First /= Windows'First or else Layouts'Last /= Windows'Last then
         return Layout_Range_Mismatch;
      end if;

      for Component in Layouts'Range loop
         if Layouts (Component).Width_In_Blocks = 0
           or else Layouts (Component).Height_In_Blocks = 0
         then
            return Invalid_Layout;
         end if;

         if Windows (Component).Width_In_Blocks = 0
           or else Windows (Component).Height_In_Blocks = 0
           or else Windows (Component).Left > Layouts (Component).Width_In_Blocks
           or else Windows (Component).Top > Layouts (Component).Height_In_Blocks
           or else Windows (Component).Width_In_Blocks >
             Layouts (Component).Width_In_Blocks - Windows (Component).Left
           or else Windows (Component).Height_In_Blocks >
             Layouts (Component).Height_In_Blocks - Windows (Component).Top
         then
            return Invalid_Window;
         end if;
      end loop;

      return Transform_Ok;
   end Validate_Windows;

   function Block_Offset
     (Layouts : Component_Block_Layout_Array;
      Component : Component_Index) return Component_Block_Count
   is
      Offset : Component_Block_Count := 0;
   begin
      for Current in Layouts'Range loop
         exit when Current = Component;
         Offset := Offset + Block_Count_For (Layouts (Current));
      end loop;

      return Offset;
   end Block_Offset;

   procedure Map_Destination
     (Operation : Block_Transform;
      Source_X : Component_Block_Count;
      Source_Y : Component_Block_Count;
      Width : Component_Block_Count;
      Height : Component_Block_Count;
      Destination_X : out Component_Block_Count;
      Destination_Y : out Component_Block_Count) is
   begin
      case Operation is
         when Identity =>
            Destination_X := Source_X;
            Destination_Y := Source_Y;
         when Flip_Horizontal =>
            Destination_X := Width - 1 - Source_X;
            Destination_Y := Source_Y;
         when Flip_Vertical =>
            Destination_X := Source_X;
            Destination_Y := Height - 1 - Source_Y;
         when Rotate_180 =>
            Destination_X := Width - 1 - Source_X;
            Destination_Y := Height - 1 - Source_Y;
         when Transpose =>
            Destination_X := Source_Y;
            Destination_Y := Source_X;
         when Rotate_90 =>
            Destination_X := Height - 1 - Source_Y;
            Destination_Y := Source_X;
         when Rotate_270 =>
            Destination_X := Source_Y;
            Destination_Y := Width - 1 - Source_X;
         when Transverse =>
            Destination_X := Height - 1 - Source_Y;
            Destination_Y := Width - 1 - Source_X;
      end case;
   end Map_Destination;

   procedure Transform_Image
     (Input_Blocks : DCT_Block_Array;
      Input_Layouts : Component_Block_Layout_Array;
      Windows : Component_Block_Window_Array;
      Operation : Block_Transform;
      Output_Blocks : in out DCT_Block_Array;
      Output_Layouts : out Component_Block_Layout_Array;
      Blocks_Written : out Component_Block_Count;
      Status : out Transform_Status)
   is
      Output_Total : Component_Block_Count := 0;
      Source_Component_Offset : Component_Block_Count;
      Destination_Component_Offset : Component_Block_Count;
      Source_X : Component_Block_Count;
      Source_Y : Component_Block_Count;
      Destination_X : Component_Block_Count;
      Destination_Y : Component_Block_Count;
      Source_Index : Component_Block_Count;
      Destination_Index : Component_Block_Count;
   begin
      Blocks_Written := 0;
      Output_Layouts := [others => (Width_In_Blocks => 0, Height_In_Blocks => 0)];
      Status := Validate_Windows (Input_Layouts, Windows);

      if Status /= Transform_Ok then
         return;
      end if;

      if Input_Layouts'First /= Output_Layouts'First
        or else Input_Layouts'Last /= Output_Layouts'Last
      then
         Status := Layout_Range_Mismatch;
         return;
      end if;

      if Component_Block_Count (Input_Blocks'Length) < Total_Block_Count (Input_Layouts) then
         Status := Output_Too_Small;
         return;
      end if;

      Output_Layouts := Transformed_Layouts (Windows, Operation);
      Output_Total := Total_Block_Count (Output_Layouts);

      if Component_Block_Count (Output_Blocks'Length) < Output_Total then
         Output_Layouts := [others => (Width_In_Blocks => 0, Height_In_Blocks => 0)];
         Status := Output_Too_Small;
         return;
      end if;

      for Component in Input_Layouts'Range loop
         Source_Component_Offset := Block_Offset (Input_Layouts, Component);
         Destination_Component_Offset := Block_Offset (Output_Layouts, Component);

         for Local_Y in 0 .. Windows (Component).Height_In_Blocks - 1 loop
            for Local_X in 0 .. Windows (Component).Width_In_Blocks - 1 loop
               Source_X := Windows (Component).Left + Local_X;
               Source_Y := Windows (Component).Top + Local_Y;
               Map_Destination
                 (Operation,
                  Local_X,
                  Local_Y,
                  Windows (Component).Width_In_Blocks,
                  Windows (Component).Height_In_Blocks,
                  Destination_X,
                  Destination_Y);

               Source_Index :=
                 Source_Component_Offset
                 + Source_Y * Input_Layouts (Component).Width_In_Blocks
                 + Source_X;
               Destination_Index :=
                 Destination_Component_Offset
                 + Destination_Y * Output_Layouts (Component).Width_In_Blocks
                 + Destination_X;

               Output_Blocks
                 (Positive (Natural (Output_Blocks'First) + Natural (Destination_Index))) :=
                   Transform
                     (Input_Blocks
                        (Positive (Natural (Input_Blocks'First) + Natural (Source_Index))),
                      Operation);
            end loop;
         end loop;
      end loop;

      Blocks_Written := Output_Total;
      Status := Transform_Ok;
   end Transform_Image;

end Jpeglib.Coefficients;

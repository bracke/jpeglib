with Jpeglib.Errors;
with Jpeglib.Internal.Bytes;

package body Jpeglib.Internal.Huffman is
   function Has_Table
     (State : Huffman_State;
      Class : Huffman_Class;
      Index : Huffman_Table_Index) return Boolean
   is
   begin
      return State.Present (Class) (Index);
   end Has_Table;

   function Definition
     (State : Huffman_State;
      Class : Huffman_Class;
      Index : Huffman_Table_Index) return Huffman_Definition
   is
   begin
      return State.Tables (Class) (Index);
   end Definition;

   function Counts (Definition : Huffman_Definition) return Length_Counts is
   begin
      return Definition.Lengths;
   end Counts;

   function Symbol_Total (Definition : Huffman_Definition) return Symbol_Count is
   begin
      return Definition.Total;
   end Symbol_Total;

   function Symbol (Definition : Huffman_Definition; Index : Symbol_Index) return Byte is
   begin
      return Definition.Symbols (Index);
   end Symbol;

   function Standard_Luminance_DC return Huffman_Definition is
      Result : Huffman_Definition :=
        (Lengths =>
           [1 => 0, 2 => 1, 3 => 5, 4 => 1, 5 => 1, 6 => 1, 7 => 1, 8 => 1,
            9 => 1, 10 => 0, 11 => 0, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0],
         Symbols => [others => 0],
         Total => 12);
   begin
      for Index in 1 .. 12 loop
         Result.Symbols (Symbol_Index (Index)) := Byte (Index - 1);
      end loop;

      return Result;
   end Standard_Luminance_DC;

   function Standard_Luminance_AC return Huffman_Definition is
      Result : constant Huffman_Definition :=
        (Lengths =>
           [1 => 0, 2 => 2, 3 => 1, 4 => 3, 5 => 3, 6 => 2, 7 => 4, 8 => 3,
            9 => 5, 10 => 5, 11 => 4, 12 => 4, 13 => 0, 14 => 0, 15 => 1, 16 => 125],
         Symbols =>
           [1 => 16#01#, 2 => 16#02#, 3 => 16#03#, 4 => 16#00#, 5 => 16#04#, 6 => 16#11#,
            7 => 16#05#, 8 => 16#12#, 9 => 16#21#, 10 => 16#31#, 11 => 16#41#, 12 => 16#06#,
            13 => 16#13#, 14 => 16#51#, 15 => 16#61#, 16 => 16#07#, 17 => 16#22#, 18 => 16#71#,
            19 => 16#14#, 20 => 16#32#, 21 => 16#81#, 22 => 16#91#, 23 => 16#A1#, 24 => 16#08#,
            25 => 16#23#, 26 => 16#42#, 27 => 16#B1#, 28 => 16#C1#, 29 => 16#15#, 30 => 16#52#,
            31 => 16#D1#, 32 => 16#F0#, 33 => 16#24#, 34 => 16#33#, 35 => 16#62#, 36 => 16#72#,
            37 => 16#82#, 38 => 16#09#, 39 => 16#0A#, 40 => 16#16#, 41 => 16#17#, 42 => 16#18#,
            43 => 16#19#, 44 => 16#1A#, 45 => 16#25#, 46 => 16#26#, 47 => 16#27#, 48 => 16#28#,
            49 => 16#29#, 50 => 16#2A#, 51 => 16#34#, 52 => 16#35#, 53 => 16#36#, 54 => 16#37#,
            55 => 16#38#, 56 => 16#39#, 57 => 16#3A#, 58 => 16#43#, 59 => 16#44#, 60 => 16#45#,
            61 => 16#46#, 62 => 16#47#, 63 => 16#48#, 64 => 16#49#, 65 => 16#4A#, 66 => 16#53#,
            67 => 16#54#, 68 => 16#55#, 69 => 16#56#, 70 => 16#57#, 71 => 16#58#, 72 => 16#59#,
            73 => 16#5A#, 74 => 16#63#, 75 => 16#64#, 76 => 16#65#, 77 => 16#66#, 78 => 16#67#,
            79 => 16#68#, 80 => 16#69#, 81 => 16#6A#, 82 => 16#73#, 83 => 16#74#, 84 => 16#75#,
            85 => 16#76#, 86 => 16#77#, 87 => 16#78#, 88 => 16#79#, 89 => 16#7A#, 90 => 16#83#,
            91 => 16#84#, 92 => 16#85#, 93 => 16#86#, 94 => 16#87#, 95 => 16#88#, 96 => 16#89#,
            97 => 16#8A#, 98 => 16#92#, 99 => 16#93#, 100 => 16#94#, 101 => 16#95#, 102 => 16#96#,
            103 => 16#97#, 104 => 16#98#, 105 => 16#99#, 106 => 16#9A#, 107 => 16#A2#, 108 => 16#A3#,
            109 => 16#A4#, 110 => 16#A5#, 111 => 16#A6#, 112 => 16#A7#, 113 => 16#A8#, 114 => 16#A9#,
            115 => 16#AA#, 116 => 16#B2#, 117 => 16#B3#, 118 => 16#B4#, 119 => 16#B5#, 120 => 16#B6#,
            121 => 16#B7#, 122 => 16#B8#, 123 => 16#B9#, 124 => 16#BA#, 125 => 16#C2#, 126 => 16#C3#,
            127 => 16#C4#, 128 => 16#C5#, 129 => 16#C6#, 130 => 16#C7#, 131 => 16#C8#, 132 => 16#C9#,
            133 => 16#CA#, 134 => 16#D2#, 135 => 16#D3#, 136 => 16#D4#, 137 => 16#D5#, 138 => 16#D6#,
            139 => 16#D7#, 140 => 16#D8#, 141 => 16#D9#, 142 => 16#DA#, 143 => 16#E1#, 144 => 16#E2#,
            145 => 16#E3#, 146 => 16#E4#, 147 => 16#E5#, 148 => 16#E6#, 149 => 16#E7#, 150 => 16#E8#,
            151 => 16#E9#, 152 => 16#EA#, 153 => 16#F1#, 154 => 16#F2#, 155 => 16#F3#, 156 => 16#F4#,
            157 => 16#F5#, 158 => 16#F6#, 159 => 16#F7#, 160 => 16#F8#, 161 => 16#F9#, 162 => 16#FA#,
            others => 0],
         Total => 162);
   begin
      return Result;
   end Standard_Luminance_AC;

   function Standard_Chrominance_DC return Huffman_Definition is
      Result : Huffman_Definition :=
        (Lengths =>
           [1 => 0, 2 => 3, 3 => 1, 4 => 1, 5 => 1, 6 => 1, 7 => 1, 8 => 1,
            9 => 1, 10 => 1, 11 => 1, 12 => 0, 13 => 0, 14 => 0, 15 => 0, 16 => 0],
         Symbols => [others => 0],
         Total => 12);
   begin
      for Index in 1 .. 12 loop
         Result.Symbols (Symbol_Index (Index)) := Byte (Index - 1);
      end loop;

      return Result;
   end Standard_Chrominance_DC;

   function Standard_Chrominance_AC return Huffman_Definition is
      Result : constant Huffman_Definition :=
        (Lengths =>
           [1 => 0, 2 => 2, 3 => 1, 4 => 2, 5 => 4, 6 => 4, 7 => 3, 8 => 4,
            9 => 7, 10 => 5, 11 => 4, 12 => 4, 13 => 0, 14 => 1, 15 => 2, 16 => 119],
         Symbols =>
           [1 => 16#00#, 2 => 16#01#, 3 => 16#02#, 4 => 16#03#, 5 => 16#11#, 6 => 16#04#,
            7 => 16#05#, 8 => 16#21#, 9 => 16#31#, 10 => 16#06#, 11 => 16#12#, 12 => 16#41#,
            13 => 16#51#, 14 => 16#07#, 15 => 16#61#, 16 => 16#71#, 17 => 16#13#, 18 => 16#22#,
            19 => 16#32#, 20 => 16#81#, 21 => 16#08#, 22 => 16#14#, 23 => 16#42#, 24 => 16#91#,
            25 => 16#A1#, 26 => 16#B1#, 27 => 16#C1#, 28 => 16#09#, 29 => 16#23#, 30 => 16#33#,
            31 => 16#52#, 32 => 16#F0#, 33 => 16#15#, 34 => 16#62#, 35 => 16#72#, 36 => 16#D1#,
            37 => 16#0A#, 38 => 16#16#, 39 => 16#24#, 40 => 16#34#, 41 => 16#E1#, 42 => 16#25#,
            43 => 16#F1#, 44 => 16#17#, 45 => 16#18#, 46 => 16#19#, 47 => 16#1A#, 48 => 16#26#,
            49 => 16#27#, 50 => 16#28#, 51 => 16#29#, 52 => 16#2A#, 53 => 16#35#, 54 => 16#36#,
            55 => 16#37#, 56 => 16#38#, 57 => 16#39#, 58 => 16#3A#, 59 => 16#43#, 60 => 16#44#,
            61 => 16#45#, 62 => 16#46#, 63 => 16#47#, 64 => 16#48#, 65 => 16#49#, 66 => 16#4A#,
            67 => 16#53#, 68 => 16#54#, 69 => 16#55#, 70 => 16#56#, 71 => 16#57#, 72 => 16#58#,
            73 => 16#59#, 74 => 16#5A#, 75 => 16#63#, 76 => 16#64#, 77 => 16#65#, 78 => 16#66#,
            79 => 16#67#, 80 => 16#68#, 81 => 16#69#, 82 => 16#6A#, 83 => 16#73#, 84 => 16#74#,
            85 => 16#75#, 86 => 16#76#, 87 => 16#77#, 88 => 16#78#, 89 => 16#79#, 90 => 16#7A#,
            91 => 16#82#, 92 => 16#83#, 93 => 16#84#, 94 => 16#85#, 95 => 16#86#, 96 => 16#87#,
            97 => 16#88#, 98 => 16#89#, 99 => 16#8A#, 100 => 16#92#, 101 => 16#93#, 102 => 16#94#,
            103 => 16#95#, 104 => 16#96#, 105 => 16#97#, 106 => 16#98#, 107 => 16#99#, 108 => 16#9A#,
            109 => 16#A2#, 110 => 16#A3#, 111 => 16#A4#, 112 => 16#A5#, 113 => 16#A6#, 114 => 16#A7#,
            115 => 16#A8#, 116 => 16#A9#, 117 => 16#AA#, 118 => 16#B2#, 119 => 16#B3#, 120 => 16#B4#,
            121 => 16#B5#, 122 => 16#B6#, 123 => 16#B7#, 124 => 16#B8#, 125 => 16#B9#, 126 => 16#BA#,
            127 => 16#C2#, 128 => 16#C3#, 129 => 16#C4#, 130 => 16#C5#, 131 => 16#C6#, 132 => 16#C7#,
            133 => 16#C8#, 134 => 16#C9#, 135 => 16#CA#, 136 => 16#D2#, 137 => 16#D3#, 138 => 16#D4#,
            139 => 16#D5#, 140 => 16#D6#, 141 => 16#D7#, 142 => 16#D8#, 143 => 16#D9#, 144 => 16#DA#,
            145 => 16#E2#, 146 => 16#E3#, 147 => 16#E4#, 148 => 16#E5#, 149 => 16#E6#, 150 => 16#E7#,
            151 => 16#E8#, 152 => 16#E9#, 153 => 16#EA#, 154 => 16#F2#, 155 => 16#F3#, 156 => 16#F4#,
            157 => 16#F5#, 158 => 16#F6#, 159 => 16#F7#, 160 => 16#F8#, 161 => 16#F9#, 162 => 16#FA#,
            others => 0],
         Total => 162);
   begin
      return Result;
   end Standard_Chrominance_AC;

   function Optimized_Definition (Frequencies : Symbol_Frequencies) return Huffman_Definition is
      Max_Nodes : constant Natural := 511;
      subtype Node_Range is Natural range 1 .. Max_Nodes;
      type Weight_Array is array (Node_Range) of Symbol_Frequency;
      type Parent_Array is array (Node_Range) of Natural range 0 .. Max_Nodes;
      type Symbol_By_Node is array (Node_Range) of Byte;
      type Boolean_Array is array (Node_Range) of Boolean;
      type Length_By_Symbol is array (Byte) of Natural range 0 .. 16;

      Weights : Weight_Array := [others => 0];
      Parents : Parent_Array := [others => 0];
      Symbols : Symbol_By_Node := [others => 0];
      Is_Leaf : Boolean_Array := [others => False];
      Active : Boolean_Array := [others => False];
      Lengths : Length_By_Symbol := [others => 0];
      Leaf_Count : Natural := 0;
      Node_Count : Natural := 0;
      Active_Count : Natural := 0;
      Result : Huffman_Definition;

      function Minimum_Length_For (Count : Natural) return Code_Length is
         Capacity : Natural := 2;
      begin
         for Length in Code_Length loop
            if Count <= Capacity then
               return Length;
            end if;
            Capacity := Capacity * 2;
         end loop;

         return Code_Length'Last;
      end Minimum_Length_For;

      procedure Add_Leaf
        (Symbol : Byte;
         Weight : Symbol_Frequency)
      is
      begin
         Node_Count := Node_Count + 1;
         Leaf_Count := Leaf_Count + 1;
         Active_Count := Active_Count + 1;
         Weights (Node_Count) := Weight;
         Symbols (Node_Count) := Symbol;
         Is_Leaf (Node_Count) := True;
         Active (Node_Count) := True;
      end Add_Leaf;

      function Better_Candidate
        (Candidate : Natural;
         Current : Natural) return Boolean
      is
      begin
         if Current = 0 then
            return True;
         elsif Weights (Candidate) /= Weights (Current) then
            return Weights (Candidate) < Weights (Current);
         elsif Is_Leaf (Candidate) /= Is_Leaf (Current) then
            return Is_Leaf (Candidate);
         elsif Is_Leaf (Candidate) then
            return Symbols (Candidate) < Symbols (Current);
         else
            return Candidate < Current;
         end if;
      end Better_Candidate;

      procedure Select_Two
        (First : out Natural;
         Second : out Natural)
      is
      begin
         First := 0;
         Second := 0;

         for Node in 1 .. Node_Count loop
            if Active (Node) then
               if Better_Candidate (Node, First) then
                  Second := First;
                  First := Node;
               elsif Better_Candidate (Node, Second) then
                  Second := Node;
               end if;
            end if;
         end loop;
      end Select_Two;

      procedure Build_Result is
         Position : Natural := 1;
      begin
         Result := (others => <>);

         for Symbol in Byte loop
            if Lengths (Symbol) /= 0 then
               Result.Lengths (Code_Length (Lengths (Symbol))) :=
                 Result.Lengths (Code_Length (Lengths (Symbol))) + 1;
               Result.Total := Result.Total + 1;
            end if;
         end loop;

         for Length in Code_Length loop
            for Symbol in Byte loop
               if Lengths (Symbol) = Natural (Length) then
                  Result.Symbols (Symbol_Index (Position)) := Symbol;
                  Position := Position + 1;
               end if;
            end loop;
         end loop;
      end Build_Result;

      First : Natural;
      Second : Natural;
      Length : Natural;
      Parent : Natural;
      Flat_Length : Code_Length;
      Too_Deep : Boolean := False;
   begin
      for Symbol in Byte loop
         if Frequencies (Symbol) > 0 then
            Add_Leaf (Symbol, Frequencies (Symbol));
         end if;
      end loop;

      if Leaf_Count = 0 then
         Add_Leaf (0, 1);
      end if;

      if Leaf_Count = 1 then
         for Symbol in Byte loop
            if Frequencies (Symbol) = 0 then
               Add_Leaf (Symbol, 1);
               exit;
            end if;
         end loop;
      end if;

      while Active_Count > 1 loop
         Select_Two (First, Second);
         Node_Count := Node_Count + 1;
         Weights (Node_Count) := Weights (First) + Weights (Second);
         Active (First) := False;
         Active (Second) := False;
         Active (Node_Count) := True;
         Active_Count := Active_Count - 1;
         Parents (First) := Node_Count;
         Parents (Second) := Node_Count;
      end loop;

      for Node in 1 .. Node_Count loop
         if Is_Leaf (Node) then
            Length := 0;
            Parent := Parents (Node);
            while Parent /= 0 loop
               Length := Length + 1;
               Parent := Parents (Parent);
            end loop;

            if Length > Natural (Code_Length'Last) then
               Too_Deep := True;
               exit;
            end if;

            Lengths (Symbols (Node)) := Length;
         end if;
      end loop;

      if Too_Deep then
         Flat_Length := Minimum_Length_For (Leaf_Count);
         Lengths := [others => 0];
         for Node in 1 .. Node_Count loop
            if Is_Leaf (Node) then
               Lengths (Symbols (Node)) := Natural (Flat_Length);
            end if;
         end loop;
      end if;

      Build_Result;
      return Result;
   exception
      when Constraint_Error =>
         return (Lengths => [8 => 2, others => 0], Symbols => [1 => 0, 2 => 1, others => 0], Total => 2);
   end Optimized_Definition;

   function Invalid
     (Segment : Segments.Segment_Reader;
      Source : Source_Offset;
      Detail : Long_Long_Integer := 0) return Results.Result
   is
   begin
      return
        Results.Failure
          (Errors.Make
             (Errors.Huffman_Invalid_Definition,
              (Source => Source,
               Marker => Segments.Descriptor (Segment).Marker,
               Detail => Detail,
               others => <>)));
   end Invalid;

   function Validate_Tree
     (Segment : Segments.Segment_Reader;
      Source : Source_Offset;
      Candidate : Huffman_Definition) return Results.Result
   is
      Available : Integer := 1;
      Used_At_Current_Length : Integer;
   begin
      for Length in Code_Length loop
         Available := Available * 2;
         Used_At_Current_Length := Integer (Candidate.Lengths (Length));
         if Used_At_Current_Length > Available then
            return Invalid (Segment, Source, Long_Long_Integer (Length));
         end if;
         Available := Available - Used_At_Current_Length;
      end loop;

      if Candidate.Total = 0 then
         return Invalid (Segment, Source, Long_Long_Integer (Candidate.Total));
      end if;

      return Results.Success;
   end Validate_Tree;

   function Parse_One
     (Segment : in out Segments.Segment_Reader;
      Class : out Huffman_Class;
      Index : out Huffman_Table_Index;
      Candidate : out Huffman_Definition) return Results.Result
   is
      Header : constant Bytes.Read_Byte_Result := Segments.Read_Byte (Segment);
      Count_Byte : Bytes.Read_Byte_Result;
      Symbol_Byte : Bytes.Read_Byte_Result;
      Table_Class : Natural;
      Table_Id : Natural;
      Total : Natural := 0;
      Outcome : Results.Result;
   begin
      Candidate := (others => <>);

      if not Results.Succeeded (Header.Outcome) then
         return Header.Outcome;
      end if;

      Table_Class := Natural (Header.Value) / 16;
      Table_Id := Natural (Header.Value) mod 16;

      if Table_Class > 1 or else Table_Id > Natural (Huffman_Table_Index'Last) then
         return Invalid (Segment, Header.Source, Long_Long_Integer (Header.Value));
      end if;

      if Table_Class = 0 then
         Class := DC;
      else
         Class := AC;
      end if;
      Index := Huffman_Table_Index (Table_Id);

      for Length in Code_Length loop
         Count_Byte := Segments.Read_Byte (Segment);
         if not Results.Succeeded (Count_Byte.Outcome) then
            return Count_Byte.Outcome;
         end if;

         Total := Total + Natural (Count_Byte.Value);
         if Total > Natural (Symbol_Count'Last) then
            return Invalid (Segment, Count_Byte.Source, Long_Long_Integer (Total));
         end if;

         Candidate.Lengths (Length) := Symbol_Count (Natural (Count_Byte.Value));
      end loop;

      Candidate.Total := Symbol_Count (Total);
      Outcome := Validate_Tree (Segment, Header.Source, Candidate);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      end if;

      for Symbol_Pos in 1 .. Total loop
         Symbol_Byte := Segments.Read_Byte (Segment);
         if not Results.Succeeded (Symbol_Byte.Outcome) then
            return Symbol_Byte.Outcome;
         end if;

         Candidate.Symbols (Symbol_Index (Symbol_Pos)) := Symbol_Byte.Value;
      end loop;

      return Results.Success;
   exception
      when Constraint_Error =>
         return Invalid (Segment, Header.Source);
   end Parse_One;

   function Parse_DHT
     (State : in out Huffman_State;
      Segment : in out Segments.Segment_Reader) return Results.Result
   is
      Class : Huffman_Class := DC;
      Index : Huffman_Table_Index := 0;
      Candidate : Huffman_Definition;
      Outcome : Results.Result;
   begin
      while Segments.Remaining (Segment) > 0 loop
         Outcome := Parse_One (Segment, Class, Index, Candidate);
         if not Results.Succeeded (Outcome) then
            return Outcome;
         end if;

         State.Tables (Class) (Index) := Candidate;
         State.Present (Class) (Index) := True;
      end loop;

      return Results.Success;
   end Parse_DHT;

   function Invalid_Compile (Detail : Long_Long_Integer := 0) return Compile_Result is
   begin
      return
        (Outcome =>
           Results.Failure
             (Errors.Make (Errors.Huffman_Invalid_Definition, (Detail => Detail, others => <>))),
         Table => (others => <>));
   end Invalid_Compile;

   function Compile (Definition : Huffman_Definition) return Compile_Result is
      Result : Compile_Result;
      Code : Natural := 0;
      Position : Natural := 1;
      Count_At_Length : Natural;
   begin
      if Definition.Total = 0 then
         return Invalid_Compile;
      end if;

      for Length in Code_Length loop
         Count_At_Length := Natural (Definition.Lengths (Length));
         for Offset in 1 .. Count_At_Length loop
            if Position > Natural (Definition.Total) then
               return Invalid_Compile (Long_Long_Integer (Position));
            elsif Code >= 2 ** Natural (Length) then
               return Invalid_Compile (Long_Long_Integer (Length));
            end if;

            Result.Table.Entries (Symbol_Index (Position)) :=
              (Length => Length,
               Code => Huffman_Code (Code),
               Symbol => Definition.Symbols (Symbol_Index (Position)));
            Position := Position + 1;
            Code := Code + 1;
         end loop;

         Code := Code * 2;
      end loop;

      Result.Table.Total := Definition.Total;
      return Result;
   exception
      when Constraint_Error =>
         return Invalid_Compile;
   end Compile;

   function Decode
     (Table : Compiled_Huffman;
      Bits : in out Bit_Streams.Bit_Reader) return Decode_Result
   is
      Code : Natural := 0;
      Bit : Bit_Streams.Bit_Result;
   begin
      for Length in Code_Length loop
         Bit := Bit_Streams.Read_Bit (Bits);
         if not Results.Succeeded (Bit.Outcome) then
            return (Outcome => Bit.Outcome, Source => Bit.Source, Symbol => 0);
         end if;

         Code := Code * 2 + Natural (Bit.Value);
         for Index in Symbol_Index range 1 .. Symbol_Index (Table.Total) loop
            if Table.Entries (Index).Length = Length
              and then Natural (Table.Entries (Index).Code) = Code
            then
               return
                 (Outcome => Results.Success,
                  Source => Bit.Source,
                  Symbol => Table.Entries (Index).Symbol);
            end if;
         end loop;
      end loop;

      return
        (Outcome =>
           Results.Failure
             (Errors.Make (Errors.Huffman_Invalid_Definition, (Source => Bit.Source, others => <>))),
         Source => Bit.Source,
         Symbol => 0);
   end Decode;

   function Encode
     (Table : Compiled_Huffman;
      Bits : in out Bit_Streams.Bit_Writer;
      Symbol : Byte) return Results.Result
   is
   begin
      for Index in Symbol_Index range 1 .. Symbol_Index (Table.Total) loop
         if Table.Entries (Index).Symbol = Symbol then
            return
              Bit_Streams.Write_Bits
                (Bits,
                 Bit_Streams.Entropy_Category (Table.Entries (Index).Length),
                 Bit_Streams.Entropy_Bits (Table.Entries (Index).Code));
         end if;
      end loop;

      return
        Results.Failure
          (Errors.Make (Errors.Huffman_Invalid_Definition, (Detail => Long_Long_Integer (Symbol), others => <>)));
   end Encode;
end Jpeglib.Internal.Huffman;

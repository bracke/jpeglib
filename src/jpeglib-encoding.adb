with Jpeglib.Internal.Baseline_Encoder;
with Jpeglib.Internal.Checked_Arithmetic;
with Jpeglib.Internal.Image_Blocks;
with Jpeglib.Internal.Markers;

package body Jpeglib.Encoding is
   use type Images.Pixel_Format;

   function Validate_Descriptor
     (Descriptor : Images.Image_Descriptor;
      Encode_Limits : Limits.Limit_Set) return Results.Result
   is
      Pixels : Internal.Checked_Arithmetic.Count_Result;
      Row_Bytes : Internal.Checked_Arithmetic.Count_Result;
      Prefix_Rows : Internal.Checked_Arithmetic.Count_Result;
      Last_Row_Start : Internal.Checked_Arithmetic.Count_Result;
      Last_Row_End : Internal.Checked_Arithmetic.Count_Result;
   begin
      if Descriptor.Width > Encode_Limits.Max_Width
        or else Descriptor.Height > Encode_Limits.Max_Height
      then
         return Results.Failure (Errors.Pixel_Count_Exceeded);
      end if;

      Pixels :=
        Internal.Checked_Arithmetic.Multiply
          (Byte_Count (Descriptor.Width), Byte_Count (Descriptor.Height));
      if not Results.Succeeded (Pixels.Outcome) then
         return Pixels.Outcome;
      elsif Pixel_Count (Pixels.Count) > Encode_Limits.Max_Pixels then
         return Results.Failure (Errors.Pixel_Count_Exceeded);
      end if;

      Row_Bytes :=
        Internal.Checked_Arithmetic.Multiply
          (Byte_Count (Descriptor.Width), Images.Bytes_Per_Pixel (Descriptor.Format));
      if not Results.Succeeded (Row_Bytes.Outcome) then
         return Row_Bytes.Outcome;
      elsif Byte_Count (Descriptor.Stride) < Row_Bytes.Count then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      end if;

      Prefix_Rows :=
        Internal.Checked_Arithmetic.Multiply
          (Byte_Count (Descriptor.Stride), Byte_Count (Descriptor.Height - 1));
      if not Results.Succeeded (Prefix_Rows.Outcome) then
         return Prefix_Rows.Outcome;
      end if;

      Last_Row_Start := Prefix_Rows;
      Last_Row_End := Internal.Checked_Arithmetic.Add (Last_Row_Start.Count, Row_Bytes.Count);
      if not Results.Succeeded (Last_Row_End.Outcome) then
         return Last_Row_End.Outcome;
      elsif Last_Row_End.Count > Descriptor.Accessible_Bytes then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      elsif Descriptor.Accessible_Bytes > Encode_Limits.Max_Output_Bytes then
         return Results.Failure (Errors.Output_Limit_Exceeded);
      end if;

      return Results.Success;
   end Validate_Descriptor;

   function Validate_View
     (Input : Images.Image_View;
      Encode_Limits : Limits.Limit_Set) return Results.Result
   is
      Outcome : Results.Result;
   begin
      if Input.Storage = null then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      end if;

      Outcome := Validate_Descriptor (Input.Descriptor, Encode_Limits);
      if not Results.Succeeded (Outcome) then
         return Outcome;
      elsif Byte_Count (Input.Storage'Length) < Input.Descriptor.Accessible_Bytes then
         return Results.Failure (Errors.Frame_Invalid_Definition);
      end if;

      return Results.Success;
   end Validate_View;

   function Same_Descriptor (Left, Right : Images.Image_Descriptor) return Boolean is
     (Left.Width = Right.Width
      and then Left.Height = Right.Height
      and then Left.Format = Right.Format
      and then Left.Stride = Right.Stride
      and then Left.Accessible_Bytes = Right.Accessible_Bytes);

   procedure Fail (Object : in out Encoder; Code : Errors.Error_Code) is
   begin
      if not Errors.Is_Fatal (Object.First_Error) then
         Object.First_Error := Errors.Make (Code);
      end if;
      Object.Current_State := Failed;
   end Fail;

   procedure Fail (Object : in out Encoder; Error : Errors.Error) is
   begin
      if not Errors.Is_Fatal (Object.First_Error) then
         Object.First_Error := Error;
      end if;
      Object.Current_State := Failed;
   end Fail;

   function Is_RGB_Family (Format : Images.Pixel_Format) return Boolean is
     (Format in Images.RGB_24 | Images.BGR_24 | Images.RGBA_32 | Images.BGRA_32);

   function Is_CMYK_Family (Format : Images.Pixel_Format) return Boolean is
     (Format in Images.CMYK_32 | Images.YCCK_32);

   function Is_Arithmetic_DCT_Mode (Mode : Encoding_Mode) return Boolean is
     (Mode in
        Arithmetic_Sequential_DCT | Arithmetic_Differential_Sequential_DCT
        | Hierarchical_Arithmetic_Sequential_DCT | Hierarchical_Arithmetic_Differential_Sequential_DCT);

   function Is_Differential_DCT_Mode (Mode : Encoding_Mode) return Boolean is
     (Mode in
        Differential_Sequential_DCT | Arithmetic_Differential_Sequential_DCT
        | Hierarchical_Differential_Sequential_DCT | Hierarchical_Arithmetic_Differential_Sequential_DCT);

   function Is_Hierarchical_DCT_Mode (Mode : Encoding_Mode) return Boolean is
     (Mode in
        Hierarchical_Sequential_DCT | Hierarchical_Arithmetic_Sequential_DCT
        | Hierarchical_Differential_Sequential_DCT | Hierarchical_Arithmetic_Differential_Sequential_DCT);

   function Is_Huffman_Lossless_Mode (Mode : Encoding_Mode) return Boolean is
     (Mode in
        Lossless_Huffman | Differential_Lossless_Huffman | Hierarchical_Lossless_Huffman
        | Hierarchical_Differential_Lossless_Huffman);

   function Is_Arithmetic_Lossless_Mode (Mode : Encoding_Mode) return Boolean is
     (Mode in
        Arithmetic_Lossless | Arithmetic_Differential_Lossless | Hierarchical_Arithmetic_Lossless
        | Hierarchical_Arithmetic_Differential_Lossless);

   function Is_Differential_Lossless_Mode (Mode : Encoding_Mode) return Boolean is
     (Mode in
        Differential_Lossless_Huffman | Arithmetic_Differential_Lossless
        | Hierarchical_Differential_Lossless_Huffman | Hierarchical_Arithmetic_Differential_Lossless);

   function Is_Hierarchical_Lossless_Mode (Mode : Encoding_Mode) return Boolean is
     (Mode in
        Hierarchical_Lossless_Huffman | Hierarchical_Arithmetic_Lossless
        | Hierarchical_Differential_Lossless_Huffman | Hierarchical_Arithmetic_Differential_Lossless);

   function Supports_Current_Image_Slice
     (Input : Images.Image_View;
      Encode_Options : Options) return Boolean
   is
     ((case Encode_Options.Mode is
        when Sequential_DCT
           | Differential_Sequential_DCT
           | Hierarchical_Sequential_DCT
           | Hierarchical_Differential_Sequential_DCT =>
          Input.Descriptor.Format = Images.Gray_8
          or else Input.Descriptor.Format = Images.Gray_Alpha_16
          or else Is_RGB_Family (Input.Descriptor.Format)
          or else Is_CMYK_Family (Input.Descriptor.Format),
        when Arithmetic_Sequential_DCT
           | Arithmetic_Differential_Sequential_DCT
           | Hierarchical_Arithmetic_Sequential_DCT
           | Hierarchical_Arithmetic_Differential_Sequential_DCT =>
          (if Encode_Options.Progressive = No_Progressive then
             Input.Descriptor.Format = Images.Gray_8
             or else Input.Descriptor.Format = Images.Gray_Alpha_16
             or else Is_RGB_Family (Input.Descriptor.Format)
             or else Is_CMYK_Family (Input.Descriptor.Format)
           else
             (Input.Descriptor.Format = Images.Gray_8
              or else Input.Descriptor.Format = Images.Gray_Alpha_16
              or else Is_RGB_Family (Input.Descriptor.Format)
              or else Is_CMYK_Family (Input.Descriptor.Format))
             and then Encode_Options.Progressive in Balanced_Progressive | Fast_Preview_Progressive),
        when Lossless_Huffman
           | Differential_Lossless_Huffman
           | Hierarchical_Lossless_Huffman
           | Hierarchical_Differential_Lossless_Huffman =>
          (Input.Descriptor.Format = Images.Gray_8
           or else Input.Descriptor.Format = Images.Gray_Alpha_16
           or else Is_RGB_Family (Input.Descriptor.Format)
           or else Is_CMYK_Family (Input.Descriptor.Format))
          and then Encode_Options.Progressive = No_Progressive,
        when Arithmetic_Lossless
           | Arithmetic_Differential_Lossless
           | Hierarchical_Arithmetic_Lossless
           | Hierarchical_Arithmetic_Differential_Lossless =>
          (Input.Descriptor.Format = Images.Gray_8
           or else Input.Descriptor.Format = Images.Gray_Alpha_16
           or else Is_RGB_Family (Input.Descriptor.Format)
           or else Is_CMYK_Family (Input.Descriptor.Format))
          and then Encode_Options.Progressive = No_Progressive));

   function Metadata_Supported (Marker : Marker_Code) return Boolean is
     (Internal.Markers.Is_APP (Marker) or else Marker = Internal.Markers.COM);

   function Internal_Subsampling
     (Subsampling : Chroma_Subsampling) return Internal.Image_Blocks.Subsampling_Layout is
   begin
      case Subsampling is
         when Subsampling_444 =>
            return Internal.Image_Blocks.Subsampling_444;
         when Subsampling_422 =>
            return Internal.Image_Blocks.Subsampling_422;
         when Subsampling_420 =>
            return Internal.Image_Blocks.Subsampling_420;
         when Subsampling_411 =>
            return Internal.Image_Blocks.Subsampling_411;
      end case;
   end Internal_Subsampling;

   function Resolve_Options (Encode_Options : Options) return Options is
      Resolved : Options := Encode_Options;
   begin
      case Encode_Options.Preset is
         when Default_Preset =>
            null;
         when Photo_Preset =>
            Resolved.Quality := 90;
            Resolved.Progressive := Balanced_Progressive;
            Resolved.Subsampling := Subsampling_420;
            Resolved.Optimize_Huffman := True;
         when Graphic_Preset =>
            Resolved.Quality := 92;
            Resolved.Progressive := No_Progressive;
            Resolved.Subsampling := Subsampling_444;
            Resolved.Optimize_Huffman := True;
         when Small_File_Preset =>
            Resolved.Quality := 55;
            Resolved.Progressive := Fast_Preview_Progressive;
            Resolved.Subsampling := Subsampling_420;
            Resolved.Optimize_Huffman := True;
      end case;

      return Resolved;
   end Resolve_Options;

   function Resolve_Target_Options
     (Encode_Options : Options;
      Descriptor : Images.Image_Descriptor) return Options
   is
      Resolved : Options := Encode_Options;
      Pixels : constant Long_Float := Long_Float (Descriptor.Width) * Long_Float (Descriptor.Height);
      Bytes_Per_Pixel_Target : Long_Float := 0.0;
   begin
      if Encode_Options.Target_Bytes = 0 or else not Is_Huffman_Lossless_Mode (Encode_Options.Mode) then
         if Encode_Options.Target_Bytes /= 0 and then Is_Arithmetic_Lossless_Mode (Encode_Options.Mode) then
            return Resolved;
         end if;
      end if;

      if Encode_Options.Target_Bytes = 0
        or else Is_Huffman_Lossless_Mode (Encode_Options.Mode)
        or else Is_Arithmetic_Lossless_Mode (Encode_Options.Mode)
        or else Pixels <= 0.0
      then
         return Resolved;
      end if;

      Bytes_Per_Pixel_Target := Long_Float (Encode_Options.Target_Bytes) / Pixels;
      Resolved.Optimize_Huffman := True;
      if Bytes_Per_Pixel_Target < 0.20 then
         Resolved.Quality := Positive'Min (Resolved.Quality, 20);
         Resolved.Progressive := Fast_Preview_Progressive;
         Resolved.Subsampling := Subsampling_420;
      elsif Bytes_Per_Pixel_Target < 0.35 then
         Resolved.Quality := Positive'Min (Resolved.Quality, 35);
         Resolved.Progressive := Fast_Preview_Progressive;
         Resolved.Subsampling := Subsampling_420;
      elsif Bytes_Per_Pixel_Target < 0.55 then
         Resolved.Quality := Positive'Min (Resolved.Quality, 55);
         if Resolved.Progressive = No_Progressive then
            Resolved.Progressive := Fast_Preview_Progressive;
         end if;
      elsif Bytes_Per_Pixel_Target < 0.80 then
         Resolved.Quality := Positive'Min (Resolved.Quality, 72);
      end if;

      return Resolved;
   end Resolve_Target_Options;

   procedure Initialize
     (Object : in out Encoder;
      Output : not null access Streams.Destination'Class;
      Encode_Options : Options := (others => <>);
      Encode_Limits : Limits.Limit_Set := Limits.Default_Limits) is
   begin
      Object.Output := Output.all'Unchecked_Access;
      Object.Encode_Options := Resolve_Options (Encode_Options);
      Object.Encode_Limits := Encode_Limits;
      Object.First_Error := Errors.Make (Errors.No_Error);
      Object.Image_Is_Defined := False;
      Object.Metadata_Segment_Count := 0;
      Object.Metadata_Bytes := 0;
      Object.Current_State := Initialized;
   end Initialize;

   procedure Reset (Object : in out Encoder; Output : not null access Streams.Destination'Class) is
   begin
      Object.Output := Output.all'Unchecked_Access;
      Object.First_Error := Errors.Make (Errors.No_Error);
      Object.Image_Is_Defined := False;
      Object.Metadata_Segment_Count := 0;
      Object.Metadata_Bytes := 0;
      Object.Current_State := Initialized;
   end Reset;

   function State (Object : Encoder) return Encoder_State is
   begin
      return Object.Current_State;
   end State;

   function Define_Image (Object : in out Encoder; Descriptor : Images.Image_Descriptor) return Results.Result is
      Outcome : Results.Result;
   begin
      if Object.Current_State /= Initialized then
         Fail (Object, Errors.Invalid_State);
         return Results.Failure (Object.First_Error);
      end if;

      Outcome := Validate_Descriptor (Descriptor, Object.Encode_Limits);
      if not Results.Succeeded (Outcome) then
         if not Errors.Is_Fatal (Object.First_Error) then
            Object.First_Error := Outcome.First_Error;
         end if;
         Object.Current_State := Failed;
         return Results.Failure (Object.First_Error);
      end if;

      Object.Descriptor := Descriptor;
      Object.Image_Is_Defined := True;
      Object.Current_State := Image_Defined;
      return Results.Success;
   end Define_Image;

   function Add_Metadata_Segment
     (Object : in out Encoder;
      Marker : Marker_Code;
      Payload : not null Streams.Const_Byte_Array_Access) return Results.Result
   is
      New_Bytes : Byte_Count;
   begin
      if Object.Current_State not in Initialized | Image_Defined | Accepting_Metadata then
         Fail (Object, Errors.Invalid_State);
         return Results.Failure (Object.First_Error);
      elsif not Metadata_Supported (Marker) then
         Fail (Object, Errors.Marker_Unexpected);
         return Results.Failure (Object.First_Error);
      elsif Payload'Length = 0
        or else Byte_Count (Payload'Length) > Object.Encode_Limits.Max_Metadata_Segment_Bytes
      then
         Fail
           (Object,
            Errors.Make
              (Errors.Metadata_Limit_Exceeded,
               (Marker => Marker, Detail => Long_Long_Integer (Payload'Length), others => <>)));
         return Results.Failure (Object.First_Error);
      elsif Object.Metadata_Segment_Count = Metadata.Max_Header_Summaries
        or else Object.Metadata_Segment_Count >= Object.Encode_Limits.Max_Metadata_Segments
      then
         Fail
           (Object,
            Errors.Make
              (Errors.Metadata_Limit_Exceeded,
               (Marker => Marker, Detail => Long_Long_Integer (Object.Metadata_Segment_Count + 1), others => <>)));
         return Results.Failure (Object.First_Error);
      end if;

      if Object.Metadata_Bytes > Object.Encode_Limits.Max_Metadata_Bytes - Byte_Count (Payload'Length) then
         Fail
           (Object,
            Errors.Make
              (Errors.Metadata_Limit_Exceeded,
               (Marker => Marker, Detail => Long_Long_Integer (Payload'Length), others => <>)));
         return Results.Failure (Object.First_Error);
      end if;

      New_Bytes := Object.Metadata_Bytes + Byte_Count (Payload'Length);
      Object.Metadata_Segment_Count := Object.Metadata_Segment_Count + 1;
      Object.Metadata_Segments (Object.Metadata_Segment_Count) :=
        (Marker => Marker, Payload => Payload);
      Object.Metadata_Bytes := New_Bytes;
      Object.Current_State := Accepting_Metadata;
      return Results.Success;
   exception
      when Constraint_Error =>
         Fail (Object, Errors.Internal_Invariant_Failed);
         return Results.Failure (Object.First_Error);
   end Add_Metadata_Segment;

   function Encode_Image (Object : in out Encoder; Input : Images.Image_View) return Results.Result is
      Outcome : Results.Result;
   begin
      if Object.Current_State not in Initialized | Image_Defined | Accepting_Metadata then
         Fail (Object, Errors.Invalid_State);
         return Results.Failure (Object.First_Error);
      end if;

      Outcome := Validate_View (Input, Object.Encode_Limits);
      if not Results.Succeeded (Outcome) then
         if not Errors.Is_Fatal (Object.First_Error) then
            Object.First_Error := Outcome.First_Error;
         end if;
         Object.Current_State := Failed;
         return Results.Failure (Object.First_Error);
      elsif Object.Image_Is_Defined and then not Same_Descriptor (Object.Descriptor, Input.Descriptor) then
         Fail (Object, Errors.Frame_Invalid_Definition);
         return Results.Failure (Object.First_Error);
      end if;

      if not Object.Image_Is_Defined then
         Object.Descriptor := Input.Descriptor;
         Object.Image_Is_Defined := True;
      end if;

      Object.Encode_Options := Resolve_Target_Options (Object.Encode_Options, Input.Descriptor);

      if not Supports_Current_Image_Slice (Input, Object.Encode_Options) then
         Fail (Object, Errors.Unsupported_Feature);
         return Results.Failure (Object.First_Error);
      end if;

      Object.Current_State := Writing_Scans;
      if Is_Huffman_Lossless_Mode (Object.Encode_Options.Mode) then
         if Input.Descriptor.Format = Images.Gray_8 then
            Outcome :=
              Internal.Baseline_Encoder.Encode_Lossless_Gray_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Predictor => Object.Encode_Options.Lossless_Predictor,
                 Point_Transform => Object.Encode_Options.Lossless_Point_Transform,
                 Differential => Is_Differential_Lossless_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_Lossless_Mode (Object.Encode_Options.Mode),
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         elsif Input.Descriptor.Format = Images.Gray_Alpha_16 then
            Outcome :=
              Internal.Baseline_Encoder.Encode_Lossless_Gray_Alpha_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Predictor => Object.Encode_Options.Lossless_Predictor,
                 Point_Transform => Object.Encode_Options.Lossless_Point_Transform,
                 Differential => Is_Differential_Lossless_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_Lossless_Mode (Object.Encode_Options.Mode),
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         elsif Is_CMYK_Family (Input.Descriptor.Format) then
            Outcome :=
              Internal.Baseline_Encoder.Encode_Lossless_CMYK_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Predictor => Object.Encode_Options.Lossless_Predictor,
                 Point_Transform => Object.Encode_Options.Lossless_Point_Transform,
                 Differential => Is_Differential_Lossless_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_Lossless_Mode (Object.Encode_Options.Mode),
                 YCCK => Input.Descriptor.Format = Images.YCCK_32,
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         else
            Outcome :=
              Internal.Baseline_Encoder.Encode_Lossless_RGB_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Predictor => Object.Encode_Options.Lossless_Predictor,
                 Point_Transform => Object.Encode_Options.Lossless_Point_Transform,
                 Differential => Is_Differential_Lossless_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_Lossless_Mode (Object.Encode_Options.Mode),
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         end if;
      elsif Is_Arithmetic_Lossless_Mode (Object.Encode_Options.Mode) then
         if Input.Descriptor.Format = Images.Gray_8 then
            Outcome :=
              Internal.Baseline_Encoder.Encode_Arithmetic_Lossless_Gray_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Predictor => Object.Encode_Options.Lossless_Predictor,
                 Point_Transform => Object.Encode_Options.Lossless_Point_Transform,
                 Differential => Is_Differential_Lossless_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_Lossless_Mode (Object.Encode_Options.Mode),
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         elsif Input.Descriptor.Format = Images.Gray_Alpha_16 then
            Outcome :=
              Internal.Baseline_Encoder.Encode_Arithmetic_Lossless_Gray_Alpha_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Predictor => Object.Encode_Options.Lossless_Predictor,
                 Point_Transform => Object.Encode_Options.Lossless_Point_Transform,
                 Differential => Is_Differential_Lossless_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_Lossless_Mode (Object.Encode_Options.Mode),
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         elsif Is_CMYK_Family (Input.Descriptor.Format) then
            Outcome :=
              Internal.Baseline_Encoder.Encode_Arithmetic_Lossless_CMYK_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Predictor => Object.Encode_Options.Lossless_Predictor,
                 Point_Transform => Object.Encode_Options.Lossless_Point_Transform,
                 Differential => Is_Differential_Lossless_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_Lossless_Mode (Object.Encode_Options.Mode),
                 YCCK => Input.Descriptor.Format = Images.YCCK_32,
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         else
            Outcome :=
              Internal.Baseline_Encoder.Encode_Arithmetic_Lossless_RGB_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Predictor => Object.Encode_Options.Lossless_Predictor,
                 Point_Transform => Object.Encode_Options.Lossless_Point_Transform,
                 Differential => Is_Differential_Lossless_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_Lossless_Mode (Object.Encode_Options.Mode),
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         end if;
      elsif Is_Arithmetic_DCT_Mode (Object.Encode_Options.Mode) then
         if Input.Descriptor.Format = Images.Gray_8
           and then Object.Encode_Options.Progressive in Balanced_Progressive | Fast_Preview_Progressive
         then
            Outcome :=
              Internal.Baseline_Encoder.Encode_Arithmetic_Progressive_Gray_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Quality => Object.Encode_Options.Quality,
                 Refine => Object.Encode_Options.Progressive = Balanced_Progressive,
                 Differential => Is_Differential_DCT_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_DCT_Mode (Object.Encode_Options.Mode),
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         elsif Input.Descriptor.Format = Images.Gray_Alpha_16
           and then Object.Encode_Options.Progressive in Balanced_Progressive | Fast_Preview_Progressive
         then
            Outcome :=
              Internal.Baseline_Encoder.Encode_Arithmetic_Progressive_Gray_Alpha_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Quality => Object.Encode_Options.Quality,
                 Refine => Object.Encode_Options.Progressive = Balanced_Progressive,
                 Differential => Is_Differential_DCT_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_DCT_Mode (Object.Encode_Options.Mode),
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         elsif Is_CMYK_Family (Input.Descriptor.Format)
           and then Object.Encode_Options.Progressive in Balanced_Progressive | Fast_Preview_Progressive
         then
            Outcome :=
              Internal.Baseline_Encoder.Encode_Arithmetic_Progressive_CMYK_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Quality => Object.Encode_Options.Quality,
                 Refine => Object.Encode_Options.Progressive = Balanced_Progressive,
                 Differential => Is_Differential_DCT_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_DCT_Mode (Object.Encode_Options.Mode),
                 YCCK => Input.Descriptor.Format = Images.YCCK_32,
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         elsif Object.Encode_Options.Progressive in Balanced_Progressive | Fast_Preview_Progressive then
            Outcome :=
              Internal.Baseline_Encoder.Encode_Arithmetic_Progressive_YCbCr_Image
                (Object.Output.all,
                 Input,
                 Layout => Internal_Subsampling (Object.Encode_Options.Subsampling),
                 Restart => Object.Encode_Options.Restart,
                 Quality => Object.Encode_Options.Quality,
                 Refine => Object.Encode_Options.Progressive = Balanced_Progressive,
                 Differential => Is_Differential_DCT_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_DCT_Mode (Object.Encode_Options.Mode),
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         elsif Input.Descriptor.Format = Images.Gray_8 then
            Outcome :=
              Internal.Baseline_Encoder.Encode_Arithmetic_Gray_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Quality => Object.Encode_Options.Quality,
                 Differential => Is_Differential_DCT_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_DCT_Mode (Object.Encode_Options.Mode),
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         elsif Input.Descriptor.Format = Images.Gray_Alpha_16 then
            Outcome :=
              Internal.Baseline_Encoder.Encode_Arithmetic_Gray_Alpha_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Quality => Object.Encode_Options.Quality,
                 Differential => Is_Differential_DCT_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_DCT_Mode (Object.Encode_Options.Mode),
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         elsif Is_CMYK_Family (Input.Descriptor.Format) then
            Outcome :=
              Internal.Baseline_Encoder.Encode_Arithmetic_CMYK_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Quality => Object.Encode_Options.Quality,
                 Differential => Is_Differential_DCT_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_DCT_Mode (Object.Encode_Options.Mode),
                 YCCK => Input.Descriptor.Format = Images.YCCK_32,
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         else
            Outcome :=
              Internal.Baseline_Encoder.Encode_Arithmetic_YCbCr_Image
                (Object.Output.all,
                 Input,
                 Layout => Internal_Subsampling (Object.Encode_Options.Subsampling),
                 Restart => Object.Encode_Options.Restart,
                 Quality => Object.Encode_Options.Quality,
                 Differential => Is_Differential_DCT_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_DCT_Mode (Object.Encode_Options.Mode),
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         end if;
      elsif Input.Descriptor.Format = Images.Gray_8 then
         if Object.Encode_Options.Progressive = No_Progressive then
            Outcome :=
              Internal.Baseline_Encoder.Encode_Gray_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Quality => Object.Encode_Options.Quality,
                 Differential => Is_Differential_DCT_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_DCT_Mode (Object.Encode_Options.Mode),
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         else
            Outcome :=
              Internal.Baseline_Encoder.Encode_Progressive_Gray_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Quality => Object.Encode_Options.Quality,
                 Refine => Object.Encode_Options.Progressive = Balanced_Progressive,
                 Optimize_Huffman => Object.Encode_Options.Optimize_Huffman,
                 Differential => Is_Differential_DCT_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_DCT_Mode (Object.Encode_Options.Mode),
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         end if;
      elsif Input.Descriptor.Format = Images.Gray_Alpha_16 then
         if Object.Encode_Options.Progressive = No_Progressive then
            Outcome :=
              Internal.Baseline_Encoder.Encode_Gray_Alpha_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Quality => Object.Encode_Options.Quality,
                 Differential => Is_Differential_DCT_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_DCT_Mode (Object.Encode_Options.Mode),
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         else
            Outcome :=
              Internal.Baseline_Encoder.Encode_Progressive_Gray_Alpha_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Quality => Object.Encode_Options.Quality,
                 Refine => Object.Encode_Options.Progressive = Balanced_Progressive,
                 Differential => Is_Differential_DCT_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_DCT_Mode (Object.Encode_Options.Mode),
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         end if;
      elsif Is_CMYK_Family (Input.Descriptor.Format) then
         if Object.Encode_Options.Progressive = No_Progressive then
            Outcome :=
              Internal.Baseline_Encoder.Encode_CMYK_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Quality => Object.Encode_Options.Quality,
                 Differential => Is_Differential_DCT_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_DCT_Mode (Object.Encode_Options.Mode),
                 YCCK => Input.Descriptor.Format = Images.YCCK_32,
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         else
            Outcome :=
              Internal.Baseline_Encoder.Encode_Progressive_CMYK_Image
                (Object.Output.all,
                 Input,
                 Restart => Object.Encode_Options.Restart,
                 Quality => Object.Encode_Options.Quality,
                 Refine => Object.Encode_Options.Progressive = Balanced_Progressive,
                 Differential => Is_Differential_DCT_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_DCT_Mode (Object.Encode_Options.Mode),
                 YCCK => Input.Descriptor.Format = Images.YCCK_32,
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         end if;
      else
         if Object.Encode_Options.Progressive = No_Progressive then
            Outcome :=
              Internal.Baseline_Encoder.Encode_YCbCr_Image
                (Object.Output.all,
                 Input,
                 Layout => Internal_Subsampling (Object.Encode_Options.Subsampling),
                 Restart => Object.Encode_Options.Restart,
                 Quality => Object.Encode_Options.Quality,
                 Optimize_Huffman => Object.Encode_Options.Optimize_Huffman,
                 Differential => Is_Differential_DCT_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_DCT_Mode (Object.Encode_Options.Mode),
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         else
            Outcome :=
              Internal.Baseline_Encoder.Encode_Progressive_YCbCr_Image
                (Object.Output.all,
                 Input,
                 Layout => Internal_Subsampling (Object.Encode_Options.Subsampling),
                 Restart => Object.Encode_Options.Restart,
                 Quality => Object.Encode_Options.Quality,
                 Refine => Object.Encode_Options.Progressive = Balanced_Progressive,
                 Optimize_Huffman => Object.Encode_Options.Optimize_Huffman,
                 Differential => Is_Differential_DCT_Mode (Object.Encode_Options.Mode),
                 Hierarchical => Is_Hierarchical_DCT_Mode (Object.Encode_Options.Mode),
                 Encoded_Metadata => Object.Metadata_Segments (1 .. Object.Metadata_Segment_Count));
         end if;
      end if;
      if not Results.Succeeded (Outcome) then
         Fail (Object, Outcome.First_Error);
         return Results.Failure (Object.First_Error);
      end if;

      Object.Current_State := Completed;
      return Results.Success;
   end Encode_Image;

   function Finish (Object : in out Encoder) return Results.Result is
   begin
      case Object.Current_State is
         when Completed =>
            return Results.Success;
         when Image_Defined | Accepting_Input | Writing_Scans =>
            Fail (Object, Errors.Invalid_State);
            return Results.Failure (Object.First_Error);
         when others =>
            Fail (Object, Errors.Invalid_State);
            return Results.Failure (Object.First_Error);
      end case;
   end Finish;

   function Last_Error (Object : Encoder) return Errors.Error is
   begin
      return Object.First_Error;
   end Last_Error;

   procedure Cancel (Object : in out Encoder) is
   begin
      if not Errors.Is_Fatal (Object.First_Error) then
         Object.First_Error := Errors.Make (Errors.Operation_Cancelled);
      end if;
      Object.Current_State := Cancelled;
   end Cancel;

   procedure Finalize (Object : in out Encoder) is
   begin
      Object.Output := null;
      Object.Current_State := Finalized;
   end Finalize;
end Jpeglib.Encoding;

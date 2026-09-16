# Limits And Safety Boundaries

This project keeps caller storage ownership explicit. Public image and stream
APIs operate on caller-provided buffers; they do not allocate hidden pixel
buffers for normal decode or encode output.

## Proved Arithmetic Boundary

The SPARK-proved descriptor arithmetic boundary is the descriptor-only image
validation predicate: `Jpeglib.Images.Descriptor_Is_Valid`. That predicate
checks:

- the minimum row byte count for the selected public pixel format
- `Stride >= Minimum_Row_Bytes`
- row-span overflow before multiplying stride by `Height - 1`
- `Accessible_Bytes` reaching the last visible row
- caller storage length covering `Accessible_Bytes`

The runtime-checked access-bearing views, `Image_View` and
`Mutable_Image_View`, are not SPARK-analyzed because they contain anonymous
access components. Their public validators first reject null storage and then
delegate all descriptor arithmetic to `Descriptor_Is_Valid`.

Raw component output is also caller-buffered. `Jpeglib.Decoding` exposes
runtime helpers for that contract because raw output can be either one byte per
sample or two bytes per sample when callers preserve 12-bit precision:

- `Effective_Raw_Output_Precision` derives the output precision from decode
  options and source precision
- `Raw_Bytes_Per_Sample`, `Raw_Minimum_Row_Bytes`, and
  `Raw_Accessible_Bytes` compute row and storage requirements, saturating at
  `Byte_Count'Last` for impossible dimensions
- `Raw_Component_View_Is_Valid` applies the same storage checks used by
  `Decode_Raw_Components`
- `Raw_Sample_Position_Is_Valid` and `Try_Raw_Sample_At` let callers preflight
  or perform packed 8-bit and 16-bit raw sample reads without raising on
  invalid coordinates or short storage

## Runtime-Enforced Boundaries

The release gate keeps runtime tests tied to the proved boundary:
`foundation.images.descriptor_overflow` covers descriptor overflow rejection and
`foundation.decoder.decode_invalid_view` covers public decoder rejection of
invalid caller views before writing pixels.
`foundation.decoder.raw_component_helpers` covers raw high-bit-depth sizing,
view validation, packed sample coordinate validation, byte-order-aware sample
reads, and non-raising sample failures.

High-bit-depth raw caller-buffer behavior is runtime-checked by
`jpeglib_precision_buffer`, covering 12-bit DCT and lossless precision policies,
and by `foundation.decoder.decode_twelve_bit_dct_color`, covering public 12-bit
YCbCr/CMYK DCT image, raw component, and coefficient decode. The matrix also
checks byte order, raw view sizing, saturated oversized-dimension handling,
single-row views with oversized strides, packed sample position validation, and
non-raising packed sample reads.

The public decoder also enforces configured output byte limits before pixel
writes through `foundation.decoder.decode_output_limit`. The public encoder
enforces output destination limits through `foundation.encoder.encode_output_limit`.

Metadata retention is bounded separately from image output. Segment count,
per-segment byte, retained buffer, callback count, and ICC profile byte limits
remain runtime-checked in the metadata invariants.

## `Unchecked_Access` Usage

The library-facing tests and command-line tools use `Unchecked_Access` only to
bind stack-allocated test buffers to the public view and stream APIs. Those
objects outlive the call using the view or stream. Production library code must
not use `Unchecked_Access` to bypass caller-buffer validation; public entry
points must validate descriptors and configured limits before writing.

## External Tools

ImageMagick and `ffmpeg` are conformance oracles only. They are not production
dependencies and do not define library safety boundaries. Required versus
diagnostic external oracle coverage is tracked in
`docs/external_reference_matrix.md`.

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

## Runtime-Enforced Boundaries

The release gate keeps runtime tests tied to the proved boundary:
`foundation.images.descriptor_overflow` covers descriptor overflow rejection and
`foundation.decoder.decode_invalid_view` covers public decoder rejection of
invalid caller views before writing pixels.

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

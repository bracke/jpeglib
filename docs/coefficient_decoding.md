# Public Coefficient Decoding Contract

`Jpeglib.Decoding.Decode_Coefficients` exposes quantized DCT coefficients before
pixel reconstruction. This is the first public decode surface that can become
supported independently of `Decode_Image`.

## Supported Inputs

- 8-bit baseline DCT JPEG streams using Huffman entropy coding.
- Grayscale scans.
- Interleaved color scans.
- Separate baseline color scans where each component is scanned once.
- Restart intervals with the expected marker sequence.
- Covered 8-bit progressive DCT coefficient streams using Huffman entropy
  coding, currently grayscale DC-first, restarted DC-first,
  DC-first-plus-AC-first, interleaved color DC-first scans, and YCbCr
  single-component luma AC-first scans after interleaved DC scans.
- Covered Huffman and arithmetic lossless plus differential-lossless streams
  expose reconstructed source-precision component samples as DC-only
  coefficient blocks, one block per sample, including covered grayscale,
  two-component, YCbCr, RGB, CMYK, and YCCK component sets.
- Public SOF/SOS component counts can represent the JPEG byte ceiling. The
  default `Max_Components` limit remains four, and callers can raise it to
  decode wider Huffman/arithmetic lossless and differential-lossless coefficient
  streams and raw-component streams into supplied component planes.

Progressive pixel reconstruction is covered for the current grayscale DC-only,
grayscale DC+AC multi-scan, Huffman YCbCr/RGB, and arithmetic DC-first
YCbCr/RGB/CMYK/YCCK image scopes. DHP-marked hierarchical streams are covered
for the parsed frame and same-geometry Huffman and arithmetic
differential-lossless continuation frames with zero residual deltas; coefficient
decode, covered grayscale raw/image decode, 2/3/4-component raw decode, and
covered three- and four-component image decode also compose same-geometry
Huffman continuation frames carrying nonzero residual deltas before exposing
DC-only sample blocks, component planes, or pixels. Covered single-component
coefficient/raw/image decode, covered two-component coefficient/raw/gray-alpha
image decode, generated three- and four-component raw decode, and generated
three- and four-component RGB-family image decode also compose same-geometry
arithmetic continuation frames carrying nonzero residual deltas. Duplicate color scan and
incomplete color scan inputs remain unsupported or invalid according to the
parsed structure.

## Fixture Corpus

Managed coefficient fixtures live under `tests/fixtures/coefficients`; managed
image decode fixtures live under `tests/fixtures/images`.

Use:

```sh
alr exec -- tests/bin/jpeglib_fixtures --generate
alr exec -- tests/bin/jpeglib_fixtures --check
```

The fixture tool writes both corpora, verifies their manifests, decodes
coefficient fixtures through the public coefficient API, and decodes image
fixtures through the public image API. Image fixture manifests include SHA-256
digests of the complete decoded output buffer, computed through `cryptolib`.
The coefficient corpus covers baseline grayscale, baseline grayscale with
restart markers, baseline YCbCr 4:2:0, wrong restart marker rejection, and
incomplete separate color scan rejection. The image corpus covers baseline
grayscale, restarted grayscale, restarted baseline YCbCr 4:2:0, interleaved and
separate-scan baseline YCbCr 4:2:0, baseline RGB, interleaved plus separate-scan
plain CMYK pixel decode fixtures, and encoder-generated progressive RGB,
arithmetic progressive RGB, differential DCT RGB, hierarchical DCT RGB,
arithmetic lossless RGB, differential lossless RGB, hierarchical lossless RGB,
arithmetic progressive CMYK/YCCK, and arithmetic lossless CMYK/YCCK image
fixtures pinned by decoded SHA-256 output.
The AUnit suite also reads these files through
`foundation.fixtures.coefficients_valid` and
`foundation.fixtures.coefficients_invalid` plus
`foundation.fixtures.images_valid`, so the corpus is part of the normal test
gate.

## Output Order

Blocks are written in deterministic decode order:

- Grayscale: left-to-right, top-to-bottom block order.
- Interleaved color: MCU order, then component order within each MCU, then each
  component's local horizontal and vertical sampling order.
- Separate color scans: component scan order, with each component written in its
  own left-to-right, top-to-bottom block order.
- Progressive color: entropy is consumed in scan order, while completed blocks
  are exposed in component-major order.
- Lossless and differential-lossless coefficient output: source-precision
  samples are exposed in component-major row-major order as DC-only blocks.

Each block contains 64 quantized coefficients in natural coefficient order, not
zig-zag order.

## Coefficient Transforms

`Jpeglib.Coefficients.Transform` returns a transformed natural-order 8x8 DCT
block. `Jpeglib.Coefficients.Apply_Transform` applies the same operation
in-place.

The public block and image transform scope covers:

- `Identity`
- `Flip_Horizontal`
- `Flip_Vertical`
- `Rotate_180`
- `Transpose`
- `Rotate_90`
- `Rotate_270`
- `Transverse`

`Component_Block_Layout` describes the component-major block grid returned by
public coefficient decoding. `Full_Windows` builds a full-image transform
window, while callers that need lossless block-aligned crops can supply one
`Component_Block_Window` per component. `Transform_Image` validates the layouts
and windows, derives transformed component layouts, remaps component-major
blocks, and applies the coefficient-domain block operation to each moved block
without allocation.

`Transform_Image` reports deterministic status values for mismatched layout
ranges, zero-sized layouts, invalid crop windows, and insufficient input or
output block storage.

`Jpeglib.Coefficients.Encoding.Encode_Grayscale_Baseline` emits a baseline
Huffman grayscale JPEG stream from quantized coefficient blocks.
`Encode_YCbCr_Baseline` emits a baseline Huffman YCbCr JPEG stream from
component-major Y, Cb, and Cr coefficient blocks and layout metadata.
`Encode_Grayscale_Progressive` emits a progressive Huffman grayscale JPEG
stream from quantized coefficient blocks, including AC coefficients.
`Encode_YCbCr_Progressive` emits a progressive Huffman YCbCr JPEG stream from
component-major Y, Cb, and Cr coefficient blocks and layout metadata. These
entry points validate block counts against the image dimensions and component
layouts, reject coefficients outside the baseline encoding range, preserve
restart interval signaling, and are covered by public encode/decode coefficient
round-trip tests. Set `Optimize_Huffman => True` to emit coefficient-derived
DHT tables instead of the standard Huffman tables; the option is covered by
baseline grayscale and YCbCr coefficient round trips. Progressive refinement
coefficient output keeps standard tables for refinement scans.

## State Transitions

`Decode_Coefficients` is valid only from `Initialized` or `Header_Ready`.

- From `Initialized`, the decoder reads the structural header and coefficient
  scan data in one call.
- From `Header_Ready`, the decoder continues from the saved scan state produced
  by `Read_Header`.
- On success, the decoder enters `Completed`.
- On failure, the decoder enters `Failed` and `Last_Error` matches the returned
  result's first error.

Calling from any other state fails with `Invalid_State`.

## Output Storage

The caller owns the `DCT_Block_Array`. The array must contain at least
`Header.Coefficient_Blocks` elements for the image being decoded.

If the array is too small:

- the call fails with `Output_Limit_Exceeded`;
- `Blocks_Decoded` is zero;
- existing caller storage is left unchanged;
- the decoder enters `Failed`.

On success, `Blocks_Decoded` is the number of blocks written.

## Restart Behavior

When `DRI` declares a nonzero restart interval:

- the decoder resets DC predictors at restart boundaries;
- restart markers must appear in the expected modulo-8 sequence;
- wrong, missing, or misplaced restart markers fail deterministically.

## Error Behavior

Malformed coefficient input must return a `Jpeglib.Results.Failure` with a
stable `Jpeglib.Errors.Error_Code`. Public coefficient decoding must not raise
exceptions for malformed JPEG bytes, undersized output storage, truncated
streams, missing tables, invalid scan parameters, invalid Huffman symbols, or
restart marker errors.

Current public AUnit contract coverage:

- `foundation.decoder.public_coefficients`
- `foundation.decoder.public_coefficients_after_header`
- `foundation.decoder.public_progressive_coefficients`
- `foundation.decoder.public_progressive_coefficients_after_header`
- `foundation.decoder.public_progressive_coefficients_restart`
- `foundation.decoder.public_progressive_coefficients_interleaved_color`
- `foundation.coefficients.public_transforms`
- `foundation.coefficients.public_image_transforms`
- `foundation.coefficients.public_encode_grayscale_baseline`
- `foundation.coefficients.public_encode_grayscale_progressive`
- `foundation.coefficients.public_encode_ycbcr_baseline`
- `foundation.coefficients.public_encode_ycbcr_progressive`
- `foundation.decoder.public_coefficients_small_output`
- `foundation.decoder.public_coefficients_invalid_state`
- `foundation.decoder.public_coefficients_restart_wrong_marker`
- `foundation.decoder.public_coefficients_incomplete_color_scans`
- `foundation.fixtures.coefficients_valid`
- `foundation.fixtures.coefficients_invalid`
- `foundation.fixtures.images_valid`

## Capability Flag

`Jpeglib.Capabilities.Coefficients` is `True` for this contract: public access
to quantized DCT coefficients from supported Huffman-coded streams.
`Jpeglib.Capabilities.Coefficient_Transforms` is `True` for the public
block-level transform operations documented above.
`Jpeglib.Capabilities.Baseline_Decode` is also `True` for the current baseline
image scope: grayscale, YCbCr, RGB, and plain CMYK Huffman-coded image decode.
Progressive coefficient extraction is partially covered as described above, and
`Jpeglib.Capabilities.Progressive_Decode` is `True` for the current progressive
grayscale, YCbCr, and RGB image-decode scope.

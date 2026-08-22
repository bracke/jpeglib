# jpeglib Implementation Plan

This plan records the completed V1 path for `jpeglib` as a usable Ada JPEG
codec. It follows the dependency order from `docs/ai_implementation_guide.md`:
bytes, arithmetic, markers, segments, tables, entropy, coefficients, transforms,
sampling, color, metadata, recovery, then public orchestration.

## Current V1 Baseline

- Root library builds with `alr build`.
- Test crate builds with `alr --chdir tests build`.
- Foundation AUnit suite passes with 372 tests.
- Header parsing, coefficient/raw/image decoding, and public image encoding are
  implemented for the V1 API surface.
- Public `Decode_Image` supports baseline grayscale, YCbCr, RGB JPEG, plain CMYK,
  YCCK, progressive grayscale/YCbCr/RGB, arithmetic, differential, lossless,
  hierarchical, 12-bit byte-output, reduced-output, metadata, and orientation
  paths described in the invariants.
- Public `Encode_Image` supports the V1 mode/format matrix for `Gray_8`,
  `Gray_Alpha_16`, `RGB_24`, `BGR_24`, `RGBA_32`, `BGRA_32`, `CMYK_32`, and
  `YCCK_32`, including
  sequential, arithmetic sequential, differential, hierarchical, Huffman
  lossless, arithmetic lossless, differential lossless, and hierarchical
  lossless modes subject to the documented lossless-progressive policy, with
  CMYK/YCCK covered across the DCT and lossless mode families.
- Capability flags in `Jpeglib.Capabilities` advertise the completed V1 surface:
  baseline/progressive decode and encode, Huffman and arithmetic coding,
  12-bit DCT byte-output decode, lossless JPEG, hierarchical JPEG,
  grayscale/YCbCr/RGB/CMYK/YCCK color paths, restart intervals, raw components,
  coefficients, reduced IDCT, Exif orientation, ICC preservation, and
  coefficient transforms.
  Public component counts now use the JPEG SOF/SOS byte ceiling, while the
  default decode limits still cap accepted streams at four components; callers
  can opt into wider raw-component decode by raising `Max_Components`.
  Advanced SOF frame families are represented in public header information,
  including 12-bit-capable, lossless predictor/point-transform metadata,
  differential, arithmetic, and hierarchical-header variants.
  V1 capability flags are enabled for the covered arithmetic coding, 12-bit DCT,
  lossless JPEG, and hierarchical JPEG scopes.
  SOF1 extended sequential 8-bit grayscale streams now decode through public
  coefficient and image entry points. SOF1 extended sequential 12-bit grayscale
  streams now decode through public image and raw component entry points with
  precision-aware byte-output scaling. SOF3 lossless Huffman 8-bit grayscale
  image and raw component decode now reconstruct predictor-1 through
  predictor-7 scans, including nonzero category-bit deltas and restart marker
  predictor resets, through initialized and header-ready public image/raw entry
  points. SOF3 lossless Huffman 8-bit YCbCr, RGB, CMYK, and YCCK image/raw
  component decode now reconstruct covered interleaved and separate
  multi-component scans, with RGB and YCCK separate scans also covered through
  public coefficient reconstruction, and sampled separate two-, three-, and four-component
  Huffman/arithmetic lossless scans now reconstruct through public coefficient and raw
  component output at parsed component dimensions, including opt-in five-component
  baseline, progressive, arithmetic sequential/progressive, and
  Huffman/arithmetic differential sequential/progressive DCT coefficient/raw
  decode, opt-in 255-component baseline/arithmetic sequential DCT,
  Huffman/arithmetic progressive and differential-progressive DC-first DCT,
  DHP-marked Huffman/arithmetic hierarchical sequential DCT, plus
  same-geometry Huffman/arithmetic differential sequential DCT continuation
  coefficient composition with covered single-component Huffman/arithmetic
  raw/image reconstruction, covered three-component arithmetic coefficient/raw/image
  reconstruction for unit-sampled component geometry, and covered three-component
  Huffman 4:2:0 coefficient/raw/image reconstruction using separate
  one-component base/residual continuation scans,
  plus Huffman/arithmetic lossless and differential-lossless SOF2/SOF3/SOF6/SOF7/SOF9/SOF10/SOF11/SOF14/SOF15
  coefficient/raw decode,
  interleaved and separate-scan SOF3/SOF7/SOF11/SOF15 coefficient and raw-component decode,
  plus DHP-marked five-component and 255-component Huffman/arithmetic
  hierarchical lossless SOF3/SOF7/SOF11/SOF15 coefficient/raw reconstruction
  when caller limits are raised.
  SOF3 lossless Huffman 12-bit grayscale, YCbCr, RGB, CMYK, and YCCK image/raw component decode
  now retain source-precision predictor state and scale byte output. SOF11 lossless
  arithmetic 8/12-bit grayscale, YCbCr, RGB, CMYK, and YCCK image/raw
  component decode now reconstruct covered scans through the arithmetic
  DC-difference path with source-precision byte-output scaling, including
  separate-scan 8-bit YCbCr, RGB, and YCCK raw, coefficient, and image reconstruction,
  plus sampled interleaved Huffman/arithmetic YCCK lossless raw, coefficient, and image reconstruction.
  Public `Encode_Image` now offers an explicit `Lossless_Huffman` mode for the
  covered 8-bit grayscale, RGB-family, CMYK, and YCCK SOF3 slices, including configurable
  predictor selections 1 through 7 with same-format CMYK/YCCK predictor round-trips,
  all point-transform values `0 .. 7` for
  covered grayscale, gray-alpha, RGB-family, CMYK, and YCCK output, optional restart markers,
  direct RGB-family and CMYK/YCCK input reading, and public decoder coverage; progressive lossless requests fail
  deterministically across representative grayscale and direct CMYK/YCCK inputs.
  Public Huffman progressive SOF2 encode also covers direct full-resolution
  CMYK/YCCK fast-preview/balanced four-component streams with deterministic
  per-channel nonzero AC coverage and a 24-scan two-bitplane balanced script.
  Public `Encode_Image` now also exposes `Arithmetic_Sequential_DCT` for the
  covered 8-bit grayscale SOF9/DAC slice, two-component `Gray_Alpha_16`
  SOF9/DAC slice, RGB-family SOF9/DAC color slices, and CMYK/YCCK
  SOF9/SOF10/DAC four-component DCT slices, including
  zero-coefficient gray-alpha/RGB/BGR/RGBA/BGRA output, deterministic nonzero
  AC single-block grayscale plus luma/Cb/Cr color patterns, single-block
  restart intervals beyond 1, restarted grayscale multi-block scans, restarted
  4:4:4/4:2:2/4:2:0/4:1:1 color scans, and public arithmetic decoder
  round-trip coverage.
  Public arithmetic progressive SOF10/DAC encode covers grayscale
  fast-preview streams and six-scan two-bitplane balanced streams,
  two-component `Gray_Alpha_16`
  fast-preview streams and 12-scan two-bitplane balanced streams with shared
  arithmetic state across component scans and deterministic nonzero gray/alpha
  AC single-block patterns, and
  RGB-family flat fast-preview streams, 18-scan two-bitplane balanced color
  streams, and deterministic nonzero luma, Cb, and Cr AC single-block patterns
  at quality 100, as well as
  direct full-resolution CMYK/YCCK fast-preview/balanced four-component
  streams with deterministic per-channel DC and nonzero AC coverage.
  Public `Encode_Image` now also exposes `Arithmetic_Lossless` for the covered
  8-bit grayscale, RGB-family, CMYK, and YCCK SOF11/DAC slices, including zero-difference
  output, exhaustive 8-bit grayscale first-sample and non-restarted
  second-sample differences across `-128 .. 127`, exhaustive two-component
  gray-alpha and RGB-family single-component first-sample and non-restarted
  second-sample differences across `-128 .. 127`, predictor selections 1 through 7 for
  `BGR_24`/`RGBA_32`/`BGRA_32` RGB-family input layouts and restarted same-format
  CMYK/YCCK predictor round-trips, all point-transform
  values `0 .. 7` for grayscale, gray-alpha, and RGB output, optional restart
  markers for multi-sample scans, CMYK/YCCK direct four-component sample input, and public arithmetic lossless decoder
  round-trip coverage.
  Public `Encode_Image` now also exposes `Differential_Lossless_Huffman` and
  `Arithmetic_Differential_Lossless` for the covered 8-bit grayscale,
  two-component `Gray_Alpha_16`, RGB-family, CMYK, and YCCK non-hierarchical SOF7/SOF15
  slices, reusing the lossless predictor-coded sample paths and round-tripping
  through the public differential-lossless decoder, including restarted
  same-format CMYK/YCCK output.
  Public `Encode_Image` now also exposes `Differential_Sequential_DCT` and
  `Arithmetic_Differential_Sequential_DCT` for the covered 8-bit grayscale,
  two-component `Gray_Alpha_16`, RGB-family, CMYK, and YCCK
  SOF5/SOF6/SOF13/SOF14 DCT slices, reusing the existing Huffman/arithmetic
  sequential and progressive DCT scan writers and round-tripping through the
  public differential DCT decoder, including direct per-channel nonzero AC
  coverage for full-resolution CMYK/YCCK output. Non-differential Huffman and
  arithmetic hierarchical sequential DCT encode emits DHP, the covered
  SOF0/SOF9 base frame, and an explicit same-geometry SOF5/SOF13 zero-residual
  continuation frame for grayscale, gray-alpha, RGB-family, CMYK, and YCCK
  output. Arithmetic sequential single-component scan decode consumes the
  MCU-padded component extent so separate scans match the advertised frame
  block geometry for subsampled color. Arithmetic progressive color decode now
  keeps Huffman separate-scan visible component ordering distinct from
  arithmetic progressive padded component storage, so subsampled SOF10
  fast-preview/balanced output with restarted separate component scans can
  round-trip without changing established Huffman fixture layout.
  Covered single-frame SOF5/SOF6/SOF13/SOF14 differential DCT grayscale streams
  now reconstruct through public coefficient, raw component, and image decode
  from initialized and header-ready decoder states. Covered SOF5/SOF6 Huffman
  YCbCr/RGB/CMYK/YCCK streams and covered SOF13/SOF14 arithmetic YCbCr/RGB/CMYK/YCCK
  DCT streams do the same from initialized and header-ready decoder states,
  including SOF14 arithmetic YCbCr luma, RGB red-channel, and CMYK/YCCK
  C-channel AC detail through coefficient, raw, and image reconstruction.
  Covered non-hierarchical
  SOF7/SOF15 grayscale, YCbCr, RGB, CMYK, and YCCK differential lossless
  coefficient, raw component, and image decode now reconstruct predictor-coded
  samples through the lossless path, including 12-bit grayscale SOF7/SOF15
  coverage.
  Covered DHP-marked hierarchical JPEG streams are now reconstructed through
  public coefficient, raw component, and image decode while preserving
  hierarchical header reporting, including single-frame hierarchical streams
  from initialized and header-ready decoder states, same-geometry Huffman and
  arithmetic differential-lossless continuation frames with zero residual
  deltas from initialized and header-ready decoder states,
  same-geometry Huffman/arithmetic differential sequential and progressive DCT
  continuation coefficient composition from initialized decoder state with covered
  Huffman/arithmetic raw/image reconstruction, plus public
  coefficient, grayscale raw/image, 2/3/4-component raw, and covered
  three-component image composition for same-geometry Huffman continuation
  frames carrying nonzero residual deltas from initialized and header-ready
  decoder states, including sampled four-component coefficient continuation
  geometry, raw-component output, image output, and separate one-component
  continuation scans with duplicate/incomplete continuation rejection, plus generated
  single-component, two-component,
  three-component, and four-component arithmetic continuation coverage carrying
  nonzero residual deltas from initialized and header-ready decoder states,
  including sampled four-component separate one-component continuation scans
  through coefficient, raw-component, and image decode with duplicate/incomplete
  continuation rejection.
  Arithmetic DAC conditioning-table parsing, the binary arithmetic decision
  decoder, DC difference decoding, AC EOB decoding, the DC/EOB block path, the
  sequential AC block loop for deterministic nonzero coefficients, the internal
  single-component DC/EOB scan path, the internal sequential scan path,
  including covered interleaved color traversal, exact DAC conditioning table
  emission, and SOF9/SOF10/SOF11 arithmetic frame emission used by the covered
  arithmetic encode paths are implemented.
  SOF10 arithmetic progressive DC-first/refine, nonzero AC-first, and
  AC-refine grayscale including arithmetic magnitude-ladder newly nonzero
  coefficients, YCbCr coefficient AC-first, plus DC-first YCbCr, RGB, CMYK,
  and YCCK coefficient, image, and raw component decode is covered through the
  progressive coefficient decoder.
  SOF9 headers now report
  arithmetic entropy, internal SOF9 coefficient decode is covered for the
  current sequential scope, and public coefficient decode dispatches that
  covered arithmetic scope from initialized, header-ready, restarted, and
  separate color scan entry points while rejecting undersized caller block
  buffers before entropy decode.
  Public grayscale, restarted grayscale image, separate color image, and raw component decode also
  reconstruct that covered arithmetic scope from initialized, header-ready,
  restarted image, restarted raw component, separate color image, and separate color raw
  component entry points, and missing
  DAC tables, including partial DC-only or AC-only DAC state, from initialized
  and covered header-ready coefficient entry points, and missing
  quantization tables are rejected deterministically before reporting decoded
  public blocks or writing caller image/raw output across the covered public
  arithmetic paths, including covered header-ready missing-DAC, partial-DAC, and
  missing-DQT image/raw failure entries.
  Arithmetic coding is advertised for the covered sequential DCT decode scopes.
  Coefficient transforms are advertised for public block-level flips, rotations,
  transpose, and transverse operations. Reduced public image output is
  advertised for opt-in DCT, covered Huffman/arithmetic grayscale, YCbCr,
  RGB, and YCCK lossless scaled output, plus covered SOF7/SOF15 differential
  lossless and DHP-marked hierarchical lossless scaled output, YCCK is
  advertised for Adobe APP14 transform 2 decode, raw
  component access is advertised for caller-buffered reconstructed component
  planes; ICC preservation is advertised for the implemented bounded APP2
  fragment assembly scope, and Exif orientation is advertised for bounded
  APP1/TIFF parsing plus opt-in decode coordinate application.
- `jpeglib_check` is the aggregate gate; conformance, fuzz, docs, proof, and
  release workflows are wired through the tests/tooling crate.
- Root Alire toolchain state is pinned through the crate configuration:
  `alr exec -- gnatls --version` should report GNAT 15.

## Phase 0: Toolchain and Project Gates

Goal: make the development environment reproducible before adding codec
behavior.

Status: implemented for the current foundation gate.

Completed:

- The root crate depends on `gnat_native = "^15"` and the tests crate runs
  through Alire, so `alr exec -- gnatls --version` reports the pinned GNAT.
- Root and tests lockfiles are generated through Alire.
- `jpeglib_check` is the local aggregate gate for root build, tests build, and
  the foundation AUnit test runner.
- `README.md` and `CONTRIBUTING.md` document the canonical Alire commands.
- The tests crate uses AUnit, `../project_tools` for test/release policy, and
  `../hostkit` for host-specific process execution.

Exit criteria:

- Root and tests crates both use pinned GNAT 15 through Alire.
- `jpeglib_check` exits successfully only when the build and foundation tests
  pass.

## Phase 1: Lock Down Coefficient Decoding

Goal: make baseline coefficient decoding a supported public feature with known
limits and known-answer coverage.

Status: implemented for the current coefficient scope. The public contract is
documented in `docs/coefficient_decoding.md`; the managed fixture corpus lives
under `tests/fixtures/coefficients`; `Jpeglib.Capabilities.Coefficients` is
enabled. Baseline image decode is advertised for grayscale, YCbCr, RGB, and plain
CMYK `Decode_Image` paths covered in Phase 2.

Completed:

- Define the exact public contract for `Decode_Coefficients`, including block
  order, restart behavior, partial-output failure behavior, and state
  transitions.
- Add known-answer fixtures for tiny grayscale and color baseline JPEGs.
- Add malformed-input tests for missing tables, bad scan parameters, bad restart
  markers, truncated entropy streams, invalid Huffman symbols, and block output
  exhaustion.
- Confirm interleaved and non-interleaved baseline scans produce deterministic
  block order.
- Update `Jpeglib.Capabilities.Coefficients` after the contract and tests are
  stable. Keep broader baseline/Huffman/color flags conservative until the full
  `Decode_Image` surface is implemented.

Exit criteria:

- Public coefficient decoding is intentionally supported, documented, and
  covered by fixtures.
- All coefficient decode failures return deterministic `Jpeglib.Errors` values
  without exceptions or unbounded reads.

## Phase 2: Pixel Reconstruction for Baseline Decode

Goal: implement `Decode_Image` for 8-bit baseline JPEGs.

Status: implemented for the current baseline scope.
`Jpeglib.Internal.Transforms` provides dequantization, DC-only reconstruction,
and a deterministic fixed-point full 8x8 inverse DCT.
`Jpeglib.Internal.Sampling` provides component block placement, edge clipping,
and image-to-component coordinate mapping for sampled baseline frames.
`Jpeglib.Internal.Colors` writes grayscale, direct RGB, plain CMYK, and YCbCr
samples to the public output formats with deterministic fixed-point conversion
and alpha fill.
Public `Decode_Image` decodes baseline grayscale JPEGs with DQT, SOF0, DHT, SOS,
and EOI into the supported public output layouts. It also reconstructs 3-component
YCbCr baseline frames through temporary component planes, subsampled lookup, and
the RGB/BGR/RGBA/BGRA output writer. RGB-tagged baseline frames are reconstructed
through the same component-plane pipeline and written as direct RGB channels.
Plain CMYK baseline frames are reconstructed through four component planes and
converted to RGB-family output with deterministic subtractive conversion.
Three- and four-component baseline image decode handle both interleaved
MCU-order scans and separate component scan order.
Public tests cover representative output layouts plus invalid image views,
output byte limits, and missing quantization tables. Restart-backed grayscale
and YCbCr image decode are covered. Adobe APP14 transform 2 YCCK decode is
covered through header inference, four-component reconstruction, and RGB-family
output conversion. Reduced-size decode output is covered for the opt-in scaling
path. Progressive grayscale DC-only, progressive grayscale DC+AC multi-scan,
4:4:4 YCbCr, 4:2:0 YCbCr, and direct RGB image decode are covered for the
current SOF2 coefficient scopes.
Managed image decode fixtures live under `tests/fixtures/images`; they are
generated and checked by `jpeglib_fixtures` alongside the coefficient corpus and
include `cryptolib` SHA-256 digests of the full decoded output. The corpus also
pins encoder-generated progressive RGB, arithmetic progressive RGB,
differential DCT RGB, hierarchical DCT RGB, arithmetic lossless RGB,
differential lossless RGB, hierarchical lossless RGB, arithmetic progressive
CMYK/YCCK, and arithmetic lossless CMYK/YCCK streams so advanced encode/decode
paths are covered by the fixture gate, not only by AUnit.

Completed:

- Add an internal transform layer for dequantization and integer IDCT.
- Add a sampling layer for MCU layout, component block placement, edge clipping,
  and common subsampling ratios: 4:4:4, 4:2:2, and 4:2:0.
- Add color conversion for grayscale, YCbCr to RGB/BGR/RGBA/BGRA, RGB JPEG, and
  CMYK where the current API can express the output.
- Validate `Images.Mutable_Image_View` dimensions, stride, and accessible bytes
  before writing output.
- Thread resource limits through allocation, MCU buffers, and output-size
  calculations.
- Preserve strict state behavior: `Initialized` or `Header_Ready` to `Decoding`
  to `Completed`, with deterministic failure on invalid state or unsupported
  input.

Exit criteria:

- `Decode_Image` decodes baseline grayscale, restarted YCbCr, interleaved and
  separate-scan YCbCr, RGB JPEG, plain CMYK JPEGs, and covered two-component
  DCT JPEGs into `Gray_8`, `Gray_Alpha_16`, `RGB_24`, `BGR_24`, `RGBA_32`, and
  `BGRA_32` outputs.
- Pixel tests compare against known-answer hashes or exact fixtures with clear
  tolerances for IDCT rounding.
- `Jpeglib.Capabilities.Baseline_Decode`, `Huffman_Coding`, `Grayscale`,
  `YCbCr`, `RGB_JPEG`, `CMYK`, `Restart_Intervals`, and relevant output flags
  are updated.

## Phase 3: Metadata Retention and Streaming Semantics

Goal: make metadata behavior useful and predictable without compromising memory
limits.

Status: implemented for the V1 metadata scope. Header parsing now records
bounded metadata summaries according to the public metadata policy and classifies
COM, JFIF, JFXX, Exif, XMP,
Extended XMP, ICC, Photoshop APP13, and Adobe APP14 from marker-local prefix
bytes without retaining full payloads. `Discard_All` suppresses retained summaries, the
default policy retains only known summary kinds, and `Preserve_All_Bounded`
also retains unknown APP summaries. Segment count, per-segment byte, total
metadata byte, and retained summary cap behavior are tested against
`Jpeglib.Limits`. `Preserve_Known`, `Preserve_Selected`, and
`Preserve_All_Bounded` can retain payload bytes into a caller-supplied metadata
buffer, with summary offsets and retained lengths pointing into that buffer.
ICC APP2 retention strips the 14-byte ICC control header and appends profile
payload bytes in fragment sequence order for well-formed in-order streams.
`Preserve_Selected` uses `Decoding.Options.Selected_Metadata` to select the
metadata kinds to summarize and retain. `Stream_To_Callback` emits
begin/data/end metadata events through the public callback hook and enforces
`Max_Metadata_Callbacks`.
Fragmented ICC APP2 profile payloads are counted into
`Image_Info.ICC_Profile_Bytes` after excluding the APP2 ICC control header, with
fragment counters, checked against `Max_ICC_Profile_Bytes`, and validated for
duplicate, out-of-order, or incomplete fragment sequences.
Encoder-side metadata emission accepts queued APPn and COM payloads through
`Jpeglib.Encoding.Add_Metadata_Segment`, enforces metadata segment count,
per-segment byte, and total metadata byte limits, then writes those segments
after SOI and before generated JFIF/tables.
Segment skipping tolerates short positive skip progress, and fixed-buffer
destinations report partial writes with byte counts and output limit errors.
Decoder and encoder cancellation/finalization states are covered as terminal
public API states, including preservation of the first cancellation error.

Completed:

- Expand metadata policies beyond `Discard_All` and bounded summaries where the
  public API requires retained payloads. Caller-buffer retention and
  `Stream_To_Callback` are implemented for bounded payload access.
- Add bounded retention for APPn and COM segments, including Exif and ICC
  handling if they remain V1 goals. ICC fragment byte accounting and
  ICC-specific limit enforcement are covered.
- Define behavior for duplicate, oversized, and fragmented ICC metadata.
  Fragmented ICC profile payloads are counted and retained without the APP2
  control header, oversized aggregate profiles fail, and duplicate,
  out-of-order, or incomplete fragment sequences fail deterministically.
- Ensure stream sources and destinations handle short reads, zero progress,
  cancellation, and finalization consistently. Short positive segment skips,
  zero-progress reads, and fixed-buffer destination capacity failures are
  covered. Decoder and encoder cancellation/finalization state behavior is
  covered.

Exit criteria:

- Metadata policies are documented and tested against limit enforcement.
- Metadata handling never bypasses `Jpeglib.Limits`.

## Phase 4: Baseline Encoding

Goal: implement `Encode_Image` and `Finish` for 8-bit baseline JPEG output.

Status: implemented for the current public V1 encoder surface. `Define_Image` now validates descriptor geometry and configured
limits before accepting an encode job. Width, height, aggregate pixel count,
stride, accessible byte span, and output byte limits fail deterministically and
leave the encoder in `Failed`; valid descriptors transition to `Image_Defined`.
`Encode_Image` validates its storage-backed `Image_View`, rejects descriptor
mismatches, and routes the covered grayscale, gray-alpha, and RGB-family slices
through the selected baseline, progressive, arithmetic, or lossless writer while
preserving deterministic results for invalid option combinations.
`Jpeglib.Internal.Writers` provides tested marker, length-bearing segment, JFIF
APP0, 8-bit DQT, DHT, grayscale SOF0/SOS, and entropy byte-stuffing output
primitives for the encoder path.
`Jpeglib.Internal.Bit_Streams` also provides a tested MSB-first entropy bit
writer with deterministic byte flushing and `FF` stuffing.
The entropy bit writer can flush pending entropy bits and emit restart markers
without exposing its destination.
Compiled Huffman tables can emit canonical symbol codes through that bit writer
and reject missing symbols deterministically.
Standard JPEG baseline luminance DC and AC Huffman table definitions are
available internally and are emitted by the grayscale encoder path.
Baseline block coefficient emission now handles DC difference categories,
amplitude bits, AC zero runs, ZRL, EOB, and predictor updates against compiled
Huffman tables.
Non-restarted grayscale baseline scan emission now traverses component blocks,
carries DC predictors across blocks, flushes entropy bytes, and rejects missing
Huffman tables deterministically.
Restarted grayscale baseline scan emission resets DC predictors at restart
interval boundaries, byte-aligns entropy output, and emits sequenced RST markers.
`Jpeglib.Internal.Transforms` now provides deterministic DC-only and full
forward DCT paths. The full forward DCT uses the same cosine scale as the
inverse transform and emits natural-order quantized coefficients.
`Jpeglib.Internal.Image_Blocks` now maps storage-backed `Gray_8` images to
row-major quantized DCT blocks for the encoder path, including required block
counts, replicated right/bottom edge padding, and selectable DC-only or
full-forward transforms.
`Jpeglib.Internal.Baseline_Encoder` now writes complete deterministic baseline
grayscale JPEG streams using full-forward DCT blocks, including SOI, JFIF APP0,
DQT, DHT, SOF0, optional DRI, SOS, entropy data, restart markers, and EOI.
Generated streams are round-tripped through the existing public decoder tests.
Baseline luminance and chrominance quantization table generation now honors
`Options.Quality` with deterministic JPEG quality scaling and clamps emitted
tables to 8-bit baseline values. The grayscale encoder uses the luminance table
for both DQT output and block quantization.
  Public `Encode_Image` now uses writer paths for `Gray_8`, `Gray_Alpha_16`,
RGB-family inputs, and lossless CMYK/YCCK inputs, including configured quality, subsampling where applicable,
restart intervals, and queued APP/COM metadata segments, and completes the
encoder on success. It also writes grayscale, `Gray_Alpha_16`, and RGB-family
progressive SOF2 streams for the current Huffman script slices, covered
arithmetic sequential SOF9/DAC streams for grayscale, `Gray_Alpha_16`, and
RGB-family inputs, plus covered arithmetic progressive SOF10/DAC streams for
grayscale, `Gray_Alpha_16`, and RGB-family flat/nonzero-AC patterns.
The current public pixel-format enum is covered by those encoder slices where
each format has a public mode family;
the AUnit gate includes a public mode/format matrix that requires every V1
encoding mode to same-format round-trip `Gray_8`, `Gray_Alpha_16`, `RGB_24`,
`BGR_24`, `RGBA_32`, and `BGRA_32`, with all DCT progressive-script choices,
and also requires `CMYK_32` and `YCCK_32` same-format round trips across all
lossless and DCT mode families, including balanced and fast-preview
progressive scripts. The matrix keeps the non-progressive lossless policy and
alpha-fill behavior for alpha channels not carried by JPEG color output
pinned. A companion metadata matrix requires queued COM
metadata to be emitted and retained through public header decode for every V1
encoding mode under the same script policy. Progressive-script lossless requests are rejected as option-policy errors across
the public lossless mode family.
Writer output-limit failures propagate through the public encoder and leave it
in `Failed`.
Encoder-side color primitives now read Gray/RGB/BGR/RGBA/BGRA input storage into
direct RGB triples and convert RGB to YCbCr with deterministic fixed-point JPEG
conversion.
`Jpeglib.Internal.Image_Blocks` now fills full-resolution row-major Y, Cb, and
Cr component planes from storage-backed RGB-family input and rejects undersized
plane buffers deterministically.
It also provides deterministic component-plane downsampling by averaging
row-major source regions into clipped target planes, including odd image edges
and output-limit failures.
Chroma subsampling layout helpers now compute 4:4:4, 4:2:2, 4:2:0, and 4:1:1
component dimensions and apply paired Cb/Cr downsampling through the generic
plane downsampler.
Explicit component planes can now be converted to row-major DCT blocks with
right/bottom edge replication and deterministic short-buffer rejection.
`Jpeglib.Internal.Baseline_Encoder` can now write complete internal YCbCr
baseline JPEG streams: it emits luma/chroma DQT and DHT tables, pads component
planes to the MCU grid, emits interleaved scan entropy, and round-trips through
the public decoder. Public RGB-family `Encode_Image` now routes through that
baseline YCbCr path.

Completed:

- Validate `Images.Image_View` descriptors and input formats. Descriptor
  validation is implemented for `Define_Image`; storage-backed `Image_View`
  validation and descriptor matching are implemented for `Encode_Image`.
- Implement RGB/gray input conversion to component planes. RGB-family sample
  reading, RGB-to-YCbCr conversion, and full-resolution Y/Cb/Cr plane assembly
  are implemented and tested. Generic component-plane downsampling is
  implemented and tested, and chroma layout helpers cover 4:4:4, 4:2:2, 4:2:0,
  and 4:1:1 dimensions plus paired Cb/Cr downsampling.
- Implement downsampling for configured subsampling modes.
- Implement forward DCT, quantization table generation from `Quality`, zig-zag
  ordering, and baseline Huffman entropy writing. Luminance and chrominance
  quality-scaled quantization table generation is implemented and tested.
- Write SOI, queued APP/COM metadata, DQT, SOF0/SOF2, DHT, DRI, SOS, entropy
  data with byte stuffing, restart markers, and EOI.
  Low-level marker, segment, JFIF APP0, 8-bit DQT, DHT, DRI, grayscale
  SOF0/SOS, YCbCr SOF0/SOS, and entropy byte-stuffing writers are implemented.
- Add entropy bit packing and baseline Huffman code emission. Entropy bit
  packing, restart marker emission, compiled Huffman symbol emission, and
  standard luminance and chrominance Huffman table definitions are implemented
  and tested. The current grayscale stream writer emits the luminance tables.
- Add baseline coefficient block emission. Single-block DC/AC emission is
  implemented and tested; non-restarted grayscale and interleaved color scan
  traversal is implemented and tested, and restarted grayscale and interleaved
  color scan traversal is implemented and tested.
  DC-only and full forward DCT are implemented and tested for the image-to-DCT
  path. `Gray_8` image-to-block extraction is implemented and tested for
  row-major blocks, edge padding, and full-FDCT AC coefficient extraction.
  Explicit component-plane to DCT block extraction is implemented and tested for
  row-major blocks, edge padding, and short-buffer rejection.
  Complete grayscale JPEG stream writing is implemented with full-forward DCT
  blocks and round-trip tested through the decoder, including restarted streams
  where configured. Complete internal YCbCr JPEG stream writing is implemented
  and round-trip tested through the decoder for the 4:2:0 layout. Public
  `Encode_Image` is wired to the grayscale and RGB-family baseline slices with
  constant and AC-detail round-trip, restarted round-trip, color round-trip,
  RGB subsampling, quality DQT, and output-limit coverage. RGB sample
  extraction, RGB-to-YCbCr conversion, and full-resolution Y/Cb/Cr plane
  assembly are implemented and tested.
  Component-plane downsampling and chroma subsampling layout helpers are
  implemented and tested. `Finish` is exact for the current one-shot encoder:
  it succeeds after completed output and rejects unfinished definitions.
  `Jpeglib.Capabilities.Baseline_Encode` is promoted for this scope.
- Make `Define_Image`, `Encode_Image`, and `Finish` state transitions exact.

Exit criteria:

- Baseline JPEGs produced by `jpeglib` decode successfully through `jpeglib` and
  at least one external reference decoder in conformance tooling.
- Quality, subsampling, restart interval, and metadata options have tests.
- `Jpeglib.Capabilities.Baseline_Encode` is updated.

## Phase 5: Conformance, Fixtures, Fuzzing, and Benchmarks

Goal: turn placeholder workflow tools into real project gates.

Status: implemented for the current project-tools gate. `jpeglib_fixtures` generates and verifies the managed
coefficient corpus and the static plus encoder-generated advanced image fixture
corpus. `jpeglib_conformance` now performs
baseline and progressive grayscale plus RGB 4:4:4/4:2:2/4:2:0/4:1:1 encode
conformance checks by generating JPEGs with `jpeglib`, decoding them through
the host ImageMagick `magick` command, comparing raw gray/RGB bytes with
bounded tolerance, and leaving reproducible temp artifacts on failure. It also
generates baseline/progressive gray and RGB JPEGs with ImageMagick from raw
samples, decodes them through `jpeglib`, and compares the decoded pixels as a
required third-party-generated interoperability corpus, including RGB 4x3/5x2
and 17x9/9x17 artifacts plus grayscale 5x3/4x4 and 17x1/2x17 artifacts at
varied quality, progressive, odd-dimension, edge-row, and RGB sampling settings.
It also
probes arithmetic sequential/progressive grayscale and RGB DCT output plus
baseline/progressive CMYK and YCCK four-channel output through self-decode and
reports whether the host ImageMagick stack accepts those optional external
decodes or uses a different channel convention. It also probes lossless,
differential, and hierarchical RGB encode streams. Advanced encode rows now
have a required native process oracle: `jpeglib_conformance` writes each
artifact, launches `tests/bin/jpeglib_decode_raw`, captures raw output bytes,
and compares them against the source samples with bounded tolerances.
ImageMagick stays as a diagnostic third-party oracle where this host rejects an
advanced JPEG family or uses a different CMYK/YCCK channel convention. The
baseline/progressive CMYK/YCCK rows additionally require `ffmpeg` as a
third-party RGB-conversion oracle, and the lossless Huffman grayscale/RGB rows,
including restarted artifacts with emitted restart markers, require `ffmpeg` as
a third-party raw-byte oracle on this host. Arithmetic sequential/progressive,
differential, and hierarchical rows also run required `ffmpeg` limitation sentinels
that lock the documented host-tool boundary. The
required versus diagnostic external coverage is documented in
`docs/external_reference_matrix.md`. `jpeglib_check` runs these conformance
checks after fixture verification.
`jpeglib_fuzz` now runs a deterministic malformed/truncated input corpus through
public header and image decode paths, including unsupported advanced SOF marker
families, malformed segment lengths, truncated Huffman tables, invalid
progressive SOS descriptors, plus generated-valid baseline, restarted,
progressive, arithmetic, arithmetic-progressive, lossless, and
arithmetic-lossless JPEG seeds with truncated-prefix coverage. It currently
runs 81 deterministic cases and fails on unexpected success, missing error
codes, or exceptions. `jpeglib_check` runs the deterministic fuzz corpus after
conformance.
`jpeglib_benchmark` now runs a fixed encode/decode timing matrix for RGB
baseline, progressive, arithmetic, lossless, plus CMYK baseline and lossless
cases, and reports elapsed times without machine-specific pass/fail thresholds.
`jpeglib_docs` now verifies required public documentation files and current
status/gate coverage, and `jpeglib_check` runs it as part of the normal local
gate.
`jpeglib_release` now verifies core release files and current-version changelog
coverage, reports `cryptolib` SHA-256 manifest lines for the core release
inputs, enforces the pin-free root Alire manifest and required tests-crate
sibling pins for `../project_tools` and `../hostkit` through `project_tools`
manifest checks, enforces the tests GPR main inventory through
`Project_Tools.Release_Checks` for `tests/tests.gpr` executable sources and
documentation coverage,
then runs the aggregate gate and benchmark smoke as a release readiness wrapper.
`jpeglib_generate` now refreshes generated fixture artifacts by invoking
`jpeglib_fixtures --generate` and verifying the resulting corpus.
`jpeglib_prove` now performs a proof-readiness audit over proof-designated
invariants by default and exposes `jpeglib_prove --run` for the executable
proof profile. The proof profile lives in `proof/jpeglib_proof.gpr`, currently
targets `Jpeglib.Internal.Checked_Arithmetic`, the SPARK-legal descriptor-only
`Descriptor_Is_Valid` arithmetic layer of `Jpeglib.Images` including
overflow-safe row-span rejection before stride-height multiplication, and the
segment boundary helpers in
`Jpeglib.Internal.Segments`, the SPARK-visible ownership budget/lease
transitions in `Jpeglib.Internal.Ownership`, marker classification helpers in
`Jpeglib.Internal.Markers`, restart-state configuration helpers in
`Jpeglib.Internal.Restarts`, plus the pure public capability surface in
`Jpeglib.Capabilities`, and invokes GNATprove only through `alr exec`.
The proof runner fails the gate when the current GNATprove output reports unproved
checks, severity diagnostics, or skipped declared SPARK bodies.
`jpeglib_release` runs that proof profile before the aggregate gate.

Completed:

- Implement `jpeglib_fixtures` to generate and verify the local fixture corpus.
  Fixture generation and verification are implemented for static baseline
  fixtures and encoder-generated progressive RGB, arithmetic progressive RGB,
  differential DCT RGB, hierarchical DCT RGB, arithmetic lossless RGB,
  differential lossless RGB, hierarchical lossless RGB, arithmetic progressive
  CMYK/YCCK, and arithmetic lossless CMYK/YCCK image fixtures, and
  `jpeglib_generate` wraps the generation workflow.
- Implement `jpeglib_conformance` with reference-image checks and clear
  pass/fail reporting. External reference gates are implemented for generated
  baseline/progressive grayscale plus RGB 4:4:4/4:2:2/4:2:0/4:1:1 encode
  output via ImageMagick, plus ImageMagick-generated baseline/progressive gray
  and RGB JPEGs decoded by `jpeglib` as required external-generated corpus
  coverage across RGB 4x3/5x2/17x9/9x17 and grayscale 5x3/4x4/17x1/2x17
  artifacts with varied quality and sampling. Arithmetic DCT, CMYK/YCCK four-channel, lossless, differential, and
  hierarchical encode probes are required to pass the `jpeglib_decode_raw`
  native process oracle, baseline/progressive CMYK/YCCK rows require `ffmpeg`
  RGB-conversion decode, ImageMagick results remain V1 telemetry, and lossless
  Huffman grayscale/RGB rows, including restarted artifacts, also require
  `ffmpeg` raw-byte decode. Arithmetic, differential, and hierarchical rows
  also require `ffmpeg` limitation sentinels that lock the documented host-tool
  boundary.
  `docs/external_reference_matrix.md`
  records which checks are required native process oracles versus diagnostic
  third-party probes.
- Implement `jpeglib_fuzz` for parser and entropy-input robustness. The
  deterministic public-API fuzz corpus is implemented and wired into
  `jpeglib_check`, with malformed headers plus generated-valid baseline,
  restarted, progressive, arithmetic, and lossless seeds.
- Implement `jpeglib_benchmark` for decode and encode throughput baselines. A
  lightweight RGB/CMYK encode/decode mode matrix is implemented.
- Extend `jpeglib_check` to run the appropriate subset for day-to-day work.
  Root/tests builds, fixture verification, conformance, deterministic fuzz,
  documentation checks, and AUnit are wired into the aggregate gate.

Exit criteria:

- CI-equivalent local commands are real and documented.
- Fuzz and conformance failures produce reproducible artifacts.

## Phase 6: Progressive Decode

Goal: add progressive JPEG decode after the baseline model is stable.

Status: implemented for the current public V1 scopes. Progressive SOS parsing now accepts valid DC first, AC first,
and AC refinement descriptors while rejecting invalid progressive scan
descriptors before entropy decoding starts. It enforces DC scans as `Ss = Se =
0`, AC scans as single-component `Ss > 0`, ordered spectral ranges, and
successive refinement steps where `Ah = Al + 1`.
`Jpeglib.Internal.Progressive` now tracks per-component coefficient scan
coverage and rejects duplicate first scans or refinement scans that do not match
the previously emitted approximation bitplane.
`Jpeglib.Internal.Coefficients` now has tested progressive DC first/refine block
primitives: first scans decode Huffman/category DC deltas and shift by `Al`,
while refinement scans apply the next approximation bit with coefficient sign
preserved.
Progressive AC first/refine block primitives are also covered: AC first scans
decode run/size symbols into zig-zag natural-order coefficients with `Al`
scaling, and AC refinement scans handle newly nonzero coefficients, existing
coefficient correction bits, and EOB-run refinement state.
`Decode_Progressive_Scan` now dispatches component-major progressive DC first,
DC refine, AC first, and AC refinement scans through those primitives.
Restart-backed grayscale progressive scan traversal is covered, and public
progressive decode orchestration is wired for the current grayscale, YCbCr, and
RGB image scope.
The scan decoder also has a stateful overload that validates progressive scan
ordering through `Jpeglib.Internal.Progressive` and commits scan-state only after
the entropy decode succeeds.
`Jpeglib.Internal.Decoder.Decode_Progressive_Coefficients` now reads internal
progressive coefficient streams through SOF2/SOS/entropy/EOI orchestration for
the covered grayscale DC-first, restarted DC-first, DC-first-plus-AC-first,
Huffman YCbCr interleaved DC-first plus component AC-first, arithmetic
DC-first/refine, nonzero AC-first, AC-refine with newly nonzero coefficient
magnitude decoding, and YCbCr coefficient AC-first multi-scan scopes, plus
multi-component DC-first scans decoded in MCU order and stored in
component-major coefficient order.
Public `Decode_Coefficients` dispatches covered SOF2 coefficient streams through
that progressive coefficient path both before and after `Read_Header`.
Public `Decode_Image` reuses the progressive coefficient path for covered
grayscale, YCbCr, and RGB SOF2 streams and reconstructs pixels through the
existing IDCT/color paths. Progressive grayscale coverage includes DC-only and
DC+AC multi-scan image reconstruction. 4:2:0 progressive YCbCr coverage
exercises sampled component placement and lookup; progressive RGB coverage
exercises the direct RGB output path. Public raw component decode also
reconstructs covered progressive grayscale component planes without color
conversion. `Jpeglib.Capabilities.Progressive_Decode` is enabled for the
current image scope.

Completed:

- Add progressive scan state separate from baseline scan state. Progressive SOS
  descriptor validation and coefficient scan-state ordering are started and
  covered by AUnit tests.
- Implement DC first/refine and AC first/refine coefficient refinement. DC and
  AC first/refine block primitives are implemented and tested.
- Add EOB run handling, successive approximation validation, and progressive
  scan ordering checks.
- Reuse the baseline pixel reconstruction pipeline after coefficient completion.

Exit criteria:

- Progressive coefficient and image decode pass known-answer tests.
- `Jpeglib.Capabilities.Progressive_Decode` is updated.

## Phase 7: Progressive Encoding and Advanced Features

Goal: complete the V1 feature set only after baseline encode/decode and
progressive decode are reliable.

Status: implemented for the current public V1 scopes. Progressive DCT encoding
is implemented across the covered grayscale, two-component `Gray_Alpha_16`,
RGB-family, CMYK, and YCCK public script slices.
Advanced JPEG families have deterministic header representation, covered decode
behavior for arithmetic-coded sequential/progressive DCT, 12-bit sequential DCT
byte-output, Huffman/arithmetic lossless JPEG, single-frame differential and
hierarchical paths, plus covered public
SOF0/SOF2/SOF3/SOF5/SOF6/SOF7/SOF9/SOF10/SOF11/SOF13/SOF14/SOF15 encode
slices including balanced/fast-preview differential and hierarchical DCT
progressive output, subsampled RGB-family advanced DCT output, DHP-marked
hierarchical DCT output with explicit Huffman SOF5 and arithmetic SOF13
zero-residual continuation frames for non-differential sequential output,
arithmetic progressive subsampled color output with MCU-padded luma/chroma
component storage,
same-geometry SOF5/SOF6/SOF13/SOF14 DCT continuation coefficient/raw/image
reconstruction with direct per-channel
nonzero AC CMYK/YCCK coverage,
and multi-frame plus restarted same-format CMYK/YCCK
hierarchical lossless output with zero-residual continuation frames and covered
restart-marker emission.

Ongoing expansion policy:

- Huffman balanced progressive grayscale encoding now emits a six-scan
  two-bitplane successive-approximation script, and RGB-family encoding now
  emits a 16-scan two-bitplane successive-approximation script. Two-component
  `Gray_Alpha_16` encoding now emits the corresponding 12-scan two-bitplane
  script, and direct CMYK/YCCK encoding now emits the corresponding 24-scan
  two-bitplane script. Arithmetic balanced progressive grayscale also emits a
  six-scan two-bitplane script, arithmetic `Gray_Alpha_16` emits a 12-scan
  two-bitplane script, arithmetic RGB-family emits an 18-scan two-bitplane
  script, and arithmetic CMYK/YCCK emits the corresponding 24-scan
  two-bitplane script.
- Keep `Balanced_Progressive` refinement scans and `Fast_Preview_Progressive`
  first-scan output covered for the grayscale, two-component, RGB-family, and
  four-component DCT encoding scopes.
- Keep the public DCT, lossless, arithmetic, differential, and hierarchical
  encoder modes aligned with their advertised covered
  SOF0/SOF2/SOF3/SOF5/SOF6/SOF7/SOF9/SOF10/SOF11/SOF13/SOF14/SOF15 slices,
  and keep option-policy rejections deterministic.
- Coefficient transforms are now in V1 for public block-level flips, rotations,
  transpose, and transverse operations. Reduced IDCT is now in V1 for opt-in
  scaled output, YCCK is now in V1 for Adobe APP14 transform 2 decode, raw
  component access is now in V1 for caller-buffered reconstructed component
  planes, ICC preservation is now in V1 for bounded APP2 fragment assembly, and
  Exif orientation is now in V1 for bounded APP1/TIFF parsing plus opt-in decode
  coordinate application.
- Keep extending advanced JPEG coverage with direct runtime checks as each
  public scope lands.

Exit criteria:

- V1 capability flags reflect actual tested behavior.
- Public API policy boundaries fail with documented, deterministic errors.
- Advanced V1 scopes are documented and covered by direct capability assertions.

## Release Readiness

The V1 release readiness checklist is implemented by `tests/bin/jpeglib_release`
and by the GitHub Actions `ci` workflow:

- `alr build` succeeds.
- `alr --chdir tests build` succeeds.
- `alr exec -- tests/bin/jpeglib_tests` succeeds.
- `alr exec -- tests/bin/jpeglib_check` succeeds.
- Conformance fixtures pass for baseline decode, baseline encode, and any
  progressive modes enabled in capabilities.
- Public docs describe supported JPEG modes, API policy boundaries, limits, color
  behavior, metadata behavior, and error handling.
- `CHANGELOG.md` lists implemented capabilities.
- `jpeglib_release` performs reproducibility checks and package validation.

## Post-V1 Work

Open library-complete work remains beyond the current release gate:

- Promote diagnostic or sentinel external rows to positive interoperability
  evidence where possible. Arithmetic, differential, hierarchical, and
  ImageMagick-diagnostic cases need stable third-party raw-byte or independently
  pinned corpus coverage, or explicit hard-failure compatibility tests.
- Expand proof coverage beyond the current helper-unit profile. Prefer
  IO-free decode/encode state helpers, limit arithmetic, and policy validation
  routines that can be made SPARK-clean without weakening the public API.
- Add a real-world interoperability corpus with pinned expectations for common
  camera, editor, browser, and malformed-in-the-wild JPEG variants.
- Keep `Jpeglib.Capabilities`, conformance policy, documentation, and release
  gates synchronized as each library-complete target lands.

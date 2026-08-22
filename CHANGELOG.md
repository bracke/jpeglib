# Changelog

## 0.1.0-dev

- Add the complete-plus competitive gap matrix and `jpeglib_complete_plus`
  tracker for multi-platform CI, expanded corpus, transform, optimization,
  precision/buffer, and performance work, explicitly excluding libjpeg API/ABI
  compatibility.
- Close the multi-platform CI complete-plus gap with a Linux, macOS, and Windows
  `jpeglib_complete` GitHub Actions matrix, including platform-local Alire lock
  refresh, explicit external dependency setup, and file-based raw oracle output
  for Windows-safe binary comparisons.
- Close the expanded real-world corpus complete-plus gap by making
  `jpeglib_real_world` verify a typed manifest with pinned file digests,
  header/metadata fields, decoded output SHA-256 values, and deterministic
  malformed rejection outcomes.
- Add public coefficient image transforms with component-major layout/window
  validation, full-image and block-aligned crop remapping, AUnit coverage, and
  a `jpeglib_transform --self-test` CLI gate.
- Add `Jpeglib.Coefficients.Encoding` for emitting baseline Huffman grayscale
  and YCbCr JPEG streams plus progressive Huffman grayscale and YCbCr streams
  from quantized coefficient blocks, with AC-preserving public coefficient
  decode round-trip coverage.
- Close the lossless-transform complete-plus gap by adding
  `Optimize_Huffman` coefficient-derived DHT output and an optional
  `jpeglib_transform --self-test` comparison against `jpegtran` when available.
- Close the encoder-optimization complete-plus gap with public
  `Optimize_Huffman`, `Target_Bytes`, and perceptual preset controls, optimized
  image-level Huffman DHT generation, and a deterministic
  `jpeglib_encoder_optimization` matrix gate.
- Close the precision-buffer complete-plus gap with public raw component
  precision policies for scaling, clamping, source-precision preservation, and
  mismatch rejection, plus the `jpeglib_precision_buffer` matrix gate.
- Close the performance-architecture complete-plus gap with a hostkit-backed
  performance matrix covering deterministic encode/decode equivalence and broad
  runtime thresholds.
- Add compiler-vectorized SIMD RGB-to-YCbCr row kernels, route encoder
  RGB-family plane filling through them, advertise `SIMD_Acceleration`, and add
  `jpeglib_simd_matrix` scalar-equivalence coverage across RGB/BGR/RGBA/BGRA
  layouts.
- Extend the SIMD color path with compiler-vectorized YCbCr-to-RGB-family row
  output kernels and expand `jpeglib_simd_matrix` to compare decode-side row
  packing against scalar `Write_YCbCr`.
- Route direct full-size lossless YCbCr image decode output through the
  YCbCr-to-RGB-family row output path, with the existing scalar pixel path kept
  for reduced-IDCT and EXIF-oriented outputs.
- Add compiler-vectorized direct RGB row output packing, route direct full-size
  RGB-labelled lossless and 4:4:4 DCT decode output through row writers, and
  expand `jpeglib_simd_matrix` to cover every public output format.
- Add compiler-vectorized gray and gray-alpha row output packing, route direct
  full-size grayscale and two-component lossless decode output through row
  writers, and extend `jpeglib_simd_matrix` scalar-equivalence coverage across
  every public output format.
- Make GitHub Actions run the full `jpeglib_complete` gate for push, pull
  request, and manual CI runs instead of stopping at release readiness.
- Close the library-complete gate by finalizing LC1 external oracle rows,
  adding the SPARK-proved `Jpeglib.Internal.Library_Policy` boundary for LC4,
  and updating documentation/release checks so `jpeglib_complete` passes with
  zero open matrix rows.
- Extend opt-in public image decode for wider DCT and lossless streams by
  consuming all decoded components while projecting the first four into public
  byte output formats, and route ambiguous non-YCbCr/non-CMYK/non-YCCK color
  models through direct component projection instead of rejecting them solely
  for color-model ambiguity.
- Strengthen the public V1 encode mode/format matrix test so every advertised
  mode and byte input format round-trips deterministic non-flat channel data
  instead of only constant sample planes.
- Expand Huffman balanced progressive grayscale encode from one refinement
  pass to a six-scan two-bitplane successive-approximation script with direct
  scan-count and round-trip coverage.
- Expand Huffman balanced progressive RGB-family encode to a 16-scan
  two-bitplane successive-approximation script with direct scan-count and
  round-trip coverage while keeping fast-preview at first scans only.
- Expand Huffman balanced progressive `Gray_Alpha_16` encode to a 12-scan
  two-bitplane successive-approximation script with direct scan-count,
  restarted, and round-trip coverage.
- Expand Huffman balanced progressive CMYK/YCCK encode to a 24-scan
  two-bitplane successive-approximation script with direct scan-count and
  per-channel round-trip coverage while keeping fast-preview at first scans
  only.
- Expand arithmetic balanced progressive grayscale, `Gray_Alpha_16`,
  RGB-family, and CMYK/YCCK encode from one refinement pass to six-scan,
  12-scan, 18-scan, and 24-scan two-bitplane successive-approximation scripts
  with direct scan-count and round-trip coverage.
- Establish repository foundation, public package map, structured result model,
  checked arithmetic, tests child crate, and documentation skeleton.
- Add baseline Huffman decode for grayscale, YCbCr, RGB JPEG, and plain CMYK
  image paths, plus public coefficient decode.
- Add baseline grayscale and RGB-family encode for non-progressive,
  metadata-discarding image views with quality, subsampling, and restart
  coverage.
- Add baseline two-component `Gray_Alpha_16` DCT encode for non-progressive
  image views with quality, restart, and public decoder round-trip coverage.
- Extend two-component `Gray_Alpha_16` DCT encode to the covered progressive
  SOF2 script slice with fast-preview, balanced DC/AC refinement, restart,
  deterministic nonzero AC coverage in both planes, and public decoder
  round-trip coverage.
- Add progressive grayscale and RGB-family encode for the current script slice,
  including Balanced refinement scans and Fast Preview first-scan output.
- Add public lossless Huffman grayscale and RGB-family encode for the covered
  SOF3 slices, including configurable predictor selections 1 through 7 and
  point-transform emission for transformed 8-bit samples, with decoder
  coverage and deterministic unsupported-option rejection for out-of-scope
  lossless encode requests, including direct four-component CMYK/YCCK
  progressive-policy rejection coverage.
- Extend public lossless Huffman encode to covered two-component
  `Gray_Alpha_16` SOF3 streams with restart and decoder round-trip coverage.
- Add public non-hierarchical differential lossless Huffman/arithmetic
  SOF7/SOF15 encode modes for the covered grayscale, `Gray_Alpha_16`, and
  RGB-family/CMYK/YCCK slices, with public differential-lossless decoder round-trip
  coverage.
- Add public hierarchical lossless Huffman/arithmetic SOF3/SOF7/SOF11/SOF15
  encode modes for the covered grayscale, `Gray_Alpha_16`, and RGB-family
  plus CMYK/YCCK slices, emitting DHP and round-tripping through public
  hierarchical decode.
- Extend non-differential public hierarchical lossless encode to write
  multi-frame streams: a base SOF3/SOF11 frame followed by a same-geometry
  SOF7/SOF15 zero-residual continuation frame, including restarted scan
  coverage for base and continuation payloads.
- Decode sampled four-component Huffman differential-lossless hierarchical
  continuation scans through parsed component geometry, including nonzero
  residual composition in public coefficient, raw-component, and image decode
  and separate one-component continuation scans, while rejecting duplicate and
  incomplete separate continuation scan sequences deterministically.
- Cover sampled four-component arithmetic differential-lossless hierarchical
  continuation scans split across separate one-component SOS segments through
  public coefficient, raw-component, and image decode, with duplicate and
  incomplete separate continuation scan rejection.
- Compose hierarchical DCT residual frames in the direct raw-component and
  image decode paths after the base entropy decoder reports SOF5/SOF13,
  and compose coefficient/raw/image output after SOF6/SOF14 progressive continuation
  frames, preserving DHP-only single-frame streams while covering
  three-component Huffman 4:2:0 separate-scan coefficient/raw/image
  reconstruction.
- Extend non-differential public Huffman/arithmetic hierarchical sequential
  DCT encode to write explicit same-geometry SOF5/SOF13 zero-residual
  continuation frames for grayscale, `Gray_Alpha_16`, RGB-family, CMYK, and
  YCCK output, and make arithmetic sequential single-component scan decode
  consume MCU-padded component extents for subsampled separate color scans,
  with marker and 4:2:0/4:1:1 round-trip coverage in the hierarchical and
  arithmetic DCT tests.
- Extend arithmetic progressive RGB-family encode/decode so subsampled SOF10
  fast-preview/balanced output uses MCU-padded luma/chroma component storage
  while preserving the established visible component ordering for Huffman
  separate-scan fixtures.
- Cover unknown-color four-component progressive DCT image decode through the
  direct-channel RGBA output policy using separate component DC-first scans.
- Expand unknown-color two-component direct-channel image decode coverage to
  Huffman and arithmetic differential-lossless streams across every public
  byte-output format.
- Expand progressive-script rejection coverage for lossless encode modes across
  every public byte input format, preserving the no-partial-output policy.
- Extend Huffman and arithmetic lossless point-transform encode/decode coverage
  to same-format CMYK and YCCK output for every point-transform value.
- Extend Huffman and arithmetic differential-lossless SOF7/SOF15 encode/decode
  coverage to point-transform values `0 .. 7` across grayscale, gray-alpha,
  RGB, CMYK, and YCCK output.
- Extend hierarchical Huffman/arithmetic lossless and differential-lossless
  encode/decode coverage to point-transform values `0 .. 7` across every
  public byte input/output format, including RGB-alpha alpha-fill behavior.
- Extend the conformance gate so ImageMagick external reference decode checks
  cover generated baseline/progressive grayscale output and RGB
  4:4:4/4:2:2/4:2:0/4:1:1 encode output, while arithmetic DCT encode probes
  and CMYK/YCCK four-channel probes are kept as explicit self-decode plus
  external-support diagnostics.
- Expand deterministic fuzzing to 81 cases by adding malformed segment-length,
  truncated-Huffman-table, invalid-progressive-SOS inputs and generated-valid
  baseline, restarted, progressive, arithmetic, arithmetic-progressive,
  lossless, and arithmetic-lossless seeds with truncated-prefix coverage.
- Add `docs/external_reference_matrix.md` to document required versus
  diagnostic external reference coverage, and extend diagnostic conformance
  probes to lossless, differential, and hierarchical RGB encode streams.
- Add `tests/bin/jpeglib_decode_raw` as a required native process oracle for
  advanced conformance rows, so arithmetic, CMYK/YCCK, lossless, differential,
  and hierarchical encode artifacts must decode through a separate raw-byte
  process while ImageMagick remains a third-party diagnostic for unsupported
  host modes.
- Require `ffmpeg` raw gray/RGB decode for lossless Huffman grayscale/RGB
  conformance artifacts, promoting the installed third-party oracle where the
  host can decode the advanced JPEG family.
- Extend that required `ffmpeg` lossless Huffman oracle to restarted grayscale
  and RGB conformance artifacts that must contain emitted restart markers.
- Require `ffmpeg` RGB-conversion decode for baseline/progressive CMYK and YCCK
  conformance artifacts, while keeping ImageMagick raw-CMYK output diagnostic
  because its channel convention differs on this host.
- Add required `ffmpeg` limitation sentinels for arithmetic, differential, and
  hierarchical conformance artifacts so the documented host-tool boundary is
  release-gated.
- Expand the executable proof profile to include restart-state configuration
  and expected-marker bounds in `Jpeglib.Internal.Restarts`.
- Add `project_tools` manifest validation to the release gate so the root crate
  stays pin-free and tests keep the required `../project_tools` and `../hostkit`
  sibling pins.
- Add a `Project_Tools.Release_Checks` tests GPR main inventory check to the
  release gate so listed test executables require source and documentation
  coverage.
- Reopen library-complete scope beyond the current release gate: diagnostic
  external decoder rows, proof expansion, and real-world corpus coverage are
  tracked as remaining work instead of being hidden behind V1 boundary wording.
- Add a library-complete implementation roadmap covering external oracle
  closure, real-world corpus, public API policy matrix, proof expansion,
  streaming/large-image behavior, and a final completeness gate.
- Add `jpeglib_complete` as the executable library-complete gate scaffold; it
  runs the release baseline and reports explicit LC blockers until the complete
  JPEG-library criteria are closed.
- Add the `jpeglib_external_matrix` checker and initial LC1 external oracle
  matrix with explicit open rows for diagnostic/sentinel interoperability work.
- Add the `jpeglib_real_world` manifest checker and initial LC2 manifest
  location for the real-world interoperability corpus.
- Populate the LC2 corpus manifest with pinned representative JPEG fixture rows
  and make `jpeglib_real_world` validate that each listed file exists and
  matches its SHA-256 digest.
- Add the `jpeglib_policy_matrix` checker and initial LC3 public API policy
  matrix with explicit open rows for library-complete coverage.
- Close the LC3 public API policy matrix rows against the existing complete
  decode/encode AUnit evidence for advertised frame families, color models,
  limits, states, metadata policies, progressive scripts, restart behavior, and
  output formats.
- Add the `jpeglib_proof_matrix` checker and initial LC4 proof expansion matrix
  with explicit open rows for library-complete coverage.
- Add the `jpeglib_stress_matrix` checker and initial LC5 streaming/large-image
  stress matrix with explicit open rows for library-complete coverage.
- Close the LC5 stress matrix with dedicated chunked restarted RGB stream
  roundtrip coverage, chunked metadata callback stress coverage, and existing
  large-dimension/resource-limit evidence.
- Add required ImageMagick-generated baseline/progressive gray and RGB decode
  artifacts to the conformance gate, expanding the external interoperability
  corpus beyond `jpeglib`-generated streams.
- Expand that ImageMagick-generated decode corpus beyond 2x2 fixtures with
  required RGB 4x3/5x2/17x9/9x17 and grayscale 5x3/4x4/17x1/2x17
  artifacts at varied quality, progressive, odd-dimension, edge-row, and RGB
  sampling settings.
- Expand the executable proof profile from checked arithmetic to include the
  SPARK-legal descriptor-only image validation layer in `Jpeglib.Images`
  including row-span overflow rejection, and the segment boundary helpers in
  `Jpeglib.Internal.Segments`, and the ownership budget/lease transitions in
  `Jpeglib.Internal.Ownership`; the proof runner now fails on unproved checks,
  severity diagnostics, or skipped declared SPARK bodies in the GNATprove
  summary.
- Add the pure public `Jpeglib.Capabilities` surface to the executable proof
  profile and mark its V1 capability invariant as proof-designated.
- Add `Jpeglib.Internal.Markers` marker classification helpers to the executable
  proof profile and mark the marker-classification invariant as proof-designated.
- Add `docs/limits_and_safety.md` to make the caller-buffer contract explicit,
  including the SPARK-proved descriptor arithmetic boundary and runtime-checked access-bearing views,
  configured output/metadata limits, and test-only `Unchecked_Access` usage.
- Classify APP13 Photoshop resource metadata as `Photoshop_APP13`, while
  preserving unknown APP policy coverage on APP15.
- Expand `jpeglib_benchmark` from one RGB baseline smoke case to a fixed matrix
  covering RGB baseline, progressive, arithmetic, lossless, plus CMYK baseline
  and lossless encode/decode timing.
- Add an executable proof profile under `proof/jpeglib_proof.gpr`, mark
  `Jpeglib.Internal.Checked_Arithmetic` for SPARK analysis, teach
  `jpeglib_prove --run` to invoke GNATprove through `alr exec`, and promote the
  release wrapper from proof-readiness audit to running the proof profile.
- Remove the last unused test-tooling placeholder helper now that all documented
  workflow executables are implemented.
- Extend the managed image fixture corpus with encoder-generated progressive
  RGB, arithmetic progressive RGB, differential DCT RGB, hierarchical DCT RGB,
  arithmetic lossless RGB, differential lossless RGB, and hierarchical lossless
  RGB streams pinned by decoded SHA-256 output.
- Expand the managed image fixture corpus with encoder-generated
  four-component arithmetic progressive CMYK/YCCK and arithmetic lossless
  CMYK/YCCK streams pinned by decoded SHA-256 output.
- Fix non-restarted arithmetic progressive encoder AC probability-state
  continuity between AC-first and AC-refinement scans, enabling balanced
  detailed 2x2 RGB, CMYK, and YCCK SOF10/DAC fixture coverage without
  weakening restarted progressive output.
- Fix arithmetic progressive AC first-scan encoding for successive
  approximation so odd coefficients are encoded with shifted significance and
  completed by refinement scans, and accept arithmetic termination bytes before
  scan-ending marker handoff. The managed arithmetic progressive RGB fixture now
  uses the detailed 2x2 encoder-generated stream instead of the flat fallback.
- Widen public component count/index types to the JPEG SOF/SOS byte ceiling
  while keeping the default decode component limit at four, and add opt-in
  five-component interleaved and separate-scan SOF3/SOF7/SOF11/SOF15 lossless
  and differential-lossless coefficient and raw-component decode coverage.
- Add opt-in five-component baseline, arithmetic sequential DCT, and
  Huffman/arithmetic differential sequential DCT coefficient/raw decode
  coverage using caller-raised component limits while preserving default
  rejection.
- Add opt-in five-component Huffman/arithmetic progressive and differential
  progressive DCT coefficient/raw decode coverage for SOF2/SOF6/SOF10/SOF14
  DC-first streams while preserving default rejection.
- Add opt-in 255-component baseline DCT coefficient/raw decode coverage at the
  JPEG SOF/SOS byte ceiling while preserving default four-component rejection.
- Add opt-in 255-component arithmetic sequential DCT SOF9 coefficient/raw
  decode coverage at the JPEG SOF/SOS byte ceiling while preserving default
  four-component rejection.
- Add opt-in 255-component Huffman/arithmetic progressive and
  differential-progressive DCT SOF2/SOF6/SOF10/SOF14 DC-first coefficient/raw
  decode coverage at the JPEG SOF/SOS byte ceiling while preserving default
  four-component rejection.
- Extend post-scan DNL coverage to Huffman and arithmetic differential-lossless
  streams, including matching raw-component decode and mismatched image-decode
  rejection with DNL marker context.
- Cover unknown-color three- and four-component Huffman/arithmetic
  differential-lossless image decode through the direct RGB/RGBA channel policy.
- Add opt-in 255-component Huffman lossless SOF3 coefficient/raw decode
  coverage at the JPEG SOF/SOS byte ceiling while preserving default
  four-component rejection.
- Add opt-in 255-component arithmetic lossless SOF11 coefficient/raw decode
  coverage at the JPEG SOF/SOS byte ceiling while preserving default
  four-component rejection.
- Add opt-in 255-component Huffman/arithmetic differential-lossless
  SOF7/SOF15 coefficient/raw decode coverage at the JPEG SOF/SOS byte ceiling
  while preserving default four-component rejection.
- Extend opt-in five-component coefficient/raw decode coverage to DHP-marked
  Huffman/arithmetic hierarchical lossless SOF3/SOF7/SOF11/SOF15 streams while
  preserving default four-component rejection.
- Add opt-in 255-component DHP-marked Huffman/arithmetic hierarchical lossless
  SOF3/SOF7/SOF11/SOF15 coefficient/raw decode coverage at the JPEG SOF/SOS
  byte ceiling while preserving default four-component rejection.
- Add opt-in 255-component DHP-marked Huffman/arithmetic hierarchical
  sequential DCT SOF0/SOF9 coefficient/raw decode coverage at the JPEG SOF/SOS
  byte ceiling while preserving default four-component rejection.
- Compose DHP-marked Huffman/arithmetic hierarchical DCT SOF0/SOF5 and
  SOF9/SOF13 coefficient streams by adding same-geometry differential
  sequential DCT residual coefficients while preserving base hierarchical
  header reporting, covering three-component arithmetic coefficient/raw/image
  composition for unit-sampled component geometry and three-component Huffman
  4:2:0 coefficient/raw/image composition with separate one-component
  base/residual continuation scans,
  and route covered Huffman/arithmetic SOF0/SOF5 and SOF9/SOF13 grayscale
  raw/image decode through the composed coefficient path.
- Cover deterministic `Balanced_Progressive` and `Fast_Preview_Progressive`
  rejection for every public Huffman/arithmetic, differential, and hierarchical
  lossless encode mode without writing partial output.
- Add public `CMYK_32` and `YCCK_32` image formats and route them through
  Huffman/arithmetic, differential, and hierarchical lossless and DCT encode
  modes, including Adobe APP14 transform 2 emission for YCCK and same-format
  public decoder round-trip coverage across progressive-script choices.
- Expand direct CMYK/YCCK advanced encode coverage to per-channel nonzero AC
  same-format round trips for Huffman/arithmetic differential DCT and
  hierarchical DCT streams.
- Expand direct CMYK/YCCK lossless encode coverage to predictor selections 1
  through 7 for Huffman and restarted arithmetic lossless streams, plus
  restarted same-format differential-lossless and hierarchical-lossless
  round trips with entropy, restart, color-model, and hierarchical header
  assertions.
- Add public differential DCT Huffman/arithmetic SOF5/SOF6/SOF13/SOF14 encode
  modes for the covered grayscale, `Gray_Alpha_16`, and RGB-family slices, with
  balanced and fast-preview progressive public differential DCT decoder
  round-trip coverage, including RGB-family 4:2:2/4:2:0/4:1:1 sequential and
  balanced/fast-preview progressive sampling layouts.
- Add public hierarchical DCT Huffman/arithmetic SOF0/SOF2/SOF5/SOF6/SOF9/SOF10/SOF13/SOF14
  encode modes for the covered grayscale, `Gray_Alpha_16`, and RGB-family
  slices, emitting DHP and round-tripping balanced and fast-preview
  progressive output through public hierarchical decode, including RGB-family
  4:2:2/4:2:0/4:1:1 sequential and balanced/fast-preview progressive
  sampling layouts.
- Align Huffman progressive YCbCr subsampled encode/decode traversal so
  interleaved DC-first scans consume padded MCU edge blocks while separate AC
  and refinement scans emit the visible component grid, covering 4:2:0 and
  4:1:1 balanced-progressive advanced DCT round trips.
- Report parsed lossless predictor selection and point transform in public
  image header information.
- Add exact DAC conditioning-table segment emission as arithmetic encode
  groundwork.
- Add SOF9/SOF10/SOF11 arithmetic frame writer primitives for grayscale,
  YCbCr, and lossless RGB-family/CMYK/YCCK encode groundwork with exact byte
  coverage.
- Add a public `Arithmetic_Sequential_DCT` encode mode for the covered
  grayscale SOF9/DAC slice, including zero-coefficient output, a deterministic
  nonzero AC single-block pattern, and restarted multi-block scans,
  with decoder round-trip coverage.
- Allow covered single-block `Arithmetic_Sequential_DCT` streams to emit restart
  intervals beyond 1 with decoder round-trip coverage.
- Extend public `Arithmetic_Sequential_DCT` encode to the covered RGB-family
  zero-block 4:4:4 SOF9/DAC slice using separate-component arithmetic color
  scans and decoder round-trip coverage.
- Extend public `Arithmetic_Sequential_DCT` encode to the covered
  two-component `Gray_Alpha_16` zero-block SOF9/DAC slice using separate
  arithmetic component scans and decoder round-trip coverage.
- Cover zero-block arithmetic sequential encode/decode for the public
  `BGR_24`, `RGBA_32`, and `BGRA_32` input layouts.
- Add covered RGB-family arithmetic sequential encode/decode coverage for the
  deterministic nonzero luma AC single-block pattern.
- Add covered RGB-family arithmetic sequential encode/decode coverage for
  deterministic nonzero Cb and Cr chroma AC single-block patterns.
- Extend the covered RGB-family arithmetic sequential encode slice to restarted
  4:4:4, 4:2:2, 4:2:0, and 4:1:1 zero-block color scans.
- Add public arithmetic progressive grayscale encode, emitting SOF10/DAC
  fast-preview DC-first/AC-first scans and balanced DC/AC refinement scans
  with restart and nonzero AC coefficient coverage.
- Extend public arithmetic progressive encode to RGB-family SOF10/DAC color
  streams using separate-component Y, Cb, and Cr scans with fast-preview,
  balanced refinement, restart, and decoder round-trip coverage.
- Extend public arithmetic progressive encode to the covered two-component
  `Gray_Alpha_16` SOF10/DAC script slice with fast-preview, balanced DC/AC
  refinement, restart, shared arithmetic conditioning state across component
  scans, nonzero AC coefficient coverage in both planes, and decoder
  round-trip coverage.
- Align arithmetic progressive color separate scans with the decoder's
  component-grid traversal for subsampled images, covering restarted 4:1:1
  balanced output, and continue AC refinement across the rest of the spectral
  band after newly significant coefficients.
- Cover arithmetic progressive RGB-family encode/decode for deterministic
  nonzero luma, Cb, and Cr AC single-block patterns under both fast-preview and
  balanced scripts.
- Preflight arithmetic sequential encode block/restart support so unsupported
  options fail deterministically before any partial JPEG stream bytes are
  written.
- Add a public `Arithmetic_Lossless` encode mode for the covered grayscale,
  two-component `Gray_Alpha_16`, and RGB-family SOF11/DAC slices, including
  zero-difference output, deterministic grayscale first-sample
  differences in `-32`, `-16`, `-8`, `-5 .. 5`, `8`, `16`, and `32`,
  gray-alpha and RGB-family single-component first-sample differences in
  `-32`, `-16`, `-8`, `-5 .. 5`, `8`, `16`, and `32`,
  point-transform output, and optionally restarted multi-sample scans, with
  decoder round-trip coverage.
- Extend covered arithmetic lossless `Gray_Alpha_16` encode/decode to
  deterministic first-component and second-component first-sample differences
  in `-32`, `-16`, `-8`, `-5 .. 5`, `8`, `16`, and `32`.
- Extend covered arithmetic lossless RGB-family encode/decode to deterministic
  first-sample differences in `-32`, `-16`, `-8`, `-5 .. 5`, `8`, `16`, and
  `32` on each individual color component.
- Extend covered arithmetic lossless grayscale encode/decode to deterministic
  non-restarted second-sample differences in that same set except the ambiguous
  `-1` case, when the restart segment begins with a zero-difference sample.
- Expand covered arithmetic lossless grayscale encode/decode to exhaustive
  first-sample and non-restarted second-sample differences across `-128 .. 127`,
  and expand gray-alpha/RGB-family single-component first-pixel and
  non-restarted second-pixel deltas to exhaustive `-128 .. 127` coverage on
  each covered component.
- Cover arithmetic lossless predictor selections 1 through 7 for public
  grayscale, `Gray_Alpha_16`, and RGB-family encode/decode slices.
- Add dedicated arithmetic lossless point-transform encode/decode coverage for
  public grayscale, `Gray_Alpha_16`, and RGB-family image views across all
  point-transform values `0 .. 7`.
- Expand public lossless Huffman point-transform encode/decode coverage for
  public grayscale, `Gray_Alpha_16`, and RGB-family image views across all
  point-transform values `0 .. 7`.
- Cover `RGBA_32` and `BGRA_32` input layouts for the public lossless Huffman
  and arithmetic lossless RGB-family encode/decode slices.
- Extend public lossless Huffman and arithmetic lossless predictor coverage
  across `BGR_24`, `RGBA_32`, and `BGRA_32` RGB-family encode layouts.
- Expand public lossless Huffman encode/decode coverage to larger signed
  difference categories across grayscale, `Gray_Alpha_16`, and RGB-family
  slices.
- Expand the public V1 encode mode/format matrix so every public encode mode
  round-trips same-format `Gray_8`, `Gray_Alpha_16`, `RGB_24`, `BGR_24`,
  `RGBA_32`, and `BGRA_32` image views through the public decoder across the
  supported DCT progressive-script and lossless non-progressive policy choices,
  including alpha-fill behavior for JPEG color output.
- Preflight arithmetic-lossless encode differences so unsupported samples fail
  deterministically before any partial JPEG stream bytes are written.
- Add deterministic unsupported-policy coverage for header-visible differential
  Huffman/arithmetic SOF decode paths across public coefficient, raw component,
  and image decode.
- Decode covered lossless and differential-lossless coefficient requests by
  exposing reconstructed source-precision component samples as DC-only
  coefficient blocks.
- Decode covered DHP-marked hierarchical streams through public coefficient,
  raw component, and image decode while retaining hierarchical header
  reporting, including same-geometry Huffman and arithmetic
  differential-lossless continuation frames with zero residual deltas from
  initialized and header-ready decoder states, plus public coefficient,
  grayscale raw/image, 2/3/4-component raw, and covered three- and
  four-component image composition for same-geometry Huffman
  continuation frames carrying nonzero residual deltas from initialized and
  header-ready decoder states, plus generated single-component, two-component,
  three-component, and four-component arithmetic coefficient/raw/image
  continuation coverage carrying nonzero residual deltas from initialized and
  header-ready decoder states.
- Extend covered single-frame DHP-marked hierarchical coefficient, raw
  component, and image decode coverage to header-ready public decoder state.
- Accept matching post-scan DNL markers for known-height baseline, arithmetic,
  progressive, differential DCT, arithmetic differential DCT, differential
  progressive DCT, arithmetic differential progressive DCT, and lossless streams
  and reject pre-scan or mismatched DNL deterministically with marker context;
  EXP remains rejected instead of being treated as a generic skipped
  length-bearing segment.
- Reject reserved JPG/JPGn marker families deterministically during public
  header/image decode instead of treating them as skippable extension segments.
- Add covered progressive grayscale, YCbCr, and RGB image decode paths through
  the public decoder.
- Add a public `Gray_Alpha_16` image format and use it to decode covered
  unknown-color two-component DCT and 8/12-bit lossless streams while
  preserving both reconstructed component samples.
- Extend SOF3 lossless Huffman 12-bit decode from grayscale to covered YCbCr,
  RGB, CMYK, and YCCK raw component and image output with source-precision
  predictor state and byte scaling.
- Extend SOF11 lossless arithmetic 12-bit decode from grayscale to covered
  YCbCr, RGB, CMYK, and YCCK raw component and image output with
  source-precision predictor state and byte scaling.
- Enable covered non-hierarchical SOF7/SOF15 differential lossless grayscale,
  unknown-color two-component `Gray_Alpha_16`, YCbCr, RGB, CMYK, and YCCK raw
  component, image, and coefficient decode through the predictor-based
  lossless paths while exposing covered lossless coefficient output as
  source-precision DC-only sample blocks, including 12-bit grayscale SOF7/SOF15
  coverage.
- Enable covered single-frame SOF5/SOF6/SOF13/SOF14 differential DCT grayscale
  plus SOF5/SOF6 Huffman RGB, YCbCr, CMYK, and YCCK, and SOF13/SOF14 arithmetic
  RGB, YCbCr, CMYK, and YCCK coefficient, raw component, and image decode through
  the existing sequential/progressive DCT reconstruction paths.
- Extend covered grayscale SOF5/SOF6/SOF13/SOF14 differential DCT coefficient,
  raw component, and image decode coverage to header-ready public decoder state.
- Extend covered SOF13/SOF14 arithmetic YCbCr differential DCT coefficient, raw
  component, and image decode coverage to header-ready public decoder state.
- Extend covered SOF5/SOF6 Huffman YCbCr and SOF13/SOF14 arithmetic RGB
  differential DCT coefficient, raw component, and image decode coverage to
  header-ready public decoder state.
- Extend covered SOF5 Huffman and SOF13 arithmetic CMYK/YCCK sequential
  differential DCT coefficient, raw component, and image decode coverage to
  header-ready public decoder state.
- Extend covered SOF6 Huffman and SOF14 arithmetic CMYK/YCCK progressive
  differential DCT coefficient, raw component, and image decode coverage to
  header-ready public decoder state.
- Expand covered SOF14 arithmetic differential progressive YCbCr, RGB, CMYK,
  and YCCK decode coverage with nonzero component AC detail through public
  coefficient, raw component, and image reconstruction.
- Extend covered arithmetic lossless YCbCr decode to separate component scans
  through public raw component, coefficient, and image reconstruction.
- Extend covered arithmetic lossless RGB decode to separate component scans
  through public raw component, coefficient, and image reconstruction.
- Extend covered arithmetic lossless YCCK decode to separate component scans
  through public raw component, coefficient, and image reconstruction.
- Extend covered Huffman lossless RGB and YCCK decode to separate component
  scans through public raw component, coefficient, and image reconstruction.
- Extend Huffman and arithmetic lossless coefficient and raw-component decode to sampled
  separate two-component, YCbCr, CMYK, and YCCK scans, preserving parsed per-component dimensions.
- Extend arithmetic lossless coefficient and raw-component decode to sampled interleaved
  YCCK scans, preserving MCU-order per-component sample traversal.
- Extend lossless image decode to allocate parsed component-plane dimensions for
  sampled interleaved YCCK streams before composing full-size output pixels.
- Add decode-side metadata summaries, bounded metadata retention, callback
  streaming, and ICC fragment validation/profile-byte retention, with ICC
  preservation advertised for bounded APP2 fragment assembly.
- Add encoder-side queued APP/COM metadata emission with public limit checks and
  decoder retention round-trip coverage.
- Add Exif APP1/TIFF orientation parsing and opt-in decode coordinate
  application, with capability advertising.
- Add public raw component access for caller-buffered reconstructed component
  sample planes without color conversion.
- Add explicit public SOF3 RGB lossless Huffman raw-component decode coverage
  through encoder-produced streams.
- Add Adobe APP14 transform 2 YCCK decode with color-model reporting and
  RGB-family output conversion.
- Add opt-in reduced output scaling for full, half, quarter, and eighth-size
  DCT image decode, and extend reduced public image output to covered
  Huffman/arithmetic grayscale, YCbCr, RGB, YCCK, SOF7/SOF15 differential
  lossless, and DHP-marked hierarchical lossless streams through the
  raw-component reconstruction path.
- Add public coefficient block transforms for flips, rotations, transpose, and
  transverse operations on natural-order DCT blocks.
- Add arithmetic DAC conditioning-table parsing groundwork.
- Add the arithmetic binary decision decoder primitive with stuffed-byte and
  marker handoff coverage.
- Add arithmetic DC difference decoding groundwork with DC conditioning context
  updates.
- Add arithmetic AC EOB decision decoding groundwork for all-zero AC tails.
- Add arithmetic DC/EOB block decoding groundwork for DC-only arithmetic block
  reconstruction.
- Add internal arithmetic DC/EOB scan decoding groundwork for single-component
  baseline scans.
- Add arithmetic sequential block decoding groundwork for a nonzero AC
  coefficient followed by EOB.
- Add internal arithmetic sequential scan decoding groundwork for a
  single-component baseline scan with a nonzero AC coefficient.
- Extend internal arithmetic sequential scan decoding groundwork to covered
  interleaved color traversal.
- Parse SOF9 arithmetic baseline headers with arithmetic entropy metadata while
  keeping public arithmetic coefficient/image decode unsupported.
- Add internal arithmetic coefficient decode groundwork for a covered SOF9/DAC
  single-block stream.
- Route public coefficient decode through the covered SOF9 arithmetic
  coefficient scope.
- Route post-header public coefficient decode through the covered SOF9
  arithmetic coefficient scope.
- Route restarted public SOF9 arithmetic coefficient decode through restart
  marker preservation and arithmetic probability-state reset.
- Route public SOF9 arithmetic coefficient decode across covered separate color
  scans with per-scan arithmetic probability-state initialization.
- Route public grayscale image decode through the covered SOF9 arithmetic
  coefficient scope.
- Route restarted public grayscale image decode through the covered SOF9
  arithmetic coefficient scope.
- Route public image decode through covered separate color SOF9 arithmetic
  scans.
- Route public raw component decode through the covered SOF9 arithmetic
  coefficient scope.
- Route restarted public raw component decode through the covered SOF9
  arithmetic coefficient scope.
- Route public raw component decode through covered separate color SOF9
  arithmetic scans.
- Route two-component SOF9 arithmetic sequential DCT streams through public raw
  component decode without color conversion.
- Route two-component SOF2/SOF10 progressive DCT streams through public raw
  component decode without color conversion.
- Route 8/12-bit two-component SOF3 Huffman lossless streams through public raw
  component decode without color conversion.
- Route 8/12-bit two-component SOF11 arithmetic lossless streams through public raw
  component decode without color conversion.
- Cover nonzero point-transform round-trips for public SOF11 arithmetic
  lossless grayscale and RGB-family encoding.
- Route post-header public grayscale image and raw component decode through the
  covered SOF9 arithmetic coefficient scope.
- Reject covered public SOF9 arithmetic coefficient streams missing required
  DAC conditioning tables with deterministic table-definition failures.
- Reject post-header covered public SOF9 arithmetic coefficient streams missing
  required DAC conditioning tables before reporting decoded blocks.
- Reject covered public SOF9 arithmetic image and raw component streams missing
  required DAC conditioning tables before writing caller output.
- Reject post-header covered public SOF9 arithmetic raw component streams missing
  required DAC conditioning tables before writing caller output.
- Reject post-header covered public SOF9 arithmetic image streams missing
  required DAC conditioning tables before writing caller output.
- Reject covered public SOF9 arithmetic coefficient streams with partial
  DC-only or AC-only DAC conditioning-table state.
- Reject post-header covered public SOF9 arithmetic coefficient streams with
  partial DC-only or AC-only DAC conditioning-table state.
- Reject covered public SOF9 arithmetic image and raw component streams with
  partial DC-only or AC-only DAC conditioning-table state before writing caller
  output.
- Reject post-header covered public SOF9 arithmetic raw component streams with
  partial DC-only or AC-only DAC conditioning-table state before writing caller
  output.
- Reject post-header covered public SOF9 arithmetic image streams with partial
  DC-only or AC-only DAC conditioning-table state before writing caller output.
- Reject covered public SOF9 arithmetic image and raw component streams missing
  required quantization tables before arithmetic entropy decode or caller output
  writes.
- Reject post-header covered public SOF9 arithmetic image and raw component
  streams missing required quantization tables before arithmetic entropy decode
  or caller output writes.
- Reject covered public SOF9 arithmetic coefficient streams with undersized
  caller block storage before entropy decode.
- Add an internal byte-ownership reservation primitive with AUnit coverage and
  proof-readiness documentation for idempotent release behavior.
- Represent advanced SOF frame families during header parsing instead of
  treating them as unsupported marker families.
- Cover advanced SOF marker families with header mode, entropy, and precision
  tests.
- Route covered SOF1 extended sequential 8-bit grayscale coefficient and image
  decode through the sequential Huffman path.
- Route covered SOF1 extended sequential 12-bit grayscale image and raw
  component decode through precision-aware IDCT reconstruction into byte output.
- Route covered SOF3 lossless Huffman 8-bit grayscale image and raw component
  decode through direct predictor-1 through predictor-7 sample reconstruction,
  including nonzero category-bit deltas, header-ready decode entry points, and
  restart marker predictor resets.
- Route covered SOF3 lossless Huffman 8-bit YCbCr image decode through direct
  interleaved component sample reconstruction.
- Route covered SOF3 lossless Huffman 8-bit YCbCr raw component decode through
  direct interleaved component sample reconstruction.
- Route covered SOF3 lossless Huffman 8-bit CMYK image and raw component decode
  through direct interleaved component sample reconstruction.
- Route covered SOF3 lossless Huffman 8-bit YCCK image and raw component decode
  through Adobe APP14 transform 2 color-model reconstruction.
- Route covered SOF3 lossless Huffman 12-bit grayscale image and raw component
  decode through source-precision predictor reconstruction and byte-output
  scaling.
- Route covered SOF11 lossless arithmetic 8-bit grayscale image and raw
  component decode through direct arithmetic DC-difference reconstruction.
- Route covered SOF11 lossless arithmetic 12-bit grayscale image and raw
  component decode through source-precision predictor reconstruction and
  byte-output scaling.
- Route covered SOF11 lossless arithmetic 8-bit YCbCr and RGB image/raw
  component decode through interleaved arithmetic DC-difference reconstruction.
- Route covered SOF11 lossless arithmetic 8-bit CMYK and YCCK image/raw
  component decode through interleaved arithmetic DC-difference reconstruction.
- Route covered SOF10 arithmetic progressive DC-first/refine, nonzero
  AC-first, AC-refine grayscale including arithmetic magnitude-ladder newly
  nonzero coefficients, YCbCr coefficient AC-first, plus DC-first YCbCr, RGB,
  CMYK, and YCCK
  coefficient, image, and raw component decode through progressive scan-state
  validation and arithmetic reconstruction.
- Extend covered SOF2 Huffman progressive YCbCr coefficient decode from
  interleaved DC-only scans to a follow-on single-component luma AC-first scan.
- Extend the internal arithmetic DC/EOB scan helper from single-component scans
  to interleaved color scans with MCU-order restart accounting.
- Report DHP hierarchical header presence in public image information.
- Add unsupported advanced SOF input to the deterministic fuzz corpus.
- Route covered progressive grayscale streams through public raw component
  decode without color conversion.
- Add fixture generation, conformance, deterministic fuzz, documentation,
  proof-readiness, benchmark, and release-readiness project tools under the
  Alire tests crate.
- Enforce the canonical `alr exec -- tests/bin/...` command policy in
  contributing documentation plus the documentation and release readiness
  checkers.
- Advertise the V1 capability flags for arithmetic coding, 12-bit DCT,
  lossless JPEG, and hierarchical JPEG after their covered public scopes landed.
- Align README V1 wording with the advertised capability surface instead of
  describing enabled public features as slices.

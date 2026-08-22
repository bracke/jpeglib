# jpeglib

`jpeglib` is a native Ada 2022 JPEG codec library. The V1 target is complete
general-purpose 8-bit JPEG decoding and encoding, including baseline,
progressive, metadata preservation, resource limits, streaming interfaces, and
deterministic error reporting.

This repository supports baseline Huffman JPEG decode for grayscale, YCbCr,
RGB JPEG, and plain CMYK inputs, progressive grayscale, YCbCr, and RGB JPEG
decode, including grayscale DC+AC multi-scan reconstruction. Public
`Encode_Image` covers the V1 mode/format matrix for `Gray_8`,
`Gray_Alpha_16`, `RGB_24`, `BGR_24`, `RGBA_32`, `BGRA_32`, `CMYK_32`, and
`YCCK_32` image views:
sequential, arithmetic sequential, differential, hierarchical, Huffman
lossless, arithmetic lossless, differential lossless, and hierarchical
lossless modes round-trip through the public decoder for the supported
non-progressive or built-in progressive policy choices. CMYK/YCCK public encode
is covered across the DCT and lossless mode families, including direct
four-channel same-format round trips and Adobe APP14 transform 2 emission for
YCCK.
Decode-side metadata summaries, bounded caller-buffer retention, metadata
callbacks, ICC fragment validation, and encoder-side queued APP/COM metadata
emission are implemented. ICC APP2 fragments are preserved as assembled profile
payload bytes when retained metadata is requested. Exif APP1/TIFF orientation
is parsed into header information and can be applied during image decode. Raw
component access decodes reconstructed component sample planes into
caller-provided buffers without color conversion; the default decode limits cap
streams at four components, while callers can raise `Max_Components` for
wider Huffman/arithmetic lossless and differential-lossless coefficient and
raw-component streams. Adobe APP14 transform 2 YCCK
decode is implemented for four-component images. Reduced IDCT output can decode
at full, half, quarter, or eighth size. Arithmetic-coded and differential DCT
decode and encode, DHP-marked hierarchical DCT encode, multi-frame
hierarchical lossless encode, 12-bit sequential DCT byte-output decode,
Huffman, arithmetic, differential, and hierarchical lossless decode and encode,
and hierarchical header reporting are implemented for the public V1 API. Unknown
two-component image decode maps the first component as gray and the second as
alpha where the requested output format carries alpha; unknown three-component
image decode maps the component channels directly to RGB-family outputs,
unknown four-component image decode maps the first three channels to RGB and
the fourth to alpha where the requested output format carries alpha, and
opt-in wider DCT and lossless image decode consumes all component data while
projecting the first four components through the same direct-channel policy.
Public coefficient block transforms support flips, rotations, transpose, and
transverse operations on natural-order 8x8 DCT blocks.

Policy boundaries are explicit: lossless encode modes reject progressive-script
requests, EXP expansion markers are skipped as length-bearing syntax, standalone
TEM markers are skipped in marker-stream positions, unsupported special JPEG
marker families fail deterministically, and
SOF zero-height/DNL-defined images are reported by header parsing with
`Height_Defined = False`; full-size public raw and image decode can use the
caller output views as provisional geometry, and public coefficient decode can
use exact caller block geometry, then validate them against DNL.
Known-height post-scan DNL markers are accepted only when they match the parsed
frame height.

## Crates

- Root crate: `jpeglib`
- Root package: `Jpeglib`
- Child crate: `tests`

The production crate is Ada-only and does not depend on AUnit,
`project_tools`, `cryptolib`, `zlib`, libjpeg, or any other JPEG codec.

Local development expects sibling checkouts for dependencies under `../`,
including `../hostkit`, `../project_tools`, `../cryptolib`, and `../zlib`.

## Development checks

Use Alire for every build and toolchain command:

```sh
alr build
alr --chdir tests build
alr exec -- tests/bin/jpeglib_tests
alr exec -- tests/bin/jpeglib_check
alr exec -- tests/bin/jpeglib_generate
alr exec -- tests/bin/jpeglib_conformance
alr exec -- tests/bin/jpeglib_fuzz
alr exec -- tests/bin/jpeglib_benchmark
alr exec -- tests/bin/jpeglib_docs
alr exec -- tests/bin/jpeglib_prove
alr exec -- tests/bin/jpeglib_prove --run
alr exec -- tests/bin/jpeglib_release
```

`jpeglib_tests` is the AUnit test runner. `jpeglib_check` is the aggregate local
gate: it verifies the AUnit suite inventory with `project_tools`, runs the root
and tests crate builds through Alire, verifies the coefficient and image fixture
corpora, runs the ImageMagick-backed conformance check, including generated
baseline/progressive gray and RGB JPEGs decoded by `jpeglib` across 2x2, 4x3,
5x2, 5x3, 4x4, 17x9, 9x17, 17x1, and 2x17 samples with varied quality and
sampling, runs the deterministic fuzz corpus, checks documentation policy, and
then runs the AUnit suite. The conformance step requires the `magick` command on
`PATH`.
The external reference policy is tracked in `docs/external_reference_matrix.md`;
ImageMagick-supported grayscale/RGB cases are required, and advanced arithmetic,
CMYK/YCCK, lossless, differential, and hierarchical modes are required to pass
the separate `tests/bin/jpeglib_decode_raw` native process oracle. CMYK/YCCK
baseline/progressive conformance also requires the installed `ffmpeg` command as
a third-party RGB-conversion oracle. ImageMagick remains diagnostic when host
tools do not expose a stable byte oracle for an advanced mode. Lossless Huffman
grayscale/RGB conformance also requires `ffmpeg` as a third-party raw-byte
oracle.
`jpeglib_prove` audits proof-readiness by default; `jpeglib_prove --run` runs
the current proof profile for checked arithmetic, descriptor-only image view
bounds via `Jpeglib.Images.Descriptor_Is_Valid`, and segment boundary helpers
through `alr exec -- gnatprove`.

Fixture files live under `tests/fixtures/coefficients` and
`tests/fixtures/images`. Refresh them with:

```sh
alr exec -- tests/bin/jpeglib_fixtures --generate
```

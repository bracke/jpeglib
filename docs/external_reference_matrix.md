# External Reference Matrix

`jpeglib_conformance` uses external tools only as reference or compatibility
oracles. The library implementation and release gate must not depend on a
system JPEG codec for production behavior. Every external row has a final
required outcome: either a positive raw-byte oracle or a compatibility-boundary
check that pins the behavior of host tools that cannot decode a JPEG family.

| JPEG scope | Current external tool | Gate policy | Notes |
| --- | --- | --- | --- |
| Baseline grayscale encode | ImageMagick `magick` | Required | Decodes `jpeg:-` to `gray:-` and compares raw samples with bounded tolerance. |
| Progressive grayscale encode | ImageMagick `magick` | Required | Same raw `gray:-` comparison as baseline grayscale. |
| Baseline RGB encode, 4:4:4/4:2:2/4:2:0/4:1:1 | ImageMagick `magick` | Required | Decodes to `rgb:-` and compares raw RGB bytes with bounded tolerance. |
| Progressive RGB encode, 4:4:4/4:2:2/4:2:0/4:1:1 | ImageMagick `magick` | Required | Decodes to `rgb:-` and compares raw RGB bytes with bounded tolerance. |
| Arithmetic sequential/progressive DCT encode | `tests/bin/jpeglib_decode_raw`; `ffmpeg`; ImageMagick `magick` | Required native process oracle; required compatibility-boundary check | Encoded artifacts must decode through the separate raw-decoder process and compare to source pixels. This host's `ffmpeg` and ImageMagick builds reject arithmetic JPEG external decode, so the conformance gate requires the documented external rejection behavior. |
| CMYK/YCCK four-channel encode | `tests/bin/jpeglib_decode_raw`; `ffmpeg`; ImageMagick `magick` | Required native process oracle; required third-party `ffmpeg` RGB-conversion oracle | Encoded artifacts must decode through the separate raw-decoder process and compare to source channels; `ffmpeg` must decode baseline/progressive CMYK/YCCK artifacts to stable RGB bytes derived from the source channels; ImageMagick raw `cmyk:-` output is recorded as tool-specific telemetry. |
| Lossless Huffman grayscale/RGB encode, including restarted artifacts | `tests/bin/jpeglib_decode_raw`; `ffmpeg`; ImageMagick `magick` | Required native process oracle; required third-party `ffmpeg` oracle | Encoded artifacts must decode through the separate raw-decoder process and `ffmpeg` raw gray/RGB output; restarted artifacts must contain emitted restart markers before the raw-byte oracles run; external ImageMagick acceptance is recorded as tool-specific telemetry. |
| Differential DCT, hierarchical DCT, and hierarchical lossless encode | `tests/bin/jpeglib_decode_raw`; `ffmpeg`; ImageMagick `magick` | Required native process oracle; required compatibility-boundary check | Encoded artifacts must decode through the separate raw-decoder process and compare to source pixels. Installed third-party tools do not provide a stable raw-byte oracle for these marker families, so conformance requires the documented external rejection or mismatch behavior. |

Advanced rows fail if `jpeglib` cannot encode, in-process self-decode, or decode
through the separate `jpeglib_decode_raw` process oracle. CMYK/YCCK rows also
fail if the installed `ffmpeg` command cannot decode baseline/progressive
artifacts to matching RGB conversion bytes. Lossless Huffman grayscale/RGB rows,
including restarted artifacts, also fail if `ffmpeg` cannot decode the generated
artifact to matching raw gray/RGB bytes. Arithmetic sequential/progressive and
differential DCT rows fail if `ffmpeg` stops rejecting the generated advanced
artifact on this host. Hierarchical DCT/lossless rows fail if `ffmpeg` no longer
returns the documented same-length mismatching byte stream. Those outcomes are
part of the current conformance contract.

The current required advanced oracle is native and process-isolated:
`jpeglib_conformance` writes the generated JPEG artifact, launches
`tests/bin/jpeglib_decode_raw`, captures raw output bytes, and compares them with
bounded tolerances. For CMYK/YCCK artifacts the gate also launches `ffmpeg` and
requires matching RGB conversion bytes. For lossless Huffman grayscale/RGB
artifacts, including restarted artifacts with emitted restart markers, the gate
also launches `ffmpeg` and requires matching raw gray/RGB bytes. Arithmetic,
differential, and hierarchical rows launch `ffmpeg` as a required compatibility
boundary check, not a positive oracle.

The executable LC1 manifest is closed: every row is required positive evidence
or required compatibility-boundary evidence, and tool behavior changes must be
accepted by updating both conformance evidence and this matrix.
The executable LC1 manifest is `tests/fixtures/external/oracle_matrix.txt`; it
is validated during bootstrap with:

```sh
alr exec -- tests/bin/jpeglib_external_matrix
```

# External Reference Matrix

`jpeglib_conformance` uses external tools only as reference or diagnostic
oracles. The library implementation and release gate must not depend on a
system JPEG codec for production behavior.

| JPEG scope | Current external tool | Gate policy | Notes |
| --- | --- | --- | --- |
| Baseline grayscale encode | ImageMagick `magick` | Required | Decodes `jpeg:-` to `gray:-` and compares raw samples with bounded tolerance. |
| Progressive grayscale encode | ImageMagick `magick` | Required | Same raw `gray:-` comparison as baseline grayscale. |
| Baseline RGB encode, 4:4:4/4:2:2/4:2:0/4:1:1 | ImageMagick `magick` | Required | Decodes to `rgb:-` and compares raw RGB bytes with bounded tolerance. |
| Progressive RGB encode, 4:4:4/4:2:2/4:2:0/4:1:1 | ImageMagick `magick` | Required | Decodes to `rgb:-` and compares raw RGB bytes with bounded tolerance. |
| Arithmetic sequential/progressive DCT encode | `tests/bin/jpeglib_decode_raw`; ImageMagick `magick` | Required native process oracle; ImageMagick diagnostic | Encoded artifacts must decode through the separate raw-decoder process and compare to source pixels; this host's ImageMagick rejects arithmetic JPEG external decode. |
| CMYK/YCCK four-channel encode | `tests/bin/jpeglib_decode_raw`; `ffmpeg`; ImageMagick `magick` | Required native process oracle; required third-party `ffmpeg` RGB-conversion oracle; ImageMagick diagnostic | Encoded artifacts must decode through the separate raw-decoder process and compare to source channels; `ffmpeg` must decode baseline/progressive CMYK/YCCK artifacts to stable RGB bytes derived from the source channels; ImageMagick raw `cmyk:-` output may use a different channel convention. |
| Lossless Huffman grayscale/RGB encode | `tests/bin/jpeglib_decode_raw`; `ffmpeg`; ImageMagick `magick` | Required native process oracle; required third-party `ffmpeg` oracle; ImageMagick diagnostic | Encoded artifacts must decode through the separate raw-decoder process and `ffmpeg` raw gray/RGB output; external ImageMagick acceptance is reported when the host decoder supports the mode. |
| Differential DCT, hierarchical DCT, and hierarchical lossless encode | `tests/bin/jpeglib_decode_raw`; ImageMagick `magick` | Required native process oracle; ImageMagick diagnostic | Encoded artifacts must decode through the separate raw-decoder process and compare to source pixels; installed third-party tools do not provide a stable raw-byte oracle for these marker families. |

Diagnostic ImageMagick cases are intentionally non-fatal for external decode
rejection or channel convention differences. Advanced rows still fail if
`jpeglib` cannot encode, in-process self-decode, or decode through the separate
`jpeglib_decode_raw` process oracle. CMYK/YCCK rows also fail if the installed
`ffmpeg` command cannot decode baseline/progressive artifacts to matching RGB
conversion bytes. Lossless Huffman grayscale/RGB rows also fail if `ffmpeg`
cannot decode the generated artifact to matching raw gray/RGB bytes.

To promote an ImageMagick diagnostic row to a required third-party byte oracle,
the project needs a host command available from the conformance harness that can
decode the mode to stable raw bytes without changing component conventions. The
current required advanced oracle is native and process-isolated:
`jpeglib_conformance` writes the generated JPEG artifact, launches
`tests/bin/jpeglib_decode_raw`, captures raw output bytes, and compares them with
bounded tolerances. For CMYK/YCCK artifacts the gate also launches `ffmpeg` and
requires matching RGB conversion bytes. For lossless Huffman grayscale/RGB
artifacts the gate also launches `ffmpeg` and requires matching raw gray/RGB
bytes.

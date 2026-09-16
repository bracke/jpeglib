# AI-Oriented Implementation Guide

Implement in dependency order. Do not add pixel reconstruction before exact
coefficient decoding has independent known-answer tests. Do not retrofit
progressive support onto a baseline-only state model.

## Package Responsibilities

- `Jpeglib`: foundational types only.
- `Jpeglib.Errors` and `Jpeglib.Results`: stable operational outcomes.
- `Jpeglib.Limits`: hostile-input resource budgets.
- `Jpeglib.Streams`: source and destination interfaces.
- `Jpeglib.Decoding` and `Jpeglib.Encoding`: public lifecycle APIs.
- `Jpeglib.Internal.*`: implementation layers only.

## Dependency Direction

Low-level bytes, arithmetic, markers, segments, tables, entropy, coefficients,
transforms, sampling, color, metadata, recovery, then orchestration.

Production packages must not depend on AUnit, `project_tools`, or the child
`tests` crate.

## Current High-Bit-Depth Encode Contract

12-bit DCT encode is not a sequential-only surface. Keep the following paths in
sync when changing precision handling, progressive scans, or coefficient
workspaces:

- `Jpeglib.Coefficients.Encoding.Encode_Grayscale_Twelve_Bit`,
  `Encode_YCbCr_Twelve_Bit`, `Encode_CMYK_Twelve_Bit`, and
  `Encode_YCCK_Twelve_Bit` emit SOF1 extended sequential precision-12 Huffman
  streams from caller-supplied quantized coefficients.
- `Jpeglib.Encoding.Encode_Raw_Grayscale_Twelve_Bit`,
  `Encode_Raw_YCbCr_Twelve_Bit`, `Encode_Raw_CMYK_Twelve_Bit`, and
  `Encode_Raw_YCCK_Twelve_Bit` accept packed two-byte raw samples in caller
  byte order. Sequential requests emit SOF1 precision-12 Huffman streams;
  `Fast_Preview_Progressive` and `Balanced_Progressive` requests emit SOF2
  precision-12 Huffman streams.
- Raw CMYK/YCCK progressive encode uses the four-component progressive
  component-scan path. YCCK must retain Adobe APP14 transform 2.
- Lossless encode modes still reject progressive-script options
  deterministically; do not generalize the 12-bit DCT policy to lossless modes.

Before treating this area as complete, run the pinned-toolchain build and the
focused public test contract:

```sh
alr --chdir tests build
alr exec -- tests/bin/jpeglib_tests
```

The required public regression is
`coefficient_encoding.raw_twelve_bit_progressive`; the complete-plus precision
matrix also records the SOF1/SOF2 12-bit raw encode policy.

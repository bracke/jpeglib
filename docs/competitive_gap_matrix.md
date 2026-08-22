# Competitive Gap Matrix

This document tracks gaps against mature JPEG ecosystems beyond the repository's
current `jpeglib_complete` gate. libjpeg-compatible API or ABI compatibility is
explicitly out of scope.

The executable matrix is:

```sh
alr exec -- tests/bin/jpeglib_complete_plus --allow-open
```

Plain `jpeglib_complete_plus` is strict and requires every row in
`tests/fixtures/complete_plus/gap_matrix.txt` to be closed.

| Gap | Target | Closure Evidence |
| --- | --- | --- |
| Multi-platform CI | `jpeglib_complete` passes on Linux, macOS, and Windows with Alire-only toolchain use. | CI matrix and successful runs. |
| Expanded real-world corpus | Camera, phone, web, editor, print, metadata-heavy, progressive, CMYK/YCCK, and malformed-common JPEGs have pinned expectations. | Strict corpus manifest with digests, header/metadata expectations, and decode checks. |
| Lossless transform API | jpegtran-style rotate, flip, transpose, crop, optimize, and valid baseline/progressive conversion. | `Jpeglib.Transforms`, CLI coverage, AUnit coverage, and jpegtran comparison where available. |
| Encoder optimization | Optimized Huffman tables, progressive scan optimization, perceptual presets, and target-size search. | Deterministic compression/quality benchmark matrix. |
| Precision and buffer API | High-bit-depth public views and legal lossless precision expansion. | Public API tests for preserve, clamp, scale, and reject policies. |
| Performance architecture | Scalar reference benchmarks and hostkit-backed optional platform acceleration hooks. | Benchmark thresholds and scalar equivalence tests. |

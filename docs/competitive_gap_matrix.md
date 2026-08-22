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
| Multi-platform CI | `jpeglib_complete` passes on Linux, macOS, and Windows with Alire-only toolchain use. | Closed by GitHub Actions `ci` run `32572734862`, with green `ubuntu-latest`, `macos-15-intel`, and `windows-latest` matrix jobs. |
| Expanded real-world corpus | Camera, phone, web, editor, print, metadata-heavy, progressive, CMYK/YCCK, and malformed-common JPEGs have pinned expectations. | Closed by `jpeglib_real_world`: 19 typed manifest rows with file digests, header/metadata expectations, decoded output SHA-256 values, and deterministic malformed rejection checks. |
| Lossless transform API | jpegtran-style rotate, flip, transpose, crop, optimize, and valid baseline/progressive conversion. | Closed by `Jpeglib.Transforms`-compatible coefficient operations through `Jpeglib.Coefficients.Transform_Image`, `Jpeglib.Coefficients.Encoding` baseline/progressive coefficient output, `Optimize_Huffman` coefficient-derived DHT emission, AUnit round trips, `jpeglib_transform --self-test`, and an optional `jpegtran` transpose comparison when `jpegtran` is on PATH. |
| Encoder optimization | Optimized Huffman tables, progressive scan optimization, perceptual presets, and target-size search. | Closed by `Jpeglib.Encoding` `Optimize_Huffman`, `Target_Bytes`, and perceptual presets; sequential and progressive Huffman image encoders derive optimized DHT tables from generated DCT blocks; `jpeglib_encoder_optimization` enforces deterministic default, optimized, progressive, preset, and target-size byte relationships. |
| Precision and buffer API | High-bit-depth public views and legal lossless precision expansion. | Closed by `Jpeglib.Decoding` `Raw_Output_Precision` and `Raw_Precision` policies; `Decode_Raw_Components` validates one-byte and two-byte caller buffers and implements scale, clamp, preserve, and reject behavior for legal 12-bit lossless streams; `jpeglib_precision_buffer` enforces the public policy matrix. |
| Performance architecture | SIMD-capable color hot paths, scalar-equivalence checks, and hostkit-backed platform reporting. | Closed by `Jpeglib.Internal.Colors` compiler-vectorized row RGB-to-YCbCr kernels, `Jpeglib.Capabilities.SIMD_Acceleration`, `jpeglib_simd_matrix` bit-exact scalar equivalence checks across RGB/BGR/RGBA/BGRA storage, and `jpeglib_performance_matrix` host-reported encode/decode thresholds. |

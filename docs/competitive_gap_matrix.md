# Competitive Gap Matrix

This document tracks gaps against mature JPEG ecosystems beyond the repository's
current `jpeglib_complete` gate. libjpeg-compatible API or ABI compatibility is
explicitly out of scope.

The strict executable matrix is:

```sh
alr exec -- tests/bin/jpeglib_complete_plus
```

Plain `jpeglib_complete_plus` is strict and requires every row in
`tests/fixtures/complete_plus/gap_matrix.txt` to be closed.
`alr exec -- tests/bin/jpeglib_complete_plus --allow-open` is retained only for
staging future rows before their evidence is complete.

| Gap | Target | Closure Evidence |
| --- | --- | --- |
| Multi-platform CI | `jpeglib_complete` passes on Linux, macOS, and Windows with Alire-only toolchain use. | Closed by GitHub Actions `ci` run `32572734862`, with green `ubuntu-latest`, `macos-15-intel`, and `windows-latest` matrix jobs. |
| Expanded real-world corpus | Camera, phone, web, editor, print, metadata-heavy, progressive, CMYK/YCCK, and malformed-common JPEGs have pinned expectations. | Closed by `jpeglib_real_world`: 19 typed manifest rows with file digests, header/metadata expectations, decoded output SHA-256 values, and deterministic malformed rejection checks. |
| Lossless transform API | jpegtran-style rotate, flip, transpose, crop, optimize, and valid baseline/progressive conversion. | Closed by `Jpeglib.Transforms`-compatible coefficient operations through `Jpeglib.Coefficients.Transform_Image`, `Jpeglib.Coefficients.Encoding` baseline/progressive coefficient output, `Optimize_Huffman` coefficient-derived DHT emission, AUnit round trips, `jpeglib_transform --self-test`, and an optional `jpegtran` transpose comparison when `jpegtran` is on PATH. |
| Encoder optimization | Optimized Huffman tables, progressive scan optimization, perceptual presets, and target-size search. | Closed by `Jpeglib.Encoding` `Optimize_Huffman`, `Target_Bytes`, and perceptual presets; sequential and progressive Huffman image encoders derive optimized DHT tables from generated DCT blocks; `jpeglib_encoder_optimization` enforces deterministic default, optimized, progressive, preset, and target-size byte relationships. |
| Progressive coefficient extraction | Public coefficient extraction for generated balanced/fast-preview progressive scan scripts across grayscale, YCbCr/RGB, CMYK, and YCCK outputs. | Closed by `foundation.decoder.public_progressive_coefficients_generated`, which encodes public progressive grayscale, RGB, CMYK, and YCCK streams with AC detail and decodes them back through `Jpeglib.Decoding.Decode_Coefficients` while checking SOF2 headers, component block counts, color models, scan visits, and retained AC coefficients. |
| Precision and buffer API | High-bit-depth public views, DCT/lossless raw precision preservation, and public buffer helpers. | Closed by `Jpeglib.Decoding` `Raw_Output_Precision`, `Raw_Precision`, and `Raw_Byte_Order` policies; `Decode_Raw_Components` validates one-byte and two-byte caller buffers and implements scale, clamp, preserve, and reject behavior for legal 12-bit DCT and lossless streams; SOF1/SOF2 12-bit grayscale, YCbCr, CMYK, and YCCK coverage verifies public image, raw component, coefficient decode, and raw encode round trips; public helpers expose effective raw precision, bytes per sample, minimum row bytes, accessible bytes, raw view validation, packed sample position checks, direct and non-raising packed sample reads, and saturating oversized-dimension handling; `jpeglib_precision_buffer`, `foundation.decoder.decode_twelve_bit_dct_color`, `coefficient_encoding.raw_twelve_bit_progressive`, and `coefficient_encoding.raw_twelve_bit_ycck` enforce the public policy matrix. |
| Performance architecture | SIMD-capable color hot paths, scalar-equivalence checks, and hostkit-backed platform reporting. | Closed by `Jpeglib.Internal.Colors` compiler-vectorized row RGB-to-YCbCr input, gray-alpha input, CMYK/YCCK input, YCbCr-to-RGB-family output, direct RGB output, gray output, gray-alpha output, CMYK output, and YCCK output kernels; encoder plane filling and decode row output use those kernels for direct full-size grayscale, two-component, three-component, four-component, lossless, 4:4:4 DCT decode, direct-output three-component subsampled DCT decode, and direct-output four-component CMYK/YCCK subsampled DCT decode; encoder chroma downsampling for 4:4:4, 4:2:2, 4:2:0, and 4:1:1 plus encoder full-block sample loading use compiler-vectorized image-block loops; `Jpeglib.Capabilities.SIMD_Acceleration` advertises the surface; `jpeglib_simd_matrix` checks bit-exact scalar equivalence across every public input/output format plus downsampling layout and reports the concrete `compiler-vectorized` backend; `jpeglib_performance_matrix` reports host-backed encode/decode thresholds plus JSON-style evidence records. |

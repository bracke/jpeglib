# Proof Profile

The release gate runs `jpeglib_prove --run` as an executable proof pass. The
same proof pass is available directly through:

```sh
alr exec -- tests/bin/jpeglib_prove --run
```

`jpeglib_prove --run` invokes proof tooling only through `alr exec`; it does not
call GNATprove from the system `PATH`. The first executable proof profile uses
`proof/jpeglib_proof.gpr` and targets these proof-designated units:

- `Jpeglib.Internal.Checked_Arithmetic`
- `Jpeglib.Images`
- `Jpeglib.Internal.Segments`

The broader proof-designated invariant registry remains in `docs/invariants.md`.
`Jpeglib.Internal.Segments` is proved for the segment-length and bounded-skip
state-transition helpers used by the public segment reader. Ownership stays in
the proof-readiness audit until its API is tightened enough for a non-noisy
proof pass. `Jpeglib.Images` is proved for the descriptor-only
`Descriptor_Is_Valid` arithmetic layer, including overflow-safe row-span rejection
before stride-height multiplication. The access-bearing public view
validators stay outside SPARK because anonymous access components are not
SPARK-legal and only delegate null-checked descriptors into that predicate.

`jpeglib_release` runs this profile as its release proof gate. Direct
GNATprove invocations are intentionally outside the project workflow; use the
`alr` command above.

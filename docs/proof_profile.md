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
- `Jpeglib.Internal.Ownership`

The broader proof-designated invariant registry remains in `docs/invariants.md`.
The caller-buffer and unsafe-boundary policy is documented in
`docs/limits_and_safety.md`.
`Jpeglib.Internal.Segments` is proved for the segment-length and bounded-skip
state-transition helpers used by the public segment reader.
`Jpeglib.Internal.Ownership` is proved for budget/lease accounting, failed
reservation side effects, and idempotent release through SPARK-visible
`Reserve_State` and `Release_State` transitions. `Jpeglib.Images` is proved for
the descriptor-only
`Descriptor_Is_Valid` arithmetic layer, including overflow-safe row-span rejection
before stride-height multiplication. The access-bearing public view
validators stay outside SPARK because anonymous access components are not
SPARK-legal and only delegate null-checked descriptors into that predicate.
This means the proved boundary is descriptor arithmetic; access lifetime is a
caller-buffer contract enforced at runtime by null checks and by descriptor
validation before public decode/encode writes.

`jpeglib_prove --run` also checks the GNATprove summary for unproved checks,
severity diagnostics, and declared SPARK bodies that were skipped. `jpeglib_release`
runs this profile as its release proof gate. Direct GNATprove invocations are
intentionally outside the project workflow; use the `alr` command above.

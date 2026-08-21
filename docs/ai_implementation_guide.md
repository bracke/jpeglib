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

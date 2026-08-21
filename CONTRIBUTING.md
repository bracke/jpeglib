# Contributing

Follow the phase order documented in `docs/ai_implementation_guide.md`.
Production code must remain Ada-only and must not introduce codec wrappers or
test-only dependencies.

Use Alire for all GNAT/GPR/toolchain work. Do not call system GNAT, GPRBuild,
GNATprove, or GNATdoc directly from `PATH`; use `alr` so the pinned toolchain is
selected.

Tests use AUnit. Test and release tooling should live in the tests crate, use
`../project_tools` for test/release policy, and use `../hostkit` for
host-specific process and filesystem behavior.

Keep the repository buildable after every change. The day-to-day gate is:

```sh
alr exec -- tests/bin/jpeglib_check
```

# Agent instructions — jpeglib

Native Ada JPEG decoding and encoding library.

This crate pins its GNAT toolchain via Alire (`gnat_native = "^15"`). Build and test with `alr`, not
system GNAT / GPRBuild / GNATprove / GNATdoc tools on `PATH` — `alr exec -- gnatls --version` must report the pinned GNAT.

```sh
alr build
```

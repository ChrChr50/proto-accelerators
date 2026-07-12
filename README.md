# proto-accelerators

[![CI](https://github.com/ChrChr50/proto-accelerators/actions/workflows/ci.yml/badge.svg)](https://github.com/ChrChr50/proto-accelerators/actions/workflows/ci.yml)

A monorepo for prototype hardware accelerator projects — RTL through GDSII on
open-source tooling and open PDKs.

## Projects

- **[macc8/](macc8/)** — signed int8, 8-lane (4-lane configurable) dot-product
  accelerator. SystemVerilog RTL, cocotb verification, SymbiYosys formal
  properties, and an OpenLane 2 / Sky130 physical design flow. See
  [macc8/README.md](macc8/README.md) for its own quickstart and toolchain.

Future prototype accelerators will live alongside `macc8/` as sibling
directories, each with its own `README.md`, `CLAUDE.md`, and build flow.

## License

Apache-2.0 — see [LICENSE](LICENSE). Individual projects may override this if
a future prototype needs different terms.

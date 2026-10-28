# proto-accelerators

[![CI](https://github.com/ChrChr50/proto-accelerators/actions/workflows/ci.yml/badge.svg)](https://github.com/ChrChr50/proto-accelerators/actions/workflows/ci.yml)

Small hardware accelerator prototypes, taken from RTL toward GDSII using only
open-source tools and open PDKs.

## Projects

- **[macc8/](macc8/)**: a signed int8 dot-product engine with 8 lanes (or 4,
  set at runtime). SystemVerilog RTL, a cocotb testbench, SymbiYosys proofs,
  and an OpenLane 2 flow targeting Sky130. Build instructions are in
  [macc8/README.md](macc8/README.md).

New prototypes will get their own top-level folder next to `macc8/`, each
with its own README and build setup.

## License

Apache-2.0, see [LICENSE](LICENSE). A project folder can carry its own
license if it ever needs different terms.

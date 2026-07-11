# reports/

Every `make lint`, `make sim` / `sim-fast` / `sim-icarus`, and `make formal`
run writes its output here, under a timestamped subdirectory, and that
subdirectory is committed to the repo — this is the project's actual,
reproducible verification record, not a throwaway log.

## Naming convention

```
reports/<YYYYMMDD-HHMMSS>_<target>/
```

The timestamp is computed once per `make` invocation (so a single `make sim`
run gets one consistent timestamp even though it touches multiple files).

| Directory suffix | Produced by | Contents |
|---|---|---|
| `_lint` | `make lint` | `verible.log`, `verilator.log` |
| `_sim-full` | `make sim` | `sim.log` (full regression incl. real int32 overflow crossing), `results.xml` (cocotb JUnit-style results) |
| `_sim-fast` | `make sim-fast` | same as above, but with `MACC8_FAST=1` (capped overflow loop, for quick iteration) |
| `_sim-icarus` | `make sim-icarus` | same as `_sim-fast`, run under Icarus Verilog instead of Verilator (see `env/tool-versions.md` for a cocotb-version caveat specific to this path) |
| `_formal` | `make formal` | `fsm_props.log` / `handshake_props.log`, plus the full SymbiYosys work directories (`fsm_props/`, `handshake_props/` — SMT2 models, per-engine logs, `PASS`/`FAIL` marker files) |

## Why timestamped and committed, not overwritten in place

A single `reports/lint.log` that gets clobbered on every run only ever shows
the most recent result — there's no record of when something last passed, or
whether a fix actually changed the outcome. Timestamped, committed
directories make the verification history part of the repo's own history,
inspectable via `git log -- reports/` without needing to have run anything
yourself.

## What's still git-ignored

`build/`, `pd/openlane/runs/`, and `pdk/` remain scratch space (large,
regenerable, or PDK-managed) — see the repo root `.gitignore`. Manually
running `verif/formal/run_formal.sh` directly (bypassing `make formal`) still
writes to `verif/formal/<task>/`, which also stays git-ignored — that path is
for quick local iteration, not the committed record.

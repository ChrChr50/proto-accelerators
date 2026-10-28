# reports/

`make lint`, `make sim` / `sim-fast` / `sim-icarus`, `make formal` and
`make synth-check` each put their output in a new timestamped folder here,
and those folders are committed. This is the project's verification record,
not a scratch log.

## Folder names

```
reports/<YYYYMMDD-HHMMSS>_<target>/
```

The timestamp is taken once per `make` call, so all files from one run share
it.

| Suffix | Made by | What's inside |
|---|---|---|
| `_lint` | `make lint` | `verible.log`, `verilator.log` |
| `_sim-full` | `make sim` | `sim.log` (full run, including the real int32 overflow) and `results.xml` (cocotb's JUnit-style results) |
| `_sim-fast` | `make sim-fast` | the same, with `MACC8_FAST=1` so the overflow loops stop early |
| `_sim-icarus` | `make sim-icarus` | like `_sim-fast` but on Icarus (see `env/tool-versions.md` for the cocotb version caveat) |
| `_formal` | `make formal` | `fsm_props.log`, `handshake_props.log`, and the full SymbiYosys work folders (SMT2 models, engine logs, `PASS`/`FAIL` files) |
| `_synth-check` | `make synth-check` | `yosys.log` (whole run), `yosys_stat.log` (raw `stat`), `summary.md` (cell and flop counts plus the checklist, also copied to `docs/synthesis_summary.md`). No PDK needed; real Sky130 area comes from OpenLane. |

## Why not just overwrite one log

If every run overwrote a single `reports/lint.log`, you'd only ever see the
latest result. There'd be no way to tell when something last passed, or
whether a fix actually changed anything. With one committed folder per run,
the verification history is part of the git history, and anyone can browse
it with `git log -- reports/` without running a thing.

## Still git-ignored

`build/`, `pd/openlane/runs/` and `pdk/` are still scratch (big,
reproducible, or managed by Volare); see `macc8/.gitignore`. Running
`verif/formal/run_formal.sh` by hand instead of `make formal` writes to
`verif/formal/<task>/`, which is ignored too. That's for quick local checks,
not the record.

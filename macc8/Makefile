# MACC-8 top-level orchestration
DESIGN      := macc8
RTL         := rtl/macc8.f
export PDK        ?= sky130A
export PDK_ROOT   ?= $(CURDIR)/pdk

# Computed once per `make` invocation. Every target below that produces a
# report writes it to reports/<TS>_<target>/, which is committed to the repo
# (see reports/README.md) -- unlike build/, pd/openlane/runs/, pdk/, which
# stay git-ignored scratch space.
TS := $(shell date +%Y%m%d-%H%M%S)

.PHONY: all lint sim sim-fast sim-icarus formal synth-check synth gds drc lvs signoff vectors clean help

help:            ## list targets
	@grep -E '^[a-z].*:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/ -/'

lint:            ## Verible + Verilator lint (report: reports/<ts>_lint/)
	@mkdir -p reports/$(TS)_lint
	verible-verilog-lint --rules_config lint/.rules.verible_lint $$(cat $(RTL) | grep -vE '^#|^\+') > reports/$(TS)_lint/verible.log 2>&1; ec=$$?; cat reports/$(TS)_lint/verible.log; test $$ec -eq 0 || exit $$ec
	verilator --lint-only -Wall -f $(RTL) lint/verilator_lint.vlt > reports/$(TS)_lint/verilator.log 2>&1; ec=$$?; cat reports/$(TS)_lint/verilator.log; test $$ec -eq 0 || exit $$ec

sim:             ## cocotb + Verilator regression, full incl. real overflow crossing (report: reports/<ts>_sim-full/)
	@mkdir -p reports/$(TS)_sim-full
	$(MAKE) -C verif/cocotb SIM=verilator > reports/$(TS)_sim-full/sim.log 2>&1; ec=$$?; cat reports/$(TS)_sim-full/sim.log; cp verif/cocotb/results.xml reports/$(TS)_sim-full/results.xml 2>/dev/null || true; test $$ec -eq 0 || exit $$ec

sim-fast:        ## cocotb + Verilator regression, fast/capped overflow loop (report: reports/<ts>_sim-fast/)
	@mkdir -p reports/$(TS)_sim-fast
	$(MAKE) -C verif/cocotb SIM=verilator MACC8_FAST=1 > reports/$(TS)_sim-fast/sim.log 2>&1; ec=$$?; cat reports/$(TS)_sim-fast/sim.log; cp verif/cocotb/results.xml reports/$(TS)_sim-fast/results.xml 2>/dev/null || true; test $$ec -eq 0 || exit $$ec

sim-icarus:      ## cocotb + Icarus regression, fast mode (report: reports/<ts>_sim-icarus/)
	@mkdir -p reports/$(TS)_sim-icarus
	$(MAKE) -C verif/cocotb SIM=icarus MACC8_FAST=1 > reports/$(TS)_sim-icarus/sim.log 2>&1; ec=$$?; cat reports/$(TS)_sim-icarus/sim.log; cp verif/cocotb/results.xml reports/$(TS)_sim-icarus/results.xml 2>/dev/null || true; test $$ec -eq 0 || exit $$ec

formal:          ## SymbiYosys property checks (report: reports/<ts>_formal/)
	@mkdir -p reports/$(TS)_formal
	cd verif/formal && sby -f fsm_props.sby -d $(CURDIR)/reports/$(TS)_formal/fsm_props > $(CURDIR)/reports/$(TS)_formal/fsm_props.log 2>&1; ec=$$?; cat $(CURDIR)/reports/$(TS)_formal/fsm_props.log; test $$ec -eq 0 || exit $$ec
	cd verif/formal && sby -f handshake_props.sby -d $(CURDIR)/reports/$(TS)_formal/handshake_props > $(CURDIR)/reports/$(TS)_formal/handshake_props.log 2>&1; ec=$$?; cat $(CURDIR)/reports/$(TS)_formal/handshake_props.log; test $$ec -eq 0 || exit $$ec

synth-check:     ## Yosys generic synthesizability + area proxy, no PDK (report: reports/<ts>_synth-check/)
	@mkdir -p reports/$(TS)_synth-check
	MACC8_REPORT_DIR=$(CURDIR)/reports/$(TS)_synth-check yosys -c syn/yosys_area.tcl > reports/$(TS)_synth-check/yosys.log 2>&1; ec=$$?; \
	cat reports/$(TS)_synth-check/yosys.log; \
	if [ $$ec -eq 0 ]; then \
	  bash scripts/parse_yosys_stat.sh reports/$(TS)_synth-check/yosys.log reports/$(TS)_synth-check/yosys_stat.log reports/$(TS)_synth-check/summary.md; \
	  cp reports/$(TS)_synth-check/summary.md docs/synthesis_summary.md; \
	fi; \
	exit $$ec

pdk:             ## fetch Sky130 via Volare
	bash scripts/install_pdk.sh

synth:           ## OpenLane synth + STA (fast)
	bash scripts/run_synth.sh

gds:             ## full RTL-to-GDSII
	bash scripts/run_gds.sh

signoff:         ## Magic DRC + Netgen LVS
	bash scripts/run_signoff.sh

vectors:         ## regenerate golden vectors
	python scripts/gen_vectors.py

clean:
	rm -rf build sim_build obj_dir *.vcd *.fst pd/openlane/runs/*

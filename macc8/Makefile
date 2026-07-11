# MACC-8 top-level orchestration
DESIGN      := macc8
RTL         := rtl/macc8.f
export PDK        ?= sky130A
export PDK_ROOT   ?= $(CURDIR)/pdk

.PHONY: all lint sim formal synth gds drc lvs signoff vectors clean help

help:            ## list targets
	@grep -E '^[a-z].*:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/ -/'

lint:            ## Verible + Verilator lint
	verible-verilog-lint --rules_config lint/.rules.verible_lint $$(cat $(RTL) | grep -vE '^#|^\+')
	verilator --lint-only -Wall -f $(RTL) lint/verilator_lint.vlt

sim:             ## cocotb + Verilator regression
	$(MAKE) -C verif/cocotb SIM=verilator

formal:          ## SymbiYosys property checks
	sby -f verif/formal/fsm_props.sby
	sby -f verif/formal/handshake_props.sby

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
	rm -rf build sim_build obj_dir *.vcd *.fst pd/openlane/runs/* reports/*

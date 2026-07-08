# -----------------------------------------------------------------------------
# verif/cocotb/Makefile — cocotb regression for MACC-8
#
#   make            # run full suite on Verilator
#   make SIM=icarus # run on Icarus Verilog instead
#   make WAVES=1    # dump macc8.fst for GTKWave
#   make MACC8_FAST=1  # shrink the accumulate-to-overflow loops (quick iteration)
#   make clean
#
# RTL_DIR defaults to the workspace layout (verif/cocotb -> ../../rtl).
# -----------------------------------------------------------------------------
TOPLEVEL_LANG ?= verilog
SIM           ?= verilator
RTL_DIR       ?= ../../rtl
MODEL_DIR     ?= ../models

TOPLEVEL      := macc8_top
MODULE        := test_macc8

# compile order: package first, top last (mirrors rtl/macc8.f)
VERILOG_SOURCES := \
  $(RTL_DIR)/macc8_pkg.sv \
  $(RTL_DIR)/macc8_reset_sync.sv \
  $(RTL_DIR)/macc8_mac_lane.sv \
  $(RTL_DIR)/macc8_adder_tree.sv \
  $(RTL_DIR)/macc8_accumulator.sv \
  $(RTL_DIR)/macc8_datapath.sv \
  $(RTL_DIR)/macc8_serial_rx.sv \
  $(RTL_DIR)/macc8_fsm.sv \
  $(RTL_DIR)/macc8_regfile.sv \
  $(RTL_DIR)/macc8_top.sv

# make the golden model importable
export PYTHONPATH := $(shell cd $(MODEL_DIR) && pwd):$(PYTHONPATH)
export MACC8_FAST

# --- simulator-specific args -------------------------------------------------
ifeq ($(SIM),verilator)
  EXTRA_ARGS += -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL
  ifeq ($(WAVES),1)
    EXTRA_ARGS += --trace-fst --trace-structs
    VERILATOR_TRACE = 1
  endif
endif

ifeq ($(SIM),icarus)
  ifeq ($(WAVES),1)
    PLUSARGS += +WAVES=1
  endif
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

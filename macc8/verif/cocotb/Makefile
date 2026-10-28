# cocotb regression for MACC-8
#
#   make                  all tests on Verilator
#   make SIM=icarus       all tests on Icarus
#   make WAVES=1          also write macc8.fst
#   make MACC8_FAST=1     cut the overflow loops short
#   make clean
#
# RTL_DIR points at ../../rtl unless you override it.
TOPLEVEL_LANG ?= verilog
SIM           ?= verilator
RTL_DIR       ?= ../../rtl
MODEL_DIR     ?= ../models

TOPLEVEL      := macc8_top
MODULE        := test_macc8

# package first, top last, same order as rtl/macc8.f
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

# so the tests can import macc8_ref
export PYTHONPATH := $(shell cd $(MODEL_DIR) && pwd):$(PYTHONPATH)
export MACC8_FAST

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

SIM        ?= icarus
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES = $(PWD)/adder.v
TOPLEVEL        := adder
MODULE          := test_adder

VVP_LIB = $(shell uv run -- cocotb-config --lib-name vpi $(SIM))

.PHONY: sim clean

sim: sim_build/sim.vvp
	GPI_USERS="$$(uv run -- cocotb-config --libpython);$$(uv run -- cocotb-config --pygpi-entry-point)" \
	PYGPI_PYTHON_BIN=$$(uv run -- cocotb-config --python-bin) \
	COCOTB_TEST_MODULES=$(MODULE) \
	COCOTB_TOPLEVEL=$(TOPLEVEL) \
	TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
	COCOTB_RESULTS_FILE=$(CURDIR)/sim_build/results.xml \
	uv run -- vvp -m $(VVP_LIB) $<

sim_build/sim.vvp: adder.v | sim_build
	printf '+timescale+1ns/1ps\n' > $(@D)/cmds.f
	iverilog -o $@ -s $(TOPLEVEL) -g2012 -f $(@D)/cmds.f $<

sim_build:
	mkdir -p $@

clean:
	rm -rf sim_build
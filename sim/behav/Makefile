#--------------------------------------------------------------------
# Cadence‑only Makefile (Xcelium / SimVision / IMC)
#--------------------------------------------------------------------

#--------------------------------------------------------------------
# Add the following to the testbench
# initial begin
#     $shm_open("waves.shm");
#     $shm_probe("AC");
# end
#--------------------------------------------------------------------

# ===== User‑configurable variables =================================
INCLUDE_FILE_NAME ?= calculator.include

# ===== Paths =======================================================
CURRENT_DIR := $(shell pwd)
WORKSPACE   := $(CURRENT_DIR)/WORKSPACE
SCRIPT_DIR  := ../../scripts
PYTHON      := python3.12

# ===== Dynamic macro definitions ===================================
VERILOG_DEFINES := SIM=1+CADENCE=1
DEFINE_FLAGS := $(foreach def,$(VERILOG_DEFINES),+define+$(def))

# ===== Help Message ================================================
.PHONY: help
help:
	@echo "----------------------------------------------------------------"
	@echo "Administrative targets:"
	@echo "  help               - this message"
	@echo "  clean              - remove WORKSPACE directory"
	@echo
	@echo "Compilation targets:"
	@echo "  link               - generate WORKSPACE/sym_links/"
	@echo "  xrun               - compile & simulate using Cadence Xcelium"
	@echo "  simvision          - view waveform database"
	@echo "  run_and_view       - xrun + simvision"
	@echo "  coverage           - open coverage in IMC"
	@echo
	@echo "  verify_onboarding  - (DIGITAL DESIGN ONBOARDING ONLY) check your project for correctness"
	@echo "----------------------------------------------------------------"

# ===== Administrative Targets ======================================
.PHONY: clean link
clean:
	@rm -rf $(WORKSPACE)

link:
	@mkdir -p $(WORKSPACE)/sym_links
	@rm -rf $(WORKSPACE)/sym_links/*
	@python3.12 link_files.py $(INCLUDE_FILE_NAME)
#   @ln -s $(CURRENT_DIR)/../../src/python_model/*.txt WORKSPACE/sym_links/.

# ===== Simulation Targets ==========================================
# .PHONY: xrun simvision run_and_view coverage

vcs: ./Include/${INCLUDE_FILE_NAME}
	cd $(WORKSPACE) && vcs -file sym_links/sim_no_path.include +v2k -R +lint=all -sverilog -full64 -kdb +incdir+sym_links \
		-timescale=1ns/10ps -debug_acc+pp+dmptf -debug_region+cell+encrypt \
		-cm line+tgl+cond+branch+fsm+assert -debug_access+all -l simulation.log +vpdfile+./simulation.vpd +fsdb+./simulation.fsdb +dumpvars +define+$(VERILOG_DEFINES) +testname=$(TESTNAME)
		# simv 

verdi:
	cd $(WORKSPACE) && verdi -sv -simBin ./simv \
	      -dbdir ./simv.daidir \
    	  -ssf ./simulation.fsdb &

coverage: vcs
	cd $(WORKSPACE) && verdi -cov -covdir simv.vdb&

XRUN_FLAGS = -64bit -sv -linedebug -access +rwc \
             -timescale 1ns/10ps \
             $(DEFINE_FLAGS) \
             +testname=$(TESTNAME) \
             +incdir+sym_links \
             -coverage all \
             -licqueue \
             -covoverwrite

VERISIUM_FLAGS = $(XRUN_FLAGS) -gui -debug_opts verisium_interactive

xrun: link
	cd $(WORKSPACE) && \
	xrun $(XRUN_FLAGS) -f sym_links/sim_no_path.include \
	     -logfile simulation.log

verisium:
	cd $(WORKSPACE) && \
	xrun $(VERISIUM_FLAGS) -f sym_links/sim_no_path.include \
		-logfile simulation.log

simvision:
	cd $(WORKSPACE) && simvision waves.shm &

run_and_view: xrun verisium

# Need to change IMC path...
cadence_coverage:
	cd $(WORKSPACE) && /tools/software/cadence/vmanager/latest/tools.lnx86/vmgr/bin/imc -load cov_work/scope/test &

# ===== Default Target ==============================================
.DEFAULT_GOAL := run_and_view

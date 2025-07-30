RISCV_PREFIX ?= riscv64-unknown-elf-
RISCV_GCC      = $(RISCV_PREFIX)gcc
RISCV_OBJCOPY  = $(RISCV_PREFIX)objcopy

RTL_DIR = rtl
TB_DIR  = tb
SW_DIR  = $(TB_DIR)/sw

# All generated files will go into the 'build' directory
BUILD_DIR = build
SIM_EXE   = $(BUILD_DIR)/sim.out
ELF_FILE  = $(BUILD_DIR)/test.elf
HEX_FILE  = $(BUILD_DIR)/test.hex

VLOG_FILES = \
	$(TB_DIR)/tb_core.v \
	$(RTL_DIR)/core.v \
	$(RTL_DIR)/control/alu_control.v \
	$(RTL_DIR)/control/branch_control.v \
	$(RTL_DIR)/alu/alu_top.v \

RISCV_GCC_OPTS = -march=rv32i -mabi=ilp32 -nostdlib

.PHONY: all
all: run

# Build the software, compile the simulator, and run it
.PHONY: run
run: $(SIM_EXE)
	@echo "--- Running Simulation ---"
	@$(SIM_EXE)

$(SIM_EXE): $(VLOG_FILES) $(HEX_FILE)
	@echo "--- Compiling Verilog ---"
	@iverilog -o $@ $(VLOG_FILES)

$(HEX_FILE): $(SW_DIR)/test.s $(SW_DIR)/linker.ld
	@echo "--- Assembling Software ---"
	@mkdir -p $(BUILD_DIR)
	@$(RISCV_GCC) $(RISCV_GCC_OPTS) -T$(SW_DIR)/linker.ld $(SW_DIR)/test.s -o $(ELF_FILE)
	@$(RISCV_OBJCOPY) -O verilog $(ELF_FILE) $@

.PHONY: clean
clean:
	@echo "--- Cleaning Up ---"
	@rm -rf $(BUILD_DIR) a.out

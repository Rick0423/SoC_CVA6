VERILOG_SRC := $(wildcard ./*.sv)
#TESTBENCHES := $(wildcard ./sim/*.sv)
OUTPUT_DIR := ./outputs
OBJ_DIR := ./obj_dir
SIM_EXEC := $(OBJ_DIR)/V$(TOP)  # 生成的可执行文件

# 选择模拟器
SIMULATOR ?= verilator
TOP ?= tree_search_tb  # 默认顶层模块

# 创建输出目录
$(shell mkdir -p $(OUTPUT_DIR))

all: run

# 运行 Verilator，允许 PINMISSING
run_verilator: $(VERILOG_SRC) $(TESTBENCHES)
	@echo "Running simulation with Verilator for TOP=$(TOP)..."
	verilator --cc --exe --build --trace --binary --top-module $(TOP) $(VERILOG_SRC) $(TESTBENCHES) -Wno-UNOPTFLAT
	
	$(SIM_EXEC)

# 根据选定的模拟器运行
run:
	@if [ "$(SIMULATOR)" = "verilator" ]; then \
	    $(MAKE) run_verilator TOP=$(TOP); \
	else \
	    echo "Unknown simulator: $(SIMULATOR)"; exit 1; \
	fi

# 清理生成文件
clean:
	rm -rf $(OUTPUT_DIR)/* $(OBJ_DIR) verilator_*

.PHONY: all run run_verilator clean

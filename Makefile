# Makefile for Tiny TPU systolic array multiplier
# Requires Icarus Verilog (iverilog / vvp)

IVERILOG  = iverilog
VVP       = vvp
SRC_DIR   = src
TB_DIR    = tb

SRCS      = $(SRC_DIR)/pe.v \
            $(SRC_DIR)/systolic_array.v \
            $(SRC_DIR)/matrix_multiplier.v

.PHONY: all clean test test_pe test_systolic_array test_matrix_multiplier

all: test

# --- PE tests ---
test_pe: $(TB_DIR)/tb_pe.v $(SRC_DIR)/pe.v
	$(IVERILOG) -o tb_pe.vvp $(SRC_DIR)/pe.v $(TB_DIR)/tb_pe.v
	$(VVP) tb_pe.vvp

# --- Systolic array tests ---
test_systolic_array: $(TB_DIR)/tb_systolic_array.v $(SRC_DIR)/pe.v $(SRC_DIR)/systolic_array.v
	$(IVERILOG) -o tb_systolic_array.vvp $(SRC_DIR)/pe.v $(SRC_DIR)/systolic_array.v $(TB_DIR)/tb_systolic_array.v
	$(VVP) tb_systolic_array.vvp

# --- Top-level matrix multiplier tests ---
test_matrix_multiplier: $(TB_DIR)/tb_matrix_multiplier.v $(SRCS)
	$(IVERILOG) -o tb_matrix_multiplier.vvp $(SRCS) $(TB_DIR)/tb_matrix_multiplier.v
	$(VVP) tb_matrix_multiplier.vvp

# --- Run all tests ---
test: test_pe test_systolic_array test_matrix_multiplier

clean:
	rm -f *.vvp *.vcd

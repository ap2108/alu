OUT = sim
VCD = wave.vcd

all: compile run

compile:
	iverilog -o $(OUT) src/test_bench/alu_tb.v src/design/alu.v
run: 
	vvp $(OUT)

wave: 
	gtkwave $(VCD) &

clean:
	rm -f $(OUT) $(VCD)
# ALU Verification Project — README

## Project Overview

This project covers the complete RTL design and verification of an 8-bit ALU (`alu.v`) with 16-bit result output, supporting arithmetic, logical, shift/rotate, signed, and multiply operations. The verification environment went through several major iterations, evolving from a file-driven testbench with a Python stimulus generator, to a self-contained hardcoded testbench, to a final self-checking testbench driven by a binary stimulus file and an inline combinational reference model.

---

## Repository Contents

| File | Description |
|---|---|
| `alu.v` | Final RTL design under test |
| `verification_plan.csv` | Human-readable test plan with Description and Priority columns |
| `generate_stim.py` | Python script that reads the plan and generates `stimulus.txt` |
| `stimulus.txt` | 33-bit binary stimulus file (489 + 20 CE test cases = 509 vectors) |
| `stimulus.hex` | 32-bit hex stimulus file (pre-CE addition, 489 vectors) |
| `stimulus.bin` | Same as stimulus.hex converted to annotated binary with underscores |
| `test_bench_alu.v` | File-driven testbench (reads stimulus.txt, uses `$readmemb`) |
| `test_bench_alu_self_contained.v` | Self-contained testbench with all 489 stimuli hardcoded |
| `alu_tb.v` | Final self-checking testbench with inline `alu_ref` reference model |

---

## ALU Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | Clock |
| `rst` | input | 1 | Synchronous reset |
| `ce` | input | 1 | Clock enable — outputs hold when deasserted |
| `mode_in` | input | 1 | `0` = logical, `1` = arithmetic |
| `in_iv` | input | 2 | Input validity — wrong value for the operation raises `err` |
| `cmd_in` | input | 4 | Operation select (combined with `mode` as 5-bit opcode) |
| `in_a`, `in_b` | input | 8 | Operands |
| `in_cin` | input | 1 | Carry-in |
| `res` | output | 16 | Result (16-bit to accommodate MUL and signed ops) |
| `cout` | output | 1 | Carry-out |
| `e`, `g`, `l` | output | 1 each | Equal / Greater / Less flags |
| `oflow` | output | 1 | Overflow flag |
| `err` | output | 1 | Error flag |

---

## Operations

**Arithmetic (mode=1):** ADD, ADD+CIN, SUB, SUB+CIN, INC_A, DEC_A, INC_B, DEC_B, CMP, MUL1, MUL2, SIGNED_ADD, SIGNED_SUB.

**Logical (mode=0):** AND, NAND, OR, NOR, XOR, XNOR, NOT_A, NOT_B, SHR1_A, SHL1_A, SHR1_B, SHL1_B, ROL_A_B, ROR_A_B.

---

## RTL Design Notes

### Registered pipeline

All outputs are registered — `res`, `err`, `oflow`, `cout`, `g`, `e`, `l` are driven by `next_*` signals computed combinationally and registered on `posedge clk`. This gives **1-cycle latency** for all non-MUL operations. The combinational block uses registered `a`/`b` (not the raw inputs), so the pipeline is: inputs arrive → registered into `a`/`b` at posedge N → combinational block computes `next_res` using those registered values → `res` updates at posedge N+1.

### MUL two-cycle operation

MUL1 and MUL2 require two consecutive cycles with the same `{mode, cmd}`:

- **Cycle 1:** Inputs latched into `hold_a`/`hold_b`/`hold_iv`. `pending` flag set. Outputs unchanged (registered block skips update).
- **Cycle 2 (same MUL type):** Operand mux feeds held inputs into `a`/`b`. Combinational computes result. `pending` cleared. Result visible after this posedge = **2-cycle total latency from cycle-1 drive**.

**Interruption rules:** If a different MUL type arrives on cycle 2, cycle 1 is discarded and cycle 2 is treated as a fresh cycle 1. If the same MUL type arrives on cycle 2 with different inputs, cycle 2's inputs are silently ignored — the held cycle-1 inputs are always used.

### `next_res` default

The combinational block has `next_res = 0` as a default at the top. This was a critical fix — without it, `next_res` retained its previous value as a latch, causing stale results to appear on MUL cycle-1 outputs.

### `inp_valid` error handling

Every operation checks `inp_valid` (or the relevant bit for single-operand ops). On error, `err=1` and all other outputs are don't-care. When `err=1` the Python generator forces all output fields to `x` in the stimulus, so the scoreboard skips them automatically.

---

## Verification Plan (`verification_plan.csv`)

81 test groups covering CE assert/deassert, all arithmetic and logical operations with boundary conditions, MUL two-cycle sequences and error cases, signed ADD/SUB with overflow and EGL variants, shift/rotate edge cases, and `inp_valid` error injection for every operation group. Each row has: Feature ID, Test Name, Description, Priority, Constraint, No. of tests, and input/expected output expressions.

Priority assignment: P1 for correctness-critical paths (arithmetic, error handling, CE, MUL), P2 for logical and shift operations.

---

## Stimulus Packet Format

### 33-bit format (`stimulus.txt` — used by `alu_tb.v`)

```
[32:25]  FID       8b   — test group identifier (metadata only, not driven to DUT)
[24:17]  A         8b
[16:9]   B         8b
[8]      CIN       1b
[7]      MODE      1b
[6:3]    CMD       4b
[2:1]    INP_VALID 2b
[0]      CE        1b
```

509 vectors total (489 functional + 20 CE tests). The file uses `x` for don't-care bits, which `$readmemb` loads directly as Verilog `x` values.

### 32-bit format (`stimulus.hex` — legacy, pre-CE)

Same layout without the CE bit, 489 vectors. `stimulus.bin` is the same data in annotated binary with underscores separating each field.

---

## Testbench Evolution

### Phase 1 — File-driven TB (`test_bench_alu.v`)

Reads `stimulus.txt` via `$readmemb`. The `drive_and_check` task went through several iterations. The original version used `repeat(2) @(posedge CLK)` for all operations — correct in some cases but wrong for MUL which needs 3 posedges from its first cycle drive. Later replaced with a 3-slot shift register pipeline: non-MUL results checked at slot[1] (2 cycles old), MUL cycle-2 results checked at slot[2] (3 cycles old), MUL cycle-1 slots flagged skip.

### Phase 2 — Self-contained TB (`test_bench_alu_self_contained.v`)

All 489 stimuli hardcoded as individual `drive_and_check(...)` calls — no `stimulus.txt` needed at runtime. Generated by a Python script that parsed `stimulus.txt` and emitted one Verilog task call per line. This TB is useful for waveform debugging since every stimulus is visible directly in the source.

### Phase 3 — Reference model TB (`alu_tb.v`)

The final and most complete testbench.

**Inline reference model (`alu_ref`):** A combinational module that mirrors all ALU operations. The default line at the top of `always @(*)` sets all outputs to `x`, so any output not explicitly assigned by the active case remains `x` — automatically implementing don't-care semantics without needing a separate expected-value table.

**CE behaviour:** The reference model uses `always @(*) if(ce)`. When `ce=0` the block doesn't execute and outputs retain their previous `reg` values (inferred latch), matching the DUT's registered freeze behaviour exactly.

**Direct stimulus indexing:** The task receives integer index `tc` and reads `stim_mem[tc-1]` directly (and `stim_mem[tc-2]` for MUL), eliminating the separate pipeline shift registers. The `is_first` flag skips the check on call 0 since `tc-1` would be invalid.

**Scoreboard:** X-aware per-bit comparison — iterates all 22 bits of the bundle `{res, err, oflow, cout, g, e, l}`, skipping any bit where `ref_bnd[i] === 1'bx`. This handles both explicit don't-cares (from the `x` default in `alu_ref`) and `inp_valid` error cases where the reference model leaves outputs undefined.

---

## Bugs Found and Fixed During Development

| # | Location | Bug | Fix |
|---|---|---|---|
| 1 | `alu.v` | `next_res` had no default — inferred latch caused stale MUL results on cycle-1 | Added `next_res = 0` default in combinational block |
| 2 | `alu.v` | `flag1`/`flag2` toggle approach raced against combinational block — MUL result on wrong cycle | Replaced with explicit `pending`/`hold_*` pipeline registers |
| 3 | `alu.v` | MUL result appeared too late due to NBA timing of flag and `a`/`b` updates | Redesigned registered block to skip output update on MUL cycle-1 |
| 4 | `test_bench_alu.v` | `repeat(2) @(posedge CLK)` wrong for both non-MUL (1 extra) and MUL (not enough) | Per-operation latency tracking with 3-slot shift register |
| 5 | `alu_tb.v` | `input tc` with no width — defaults to 1 bit, truncating loop index 0–508 | Changed to `input integer tc` |
| 6 | `alu_tb.v` | Full 33-bit word unpacked into DUT inputs including FID byte | Unpack only `[24:0]`, extract FID separately as `stim_mem[tc][32:25]` |
| 7 | `alu_tb.v` | Wrong field order in ref model unpack (`mode_ref` received `a` value, etc.) | Reordered to match packet layout: `fid, a, b, cin, mode, cmd, iv, ce` |
| 8 | `alu_tb.v` | `ce_ref` missing from unpack — ref model always saw CE=1 while DUT froze on CE=0, causing permanent 1-cycle offset | Added `ce_ref` to both MUL and non-MUL unpack assignments |
| 9 | `generate_stim.py` | CSV function calls with commas (`signed_add_16(a,b)`) split by CSV parser | Added comma-free alias functions (`sadd16()`, `ssub16()`) bound to local `a`/`b` via closure |
| 10 | `generate_stim.py` | `z` written for don't-care bits — `$readmemb` requires `x` | Changed all don't-care output fields to write `x` |

---

## Running the Simulation

**Final testbench (recommended):**
```bash
iverilog -g2012 -o sim alu.v alu_tb.v
vvp sim
```
Requires `stimulus.txt` in the working directory.

**Self-contained testbench (no external files):**
```bash
iverilog -g2012 -o sim alu.v test_bench_alu_self_contained.v
vvp sim
```

**Regenerating stimulus from the verification plan:**
```bash
python3 generate_stim.py   # reads verification_plan.csv, writes stimulus.txt
```
# ALU Design and Verification Project

## Overview

This project contains the RTL design and complete verification environment for an 8-bit ALU (`alu.v`). The verification flow produces a self-contained Verilog testbench that requires no external files at simulation time. (493 Test Vectors.)

---

## ALU Interface

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | Clock |
| `rst` | input | 1 | Synchronous reset |
| `ce` | input | 1 | Clock enable- outputs hold when deasserted |
| `mode` | input | 1 | `0` = logical operations, `1` = arithmetic operations |
| `inp_valid` | input | 2 | Input validity indicator- required operands being invalid raises `err` |
| `cmd` | input | 4 | Operation select (combined with `mode` for full opcode) |
| `ina`, `inb` | input | 8 | Operands A and B |
| `cin` | input | 1 | Carry-in (used by ADD with carry, SUB with borrow) |
| `res` | output | 16 | Result- 16-bit to accommodate MUL and signed operations |
| `cout` | output | 1 | Carry-out |
| `e`, `g`, `l` | output | 1 each | Equal / Greater / Less comparison flags |
| `oflow` | output | 1 | Overflow flag |
| `err` | output | 1 | Error flag- asserted on invalid `inp_valid` or out-of-range shift |

---

## Stimulus Packet Format

Each test vector is a 57-bit binary string:

```
[56:49]  Feature_ID   8b 
[48:47]  Reserved     2b
[46:39]  OPA          8b
[38:31]  OPB          8b
[30:27]  CMD          4b
[26]     CIN          1b
[25]     CE           1b
[24]     MODE         1b
[23:22]  INP_VALID    2b
[21:6]   Exp_RES     16b 
[5]      exp_cout     1b
[4]      exp_e        1b
[3]      exp_g        1b
[2]      exp_l        1b
[1]      exp_oflow    1b
[0]      exp_err      1b
```

`x` characters are written literally into the file and loaded as Verilog `x` values by `$readmemb`. When `err` is expected to be `1`, all other output fields are treated as don't care terms.

---

## Verification Plan 

[Open Google Sheets Link](https://docs.google.com/spreadsheets/d/1YelYtx9FtWXE92oQWSma7PSBhO9VThlmOj5hM4fDBs8/edit?usp=sharing)
---

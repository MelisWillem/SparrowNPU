Phase 1 — Single PE
Goal: working multiply-accumulate unit

Verilog module:
- `hardware/multiplier/multiplier.srcs/sources_1/new/mul.v`
- `hardware/multiplier/multiplier.srcs/sources_1/new/mul_acc.v`
- Input registers: A, B (int8)
- Multiplier: int8 × int8 → int16
- Accumulator: int16 (signed)
- Clock, reset, enable signals

Testbench:
- `hardware/multiplier/multiplier.srcs/sources_1/new/tb_mul.v`
- `hardware/multiplier/multiplier.srcs/sources_1/new/tb_mul_acc.v`
- Feed known test vectors
- Verify against Python reference
- Check overflow/underflow handling

Success: testbech is ok

Phase 2 — 2×2 Systolic Array Goal: validate systolic dataflow
- Wire 4 PEs in 2×2 grid
- A matrix flows right (row-wise)
- B matrix flows down (column-wise)
- Each PE accumulates over K cycles

     B0  B1
A0  PE00 PE01
A1  PE10 PE11

Validation:
- Test matrix multiply (e.g., 2×K × K×2)
- Verify pipelined accumulation
- Check data propagation timing

Defer: BRAM

AXI-Stream variant: `systolic_2x2_axis.v` — 2×2 systolic with AXI-Stream for DMA (see `hardware/multiplier/docs/AXI_STREAM_SYSTOLIC.md`).

Success: correct output → core works.

Phase 3 — Tile Interface Contract

Goal: define hardware-software interface

Specify:
- Tile dimensions (e.g., 4×4, 8×8)
- Cycles per tile computation
- Input format (packed/unpacked, endianness)
- Output format (accumulator width, scaling)
- Control signals (start, done, stall)

see: kernels.md
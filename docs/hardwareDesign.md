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

Success: correct output → core works.

Phase 3 — DMA, feeder, and tile contract

Goal: end-to-end path from PS memory to the systolic tile and back.

Architecture (see `hardware/multiplier/docs/AXI_STREAM_SYSTOLIC.md`):

1. **DMA** — AXI DMA moves A, B, and C between DRAM and PL streams (bursts, TLAST).
2. **systolic_feeder** — Internal memory caches a tile’s **pre-packed** inputs; load FSM fills cache from streams; feed FSM replays **one beat per cycle** into the array (decouples burst DMA from systolic timing). Software supplies wavefront order in DRAM.
3. **systolic array** (`systolic_2x2`) — Fixed datapath; no DMA awareness.

RTL: `systolic_feeder.v` (BRAM + load/feed/drain + `systolic_2x2`); `systolic_2x2_axis.v` is the thin AXI wrapper around the feeder.

Specify for the overlay:

- Tile dimensions (e.g., 2×K × K×2)
- Cache depth / double-buffering
- Input format in DRAM (**v1:** pre-packed wavefront beats per `AXI_STREAM_SYSTOLIC.md`)
- Output format (accumulator width, packing)
- Control: start tile, done, errors

see: kernels.md
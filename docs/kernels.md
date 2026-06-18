# kernels

## matmul_2x2_systolic_tile (PL + host packing)

- **Hardware:** `systolic_2x2_axis` — dual MM2S (A, B), S2MM (C). See `hardware/multiplier/docs/AXI_STREAM_SYSTOLIC.md`.
- **v1 software:** Host packs **wavefront** beats; see `kernel_ref.py` — `pack_wavefront_2x2_u8`, `unpack_axis_c_u64`, `run_pynq_systolic_2x2`. Self-test: `uv run python docs/kernel_ref.py`.
- **Golden:** `golden_matmul_2x2_u8` (uint8 × uint8, uint16 result).

## matmul_4x4_int8
- name: matmul_4x4_int8
- inputs: A[4x4] int8, B[4x4] int8
- input format: packed, little-endian
- output: C[4x4] int32 (accumulator width)
- output format: int32 accumulator, no scaling
- latency: fixed 4 + 1 = 5 cycles
- control signals: start, done

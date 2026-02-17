# kernels

## matmul_4x4_int8
- name: matmul_4x4_int8
- inputs: A[4x4] int8, B[4x4] int8
- input format: packed, little-endian
- output: C[4x4] int32 (accumulator width)
- output format: int32 accumulator, no scaling
- latency: fixed 4 + 1 = 5 cycles
- control signals: start, done

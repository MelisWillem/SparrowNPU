# AXI-Stream Systolic Array

The `systolic_2x2_axis` module wraps the 2×2 systolic array with AXI-Stream interfaces for DMA integration.

## Block Diagram

```
                    ┌─────────────────────────────────────────┐
 S_AXIS_A (MM2S) ───▶│                                         │
                    │         systolic_2x2_axis                │───▶ M_AXIS_C (S2MM)
 S_AXIS_B (MM2S) ───▶│   ┌─────────────────┐                  │
                    │   │  systolic_2x2    │                  │
                    │   │  (2×2 PEs)        │                  │
                    │   └─────────────────┘                  │
                    └─────────────────────────────────────────┘
```

## Interface

### Input Streams (Slave, from DMA MM2S)

| Signal | Width | Description |
|--------|-------|-------------|
| S_AXIS_A_TDATA | 32 | A matrix column k: `{A[1][k], A[0][k]}` |
| S_AXIS_A_TVALID | 1 | Valid data present |
| S_AXIS_A_TREADY | 1 | Sink ready (output) |
| S_AXIS_A_TLAST | 1 | Last beat of tile |

| Signal | Width | Description |
|--------|-------|-------------|
| S_AXIS_B_TDATA | 32 | B matrix row k: `{B[k][1], B[k][0]}` |
| S_AXIS_B_TVALID | 1 | Valid data present |
| S_AXIS_B_TREADY | 1 | Sink ready (output) |
| S_AXIS_B_TLAST | 1 | Last beat of tile |

**Both streams must be synchronized**—one beat of A and one beat of B are consumed together. TLAST on both streams marks the last beat of a tile.

### Output Stream (Master, to DMA S2MM)

| Signal | Width | Description |
|--------|-------|-------------|
| M_AXIS_C_TDATA | 64 | `{P11, P10, P01, P00}` (16-bit each) |
| M_AXIS_C_TVALID | 1 | Valid result |
| M_AXIS_C_TREADY | 1 | Downstream ready (input) |
| M_AXIS_C_TLAST | 1 | Always 1 (one beat per tile) |

## Data Layout

Data follows the **systolic wavefront order**, not simple row/column-major.

For a 2×K × K×2 matrix multiply (C = A × B):

- **A** is 2×K: 2 rows, K columns
- **B** is K×2: K rows, 2 columns  
- **C** is 2×2: C[i][j] = Σ_k A[i][k] × B[k][j]

Each beat supplies: `TDATA[7:0] = A_in_0 / B_in_0`, `TDATA[15:8] = A_in_1 / B_in_1`

### Stream Order (wavefront diagonals)

| Beat | A_in_0 (row 0) | A_in_1 (row 1) | B_in_0 (col 0) | B_in_1 (col 1) |
|------|----------------|----------------|----------------|----------------|
| 0 | A[0][0] | 0 | B[0][0] | 0 |
| 1 | A[0][1] | A[1][0] | B[1][0] | B[0][1] |
| 2 | 0 | A[1][1] | 0 | B[1][1] |
| ... | ... | ... | ... | ... |
| K | 0 | A[1][K-1] | 0 | B[K-1][1] |

For 2×2: 3 beats (k=0,1,2). TLAST on last beat.

### Example: 2×2 × 2×2

A = [1 2]  B = [5 6]  C = [19 22]
    [3 4]      [7 8]      [43 50]

| Beat | S_AXIS_A_TDATA | S_AXIS_B_TDATA |
|------|----------------|----------------|
| 0 | 0x0001 (A_in_0=1, A_in_1=0) | 0x0005 (B_in_0=5, B_in_1=0) |
| 1 | 0x0302 (A_in_0=2, A_in_1=3) | 0x0807 (B_in_0=7, B_in_1=6) |
| 2 | 0x0400 (A_in_0=0, A_in_1=4) | 0x0800 (B_in_0=0, B_in_1=8) |

TLAST = 1 on beat 2.

Output: `M_AXIS_C_TDATA = {P11=50, P10=43, P01=22, P00=19}`

## DMA Setup (Xilinx)

1. **AXI DMA** with:
   - 2× MM2S channels (for A and B)
   - 1× S2MM channel (for C)
2. Source buffers: A and B in memory, packed as above
3. Destination buffer: 8 bytes for C result
4. Start both MM2S transfers in parallel; S2MM captures one 64-bit beat

## Timing

- **K+1 beats** of input for 2×K × K×2 (wavefront includes padding beats)
- **2 drain cycles** internal (no input consumed)
- **1 beat** of output
- Backpressure: if downstream does not accept output, inputs are stalled (TREADY low)

# AXI-Stream Systolic Tile (PYNQ-Z2)

This document describes how **DMA**, **systolic_feeder**, and the **systolic array** fit together for a 2×2 systolic tile with AXI-Stream to/from PS memory.

## System architecture

The systolic core expects **one wavefront beat per clock** when it is computing. The DMA can burst faster than that. **Version 1 (current RTL):** software fills DRAM with **already-packed** wavefront beats (see tables below); the DMA only moves bytes—the CPU does not send plain row-major matrices and expect the FPGA to reshuffle them. A **systolic_feeder** sits between the DMA and the array to:

1. **Absorb** incoming AXI-Stream beats (burst-safe).
2. **Cache** a full tile’s inputs in internal memory (BRAM/URAM or equivalent).
3. **Replay** data to the systolic array at **exactly one beat per cycle** in the **wavefront order** the PEs expect.

```
┌─────────────┐     AXI-Stream      ┌──────────────────────┐     one beat/cycle      ┌─────────────────┐
│  PS DRAM    │◄──────────────────►│                      │────────────────────────►│                 │
│  (buffers)  │   MM2S (A, B)       │  systolic_feeder     │   A_in_0/1, B_in_0/1    │  systolic_2x2   │
│             │                     │  • input cache (mem) │                         │  (2×2 PEs)      │
│             │◄───────────────────│  • load FSM (DMA)    │                         │                 │
│             │   S2MM (C)          │  • feed FSM (array)  │◄────────────────────────│                 │
└─────────────┘                     └──────────────────────┘                         └─────────────────┘
       ▲                                       ▲                                            │
       │                                       │                                            │
       └──────────────── AXI DMA ──────────────┴────────────────────────────────────────────┘
                              (PL: Xilinx AXI DMA IP)
```

**Roles**

| Block | Role |
|-------|------|
| **DMA** | Moves bytes between PS DRAM and PL AXI-Stream endpoints (MM2S for inputs, S2MM for result). Bursts, TLAST, and width are defined by the DMA IP and buffer lengths—not by the systolic timing. |
| **systolic_feeder** | Internal memory + control: **(load)** write cache from one or more AXI-Stream slave ports; **(feed)** drive `A_in_0`, `A_in_1`, `B_in_0`, `B_in_1`, `enable_mac`, and resets so the array sees the correct wavefront, independent of how fast the DMA filled the cache. |
| **systolic array** (`systolic_2x2`) | Pure datapath: A flows right, B flows down, four `mulc_acc` PEs. No knowledge of DMA or burst behavior. |

The RTL top **`systolic_2x2_axis`** instantiates **`systolic_feeder`**, which owns the AXI slaves, internal BRAM cache, load/feed/drain FSM, **`systolic_2x2`**, and the **M_AXIS_C** master.

---

## systolic_feeder (design contract)

### Responsibilities

- **Input cache:** Stores **one tile’s packed beats** (one 16-bit word per stream per beat, up to `K_MAX` beats per stream). Enough BRAM for the largest tile you parameterize.
- **Load path:** AXI-Stream slave(s) from DMA. Assert `TREADY` when there is space in the cache; accept bursts; honor `TLAST` to mark end of a logical input packet (tile or sub-tile, per software contract).
- **Feed path:** State machine that, after a tile is loaded (or while double-buffering), steps through addresses in internal memory and presents one `{A_in_0, A_in_1, B_in_0, B_in_1}` per cycle to the systolic array with `enable_mac` aligned to the wavefront table below.
- **Output path (optional in feeder vs top):** After the array has finished a tile (including drain cycles for pipeline), capture `{P00, P01, P10, P11}` and drive the S2MM AXI-Stream master with the packed C beat(s).

### Why it is required

- **Rate:** DMA can deliver many beats in a burst; the array consumes **at most one** useful beat per cycle when `enable_mac` is asserted for that phase.
- **Order (v1):** Wavefront order is defined by **software** when it builds the DMA buffers. The feeder replays cached beats in order; it does **not** convert row-major matrices into wavefronts.
- **Backpressure:** While the array is draining or computing, the feeder can deassert `TREADY` on the input streams without stalling the array’s internal timing—once the tile is in memory, feeding is **locally timed**.

---

## AXI-Stream at the DMA boundary

### Input streams (MM2S → PL)

These attach to the **feeder’s load side** (not directly to the array in the target design).

| Stream | Typical `TDATA` | Meaning per beat |
|--------|-----------------|------------------|
| **S_AXIS_A** | 32-bit | A column k: `{A[1][k], A[0][k]}` in `[15:8],[7:0]` |
| **S_AXIS_B** | 32-bit | B row k: `{B[k][1], B[k][0]}` in `[15:8],[7:0]` |

**Synchronization:** One beat of A and one beat of B per index k must belong to the same tile; both streams should carry **TLAST** on the same final beat of the tile (or the feeder defines a stricter rule and documents it).

### Output stream (PL → S2MM)

| Stream | Typical `TDATA` | Meaning |
|--------|-----------------|---------|
| **M_AXIS_C** | 64-bit | `{P11, P10, P01, P00}` (16-bit each) |
| **TLAST** | 1 | Assert on the final beat of the result packet (often one beat per tile). |

Exact packing and endianness should match the PYNQ buffer layout (see Python example in an overlay README when available).

---

## Data layout: wavefront order (what the array sees)

For C = A × B with A **2×K**, B **K×2**, the **feeder** must emit beats so that at cycle t the PEs see the same pattern as in simulation. Example for 2×2 × 2×2 (K=2; padding beats as in reference testbench):

| Beat | A_in_0 (row 0) | A_in_1 (row 1) | B_in_0 (col 0) | B_in_1 (col 1) |
|------|----------------|----------------|----------------|----------------|
| 0 | A[0][0] | 0 | B[0][0] | 0 |
| 1 | A[0][1] | A[1][0] | B[1][0] | B[0][1] |
| 2 | 0 | A[1][1] | 0 | B[1][1] |
| … | … | … | … | … |

The feeder either stores wavefront beats directly from software or **generates** this sequence from row-major A and B in its cache.

### Example: 2×2 × 2×2

A = [1 2; 3 4], B = [5 6; 7 8] → C = [19 22; 43 50].

| Beat | S_AXIS_A_TDATA | S_AXIS_B_TDATA |
|------|----------------|----------------|
| 0 | 0x0001 | 0x0005 |
| 1 | 0x0302 | 0x0607 |
| 2 | 0x0400 | 0x0800 |

TLAST = 1 on beat 2. After drain, **M_AXIS_C** = `{50, 43, 22, 19}` (with field widths as in your RTL).

---

## DMA setup (Xilinx)

1. **AXI DMA:** 2× MM2S (A, B), 1× S2MM (C); connect MM2S to feeder’s **load** ports, S2MM to feeder/array **result** port.
2. **Buffers:** A and B in DRAM in the format the **feeder load** expects (raw matrices or pre-packed beats—document per overlay).
3. **Software:** Start MM2S transfers; when feeder signals tile done (or DMA S2MM completes), read C.

---

## Timing summary

| Stage | Behavior |
|-------|----------|
| DMA → feeder | Bursty; limited by `TREADY` and cache space. |
| Feeder → array | One wavefront beat per cycle during compute/drain phases. |
| Array → DRAM | One or more C beats after tile completion; depends on output FSM. |

Internal **drain** cycles (zeros into the array while MACs finish) are owned by the feeder (or a thin wrapper), not by the DMA.

---

## File pointers

- Systolic core: `hardware/multiplier/multiplier.srcs/sources_1/new/systolic_2x2.v`
- Feeder (BRAM + FSM + array instance): `hardware/multiplier/multiplier.srcs/sources_1/new/systolic_feeder.v`
- AXI top (wraps feeder): `hardware/multiplier/multiplier.srcs/sources_1/new/systolic_2x2_axis.v`

Parameter **`K_MAX`** (default 64): maximum number of packed input beats per tile; increase in `systolic_2x2_axis` if tiles grow.

# Reference for host-side packing and golden checks (systolic 2×2 tile).
# Hardware: systolic_2x2_axis / systolic_feeder — see hardware/multiplier/docs/AXI_STREAM_SYSTOLIC.md
#
# Run checks:  uv run python docs/kernel_ref.py
# (Uses project env from pyproject.toml / uv.lock — not system Python.)
from __future__ import annotations

import numpy as np


def matmul(A: np.ndarray, B: np.ndarray):
    """Generic int reference (widened accumulators)."""
    A_acc = A.astype(np.int32)
    B_acc = B.astype(np.int32)
    return A_acc @ B_acc


def pack_wavefront_2x2_u8(A: np.ndarray, B: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """
    Build DMA buffers for a 2×2 × 2×2 tile (unsigned 8-bit), wavefront order.

    Each stream is 3 × uint32 beats; TLAST on the last beat (software / DMA length).

    A, B: shape (2, 2), dtype uint8 (or castable).
    Returns:
        a_beats, b_beats: shape (3,), dtype uint32 — lower 16 bits used per RTL.
    """
    A = A.astype(np.uint8, copy=False)
    B = B.astype(np.uint8, copy=False)

    def pack16(lo: int, hi: int) -> np.uint32:
        return np.uint32((np.uint16(hi) << 8) | np.uint16(lo))

    a0 = [
        pack16(A[0, 0], 0),
        pack16(A[0, 1], A[1, 0]),
        pack16(0, A[1, 1]),
    ]
    b0 = [
        pack16(B[0, 0], 0),
        pack16(B[1, 0], B[0, 1]),
        pack16(0, B[1, 1]),
    ]
    return np.array(a0, dtype=np.uint32), np.array(b0, dtype=np.uint32)


def unpack_axis_c_u64(word: int | np.uint64) -> np.ndarray:
    """
    Decode one M_AXIS_C beat: {P11, P10, P01, P00} as in RTL (little-endian 16-bit lanes).
    Returns C as (2, 2) uint16.
    """
    w = int(np.uint64(word))
    p00 = np.uint16(w & 0xFFFF)
    p01 = np.uint16((w >> 16) & 0xFFFF)
    p10 = np.uint16((w >> 32) & 0xFFFF)
    p11 = np.uint16((w >> 48) & 0xFFFF)
    return np.array([[p00, p01], [p10, p11]], dtype=np.uint16)


def golden_matmul_2x2_u8(A: np.ndarray, B: np.ndarray) -> np.ndarray:
    """Unsigned 8×8 → sum in uint32; result fits uint16 for typical test sizes."""
    A = A.astype(np.uint32, copy=False)
    B = B.astype(np.uint32, copy=False)
    return (A @ B).astype(np.uint16)


def run_pynq_systolic_2x2(
    dma_send_a,
    dma_send_b,
    dma_recv_c,
    A: np.ndarray,
    B: np.ndarray,
    *,
    wait: bool = True,
) -> np.ndarray:
    """
    Run one 2×2 tile on PL (pre-packed wavefront). Wire your overlay's DMA objects.

    Parameters
    ----------
    dma_send_a, dma_send_b : pynq.lib.dma.DMA
        MM2S channels for S_AXIS_A and S_AXIS_B (same length, TLAST on last beat).
    dma_recv_c : pynq.lib.dma.DMA
        S2MM for one 64-bit beat of C.
    A, B : (2, 2) uint8 arrays.

    Returns
    -------
    C : (2, 2) uint16
    """
    from pynq import allocate

    a_beats, b_beats = pack_wavefront_2x2_u8(A, B)
    buf_a = allocate(shape=a_beats.shape, dtype=np.uint32)
    buf_b = allocate(shape=b_beats.shape, dtype=np.uint32)
    buf_c = allocate(shape=(1,), dtype=np.uint64)
    np.copyto(buf_a, a_beats)
    np.copyto(buf_b, b_beats)

    dma_send_a.transfer(buf_a)
    dma_send_b.transfer(buf_b)
    dma_recv_c.transfer(buf_c)
    if wait:
        dma_send_a.wait()
        dma_send_b.wait()
        dma_recv_c.wait()

    return unpack_axis_c_u64(buf_c[0])


if __name__ == "__main__":
    # Self-test (no PYNQ): matches tb_systolic_2x2_axis golden
    A = np.array([[1, 2], [3, 4]], dtype=np.uint8)
    B = np.array([[5, 6], [7, 8]], dtype=np.uint8)
    a_beats, b_beats = pack_wavefront_2x2_u8(A, B)
    assert np.array_equal(a_beats, np.array([0x0001, 0x0302, 0x0400], dtype=np.uint32))
    assert np.array_equal(b_beats, np.array([0x0005, 0x0607, 0x0800], dtype=np.uint32))
    C = golden_matmul_2x2_u8(A, B)
    assert np.array_equal(C, np.array([[19, 22], [43, 50]], dtype=np.uint16))
    w = np.uint64(50) << 48 | np.uint64(43) << 32 | np.uint64(22) << 16 | np.uint64(19)
    assert np.array_equal(unpack_axis_c_u64(w), C)
    print("kernel_ref.py self-test OK")

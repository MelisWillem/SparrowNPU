# reference implementation of the kernel
import numpy as np

def matmul(A: np.ndarray, B: np.ndarray):
    # cast to accumulator type first
    A_acc = A.astype(np.int32)
    B_acc = B.astype(np.int32)
    return A_acc @ B_acc

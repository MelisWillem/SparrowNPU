# Plan

Overview

Small end-to-end proof-of-concept: train a tiny transformer, quantize and export tile-friendly int8 weights, implement a small systolic accelerator + DMA, and run inference on an ARM+FPGA platform.

Goals

- Correct int8 inference on accelerator + minimal runtime.
- Small, reproducible artifacts: train code, quantizer/exporter, compiler, RTL or simulator, runtime, and docs.

## Model & quantization
- Tiny transformer (2 layers, d_model=64, heads=2, MLP=128, vocab=256).
- optoinal: improve the behavior of the transformer by training it on a small corpus.

## Hardware & Compiler co-design
- **Hardware spec:** Choose systolic array size (8×8 recommended), double-buffered BRAM, AXI DMA, control interface. Define tile shapes, memory bandwidth, and latency assumptions.
- **Compiler IR:** Design a small IR that expresses tiled GEMM, 1×1 conv, and data movement. Tile shapes and memory hierarchy constraints come from hardware spec.
- **Codegen:** Lower transformer linear ops to IR primitives, emit weight tile layout, produce a lightweight host schedule (DMA ops + compute sequence).

## Runtime
- Minimal Python runtime that executes the compiler-produced schedule:
	- Issue DMA transfers, kick accelerator, wait for completion, do CPU-side softmax/layernorm/residuals.
	- Keep logic minimal: the compiler emits the schedule and ordering — runtime does not make heavy decisions.

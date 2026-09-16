import cocotb
from cocotb.triggers import FallingEdge
from cocotb.clock import Clock


@cocotb.test()
async def test_adder_all_values(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    WIDTH = 8

    for i in range(2**WIDTH):
        for j in range(2**WIDTH):
            for k in range(2):
                dut.a.value = i
                dut.b.value = j
                dut.cin.value = k
                # compute happens on rising edge
                await FallingEdge(dut.clk)
                expected = i + j + k
                assert (dut.cout.value, dut.sum.value) == (
                    expected >> WIDTH,
                    expected & ((1 << WIDTH) - 1),
                ), f"FAIL: a={i} b={j} cin={k} -> got sum={dut.sum.value} cout={dut.cout.value}, expected sum={expected & ((1 << WIDTH) - 1)} cout={expected >> WIDTH}"
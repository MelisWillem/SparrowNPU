import argparse
from pathlib import Path

from cocotb_tools.runner import get_runner

HERE = Path(__file__).parent


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--top", default="adder", help="HDL toplevel module (default: adder)")
    parser.add_argument("--waves", action="store_true", help="record .fst waveform traces")
    parser.add_argument("--clean", action="store_true", help="delete sim_build and rebuild from scratch")
    args = parser.parse_args()

    runner = get_runner("icarus")
    runner.build(
        sources=[HERE / f"{args.top}.v"],
        hdl_toplevel=args.top,
        timescale=("1ns", "1ps"),
        waves=args.waves,
        clean=args.clean,
    )
    runner.test(
        hdl_toplevel=args.top,
        test_module=f"test_{args.top}",
        waves=args.waves,
    )


if __name__ == "__main__":
    main()
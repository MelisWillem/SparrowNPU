# Simple experiment to do some verilog with opensource tools

A toy 8-bit pipelined adder (`adder.v` — registered sum+carry-out, registered on
`posedge clk`) verified with [cocotb](https://docs.cocotb.org/) and
[iverilog](https://iverilog.icarus.com/).

## Run the test

```sh
make sim
```

Exhaustively checks all 2^8 x 2^8 x 2 (a, b, cin) combinations against the
expected sum and carry-out. Clean up with `make clean`.

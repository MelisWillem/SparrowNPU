`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/14/2025 09:43:55 PM
// Design Name: 
// Module Name: mul_acc
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mulc_acc (
    input wire clk,
    input wire reset,
    input wire enable_mac,
    input wire [7:0] A, // 8-bit operand (unsigned interpretation)
    input wire [7:0] B, // 8-bit operand (unsigned interpretation)
    output wire [15:0] P_out // 16-bit accumulated product
);

// The operands are treated as unsigned
reg [7:0] op_A_reg;
reg [7:0] op_B_reg;
reg [15:0] product_reg;
reg [15:0] accumulator_reg;

// 1. Input Register Stage (Optional, for better clocking/pipelining)
always @(posedge clk) begin
    if (reset) begin
        op_A_reg <= 8'h0;
        op_B_reg <= 8'h0;
    end else begin
        op_A_reg <= A;
        op_B_reg <= B;
    end
end

// 2. Multiplication Stage (Infers the multiplier part of DSP48E1)
// The synthesizer is highly optimized to map A * B to the dedicated multiplier
(* USE_DSP48 = "yes" *)
always @(*) begin
    product_reg = op_A_reg * op_B_reg;
end

// 3. Accumulation Stage (Infers the adder/accumulator part of DSP48E1)
always @(posedge clk) begin
    if (reset) begin
        accumulator_reg <= 16'h0;
    end
    else if (enable_mac) begin
        accumulator_reg <= accumulator_reg + product_reg;
    end
    else begin
        accumulator_reg <= accumulator_reg;
    end
end

// Output
assign P_out = accumulator_reg;

endmodule


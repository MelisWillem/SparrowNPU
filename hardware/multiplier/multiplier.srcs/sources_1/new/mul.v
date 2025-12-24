`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/14/2025 09:43:55 PM
// Design Name: 
// Module Name: mul
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


// Synchronous (clocked) signed multiplier module
// Performs multiplication of two 8-bit signed inputs and outputs a 32-bit signed result
module mul (
    input  wire        clk,      // Clock signal
    input  wire        reset,    // Reset signal (active high)
    input  wire        enable,   // Enable signal to control when multiplication happens
    input  wire signed [7:0] a,  // First 8-bit signed input operand
    input  wire signed [7:0] b,  // Second 8-bit signed input operand
    output reg  signed [31:0] y  // 32-bit signed output (product)
);
    // Synchronous behavior: updates only on rising clock edge
    always @(posedge clk) begin
        if (reset) begin
            // Reset: clear output to zero
            y <= 0;
        end
        else if (enable) begin
            // Enable: perform multiplication and store result
            y <= a * b;
        end
    end
endmodule

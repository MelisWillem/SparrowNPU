`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/14/2025 10:16:06 PM
// Design Name: 
// Module Name: tb_mul
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


module tb_mul1d;
    reg clk = 0;
    reg reset;
    reg enable;
    reg signed [7:0] a;
    reg signed [7:0] b;
    wire signed [15:0] y;

    mul dut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .a(a),
        .b(b),
        .y(y)
    );

    always #5 clk = ~clk; // 100 MHz

    initial begin
        reset = 1;
        enable = 0;
        a = 0;
        b = 0;

        #20;
        reset = 0;
        enable = 1;

        a = 8'sd3;  b = 8'sd4;   // 3*4=12
        #10;
        a = 8'sd2; b = 8'sd5;   // 2*5=10
        #10;
        a = 8'sd7;  b = 8'sd6;  // 7*6=42
        #10;

        $finish;
    end
endmodule

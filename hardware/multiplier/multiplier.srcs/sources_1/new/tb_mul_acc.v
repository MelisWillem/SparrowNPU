`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/14/2025 10:16:06 PM
// Design Name: 
// Module Name: tb_mul_acc
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Testbench for multiply-accumulate module
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_mul_acc;
    reg clk = 0;
    reg reset;
    reg enable_mac;
    reg [7:0] A;  // 8-bit unsigned operand
    reg [7:0] B;  // 8-bit unsigned operand
    wire [15:0] P_out;  // 16-bit accumulated product output

    // Instantiate the multiply-accumulate module
    mulc_acc dut (
        .clk(clk),
        .reset(reset),
        .enable_mac(enable_mac),
        .A(A),
        .B(B),
        .P_out(P_out)
    );

    // Clock generation: 100 MHz (10ns period)
    always begin
        #5 clk = ~clk;
    end

    // Test stimulus
    initial begin
        // Initialize signals
        reset = 1;
        enable_mac = 0;
        A = 8'h0;
        B = 8'h0;

        // Wait a few clock cycles with reset active
        #20;
        reset = 0;
        enable_mac = 1;

        // Test 1: First multiplication (3 * 4 = 12)
        // Accumulator should be: 0 + 12 = 12
        A = 8'd3;
        B = 8'd4;
        #10;
        
        // Test 2: Second multiplication (5 * 6 = 30)
        // Accumulator should be: 12 + 30 = 42
        A = 8'd5;
        B = 8'd6;
        #10;
        
        // Test 3: Third multiplication (2 * 7 = 14)
        // Accumulator should be: 42 + 14 = 56
        A = 8'd2;
        B = 8'd7;
        #10;
        
        // Test 4: Disable accumulation (should hold value)
        enable_mac = 0;
        A = 8'd10;
        B = 8'd10;  // 10*10=100, but shouldn't accumulate
        #10;
        
        // Test 5: Re-enable accumulation (10 * 10 = 100)
        // Accumulator should be: 56 + 100 = 156
        enable_mac = 1;
        #10;
        
        // Test 6: Reset accumulator
        reset = 1;
        #10;
        reset = 0;
        enable_mac = 1;
        
        // Test 7: Start fresh accumulation (8 * 9 = 72)
        // Accumulator should be: 0 + 72 = 72
        A = 8'd8;
        B = 8'd9;
        #10;
        
        // Test 8: Maximum values (255 * 255 = 65025)
        // Accumulator should be: 72 + 65025 = 65097 (fits in 16 bits)
        A = 8'd255;
        B = 8'd255;
        #10;
        
        // Test 9: Overflow test (would need accumulator > 65535 to overflow)
        // Note: 8-bit max product is 65025, so would need many accumulations to overflow
        // For demonstration: reset and accumulate large values
        reset = 1;
        #10;
        reset = 0;
        A = 8'd255;
        B = 8'd255;  // 65025
        #10;
        A = 8'd255;
        B = 8'd255;  // 65025 + 65025 = 130050 (overflows! wraps to 130050 - 65536 = 64514)
        #20;

        $finish;
    end

endmodule

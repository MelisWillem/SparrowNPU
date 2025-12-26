`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/14/2025 10:16:06 PM
// Design Name: 
// Module Name: tb_systolic_2x2
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Testbench for 2×2 systolic array
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_systolic_2x2;
    reg clk = 0;
    reg reset;
    reg enable_mac;
    reg [7:0] A_in_0;  // Top of column 0 (A flows down)
    reg [7:0] A_in_1;  // Top of column 1 (A flows down)
    reg [7:0] B_in_0;  // Left of row 0 (B flows right)
    reg [7:0] B_in_1;  // Left of row 1 (B flows right)
    wire [15:0] P_out_00;
    wire [15:0] P_out_01;
    wire [15:0] P_out_10;
    wire [15:0] P_out_11;

    // Instantiate the systolic array
    systolic_2x2 dut (
        .clk(clk),
        .reset(reset),
        .enable_mac(enable_mac),
        .A_in_0(A_in_0),
        .A_in_1(A_in_1),
        .B_in_0(B_in_0),
        .B_in_1(B_in_1),
        .P_out_00(P_out_00),
        .P_out_01(P_out_01),
        .P_out_10(P_out_10),
        .P_out_11(P_out_11)
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
        A_in_0 = 8'h0;
        A_in_1 = 8'h0;
        B_in_0 = 8'h0;
        B_in_1 = 8'h0;

        // Wait a few clock cycles with reset active
        #20;
        reset = 0;
        enable_mac = 1;

        // Test: A = [1 2]  B = [5 6]  Expected C = [19 22]
        //            [3 4]      [7 8]                [43 50]
        //
        // Timing: PE00 (no delay), PE01 (B delayed), PE10 (A delayed), PE11 (both delayed)

        // PE00: 1*5 + 2*7 = 19
        // PE01: 1*6 + 2*8 = 22
        // PE10: 3*5 + 4*7 = 43
        // PE11: 3*6 + 4*8 = 50

        // pipeline:
        // A0: 1 -> 2 -> 0 -> 0 ...
        // A1: 0 -> 3 -> 4 -> 0 ...
        // B0: 5 -> 7 -> 0 -> 0 ...
        // B1: 0 -> 6 -> 8 -> 0 ...
        
        // Cycle 1: Only PE00 ready
        A_in_0 = 8'd1;  // A[0][0]
        A_in_1 = 8'd0;
        B_in_0 = 8'd5;  // B[0][0]
        B_in_1 = 8'd0;
        #10;

        // Cycle 2: PE00, PE01, PE10 active
        A_in_0 = 8'd2;  // A0: 2
        A_in_1 = 8'd3;  // A1: 3
        B_in_0 = 8'd7;  // B0: 7
        B_in_1 = 8'd6;  // B1: 6
        #10;

        // Cycle 3: 
        A_in_0 = 8'd0;  // A0: 0
        A_in_1 = 8'd4;  // A1: 4
        B_in_0 = 8'd0;  // B0: 0
        B_in_1 = 8'd8;  // B1: 8
        #10;

        // Cycle 4:
        A_in_0 = 8'd0;  // A[1][1]
        A_in_1 = 8'd0;  // A[1][0]
        B_in_0 = 8'd0;
        B_in_1 = 8'd0;
        #10;

        // Cycle 5+: Zero out inputs to stop accumulation
        A_in_0 = 8'd0;
        A_in_1 = 8'd0;
        B_in_0 = 8'd0;
        B_in_1 = 8'd0;
        #10;

        // Wait for delayed paths to complete
        #50;
        
        // Display results
        $display("=== Systolic Array Results ===");
        $display("P_out_00 (C[0][0]): Expected = 19, Got = %d", P_out_00);
        $display("P_out_01 (C[0][1]): Expected = 22, Got = %d", P_out_01);
        $display("P_out_10 (C[1][0]): Expected = 43, Got = %d", P_out_10);
        $display("P_out_11 (C[1][1]): Expected = 50, Got = %d", P_out_11);
        $display("==============================");

        // Assertions to verify correctness
        if (P_out_00 == 16'd19) begin
            $display("✓ PASS: P_out_00 = 19");
        end else begin
            $display("✗ FAIL: P_out_00 = %d, expected 19", P_out_00);
            $error("P_out_00 mismatch!");
        end

        if (P_out_01 == 16'd22) begin
            $display("✓ PASS: P_out_01 = 22");
        end else begin
            $display("✗ FAIL: P_out_01 = %d, expected 22", P_out_01);
            $error("P_out_01 mismatch!");
        end

        if (P_out_10 == 16'd43) begin
            $display("✓ PASS: P_out_10 = 43");
        end else begin
            $display("✗ FAIL: P_out_10 = %d, expected 43", P_out_10);
            $error("P_out_10 mismatch!");
        end

        if (P_out_11 == 16'd50) begin
            $display("✓ PASS: P_out_11 = 50");
        end else begin
            $display("✗ FAIL: P_out_11 = %d, expected 50", P_out_11);
            $error("P_out_11 mismatch!");
        end

        $display("\nTest completed!");
        $finish;
    end

endmodule

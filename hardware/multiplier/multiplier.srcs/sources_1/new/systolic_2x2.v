`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/14/2025 09:43:55 PM
// Design Name: 
// Module Name: systolic_2x2
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 2×2 systolic array for matrix multiplication
//              A matrix flows right (row-wise), B matrix flows down (column-wise)
// 
// Dependencies: mulc_acc
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module systolic_2x2 (
    input wire clk,
    input wire reset,
    input wire enable_mac,
    // A matrix inputs (flow right row-wise)
    input wire [7:0] A_in_0,  // Left of row 0
    input wire [7:0] A_in_1,  // Left of row 1
    // B matrix inputs (flow down column-wise)
    input wire [7:0] B_in_0,  // Top of column 0
    input wire [7:0] B_in_1,  // Top of column 1
    // Outputs from each PE
    output wire [15:0] P_out_00,  // PE at row 0, col 0
    output wire [15:0] P_out_01,  // PE at row 0, col 1
    output wire [15:0] P_out_10,  // PE at row 1, col 0
    output wire [15:0] P_out_11   // PE at row 1, col 1
);

// Systolic array layout:
//      B0  B1
// A0  PE00 PE01
// A1  PE10 PE11

// Internal signals for systolic data flow
// A flows right (row-wise) - registered values
reg [7:0] A_00_to_01;  // A0 from PE00 to PE01 (row 0, flows right)
reg [7:0] A_10_to_11;  // A1 from PE10 to PE11 (row 1, flows right)

// B flows down (column-wise) - registered values  
reg [7:0] B_00_to_10;  // B0 from PE00 to PE10 (column 0, flows down)
reg [7:0] B_01_to_11;  // B1 from PE01 to PE11 (column 1, flows down)

// Systolic data flow registers
// A flows right: register A values as they flow through PEs
always @(posedge clk) begin
    if (reset) begin
        A_00_to_01 <= 8'h0;
        A_10_to_11 <= 8'h0;
    end else begin
        // A0 from PE00 flows right to PE01 (row 0)
        A_00_to_01 <= A_in_0;
        // A1 from PE10 flows right to PE11 (row 1)
        A_10_to_11 <= A_in_1;
    end
end

// B flows down: register B values as they flow through PEs
always @(posedge clk) begin
    if (reset) begin
        B_00_to_10 <= 8'h0;
        B_01_to_11 <= 8'h0;
    end else begin
        // B0 from PE00 flows down to PE10 (column 0)
        B_00_to_10 <= B_in_0;
        // B1 from PE01 flows down to PE11 (column 1)
        B_01_to_11 <= B_in_1;
    end
end

// PE00: Top-left
mulc_acc pe00 (
    .clk(clk),
    .reset(reset),
    .enable_mac(enable_mac),
    .A(A_in_0),      // A0 enters from left (row 0)
    .B(B_in_0),      // B0 enters from top (column 0)
    .P_out(P_out_00)
);

// PE01: Top-right
mulc_acc pe01 (
    .clk(clk),
    .reset(reset),
    .enable_mac(enable_mac),
    .A(A_00_to_01),  // A0 comes from PE00 (flows right)
    .B(B_in_1),      // B1 enters from top (column 1)
    .P_out(P_out_01)
);

// PE10: Bottom-left
mulc_acc pe10 (
    .clk(clk),
    .reset(reset),
    .enable_mac(enable_mac),
    .A(A_in_1),      // A1 enters from left (row 1)
    .B(B_00_to_10),  // B0 comes from PE00 (flows down)
    .P_out(P_out_10)
);

// PE11: Bottom-right
mulc_acc pe11 (
    .clk(clk),
    .reset(reset),
    .enable_mac(enable_mac),
    .A(A_10_to_11),  // A1 comes from PE10 (flows right)
    .B(B_01_to_11),  // B1 comes from PE01 (flows down)
    .P_out(P_out_11)
);

endmodule

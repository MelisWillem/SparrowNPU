`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: systolic_2x2_axis
// Description: Top-level AXI-Stream tile — instantiates systolic_feeder + systolic_2x2.
//              Stream protocol: see hardware/multiplier/docs/AXI_STREAM_SYSTOLIC.md
//
// Dependencies: systolic_feeder, systolic_2x2, mulc_acc
//////////////////////////////////////////////////////////////////////////////////

module systolic_2x2_axis #(
    parameter K_MAX = 64,
    parameter C_AXIS_TDATA_WIDTH = 32
) (
    input wire clk,
    input wire reset,

    input wire [C_AXIS_TDATA_WIDTH-1:0] S_AXIS_A_TDATA,
    input wire S_AXIS_A_TVALID,
    output wire S_AXIS_A_TREADY,
    input wire S_AXIS_A_TLAST,

    input wire [C_AXIS_TDATA_WIDTH-1:0] S_AXIS_B_TDATA,
    input wire S_AXIS_B_TVALID,
    output wire S_AXIS_B_TREADY,
    input wire S_AXIS_B_TLAST,

    output wire [63:0] M_AXIS_C_TDATA,
    output wire M_AXIS_C_TVALID,
    input wire M_AXIS_C_TREADY,
    output wire M_AXIS_C_TLAST
);

    systolic_feeder #(
        .K_MAX(K_MAX),
        .C_AXIS_TDATA_WIDTH(C_AXIS_TDATA_WIDTH)
    ) u_feeder (
        .clk(clk),
        .reset(reset),
        .S_AXIS_A_TDATA(S_AXIS_A_TDATA),
        .S_AXIS_A_TVALID(S_AXIS_A_TVALID),
        .S_AXIS_A_TREADY(S_AXIS_A_TREADY),
        .S_AXIS_A_TLAST(S_AXIS_A_TLAST),
        .S_AXIS_B_TDATA(S_AXIS_B_TDATA),
        .S_AXIS_B_TVALID(S_AXIS_B_TVALID),
        .S_AXIS_B_TREADY(S_AXIS_B_TREADY),
        .S_AXIS_B_TLAST(S_AXIS_B_TLAST),
        .M_AXIS_C_TDATA(M_AXIS_C_TDATA),
        .M_AXIS_C_TVALID(M_AXIS_C_TVALID),
        .M_AXIS_C_TREADY(M_AXIS_C_TREADY),
        .M_AXIS_C_TLAST(M_AXIS_C_TLAST)
    );

endmodule

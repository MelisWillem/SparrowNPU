`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: systolic_2x2_axis
// Description: 2×2 systolic array with AXI-Stream interface for DMA
//
// Stream protocol (wavefront order, see docs/AXI_STREAM_SYSTOLIC.md):
//   - S_AXIS_A: TDATA[7:0]=A_in_0, TDATA[15:8]=A_in_1 per beat
//   - S_AXIS_B: TDATA[7:0]=B_in_0, TDATA[15:8]=B_in_1 per beat
//   - M_AXIS_C: Output 64-bit beat {P11, P10, P01, P00}
//
// Handshake: data transfer when TVALID & TREADY both high.
// TLAST on input streams marks last beat of a tile (triggers output flush).
//
// Dependencies: systolic_2x2, mulc_acc
//////////////////////////////////////////////////////////////////////////////////

module systolic_2x2_axis #(
    parameter C_AXIS_TDATA_WIDTH = 32
) (
    input wire clk,
    input wire reset,

    // AXI-Stream slave: A matrix input (from DMA MM2S)
    input wire [C_AXIS_TDATA_WIDTH-1:0] S_AXIS_A_TDATA,
    input wire S_AXIS_A_TVALID,
    output wire S_AXIS_A_TREADY,
    input wire S_AXIS_A_TLAST,

    // AXI-Stream slave: B matrix input (from DMA MM2S)
    input wire [C_AXIS_TDATA_WIDTH-1:0] S_AXIS_B_TDATA,
    input wire S_AXIS_B_TVALID,
    output wire S_AXIS_B_TREADY,
    input wire S_AXIS_B_TLAST,

    // AXI-Stream master: C matrix output (to DMA S2MM)
    output wire [63:0] M_AXIS_C_TDATA,
    output wire M_AXIS_C_TVALID,
    input wire M_AXIS_C_TREADY,
    output wire M_AXIS_C_TLAST
);

    // Extract packed values from 32-bit beats
    // A: TDATA[15:8]=A[1][k], TDATA[7:0]=A[0][k]
    // B: TDATA[15:8]=B[k][1], TDATA[7:0]=B[k][0]
    wire [7:0] A_in_0 = S_AXIS_A_TDATA[7:0];
    wire [7:0] A_in_1 = S_AXIS_A_TDATA[15:8];
    wire [7:0] B_in_0 = S_AXIS_B_TDATA[7:0];
    wire [7:0] B_in_1 = S_AXIS_B_TDATA[15:8];

    // Systolic array outputs
    wire [15:0] P_out_00, P_out_01, P_out_10, P_out_11;

    reg [1:0] state;
    localparam IDLE      = 2'd0;
    localparam COMPUTING = 2'd1;
    localparam DRAINING  = 2'd2;
    localparam FLUSHING  = 2'd3;

    // Drain cycle counter: need 2 extra cycles after last data for PE11 to complete
    reg [1:0] drain_cnt;

    wire both_inputs_valid = S_AXIS_A_TVALID & S_AXIS_B_TVALID;
    wire input_handshake = both_inputs_valid & S_AXIS_A_TREADY & S_AXIS_B_TREADY;
    wire last_beat = S_AXIS_A_TLAST & S_AXIS_B_TLAST;

    // Reset systolic accumulators one cycle after output completes (clears for next tile)
    reg reset_systolic;
    always @(posedge clk) begin
        if (reset)
            reset_systolic <= 1'b1;
        else
            reset_systolic <= (state == FLUSHING && M_AXIS_C_TVALID && M_AXIS_C_TREADY);
    end
    wire systolic_reset = reset | reset_systolic;

    // Generate enable_mac: active when feeding data or during drain
    reg enable_mac;
    always @(posedge clk) begin
        if (reset) begin
            enable_mac <= 1'b0;
        end else begin
            enable_mac <= feed_from_stream || (state == DRAINING);
        end
    end

    // Feed from stream when we have valid handshake (IDLE or COMPUTING), else zeros during drain
    wire feed_from_stream = (state == IDLE || state == COMPUTING) && both_inputs_valid;
    wire [7:0] A_0_mux = feed_from_stream ? A_in_0 : 8'h0;
    wire [7:0] A_1_mux = feed_from_stream ? A_in_1 : 8'h0;
    wire [7:0] B_0_mux = feed_from_stream ? B_in_0 : 8'h0;
    wire [7:0] B_1_mux = feed_from_stream ? B_in_1 : 8'h0;

    // State machine
    always @(posedge clk) begin
        if (reset) begin
            state     <= IDLE;
            drain_cnt <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (input_handshake) begin
                        state <= last_beat ? DRAINING : COMPUTING;
                        if (last_beat)
                            drain_cnt <= 2'd0;
                    end
                end
                COMPUTING: begin
                    if (input_handshake && last_beat) begin
                        drain_cnt <= 2'd0;
                        state    <= DRAINING;
                    end
                end
                DRAINING: begin
                    if (drain_cnt == 2'd1)
                        state <= FLUSHING;
                    drain_cnt <= drain_cnt + 2'd1;
                end
                FLUSHING: begin
                    if (M_AXIS_C_TVALID & M_AXIS_C_TREADY)
                        state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

    // Input TREADY: accept when in IDLE or COMPUTING, and not blocked
    assign S_AXIS_A_TREADY = (state == IDLE || state == COMPUTING) && (state != FLUSHING);
    assign S_AXIS_B_TREADY = (state == IDLE || state == COMPUTING) && (state != FLUSHING);

    // Output: one 64-bit beat with all four results
    assign M_AXIS_C_TDATA  = {P_out_11, P_out_10, P_out_01, P_out_00};
    assign M_AXIS_C_TVALID = (state == FLUSHING);
    assign M_AXIS_C_TLAST  = 1'b1;  // Single beat per tile

    // Systolic array instance
    systolic_2x2 u_systolic (
        .clk(clk),
        .reset(systolic_reset),
        .enable_mac(enable_mac),
        .A_in_0(A_0_mux),
        .A_in_1(A_1_mux),
        .B_in_0(B_0_mux),
        .B_in_1(B_1_mux),
        .P_out_00(P_out_00),
        .P_out_01(P_out_01),
        .P_out_10(P_out_10),
        .P_out_11(P_out_11)
    );

endmodule

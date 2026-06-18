`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: systolic_feeder
// Description: BRAM cache + load/feed FSM between AXI-Stream (DMA) and systolic_2x2.
//              Loads N synchronized beats (packed A/B per beat), then replays
//              wavefront from RAM at 1 beat/cycle, then drain + M_AXIS_C flush.
//              See hardware/multiplier/docs/AXI_STREAM_SYSTOLIC.md
//
// Dependencies: systolic_2x2, mulc_acc
//////////////////////////////////////////////////////////////////////////////////

// Parameterized module for the systolic feeder
// C = A × B
// A is a 2xK matrix
// B is a Kx2 matrix
// K_MAX is the maximum number of packed input beats per tile
// There are 3 streams: A, B, and C
// A and B are slave streams, C is a master stream
// Each stream has 4 io/s
//  - TDATA: data input/output
//  - TVALID: valid signal input/output
//  - TREADY: ready signal input/output
//  - TLAST: last signal input/output
module systolic_feeder #(
    parameter K_MAX = 64,
    parameter C_AXIS_TDATA_WIDTH = 32
) (
    input wire clk,
    input wire reset,

    // Slave stream A (A matrix)
    input wire [C_AXIS_TDATA_WIDTH-1:0] S_AXIS_A_TDATA,  // data input for the A axis
    input wire S_AXIS_A_TVALID,  // valid signal for the A axis
    output wire S_AXIS_A_TREADY,  // ready signal for the A axis
    input wire S_AXIS_A_TLAST,  // last signal for the A axis

    // Slave stream B (B matrix)
    input wire [C_AXIS_TDATA_WIDTH-1:0] S_AXIS_B_TDATA,  // data input for the B axis
    input wire S_AXIS_B_TVALID,  // valid signal for the B axis
    output wire S_AXIS_B_TREADY,  // ready signal for the B axis
    input wire S_AXIS_B_TLAST,  // last signal for the B axis

    // Master stream C (C matrix)
    output wire [63:0] M_AXIS_C_TDATA,  // data output for the C axis
    output wire M_AXIS_C_TVALID,  // valid signal for the C axis
    input wire M_AXIS_C_TREADY,  // ready signal for the C axis
    output wire M_AXIS_C_TLAST  // last signal for the C axis
);

    // PTR_W is the width of the pointer to the RAM
    localparam PTR_W = $clog2(K_MAX + 1);

    (* ram_style = "block" *) reg [15:0] ram_a [0:K_MAX-1];
    (* ram_style = "block" *) reg [15:0] ram_b [0:K_MAX-1];

    localparam [2:0] ST_IDLE     = 3'd0,
                     ST_LOADING  = 3'd1,
                     ST_ARM      = 3'd5,  // 1 cycle so BRAM write settles before ST_FEED reads
                     ST_FEED      = 3'd2,
                     ST_DRAINING  = 3'd3,
                     ST_FLUSHING  = 3'd4;

    reg [2:0] state;

    reg [PTR_W-1:0] wr_ptr;
    reg [PTR_W-1:0] loaded_beats;
    reg [PTR_W-1:0] feed_idx;

    reg [1:0] drain_cnt;

    wire both_in_valid = S_AXIS_A_TVALID & S_AXIS_B_TVALID;
    wire load_handshake = both_in_valid & S_AXIS_A_TREADY & S_AXIS_B_TREADY;
    wire last_load_beat = S_AXIS_A_TLAST & S_AXIS_B_TLAST;

    wire feed_active = (state == ST_FEED);
    wire drain_active = (state == ST_DRAINING);

    wire [PTR_W-1:0] prev_idx = feed_idx - {{(PTR_W-1){1'b0}}, 1'b1};

    wire [7:0] comb_a0 = (feed_idx < loaded_beats) ? ram_a[feed_idx][7:0] : 8'h0;
    wire [7:0] comb_a1 = (feed_idx >= 1 && prev_idx < loaded_beats) ? ram_a[prev_idx][15:8] : 8'h0;
    wire [7:0] comb_b0 = (feed_idx < loaded_beats) ? ram_b[feed_idx][7:0] : 8'h0;
    wire [7:0] comb_b1 = (feed_idx >= 1 && prev_idx < loaded_beats) ? ram_b[prev_idx][15:8] : 8'h0;

    wire [7:0] mac_a0 = feed_active ? comb_a0 : 8'h0;
    wire [7:0] mac_a1 = feed_active ? comb_a1 : 8'h0;
    wire [7:0] mac_b0 = feed_active ? comb_b0 : 8'h0;
    wire [7:0] mac_b1 = feed_active ? comb_b1 : 8'h0;

    wire enable_mac = feed_active | drain_active;

    wire ram_has_room = (wr_ptr < K_MAX);

    assign S_AXIS_A_TREADY = (state == ST_IDLE || state == ST_LOADING) && ram_has_room;
    assign S_AXIS_B_TREADY = (state == ST_IDLE || state == ST_LOADING) && ram_has_room;

    always @(posedge clk) begin
        if (reset) begin
            state <= ST_IDLE;
            wr_ptr <= 0;
            loaded_beats <= 0;
            feed_idx <= 0;
            drain_cnt <= 0;
        end else begin
            case (state)
                ST_IDLE: begin
                    wr_ptr <= 0;
                    if (load_handshake) begin
                        ram_a[wr_ptr] <= S_AXIS_A_TDATA[15:0];
                        ram_b[wr_ptr] <= S_AXIS_B_TDATA[15:0];
                        if (last_load_beat) begin
                            loaded_beats <= wr_ptr + 1'b1;
                            feed_idx <= 0;
                            state <= ST_ARM;
                        end else begin
                            wr_ptr <= wr_ptr + 1'b1;
                            state <= ST_LOADING;
                        end
                    end
                end
                ST_LOADING: begin
                    if (load_handshake) begin
                        ram_a[wr_ptr] <= S_AXIS_A_TDATA[15:0];
                        ram_b[wr_ptr] <= S_AXIS_B_TDATA[15:0];
                        if (last_load_beat) begin
                            loaded_beats <= wr_ptr + 1'b1;
                            feed_idx <= 0;
                            state <= ST_ARM;
                        end else
                            wr_ptr <= wr_ptr + 1'b1;
                    end
                end
                ST_ARM: begin
                    state <= ST_FEED;
                end
                ST_FEED: begin
                    if (feed_idx == loaded_beats - 1'b1) begin
                        drain_cnt <= 0;
                        state <= ST_DRAINING;
                    end else
                        feed_idx <= feed_idx + 1'b1;
                end
                ST_DRAINING: begin
                    if (drain_cnt == 2'd1)
                        state <= ST_FLUSHING;
                    else
                        drain_cnt <= drain_cnt + 1'b1;
                end
                ST_FLUSHING: begin
                    if (M_AXIS_C_TVALID && M_AXIS_C_TREADY)
                        state <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end

    reg reset_systolic;
    always @(posedge clk) begin
        if (reset)
            reset_systolic <= 1'b1;
        else
            reset_systolic <= (state == ST_FLUSHING && M_AXIS_C_TVALID && M_AXIS_C_TREADY);
    end
    wire systolic_reset = reset | reset_systolic;

    wire [15:0] P_out_00, P_out_01, P_out_10, P_out_11;

    systolic_2x2 u_systolic (
        .clk(clk),
        .reset(systolic_reset),
        .enable_mac(enable_mac),
        .A_in_0(mac_a0),
        .A_in_1(mac_a1),
        .B_in_0(mac_b0),
        .B_in_1(mac_b1),
        .P_out_00(P_out_00),
        .P_out_01(P_out_01),
        .P_out_10(P_out_10),
        .P_out_11(P_out_11)
    );

    assign M_AXIS_C_TDATA  = {P_out_11, P_out_10, P_out_01, P_out_00};
    assign M_AXIS_C_TVALID = (state == ST_FLUSHING);
    assign M_AXIS_C_TLAST  = 1'b1;

endmodule

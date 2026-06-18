`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for systolic_feeder (BRAM load + wavefront replay + M_AXIS_C flush)
//
// Test 1: Same 2×2 matmul as tb_systolic_2x2_axis — A = [1 2; 3 4], B = [5 6; 7 8]
//         Expected C = [19 22; 43 50] in {P11,P10,P01,P00} packing on M_AXIS_C.
// Test 2: M_AXIS_C_TREADY low until after TVALID, then complete handshake.
//////////////////////////////////////////////////////////////////////////////////

module tb_systolic_feeder;

    reg clk = 0;
    reg reset;

    reg [31:0] S_AXIS_A_TDATA;
    reg S_AXIS_A_TVALID;
    wire S_AXIS_A_TREADY;
    reg S_AXIS_A_TLAST;

    reg [31:0] S_AXIS_B_TDATA;
    reg S_AXIS_B_TVALID;
    wire S_AXIS_B_TREADY;
    reg S_AXIS_B_TLAST;

    wire [63:0] M_AXIS_C_TDATA;
    wire M_AXIS_C_TVALID;
    reg M_AXIS_C_TREADY;
    wire M_AXIS_C_TLAST;

    systolic_feeder #(
        .K_MAX(64),
        .C_AXIS_TDATA_WIDTH(32)
    ) dut (
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

    always #5 clk = ~clk;

    task axis_wait_both_ready;
        begin
            @(posedge clk);
            while (!(S_AXIS_A_TREADY && S_AXIS_B_TREADY))
                @(posedge clk);
        end
    endtask

    task send_load_beat;
        input [31:0] adata;
        input [31:0] bdata;
        input last_beat;
        begin
            S_AXIS_A_TDATA  = adata;
            S_AXIS_B_TDATA  = bdata;
            S_AXIS_A_TVALID = 1'b1;
            S_AXIS_B_TVALID = 1'b1;
            S_AXIS_A_TLAST  = last_beat;
            S_AXIS_B_TLAST  = last_beat;
            axis_wait_both_ready;
        end
    endtask

    task axis_idle;
        begin
            S_AXIS_A_TVALID = 1'b0;
            S_AXIS_B_TVALID = 1'b0;
            S_AXIS_A_TLAST  = 1'b0;
            S_AXIS_B_TLAST  = 1'b0;
        end
    endtask

    task check_c_matrix;
        input [63:0] cdata;
        begin
            $display("M_AXIS_C_TDATA = 0x%016x", cdata);
            $display("  P00: exp 19 got %d", cdata[15:0]);
            $display("  P01: exp 22 got %d", cdata[31:16]);
            $display("  P10: exp 43 got %d", cdata[47:32]);
            $display("  P11: exp 50 got %d", cdata[63:48]);
            if (cdata[15:0]  == 16'd19 &&
                cdata[31:16] == 16'd22 &&
                cdata[47:32] == 16'd43 &&
                cdata[63:48] == 16'd50)
                $display("PASS");
            else
                $error("Output mismatch");
        end
    endtask

    initial begin
        reset = 1'b1;
        S_AXIS_A_TDATA  = 32'h0;
        S_AXIS_A_TVALID = 1'b0;
        S_AXIS_A_TLAST  = 1'b0;
        S_AXIS_B_TDATA  = 32'h0;
        S_AXIS_B_TVALID = 1'b0;
        S_AXIS_B_TLAST  = 1'b0;
        M_AXIS_C_TREADY = 1'b1;

        #30 reset = 1'b0;

        // --- Test 1: TREADY always 1 ---
        @(posedge clk);
        send_load_beat(32'h00000001, 32'h00000005, 1'b0);
        send_load_beat(32'h00000302, 32'h00000607, 1'b0);
        send_load_beat(32'h00000400, 32'h00000800, 1'b1);
        axis_idle;
        @(posedge clk);

        while (!M_AXIS_C_TVALID)
            @(posedge clk);
        $display("=== Test 1 (feeder load + feed + flush) ===");
        check_c_matrix(M_AXIS_C_TDATA);
        // Handshake may occur same cycle as TVALID; advance past flush like tb_systolic_2x2_axis
        @(posedge clk);
        @(posedge clk);

        // --- Test 2: backpressure on M_AXIS_C ---
        M_AXIS_C_TREADY = 1'b0;
        @(posedge clk);
        send_load_beat(32'h00000001, 32'h00000005, 1'b0);
        send_load_beat(32'h00000302, 32'h00000607, 1'b0);
        send_load_beat(32'h00000400, 32'h00000800, 1'b1);
        axis_idle;

        begin : test2_wait
            integer n;
            n = 0;
            while (!M_AXIS_C_TVALID) begin
                @(posedge clk);
                n = n + 1;
                if (n > 500) begin
                    $error("Test2: timeout waiting for M_AXIS_C_TVALID");
                    $finish;
                end
            end
        end

        repeat (3) @(posedge clk);
        M_AXIS_C_TREADY = 1'b1;
        @(posedge clk);
        while (!(M_AXIS_C_TVALID && M_AXIS_C_TREADY))
            @(posedge clk);

        $display("=== Test 2 (M_AXIS_C backpressure) ===");
        check_c_matrix(M_AXIS_C_TDATA);
        @(posedge clk);

        $display("tb_systolic_feeder: done");
        $finish;
    end

endmodule

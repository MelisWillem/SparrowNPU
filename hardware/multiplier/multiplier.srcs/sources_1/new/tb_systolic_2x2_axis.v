`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for systolic_2x2_axis (AXI-Stream DMA interface)
//
// Test: A = [1 2]  B = [5 6]  Expected C = [19 22]
//            [3 4]      [7 8]                [43 50]
//////////////////////////////////////////////////////////////////////////////////

module tb_systolic_2x2_axis;

    reg clk = 0;
    reg reset;

    // AXI-Stream A (simulated DMA MM2S)
    reg [31:0] S_AXIS_A_TDATA;
    reg S_AXIS_A_TVALID;
    wire S_AXIS_A_TREADY;
    reg S_AXIS_A_TLAST;

    // AXI-Stream B (simulated DMA MM2S)
    reg [31:0] S_AXIS_B_TDATA;
    reg S_AXIS_B_TVALID;
    wire S_AXIS_B_TREADY;
    reg S_AXIS_B_TLAST;

    // AXI-Stream C (to DMA S2MM)
    wire [63:0] M_AXIS_C_TDATA;
    wire M_AXIS_C_TVALID;
    reg M_AXIS_C_TREADY;
    wire M_AXIS_C_TLAST;

    systolic_2x2_axis #(.C_AXIS_TDATA_WIDTH(32)) dut (
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

    initial begin
        reset = 1;
        S_AXIS_A_TDATA  = 32'h0;
        S_AXIS_A_TVALID = 0;
        S_AXIS_A_TLAST  = 0;
        S_AXIS_B_TDATA  = 32'h0;
        S_AXIS_B_TVALID = 0;
        S_AXIS_B_TLAST  = 0;
        M_AXIS_C_TREADY = 1;

        #30 reset = 0;

        // Systolic wavefront order - 3 beats for 2x2, then 2 internal drain cycles
        // Beat 0: A_in_0=1, A_in_1=0; B_in_0=5, B_in_1=0
        // Beat 1: A_in_0=2, A_in_1=3; B_in_0=7, B_in_1=6
        // Beat 2: A_in_0=0, A_in_1=4; B_in_0=0, B_in_1=8  (TLAST)

        @(posedge clk);
        S_AXIS_A_TDATA  = 32'h00000001;  // A_in_0=1, A_in_1=0
        S_AXIS_A_TVALID = 1;
        S_AXIS_B_TDATA  = 32'h00000005;  // B_in_0=5, B_in_1=0
        S_AXIS_B_TVALID = 1;
        S_AXIS_A_TLAST  = 0;
        S_AXIS_B_TLAST  = 0;

        @(posedge clk);
        while (!(S_AXIS_A_TREADY && S_AXIS_B_TREADY)) @(posedge clk);
        S_AXIS_A_TDATA  = 32'h00000302;  // A_in_0=2, A_in_1=3
        S_AXIS_B_TDATA  = 32'h00000607;  // B_in_0=7, B_in_1=6  (was 0x0807 = wrong hi byte)
        S_AXIS_A_TLAST  = 0;
        S_AXIS_B_TLAST  = 0;

        @(posedge clk);
        while (!(S_AXIS_A_TREADY && S_AXIS_B_TREADY)) @(posedge clk);
        S_AXIS_A_TDATA  = 32'h00000400;  // A_in_0=0, A_in_1=4
        S_AXIS_B_TDATA  = 32'h00000800;  // B_in_0=0, B_in_1=8
        S_AXIS_A_TLAST  = 1;
        S_AXIS_B_TLAST  = 1;

        @(posedge clk);
        while (!(S_AXIS_A_TREADY && S_AXIS_B_TREADY)) @(posedge clk);
        S_AXIS_A_TVALID = 0;
        S_AXIS_B_TVALID = 0;
        S_AXIS_A_TLAST  = 0;
        S_AXIS_B_TLAST  = 0;

        // Wait for output
        @(posedge clk);
        while (!M_AXIS_C_TVALID) @(posedge clk);

        $display("=== Systolic Array AXI-Stream Results ===");
        $display("M_AXIS_C_TDATA = 0x%016x", M_AXIS_C_TDATA);
        $display("  P00 (C[0][0]): Expected = 19, Got = %d", M_AXIS_C_TDATA[15:0]);
        $display("  P01 (C[0][1]): Expected = 22, Got = %d", M_AXIS_C_TDATA[31:16]);
        $display("  P10 (C[1][0]): Expected = 43, Got = %d", M_AXIS_C_TDATA[47:32]);
        $display("  P11 (C[1][1]): Expected = 50, Got = %d", M_AXIS_C_TDATA[63:48]);
        $display("==========================================");

        // Consume output (TREADY already 1)
        @(posedge clk);

        if (M_AXIS_C_TDATA[15:0]  == 16'd19 &&
            M_AXIS_C_TDATA[31:16] == 16'd22 &&
            M_AXIS_C_TDATA[47:32] == 16'd43 &&
            M_AXIS_C_TDATA[63:48] == 16'd50) begin
            $display("PASS: All outputs correct");
        end else begin
            $display("FAIL: Output mismatch");
            $error("Test failed!");
        end

        $finish;
    end

endmodule

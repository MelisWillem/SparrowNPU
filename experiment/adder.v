module adder #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire             cin,
    input  wire             clk,
    output wire [WIDTH-1:0] sum,
    output wire             cout
);
    reg [WIDTH:0] sum_reg;

    always @(posedge clk) begin
        sum_reg <= a + b + cin;
    end

    assign sum = sum_reg[WIDTH-1:0];
    assign cout = sum_reg[WIDTH];

endmodule
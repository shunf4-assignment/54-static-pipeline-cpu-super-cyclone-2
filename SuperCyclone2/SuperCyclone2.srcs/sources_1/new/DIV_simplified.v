`timescale 1ns / 1ns

module DIV(
    input clk,
    input ena,
    input [31:0] dividend,
    input [31:0] divisor,
    input isUnsigned,
    output [31:0] q,
    output [31:0] r,
    output busy
    );
    
    reg lastEna;
    reg [7:0] counter;
    localparam COUNTER_CYCLE = 25;

    always @(posedge clk) begin
        // negedge of main clk
        lastEna <= ena;
        if (ena != lastEna)
        begin
            counter <= 0;
        end
        else if (ena) begin
            counter <= counter + 1;
        end
    end

    assign busy = ena & (counter != COUNTER_CYCLE);

    //reg [32:0] r_dividend = 0;
    wire [32:0] r_dividend = {1'b0, isUnsigned ? dividend : dividend[31] ? -dividend : dividend};
    //reg [32:0] r_divisor = 0;
    wire [32:0] r_divisor = {1'b0, isUnsigned ? divisor : divisor[31] ? -divisor : divisor};

    wire [32:0] w_quotient = r_dividend / r_divisor;
    wire [32:0] w_remainder = r_dividend % r_divisor;

    assign q = isUnsigned ? w_quotient[31:0] : (dividend[31] ^ divisor[31]) ? (-w_quotient[31:0]) : w_quotient[31:0];
    assign r = isUnsigned ? w_remainder[31:0] : dividend[31] ? (-w_remainder[31:0]) : w_remainder[31:0];
endmodule

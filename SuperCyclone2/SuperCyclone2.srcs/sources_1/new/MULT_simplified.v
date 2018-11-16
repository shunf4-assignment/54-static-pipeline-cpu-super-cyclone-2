`timescale 1ns / 1ps

module MULT (
    input clk,
    input ena,
    input isUnsigned,
    input [31:0] a,
    input [31:0] b,
    output reg [63:0] z,
    output carry,
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

reg [63:0] ax, bx;
wire [63:0] zx;

always @(a or b or isUnsigned) begin
    if(isUnsigned == 1'b1) begin
        ax = a;
        bx = b;
    end else begin
        ax = a[31] ? -a : a;
        bx = b[31] ? -b : b;
    end
end


assign zx = ax * bx;
assign carry = 1'b0;

always @(isUnsigned or zx or a or b) begin
    if(isUnsigned == 1) begin
        z = zx;
    end else begin
        z = (a[31] ^ b[31]) ? -zx : zx;
    end
end


endmodule
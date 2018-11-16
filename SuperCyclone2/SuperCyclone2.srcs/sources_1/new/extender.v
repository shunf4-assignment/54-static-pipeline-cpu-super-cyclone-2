module extender #(
    parameter numOfBits = 16,   // lowest [numOfBits] bits are extended to 32 bits
    parameter isSigned = 1'b1
)
(
    input [31:0] in,
    output [31:0] out
);
    wire paddingBit = numOfBits == 0 ? 1'b0 : isSigned ? in[numOfBits-1] : 1'b0;

    assign out = {{(32-numOfBits){paddingBit}}, in[numOfBits-1:0]};
endmodule


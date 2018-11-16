`timescale 1ns/1ns

module ALU(
    input clk,
    input [31:0] A,
    input [31:0] B,
    input [4:0] modeSel,        //Mode Select, one of the ALU_XXXX constants
    output reg [31:0] R,
    output reg [31:0] RX,            //Extra result, high bits for multiplication and remainder for division

    output isRZero,
    output reg isCarry,
    output isRNegative,
    output reg isOverflow,
    output busy

);
    `include "aluHeader.vh"

    wire [4:0] Blow5 = B[4:0];

    wire signed [31:0] signedA = A;
    wire signed [31:0] signedB = B;

    wire [32:0] extendedA = {A[31], A};
    wire [32:0] extendedB = {B[31], B};
    reg [32:0] extendedResult;

    wire signed [63:0] extendedA64Left = {A, 32'h0};
    wire [63:0] extendedA64Right = {32'h0, A};
    reg [63:0] extendedAShifted;

    wire opIsUnsigned = modeSel[4];

    wire [5:0] clzResult;
    wire clzBusy;

    wire [63:0] multResult;
    wire multCarry;
    wire multBusy;

    wire [31:0] divQuotient;
    wire [31:0] divRemainder;
    wire divBusy;

    assign busy = multBusy | divBusy | clzBusy;

    CLZAlgorithm clzblock (clk, A, (modeSel == ALU_CLZ), clzResult, clzBusy);
    MULT multiplier (
        .clk(clk),
        .ena(modeSel == ALU_SMUL || modeSel == ALU_UMUL),
        .isUnsigned(opIsUnsigned),
        .a(A),
        .b(B),
        .z(multResult),
        .carry(multCarry),
        .busy(multBusy)
    );
    DIV divider (
        .clk(clk),
        .ena(modeSel == ALU_SDIV || modeSel == ALU_UDIV),
        .dividend(A),
        .divisor(B),
        .isUnsigned(opIsUnsigned),
        .q(divQuotient),
        .r(divRemainder),
        .busy(divBusy)
    );

    assign isRZero = (R == 32'h0);
    assign isRNegative = (R[31] == 1'b1);

    always @(*) begin
        case (modeSel)
            ALU_AND: begin
                R = A & B;
                RX = 0;
                isCarry = 0;
                isOverflow = 0;
            end
            ALU_XOR: begin
                R = A ^ B;
                RX = 0;
                isCarry = 0;
                isOverflow = 0;
            end
            ALU_OR: begin
                R = A | B;
                RX = 0;
                isCarry = 0;
                isOverflow = 0;
            end
            ALU_NOR: begin
                R = ~(A | B);
                RX = 0;
                isCarry = 0;
                isOverflow = 0;
            end
            ALU_SL: begin
                extendedAShifted = extendedA64Right << Blow5;
                R = extendedAShifted[31:0];
                //RX = (Blow5 == 0) ? 32'h0 : {{(32 - Blow5){1'b0}}, A[31:32-Blow5]};
                RX = extendedAShifted[63:32];
                isCarry = RX[0];
                isOverflow = 0;
            end
            ALU_SRL: begin
                extendedAShifted = extendedA64Left >> Blow5;
                R = extendedAShifted[63:32];
                //RX = ((Blow5 == 0) ? 32'h0 : {A[Blow5-1:0], {(32 - Blow5){1'b0}}});
                RX = extendedAShifted[31:0];
                isCarry = RX[31];
                isOverflow = 0;
            end
            ALU_SRA: begin
                extendedAShifted = extendedA64Left >>> Blow5;
                R = extendedAShifted[63:32];
                //RX = ((Blow5 == 0) ? 32'h0 : {A[Blow5-1:0], {(32 - Blow5){1'b0}}});
                RX = extendedAShifted[31:0];
                isCarry = RX[31];
                isOverflow = 0;
            end
            ALU_EQU: begin
                R = (A == B)?32'h1:32'h0;
                RX = 0;
                isCarry = 0;
                isOverflow =0;
            end
            ALU_CLZ: begin
                R = {27'b0, clzResult};
                RX = 0;
                isCarry = 0;
                isOverflow = 0;
            end
            //////////////
            ALU_SSUB: begin
                extendedResult = extendedA - extendedB;
                R = extendedResult[31:0];
                RX = 0;
                isCarry = A[31] ^ B[31] ^ extendedResult[32];
                isOverflow = extendedResult[32] ^ extendedResult[31];
            end
            ALU_SMUL: begin
                R = multResult[31:0];
                RX = multResult[63:32];
                isCarry = multCarry;
                isOverflow = 0;
            end
            ALU_SDIV: begin
                R = divQuotient;
                RX = divRemainder;
                isCarry = 0;
                isOverflow = 0;
            end
            ALU_SADD: begin
                extendedResult = extendedA + extendedB;
                R = extendedResult[31:0];
                RX = 0;
                isCarry = A[31] ^ B[31] ^ extendedResult[32];
                isOverflow = extendedResult[32] ^ extendedResult[31];
            end
            ALU_SLES: begin
                R = (signedA < signedB) ? 32'h1 : 32'h0;
                RX = 0;
                isCarry = 0;
                isOverflow = 0;
            end
            ///////////////
            ALU_USUB: begin
                extendedResult = extendedA - extendedB;
                R = extendedResult[31:0];
                RX = 0;
                isCarry = A[31] ^ B[31] ^ extendedResult[32];
                isOverflow = 0;
            end
            ALU_UMUL: begin
                R = multResult[31:0];
                RX = multResult[63:32];
                isCarry = multCarry;
                isOverflow = 0;
            end
            ALU_UDIV: begin
                R = divQuotient;
                RX = divRemainder;
                isCarry = 0;
                isOverflow = 0;
            end
            ALU_UADD: begin
                extendedResult = extendedA + extendedB;
                R = extendedResult[31:0];
                RX = 0;
                isCarry = A[31] ^ B[31] ^ extendedResult[32];
                isOverflow = 0;
            end
            ALU_ULES: begin
                R = (A < B) ? 32'h1 : 32'h0;
                RX = 0;
                isCarry = 0;
                isOverflow = 0;
            end
            
            default: begin
                R = 0;
                RX = 0;
                isCarry = 0;
                isOverflow = 0;
            end
        endcase
    end
    
endmodule


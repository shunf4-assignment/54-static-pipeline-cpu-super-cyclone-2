`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/12/16 13:09:08
// Design Name: 
// Module Name: 7seg-display
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module display_7seg #(
    parameter FREQ_DIVISOR = 100000
)(
    input clk_100MHz,
    input digit_ena,
    input [3:0] digit7,
    input [3:0] digit6,
    input [3:0] digit5,
    input [3:0] digit4,
    input [3:0] digit3,
    input [3:0] digit2,
    input [3:0] digit1,
    input [3:0] digit0,
    input [7:0] dot,
    input [63:0] led_control,
    output [7:0] AN,
    output [7:0] C_wire  //0-7:abcdefgp
    );
    wire clk;
    freqDivider freqDivider_inst
    (
        .clk_i(clk_100MHz),
        .reset(1'b0),
        .clk_o(clk)
    );
    
    localparam A = 0;
    localparam B = 1;
    localparam C = 2;
    localparam D = 3;
    localparam E = 4;
    localparam F = 5;
    localparam G = 6;
    localparam P = 7;
    
    reg [2:0] whichdigit = 3'h0;
    reg [7:0] AN_r = 8'hff;
    reg [7:0] C_r = 8'hff;
    reg [3:0] curr_digit;

    assign C_wire = digit_ena ? C_r : led_control[whichdigit * 8 +: 8];
    
    assign CA = C_wire[0];
    assign CB = C_wire[1];
    assign CC = C_wire[2];
    assign CD = C_wire[3];
    assign CE = C_wire[4];
    assign CF = C_wire[5];
    assign CG = C_wire[6];
    assign DP = C_wire[7];
    

    always @(whichdigit or dot or digit0 or digit1 or digit2 or digit3 or digit4 or digit5 or digit6 or digit7) begin
        case(whichdigit)
            0: curr_digit = digit0;
            1: curr_digit = digit1;
            2: curr_digit = digit2;
            3: curr_digit = digit3;
            4: curr_digit = digit4;
            5: curr_digit = digit5;
            6: curr_digit = digit6;
            7: curr_digit = digit7;
            default: curr_digit = 4'hz;
        endcase
        
    end

    always @ (curr_digit or dot or whichdigit) begin
        C_r = 8'hff;
        case (curr_digit)
            4'h0: begin
                C_r[A] = 0;
                C_r[B] = 0;
                C_r[C] = 0;
                C_r[D] = 0;
                C_r[E] = 0;
                C_r[F] = 0;
                end
            4'h1: begin
                C_r[B] = 0;
                C_r[C] = 0;
                end
            4'h2: begin
                C_r[A] = 0;
                C_r[B] = 0;
                C_r[G] = 0;
                C_r[E] = 0;
                C_r[D] = 0;
                end
            4'h3: begin
                C_r[A] = 0;
                C_r[B] = 0;
                C_r[G] = 0;
                C_r[C] = 0;
                C_r[D] = 0;
                end
            4'h4: begin
                C_r[F] = 0;
                C_r[G] = 0;
                C_r[B] = 0;
                C_r[C] = 0;
                end
            4'h5: begin
                C_r[A] = 0;
                C_r[F] = 0;
                C_r[G] = 0;
                C_r[C] = 0;
                C_r[D] = 0;
                end
            4'h6: begin
                C_r[A] = 0;
                C_r[F] = 0;
                C_r[G] = 0;
                C_r[C] = 0;
                C_r[D] = 0;
                C_r[E] = 0;
                end
            4'h7: begin
                C_r[A] = 0;
                C_r[B] = 0;
                C_r[C] = 0;
                end
            4'h8: begin
                C_r[A] = 0;
                C_r[B] = 0;
                C_r[C] = 0;
                C_r[D] = 0;
                C_r[E] = 0;
                C_r[F] = 0;
                C_r[G] = 0;
                end
            4'h9: begin
                C_r[A] = 0;
                C_r[B] = 0;
                C_r[C] = 0;
                C_r[D] = 0;
                C_r[F] = 0;
                C_r[G] = 0;
                end
            4'hA: begin
                C_r[A] = 0;
                C_r[B] = 0;
                C_r[C] = 0;
                C_r[E] = 0;
                C_r[F] = 0;
                C_r[G] = 0;
                end
            4'hB: begin
                C_r[F] = 0;
                C_r[E] = 0;
                C_r[G] = 0;
                C_r[C] = 0;
                C_r[D] = 0;
                end
            4'hC: begin
                C_r[A] = 0;
                C_r[F] = 0;
                C_r[E] = 0;
                C_r[D] = 0;
                end
            4'hD: begin
                C_r[B] = 0;
                C_r[G] = 0;
                C_r[E] = 0;
                C_r[C] = 0;
                C_r[D] = 0;
                end
            4'hE: begin
                C_r[A] = 0;
                C_r[F] = 0;
                C_r[G] = 0;
                C_r[E] = 0;
                C_r[D] = 0;
                end
            4'hF: begin
                C_r[A] = 0;
                C_r[F] = 0;
                C_r[G] = 0;
                C_r[E] = 0;
                end
            default:
                begin
                end
        endcase
        C_r[P] = ~dot[whichdigit];
    end

    assign AN = ~(8'h1 << whichdigit);

    always @(posedge clk) begin
        whichdigit <= whichdigit + 1;
    end
endmodule

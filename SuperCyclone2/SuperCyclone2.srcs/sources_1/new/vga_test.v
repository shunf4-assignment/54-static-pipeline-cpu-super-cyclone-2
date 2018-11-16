`timescale 1ns / 1ps
`include "sdHeader.vh"

module vga_test(
    input CLK100MHZ,
    input BTNC,

    output [3:0] VGA_R,
    output [3:0] VGA_G,
    output [3:0] VGA_B,
    output VGA_HS,
    output VGA_VS
    
);
    wire clk_vga;
    wire clk_cpu;

    wire [10:0] x;
    wire [9:0] y;

    wire [10:0] xNext;
    wire [10:0] yNext;

    wire inplace;

    wire reset_deJittered;

    reg [2:0] reset_deJitter;
    reg [3:0] VGA_R_r;
    reg [3:0] VGA_G_r;
    reg [3:0] VGA_B_r;
    
    wire clkLocked;
    
    clk_generator clkgen_inst(
        .clk_100MHz(CLK100MHZ),
        .clk_vga(clk_vga),
        .clk_cpu(clk_cpu),
        .reset(reset_deJittered),
        .locked(clkLocked)
    );
    
    always @(posedge CLK100MHZ)
    begin
        reset_deJitter <= {reset_deJitter[1:0], BTNC};
    end

    assign reset_deJittered = (reset_deJitter == 3'b111);

    vga vga_inst
    (
        .clk(clk_vga),
        .rst(reset_deJittered),
        
        .hsync(VGA_HS),
        .vsync(VGA_VS),
        .x(x),
        .y(y),
        .xNext(xNext),
        .yNext(yNext),
        .inplace(inplace)
    );

    wire [15:0] xNext_ext = {5'h00, xNext};
    wire [15:0] yNext_ext = {6'h00, yNext};

    always @(posedge clk_vga)
    begin
        VGA_B_r <= (xNext_ext << 4) / 1024;
        VGA_R_r <= (yNext_ext << 4) / 576;
        VGA_G_r <= (yNext_ext << 4) / 576;
    end
    
    assign VGA_R = inplace ? VGA_R_r : 4'hz;
    assign VGA_G = inplace ? VGA_G_r : 4'hz;
    assign VGA_B = inplace ? VGA_B_r : 4'hz;

endmodule
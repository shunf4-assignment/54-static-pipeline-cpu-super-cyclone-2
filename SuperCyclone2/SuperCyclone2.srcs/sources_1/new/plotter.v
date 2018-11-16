`timescale 1ns/1ns
`include "sdHeader.vh"

module plotter(
    input clk,
    input reset,
    output [15:0] backgroundMemAddrb,
    input [11:0] backgroundMemDoutb,
    output [17:0] canvasMemAddrb,
    input [12:0] canvasMemDoutb,
    output vgaMemWe,
    output [17:0] vgaMemAddr,
    output [11:0] vgaMemDina
);

    reg [31:0] pixelCounter;
    reg [5:0] frameCounter;
    localparam pixelNum = 512 * 288;
    localparam framePeriod = 20;

    always @(posedge clk)
    begin
        if(reset) begin
            pixelCounter <= 0;
            frameCounter <= 0;
        end else begin
            if (pixelCounter <= pixelNum - 1) begin
                pixelCounter <= pixelCounter + 1;
            end else begin
                pixelCounter <= 0;
                if (frameCounter <= framePeriod - 1) begin
                    frameCounter <= frameCounter + 1;
                end else begin
                    frameCounter <= 0;
                end
            end
        end
    end

    assign vgaMemWe = (frameCounter == framePeriod - 1) && (pixelCounter != 0);
    assign vgaMemAddr = pixelCounter - 1;
    assign vgaMemDina = (canvasMemDoutb == 13'h0000) ? (backgroundMemDoutb) : (canvasMemDoutb[11:0]);

    assign backgroundMemAddrb = {pixelCounter[17:10], pixelCounter[8:1]};
    assign canvasMemAddrb = pixelCounter;

endmodule

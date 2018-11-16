`timescale 1ns / 1ps

module regfile #(
    parameter num = 32,
    parameter width = 32,
    parameter numlog = 5
)(
    input clk,
    input rst,
    input we,
    input cpuPaused,
    input [numlog-1:0] raddr1,
    input [numlog-1:0] raddr2,
    input [numlog-1:0] debugRFAddr,
    input [numlog-1:0] waddr,
    output [width-1:0] rdata1,
    output [width-1:0] rdata2,
    output [width-1:0] debugRFData,
    input [width-1:0] wdata
    );

    reg [width - 1:0] array_reg [0:num - 1];

    assign rdata1 = array_reg[raddr1];
    assign rdata2 = array_reg[raddr2];
    assign debugRFData = array_reg[debugRFAddr];

    integer j;
    always @(posedge clk)
    begin
        if(rst) begin
            for(j = 0; j < num; j = j + 1)
            begin : reset_regs
                array_reg[j] <= {(width){1'b0}};
            end
        end else begin
            if (array_reg[0] != 0)
                array_reg[0] <= 0;
            if (~cpuPaused) begin
                if(we) begin
                    if(waddr != 0)  // zero register $zero
                        array_reg[waddr] <= wdata;
                end
            end
        end
    end
endmodule

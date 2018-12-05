`timescale 1ns / 1ns
/// CoProcessor 0 Module
module cp0(
    input clk,
    input rst,
    input cpuPaused,
    input mfc0,
    input mtc0,
    input [31:0] pc,
    output reg [31:0] nextPC,
    input [4:0] addr,
    input [31:0] data,
    input exception,
    input eret,
    input [31:0] cause,
    input intr,
    output reg [31:0] CP0_out,
    output [31:0] status,
    output reg [31:0] epc_out
);
    // can be changed to output
    wire [31:0] cause_reg_debug;
    wire [31:0] status_reg_debug;
    wire [31:0] epc_reg_debug;

    reg [31:0] cause_reg = 0;
    reg [31:0] status_reg = 32'h0000000f;
    reg [31:0] epc_reg = 32'h00400000;

    assign status = status_reg;
    wire [4:0] excCode = cause[6:2];

    assign cause_reg_debug = cause_reg;
    assign status_reg_debug = status_reg;
    assign epc_reg_debug = epc_reg;

    always @(*) begin
        if(mfc0) begin
            if(addr == 12)
                CP0_out = status_reg;
            else if (addr == 13)
                CP0_out = cause_reg;
            else if (addr == 14)
                CP0_out = epc_reg;
            else
                CP0_out = 32'hacacacac;
        end
        else CP0_out = 32'hbcbcbcbc;
    end

    always @(*) begin
        // if(eret) begin
        //     epc_out = epc_reg;
        // end else begin
        //     epc_out = 32'h87878787;
        // end
        epc_out = epc_reg;
    end

    wire interruptEna = status_reg[0];
    wire syscallMask = status_reg[1];
    wire breakMask = status_reg[2];
    wire teqMask = status_reg[3];

    localparam exceptionEntry = 32'h00400004;

    always @(*) begin
        nextPC = pc + 4;

        if(eret) begin
            nextPC = epc_reg;
        end else if (exception && interruptEna) begin
            if((excCode == 'b01000) && syscallMask) begin
                // Syscall
                nextPC = exceptionEntry;
            end else if((excCode == 'b01001) && breakMask) begin
                // Break
                nextPC = exceptionEntry;
            end else if((excCode == 'b01101) && teqMask) begin
                // Teq
                nextPC = exceptionEntry;
            end else if(excCode == 'b00000) begin
                // Outside Interrupt
                nextPC = exceptionEntry;
            end
        end

    end

    always @(posedge clk) begin
        if(rst) begin
            cause_reg <= 0;
            status_reg <= 32'h0000000f;
            epc_reg <= 32'h00400000;
        end else if(cpuPaused) begin
            status_reg <= status_reg;
        end else if(eret) begin
            status_reg <= status_reg >> 5;
        end else if (exception && interruptEna) begin
            if((excCode == 'b01000) && syscallMask) begin
                // Syscall
                cause_reg[6:2] <= excCode;
                status_reg <= status_reg << 5;
                epc_reg <= pc;
            end else if((excCode == 'b01001) && breakMask) begin
                // Break
                cause_reg[6:2] <= excCode;
                status_reg <= status_reg << 5;
                epc_reg <= pc;
            end else if((excCode == 'b01101) && teqMask) begin
                // Teq
                cause_reg[6:2] <= excCode;
                status_reg <= status_reg << 5;
                epc_reg <= pc;
            end else if(excCode == 'b00000) begin
                // Outside Interrupt
                cause_reg[6:2] <= excCode;
                status_reg <= status_reg << 5;
                epc_reg <= pc;
            end
        end else if(mtc0) begin
            if (addr == 12)
                status_reg <= data;
            else if (addr == 13)
                cause_reg <= data;
            else if (addr == 14)
                epc_reg <= data;
        end

    end
endmodule

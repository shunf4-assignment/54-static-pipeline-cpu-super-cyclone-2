`timescale 1ns/1ns
`include "sdHeader.vh"

module debugInfo(
    input CLK100MHZ,
    input clk_cpu,
    input reset,
    input [15:0] SW,
    input [31:0] pc,
    input [31:0] instruction,
    input cpuRunning,
    input cpuPaused,
    input [7:0] blState,
    input [7:0] sdState,
    input blError,
    input sdError,
    input [31:0] debugInfo,
    input debugInfoAvailable,
    input [31:0] debugDMEMData,
    input [31:0] debugIMEMData,
    input [31:0] debugRFData,

    output reg [12:0] debugDMEMAddr,
    output reg [12:0] debugIMEMAddr,
    output [4:0] debugRFAddr,

    output [15:0] LED,
    output reg [31:0] sevenSegOut
);

    wire latch_n = SW[1];

    assign LED[0] = cpuRunning;
    assign LED[1] = cpuPaused;
    assign LED[2] = ~latch_n;
    assign LED[3] = debugInfoAvailable;
    assign LED[4] = reset;
    assign LED[5] = clk_cpu;
    assign LED[15] = blError;
    assign LED[14] = sdError;
    
    //assign debugDMEMAddr = {5'h0, SW[15:8]};
    //assign debugIMEMAddr = {5'h0, SW[15:8]};
    assign debugRFAddr = SW[12:8];

    reg [31:0] instructionHistory [0:7];
    reg [31:0] regHistory [0:7];
    reg [31:0] debugInfoHistory [0:31];

    reg [31:0] blStateHistory;
    reg [31:0] sdStateHistory;
    

    integer i;

    always @(posedge clk_cpu)
    begin
        if (reset) begin
            for (i = 0; i < 8; i=i+1) begin
                instructionHistory[i] <= 0;
                regHistory[i] <= 0;
            end
        end else begin
            if (~latch_n) begin
                if(regHistory[0] != pc) begin
                    for (i = 0; i < 7; i=i+1) begin
                        regHistory[i + 1] <= regHistory[i];
                        instructionHistory[i + 1] <= regHistory[i];
                    end

                    regHistory[0] <= pc;
                    instructionHistory[0] <= instruction;
                end
            end
        end
    end

    always @(posedge clk_cpu)
    begin
        if (reset) begin
            blStateHistory <= 0;
            sdStateHistory <= 0;
            for (i = 0; i < 32; i=i+1) begin
                debugInfoHistory[i] <= 0;
            end
        end else begin
            if (~latch_n) begin
                if (blState != blStateHistory[7:0])
                    blStateHistory <= {blStateHistory[23:0], blState};

                if (sdState != sdStateHistory[7:0])
                    sdStateHistory <= {sdStateHistory[23:0], sdState};

                if(debugInfoAvailable)
                begin
                    for (i = 0; i < 31; i=i+1) begin
                        debugInfoHistory[i + 1] <= debugInfoHistory[i];
                    end
                    debugInfoHistory[0] <= debugInfo;
                end
            end
        end
    end

    always @(*)
    begin
        debugDMEMAddr = {5'h0, SW[15:8]};
        debugIMEMAddr = {5'h0, SW[15:8]};
        case (SW[7:3])
            0:
                sevenSegOut = regHistory[SW[10:8]];
            1:
                sevenSegOut = instructionHistory[SW[10:8]];
            2:
                sevenSegOut = debugDMEMData;
            3:
                sevenSegOut = debugIMEMData;
            4:
                sevenSegOut = debugRFData;
            5:
                sevenSegOut = sdStateHistory;
            6:
                sevenSegOut = blStateHistory;
            7:
                sevenSegOut = debugInfoHistory[SW[12:8]];
            8:
            begin
                debugDMEMAddr = {5'h1, SW[15:8]};
                sevenSegOut = debugDMEMData;
            end

            default:
            begin
                sevenSegOut = 'hFFFFFFFF;
            end
        endcase
    end

endmodule



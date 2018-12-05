`timescale 1ns / 1ps
`include "sdHeader.vh"

module topmodule(
    input CLK100MHZ,

    input [15:0] SW,
    output reg [15:0] LED,
    output [7:0] AN,
    output [7:0] C,

    output SD_SCK,
    output SD_CMD,
    input SD_DAT0,
    output SD_DAT3,
    output SD_RESET,

    input BTNU,
    input BTNC,
    input BTNL,
    input BTND,
    input BTNR,
    input CPU_RESETN,

    output [3:0] VGA_R,
    output [3:0] VGA_G,
    output [3:0] VGA_B,

    output VGA_HS,
    output wire VGA_VS
);

    wire clk_cpu;
    wire btnu_deJittered;
    wire btnc_deJittered;
    wire btnl_deJittered;
    wire btnd_deJittered;
    wire btnr_deJittered;
    wire cpuresetn_deJittered;

    reg [2:0] btnu_deJitter;
    reg [2:0] btnc_deJitter;
    reg [2:0] btnl_deJitter;
    reg [2:0] btnd_deJitter;
    reg [2:0] btnr_deJitter;
    reg [2:0] cpuresetn_deJitter;

    wire [31:0] instruction;
    wire [31:0] pc;
    wire [31:0] addr;
    wire [7:0] blState;
    wire [7:0] sdState;
    wire [4:0] spiState;
    wire [31:0] debugInfo;
    wire debugInfoAvailable;

    wire [15:0] LED_debug;
    wire [15:0] LED_main;

    wire cpuRunning;
    wire cpuPaused;
    wire blError;
    wire sdError;

    wire [31:0] debugDMEMData;
    wire [31:0] debugIMEMData;
    wire [31:0] debugRFData;
    wire [31:0] sevenSegOut_main;
    wire [31:0] sevenSegOut_debug;

    wire compStartOk;
    reg debugMode;
    //wire debugMode = SW[0];
    wire reset = cpuresetn_deJittered;

    always @(posedge CLK100MHZ)
    begin
        if (reset) begin
            if (SW[0]) begin
                debugMode <= `Enabled;
            end else begin
                debugMode <= `Disabled;
            end
        end
    end

    always @(posedge CLK100MHZ)
    begin
        btnu_deJitter <= {btnu_deJitter[1:0], BTNU};
        btnc_deJitter <= {btnc_deJitter[1:0], BTNC};
        btnl_deJitter <= {btnl_deJitter[1:0], BTNL};
        btnd_deJitter <= {btnd_deJitter[1:0], BTND};
        btnr_deJitter <= {btnr_deJitter[1:0], BTNR};
        cpuresetn_deJitter <= {cpuresetn_deJitter[1:0], ~CPU_RESETN};
    end

    assign btnu_deJittered = (btnu_deJitter == 3'b111);
    assign btnc_deJittered = (btnc_deJitter == 3'b111);
    assign btnl_deJittered = (btnl_deJitter == 3'b111);
    assign btnd_deJittered = (btnd_deJitter == 3'b111);
    assign btnr_deJittered = (btnr_deJitter == 3'b111);
    assign cpuresetn_deJittered = (cpuresetn_deJitter == 3'b111);

    assign LED_main[0] = cpuRunning;
    assign LED_main[1] = cpuPaused;
    assign LED_main[15] = blError;
    assign LED_main[14] = sdError;

    reg [31:0] sevenSegOut;

    always @(*)
    begin
        if(debugMode) begin
            sevenSegOut = sevenSegOut_debug;
            LED = LED_debug;
        end else begin
            sevenSegOut = sevenSegOut_main;
            LED = LED_main;
        end
    end

    wire [12:0] debugDMEMAddr;
    wire [12:0] debugIMEMAddr;
    wire [4:0] debugRFAddr;

    debugInfo debugInfo_inst(
        .CLK100MHZ(CLK100MHZ),
        .clk_cpu(clk_cpu),
        .reset(reset),
        
        .SW(SW),

        .pc(pc),
        .instruction(instruction),
        .cpuRunning(cpuRunning),
        .cpuPaused(cpuPaused),
        .blState(blState),
        .sdState(sdState),
        .blError(blError),
        .sdError(sdError),
        .debugInfo(debugInfo),
        .debugInfoAvailable(debugInfoAvailable),

        .debugDMEMData(debugDMEMData),
        .debugIMEMData(debugIMEMData),
        .debugRFData(debugRFData),

        .debugDMEMAddr(debugDMEMAddr),
        .debugIMEMAddr(debugIMEMAddr),
        .debugRFAddr(debugRFAddr),

        .LED(LED_debug),
        .sevenSegOut(sevenSegOut_debug)
    );


    computer computer_uut(
        .clk_in(CLK100MHZ),
        .reset(reset),
        .compStartEn(btnc_deJittered),
        .compStartOk(compStartOk),

        .btnu(~(debugMode | ~compStartOk) & btnu_deJittered),
        .btnc(~(debugMode | ~compStartOk) & btnc_deJittered),
        .btnd(~(debugMode | ~compStartOk) & btnd_deJittered),
        .btnl(~(debugMode | ~compStartOk) & btnl_deJittered),
        .btnr(~(debugMode | ~compStartOk) & btnr_deJittered),

        .btnu_orig(btnu_deJittered),
        .btnc_orig(btnc_deJittered),
        .btnd_orig(btnd_deJittered),
        .btnl_orig(btnl_deJittered),
        .btnr_orig(btnr_deJittered),

        .SW(SW),

        .debugDMEMAddr(debugDMEMAddr),
        .debugIMEMAddr(debugDMEMAddr),
        .debugRFAddr(debugRFAddr),

        .clk_cpu(clk_cpu),
        .pc(pc),
        .inst(instruction),
        .addr(addr),
        .blState(blState),
        .sdState(sdState),
        .spiState(spiState),
        .debugInfo(debugInfo),
        .debugInfoAvailable(debugInfoAvailable),

        .cpuRunning(cpuRunning),
        .cpuPaused(cpuPaused),
        .sdError(sdError),
        .blError(blError),

        .debugDMEMData(debugDMEMData),
        .debugIMEMData(debugIMEMData),
        .debugRFData(debugRFData),

        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_VS(VGA_VS),
        .VGA_HS(VGA_HS),

        .SPI_CLK(SD_SCK),
        .SPI_MOSI(SD_CMD),
        .SPI_MISO(SD_DAT0),
        .SPI_CSn(SD_DAT3),
        .SD_RESET(SD_RESET),

        .sevenSegOut(sevenSegOut_main)
    );

    
    
    display_7seg disp7seg(
        .clk_100MHz(CLK100MHZ),
        .digit_ena(`Enabled),
        .digit7(
            sevenSegOut[31:28]
        ),
        .digit6(
            sevenSegOut[27:24]
        ),
        .digit5(
            sevenSegOut[23:20]
        ),
        .digit4(
            sevenSegOut[19:16]
        ),
        .digit3(
            sevenSegOut[15:12]
        ),
        .digit2(
            sevenSegOut[11:8]
        ),
        .digit1(
            sevenSegOut[7:4]
        ),
        .digit0(
            sevenSegOut[3:0]
        ),
        .dot(8'b00000001),
        .led_control({64{1'b0}}),
        .AN(AN),
        .C_wire(C)
    );

endmodule


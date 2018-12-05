`timescale 1ns/1ns
`include "sdHeader.vh"

`define IMEM_ADDRBITS 10
`define DMEM_ADDRBITS 10
`define IMEM_ADDRSLICE (`IMEM_ADDRBITS + 2 - 1):2
`define DMEM_ADDRSLICE (`DMEM_ADDRBITS + 2 - 1):2
`define IMEM_ADDRSLICE_NOOFFSET (`IMEM_ADDRBITS - 1):0
`define DMEM_ADDRSLICE_NOOFFSET (`DMEM_ADDRBITS - 1):0


module computer(
    input clk_in,
    input reset,
    input compStartEn,
    output reg compStartOk,

    input btnu,
    input btnc,
    input btnd,
    input btnl,
    input btnr,
    input btnu_orig,
    input btnc_orig,
    input btnd_orig,
    input btnl_orig,
    input btnr_orig,

    input [15:0] SW,

    input [12:0] debugDMEMAddr,
    input [12:0] debugIMEMAddr,
    input [4:0] debugRFAddr,

    output clk_cpu,
    output [31:0] inst,
    output [31:0] pc,
    output [31:0] addr,
    output [7:0] blState,
    output [7:0] sdState,
    output [4:0] spiState,
    output [31:0] debugInfo,
    output debugInfoAvailable,

    output cpuRunning,
    output cpuPaused,
    output sdError,
    output blError,
    output [31:0] debugDMEMData,
    output [31:0] debugIMEMData,
    output [31:0] debugRFData,
    output [3:0] VGA_R,
    output [3:0] VGA_G,
    output [3:0] VGA_B,
    output VGA_HS,
    output VGA_VS,

    output SPI_CLK,
    output SPI_MOSI,
    input SPI_MISO,
    output SPI_CSn,
    output SD_RESET,

    output [31:0] sevenSegOut
);

    wire clk_vga;
    wire clk_cpu_orig;
    //assign clk_cpu = SW[2] ? btnd_orig : clk_cpu_orig;
    assign clk_cpu = clk_cpu_orig;

    wire debugInfoAvailable_bl;
    wire debugInfoAvailable_sd;

    wire [31:0] debugInfo_bl;
    wire [63:0] debugInfo_sd;

    assign debugInfoAvailable = debugInfoAvailable_sd | debugInfoAvailable_bl;
    assign debugInfo = debugInfoAvailable_sd ? debugInfo_sd[31:0] : debugInfoAvailable_bl ? debugInfo_bl : 32'hFFFFFFFF;

    //////////////////
    /// Clock generator
    
    clk_generator clkgen_inst(
        .clk_100MHz(clk_in),
        .clk_vga(clk_vga),
        .clk_cpu(clk_cpu_orig)
    );

    //////////////////
    /// VGA

    wire [10:0] x;
    wire [9:0] y;

    wire [10:0] xNext;
    wire [9:0] yNext;

    wire [17:0] vgaMemXYAddr = {yNext[9:1], xNext[9:1]};

    wire inplace;

    reg [3:0] VGA_R_r;
    reg [3:0] VGA_G_r;
    reg [3:0] VGA_B_r;

    wire [11:0] vgaMemWord;

    wire vgaMemWe;
    wire [17:0] vgaMemAddr;
    wire [11:0] vgaMemDina;
    
    vga vga_inst
    (
        .clk(clk_vga),
        .rst(reset),
        .hsync(VGA_HS),
        .vsync(VGA_VS),
        .x(x),
        .y(y),
        .xNext(xNext),
        .yNext(yNext),
        .inplace(inplace)
    );

    assign vgaMemWord = 0;

/*
    vga_mem vga_mem_inst (
        .clka(clk_cpu),    // input wire clka
        .wea(vgaMemWe),      // input wire [0 : 0] wea
        .addra(vgaMemAddr),  // input wire [17 : 0] addra
        .dina(vgaMemDina),    // input wire [11 : 0] dina
        .clkb(clk_vga),    // input wire clkb
        .addrb(vgaMemXYAddr),  // input wire [17 : 0] addrb
        .doutb(vgaMemWord)  // output wire [11 : 0] doutb
    );
*/

    wire backgroundMemWea;
    wire [15:0] backgroundMemAddra;
    wire [11:0] backgroundMemDina;
    wire [15:0] backgroundMemAddrb;
    wire [11:0] backgroundMemDoutb;

    assign backgroundMemDoutb = 0;

/*
    background_mem background_mem_inst (
        .clka(clk_cpu),    // input wire clka
        .wea(backgroundMemWea),      // input wire [0 : 0] wea
        .addra(backgroundMemAddra),  // input wire [15 : 0] addra
        .dina(backgroundMemDina),    // input wire [11 : 0] dina
        .clkb(clk_cpu),    // input wire clkb
        .addrb(backgroundMemAddrb),  // input wire [15 : 0] addrb
        .doutb(backgroundMemDoutb)  // output wire [11 : 0] doutb
    );
*/
    wire canvasMemWea;
    wire [17:0] canvasMemAddra;
    wire [12:0] canvasMemDina;
    wire [17:0] canvasMemAddrb;
    wire [12:0] canvasMemDoutb;

    assign canvasMemDoutb = 0;

/*
    canvas_mem canvas_mem_inst (
        .clka(clk_cpu),    // input wire clka
        .wea(canvasMemWea),      // input wire [0 : 0] wea
        .addra(canvasMemAddra),  // input wire [17 : 0] addra
        .dina(canvasMemDina),    // input wire [12 : 0] dina
        .clkb(clk_cpu),    // input wire clkb
        .addrb(canvasMemAddrb),  // input wire [17 : 0] addrb
        .doutb(canvasMemDoutb)  // output wire [12 : 0] doutb
    );

    plotter plotter_inst(
        .clk(clk_cpu),
        .reset(reset),
        .backgroundMemAddrb(backgroundMemAddrb),
        .backgroundMemDoutb(backgroundMemDoutb),
        .canvasMemAddrb(canvasMemAddrb),
        .canvasMemDoutb(canvasMemDoutb),
        .vgaMemWe(vgaMemWe),
        .vgaMemAddr(vgaMemAddr),
        .vgaMemDina(vgaMemDina)
    );
*/
    always @(*)
    begin
        VGA_R_r = vgaMemWord[11:8];
        VGA_G_r = vgaMemWord[7:4];
        VGA_B_r = vgaMemWord[3:0];
    end
    
    assign VGA_R = inplace ? VGA_R_r : 4'hz;
    assign VGA_G = inplace ? VGA_G_r : 4'hz;
    assign VGA_B = inplace ? VGA_B_r : 4'hz;


    ////////////////
    /// DMEM
    /// Port A: Work at falling edge of clk.
    /// Port B: Work at rising edge of clk.
    wire knWorking;
    wire knInitOk;

    wire dmemAEn_kn;
    wire [3:0] dmemAWe_kn;
    wire [31:0] dmemAAddr_kn;
    wire [31:0] dmemAIn_kn;

    wire dmemAEn_cpu;
    wire dmemAEn_bl;
    wire dmemAEn = dmemAEn_cpu | dmemAEn_bl | dmemAEn_kn;
    
    wire [3:0] dmemAWe_cpu;
    wire [3:0] dmemAWe_bl;
    wire [3:0] dmemAWe = dmemAEn_bl ? dmemAWe_bl : knWorking ? dmemAWe_kn : dmemAEn_cpu ? dmemAWe_cpu : 4'h0;
    wire [31:0] dmemAAddr_cpu;
    wire [31:0] dmemAAddr_bl;
    wire [31:0] dmemAAddr = dmemAEn_bl ? dmemAAddr_bl : knWorking ? dmemAAddr_kn : dmemAEn_cpu ? dmemAAddr_cpu : 0;
    wire [31:0] dmemAIn_cpu;
    wire [31:0] dmemAIn_bl;
    wire [31:0] dmemAIn = dmemAEn_bl ? dmemAIn_bl : knWorking ? dmemAIn_kn : dmemAEn_cpu ? dmemAIn_cpu : 0;
    wire [31:0] dmemAOut;

    /////////
    /// DMEM Address Mapper
    wire [31:0] dmemARealAddr = dmemAAddr - 32'h10010000;

    // DMEM
    assign addr = dmemAEn ? dmemAAddr : 32'hFFFFFFFF;

    DMEM dmem (
        .clka(clk_cpu),    // input wire clka
        .ena(dmemAEn),      // input wire ena
        .wea(dmemAWe),      // input wire [3 : 0] wea
        .addra(dmemARealAddr[`DMEM_ADDRSLICE]),
        .dina(dmemAIn),    // input wire [31 : 0] dina
        .douta(dmemAOut),   // output wire [31 : 0] douta
        .clkb(clk_in),
        .web(0),
        .addrb(debugDMEMAddr[`DMEM_ADDRSLICE_NOOFFSET]),
        .dinb('hx),
        .doutb(debugDMEMData)
    );

    //////////////
    /// IMEM
    ///
    wire imemWe_cpu;
    wire imemWe_bl;
    wire imemWe = imemWe_bl | imemWe_cpu;
    wire [31:0] imemRAddr;
    wire [31:0] imemOut;

    wire [31:0] imemWAddr_cpu;
    wire [31:0] imemWAddr_bl;
    wire [31:0] imemWAddr = imemWe_cpu ? imemWAddr_cpu : imemWe_bl ? imemWAddr_bl : 32'hFFFFFFFF;

    wire [31:0] imemWData_cpu;
    wire [31:0] imemWData_bl;
    wire [31:0] imemWData = imemWe_cpu ? imemWData_cpu : imemWe_bl ? imemWData_bl : 32'hFEFEFEFE;

    wire [31:0] imemSelectedAddr = imemWe ? imemWAddr : imemRAddr;
    wire [31:0] imemRealAddr = imemSelectedAddr - 32'h00400000;
    
    IMEM imem (
        .a(imemRealAddr[`IMEM_ADDRSLICE]),
        .d(imemWData),
        .dpra(debugIMEMAddr[`IMEM_ADDRSLICE_NOOFFSET]),
        .clk(clk_cpu),
        .we(imemWe),
        .spo(imemOut),
        .dpo(debugIMEMData)
    );

    //////////////
    /// CPU Instantiation
    reg cpuEna;
    assign pc = imemRAddr;
    assign inst = imemOut;
    wire [7:0] cpuSyscallFuncCode;
    wire [4:0] rfRAddr1_kn;
    wire [31:0] rfRData1;

    Supercyclone sccpu(
        .clk(clk_cpu),
        .reset(reset),
        .ena(cpuEna),
        .dmemAEn(dmemAEn_cpu),
        .dmemAWe(dmemAWe_cpu),
        .dmemAAddr(dmemAAddr_cpu),
        .dmemAIn(dmemAIn_cpu),
        .dmemAOut(dmemAOut),
        .inst(imemOut),
        .cpuRunning(cpuRunning),
        .cpuPaused(cpuPaused),
        .pc(imemRAddr),
        .imemWAddr(imemWAddr_cpu),
        .imemWData(imemWData_cpu),
        .imemWe(imemWe_cpu),
        .debugRFAddr(debugRFAddr),
        .debugRFData(debugRFData),
        .syscallFuncCode(cpuSyscallFuncCode),
        .rfRAddr1_kn(rfRAddr1_kn),
        .rfRData1(rfRData1),
        .knWorking(knWorking)
    );

    `include "sdStates.vh"
    ////////////////
    /// Bootloader and File System Logic
    reg loadInitScriptEn;
    reg blIgnoreInitScript;
    wire loadInitScriptOk;
    wire sdStartEn;
    wire sdReadEn;
    wire [31:0] sdReadAddr;
    wire [31:0] sdReadSectorNum;
    wire sdStartOk;
    wire sdReadOk;
    wire [7:0] sdReadData;
    wire sdReadDataValid;
    wire sdReadDataASectorDone;
    
    wire blLoadExecutableEn;
    wire [87:0] blLoadExecutableName;
    wire [31:0] blLoadExecutableIMEMAddr;
    wire blLoadExecutableOk;

    wire [31:0] blWordLimit;
    wire [31:0] blWordOffset;

    wire blLoadFileEn;
    wire [87:0] blLoadFileName;
    wire [31:0] blLoadFileDMEMAddr;
    wire blLoadFileOk;

    wire blLoadBackgroundFileEn;
    wire blLoadBackgroundFileOk;

    wire blWorking;

    // 文件系统控制器, 兼 Bootloader 功能
    bootloader bootloader_inst(
        .clk(clk_cpu),
        .reset(reset),
        .iloadInitScriptEn(loadInitScriptEn),
        .oOk(loadInitScriptOk),
        .blWorking(blWorking),

        .iIgnoreInitScript(blIgnoreInitScript),

        .sdIdle(sdState == S_SD_IDLE),
        .sdStartEn(sdStartEn),
        .sdReadEn(sdReadEn),
        .sdReadAddr(sdReadAddr),
        .sdReadSectorNum(sdReadSectorNum),
        .sdStartOk(sdStartOk),
        .sdReadOk(sdReadOk),
        .sdReadData(sdReadData),
        .sdReadDataValid(sdReadDataValid),
        .sdReadDataASectorDone(sdReadDataASectorDone),

        .imemWe(imemWe_bl),
        .imemWAddr(imemWAddr_bl),
        .imemWData(imemWData_bl),

        .dmemAWe(dmemAWe_bl),
        .dmemAEn(dmemAEn_bl),
        .dmemAAddr(dmemAAddr_bl),
        .dmemAIn(dmemAIn_bl),

        .iLoadExecutableEn(blLoadExecutableEn),
        .iLoadExecutableName(blLoadExecutableName),
        .iLoadExecutableIMEMAddr(blLoadExecutableIMEMAddr),
        .oLoadExecutableOk(blLoadExecutableOk),

        .iWordLimit(blWordLimit),
        .iWordOffset(blWordOffset),

        .iLoadFileEn(blLoadFileEn),
        .iLoadFileName(blLoadFileName),
        .iLoadFileDMEMAddr(blLoadFileDMEMAddr),
        .oLoadFileOk(blLoadFileOk),

        .iLoadBackgroundFileEn(blLoadBackgroundFileEn),
        .oLoadBackgroundFileOk(blLoadBackgroundFileOk),

        .backgroundMemWea(backgroundMemWea),
        .backgroundMemAddra(backgroundMemAddra),
        .backgroundMemDina(backgroundMemDina),

        .blState(blState),
        .blError(blError),

        .debugInfo(debugInfo_bl),
        .debugInfoAvailable(debugInfoAvailable_bl)
    );

    //////////////////////
    /// Kernel - Handles all syscalls.

    // 处理所有 syscall 指令的硬件核心. 操控图形缓存, 文件系统控制机器, 按键输入等.

    kernel kernel_inst(
        .clk(~clk_cpu),
        .reset(reset),
        .funcCode(cpuSyscallFuncCode),
        .SW(SW),
        .btnu(btnu),
        .btnc(btnc),
        .btnd(btnd),
        .btnl(btnl),
        .btnr(btnr),

        .rfRAddr1(rfRAddr1_kn),
        .rfRData1(rfRData1),

        .working(knWorking),
        .initOk(knInitOk),

        .dmemAOut(dmemAOut),
        .dmemAEn(dmemAEn_kn),
        .dmemAWe(dmemAWe_kn),
        .dmemAAddr(dmemAAddr_kn),
        .dmemAIn(dmemAIn_kn),

        .blLoadExecutableEn(blLoadExecutableEn),
        .blLoadExecutableName(blLoadExecutableName),
        .blLoadExecutableIMEMAddr(blLoadExecutableIMEMAddr),
        .blLoadExecutableOk(blLoadExecutableOk),

        .blLoadFileEn(blLoadFileEn),
        .blLoadFileName(blLoadFileName),
        .blLoadFileDMEMAddr(blLoadFileDMEMAddr),
        .blLoadFileOk(blLoadFileOk),

        .blWordLimit(blWordLimit),
        .blWordOffset(blWordOffset),

        .blLoadBackgroundFileEn(blLoadBackgroundFileEn),
        .blLoadBackgroundFileOk(blLoadBackgroundFileOk),

        .canvasMemWea(canvasMemWea),
        .canvasMemAddra(canvasMemAddra),
        .canvasMemDina(canvasMemDina),
        
        .sevenSegOut(sevenSegOut)
    );

    //////////////////////
    /// SD Controller and SPI Controller.
    wire spiEn;
    wire spiClk74En;
    wire spiClk74Ok;
    wire spiTxEn;
    wire spiTxOk;
    wire [7:0] spiTxData;
    wire spiRxEn;
    wire spiRxOk;
    wire [7:0] spiRxData;
    wire spiClk8En;
    wire spiClk8Ok;

    sd_controller sdcon_inst(
        .clk(clk_cpu),
        .rst(reset),
        .iStartEn(sdStartEn),
        .oStartOk(sdStartOk),
        .iReadEn(sdReadEn),
        .oReadOk(sdReadOk),
        .iReadAddr(sdReadAddr),
        .iReadSectorNum(sdReadSectorNum),
        
        .oReadData(sdReadData),
        .oReadDataValid(sdReadDataValid),
        .oReadDataASectorDone(sdReadDataASectorDone),

        .oSpiEn(spiEn),
        .oSpiClk74En(spiClk74En),
        .iSpiClk74Ok(spiClk74Ok),
        .oSpiTxEn(spiTxEn),
        .iSpiTxOk(spiTxOk),
        .oSpiTxData(spiTxData),
        .oSpiRxEn(spiRxEn),
        .iSpiRxOk(spiRxOk),
        .iSpiRxData(spiRxData),

        .oSpiClk8En(spiClk8En),
        .iSpiClk8Ok(spiClk8Ok),

        .sdState(sdState),
        .error(sdError),
        .oDebugInfo(debugInfo_sd),
        .oDebugInfoAvailable(debugInfoAvailable_sd)
    );

    spi_controller spicon_inst(
        .clk(clk_cpu),
        .rst(reset),
        .en(spiEn),
        .iClk74En(spiClk74En),
        .oClk74Ok(spiClk74Ok),
        .iTxEn(spiTxEn),
        .oTxOk(spiTxOk),
        .iTxData(spiTxData),
        .oRxOk(spiRxOk),
        .iRxEn(spiRxEn),
        .oRxData(spiRxData),
        .oClk8Ok(spiClk8Ok),
        .iClk8En(spiClk8En),
        .SPI_CLK(SPI_CLK),
        .SPI_MOSI(SPI_MOSI),
        .SPI_MISO(SPI_MISO),
        .SPI_CSn(SPI_CSn),
        .SD_RESET(SD_RESET),
        .spiState(spiState),
        .speedChoice(3)
    );

    //////////////
    /// Startup Logic
    always @(posedge clk_in)
    begin
        if(reset) begin
            cpuEna <= `False;
            loadInitScriptEn <= `False;
            compStartOk <= `False;
            // 忽略加载 APOCLYPS.BIN, 直接使用原 IMEM 的内容.
            blIgnoreInitScript <= `True;
        end else begin
            if(loadInitScriptOk) begin
                loadInitScriptEn <= `False;
                // 等 kernel 初始化(清空 canvas) 完成
                if(knInitOk) begin
                    cpuEna <= `True;
                    compStartOk <= `True;
                end
            end else begin
                if(compStartEn) begin
                    loadInitScriptEn <= `True;
                end
            end
        end
    end

endmodule
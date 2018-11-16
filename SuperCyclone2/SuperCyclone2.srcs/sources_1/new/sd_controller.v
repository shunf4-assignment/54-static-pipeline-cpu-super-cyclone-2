`timescale 1ns/1ns

`include "sdHeader.vh"

/* SD 卡控制器。驱动 SPI 控制器控制 SD 卡。*/
module sd_controller(
    input clk,  // 系统时钟，不一定是 SPI 实际操作 SD 卡的控制时钟。主要用于这个控制器的内部状态机。
    input rst,

/* ---- 关于 SD 卡控制器开机 ---- */
    input iStartEn,     // 让 SD 卡控制器开始工作的外部控制信号
    output reg oStartOk,     // 传递给外部，表示开始准备工作完成的控制信号

/* ---- 关于 SD 卡控制器读数据 ---- */
    input iReadEn,      // 让 SD 卡控制器读的外部控制信号
    output reg oReadOk,

    input [31:0] iReadAddr,          // 读的地址
    input [31:0] iReadSectorNum,   // 要读的扇区数

    output reg [7:0] oReadData,
    output reg oReadDataValid,
    output reg oReadDataASectorDone,    // 读完了一个扇区

/* ---- 与 SPI 控制器有关的信号 ---- */
    output reg oSpiEn,
    
    output reg oSpiClk74En,
    input iSpiClk74Ok,

    output reg oSpiTxEn,
    input iSpiTxOk,
    output reg [7:0] oSpiTxData,

    output reg oSpiRxEn,
    input iSpiRxOk,
    input [7:0] iSpiRxData,

    output reg oSpiClk8En,
    input iSpiClk8Ok,

/* ---- 调试信号 ---- */
    output reg cmd0ResetOk,
    output reg cmd1LegacyInitOk,
    output reg cmd8AskVoltageOk,
    output reg cmd55AppCommandOk,
    output reg acmd41InitOk,

    output reg [7:0] sdState,
    output reg error,
    output reg [63:0] oDebugInfo,
    output reg oDebugInfoAvailable,
    
    output reg acmd41InitAbandoned,
    output reg cmd58ReadOcrHaveGot,
    output reg cmd58ReadOcrNotBusy,
    output reg cmd58ReadOcrCCS,     // Card Capacity Status

    output reg [10:0] responseByteCounter,
    output reg responseStart

    
);

    reg [7:0] nextState;
    reg [7:0] nextNextState;
    reg [7:0] nextNextNextState;
    reg [7:0] nextStateIfInvalid;
    reg [7:0] nextStateToRetry;

    reg [63:0] command;
    reg [5:0] commandByteCounter;
    reg [7:0] expectedSpiRxData;
    reg [7:0] invalidSpiRxData;

    reg [9:0] waitSpiRxDataCounter;
    reg [9:0] retryACMD41Counter;

    reg [31:0] iReadSectorNumStored;

    reg startBlockTokenReceived;

    reg [7:0] resetCounter;

    `include "sdStates.vh"

    
    // COMMANDS
    localparam CMD0 = {8'hff, 2'b01, 6'h0, 32'h0, 8'h95}; 
    localparam LEN_CMD0 = 7; 
    localparam CMD1 = {8'hff, 2'b01, 6'h1, 32'h0, 8'hF1}; 
    localparam LEN_CMD1 = 7; 
    localparam CMD6 = {8'hff, 2'b01, 6'h6, 1'b1, 7'h00, 16'h0, 4'h0, 4'h1, 8'hf6};
    localparam LEN_CMD6 = 7;
    localparam CMD8 = {8'hff, 2'b01, 6'h8, 16'h0, 8'h1, 8'hAA, 8'h87};
    localparam LEN_CMD8 = 7;
    localparam CMD55 = {8'hff, 2'b01, 6'd55, 32'h0, 8'h65};
    localparam LEN_CMD55 = 7;
    localparam ACMD41 = {8'hff, 2'b01, 6'd41, 32'h40000000, 8'h41};
    localparam LEN_ACMD41 = 7;
    //localparam ACMD41 = {8'hff, 2'b01, 6'd41, 32'h40000000, 8'h95};
    localparam CMD58 = {8'hff, 2'b01, 6'd58, 32'h0, 8'h58};
    localparam LEN_CMD58 = 7;
    localparam CMD0_R = 8'h01;
    localparam CMD_R_ILLEGAL = 8'h05;
    localparam CMD1_R = 8'h00;
    localparam CMD17_H = 16'hFF51;
    localparam CMD17_T = 8'h17;
    localparam CMD18_H = 16'hFF52;
    localparam CMD18_T = 8'h18;
    localparam CMD12 = {8'hff, 2'b01, 6'd12, 32'h0, 8'hFD};
    localparam LEN_CMD12 = 7;

    localparam RESP_HIGHLEVEL = 8'hff;
    localparam RESP_CMD0 = 8'h01;
    localparam RESP_CMD8 = 8'h01;
    localparam RESP_LOWLEVEL = 8'h00;
    localparam RESP_CMD1 = 8'h00;
    localparam RESP_CMD_ILLEGAL = 8'h05;
    localparam RESP_CMD55 = 8'h01;
    localparam RESP_ACMD41 = 8'h00;
    localparam RESP_ACMD41_INVALID = 8'h01;

    localparam T_DELAYTICKS = 12'd4000;     // 40μs
    localparam T_RESPMAXCNT = 120;
    localparam T_RESPMAXCNT_READ = 4800;

    // 启动延迟
    reg [11:0] startDelayCounter = 0;

    // 主状态机
    always @(posedge clk)
    if(rst || (iStartEn && sdState == S_SD_RESET)) begin
        oStartOk <= `Disabled;
        oReadOk <= `False;
        oReadData <= 'h0;
        oReadDataValid <= `False;
        oReadDataASectorDone <= `False;
        oSpiEn <= `Disabled;
        oSpiClk74En <= `Disabled;
        oSpiTxEn <= `Disabled;
        oSpiTxData <= 'h0;
        oSpiRxEn <= `Disabled;
        oSpiClk8En <= `Disabled;

        cmd0ResetOk <= `False;
        cmd1LegacyInitOk <= `False;
        cmd8AskVoltageOk <= `False;
        cmd55AppCommandOk <= `False;
        acmd41InitOk <= `False;

        sdState <= S_SD_PREDELAY;
        error <= `False;
        oDebugInfo <= 'hABABABABCDCDCDCD;
        oDebugInfoAvailable <= `False;

        acmd41InitAbandoned <= `False;
        cmd58ReadOcrHaveGot <= `False;
        cmd58ReadOcrNotBusy <= `False;
        cmd58ReadOcrCCS <= `False;

        nextState <= S_SD_RESET;
        nextNextState <= S_SD_RESET;
        nextNextNextState <= S_SD_RESET;
        nextStateIfInvalid <= S_SD_RESET;
        nextStateToRetry <= S_SD_RESET;

        command <= 'h0;
        commandByteCounter <= 'h0;
        expectedSpiRxData <= 'h0;
        invalidSpiRxData <= 'h0;
        
        waitSpiRxDataCounter <= 'h0;
        retryACMD41Counter <= 'h0;
        responseByteCounter <= 'h0;
        responseStart <= 'h0;

        iReadSectorNumStored <= 'hEFEFEFEF;
        startBlockTokenReceived <= `False;

        resetCounter <= 0;
    end else begin
        if (oDebugInfoAvailable)
            oDebugInfoAvailable <= `Disabled;

        if (oReadOk)
            oReadOk <= `Disabled;

        if (oReadDataValid)
            oReadDataValid <= `Disabled;

        if (oReadDataASectorDone)
            oReadDataASectorDone <= `Disabled;

        case(sdState)
            S_SD_PREDELAY:
                if (iStartEn) begin
                    sdState <= S_SD_DELAY;
                    startDelayCounter <= 0;
                    oSpiEn <= `Enabled;
                end else begin
                    oSpiEn <= `Disabled;
                end

            S_SD_DELAY:
                if (startDelayCounter == T_DELAYTICKS - 1)
                begin
                    sdState <= S_SD_CLK74;
                end else begin
                    startDelayCounter <= startDelayCounter + 1;
                end

            S_SD_CLK74:
                if (iSpiClk74Ok) begin
                    oSpiClk74En <= `Disabled;
                    sdState <= S_SD_SDRESET_PRE;
                end else begin
                    oSpiClk74En <= `Enabled;
                end
            
            S_SD_SDRESET_PRE:
                begin
                    command <= CMD0;
                    commandByteCounter <= LEN_CMD0;
                    nextState <= S_SD_SDRESET_RESP_PRE;
                    sdState <= S_SD_TXCMD;
                end

            S_SD_SDRESET_RESP_PRE:
                begin
                    if (resetCounter >= 200) begin
                        cmd0ResetOk <= `False;
                        oDebugInfo <= 32'h5DEAA0A1; // SD ERROR!
                        oDebugInfoAvailable <= `Enabled;
                        sdState <= S_SD_ERR;
                    end else begin
                        resetCounter <= resetCounter + 1;
                        cmd0ResetOk <= `False;
                        expectedSpiRxData <= RESP_CMD0;
                        invalidSpiRxData <= RESP_LOWLEVEL;
                        nextState <= S_SD_ASKVOLTAGE_PRE;
                        nextStateIfInvalid <= S_SD_ERR;
                        nextStateToRetry <= S_SD_SDRESET_PRE;   // 
                        sdState <= S_SD_GENERAL_RESP_CHECK;
                    end
                end

            S_SD_ASKVOLTAGE_PRE:
                begin
                    cmd0ResetOk <= `True;
                    command = CMD8;
                    commandByteCounter <= LEN_CMD8;
                    nextState <= S_SD_ASKVOLTAGE_RESP_PRE;
                    sdState <= S_SD_TXCMD;
                end

            S_SD_ASKVOLTAGE_RESP_PRE:
                begin
                    cmd8AskVoltageOk <= `False;
                    responseByteCounter <= 5;
                    responseStart <= `False;
                    waitSpiRxDataCounter <= 0;
                    sdState <= S_SD_ASKVOLTAGE_RESP_CHECK;
                end

            S_SD_ASKVOLTAGE_RESP_CHECK:
                if (iSpiRxOk) begin
                    oSpiRxEn <= `Disabled;
                    if(!responseStart) begin
                        if (iSpiRxData != RESP_HIGHLEVEL) begin
                            responseByteCounter <= responseByteCounter - 1;
                            case (iSpiRxData)
                                RESP_CMD8:
                                begin
                                    nextState <= S_SD_SDINIT_PRE;
                                    responseStart <= `True;
                                end

                                RESP_CMD_ILLEGAL:
                                begin
                                    nextState <= S_SD_ERR;
                                    oDebugInfoAvailable <= `Enabled;
                                    oDebugInfo[7:0] <= iSpiRxData;
                                    oDebugInfo[63:8] <= 56'h58;
                                    sdState <= S_SD_8CLK;
                                end

                                default:
                                begin
                                    nextState <= S_SD_ASKVOLTAGE_PRE;
                                    oDebugInfoAvailable <= `Enabled;
                                    oDebugInfo[7:0] <= iSpiRxData;
                                    oDebugInfo[63:8] <= 56'h68;
                                    sdState <= S_SD_8CLK;
                                end
                            endcase
                        end else if (waitSpiRxDataCounter == T_RESPMAXCNT) begin
                            oDebugInfoAvailable <= `Enabled;
                            oDebugInfo[15:0] <= waitSpiRxDataCounter;
                            oDebugInfo[63:16] <= {32'hCC, 8'hAc, nextState};
                            sdState <= S_SD_ASKVOLTAGE_PRE;
                        end else begin
                            waitSpiRxDataCounter <= waitSpiRxDataCounter + 1;
                        end
                    end else begin
                        responseByteCounter <= responseByteCounter - 1;
                        case (responseByteCounter)
                            1:  // 最后一字节: 检查校验位
                            begin
                                if (iSpiRxData != 8'hAA) begin
                                    oDebugInfoAvailable <= `True;
                                    oDebugInfo <= {56'hFDFD, iSpiRxData};
                                    nextState <= S_SD_ERR;
                                end else begin
                                    if (nextState != S_SD_ERR)
                                        cmd8AskVoltageOk <= `Enabled;
                                end
                                sdState <= S_SD_8CLK;
                            end

                            2: // 倒数第二字节: 检查电压是否正常
                            begin
                                if ((iSpiRxData & 8'h0F) != 8'h01) begin
                                    oDebugInfoAvailable <= `True;
                                    oDebugInfo <= {56'hFDFE, iSpiRxData};
                                    nextState <= S_SD_ERR;
                                end
                            end
                        endcase
                    end
                end else begin
                    oSpiRxEn <= `Enabled;
                end

            S_SD_SDINIT_PRE:
                begin
                // SEND CMD55 (APPCMD)
                    cmd55AppCommandOk <= `False;
                    command <= CMD55;
                    commandByteCounter <= LEN_CMD55;
                    nextState <= S_SD_SDINIT_CMD55_RESP_PRE;
                    sdState <= S_SD_TXCMD;
                end

            S_SD_SDINIT_CMD55_RESP_PRE:
                begin
                    nextState <= S_SD_SDINIT_ACMD41_PRE;
                    nextStateIfInvalid <= S_SD_SDINIT_CMD55_INVALID;
                    nextStateToRetry <= S_SD_SDINIT_PRE;
                    expectedSpiRxData <= RESP_CMD55;
                    invalidSpiRxData <= RESP_CMD_ILLEGAL;
                    sdState <= S_SD_GENERAL_RESP_CHECK;
                end

            S_SD_SDINIT_CMD55_INVALID:
                begin
                    oDebugInfoAvailable <= `True;
                    oDebugInfo <= {56'hED, 8'hCF};
                    sdState <= S_SD_ERR;
                end

            S_SD_SDINIT_ACMD41_PRE:
                begin
                    cmd55AppCommandOk <= `True;
                    retryACMD41Counter <= 0;
                    acmd41InitOk <= `False;
                    acmd41InitAbandoned <= `False;
                    command <= ACMD41;
                    commandByteCounter <= LEN_ACMD41;
                    nextState <= S_SD_SDINIT_ACMD41_RESP_PRE;
                    sdState <= S_SD_TXCMD;
                end
                    
            S_SD_SDINIT_ACMD41_RESP_PRE:
                begin
                    nextState <= S_SD_READOCR_PRE;
                    nextStateIfInvalid <= S_SD_SDINIT_RETRY;
                    nextStateToRetry <= S_SD_SDINIT_PRE;
                    expectedSpiRxData <= RESP_ACMD41;
                    invalidSpiRxData <= RESP_ACMD41_INVALID;
                    sdState <= S_SD_GENERAL_RESP_CHECK;
                end

            S_SD_SDINIT_RETRY:
                begin
                    if(retryACMD41Counter == 1023) begin
                        acmd41InitAbandoned <= `True;
                        sdState <= S_SD_READOCR_PRE;
                        retryACMD41Counter <= 0;
                    end else begin
                        sdState <= S_SD_SDINIT_PRE;
                        retryACMD41Counter <= retryACMD41Counter + 1;
                    end
                end

            S_SD_READOCR_PRE:
                begin
                    acmd41InitOk <= `True;
                    command <= CMD58;
                    commandByteCounter <= LEN_CMD58;
                    nextState <= S_SD_READOCR_RESP_PRE;
                    sdState <= S_SD_TXCMD;
                end

            S_SD_READOCR_RESP_PRE:
                begin
                    cmd58ReadOcrHaveGot <= `False;
                    cmd58ReadOcrCCS <= `False;
                    cmd58ReadOcrNotBusy <= `False;

                    responseByteCounter <= 5;
                    responseStart <= `False;
                    waitSpiRxDataCounter <= 0;
                    sdState <= S_SD_READOCR_RESP_CHECK;
                end

            S_SD_READOCR_RESP_CHECK:
                if (iSpiRxOk) begin
                    oSpiRxEn <= `Disabled;
                    if(!responseStart) begin
                        if (iSpiRxData != RESP_HIGHLEVEL) begin
                            responseByteCounter <= responseByteCounter - 1;
                            if (iSpiRxData == RESP_LOWLEVEL) begin
                                responseStart <= `True;
                            end else begin
                                nextState <= S_SD_ERR;
                                oDebugInfoAvailable <= `Enabled;
                                oDebugInfo[7:0] <= iSpiRxData;
                                oDebugInfo[63:8] <= 56'hAA;
                                sdState <= S_SD_8CLK;
                            end
                        end else if (waitSpiRxDataCounter == T_RESPMAXCNT) begin
                            oDebugInfoAvailable <= `Enabled;
                            oDebugInfo[15:0] <= waitSpiRxDataCounter;
                            oDebugInfo[63:16] <= {32'hCC, 8'hAA, nextState};
                            sdState <= S_SD_READOCR_PRE;
                        end else begin
                            waitSpiRxDataCounter <= waitSpiRxDataCounter + 1;
                        end
                    end else begin
                        responseByteCounter <= responseByteCounter - 1;
                        case (responseByteCounter)
                            1:  // 最后一字节: 检查校验位
                            begin
                                nextState <= nextState;
                                sdState <= S_SD_8CLK;
                            end

                            4: // OCR 第一个字节
                            begin
                                oDebugInfoAvailable <= `True;
                                oDebugInfo <= {56'h0, 3'h0, iSpiRxData[7],3'h0, iSpiRxData[6]};

                                cmd58ReadOcrHaveGot <= `True;
                                cmd58ReadOcrNotBusy <= iSpiRxData[7];
                                cmd58ReadOcrCCS <= iSpiRxData[6];

                                // 我们跳过 CMD6 (查询此卡是否允许提速).
                                nextState <= S_SD_IDLE;
                            end
                        endcase
                    end
                end else begin
                    oSpiRxEn <= `Enabled;
                end

            S_SD_GENERAL_RESP_CHECK:
                begin
                    waitSpiRxDataCounter <= 0;
                    sdState <= S_SD_GENERAL_RESP_CHECK_DO;
                end

            S_SD_GENERAL_RESP_CHECK_DO:
            // 参数: nextState, nextStateIfInvalid, nextStateToRetry
            //      expectedSpiRxData, invalidSpiRxData
                if (iSpiRxOk) begin
                    oSpiRxEn <= `Disabled;
                    if(iSpiRxData != RESP_HIGHLEVEL) begin
                        if(iSpiRxData == expectedSpiRxData) begin
                            nextState <= nextState;
                            sdState <= S_SD_8CLK;
                        end else if (iSpiRxData == invalidSpiRxData) begin
                            nextState <= nextStateIfInvalid;
                            sdState <= S_SD_8CLK;
                        end else begin
                            oDebugInfoAvailable <= `Enabled;
                            oDebugInfo[7:0] <= iSpiRxData;
                            oDebugInfo[63:8] <= {40'h0, 8'hAB, nextState};
                            nextState <= S_SD_ERR;
                            sdState <= S_SD_8CLK;
                        end
                    end else if (waitSpiRxDataCounter == T_RESPMAXCNT) begin
                        // 超时
                        waitSpiRxDataCounter <= 0;
                        oDebugInfoAvailable <= `Enabled;
                        oDebugInfo[7:0] <= iSpiRxData;
                        oDebugInfo[63:8] <= {40'hCC, 8'hAB, nextState};
                        sdState <= nextStateToRetry;
                    end else begin
                        waitSpiRxDataCounter <= waitSpiRxDataCounter + 1;
                    end
                end else begin
                    oSpiRxEn <= `Enabled;
                end

            S_SD_TXCMD:
                begin
                    nextNextState <= nextState;
                    nextState <= S_SD_TXCMD_DO;
                    sdState <= S_SD_8CLK;
                    // 在传输前, 等待8个时钟周期
                end

            S_SD_TXCMD_DO:
                begin
                    if(iSpiTxOk) begin
                        if(commandByteCounter <= 1)begin
                            commandByteCounter <= 0;
                            oSpiTxEn <= `Disabled;
                            sdState <= nextState;
                        end else begin
                            oSpiTxEn <= `Enabled;
                            commandByteCounter <= commandByteCounter - 1;
                        end
                    end else begin
                        nextState <= nextNextState;
                        oSpiTxEn <= `Enabled;
                        oSpiTxData <= command[((commandByteCounter << 3) - 1) -: 8];
                    end
                end

            S_SD_8CLK:
                begin
                    if(iSpiClk8Ok) begin
                        oSpiClk8En <= `Disabled;
                        sdState <= nextState;
                    end else begin
                        oSpiClk8En <= `Enabled;
                    end
                end

            S_SD_ERR:
                begin
                    error <= `True;
                end

            S_SD_IDLE:
                begin
                    if(iReadEn) begin
                        iReadSectorNumStored <= iReadSectorNum;
                        sdState <= S_SD_READ_PRE;
                    end
                    oStartOk <= `True;
                end
            
            S_SD_READ_PRE:
                begin
                    if(iReadSectorNumStored == 0)
                        sdState <= S_SD_IDLE;
                    else if (iReadSectorNumStored == 1) begin
                        command <= {CMD17_H, cmd58ReadOcrCCS ? iReadAddr : (iReadAddr << 9), CMD17_T};
                    end else begin
                        command <= {CMD18_H, cmd58ReadOcrCCS ? iReadAddr : (iReadAddr << 9), CMD18_T};
                    end

                    commandByteCounter <= 7;
                    nextState <= S_SD_READ;
                    sdState <= S_SD_TXCMD;
                    startBlockTokenReceived <= `False;
                end

            S_SD_READ:
                begin
                    responseByteCounter <= 512 + 2; // CRC 校验码 2 字节
                    responseStart <= 0;
                    waitSpiRxDataCounter <= 0;
                    sdState <= S_SD_READ_DO;
                    
                end

            S_SD_READ_DO:
                if(iSpiRxOk) begin
                    oSpiRxEn <= `False;
                    if (!responseStart) begin
                        if (iSpiRxData != RESP_HIGHLEVEL) begin
                            if (iSpiRxData == 8'hFE) begin
                                if(startBlockTokenReceived)
                                    responseStart <= `True;
                                else begin
                                    oDebugInfoAvailable <= `Enabled;
                                    oDebugInfo[7:0] <= iSpiRxData;
                                    oDebugInfo[63:8] <= {40'h0,8'hED,8'h17};
                                    nextState <= S_SD_ERR;
                                    sdState <= S_SD_8CLK;
                                end
                            end else if (iSpiRxData == 8'h00) begin
                                startBlockTokenReceived <= `True;
                            end else begin
                                oDebugInfoAvailable <= `Enabled;
                                oDebugInfo[7:0] <= iSpiRxData;
                                oDebugInfo[63:8] <= {40'h0,8'hEC,8'h17};
                                nextState <= S_SD_ERR;
                                sdState <= S_SD_8CLK;
                            end
                        end else if (waitSpiRxDataCounter == T_RESPMAXCNT_READ) begin
                            oDebugInfoAvailable <= `Enabled;
                            oDebugInfo[7:0] <= iSpiRxData;
                            oDebugInfo[63:8] <= {48'hAA, 8'hEE};
                            nextState <= S_SD_ERR;
                            sdState <= S_SD_8CLK;
                        end else begin
                            waitSpiRxDataCounter <= waitSpiRxDataCounter + 1;
                        end
                    end else begin
                        responseByteCounter <= responseByteCounter - 1;
                        if(responseByteCounter > 2) begin // 非 CRC 字节
                            oReadData <= iSpiRxData;
                            oReadDataValid <= `Enabled;
                        end else if (responseByteCounter == 1) begin    // 读取完成
                            responseStart <= `False;
                            
                            oReadDataASectorDone <= `True;
                            
                            if (command[7:0] == CMD18_T)
                            begin
                                // 多扇区
                                if (iReadSectorNumStored == 1) begin
                                    // 读完
                                    nextState <= S_SD_MULTIREADDONE_PRE;
                                    sdState <= S_SD_8CLK;
                                end else begin
                                    iReadSectorNumStored <= iReadSectorNumStored - 1;
                                    sdState <= S_SD_READ;
                                end
                            end else begin
                                nextState <= S_SD_MULTIREADDONE_POST;
                                sdState <= S_SD_8CLK;
                            end
                        end
                    end
                end else begin
                    oSpiRxEn <= `True;
                end
            
            S_SD_MULTIREADDONE_PRE:
                begin
                    command <= CMD12;
                    commandByteCounter <= LEN_CMD12;
                    nextState <= S_SD_MULTIREADDONE_PAUSE;
                    sdState <= S_SD_TXCMD;
                end

            S_SD_MULTIREADDONE_PAUSE:
                begin
                    nextState <= S_SD_MULTIREADDONE_RESP_PRE;
                    sdState <= S_SD_8CLK;
                end

            S_SD_MULTIREADDONE_RESP_PRE:
                begin
                    waitSpiRxDataCounter <= 0;
                    nextState <= S_SD_MULTIREADDONE_RESP_ZERO;
                    nextStateIfInvalid <= S_SD_MULTIREADDONE_RESP_ZERO;
                    nextStateToRetry <= S_SD_MULTIREADDONE_POST;   //长时间没有回应00，回复FF，也默认成功执行了

                    expectedSpiRxData <= RESP_LOWLEVEL;
                    invalidSpiRxData <= 8'h7F;  //7F 也可接受
                    sdState <= S_SD_GENERAL_RESP_CHECK;
                end

            S_SD_MULTIREADDONE_RESP_ZERO:
                begin
                    if (iSpiRxOk) begin
                        oSpiRxEn <= `Disabled;
                        if (iSpiRxData == RESP_HIGHLEVEL) begin
                            nextState <= S_SD_MULTIREADDONE_POST;
                            sdState <= S_SD_8CLK;
                        end else begin
                            if (waitSpiRxDataCounter == T_RESPMAXCNT) begin
                                oDebugInfoAvailable <= `Enabled;
                                oDebugInfo[7:0] <= iSpiRxData;
                                oDebugInfo[63:8] <= {48'h0, 8'hAC};
                                sdState <= S_SD_ERR;
                            end else begin
                                waitSpiRxDataCounter <= waitSpiRxDataCounter + 1;
                            end
                        end
                    end else begin
                        oSpiRxEn <= `Enabled;
                    end
                end

            S_SD_MULTIREADDONE_POST:
                begin
                    oReadOk <= `Enabled;
                    sdState <= S_SD_MULTIREADDONE_POST_POST;
                end

            S_SD_MULTIREADDONE_POST_POST:
                begin
                    sdState <= S_SD_IDLE;
                end
            
            default:
                sdState <= S_SD_RESET;
        endcase
    end
endmodule
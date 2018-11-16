`timescale 1ns/1ns
`include "sdHeader.vh"
`define Root 2'h0
`define File 2'h1
`define Executable 2'h2
`define Background 2'h3


// 注意: 命名中所有 bl, bootloader 等字样的含义是指本文件系统控制器, 而不是单指其 bootloader 功能
module bootloader(
    input clk,
    input reset,

    input iloadInitScriptEn,
    output reg oOk,
    output reg blWorking,

    input iIgnoreInitScript,

    input sdIdle,
    output reg sdStartEn,
    output reg sdReadEn,
    output reg [31:0] sdReadAddr,
    output reg [31:0] sdReadSectorNum,
    input sdStartOk,
    input sdReadOk,
    input [7:0] sdReadData,
    input sdReadDataValid,
    input sdReadDataASectorDone,

    output reg imemWe,
    output reg [31:0] imemWAddr,
    output reg [31:0] imemWData,

    output reg [3:0] dmemAWe,
    output reg dmemAEn,
    output reg [31:0] dmemAAddr,
    output reg [31:0] dmemAIn,
    

    input iLoadExecutableEn,
    input [87:0] iLoadExecutableName,
    input [31:0] iLoadExecutableIMEMAddr,
    output reg oLoadExecutableOk,

    input [31:0] iWordLimit,
    input [31:0] iWordOffset,

    input iLoadFileEn,
    input [87:0] iLoadFileName,
    input [31:0] iLoadFileDMEMAddr,
    output reg oLoadFileOk,

    input iLoadBackgroundFileEn,
    output reg oLoadBackgroundFileOk,

    output reg backgroundMemWea,
    output reg [15:0] backgroundMemAddra,
    output reg [11:0] backgroundMemDina,

    output reg [7:0] blState,
    output reg blError,
    output reg [31:0] debugInfo,
    output reg debugInfoAvailable
);

    localparam initInstAddr = 32'h00400000;
    localparam initDataAddr = 32'h10010000;
    localparam exceptionEntry = 32'h00400004;

    `include "blStates.vh"

    localparam N_BL_INITSCRIPT = "APOCLYPSBIN";
    
    reg iIgnoreInitScript_effective;
    
    reg tmpError;
    

    reg [10:0] readByteCounter;
    reg [31:0] readSectorCounter;

    reg [23:0] mbrHeader;

    reg [31:0] dbrAddr;

    reg isFdd;

    reg [87:0] loadExecutableName;
    reg [31:0] loadExecutableIMEMAddr;
    reg [87:0] loadFileName;
    reg [31:0] loadFileDMEMAddr;
    reg [31:0] wordLimit;
    reg [31:0] wordOffset;

    reg [1:0] executableOrFile;

    reg rootClusMemWe;
    reg [7:0] rootClusMemDina;
    reg [14:0] rootClusMemAddra;
    wire [7:0] rootClusMemDoutb;
    reg [14:0] rootClusMemAddrb;

    reg [5:0] BPB_SecPerClus_log2;
    reg [15:0] BPB_RsvdSecCnt;
    reg [7:0] BPB_NumFATs;
    reg [31:0] BPB_FATSz32;
    reg [31:0] BPB_RootClusNum;

    reg [31:0] currRootFATSecNum;
    reg [31:0] currFileFATSecNum;
    reg [31:0] currRootClusNum;

    wire [31:0] fatSecNum = dbrAddr + BPB_RsvdSecCnt;
    wire [31:0] firstClusSec = fatSecNum + BPB_NumFATs * BPB_FATSz32;
    wire [5:0] clusSize_log2 = BPB_SecPerClus_log2 + 9;
    wire [5:0] dirItemsPerClus_log2 = clusSize_log2 - 5;

    reg [10:0] dirItemIndex;
    reg [7:0] scanRootState;
    reg [31:0] currFileClusNum;
    reg [31:0] currFileSectorCounter;
    reg [87:0] currFileName;
    reg [31:0] currFileSize;

    reg [1:0] clusNumUse;

    reg [31:0] nextClusNum;

    reg [7:0] nextState;
    reg [7:0] nextNextState;

    reg [31:0] fatClusAddr;

    reg [7:0] rootFATSector [0:511];
    reg [7:0] fileFATSector [0:511];

    reg [31:0] memWord;
    reg [1:0] memByteCount;
    reg [15:0] memWordCount;

    root_cluster root_cluster_inst (
        .clka(clk),
        .wea(rootClusMemWe),
        .addra(rootClusMemAddra),
        .dina(rootClusMemDina),
        .clkb(clk),
        .addrb(rootClusMemAddrb),
        .doutb(rootClusMemDoutb)
    );

    always @(posedge clk)
    begin
        if (debugInfoAvailable)
            debugInfoAvailable <= `False;

        if (rootClusMemWe)
            rootClusMemWe <= `Disabled;

        if (imemWe)
            imemWe <= `Disabled;
        
        if (dmemAEn)
            dmemAEn <= `Disabled;

        if (dmemAWe)
            dmemAWe <= 4'h0;

        if (backgroundMemWea)
            backgroundMemWea <= `Disabled;

        if (oLoadExecutableOk)
            oLoadExecutableOk <= `False;

        if (oLoadFileOk)
            oLoadFileOk <= `False;

        if (oLoadBackgroundFileOk)
            oLoadBackgroundFileOk <= `False;


        if(reset || blState == S_BL_RESET) begin
            blState <= S_BL_INIT;
            sdStartEn <= `Disabled;
            sdReadEn <= `Disabled;
            imemWe <= `Disabled;

            oOk <= `False;
            sdReadAddr <= 0;
            sdReadSectorNum <= 0;
            imemWAddr <= 0;
            imemWData <= 0;
            dmemAWe <= 0;
            dmemAEn <= `Disabled;
            dmemAAddr <= 0;
            dmemAIn <= 0;

            oLoadExecutableOk <= `False;
            oLoadFileOk <= `False;
            oLoadBackgroundFileOk <= `False;
            blError <= `False;

            debugInfoAvailable <= `False;
            tmpError <= `False;

            readByteCounter <= 0;
            readSectorCounter <= 0;

            mbrHeader <= 0;
            dbrAddr <= 0;
            isFdd <= `False;
            loadExecutableName <= 0;
            loadExecutableIMEMAddr <= 0;
            loadFileName <= 0;
            loadFileDMEMAddr <= 0;
            wordLimit <= 0;
            wordOffset <= 0;
            executableOrFile <= 0;

            rootClusMemWe <= `Disabled;
            rootClusMemDina <= 0;
            rootClusMemAddra <= 0;
            rootClusMemAddrb <= 0;

            BPB_SecPerClus_log2 <= 0;
            BPB_RsvdSecCnt <= 0;
            BPB_NumFATs <= 0;
            BPB_FATSz32 <= 0;
            BPB_RootClusNum <= 0;

            currRootFATSecNum <= 0;
            currFileFATSecNum <= 0;
            currRootClusNum <= 0;

            dirItemIndex <= 0;
            scanRootState <= 0;
            currFileClusNum <= 0;
            currFileName <= 0;

            clusNumUse <= 0;
            nextClusNum <= 0;
            nextState <= 0;
            nextNextState <= 0;
            fatClusAddr <= 0;
            memWord <= 0;
            memByteCount <= 0;
            memWordCount <= 0;

            blWorking <= `False;

        end else case(blState)
            S_BL_INIT:
            begin
                if (iloadInitScriptEn) begin
                    blState <= S_BL_SDSTART;
                    blWorking <= `True;
                    iIgnoreInitScript_effective <= iIgnoreInitScript;
                end
            end

            S_BL_SDSTART:
            begin
                if(sdStartOk) begin
                    blState <= S_BL_READSECTOR0_PRE;
                end else begin
                    sdStartEn <= `Enabled;
                end
            end

            S_BL_READSECTOR0_PRE:
            begin
                if (sdStartOk && sdIdle)
                begin
                    readByteCounter <= 0;
                    readSectorCounter <= 0;
                    sdReadSectorNum <= 1;
                    sdReadAddr <= 0;
                    sdReadEn <= `Enabled;
                    blState <= S_BL_READSECTOR0;
                    tmpError <= `False;
                    isFdd <= `False;
                end else if (~sdStartOk)
                    blState <= S_BL_RESET;
            end

            S_BL_READSECTOR0:
            if (sdReadOk) begin
                sdReadEn <= `Disabled;
                
                if (tmpError) begin
                    blState <= S_BL_ERROR;
                end else begin
                    blState <= S_BL_READDBR_PRE;
                end

            end else if (sdReadDataValid) begin
                readByteCounter <= readByteCounter + 1;
                
                if(!tmpError) begin
                    if(readByteCounter < 2) begin
                        mbrHeader[(readByteCounter << 3) +: 8] <= sdReadData;
                    end else if (readByteCounter == 2) begin
                        if(mbrHeader[7:0] == 8'hEB && sdReadData == 8'h90 || mbrHeader[7:0] == 8'hE9) begin
                            isFdd <= `True;
                            dbrAddr <= 0;
                        end
                    end else if (!isFdd && readByteCounter == 'h1C2) begin
                        if (sdReadData == 'h0B || sdReadData == 'h0C)
                        begin
                            // 第一个分区是 FAT32
                            ;
                        end else begin
                            debugInfo <= {24'hC0, sdReadData};
                            debugInfoAvailable <= `True;
                            tmpError <= `True;
                        end
                    end else if (!isFdd && readByteCounter >= 'h1C6 && readByteCounter <= 'h1C9)
                    begin
                        // 分区的 0 扇区位置
                        dbrAddr[((readByteCounter - 'h1C6) << 3 ) +: 8] <= sdReadData;
                    end 
                end
            end else if(sdReadDataASectorDone) begin
                readByteCounter <= 0;
                readSectorCounter <= readSectorCounter + 1;
            end

            S_BL_READDBR_PRE:
                begin
                    readByteCounter <= 0;
                    readSectorCounter <= 0;
                    sdReadSectorNum <= 1;
                    sdReadAddr <= dbrAddr;
                    sdReadEn <= `Enabled;
                    blState <= S_BL_READDBR;
                    tmpError <= `False;
                end

            S_BL_READDBR:
                if (sdReadOk) begin
                    sdReadEn <= `Disabled;
                    if(!tmpError) begin
                        loadExecutableName <= N_BL_INITSCRIPT;
                        loadExecutableIMEMAddr <= initInstAddr;
                        wordLimit <= 8192;
                        wordOffset <= 0;
                        executableOrFile <= `Executable;
                        blState <= S_BL_READROOTCLUS_PRE;
                        debugInfo <= {8'hEC, BPB_FATSz32[23:0]};
                        debugInfoAvailable <= `True;
                    end else begin
                        blState <= S_BL_ERROR;
                    end
                end else if (sdReadDataValid) begin
                    readByteCounter <= readByteCounter + 1;
                    
                    if(!tmpError) begin
                        if(readByteCounter == 13) begin
                            case (sdReadData)
                                1:BPB_SecPerClus_log2 <= 0;
                                2:BPB_SecPerClus_log2 <= 1;
                                4:BPB_SecPerClus_log2 <= 2;
                                8:BPB_SecPerClus_log2 <= 3;
                                16:BPB_SecPerClus_log2 <= 4;
                                32:BPB_SecPerClus_log2 <= 5;
                                64:BPB_SecPerClus_log2 <= 6;
                                default:begin
                                    debugInfo <= {24'hDC, sdReadData};
                                    debugInfoAvailable <= `True;
                                    tmpError <= `True;
                                end
                            endcase
                        end else if (readByteCounter == 14 || readByteCounter == 15) begin
                            BPB_RsvdSecCnt[((readByteCounter - 14) << 3) +: 8] <= sdReadData;
                        end else if (readByteCounter == 16) begin
                            BPB_NumFATs <= sdReadData;
                        end else if (readByteCounter >= 36 && readByteCounter < 40)
                        begin
                            BPB_FATSz32[((readByteCounter - 36) << 3) +: 8] <= sdReadData;
                        end else if (readByteCounter >= 44 && readByteCounter < 48)
                        begin
                            BPB_RootClusNum[((readByteCounter - 44) << 3) +: 8] <= sdReadData;
                        end
                    end
                end else if(sdReadDataASectorDone) begin
                    readByteCounter <= 0;
                    readSectorCounter <= readSectorCounter + 1;
                end

            S_BL_READROOTCLUS_PRE, S_BL_LOAD:
                begin
                    currRootFATSecNum <= 32'hFFFFFFFF;
                    currFileFATSecNum <= 32'hFFFFFFFF;
                    currRootClusNum <= BPB_RootClusNum;
                    debugInfo <= {2'b10, BPB_SecPerClus_log2, BPB_RsvdSecCnt, BPB_NumFATs};
                    debugInfoAvailable <= `True;
                    
                    if (iIgnoreInitScript_effective) begin
                        if(!oOk) begin
                            oOk <= `True;
                        end
                        blState <= S_BL_IDLE;
                    end else begin
                        blState <= S_BL_READROOTCLUS_INVOKE;
                    end
                end
                
            S_BL_READROOTCLUS_INVOKE:
                begin
                    readByteCounter <= 0;
                    readSectorCounter <= 0;
                    tmpError <= `False;
                    sdReadEn <= `True;
                    sdReadSectorNum <= (1 << BPB_SecPerClus_log2);
                    sdReadAddr <= ((currRootClusNum - 2) << BPB_SecPerClus_log2) + firstClusSec;
                    blState <= S_BL_READROOTCLUS;
                end

            S_BL_READROOTCLUS:
                if (sdReadOk) begin
                    rootClusMemWe <= `Disabled;
                    sdReadEn <= `Disabled;
                    rootClusMemAddrb <= 'h10;
                    blState <= S_BL_SCANROOT_PRE;
                end else if (sdReadDataValid) begin
                    readByteCounter <= readByteCounter + 1;
                    
                    rootClusMemWe <= `Enabled;
                    rootClusMemAddra <= (readSectorCounter << 9) | readByteCounter;
                    rootClusMemDina <= sdReadData;
                    if (readSectorCounter <= 1 && readByteCounter < 8) begin
                        debugInfo <= {16'hC7C7, readByteCounter[7:0],sdReadData};
                        debugInfoAvailable <= `True;
                    end
                end else if (sdReadDataASectorDone) begin
                    readByteCounter <= 0;
                    readSectorCounter <= readSectorCounter + 1;
                end

            S_BL_SCANROOT_PRE:
                begin
                    dirItemIndex <= 0;
                    scanRootState <= 0;
                    debugInfo <= {8'hED, sdReadAddr[23:0]};
                    debugInfoAvailable <= `True;

                    blState <= S_BL_SCANROOT_DO;
                end

            S_BL_SCANROOT_INCREMENT:
                begin
                    if (dirItemIndex == (1 << dirItemsPerClus_log2) - 1) begin
                        // 读下一簇
                        blState <= S_BL_GETNEXTROOTCLUS;
                    end else begin
                        dirItemIndex <= dirItemIndex + 1;
                        scanRootState <= 0;
                        blState <= S_BL_SCANROOT_DO;
                    end
                end

            S_BL_SCANROOT_DO:
                begin
                    scanRootState <= scanRootState + 1;
                    case(scanRootState)
                        0:
                        begin
                            rootClusMemAddrb <= (dirItemIndex << 5) + 26;
                            if(dirItemIndex == 0)begin
                                debugInfo <= {24'hE7, rootClusMemDoutb};
                                debugInfoAvailable <= `True;
                            end
                        end

                        1,2,3,4,5:
                        begin
                            if (scanRootState == 2) begin
                                rootClusMemAddrb <= rootClusMemAddrb - 7;
                            end else begin
                                rootClusMemAddrb <= rootClusMemAddrb + 1;
                            end

                            if (scanRootState == 1) begin
                                ;
                            end else begin
                                currFileClusNum[((scanRootState - 2) << 3) +: 8] <= rootClusMemDoutb;
                            end
                        end

                        6:
                        begin
                            if (currFileClusNum == 0) begin
                                scanRootState <= 0;
                                blState <= S_BL_SCANROOT_INCREMENT;
                            end else begin
                                rootClusMemAddrb <= (dirItemIndex << 5) + 0;
                            end
                        end

                        7,8,9,10,11,12,13,14,15,16,17,18:
                        begin
                            rootClusMemAddrb <= rootClusMemAddrb + 1;
                            if(scanRootState == 7) begin
                                ;
                            end else begin
                                // Big Endian
                                // Upper Case
                                currFileName[((18 - scanRootState) << 3) +: 8] <= ((rootClusMemDoutb >= 'h61 && rootClusMemDoutb <= 'h7a) ? (rootClusMemDoutb - 'h20) : rootClusMemDoutb);
                            end
                        end
                        
                        19:
                        begin
                            if (currFileName == ((executableOrFile == `Executable) ? loadExecutableName : loadFileName)) begin
                                debugInfo <= currFileName[31:0];
                                debugInfoAvailable <= `True;
                                rootClusMemAddrb <= (dirItemIndex << 5) + 11;
                            end else begin
                                debugInfo <= currFileName[31:0];
                                debugInfoAvailable <= `True;
                                blState <= S_BL_SCANROOT_INCREMENT;
                            end
                        end
                        
                        20:
                        ;

                        21:
                        begin
                            if((rootClusMemDoutb & 8'h0F) == 8'h0F) begin
                                debugInfo <= {{3{8'hA2}}, rootClusMemDoutb};
                                debugInfoAvailable <= `True;
                                blState <= S_BL_SCANROOT_INCREMENT;
                            end else begin
                                rootClusMemAddrb <= (dirItemIndex << 5) + 28;
                            end
                        end

                        22:
                        rootClusMemAddrb <= rootClusMemAddrb + 1;

                        23,24,25,26:
                        begin
                            rootClusMemAddrb <= rootClusMemAddrb + 1; 
                            currFileSize[((scanRootState - 23) << 3) +: 8] <= rootClusMemDoutb;
                        end

                        27:
                        if (currFileSize == 0) begin
                            debugInfo <= currFileSize;
                            debugInfoAvailable <= `True;
                            blState <= S_BL_SCANROOT_INCREMENT;
                        end else begin
                            if (executableOrFile == `Executable) begin
                                ;
                            end else if (executableOrFile == `File) begin
                                dmemAEn <= `Enabled;
                                dmemAWe <= (loadFileDMEMAddr != 32'h10010000) ? (4'hf) : (4'h0);
                                dmemAAddr <= loadFileDMEMAddr - 1;
                                dmemAIn <= currFileSize;
                            end
                            blState <= S_BL_READFILECLUS_PRE_JUMPCLUS;
                        end
                    endcase
                end

            S_BL_GETNEXTROOTCLUS:
                begin
                    nextState <= S_BL_GETNEXTROOTCLUS_POST;
                    clusNumUse <= `Root;
                    blState <= S_BL_GETNEXTCLUSNUM;
                end

            S_BL_GETNEXTROOTCLUS_POST:
                begin
                    //debugInfo <= {8'hB9, nextClusNum[23:0]};
                    //debugInfoAvailable <= `True;

                    if (nextClusNum[30:0] != 31'hfffffff) begin
                        currRootClusNum <= nextClusNum;
                        blState <= S_BL_READROOTCLUS_INVOKE;
                    end else begin
                        debugInfo <= {8'hBA, nextClusNum[23:0]};
                        debugInfoAvailable <= `True;
                        blState <= S_BL_ERROR;
                    end
                end

            S_BL_GETNEXTCLUSNUM:
                begin
                    nextNextState <= nextState;
                    if( (clusNumUse == `Root && ((currRootClusNum << 2) >> 9) + fatSecNum == currRootFATSecNum ) || (clusNumUse == `File && ((currFileClusNum << 2) >> 9) + fatSecNum == currFileFATSecNum )) begin
                        // 不需要读 FAT 表，之前已经读入过
                        blState <= S_BL_GETNEXTCLUSNUM_POST;
                    end else begin
                        fatClusAddr <= (clusNumUse == `Root) ? (((currRootClusNum << 2) >> 9) + fatSecNum) : ((currFileClusNum << 2) >> 9) + fatSecNum;
                        nextState <= S_BL_GETNEXTCLUSNUM_POST;
                        blState <= S_BL_READFATSEC_PRE;
                    end
                end

            S_BL_GETNEXTCLUSNUM_POST:
                begin
                    //debugInfo <= {8'hB5, fatClusAddr[23:0]};
                    //debugInfoAvailable <= `True;
                    
                    if(clusNumUse == `File) begin
                        nextClusNum <= {fileFATSector[((currFileClusNum << 2) & 9'b111111111) + 3], fileFATSector[((currFileClusNum << 2) & 9'b111111111) + 2], fileFATSector[((currFileClusNum << 2) & 9'b111111111) + 1], fileFATSector[(currFileClusNum << 2) & 9'b111111111]};
                        currFileFATSecNum <= fatClusAddr;
                    end else begin
                        nextClusNum <= {rootFATSector[((currRootClusNum << 2) & 9'b111111111) + 3], rootFATSector[((currRootClusNum << 2) & 9'b111111111) + 2], rootFATSector[((currRootClusNum << 2) & 9'b111111111) + 1], rootFATSector[(currRootClusNum << 2) & 9'b111111111]};
                        currRootFATSecNum <= fatClusAddr;
                    end

                    blState <= nextNextState;
                end

            S_BL_READFATSEC_PRE:
                begin
                    sdReadEn <= `Enabled;
                    readByteCounter <= 0;
                    readSectorCounter <= 0;
                    sdReadSectorNum <= 1;
                    sdReadAddr <= fatClusAddr;
                    blState <= S_BL_READFATSEC;
                end

            S_BL_READFATSEC:
                if(sdReadOk) begin
                    blState <= nextState;
                    sdReadEn <= `Disabled;
                end else if (sdReadDataValid) begin
                    readByteCounter <= readByteCounter + 1;
                    

                    if (clusNumUse == `File)
                        fileFATSector[readByteCounter] <= sdReadData;
                    else
                        rootFATSector[readByteCounter] <= sdReadData;
                end else if (sdReadDataASectorDone) begin
                    readByteCounter <= 0;
                    readSectorCounter <= readSectorCounter + 1;
                end

            S_BL_READFILECLUS_PRE_JUMPCLUS:
                begin
                    readSectorCounter <= 0;
                    currFileSectorCounter <= 0;
                    memWordCount <= 0;
                    blState <= S_BL_READFILECLUS_PRE_JUMPCLUS_CHECK;
                end

            S_BL_READFILECLUS_PRE_JUMPCLUS_CHECK:
                begin
                    if (((wordOffset >> 7) >> BPB_SecPerClus_log2) != (currFileSectorCounter >> BPB_SecPerClus_log2)) begin
                        nextState <= S_BL_READFILECLUS_PRE_JUMPCLUS_POST;
                        clusNumUse <= `File;
                        blState <= S_BL_GETNEXTCLUSNUM;
                    end else begin
                        blState <= S_BL_READFILECLUS_PRE;
                    end
                end

            S_BL_READFILECLUS_PRE_JUMPCLUS_POST:
                if (nextClusNum[30:0] != 31'hfffffff) begin
                    debugInfo <= {8'h6E, currFileSectorCounter[23:0]};
                    debugInfoAvailable <= `True;

                    currFileClusNum <= nextClusNum;
                    currFileSectorCounter <= currFileSectorCounter + (1 << BPB_SecPerClus_log2);

                    blState <= S_BL_READFILECLUS_PRE_JUMPCLUS_CHECK;
                end else begin
                    debugInfo <= {8'h6D, currFileSectorCounter[23:0]};
                    debugInfoAvailable <= `True;
                    blState <= S_BL_ERROR;
                end

            // currFileSectorCounter: 备份 readSectorCounter
            S_BL_READFILECLUS_PRE:
                begin
                    sdReadEn <= `Enabled;
                    readByteCounter <= 0;
                    readSectorCounter <= currFileSectorCounter;
                    sdReadSectorNum <= (1 << BPB_SecPerClus_log2);
                    sdReadAddr <= ((currFileClusNum - 2) << BPB_SecPerClus_log2) + firstClusSec;
                    memWord <= 0;
                    memByteCount <= 0;
                    blState <= S_BL_READFILECLUS;
                end

            S_BL_READFILECLUS:
                if(sdReadOk) begin
                    sdReadEn <= `Disabled;
                    blState <= S_BL_READFILECLUS_CHECKNEXTCLUS;
                    debugInfo <= {8'hB6, sdReadAddr[23:0]};
                    debugInfoAvailable <= `True;
                end else if (sdReadDataValid) begin
                    readByteCounter <= readByteCounter + 1;
                    memByteCount <= memByteCount + 1;

                    memWord[{memByteCount, 3'h0} +: 8] <= sdReadData;

                    if (readSectorCounter <= 1 && readByteCounter > 0 && readByteCounter < 14 && memByteCount == 0) begin
                        debugInfo <= {8'hB7, imemWAddr[23:0]};
                        debugInfoAvailable <= `True;
                    end

                    if (memByteCount == 3)
                    begin
                        if (readSectorCounter <= 1 && readByteCounter < 14) begin
                            debugInfo <= {8'hB5, memWord[23:0]};
                            debugInfoAvailable <= `True;
                        end
                        
                        if (memWordCount < wordLimit && (((readSectorCounter << 9) | readByteCounter) >> 2) <= ((currFileSize - 1) >> 2) && (((readSectorCounter << 9) | readByteCounter) >> 2) >= wordOffset)
                        begin
                            memWordCount <= memWordCount + 1;
                            if (executableOrFile == `Executable) begin
                                imemWe <= `Enabled;
                                imemWAddr <= loadExecutableIMEMAddr + (((readSectorCounter << 9) | readByteCounter)) - (wordOffset << 2) - 3;
                                imemWData <= {sdReadData, memWord[23:0]};
                            end else if (executableOrFile == `File) begin
                                dmemAEn <= `Enabled;
                                dmemAWe <= 4'hf;
                                dmemAAddr <= loadFileDMEMAddr + (((readSectorCounter << 9) | readByteCounter))  - (wordOffset << 2) - 3;
                                dmemAIn <= {sdReadData, memWord[23:0]};
                            end else if (executableOrFile == `Background) begin
                                backgroundMemWea <= `Enabled;
                                backgroundMemAddra <= (((readSectorCounter << 9) | readByteCounter)) >> 1;
                                backgroundMemDina <= {sdReadData[7:4], sdReadData[2:0], memWord[23], memWord[20:17]};
                            end
                        end
                    end else if (memByteCount == 1)
                    begin
                        if (executableOrFile == `Background) begin
                            backgroundMemWea <= `Enabled;
                            backgroundMemAddra <= (((readSectorCounter << 9) | readByteCounter)) >> 1;
                            backgroundMemDina <= {sdReadData[7:4], sdReadData[2:0], memWord[7], memWord[4:1]};
                        end
                    end
                end else if (sdReadDataASectorDone) begin
                    readByteCounter <= 0;
                    readSectorCounter <= readSectorCounter + 1;
                end

            S_BL_READFILECLUS_CHECKNEXTCLUS:
                begin
                    if(memWordCount < wordLimit) begin
                        currFileSectorCounter <= readSectorCounter;
                        nextState <= S_BL_READFILECLUS_CHECKNEXTCLUS_POST;
                        clusNumUse <= `File;
                        blState <= S_BL_GETNEXTCLUSNUM;
                    end else begin
                        debugInfo <= {8'hBf, currFileSectorCounter[23:0]};
                        debugInfoAvailable <= `True;
                        blState <= S_BL_READFILECLUS_POST;
                    end
                end

            S_BL_READFILECLUS_CHECKNEXTCLUS_POST:
                begin
                    if (nextClusNum[30:0] != 31'hfffffff) begin
                        debugInfo <= {8'hBE, currFileSectorCounter[23:0]};
                        debugInfoAvailable <= `True;

                        currFileClusNum <= nextClusNum;
                        sdReadEn <= `Enabled;
                        readByteCounter <= 0;
                        readSectorCounter <= currFileSectorCounter;
                        sdReadSectorNum <= (1 << BPB_SecPerClus_log2);
                        sdReadAddr <= ((nextClusNum - 2) << BPB_SecPerClus_log2) + firstClusSec;
                        memWord <= 0;
                        memByteCount <= 0;
                        blState <= S_BL_READFILECLUS;
                    end else begin
                        debugInfo <= {8'hBD, currFileSectorCounter[23:0]};
                        debugInfoAvailable <= `True;
                        blState <= S_BL_READFILECLUS_POST;
                    end
                end

            S_BL_READFILECLUS_POST:
                begin
                    if(!oOk) begin
                        oOk <= `True;
                    end else begin
                        if (executableOrFile == `Executable)
                            oLoadExecutableOk <= `True;
                        else if (executableOrFile == `File)
                            oLoadFileOk <= `True;
                        else if (executableOrFile == `Background)
                            oLoadBackgroundFileOk <= `True;
                    end
                    blState <= S_BL_IDLE;
                end

            

            S_BL_IDLE:
                begin
                    blWorking <= `False;
                    if (iLoadExecutableEn) begin
                        loadExecutableIMEMAddr <= iLoadExecutableIMEMAddr;
                        loadExecutableName <= iLoadExecutableName;
                        wordLimit <= iWordLimit;
                        wordOffset <= iWordOffset;
                        executableOrFile <= `Executable;
                        blState <= S_BL_LOAD;
                        blWorking <= `True;
                        iIgnoreInitScript_effective <= `Disabled;
                    end else if (iLoadFileEn) begin
                        loadFileDMEMAddr <= iLoadFileDMEMAddr;
                        loadFileName <= iLoadFileName;
                        wordLimit <= iWordLimit;
                        wordOffset <= iWordOffset;                        
                        executableOrFile <= `File;
                        blState <= S_BL_LOAD;
                        blWorking <= `True;
                    end else if (iLoadBackgroundFileEn) begin
                        loadFileName <= iLoadFileName;
                        wordLimit <= 32'hFFFFFFFF;
                        wordOffset <= 0;
                        executableOrFile <= `Background;
                        blState <= S_BL_LOAD;
                        blWorking <= `True;
                    end
                end

            S_BL_ERROR:
                blError <= `True;

            default:
                blState <= S_BL_RESET;

        endcase

    end

endmodule
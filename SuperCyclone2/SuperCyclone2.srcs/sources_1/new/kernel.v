`timescale 1ns/1ns
`include "sdHeader.vh"

module kernel(
    input clk,
    input reset,
    input [7:0] funcCode,

    input [15:0] SW,
    input btnu,
    input btnc,
    input btnd,
    input btnl,
    input btnr,
    
    output reg [4:0] rfRAddr1,
    input [31:0] rfRData1,

    output reg working,
    output reg initOk,

    input [31:0] dmemAOut,
    output reg dmemAEn,
    output reg [3:0] dmemAWe,
    output reg [31:0] dmemAAddr,
    output reg [31:0] dmemAIn,

    output reg blLoadExecutableEn,
    output reg [87:0] blLoadExecutableName,
    output reg [31:0] blLoadExecutableIMEMAddr,
    input blLoadExecutableOk,

    output reg blLoadFileEn,
    output reg [87:0] blLoadFileName,
    output reg [31:0] blLoadFileDMEMAddr,
    input blLoadFileOk,

    output reg [31:0] blWordLimit,
    output reg [31:0] blWordOffset,

    output reg blLoadBackgroundFileEn,
    input blLoadBackgroundFileOk,

    output reg canvasMemWea,
    output reg [17:0] canvasMemAddra,
    output reg [12:0] canvasMemDina,

    output reg [31:0] sevenSegOut

);

    reg [31:0] v0;
    reg [31:0] v1;
    reg [31:0] a0;
    reg [31:0] a1;
    reg [31:0] a2;

    reg [7:0] knState;
    reg [7:0] nextState;

    reg [7:0] funcCode_stored;

    `include "knStates.vh"
    localparam canvasSize = 512*288;
    reg [17:0] canvasPixelCount;

    always @(posedge clk) begin
        if (reset) begin
            working <= `False;
            dmemAEn <= `Disabled;
            dmemAWe <= 0;
            dmemAAddr <= 0;
            dmemAIn <= 0;
            
            blLoadExecutableEn <= `Disabled;
            blLoadFileEn <= `Disabled;
            blLoadBackgroundFileEn <= `Disabled;

            canvasMemWea <= `Disabled;
            sevenSegOut <= 32'h12ABCDEF;
            initOk <= `False;
            canvasPixelCount <= 0;
        end else if(~working && ~initOk) begin
            working <= `True;
            canvasPixelCount <= 0;
            knState <= S_KN_CLEARCANVAS;
            dmemAWe <= 0;
        end else if(working) begin
            case (knState)
                S_KN_READV0:
                begin
                    knState <= S_KN_READV1;
                    v0 <= rfRData1;
                end

                S_KN_READV1:
                begin
                    knState <= S_KN_READA0;
                    v1 <= rfRData1;
                end

                S_KN_READA0:
                begin
                    knState <= S_KN_READA1;
                    a0 <= rfRData1;
                end

                S_KN_READA1:
                begin
                    knState <= S_KN_READA2;
                    a1 <= rfRData1;
                end

                S_KN_READA2:
                begin
                    knState <= S_KN_FUNCBRANCH;
                    a2 <= rfRData1;
                end

                S_KN_FUNCBRANCH:
                begin
                    if(funcCode_stored == 'h11) begin
                        knState <= S_KN_READSDTODMEM;
                    end else if(funcCode_stored == 'h12) begin
                        knState <= S_KN_READSDTOIMEM;
                    end else if(funcCode_stored == 'h13) begin
                        knState <= S_KN_READSDTOBACKGROUND;
                    end else if(funcCode_stored == 'h1) begin
                        knState <= S_KN_CHANGE7SEG;
                    end else if(funcCode_stored == 'h2) begin
                        knState <= S_KN_DRAWPIXEL;
                    end else if(funcCode_stored == 'h3) begin
                        canvasPixelCount <= 0;
                        knState <= S_KN_CLEARCANVAS;
                    end else if(funcCode_stored == 'h8) begin
                        knState <= S_KN_WAITFORBUTTON;
                    end else if(funcCode_stored == 'h9) begin
                        knState <= S_KN_READSW;
                    end else begin
                        knState <= S_KN_DONE;
                    end
                end

                S_KN_DONE:
                begin
                    working <= `False;
                    canvasMemWea <= `False;
                    dmemAWe <= 0;
                    dmemAEn <= `Disabled;

                end

                S_KN_READSDTODMEM:
                begin
                    nextState <= S_KN_READSDTODMEM_DO;
                    knState <= S_KN_READFILENAME;
                end

                S_KN_READSDTOIMEM:
                begin
                    nextState <= S_KN_READSDTOIMEM_DO_PRE;
                    knState <= S_KN_READFILENAME;
                end

                S_KN_READSDTOBACKGROUND:
                begin
                    nextState <= S_KN_READSDTOBACKGROUND_DO;
                    knState <= S_KN_READFILENAME;
                end

                S_KN_READFILENAME:
                begin
                    // 从内存读取文件名
                    dmemAEn <= `True;
                    dmemAAddr <= v1;
                    knState <= S_KN_READFILENAME_0;
                end

                S_KN_READFILENAME_0:
                begin
                    dmemAEn <= `True;
                    dmemAAddr <= dmemAAddr + 4;
                    knState <= S_KN_READFILENAME_1;
                end

                S_KN_READFILENAME_1:
                begin
                    blLoadFileName[87:56] <= dmemAOut;
                    dmemAEn <= `True;
                    dmemAAddr <= dmemAAddr + 4;
                    knState <= S_KN_READFILENAME_2;
                end

                S_KN_READFILENAME_2:
                begin
                    blLoadFileName[55:24] <= dmemAOut;
                    knState <= S_KN_READFILENAME_3;
                end

                S_KN_READFILENAME_3:
                begin
                    blLoadFileName[23:0] <= dmemAOut[31:8];
                    knState <= nextState;
                end

                S_KN_READSDTODMEM_DO:
                begin
                    if(blLoadFileOk) begin
                        knState <= S_KN_DONE;
                        blLoadFileEn <= `False;
                    end else begin
                        blLoadFileDMEMAddr <= a0;
                        blWordOffset <= a1;
                        blWordLimit <= a2;
                        blLoadFileEn <= `True;
                    end
                end

                S_KN_READSDTOIMEM_DO_PRE:
                begin
                    blLoadExecutableName <= blLoadFileName;
                    knState <= S_KN_READSDTOIMEM_DO;
                end

                S_KN_READSDTOIMEM_DO:
                begin
                    if(blLoadExecutableOk) begin
                        knState <= S_KN_DONE;
                        blLoadExecutableEn <= `False;
                    end else begin
                        blLoadExecutableIMEMAddr <= a0;
                        blWordOffset <= a1;
                        blWordLimit <= a2;
                        blLoadExecutableEn <= `True;
                    end
                end

                S_KN_READSDTOBACKGROUND_DO:
                begin
                    if(blLoadBackgroundFileOk) begin
                        knState <= S_KN_DONE;
                        blLoadBackgroundFileEn <= `False;
                    end else begin
                        blLoadBackgroundFileEn <= `True;
                    end
                end

                S_KN_CHANGE7SEG:
                begin
                    sevenSegOut <= v1;
                    knState <= S_KN_DONE;
                end

                S_KN_DRAWPIXEL:
                begin
                    canvasMemWea <= `Enabled;
                    canvasMemAddra <= {v1[24:16], v1[8:0]};
                    canvasMemDina <= {1'b1, a0[15:12], a0[10:7], a0[4:1]};
                    knState <= S_KN_DONE;
                end

                S_KN_CLEARCANVAS:
                begin
                    if (canvasPixelCount < canvasSize) begin
                        canvasMemWea <= `Enabled;
                        canvasMemAddra <= canvasPixelCount;
                        canvasMemDina <= 0;
                        canvasPixelCount <= canvasPixelCount + 1;
                    end else begin
                        canvasMemWea <= `Disabled;
                        initOk <= `True;
                        knState <= S_KN_DONE;
                    end
                end

                S_KN_WAITFORBUTTON:
                begin
                    knState <= S_KN_DONE;
                    if(btnu) begin
                        dmemAEn <= `True;
                        dmemAWe <= 'hf;
                        dmemAAddr <= a0;
                        dmemAIn <= 32'h1;
                    end else if(btnc) begin
                        dmemAEn <= `True;
                        dmemAWe <= 'hf;
                        dmemAAddr <= a0;
                        dmemAIn <= 32'h2;
                    end else if(btnd) begin
                        dmemAEn <= `True;
                        dmemAWe <= 'hf;
                        dmemAAddr <= a0;
                        dmemAIn <= 32'h3;
                    end else if(btnl) begin
                        dmemAEn <= `True;
                        dmemAWe <= 'hf;
                        dmemAAddr <= a0;
                        dmemAIn <= 32'h4;
                    end else if(btnr) begin
                        dmemAEn <= `True;
                        dmemAWe <= 'hf;
                        dmemAAddr <= a0;
                        dmemAIn <= 32'h5;
                    end else begin
                        knState <= S_KN_WAITFORBUTTON;
                    end
                end

                S_KN_READSW:
                begin
                    dmemAEn <= `True;
                    dmemAWe <= 'hf;
                    dmemAAddr <= a0;
                    dmemAIn <= {16'h0, SW};
                    knState <= S_KN_DONE;
                end

                default:
                begin
                    knState <= S_KN_DONE;
                end
            endcase
        end else if(funcCode != 0) begin
            working <= `True;
            knState <= S_KN_READV0;
            funcCode_stored <= funcCode;
            dmemAWe <= 0;
        end
    end

    always @* begin
        case (knState)
            S_KN_READV0:
            begin
                rfRAddr1 = 2;
            end

            S_KN_READV1:
            begin
                rfRAddr1 = 3;
            end

            S_KN_READA0:
            begin
                rfRAddr1 = 4;
            end

            S_KN_READA1:
            begin
                rfRAddr1 = 5;
            end

            S_KN_READA2:
            begin
                rfRAddr1 = 6;
            end

            default:
                rfRAddr1 = 0;
        endcase
    end

endmodule
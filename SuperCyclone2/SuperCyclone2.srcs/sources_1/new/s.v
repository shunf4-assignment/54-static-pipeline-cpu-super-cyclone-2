`timescale 1ns / 1ns
`define ENABLE 1'b1
`define DISABLE 1'b0

`define SIGNED 1'b1
`define UNSIGNED 1'b0
    
module Supercyclone(
    input clk,
    input reset,
    input ena,

    input [31:0] inst,  //imemOut
    output cpuRunning,
    output cpuPaused,
    output reg [31:0] pc,   //imemRAddr

    output reg dmemAEn,
    output [3:0] dmemAWe,
    output reg [31:0] dmemAAddr,
    output reg [31:0] dmemAIn,
    input [31:0] dmemAOut,

    output [31:0] imemWAddr,
    output [31:0] imemWData,
    output imemWe,

    input [4:0] debugRFAddr,
    output [31:0] debugRFData,

    output reg [7:0] syscallFuncCode,
    input [4:0] rfRAddr1_kn,
    output [31:0] rfRData1,

    input knWorking
);
    assign imemWAddr = 32'h0;
    assign imemWData = 32'h0;
    assign imemWe = `DISABLE;
    
    reg cpuStarted;
    assign cpuRunning = (ena & cpuStarted);

    `include "aluHeader.vh"
    `include "IDCodes.vh"

    ////////////////////
    /// Parts Instantiating
    /// Register File
    wire rfWe;
    wire [4:0] rfRAddr1;
    wire [4:0] rfRAddr2;
    wire [4:0] rfWAddr;
    wire [31:0] rfWData;
    wire [31:0] rfRData2;

    regfile cpu_ref(
        .clk(clk),
        .rst(reset),
        .we(rfWe),
        .raddr1(knWorking ? rfRAddr1_kn : rfRAddr1),
        .raddr2(rfRAddr2),
        .waddr(rfWAddr),
        .rdata1(rfRData1),
        .rdata2(rfRData2),
        .wdata(rfWData),
        .debugRFAddr(debugRFAddr),
        .debugRFData(debugRFData)
    );

    /// ALU
    reg [31:0] aluA;
    reg [31:0] aluB;
    reg [4:0] aluModeSel;
    wire [31:0] aluR;
    wire [31:0] aluRX;
    wire aluZero, aluCarry, aluNegative, aluOverflow;
    ALU alu(
        .clk(~clk),
        .A(aluA),
        .B(aluB),
        .modeSel(aluModeSel),
        .R(aluR),
        .RX(aluRX),
        .isRZero(aluZero),
        .isCarry(aluCarry),
        .isRNegative(aluNegative),
        .isOverflow(aluOverflow)
    );

    ///////////////
    /// Extender
    ///
    wire [31:0] extend16S_1In;
    wire [31:0] extend16S_1Out;

    wire [31:0] extend16S_2In;
    wire [31:0] extend16S_2Out;

    wire [31:0] extend16UIn;
    wire [31:0] extend16UOut;

    wire [31:0] extend8SIn;
    wire [31:0] extend8SOut;

    wire [31:0] extend8UIn;
    wire [31:0] extend8UOut;

    extender #(16, `SIGNED) extend16S_1(
        .in(extend16S_1In),
        .out(extend16S_1Out)
    );

    extender #(16, `SIGNED) extend16S_2(
        .in(extend16S_2In),
        .out(extend16S_2Out)
    );

    extender #(16, `UNSIGNED) extend16U(
        .in(extend16UIn),
        .out(extend16UOut)
    );

    extender #(8, `SIGNED) extend8S(
        .in(extend8SIn),
        .out(extend8SOut)
    );

    extender #(8, `UNSIGNED) extend8U(
        .in(extend8UIn),
        .out(extend8UOut)
    );

    /////////////////////////////////////
    /// Special structures
    /// Instruction Decoder
    wire [5:0] op = inst[31:26];
    wire [5:0] func = inst[5:0];
    wire [4:0] rs = inst[25:21];
    wire [4:0] base = inst[25:21];
    wire [4:0] rt = inst[20:16];
    wire [4:0] rd = inst[15:11];
    wire [4:0] shamt = inst[10:6];
    wire [15:0] imm = inst[15:0];
    wire [25:0] index = inst[25:0];

    ///////////////////////
    /// PC, HI, LO
    /// PC is defined at I/O ports.
    reg [31:0] hi;
    reg [31:0] lo;
    reg [31:0] nextHi;
    reg [31:0] nextLo;

    /////////////////////////
    /// CPU Starting

    reg [3:0] startCounter;
    localparam startNo = 10;

    localparam initInstAddr = 32'h00400000;
    localparam initDataAddr = 32'h10010000;

    always @(posedge clk) begin
        if(reset == `ENABLE) begin
            startCounter <= 0;
            cpuStarted <= `DISABLE;
            hi <= 0;
            lo <= 0;
        end
        else

        if(cpuStarted == `DISABLE && ena) begin
            if(startCounter < startNo - 1) begin
                startCounter <= startCounter + 1;
            end
            else if (startCounter >= startNo - 1) begin
                startCounter <= startNo - 1;
                cpuStarted <= `ENABLE;
            end
        end
    end


    /////////////////
    /// Other definitions

    localparam exceptionEntry = 32'h00400004;
    `define SYSCALLCAUSE  5'b01000
    `define BREAKCAUSE  5'b01001
    `define TEQCAUSE 5'b01101

    reg [4:0] cp0Addr;
    reg [31:0] cp0WData;
    wire [31:0] cp0RData;
    reg cp0Exception;
    wire cp0Intr = `DISABLE;
    wire [31:0] cp0Status;
    reg [31:0] cp0Cause;
    reg [3:0] dmemAWe_orig;
    assign dmemAWe = dmemAWe_orig;
    localparam BigEndianCPU = 1'b0;

    ///////////////////////
    /// Pipeline Logic
    ///////////////////////


    wire bubbleIF = `DISABLE;
    wire bubbleID = 
        (id_rs_willRead_wire && id_rs_wire == ex_rfWAddr_wire && id_rs_wire != 0 && ex_rfWe_wire)
     || (id_rt_willRead_wire && id_rt_wire == ex_rfWAddr_wire && id_rt_wire != 0 && ex_rfWe_wire);
        
    wire bubbleEX = `DISABLE;
    wire bubbleMEM = `DISABLE;
    wire bubbleWB = `DISABLE;

    wire allowIF = ~bubbleIF & allowID & allowEX & allowMEM & allowWB;
    wire allowID = ~bubbleID & allowEX & allowMEM & allowWB;
    wire allowEX = ~bubbleEX & allowMEM & allowWB;
    wire allowMEM = ~bubbleMEM & allowWB;
    wire allowWB = ~bubbleWB;

    /// Instruction Fetch
    reg [31:0] preif_pc;

    wire [31:0] if_pcPlus4_wire = preif_pc + 4;
    wire [31:0] if_npc_wire;
    wire if_invalidated_wire;

    reg [31:0] ifid_inst;

    always @(posedge clk) begin
        if (reset == `ENABLE) begin
            ifid_inst <= 0;
            preif_pc <= initInstAddr;
        end
        else
        if (cpuRunning) begin

            if (allowIF) begin
                if (if_invalidated_wire) begin
                    ifid_inst <= NullInstruction;
                end else begin
                    ifid_inst <= inst;
                end
                preif_pc <= preif_npc_wire;
            end else if (bubbleIF) begin
                ifid_inst <= NullInstruction;
            end

        end
    end

    // Instruction Decoding

    wire [54:0] id_itype_wire;   // 指令类型
    wire [31:0] id_npc_cp0_val_wire = excpetionEntry;
    wire [31:0] id_iretpc_cp0_val_wire = cp0ExecAddr;
    wire [4:0] id_rfWAddr_wire;
    wire [15:0] id_imm_wire;
    wire [4:0] id_aluModeSel_wire;
    wire [4:0] id_rs_wire;
    wire [4:0] id_rt_wire;
    wire [4:0] id_rd_wire;
    wire [31:0] id_pcPlus4_val_wire = if_pcPlus4_wire;
    wire [31:0] id_rs_val_wire;   // 带 val 的都是 CPU 发往 ID, 否则相反
    wire [31:0] id_rt_val_wire;
    wire [31:0] id_extender16S_val_wire;
    wire [31:0] id_extender16U_val_wire;
    wire [31:0] id_aluA_wire;
    wire [31:0] id_aluB_wire;
    wire [31:0] id_npc_wire;
    assign preif_npc_wire = id_npc_wire;
    wire id_rfWe_wire;
    wire id_dmemEn_wire;
    wire [31:0] id_rsVal_wire;
    wire [31:0] id_rtVal_wire;
    wire [3:0] id_dmemWe_wire;
    wire id_condJump_wire;
    wire id_rs_willRead_wire;
    wire id_rt_willRead_wire;
    assign if_invalidated_wire = id_condJump_wire;

    assign rfRAddr1 = id_rs_wire;
    assign rfRAddr2 = id_rt_wire;
    assign id_rs_val_wire = // 相关作用路径
        (ex_rfWAddr_wire == id_rs_wire && id_rs_wire != 0 && ex_rfWe_wire) ?
            (ex_itype_wire[ISw] | ex_itype_wire[ILbu] | ex_itype_wire[ILhu] | ex_itype_wire[ILb] | ex_itype_wire[ILh]) ? // 此时无法拿到内存中的数据
                32'h8A8A8A8A
            :
                ex_result_wire
        : (mem_rfWAddr_wire == id_rs_wire && id_rs_wire != 0 && mem_rfWe_wire) ?
            mem_result_wire
        : (wb_rfWAddr_wire == id_rs_wire && id_rs_wire != 0 && wb_rfWe_wire) ?
            wb_result_wire
        : rfRData1;
    assign id_rt_val_wire = // 相关作用路径
        (ex_rfWAddr_wire == id_rt_wire && id_rt_wire != 0 && ex_rfWe_wire) ?
            (ex_itype_wire[ISw] | ex_itype_wire[ILbu] | ex_itype_wire[ILhu] | ex_itype_wire[ILb] | ex_itype_wire[ILh]) ? // 此时无法拿到内存中的数据
                32'h8A8A8A8A
            :
                ex_result_wire
        : (mem_rfWAddr_wire == id_rt_wire && id_rt_wire != 0 && mem_rfWe_wire) ?
            mem_result_wire
        : (wb_rfWAddr_wire == id_rt_wire && id_rt_wire != 0 && wb_rfWe_wire) ?
            wb_result_wire
        : rfRData2;

    assign extend16S_1In = id_imm_wire;
    assign extend16UIn = id_imm_wire;
    assign id_extender16S_val_wire = extend16S_1Out;
    assign id_extender16U_val_wire = extend16UOut;

    reg [54:0] idex_itype;
    reg [4:0] idex_rfWAddr;
    reg [4:0] idex_imm;
    reg [4:0] idex_aluModeSel;
    reg [4:0] idex_rs;
    reg [4:0] idex_rt;
    reg [4:0] idex_rd;
    reg [31:0] idex_aluA;
    reg [31:0] idex_aluB;
    //reg [31:0] idex_npc;
    reg idex_rfWe;
    reg idex_dmemEn;
    reg [3:0] idex_dmemWe;
    reg [31:0] idex_rsVal;
    reg [31:0] idex_rtVal;
    reg idex_condJump;

    ID id(
        .inst(ifid_inst),
        .pcPlus4(id_pcPlus4_val_wire),
        .npc_cp0(id_npc_cp0_val_wire),
        .iretpc_cp0(id_iretpc_cp0_val_wire),
        .rsVal(id_rs_val_wire),
        .rtVal(id_rt_val_wire),
        .extender16SVal(id_extender16S_val_wire),
        .extender16UVal(id_extender16U_val_wire),
        
        .iType(id_itype_wire),
        .imm(id_imm_wire),
        .aluModeSel(id_aluModeSel_wire),
        .rfWAddr(id_rfWAddr_wire),
        .rs(id_rs_wire),
        .rs_willRead(id_rs_willRead_wire),
        .rt(id_rt_wire),
        .rt_willRead(id_rt_willRead_wire),
        .rd(id_rd_wire),
        .aluA(id_aluA_wire),
        .aluB(id_aluB_wire),
        .npc(id_npc_wire),
        .condJump(id_condJump_wire),
        .rfWe(id_rfWe_wire),
        .dmemEn(id_dmemEn_wire),
        .dmemWe(id_dmemWe_wire)
    );
        

    always @(posedge clk) begin
        if (reset == `ENABLE) begin
            idex_itype <= 0;
            idex_rfWAddr <= 0;
            idex_imm <= 0;
            idex_aluModeSel <= 0;
            idex_rs <= 0;
            idex_rt <= 0;
            idex_rd <= 0;
            idex_aluA <= 0;
            idex_aluB <= 0;
            //idex_npc <= 32'hFFFFFFFF;
            idex_rfWe <= `DISABLE;
            idex_dmemEn <= `DISABLE;
            idex_dmemWe <= 0;
            idex_rsVal <= 0;
            idex_rtVal <= 0;
            idex_condJump <= `DISABLE;
        end
        else
        if (cpuRunning) begin

            if (allowID) begin
                idex_itype <= id_itype_wire;
                idex_rfWAddr <= id_rfWAddr_wire;
                idex_imm <= id_imm_wire;
                idex_aluModeSel <= id_aluModeSel_wire;
                idex_rs <= id_rs_wire;
                idex_rt <= id_rt_wire;
                idex_rd <= id_rd_wire;
                idex_aluA <= id_aluA_wire;
                idex_aluB <= id_aluB_wire;
                //idex_npc <= id_npc_wire
                idex_rfWe <= id_rfWe_wire;
            end else if (bubbleID) begin

            end

        end
    end

    ///////////////
    /// CP0
    
    cp0 cp0(
        .clk(clk),
        .rst(reset),
        .cpuPaused(cpuPaused),
        .mfc0(iMfc0),
        .mtc0(iMtc0),
        .pc(pc),
        .nextPC(nextPC_cp0),
        .addr(cp0Addr),
        .data(cp0WData),
        .exception(cp0Exception),
        .eret(iEret),
        .cause(cp0Cause),
        .intr(cp0Intr),

        .PC0_out(cp0RData),
        .status(cp0Status),
        .epc_out(cp0ExecAddr)

    );

endmodule

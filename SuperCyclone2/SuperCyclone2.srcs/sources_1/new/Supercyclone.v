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
    output [31:0] pc,   //imemRAddr

    output dmemAEn,
    output [3:0] dmemAWe,
    output [31:0] dmemAAddr,
    output [31:0] dmemAIn,
    input [31:0] dmemAOut,

    output [31:0] imemWAddr,
    output [31:0] imemWData,
    output imemWe,

    input [4:0] debugRFAddr,
    output [31:0] debugRFData,

    output [7:0] syscallFuncCode,
    input [4:0] rfRAddr1_kn,
    output [31:0] rfRData1,

    input knWorking
);
    assign imemWAddr = 32'h0;
    assign imemWData = 32'h0;
    assign imemWe = `DISABLE;

    assign cpuPaused = knWorking;
    
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
    wire [31:0] aluA;
    wire [31:0] aluB;
    wire [4:0] aluModeSel;
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

    wire [31:0] extend16U_forLBUIn;
    wire [31:0] extend16U_forLBUOut;

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

    extender #(16, `UNSIGNED) extend16U_forLBU(
        .in(extend16U_forLBUIn),
        .out(extend16U_forLBUOut)
    );

    extender #(8, `SIGNED) extend8S(
        .in(extend8SIn),
        .out(extend8SOut)
    );

    extender #(8, `UNSIGNED) extend8U(
        .in(extend8UIn),
        .out(extend8UOut)
    );

    ///////////////////////
    /// HI, LO

    reg [31:0] hi;
    reg [31:0] lo;

    /////////////////////////
    /// CPU Starting

    reg [3:0] startCounter;
    localparam startNo = 10;

    localparam exceptionEntry = 32'h00400004;
    localparam initInstAddr = 32'h00400000;
    localparam initDataAddr = 32'h10010000;

    always @(posedge clk) begin
        if(reset == `ENABLE) begin
            startCounter <= 0;
            cpuStarted <= `DISABLE;
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

    `define SYSCALLCAUSE  5'b01000
    `define BREAKCAUSE  5'b01001
    `define TEQCAUSE 5'b01101

    wire [31:0] cp0RData;
    wire cp0Exception;
    wire cp0Intr = `DISABLE;
    wire [31:0] cp0Status;
    wire [31:0] cp0Cause;
    wire [31:0] cp0ExecAddr;

    localparam BigEndianCPU = 1'b0;

    ///////////////////////
    /// Pipeline Logic
    ///////////////////////


    wire bubbleIF = `DISABLE;
    wire bubbleID;
    /* 最下方会定义 bubbleID */
        
    wire bubbleEX = `DISABLE;
    wire bubbleMEM = `DISABLE;
    wire bubbleWB = `DISABLE;

    wire allowWB = ~bubbleWB;
    wire allowMEM = ~bubbleMEM & allowWB;
    wire allowEX = ~bubbleEX & allowMEM & allowWB;
    wire allowID = ~bubbleID & allowEX & allowMEM & allowWB;
    wire allowIF = ~bubbleIF & allowID & allowEX & allowMEM & allowWB;
    
    /// Instruction Fetch
    reg [31:0] preif_pc;

    wire [31:0] if_pcPlus4_wire = preif_pc + 4;
    wire [31:0] if_npc_wire;
    wire if_invalidated_wire;

    reg [31:0] ifid_inst;

    assign pc = preif_pc;

    reg [31:0] instCounter;
    reg [31:0] bubbleCounter;
    reg [31:0] slotCounter;

    always @(posedge clk) begin
        if (reset == `ENABLE) begin
            ifid_inst <= 0;
            instCounter <= 0;
            bubbleCounter <= 0;
            slotCounter <= 0;
            preif_pc <= initInstAddr;
        end
        else
        if (cpuRunning) begin
            instCounter <= instCounter + 1;
            if (allowIF) begin
                if (if_invalidated_wire) begin
                    ifid_inst <= NullInstruction;
                    slotCounter <= slotCounter + 1;
                end else begin
                    ifid_inst <= inst;
                end
                preif_pc <= if_npc_wire;
            end else if (bubbleIF) begin
                ifid_inst <= NullInstruction;
            end
            
            if (bubbleEX || bubbleID || bubbleIF || bubbleMEM || bubbleWB)
                bubbleCounter <= bubbleCounter + 1;
        end
    end

    // Instruction Decoding

    wire [54:0] id_itype_wire;   // 指令类型
    wire [31:0] id_npc_cp0Val_wire;
    wire [31:0] id_iretpc_cp0Val_wire = cp0ExecAddr;
    wire [4:0] id_rfWAddr_wire;
    wire [15:0] id_imm_wire;
    wire [4:0] id_aluModeSel_wire;
    wire [4:0] id_rs_wire;
    wire [4:0] id_rt_wire;
    wire [4:0] id_rd_wire;
    wire [31:0] id_pcPlus4Val_wire = if_pcPlus4_wire;
    wire [31:0] id_rsVal_wire;   // 带 val 的都是 CPU 发往 ID, 否则相反
    wire [31:0] id_rtVal_wire;
    wire [31:0] id_extender16SVal_wire;
    wire [31:0] id_extender16UVal_wire;
    wire [31:0] id_aluA_wire;
    wire [31:0] id_aluB_wire;
    wire [31:0] id_npc_wire;
    assign if_npc_wire = id_npc_wire;
    wire id_rfWe_wire;
    wire id_dmemEn_wire;
    wire [3:0] id_dmemWe_wire;
    wire id_condJump_wire;
    wire id_rs_willRead_wire;
    wire id_rt_willRead_wire;
    wire [7:0] id_syscallFuncode_wire;

    assign if_invalidated_wire = id_condJump_wire;

    assign cp0Exception = id_itype_wire[IBreak] || id_itype_wire[ISyscall] || (id_itype_wire[ITeq] && id_condJump_wire);
    assign cp0Cause = 
        id_itype_wire[IBreak] ? 
            {25'h0, `BREAKCAUSE, 2'h0}
        : id_itype_wire[ISyscall] ?
            {25'h0, `SYSCALLCAUSE, 2'h0}
        : (id_itype_wire[ITeq] && id_condJump_wire) ?
            {25'h0, `TEQCAUSE, 2'h0}
        : 0
    ;
    assign syscallFuncCode = allowID & id_syscallFuncode_wire;
    assign rfRAddr1 = id_rs_wire;
    assign rfRAddr2 = id_rt_wire;
    /* assign id_rsVal_wire = // 相关作用路径, 赋值在底部 */
    
    /* assign id_rtVal_wire = // 相关作用路径, 赋值在底部 */
        
    assign extend16S_1In = id_imm_wire;
    assign extend16UIn = id_imm_wire;
    assign id_extender16SVal_wire = extend16S_1Out;
    assign id_extender16UVal_wire = extend16UOut;

    reg [54:0] idex_itype;
    reg [4:0] idex_rfWAddr;
    reg [15:0] idex_imm;
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
        .pcPlus4(id_pcPlus4Val_wire),
        .npc_cp0(id_npc_cp0Val_wire),
        .iretpc_cp0(id_iretpc_cp0Val_wire),
        .rsVal(id_rsVal_wire),
        .rtVal(id_rtVal_wire),
        .extender16SVal(id_extender16SVal_wire),
        .extender16UVal(id_extender16UVal_wire),
        
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
        .dmemWe(id_dmemWe_wire),
        
        .syscallFuncCode(id_syscallFuncode_wire)
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
                idex_dmemEn <= id_dmemEn_wire;
                idex_dmemWe <= id_dmemWe_wire;
                idex_rsVal <= id_rsVal_wire;
                idex_rtVal <= id_rtVal_wire;
                idex_condJump <= id_condJump_wire;
            end else if (bubbleID) begin
                idex_itype <= 0;
                idex_rfWAddr <= 0;
                idex_imm <= 0;
                idex_aluModeSel <= 0;
                idex_rs <= 0;
                idex_rt <= 0;
                idex_rd <= 0;
                idex_aluA <= 0;
                idex_aluB <= 0;
                //idex_npc <= id_npc_wire
                idex_rfWe <= `DISABLE;
                idex_dmemEn <= `DISABLE;
                idex_dmemWe <= 0;
                idex_rsVal <= 0;
                idex_rtVal <= 0;
                idex_condJump <= `DISABLE;
            end
        end
    end

    // EXecution

    wire [54:0] ex_itype_wire = idex_itype;
    wire [4:0] ex_rfWAddr_wire = idex_rfWAddr;
    wire [15:0] ex_imm_wire = idex_imm;
    wire [4:0] ex_aluModeSel_wire = idex_aluModeSel;
    wire [4:0] ex_rs_wire = idex_rs;
    wire [4:0] ex_rt_wire = idex_rt;
    wire [4:0] ex_rd_wire = idex_rd;
    wire [31:0] ex_aluA_wire = idex_aluA;
    wire [31:0] ex_aluB_wire = idex_aluB;
    wire ex_rfWe_wire_orig = idex_rfWe;
    wire ex_dmemEn_wire = idex_dmemEn;
    wire [3:0] ex_dmemWe_wire_orig = idex_dmemWe;
    wire [31:0] ex_rsVal_wire = idex_rsVal;
    wire [31:0] ex_rtVal_wire = idex_rtVal;
    wire ex_condJump_wire = idex_condJump;

    assign aluA = ex_aluA_wire;
    assign aluB = ex_aluB_wire;
    assign aluModeSel = ex_aluModeSel_wire;

    reg [31:0] ex_result_calculated;
    reg [31:0] ex_extra_result_calculated;
    reg ex_rfWe_calculated;
    reg [3:0] ex_dmemWe_calculated;
    reg [31:0] ex_dmemIn_calculated;
    reg [7:0] ex_bytePos_calculated;

    wire [31:0] ex_result_wire = ex_result_calculated;
    wire [31:0] ex_extra_result_wire = ex_extra_result_calculated;
    wire ex_rfWe_wire = ex_rfWe_calculated;
    wire [3:0] ex_dmemWe_wire = ex_dmemWe_calculated;
    wire [31:0] ex_dmemIn_wire = ex_dmemIn_calculated;
    wire [7:0] ex_bytePos_wire = ex_bytePos_calculated;

    reg [54:0] exmem_itype;
    reg [4:0] exmem_rfWAddr;
    reg exmem_rfWe;
    reg exmem_condJump;
    reg [31:0] exmem_result;
    reg [7:0] exmem_bytePos;
    

`define E(instName) ex_itype_wire[instName]

    always @* begin
        ex_extra_result_calculated = 0;
        ex_bytePos_calculated = 0;
        ex_result_calculated = 0;
        ex_dmemWe_calculated = ex_dmemWe_wire_orig;
        ex_dmemIn_calculated = ex_rtVal_wire;

        ex_rfWe_calculated = ex_rfWe_wire_orig;
        if (`E(IAdd) || `E(IAddu) || `E(ISub) || `E(ISubu) || `E(IAnd) || `E(IOr) || `E(IXor) || `E(INor) || `E(ISlt) || `E(ISltu) || `E(ISll) || `E(ISrl) || `E(ISra) || `E(ISllv) || `E(ISrlv) || `E(ISrav) || /*ijr*/ `E(IAddi) || `E(IAddiu) || `E(IAndi) || `E(IOri) || `E(IXori) ||/*ilw,isw,ibeq,ibne*/ `E(ISlti) || `E(ISltiu) || `E(ILui) ||/*ij*/ `E(IJal) || `E(IDiv) || `E(IDivu) || `E(IMul) || `E(IMult) || `E(IMultu) ||/*ibgez*/ `E(IJalr) ||/*ilb,ilh,ilbu,ilhu,isb,ish,ibreak,isyscall,ieret*/ `E(IMfhi) || `E(IMflo) || `E(IMthi) || `E(IMtlo) || `E(IMfc0) || `E(IMtc0) || `E(IClz) /*iteq*/) begin
            if (`E(ILui))
                ex_result_calculated = {ex_imm_wire, 16'h0};
            else if (`E(IMfhi))
                ex_result_calculated = hi;
            else if (`E(IMflo))
                ex_result_calculated = lo;
            else if (`E(IMtc0))
                ex_result_calculated = cp0RData;
            else begin
                ex_result_calculated = aluR;
                ex_extra_result_calculated = aluRX;
            end

            if (`E(IAdd) || `E(ISub)) begin
                ex_rfWe_calculated = ex_rfWe_wire_orig & ~aluOverflow;
            end
        end

        if (`E(ILw) || `E(ISw) || `E(ILb) || `E(ILh) || `E(ILbu) || `E(ILhu) || `E(ISb) || `E(ISh)) begin
            ex_result_calculated = aluR;
        end

        if (`E(ISw)) begin
            ex_dmemWe_calculated = ex_dmemWe_wire_orig & 4'hf;
            ex_dmemIn_calculated = ex_rtVal_wire;
        end

        if (`E(ISb)) begin
            ex_bytePos_calculated = { 6'h0, aluR[1:0] ^ {2{BigEndianCPU}} };
            ex_dmemIn_calculated = ex_rtVal_wire << (ex_bytePos_calculated << 3);
            ex_dmemWe_calculated = ex_dmemWe_wire_orig & ((4'h1) << ex_bytePos_calculated);
        end

        if (`E(ISh)) begin
            ex_bytePos_calculated = {6'b000, aluR[1] ^ BigEndianCPU, 1'b0};
            ex_dmemIn_calculated = ex_rtVal_wire << (ex_bytePos_calculated[1] ? 16 : 0);
            ex_dmemWe_calculated = ex_dmemWe_wire_orig & ((4'b0011) << ex_bytePos_calculated);
        end
    end

    assign dmemAAddr = ex_result_calculated;
    assign dmemAEn = ex_dmemEn_wire;
    assign dmemAWe = ex_dmemWe_wire;
    assign dmemAIn = ex_dmemIn_wire;

    always @(posedge clk) begin
        if (reset == `ENABLE) begin
            exmem_itype <= 0;
            exmem_rfWAddr <= 0;
            exmem_rfWe <= `DISABLE;
            exmem_condJump <= `DISABLE;
            exmem_result <= 0;
            exmem_bytePos <= 0;

            hi <= 0;
            lo <= 0;
        end
        else
        if (cpuRunning) begin

            if (allowEX) begin
                exmem_itype <= ex_itype_wire;
                exmem_rfWAddr <= ex_rfWAddr_wire;
                exmem_rfWe <= ex_rfWe_wire;
                exmem_condJump <= ex_condJump_wire;
                exmem_result <= ex_result_wire;
                exmem_bytePos <= ex_bytePos_wire;

                if (`E(IDiv) || `E(IDivu) || `E(IMult) || `E(IMultu)) begin
                    hi <= ex_extra_result_wire;
                    lo <= ex_result_wire;
                end else if (`E(IMthi)) begin
                    hi <= ex_result_wire;
                end else if (`E(IMtlo)) begin
                    lo <= ex_result_wire;
                end

                // 另外, cp0 的寄存器也会更新 (MTC0)

            end else if (bubbleEX) begin
                exmem_itype <= 0;
                exmem_rfWAddr <= 0;
                exmem_rfWe <= `DISABLE;
                exmem_condJump <= `DISABLE;
                exmem_result <= 0;
                exmem_bytePos <= 0;
            end

        end
    end

    // MEMory manipulation

    wire [54:0] mem_itype_wire = exmem_itype;
    wire [4:0] mem_rfWAddr_wire = exmem_rfWAddr;
    wire mem_rfWe_wire = exmem_rfWe;
    wire mem_condJump_wire = exmem_condJump;
    wire [31:0] mem_result_wire_orig = exmem_result;    // 可能是地址, 也可能是数据
    wire [7:0] mem_bytePos_wire = exmem_bytePos;

    reg [31:0] mem_result_calculated;

    wire [31:0] mem_dmemOut_wire = dmemAOut;
    wire [31:0] mem_result_wire = mem_result_calculated;

    reg [54:0] memwb_itype;
    reg [4:0] memwb_rfWAddr;
    reg memwb_rfWe;
    reg [31:0] memwb_result;

`define M(instName) mem_itype_wire[instName]

    assign extend8SIn = mem_dmemOut_wire[8 * mem_bytePos_wire +: 8];
    assign extend16S_2In = mem_dmemOut_wire[8 * mem_bytePos_wire +: 16];
    assign extend8UIn = mem_dmemOut_wire[8 * mem_bytePos_wire +: 8];
    assign extend16U_forLBUIn = mem_dmemOut_wire[8 * mem_bytePos_wire +: 16];

    always @* begin
        mem_result_calculated = mem_result_wire_orig;
        if (`M(ILw)) begin
            mem_result_calculated = mem_dmemOut_wire;
        end
        if ( `M(ILb)) begin
            mem_result_calculated = extend8SOut;
        end
        if (`M(ILh)) begin
            mem_result_calculated = extend16S_2Out;
        end
        if ( `M(ILbu) ) begin
            mem_result_calculated = extend8UOut;
        end
        if ( `M(ILhu)) begin
            mem_result_calculated = extend16U_forLBUOut;
        end
    end

    always @(posedge clk) begin
        if (reset == `ENABLE) begin
            memwb_itype <= 0;
            memwb_rfWAddr <= 0;
            memwb_rfWe <= `DISABLE;
            memwb_result <= 0;
        end
        else
        if (cpuRunning) begin

            if (allowMEM) begin
                memwb_itype <= mem_itype_wire;
                memwb_rfWAddr <= mem_rfWAddr_wire;
                memwb_rfWe <= mem_rfWe_wire;
                memwb_result <= mem_result_wire;
            end else if (bubbleMEM) begin
                memwb_itype <= 0;
                memwb_rfWAddr <= 0;
                memwb_rfWe <= `DISABLE;
                memwb_result <= 0;
            end

        end
    end

    // Writing Back

    wire [54:0] wb_itype_wire = memwb_itype;
    wire [4:0] wb_rfWAddr_wire = memwb_rfWAddr;
    wire wb_rfWe_wire = memwb_rfWe;
    wire [31:0] wb_result_wire = memwb_result;

    assign rfWAddr = wb_rfWAddr_wire;
    assign rfWData = wb_result_wire;
    assign rfWe = wb_rfWe_wire;

    // Some values assignment

    assign bubbleID = (ex_itype_wire[ISw] | ex_itype_wire[ILbu] | ex_itype_wire[ILhu] | ex_itype_wire[ILb] | ex_itype_wire[ILh]) && (
        (id_rs_willRead_wire && id_rs_wire == ex_rfWAddr_wire && id_rs_wire != 0 && ex_rfWe_wire)
     || (id_rt_willRead_wire && id_rt_wire == ex_rfWAddr_wire && id_rt_wire != 0 && ex_rfWe_wire)
    );

    assign id_rsVal_wire = // 相关作用路径
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
    assign id_rtVal_wire = // 相关作用路径
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

    ///////////////
    /// CP0
    
    cp0 cp0(
        .clk(clk),
        .rst(reset),
        .cpuPaused(cpuPaused),
        .mfc0(`E(IMfc0)),
        .mtc0(`E(IMtc0)),
        .pc(pc),
        .nextPC(id_npc_cp0Val_wire),
        .addr(ex_rd_wire),
        .data(ex_result_calculated),
        .exception(cp0Exception),
        .eret(id_itype_wire[IEret]),
        .cause(cp0Cause),
        .intr(cp0Intr),

        .CP0_out(cp0RData),
        .status(cp0Status),
        .epc_out(cp0ExecAddr)

    );

endmodule

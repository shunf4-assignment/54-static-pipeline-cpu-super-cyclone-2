`timescale 1ns / 1ps


`define ENABLE 1'b1
`define DISABLE 1'b0

module ID(
    input [31:0] inst,
    input [31:0] pcPlus4,
    input [31:0] npc_cp0,
    input [31:0] iretpc_cp0,
    input [31:0] rsVal,
    input [31:0] rtVal,
    input [31:0] extender16SVal,
    input [31:0] extender16UVal,
    
    output [54:0] iType,
    output [15:0] imm,
    output reg [4:0] aluModeSel,
    output reg [4:0] rfWAddr,
    output [4:0] rs,
    output reg rs_willRead,
    output [4:0] rt,
    output reg rt_willRead,
    output [4:0] rd,
    output reg [31:0] aluA,
    output reg [31:0] aluB,
    output reg [31:0] npc,
    output reg condJump,
    output reg rfWe,
    output reg dmemEn,
    output reg [3:0] dmemWe,
    output reg [7:0] syscallFuncCode
    );

    `include "aluHeader.vh"
    `include "IDCodes.vh"

    wire [5:0] op = inst[31:26];
    wire [5:0] func = inst[5:0];
    wire [4:0] rs_orig = inst[25:21];
    wire [4:0] base = inst[25:21];
    assign rt = inst[20:16];
    assign rd = inst[15:11];
    wire [4:0] shamt = inst[10:6];
    assign imm = inst[15:0];
    wire [25:0] index = inst[25:0];

    wire [31:0] pc = pcPlus4 - 4;

    reg iAdd, iAddu, iSub, iSubu, iAnd, iOr, iXor, iNor, iSlt, iSltu, iSll, iSrl, iSra, iSllv, iSrlv, iSrav, iJr, iAddi, iAddiu, iAndi, iOri, iXori, iLw, iSw, iBeq, iBne, iSlti, iSltiu, iLui, iJ, iJal, iDiv, iDivu, iMult, iMultu, iBgez, iJalr, iLbu, iLhu, iLb, iLh, iSb, iSh, iBreak, iSyscall, iEret, iMfhi, iMflo, iMthi, iMtlo, iMfc0, iMtc0, iClz, iTeq, iMul;
    
    assign iType = {iAdd, iAddu, iSub, iSubu, iAnd, iOr, iXor, iNor, iSlt, iSltu, iSll, iSrl, iSra, iSllv, iSrlv, iSrav, iJr, iAddi, iAddiu, iAndi, iOri, iXori, iLw, iSw, iBeq, iBne, iSlti, iSltiu, iLui, iJ, iJal, iDiv, iDivu, iMult, iMultu, iBgez, iJalr, iLbu, iLhu, iLb, iLh, iSb, iSh, iBreak, iSyscall, iEret, iMfhi, iMflo, iMthi, iMtlo, iMfc0, iMtc0, iClz, iTeq, iMul};

    assign rs = iSyscall ? 2 : rs_orig;

    assign isNop = (iType == 55'h0);

    reg validInstruction;
    always @ (*)
    begin
        aluModeSel = 0;  // AND
        condJump = `DISABLE;
        rfWe = `ENABLE;
        dmemWe = 0;
        rfWAddr = 0;
        aluA = rsVal;
        aluB = rtVal;
        npc = pcPlus4;
        dmemEn = `DISABLE;
        rs_willRead = `ENABLE;
        rt_willRead = `ENABLE;
        validInstruction = `DISABLE;
        syscallFuncCode = 0;
        if(op == 6'b000000 && func == 6'b100000) begin
            validInstruction = `ENABLE;
            iAdd = 1; 
            aluModeSel = ALU_SADD;
            rfWAddr = rd;
            //wd = alur
        end else iAdd = 0;
        if(op == 6'b000000 && func == 6'b100001) begin
            validInstruction = `ENABLE;
            iAddu = 1;
            aluModeSel = ALU_UADD;
            rfWAddr = rd;
            //wd = alur
        end else iAddu = 0;
        if(op == 6'b000000 && func == 6'b100010) begin
            validInstruction = `ENABLE;
            iSub = 1;
            aluModeSel = ALU_SSUB;
            rfWAddr = rd;
            //wd = alur
        end else iSub = 0;
        if(op == 6'b000000 && func == 6'b100011) begin
            validInstruction = `ENABLE;
            iSubu = 1;
            aluModeSel = ALU_USUB;
            rfWAddr = rd;
            //wd=alur
        end else iSubu = 0;
        if(op == 6'b000000 && func == 6'b100100) begin
            validInstruction = `ENABLE;
            iAnd = 1;
            aluModeSel = ALU_AND;
            rfWAddr = rd;
            //wd=alur
        end else iAnd = 0;
        if(op == 6'b000000 && func == 6'b100101) begin
            validInstruction = `ENABLE;
            iOr = 1;
            aluModeSel = ALU_OR;
            rfWAddr = rd;
            //wd=alur
        end else iOr = 0;
        if(op == 6'b000000 && func == 6'b100110) begin
            validInstruction = `ENABLE;
            iXor = 1;
            aluModeSel = ALU_XOR;
            rfWAddr = rd;
            //wd=alur
        end else iXor = 0;
        if(op == 6'b000000 && func == 6'b100111) begin
            validInstruction = `ENABLE;
            iNor = 1;
            aluModeSel = ALU_NOR;
            rfWAddr = rd;
            //wd=alur
        end else iNor = 0;
        if(op == 6'b000000 && func == 6'b101010) begin
            validInstruction = `ENABLE;
            iSlt = 1;
            aluModeSel = ALU_SLES;
            rfWAddr = rd;
            //wd=alur
        end else iSlt = 0;
        if(op == 6'b000000 && func == 6'b101011) begin
            validInstruction = `ENABLE;
            iSltu = 1;
            aluModeSel = ALU_ULES;
            rfWAddr = rd;
            //wd=alur
        end else iSltu = 0;

        if(op == 6'b000000 && func == 6'b000000) begin
            validInstruction = `ENABLE;
            iSll = 1;
            aluA = rtVal;
            aluB = shamt;
            rs_willRead = `DISABLE;
            aluModeSel = ALU_SL;
            rfWAddr = rd;
            //wd=alur
        end else iSll = 0;
        if(op == 6'b000000 && func == 6'b000010) begin
            validInstruction = `ENABLE;
            iSrl = 1;
            aluA = rtVal;
            aluB = shamt;
            rs_willRead = `DISABLE;
            aluModeSel = ALU_SRL;
            rfWAddr = rd;
            //wd=alur
        end else iSrl = 0;
        if(op == 6'b000000 && func == 6'b000011) begin
            validInstruction = `ENABLE;
            iSra = 1;
            aluA = rtVal;
            aluB = shamt;
            rs_willRead = `DISABLE;
            aluModeSel = ALU_SRA;
            rfWAddr = rd;
            //wd=alur
        end else iSra = 0;

        if(op == 6'b000000 && func == 6'b000100) begin
            validInstruction = `ENABLE;
            iSllv = 1;
            aluA = rtVal;
            aluB = rsVal;
            aluModeSel = ALU_SL;
            rfWAddr = rd;
            //wd=alur
        end else iSllv = 0;
        if(op == 6'b000000 && func == 6'b000110) begin
            validInstruction = `ENABLE;
            iSrlv = 1;
            aluA = rtVal;
            aluB = rsVal;
            aluModeSel = ALU_SRL;
            rfWAddr = rd;
            //wd=alur
        end else iSrlv = 0;
        if(op == 6'b000000 && func == 6'b000111) begin
            validInstruction = `ENABLE;
            iSrav = 1;
            aluA = rtVal;
            aluB = rsVal;
            aluModeSel = ALU_SRA;
            rfWAddr = rd;
            //wd=alur
        end else iSrav = 0;

        if(op == 6'b000000 && func == 6'b001000 && rt == 5'h0 && rd == 5'h0) begin
            validInstruction = `ENABLE;
            iJr = 1;
            aluA = 0;
            aluB = 0;
            rt_willRead = `DISABLE;
            rfWe = `DISABLE;
            condJump = `ENABLE;
            npc = rsVal;
            //no wd
        end else iJr = 0;

        if(op == 6'b001000) begin
            validInstruction = `ENABLE;
            iAddi = 1;
            aluA = rsVal;
            aluB = extender16SVal;
            aluModeSel = ALU_SADD;
            rfWAddr = rt;
            rt_willRead = `DISABLE;
            //wd=alur
        end else iAddi = 0;
        if(op == 6'b001001) begin
            validInstruction = `ENABLE;
            iAddiu = 1;
            aluA = rsVal;
            aluB = extender16SVal;
            aluModeSel = ALU_UADD;
            rfWAddr = rt;
            rt_willRead = `DISABLE;
            //wd=alur
        end else iAddiu = 0;
        if(op == 6'b001100) begin
            validInstruction = `ENABLE;
            iAndi = 1;
            aluA = rsVal;
            aluB = extender16UVal;
            aluModeSel = ALU_AND;
            rfWAddr = rt;
            rt_willRead = `DISABLE;
            //wd=alur
        end else iAndi = 0;
        if(op == 6'b001101) begin
            validInstruction = `ENABLE;
            iOri = 1;
            aluA = rsVal;
            aluB = extender16UVal;
            aluModeSel = ALU_OR;
            rfWAddr = rt;
            rt_willRead = `DISABLE;
            //wd=alur
        end else iOri = 0;
        if(op == 6'b001110) begin
            validInstruction = `ENABLE;
            iXori = 1;
            aluA = rsVal;
            aluB = extender16UVal;
            aluModeSel = ALU_XOR;
            rfWAddr = rt;
            rt_willRead = `DISABLE;
            //wd=alur
        end else iXori = 0;
        if(op == 6'b100011) begin
            validInstruction = `ENABLE;
            iLw = 1;
            aluA = rsVal;
            aluB = extender16SVal;
            aluModeSel = ALU_UADD;
            
            dmemEn = `ENABLE;
            //dmemaddr=alur

            rfWAddr = rt;
            rt_willRead = `DISABLE;
            //wd=dmemout
        end else iLw = 0;
        if(op == 6'b101011) begin
            validInstruction = `ENABLE;
            iSw = 1;
            aluA = rsVal;
            aluB = extender16SVal;
            aluModeSel = ALU_UADD;
            rfWe = `DISABLE;
            dmemEn = `ENABLE;
            dmemWe = 4'hf;
            //dmemaddr=alur
            //dmemIn = rtVal;
            //no wd
        end else iSw = 0;
        if(op == 6'b000100) begin
            validInstruction = `ENABLE;
            iBeq = 1;
            aluA = 0;
            aluB = 0;
            rfWe = `DISABLE;
            condJump = (rsVal == rtVal);
            npc = (rsVal == rtVal) ? (pc + (extender16SVal << 2)) : pcPlus4;
            //no wd
        end else iBeq = 0;
        if(op == 6'b000101) begin
            validInstruction = `ENABLE;
            iBne = 1;
            aluA = 0;
            aluB = 0;
            rfWe = `DISABLE;
            condJump = (rsVal != rtVal);
            npc = (rsVal != rtVal) ? (pc + (extender16SVal << 2)) : pcPlus4;
            //no wd
        end else iBne = 0;
        if(op == 6'b001010) begin
            validInstruction = `ENABLE;
            iSlti = 1;
            aluA = rsVal;
            aluB = extender16SVal;
            aluModeSel = ALU_SLES;
            rfWAddr = rt;
            rt_willRead = `DISABLE;
            //wd=alur
        end else iSlti = 0;
        if(op == 6'b001011) begin
            validInstruction = `ENABLE;
            iSltiu = 1;
            aluA = rsVal;
            aluB = extender16SVal;
            aluModeSel = ALU_ULES;
            rfWAddr = rt;
            rt_willRead = `DISABLE;
            //wd=alur
        end else iSltiu = 0;

        if(op == 6'b001111) begin
            validInstruction = `ENABLE;
            iLui = 1;
            aluA = 0;
            aluB = 0;
            rfWAddr = rt;
            rs_willRead = `DISABLE;
            rt_willRead = `DISABLE;
            //wd={imm,16'h0}
        end else iLui = 0;

        if(op == 6'b000010) begin
            validInstruction = `ENABLE;
            iJ = 1;
            aluA = 0;
            aluB = 0;
            rfWe = `DISABLE;
            condJump = `ENABLE;
            npc = {pc[31:28], index, 2'b0};
            rs_willRead = `DISABLE;
            rt_willRead = `DISABLE;
            //no wd
        end else iJ = 0;
        if(op == 6'b000011) begin
            validInstruction = `ENABLE;
            iJal = 1;
            aluA = pc;
            aluB = 0;
            aluModeSel = ALU_UADD;
            condJump = `ENABLE;
            npc = {pc[31:28], index, 2'b0};
            
            rfWAddr = 31;
            rs_willRead = `DISABLE;
            rt_willRead = `DISABLE;
            //wd = pc
        end else iJal = 0;
        
        if(op == 6'b000000 && func == 6'b011010 && rd == 5'h0) begin
            validInstruction = `ENABLE;
            iDiv = 1;
            aluModeSel = ALU_SDIV;
            rfWe = `DISABLE;
            //no wd; hilo
        end else iDiv = 0;
        if(op == 6'b000000 && func == 6'b011011 && rd == 5'h0) begin
            validInstruction = `ENABLE;
            iDivu = 1;
            aluModeSel = ALU_UDIV;
            rfWe = `DISABLE;
            //no wd; hilo
        end else iDivu = 0;
        if(op == 6'b011100 && func == 6'b000010) begin
            validInstruction = `ENABLE;
            iMul = 1;
            aluModeSel = ALU_SMUL;
            rfWAddr = rd;
            //wd=alur
        end else iMul = 0;
        if(op == 6'b000000 && func == 6'b011000 && rd == 5'h0) begin
            validInstruction = `ENABLE;
            iMult = 1;
            aluModeSel = ALU_SMUL;
            rfWe = `DISABLE;
            //no wd;hilo
        end else iMult = 0;
        if(op == 6'b000000 && func == 6'b011001 && rd == 5'h0) begin
            validInstruction = `ENABLE;
            iMultu = 1;
            aluModeSel = ALU_UMUL;
            rfWe = `DISABLE;
            //no wd;hilo
        end else iMultu = 0;

        if(op == 6'b000001 && rt == 5'b00001) begin
            validInstruction = `ENABLE;
            iBgez = 1;
            aluA = 0;
            aluB = 0;
            rfWe = `DISABLE;
            rt_willRead = `DISABLE;
            condJump = ~rsVal[31];
            npc = (~rsVal[31]) ? (pc + (extender16SVal << 2)) : pcPlus4;
            //no wd
        end else iBgez = 0;

        if(op == 6'b000000 && rt == 5'b00000 && shamt == 5'b00000 && func == 6'b001001) begin
            validInstruction = `ENABLE;
            iJalr = 1;
            aluA = pc;
            aluB = 0;
            aluModeSel = ALU_UADD;
            condJump = `ENABLE;
            npc = rsVal;
            rt_willRead = `DISABLE;
            rfWAddr = rd;
            //wd=pc
        end else iJalr = 0;

        if(op == 6'b100000) begin
            validInstruction = `ENABLE;
            iLb = 1;
            aluA = rsVal;
            aluB = extender16SVal;
            aluModeSel = ALU_UADD;

            dmemEn = `ENABLE;
            //dmemaddr = alur
            rfWAddr = rt;
            rt_willRead = `DISABLE;
            //bytePos = {3'b000, dmemAAddr[1:0] ^ {2{BigEndianCPU}}};
            //wd=extend8S(dmemAOut[8 * bytePos +: 8])

        end else iLb = 0;
        if(op == 6'b100001) begin
            validInstruction = `ENABLE;
            iLh = 1;
            aluA = rsVal;
            aluB = extender16SVal;
            aluModeSel = ALU_UADD;

            dmemEn = `ENABLE;
            //dmemaddr=alur
            rfWAddr = rt;
            rt_willRead = `DISABLE;
            //bytePos = {3'b000, dmemAAddr[1] ^ BigEndianCPU, 1'b0};
            //wd=extend16S_2(dmemAOut[8 * bytePos +: 16])
            
        end else iLh = 0;
        if(op == 6'b100100) begin
            validInstruction = `ENABLE;
            iLbu = 1;
            aluA = rsVal;
            aluB = extender16SVal;
            aluModeSel = ALU_UADD;

            dmemEn = `ENABLE;
            //dmemaddr = alur
            rfWAddr = rt;
            rt_willRead = `DISABLE;
            //bytePos = {3'b000, dmemAAddr[1:0] ^ {2{BigEndianCPU}}};
            //wd=extend8U(dmemAOut[8 * bytePos +: 8])
            
        end else iLbu = 0;
        if(op == 6'b100101) begin
            validInstruction = `ENABLE;
            iLhu = 1;
            aluA = rsVal;
            aluB = extender16SVal;
            aluModeSel = ALU_UADD;

            dmemEn = `ENABLE;
            //dmemaddr=alur
            rfWAddr = rt;
            rt_willRead = `DISABLE;
            //bytePos = {3'b000, dmemAAddr[1] ^ BigEndianCPU, 1'b0};
            //wd=extend16U(dmemAOut[8 * bytePos +: 16])
        end else iLhu = 0;

        if(op == 6'b101000) begin
            validInstruction = `ENABLE;
            iSb = 1;
            aluA = rsVal;
            aluB = extender16SVal;
            aluModeSel = ALU_UADD;

            rfWe = `DISABLE;
            dmemEn = `ENABLE;
            //dmemaddr=alur
            dmemWe = 4'hf;
            // dmemWe will be masked later in exec
            // dmemWe &= ((4'h1) << {6'h0, bytePos[1:0]})

            //bytePos = {3'b000, dmemAAddr[1:0] ^ {2{BigEndianCPU}} };
            //dmemin=rtVal << ({6'h0, bytePos[1:0]} << 3)
        end else iSb = 0;
        if(op == 6'b101001) begin
            validInstruction = `ENABLE;
            iSh = 1;
            aluA = rsVal;
            aluB = extender16SVal;
            aluModeSel = ALU_UADD;
            
            rfWe = `DISABLE;
            dmemEn = `ENABLE;
            //dmemaddr=alur
            dmemWe = 4'hf;
            // dmemWe will be masked later in exec
            // dmemWe &= ((4'b0011) << ({7'h0,bytePos[1]} << 1) )
            
            // bytePos = {3'b000, dmemAAddr[1] ^ BigEndianCPU, 1'b0};
            // dmemin=rtVal << (bytePos[1] ? 16 : 0)
        end else iSh = 0;

        if(op == 6'b000000 && func == 6'b001101) begin
            validInstruction = `ENABLE;
            iBreak = 1;
            rfWe = `DISABLE;
            aluA = 0;
            aluB = 0;
            condJump = `ENABLE;
            npc = npc_cp0;
            rs_willRead = `DISABLE;
            rt_willRead = `DISABLE;
        end else iBreak = 0;
        if(inst == 32'b000000_00000_00000_00000_00000_001100) begin
            validInstruction = `ENABLE;
            iSyscall = 1;
            syscallFuncCode = rsVal[7:0];  //Êµ¼ÊÎª R[2]
            rfWe = `DISABLE;
            aluA = 0;
            aluB = 0;
            condJump = `ENABLE;
            npc = npc_cp0;
            rs_willRead = `ENABLE;
            rt_willRead = `DISABLE;
        end else iSyscall = 0;
        if(inst == 32'h42000018) begin
            validInstruction = `ENABLE;
            iEret = 1;
            rfWe = `DISABLE;
            aluA = 0;
            aluB = 0;
            condJump = `ENABLE;
            npc = iretpc_cp0;
            rs_willRead = `DISABLE;
            rt_willRead = `DISABLE;
        end else iEret = 0;

        if(op == 6'b000000 && rt == 5'h0 && func == 6'b010000) begin
            validInstruction = `ENABLE;
            iMfhi = 1;
            aluA = 0;
            aluB = 0;
            rfWAddr = rd;
            rs_willRead = `DISABLE;
            rt_willRead = `DISABLE;
            //wd=hi
        end else iMfhi = 0;
        if(op == 6'b000000 && rt == 5'h0 && func == 6'b010010) begin
            validInstruction = `ENABLE;
            iMflo = 1;
            aluA = 0;
            aluB = 0;
            rfWAddr = rd;
            rs_willRead = `DISABLE;
            rt_willRead = `DISABLE;
            //wd=lo
        end else iMflo = 0;

        if(op == 6'b000000 && rd == 5'h0 && rt == 5'h0 && func == 6'b010001) begin
            validInstruction = `ENABLE;
            iMthi = 1;
            rfWe = `DISABLE;
            aluA = rsVal;
            aluB = 0;
            aluModeSel = aluModeSel;
            rt_willRead = `DISABLE;
            //no wd
        end else iMthi = 0;
        if(op == 6'b000000 && rd == 5'h0 && rt == 5'h0 && func == 6'b010011) begin
            validInstruction = `ENABLE;
            iMtlo = 1;
            rfWe = `DISABLE;
            aluA = rsVal;
            aluB = 0;
            aluModeSel = aluModeSel;
            //no wd
            rt_willRead = `DISABLE;
            //nextlo = rsVal
        end else iMtlo = 0;

        if(op == 6'b010000 && rs == 5'b00000 && inst[10:3] == 8'h00) begin
            validInstruction = `ENABLE;
            iMfc0 = 1;
            aluA = 0;
            aluB = 0;
            rfWAddr = rt;
            rs_willRead = `DISABLE;
            rt_willRead = `DISABLE;
            //wd=cp0[rd]
        end else iMfc0 = 0;
        if(op == 6'b010000 && rs == 5'b00100 && inst[10:3] == 8'h00) begin
            validInstruction = `ENABLE;
            iMtc0 = 1;
            rfWe = `DISABLE;
            aluA = rtVal;
            aluB = 0;
            aluModeSel = aluModeSel;
            rs_willRead = `DISABLE;
            //no wd
            //cp0[rd] = rtVal
        end else iMtc0 = 0;

        if(op == 6'b011100 && func == 6'b100000) begin
            validInstruction = `ENABLE;
            iClz = 1;
            aluModeSel = ALU_CLZ;
            rfWAddr = rd;
            //wd=alur
            rt_willRead = `DISABLE;
        end else iClz = 0;
        if(op == 6'b000000 && func == 6'b110100) begin
            validInstruction = `ENABLE;
            iTeq = 1;
            aluA = 0;
            aluB = 0;
            rfWe = `DISABLE;
            condJump = rsVal == rtVal;
            npc = (rsVal == rtVal) ? (npc_cp0) : pcPlus4;
            //no wd
        end else iTeq = 0;

        if (!validInstruction) begin
            aluModeSel = 0;  // AND
            condJump = `DISABLE;
            rfWe = `DISABLE;
            dmemWe = 0;
            rfWAddr = 0;
            aluA = 0;
            aluB = 0;
            npc = pcPlus4;
            dmemEn = `DISABLE;
            rs_willRead = `DISABLE;
            rt_willRead = `DISABLE;
        end
    end

endmodule

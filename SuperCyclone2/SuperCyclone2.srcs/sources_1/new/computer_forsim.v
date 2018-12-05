`timescale 1ns/1ns
`include "sdHeader.vh"

`define IMEM_ADDRBITS 10
`define DMEM_ADDRBITS 10
`define IMEM_ADDRSLICE (`IMEM_ADDRBITS + 2 - 1):2
`define DMEM_ADDRSLICE (`DMEM_ADDRBITS + 2 - 1):2
`define IMEM_ADDRSLICE_NOOFFSET (`IMEM_ADDRBITS - 1):0
`define DMEM_ADDRSLICE_NOOFFSET (`DMEM_ADDRBITS - 1):0


module computer_forsim(
    input clk_in,
    input reset,
    input cpuEna,

    output clk_cpu,
    output [31:0] inst,
    output [31:0] pc,
    output [31:0] addr,

    output cpuRunning,
    output cpuPaused
);
    //////////////////
    /// Clock generator
    
    clk_generator clkgen_inst(
        .clk_100MHz(clk_in),
        .clk_vga(clk_vga),
        .clk_cpu(clk_cpu)
    );

    ////////////////
    /// DMEM
    /// Port A: Work at falling edge of clk.
    /// Port B: Work at rising edge of clk.
    wire knWorking = `False;

    wire dmemAEn;
    
    wire [3:0] dmemAWe;
    wire [31:0] dmemAAddr;
    wire [31:0] dmemAIn;
    wire [31:0] dmemAOut;

    /////////
    /// DMEM Address Mapper
    wire [31:0] dmemARealAddr = dmemAAddr - 32'h10010000;

    // DMEM
    assign addr = dmemAEn ? dmemAAddr : 32'hFFFFFFFF;

    wire [31:0] dmemDoutb;

    DMEM dmem (
        .clka(clk_cpu),    // input wire clka
        .ena(dmemAEn),      // input wire ena
        .wea(dmemAWe),      // input wire [3 : 0] wea
        .addra(dmemARealAddr[`DMEM_ADDRSLICE]),
        .dina(dmemAIn),    // input wire [31 : 0] dina
        .douta(dmemAOut),   // output wire [31 : 0] douta
        .clkb(clk_in),
        .web(4'h0),
        .addrb(10'h0),
        .dinb('hx),
        .doutb(dmemDoutb)
    );

    //////////////
    /// IMEM
    ///
    wire imemWe;
    wire [31:0] imemRAddr;
    wire [31:0] imemOut;

    wire [31:0] imemWAddr;

    wire [31:0] imemWData;

    wire [31:0] imemSelectedAddr = imemWe ? imemWAddr : imemRAddr;
    wire [31:0] imemRealAddr = imemSelectedAddr - 32'h00400000;
    
    wire [31:0] dmemDpo;

    IMEM imem (
        .a(imemRealAddr[`IMEM_ADDRSLICE]),
        .d(imemWData),
        .dpra(10'h0),
        .clk(clk_cpu),
        .we(imemWe),
        .spo(imemOut),
        .dpo(dmemDpo)
    );

    //////////////
    /// CPU Instantiation
    assign pc = imemRAddr;
    assign inst = imemOut;
    wire [7:0] cpuSyscallFuncCode;
    wire [4:0] rfRAddr1_kn;
    wire [31:0] rfRData1;
    wire [31:0] debugRFData;

    Supercyclone sccpu(
        .clk(clk_cpu),
        .reset(reset),
        .ena(cpuEna),
        .dmemAEn(dmemAEn),
        .dmemAWe(dmemAWe),
        .dmemAAddr(dmemAAddr),
        .dmemAIn(dmemAIn),
        .dmemAOut(dmemAOut),
        .inst(imemOut),
        .cpuRunning(cpuRunning),
        .cpuPaused(cpuPaused),
        .pc(imemRAddr),
        .imemWAddr(imemWAddr),
        .imemWData(imemWData),
        .imemWe(imemWe),
        .debugRFAddr(5'h0),
        .debugRFData(debugRFData),
        .syscallFuncCode(cpuSyscallFuncCode),
        .rfRAddr1_kn(rfRAddr1_kn),
        .rfRData1(rfRData1),
        .knWorking(knWorking)
    );
endmodule
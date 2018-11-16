`timescale 1ns / 1ps
`include "sdHeader.vh"

module cpu_boardtest(
    input CLK100MHZ,
    input BTNL,
    input BTNR,
    input BTNU,
    input BTNC,
    input [15:0] SW,
    output [15:0] LED,
    output [7:0] AN,
    output [7:0] C,
    output [3:0] VGA_R,
    output [3:0] VGA_G,
    output [3:0] VGA_B,
    output VGA_HS,
    output VGA_VS
);

    wire clk_cpu;
    wire reset_deJittered;
    wire storeCpuConfig_deJittered;
    wire storeInput_deJittered;
    reg [2:0] reset_deJitter;
    reg [2:0] storeCpuConfig_deJitter;
    reg [2:0] storeInput_deJitter;
    wire [31:0] instruction;
    wire [31:0] pc;
    wire [31:0] addr;
    wire cpuRunning;
    wire [31:0] debugDMEMData;
    wire [31:0] debugIMEMData;
    wire [31:0] debugRFData;
    wire [31:0] sevenSegOut_cpu;
    reg [15:0] SW_stored_cpuConfig;
    reg [15:0] SW_stored_input;
    
    assign LED[0] = cpuRunning;
    assign LED[1] = reset_deJittered;
    assign LED[2] = storeCpuConfig_deJittered;
    assign LED[3] = storeInput_deJittered;

    always @(posedge CLK100MHZ)
    begin
        reset_deJitter <= {reset_deJitter[1:0], BTNC};
        storeCpuConfig_deJitter <= {storeCpuConfig_deJitter[1:0], BTNL};
        storeInput_deJitter <= {storeInput_deJitter[1:0], BTNR};

    end

    assign reset_deJittered = (reset_deJitter == 3'b111);
    assign storeCpuConfig_deJittered = (storeCpuConfig_deJitter == 3'b111);
    assign storeInput_deJittered = (storeInput_deJitter == 3'b111);

    always @(posedge CLK100MHZ)
    begin
        if(storeCpuConfig_deJittered) begin
            SW_stored_cpuConfig <= SW;
        end
        if(storeInput_deJittered) begin
            SW_stored_input <= SW;
        end
    end


    computer computer_uut(
        .clk_in(CLK100MHZ),
        .reset(reset_deJittered),
        .cpuEna(SW_stored_cpuConfig[0]),
        .ioSelEna(SW_stored_cpuConfig[2]),
        .debugDMEMAddr({5'h0, SW[15:8]}),
        .debugIMEMAddr({5'h0, SW[15:8]}),
        .debugRFAddr(SW[12:8]),
        .SW_stored_input(SW_stored_input),

        .clk_cpu(clk_cpu),
        .inst(instruction),
        .pc(pc),
        .addr(addr),
        .cpuRunning(cpuRunning),
        .debugDMEMData(debugDMEMData),
        .debugIMEMData(debugIMEMData),
        .debugRFData(debugRFData),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_VS(VGA_VS),
        .VGA_HS(VGA_HS),
        .sevenSegOut(sevenSegOut_cpu)
    );

    wire latch_n = SW[1];

    reg [31:0] instruction_reg [0:7];
    reg [31:0] pc_reg [0:7];

    always @(posedge clk_cpu)
    begin
        if (reset_deJittered) begin
            instruction_reg[7] <= 0;
            instruction_reg[6] <= 0;
            instruction_reg[5] <= 0;
            instruction_reg[4] <= 0;
            instruction_reg[3] <= 0;
            instruction_reg[2] <= 0;
            instruction_reg[1] <= 0;
            instruction_reg[0] <= 0;

            pc_reg[7] <= 0;
            pc_reg[6] <= 0;
            pc_reg[5] <= 0;
            pc_reg[4] <= 0;
            pc_reg[3] <= 0;
            pc_reg[2] <= 0;
            pc_reg[1] <= 0;
            pc_reg[0] <= 0;
        end else begin
            if (~latch_n) begin
                if(pc_reg[0] != pc) begin
                    pc_reg[7] <= pc_reg[6];
                    pc_reg[6] <= pc_reg[5];
                    pc_reg[5] <= pc_reg[4];
                    pc_reg[4] <= pc_reg[3];
                    pc_reg[3] <= pc_reg[2];
                    pc_reg[2] <= pc_reg[1];
                    pc_reg[1] <= pc_reg[0];
                    pc_reg[0] <= pc;

                    instruction_reg[7] <= instruction_reg[6];
                    instruction_reg[6] <= instruction_reg[5];
                    instruction_reg[5] <= instruction_reg[4];
                    instruction_reg[4] <= instruction_reg[3];
                    instruction_reg[3] <= instruction_reg[2];
                    instruction_reg[2] <= instruction_reg[1];
                    instruction_reg[1] <= instruction_reg[0];
                    instruction_reg[0] <= instruction;
                end
            end
        end
    end

    reg [31:0] sevenSegOut;

    always @(posedge clk_cpu)
    begin
        case (SW[5:3])
            0:
                sevenSegOut = pc_reg[SW[10:8]];
            1:
                sevenSegOut = sevenSegOut_cpu;
            2:
                sevenSegOut = debugDMEMData;
            3:
                sevenSegOut = debugRFData;
            4:
                sevenSegOut = {16'h0, SW_stored_cpuConfig};
            5:
                sevenSegOut = {16'h0, SW_stored_input};
            default:
                sevenSegOut = 'hFFFFFFFF;
        endcase
    end
    

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


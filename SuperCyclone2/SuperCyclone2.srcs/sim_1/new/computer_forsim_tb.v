`timescale 1ns / 1ps

module computer_forsim_tb(

    );
    
    reg clk_in = 0;
    reg reset = 0;
    reg cpuEna = 0;
    
    wire clk_cpu;
    wire [31:0] inst;
    wire [31:0] pc;
    wire [31:0] addr;

    wire cpuRunning;
    wire cpuPaused;

    always begin
        #5 clk_in = ~clk_in;
    end

    initial begin
        #3 reset = 1;
        #5 reset = 0;
        cpuEna = 1;
    end

    computer_forsim uut(
        clk_in,
        reset,
        cpuEna,
        clk_cpu,
        inst,
        pc,
        addr,
        cpuRunning,
        cpuPaused
    );

    wire clk_a;
    wire clk_b;
    clk_generator clkgen_uut(
        .clk_100MHz(clk_in),
        .clk_vga(clk_a),
        .clk_cpu(clk_b)
    );

endmodule

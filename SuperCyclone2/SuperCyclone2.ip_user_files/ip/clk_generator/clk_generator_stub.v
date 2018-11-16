// Copyright 1986-2016 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2016.2 (win64) Build 1577090 Thu Jun  2 16:32:40 MDT 2016
// Date        : Fri Nov 16 16:02:18 2018
// Host        : SHUN-LAPTOP running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/clk_generator/clk_generator_stub.v
// Design      : clk_generator
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tcsg324-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module clk_generator(clk_100MHz, clk_vga, clk_cpu)
/* synthesis syn_black_box black_box_pad_pin="clk_100MHz,clk_vga,clk_cpu" */;
  input clk_100MHz;
  output clk_vga;
  output clk_cpu;
endmodule

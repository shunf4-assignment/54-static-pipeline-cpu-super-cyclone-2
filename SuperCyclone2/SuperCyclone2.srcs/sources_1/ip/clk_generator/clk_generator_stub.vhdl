-- Copyright 1986-2016 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2016.2 (win64) Build 1577090 Thu Jun  2 16:32:40 MDT 2016
-- Date        : Fri Nov 16 16:02:18 2018
-- Host        : SHUN-LAPTOP running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/clk_generator/clk_generator_stub.vhdl
-- Design      : clk_generator
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a100tcsg324-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clk_generator is
  Port ( 
    clk_100MHz : in STD_LOGIC;
    clk_vga : out STD_LOGIC;
    clk_cpu : out STD_LOGIC
  );

end clk_generator;

architecture stub of clk_generator is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk_100MHz,clk_vga,clk_cpu";
begin
end;

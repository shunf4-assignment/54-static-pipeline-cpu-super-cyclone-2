-makelib ies/xil_defaultlib -sv \
  "D:/SoftPath/Xilinx/Vivado/2016.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
-endlib
-makelib ies/xpm \
  "D:/SoftPath/Xilinx/Vivado/2016.2/data/ip/xpm/xpm_VCOMP.vhd" \
-endlib
-makelib ies/xil_defaultlib \
  "../../../../SuperCyclone2.srcs/sources_1/ip/clk_generator/clk_generator_clk_wiz.v" \
  "../../../../SuperCyclone2.srcs/sources_1/ip/clk_generator/clk_generator.v" \
-endlib
-makelib ies/xil_defaultlib \
  glbl.v
-endlib


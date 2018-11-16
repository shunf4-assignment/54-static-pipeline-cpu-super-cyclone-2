proc start_step { step } {
  set stopFile ".stop.rst"
  if {[file isfile .stop.rst]} {
    puts ""
    puts "*** Halting run - EA reset detected ***"
    puts ""
    puts ""
    return -code error
  }
  set beginFile ".$step.begin.rst"
  set platform "$::tcl_platform(platform)"
  set user "$::tcl_platform(user)"
  set pid [pid]
  set host ""
  if { [string equal $platform unix] } {
    if { [info exist ::env(HOSTNAME)] } {
      set host $::env(HOSTNAME)
    }
  } else {
    if { [info exist ::env(COMPUTERNAME)] } {
      set host $::env(COMPUTERNAME)
    }
  }
  set ch [open $beginFile w]
  puts $ch "<?xml version=\"1.0\"?>"
  puts $ch "<ProcessHandle Version=\"1\" Minor=\"0\">"
  puts $ch "    <Process Command=\".planAhead.\" Owner=\"$user\" Host=\"$host\" Pid=\"$pid\">"
  puts $ch "    </Process>"
  puts $ch "</ProcessHandle>"
  close $ch
}

proc end_step { step } {
  set endFile ".$step.end.rst"
  set ch [open $endFile w]
  close $ch
}

proc step_failed { step } {
  set endFile ".$step.error.rst"
  set ch [open $endFile w]
  close $ch
}

set_msg_config -id {HDL 9-1061} -limit 100000
set_msg_config -id {HDL 9-1654} -limit 100000

start_step init_design
set rc [catch {
  create_msg_db init_design.pb
  set_param xicom.use_bs_reader 1
  set_param simulator.modelsimInstallPath D:/SoftPath/modelsim/win64
  create_project -in_memory -part xc7a100tcsg324-1
  set_property board_part digilentinc.com:nexys4_ddr:part0:1.1 [current_project]
  set_property design_mode GateLvl [current_fileset]
  set_param project.singleFileAddWarning.threshold 0
  set_property webtalk.parent_dir D:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.cache/wt [current_project]
  set_property parent.project_path D:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.xpr [current_project]
  set_property ip_repo_paths d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.cache/ip [current_project]
  set_property ip_output_repo d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.cache/ip [current_project]
  set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY} [current_project]
  add_files -quiet D:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.runs/synth_1/topmodule.dcp
  add_files -quiet d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/clk_generator/clk_generator.dcp
  set_property netlist_only true [get_files d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/clk_generator/clk_generator.dcp]
  add_files -quiet d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/root_cluster/root_cluster.dcp
  set_property netlist_only true [get_files d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/root_cluster/root_cluster.dcp]
  add_files -quiet d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/DMEM/DMEM.dcp
  set_property netlist_only true [get_files d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/DMEM/DMEM.dcp]
  add_files -quiet d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/IMEM/IMEM.dcp
  set_property netlist_only true [get_files d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/IMEM/IMEM.dcp]
  read_xdc -mode out_of_context -ref clk_generator -cells inst d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/clk_generator/clk_generator_ooc.xdc
  set_property processing_order EARLY [get_files d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/clk_generator/clk_generator_ooc.xdc]
  read_xdc -prop_thru_buffers -ref clk_generator -cells inst d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/clk_generator/clk_generator_board.xdc
  set_property processing_order EARLY [get_files d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/clk_generator/clk_generator_board.xdc]
  read_xdc -ref clk_generator -cells inst d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/clk_generator/clk_generator.xdc
  set_property processing_order EARLY [get_files d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/clk_generator/clk_generator.xdc]
  read_xdc -mode out_of_context -ref root_cluster -cells U0 d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/root_cluster/root_cluster_ooc.xdc
  set_property processing_order EARLY [get_files d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/root_cluster/root_cluster_ooc.xdc]
  read_xdc -mode out_of_context -ref DMEM -cells U0 d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/DMEM/DMEM_ooc.xdc
  set_property processing_order EARLY [get_files d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/DMEM/DMEM_ooc.xdc]
  read_xdc -mode out_of_context -ref IMEM -cells U0 d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/IMEM/IMEM_ooc.xdc
  set_property processing_order EARLY [get_files d:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/sources_1/ip/IMEM/IMEM_ooc.xdc]
  read_xdc D:/Projects/CompStruct/SuperCyclone2/SuperCyclone2.srcs/constrs_1/new/supercyclone_top.xdc
  link_design -top topmodule -part xc7a100tcsg324-1
  write_hwdef -file topmodule.hwdef
  close_msg_db -file init_design.pb
} RESULT]
if {$rc} {
  step_failed init_design
  return -code error $RESULT
} else {
  end_step init_design
}

start_step place_design
set rc [catch {
  create_msg_db place_design.pb
  implement_debug_core 
  place_design 
  write_checkpoint -force topmodule_placed.dcp
  report_io -file topmodule_io_placed.rpt
  report_utilization -file topmodule_utilization_placed.rpt -pb topmodule_utilization_placed.pb
  report_control_sets -verbose -file topmodule_control_sets_placed.rpt
  close_msg_db -file place_design.pb
} RESULT]
if {$rc} {
  step_failed place_design
  return -code error $RESULT
} else {
  end_step place_design
}

start_step route_design
set rc [catch {
  create_msg_db route_design.pb
  route_design 
  write_checkpoint -force topmodule_routed.dcp
  report_drc -file topmodule_drc_routed.rpt -pb topmodule_drc_routed.pb
  report_timing_summary -warn_on_violation -max_paths 10 -file topmodule_timing_summary_routed.rpt -rpx topmodule_timing_summary_routed.rpx
  report_power -file topmodule_power_routed.rpt -pb topmodule_power_summary_routed.pb -rpx topmodule_power_routed.rpx
  report_route_status -file topmodule_route_status.rpt -pb topmodule_route_status.pb
  report_clock_utilization -file topmodule_clock_utilization_routed.rpt
  close_msg_db -file route_design.pb
} RESULT]
if {$rc} {
  step_failed route_design
  return -code error $RESULT
} else {
  end_step route_design
}

start_step write_bitstream
set rc [catch {
  create_msg_db write_bitstream.pb
  catch { write_mem_info -force topmodule.mmi }
  write_bitstream -force topmodule.bit 
  catch { write_sysdef -hwdef topmodule.hwdef -bitfile topmodule.bit -meminfo topmodule.mmi -file topmodule.sysdef }
  catch {write_debug_probes -quiet -force debug_nets}
  close_msg_db -file write_bitstream.pb
} RESULT]
if {$rc} {
  step_failed write_bitstream
  return -code error $RESULT
} else {
  end_step write_bitstream
}


# TCL File Generated by Component Editor 20.1
# Sun Aug 14 14:47:33 CEST 2022
# DO NOT MODIFY


# 
# ZworkAvalon "ZworkAvalon" v1.0
# zorkzorkus 2022.08.14.14:47:33
# Multicycle No-Pipeline RV32IMCsr RISC-V Core
# 

# 
# request TCL package from ACDS 16.1
# 
package require -exact qsys 16.1


# 
# module ZworkAvalon
# 
set_module_property DESCRIPTION "Multicycle No-Pipeline RV32IMCsr RISC-V Core"
set_module_property NAME ZworkAvalon
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property GROUP RISC-V
set_module_property AUTHOR zorkzorkus
set_module_property DISPLAY_NAME ZworkAvalon
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL ZworkAvalon
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file ZworkAvalon.vhd VHDL PATH ZworkAvalon.vhd TOP_LEVEL_FILE
add_fileset_file ZworkCore.vhd VHDL PATH ZworkCore.vhd
add_fileset_file ZworkDivider.vhd VHDL PATH ZworkDivider.vhd
add_fileset_file ZworkUtil.vhd VHDL PATH ZworkUtil.vhd
add_fileset_file ZworkRegister.vhd VHDL PATH ZworkRegister.vhd


# 
# parameters
# 
add_parameter g_reset_vector STD_LOGIC_VECTOR 16 "Address of the first instruction after reset or power-up."
set_parameter_property g_reset_vector DEFAULT_VALUE 16
set_parameter_property g_reset_vector DISPLAY_NAME g_reset_vector
set_parameter_property g_reset_vector WIDTH 32
set_parameter_property g_reset_vector TYPE STD_LOGIC_VECTOR
set_parameter_property g_reset_vector UNITS None
set_parameter_property g_reset_vector ALLOWED_RANGES 0:4294967295
set_parameter_property g_reset_vector DESCRIPTION "Address of the first instruction after reset or power-up."
set_parameter_property g_reset_vector HDL_PARAMETER true
add_parameter g_mtvec STD_LOGIC_VECTOR 32 "Initial address of the exception vector"
set_parameter_property g_mtvec DEFAULT_VALUE 32
set_parameter_property g_mtvec DISPLAY_NAME g_mtvec
set_parameter_property g_mtvec WIDTH 32
set_parameter_property g_mtvec TYPE STD_LOGIC_VECTOR
set_parameter_property g_mtvec UNITS None
set_parameter_property g_mtvec ALLOWED_RANGES 0:4294967295
set_parameter_property g_mtvec DESCRIPTION "Initial address of the exception vector"
set_parameter_property g_mtvec HDL_PARAMETER true


# 
# display items
# 


# 
# connection point clock
# 
add_interface clock clock end
set_interface_property clock clockRate 0
set_interface_property clock ENABLED true
set_interface_property clock EXPORT_OF ""
set_interface_property clock PORT_NAME_MAP ""
set_interface_property clock CMSIS_SVD_VARIABLES ""
set_interface_property clock SVD_ADDRESS_GROUP ""

add_interface_port clock clk clk Input 1


# 
# connection point avalon_master
# 
add_interface avalon_master avalon start
set_interface_property avalon_master addressUnits SYMBOLS
set_interface_property avalon_master associatedClock clock
set_interface_property avalon_master associatedReset reset_sink
set_interface_property avalon_master bitsPerSymbol 8
set_interface_property avalon_master burstOnBurstBoundariesOnly false
set_interface_property avalon_master burstcountUnits WORDS
set_interface_property avalon_master doStreamReads false
set_interface_property avalon_master doStreamWrites false
set_interface_property avalon_master holdTime 0
set_interface_property avalon_master linewrapBursts false
set_interface_property avalon_master maximumPendingReadTransactions 0
set_interface_property avalon_master maximumPendingWriteTransactions 0
set_interface_property avalon_master readLatency 0
set_interface_property avalon_master readWaitTime 1
set_interface_property avalon_master setupTime 0
set_interface_property avalon_master timingUnits Cycles
set_interface_property avalon_master writeWaitTime 0
set_interface_property avalon_master ENABLED true
set_interface_property avalon_master EXPORT_OF ""
set_interface_property avalon_master PORT_NAME_MAP ""
set_interface_property avalon_master CMSIS_SVD_VARIABLES ""
set_interface_property avalon_master SVD_ADDRESS_GROUP ""

add_interface_port avalon_master mm_addr address Output 32
add_interface_port avalon_master mm_byten byteenable Output 4
add_interface_port avalon_master mm_rdata readdata Input 32
add_interface_port avalon_master mm_read read Output 1
add_interface_port avalon_master mm_waitrequest waitrequest Input 1
add_interface_port avalon_master mm_wdata writedata Output 32
add_interface_port avalon_master mm_write write Output 1


# 
# connection point interrupt_receiver
# 
add_interface interrupt_receiver interrupt start
set_interface_property interrupt_receiver associatedAddressablePoint ""
set_interface_property interrupt_receiver associatedClock clock
set_interface_property interrupt_receiver associatedReset reset_sink
set_interface_property interrupt_receiver irqScheme INDIVIDUAL_REQUESTS
set_interface_property interrupt_receiver ENABLED true
set_interface_property interrupt_receiver EXPORT_OF ""
set_interface_property interrupt_receiver PORT_NAME_MAP ""
set_interface_property interrupt_receiver CMSIS_SVD_VARIABLES ""
set_interface_property interrupt_receiver SVD_ADDRESS_GROUP ""

add_interface_port interrupt_receiver interrupt irq Input 32


# 
# connection point reset_sink
# 
add_interface reset_sink reset end
set_interface_property reset_sink associatedClock clock
set_interface_property reset_sink synchronousEdges DEASSERT
set_interface_property reset_sink ENABLED true
set_interface_property reset_sink EXPORT_OF ""
set_interface_property reset_sink PORT_NAME_MAP ""
set_interface_property reset_sink CMSIS_SVD_VARIABLES ""
set_interface_property reset_sink SVD_ADDRESS_GROUP ""

add_interface_port reset_sink resetn reset_n Input 1

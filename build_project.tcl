# Ricrea il progetto Vivado da zero a partire dai sorgenti di questa cartella.
# Uso dalla Tcl console di Vivado:
#   cd C:/Users/MNS/Desktop/FPGA_FOG_open_loop_200KHz_src
#   source build_project.tcl
#
# Struttura:
#   rtl/     moduli RTL (module reference dei block design)
#   mem/     LUT del seno (lut_sin.mem letta da sin_gen.v con $readmemh)
#   constr/  vincoli Red Pitaya
#   sim/     testbench
#   bd/      block design esportati con write_bd_tcl (uno .tcl per design)

set root      [file dirname [file normalize [info script]]]
set proj_name FPGA_open_loop_200KHz
set proj_dir  $root/vivado
set part      xc7z020clg400-1
# Block design da usare come top (nome del wrapper)
set top_wrapper open_loop_200KHz_square_wrapper

create_project $proj_name $proj_dir -part $part -force
set_property target_language Verilog [current_project]

# Sorgenti
add_files -norecurse [glob $root/rtl/*.v $root/rtl/*.vhd]
add_files -norecurse $root/mem/lut_sin.mem
add_files -fileset constrs_1 -norecurse [glob $root/constr/*.xdc]
add_files -fileset sim_1 -norecurse [glob $root/sim/*.v]
set_property top tb_square [get_filesets sim_1]
update_compile_order -fileset sources_1

# Block design + wrapper
foreach bd_tcl [glob -nocomplain $root/bd/*.tcl] {
    source $bd_tcl
    set bd_file [get_files [current_bd_design].bd]
    validate_bd_design
    save_bd_design
    close_bd_design [current_bd_design]
    add_files -norecurse [make_wrapper -files $bd_file -top]
}

if {[llength [get_files -quiet $top_wrapper.v]]} {
    set_property top $top_wrapper [current_fileset]
}
update_compile_order -fileset sources_1
puts "Progetto creato in $proj_dir (top: [get_property top [current_fileset]])"

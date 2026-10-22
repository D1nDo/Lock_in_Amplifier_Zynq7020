# Riesporta i block design del progetto in bd/*.tcl.
# Da lanciare dopo aver modificato i BD nel progetto generato da build_project.tcl,
# così le modifiche finiscono nel repository (la cartella vivado/ non è versionata).
# Uso dalla Tcl console di Vivado, con il progetto aperto:
#   source <percorso del repository>/export_bd.tcl

set root [file dirname [file normalize [info script]]]
file mkdir $root/bd

foreach bd_file [get_files -quiet *.bd] {
    set name [file rootname [file tail $bd_file]]
    open_bd_design $bd_file
    validate_bd_design
    save_bd_design
    write_bd_tcl -force -no_ip_version $root/bd/$name.tcl
    close_bd_design [current_bd_design]
    puts "Esportato: $root/bd/$name.tcl"
}

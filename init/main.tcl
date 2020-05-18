set header "# File created using tekyll: https://github.com/lawrencewoodman/tekyll\n\n"
set mainTcl [read -directory [dir root] main.tcl]
set uncommentedOrnamentText [regsub -line -all {^#>(.*)$} $mainTcl {\1}]
set sblasmTcl $header
append sblasmTcl [ornament $uncommentedOrnamentText]
write [file join [dir build] sblasm.tcl] $sblasmTcl

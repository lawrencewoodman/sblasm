set header "# File created using tekyll: https://github.com/lawrencewoodman/tekyll\n\n"
# TODO: Use header above
set mainTcl [read -directory [dir root] main.tcl]
set uncommentedOrnamentText [regsub -line -all {^#>(.*)$} $mainTcl {\1}]
set subleasmTcl [append $header [ornament $uncommentedOrnamentText]]
write [file join [dir build] subleasm.tcl] $subleasmTcl

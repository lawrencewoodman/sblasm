#! /usr/bin/env tclsh
#
# A SUBLEQ assembler
#
# Copyright (C) 2020 Lawrence Woodman <lwoodman@vlifesystems.com>
# Licensed under an MIT licence.  Please see LICENCE.md for details.


# TODO: Should use $ or . instead of ? for current address?
# TODO: Could use ? for other interesting things.

# TODO: Could use # as sugar to support a constant, where number is put
# TODO: into an address and the #constant is replaced with a pointer to it.
# TODO: This would conflict with comments however could use ;
# TODO:  or / (clash with division) instead for comments.

# TODO: Could use * as sugar to support indirect addressing? May not be
# TODO: a good idea because couldn't easily increment.  Also could
# TODO: conflict with pointer arithmetic. Perhaps use [] instead.

# TODO: Support conditional assembly .ifdef, .ifzero, if nzero, etc
# TODO: With string maps should 0-stringAddr become 0-?-x, where x is the offset

# The lines beginning '#>' will have the '#>' removed if processed by
# tekyll to create a single file, so that those lines can instruct
# ornament what to do.
#>! if 0 {
set ThisScriptDir [file dirname [info script]]
set LibDir [file join $ThisScriptDir lib]
set VendorDir [file join $ThisScriptDir vendor]
source [file join $VendorDir xproc-0.1.tm]
source [file join $LibDir asm.tcl]
#>! }
#>!* commandSubst true
#>[read -directory [dir vendor] xproc-0.1.tm]
#>[read -directory [dir lib] asm.tcl]
#>!* commandSubst false


set debug false

if {$argc != 1} {
  puts stderr "Please supply filename"
  exit 1
}

set filename [lindex $argv 0]


# TODO: Add Error handling
proc readFile {filename} {
  set fp [open $filename r]
  set data [split [read $fp] "\n"]
  close $fp
  return $data
}


set src [readFile $filename]
set asm [assemble $src]
puts $asm

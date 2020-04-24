#! /usr/bin/env tclsh
#
# A SUBLEQ assembler
#
# Copyright (C) 2020 Lawrence Woodman <lwoodman@vlifesystems.com>
# Licensed under an MIT licence.  Please see LICENCE.md for details.


# TODO: Could use # as sugar to support a constant, where number is put
# TODO: into an address and the #constant is replaced with a pointer to it.

# TODO: Could use * as sugar to support indirect addressing? May not be
# TODO: a good idea because couldn't easily increment.  Also could
# TODO: conflict with pointer arithmetic. Perhaps use [] instead.

# TODO: Support conditional assembly .ifdef, .ifzero, if nzero, etc
# TODO: With string maps should 0-stringAddr become 0-?-x, where x is the offset

# The lines beginning '#>' will have the '#>' removed if processed by
# tekyll to create a single file, so that those lines can instruct
# ornament what to do.
# tekyll: https://github.com/lawrencewoodman/tekyll
#>! if 0 {
set ThisScriptDir [file dirname [info script]]
set LibDir [file join $ThisScriptDir lib]
set VendorDir [file join $ThisScriptDir vendor]
source [file join $VendorDir xproc-0.1.tm]
source [file join $LibDir asm.tcl]
source [file join $LibDir file.tcl]
#>! }
#>!* commandSubst true
#>[read -directory [dir vendor] xproc-0.1.tm]
#>[read -directory [dir lib] asm.tcl]
#>[read -directory [dir lib] file.tcl]
#>!* commandSubst false


proc getParams {_args} {
  set cmd [file tail [info script]]
  set usage "Usage: $cmd \[OPTION]... filename
Assemble SUBLEQ assembly from filename

Arguments:
  -l filename      Output a listing to listing to filename
  -h               Display this help and exit
  --               Mark the end of switches
"

  array set params {}
  while {[llength $_args]} {
    switch -glob -- [lindex $_args 0] {
      -l   {
        set params(listingFilename) [lindex $_args 1]
        set _args [lrange $_args 2 end]
      }
      -h   {
        puts $usage
        set _args [lrange $_args 1 end]
        exit 0
      }
      --   {set _args [lrange $_args 1 end] ; break}
      -*   {
        return -code error "Unknown option: [lindex $_args 0]"
      }
      default break
    }
  }
  if {[llength $_args] == 0} {
    return -code error "Please supply filename"
  }
  if {[llength $_args] > 1} {
    return -code error "Too many arguments"
  }
  set params(srcFilename) [lindex $_args 0]
  return [array get params]
}

set cmd [file tail [info script]]

try {
  set params [getParams $argv]
  set srcFilename [dict get $params srcFilename]
  set src [readFile $srcFilename]
} on error {err} {
  puts stderr "$cmd: $err"
  puts stderr "Try '$cmd -h' for more information."
  exit 1
}

lassign [assemble $src] output listing

if {[dict exists $params listingFilename]} {
  try {
    outputListing $listing [dict get $params listingFilename] $srcFilename
  } on error {err} {
    puts stderr "$cmd: $err"
    exit 1
  }
}

puts $output

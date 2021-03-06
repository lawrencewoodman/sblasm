#! /usr/bin/env tclsh
#
# A SUBLEQ assembler
#
# Copyright (C) 2020 Lawrence Woodman <lwoodman@vlifesystems.com>
# Licensed under an MIT licence.  Please see LICENCE.md for details.


# The lines beginning '#>' will have the '#>' removed if processed by
# tekyll to create a single file, so that those lines can instruct
# ornament what to do.
# tekyll: https://github.com/lawrencewoodman/tekyll
#>! if 0 {
set ThisScriptDir [file dirname [info script]]
set LibDir [file join $ThisScriptDir lib]
set VendorDir [file join $ThisScriptDir vendor]
source [file join $VendorDir xproc-0.1.tm]
source [file join $LibDir error.tcl]
source [file join $LibDir lexer.tcl]
source [file join $LibDir parser.tcl]
source [file join $LibDir asm.tcl]
source [file join $LibDir file.tcl]
#>! }
#>!* commandSubst true
#>[read -directory [dir vendor] xproc-0.1.tm]
#>[read -directory [dir lib] error.tcl]
#>[read -directory [dir lib] lexer.tcl]
#>[read -directory [dir lib] parser.tcl]
#>[read -directory [dir lib] asm.tcl]
#>[read -directory [dir lib] file.tcl]
#>!* commandSubst false


proc getParams {_args} {
  set cmd [file tail [info script]]
  set usage "Usage: $cmd \[OPTION]... filename
Assemble SUBLEQ assembly from filename

Arguments:
  -l filename      Output a listing to listing to filename
  -o filename      Output to filename rather than stdout
  -h               Display this help and exit
  --               Mark the end of switches
"

  array set params {}
  while {[llength $_args]} {
    switch -glob -- [lindex $_args 0] {
      -l   {set _args [lassign $_args - params(listingFilename)]}
      -o   {set _args [lassign $_args - params(outputFilename)]}
      -h   {puts $usage; exit 0}
      --   {set _args [lassign $_args -]; break}
      -*   {return -code error "Unknown option: [lindex $_args 0]"}
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


# TODO: Add errors to listing?
proc outputErrors {errors} {
  puts stderr "Errors\n======"
  set lastFilename ""

  set errors [lsort -command errorCompare $errors]
  lassign $errors firstError
  if {[dict exists $firstError lineNum]} {
    foreach err $errors {
      dict with err {
        if {$filename ne $lastFilename} {
          puts stderr "\n$filename"
          puts "[string repeat "-" [string length $filename]]\n"
          puts stderr [format {%4s} "Line"]
          set lastFilename $filename
        }
        puts stderr [format {%4i - %s} $lineNum $line]
        puts stderr [format {%4s | %s} {} $msg]
      }
    }
  } else {
    puts stderr [format {%4s} "Pos"]

    foreach err $errors {
      dict with err {
        puts stderr [format {%4i - %s} $pos $msg]
      }
    }
  }
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

lassign [assemble $srcFilename $src] code listing errors

# Output listing to file if requested
if {[dict exists $params listingFilename] && [llength $listing] > 0} {
  try {
    outputListing $listing [dict get $params listingFilename]
  } on error {err} {
    puts stderr "$cmd: $err"
    exit 1
  }
}

if {[llength $errors] > 0} {
  outputErrors $errors
  exit 1
}


try {
  outputCode $params $code
} on error {err} {
  puts stderr "$cmd: $err"
  exit 1
}

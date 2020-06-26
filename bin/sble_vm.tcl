#! /usr/bin/env tclsh
#
# A simple SUBLEQ VM
#
# Copyright (C) 2020 Lawrence Woodman <lwoodman@vlifesystems.com>
# Licensed under an MIT licence.  Please see LICENCE.md for details.

package require Expect
package require xproc


proc getParams {_args} {
  set cmd [file tail [info script]]
  set usage "Usage: $cmd \[OPTION]... filename
Execute SUBLEQ machine code

Arguments:
  -trace           Trace execution of program
  -word            The word size in bits (default: 0 - unlimited)
  -h               Display this help and exit
  --               Mark the end of switches
"

  array set params {trace false word 0}
  while {[llength $_args]} {
    switch -glob -- [lindex $_args 0] {
      -trace   {set _args [lrange $_args 1 end]; set params(trace) true}
      -word    {set _args [lassign $_args - params(word)]}
      -h   {puts $usage; exit 0}
      --   {set _args [lassign $_args -] ; break}
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
  if {$params(word) < 0} {
    return -code error "Invalid value for -word: $params(word)"
  }
  lassign $_args params(filename)
  return [array get params]
}


proc loadProgram {memory filename word} {
  set fp [open $filename r]
  set data [split [read $fp] " "]
  close $fp

  set minWord [expr {0-(pow(2,$word)/2)}]
  set maxWord [expr {(pow(2,$word)/2)-1}]

  set i 0
  foreach v $data {
    if {$i >= [llength $memory]} {
      return -code error "program exceeds memory size"
    }
    if {$word > 0 && ($v < $minWord || $v > $maxWord)} {
      return -code error "value in program exceeeds word size: $v"
    }
    lset memory $i $v
    incr i
  }
  return $memory
}


proc initMemory {memorySize} {
  for {set i 0} {$i < $memorySize} {incr i} {
    lappend memory 0
  }
  return $memory
}


proc getTrace {memory numInstExecuted pc a b c} {
  append res [format {pc: %5i - sble: %5i %5i %5i  } $pc $a $b $c]
  if {$a >= 0} {
    append res [format {[%i]: %i } $a [lindex $memory $a]]
  }
  if {$b >= 0} {
    append res [format {[%i]: %i} $b [lindex $memory $b]]
  }
  append res "  -  NumExecuted: $numInstExecuted"
  return $res
}


proc run {memory word trace} {
  set preSTTYAttributes [stty]
  stty raw -echo           ; # Used to prevent read stdin echo and line mode

  set OUT -1
  set IN -1
  set HALT -1
  set pc 0
  set isHalt false
  set numInstExecuted 0
  set minWord [expr {0-(pow(2,$word)/2)}]
  set maxWord [expr {(pow(2,$word)/2)-1}]
  while {$pc >= 0} {
    lassign [lrange $memory $pc $pc+2] a b c
    try {
      # TODO: Test to ensure that a, b c are read in one go so that an
      # TODO: alteration to c won't have an effect on this execution
      if {$trace} {
        puts [getTrace $memory $numInstExecuted $pc $a $b $c]
      }
      incr pc 3

      if {$a == $IN} {
        scan [read stdin 1] %c ch
        set aVal $ch
      } else {
        set aVal [lindex $memory $a]
      }

      if {$b == $OUT} {
        puts -nonewline [format %c $aVal]
        # TODO: Work out if flush needed
        flush stdout
      } else {
        if {$a == $IN} {
          set res $aVal
        } else {
          set res [expr {[lindex $memory $b] - $aVal}]
          if {$word > 0} {
            set res [wrapNum $minWord $maxWord $res]
          }
        }
        lset memory $b $res
        if {$res <= 0} {
          set pc $c
        }
      }
    } on error {err} {
      puts stderr "[getTrace $memory $numInstExecuted $pc $a $b $c]\n"
      puts stderr $err
      exit 1
    }
    incr numInstExecuted
  }
  stty {*}$preSTTYAttributes
}


proc wrapNum {min max num} {
  if {$num < $min} {
    return [expr {int($max + ($num - $min) + 1)}]
  } elseif {$num > $max} {
    return [expr {int($min + ($num - $max) - 1)}]
  }
  return $num
}


proc main {_args} {
  set memorySize 5000
  set memory [initMemory $memorySize]

  try {
    set params [getParams $_args]
    set filename [dict get $params filename]
    set memory [loadProgram $memory $filename [dict get $params word]]
  } on error {err} {
    set cmd [file tail [info script]]
    puts stderr "$cmd: $err"
    puts stderr "Try '$cmd -h' for more information."
    exit 1
  }
  run $memory [dict get $params word] [dict get $params trace]
}


main $argv

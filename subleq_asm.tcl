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

package require xproc

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


xproc::proc assemble {src} {
  # TODO: Find better name than result
  lassign [pass1 $src] result constants labels
  set pass2Output [pass2 $result $constants $labels]
  return [pass3 $pass2Output]
} -test {{ns t} {
  # TODO: Add test for label that doesn't exist
  # TODO: Add test for $var not being substituted
  # TODO: Add support for calculations on constants
  set cases [list \
    [dict create \
      filename "helloworld.sq" \
      result [list 16 -1 3 15 0 6 15 10 9 30 16 -1 30 30 0 -1 \
                   72 69 76 76 79 44 32 87 79 82 76 68 33 10 0]]
  ]
  xproc::testCases $t $cases {{ns case} {
    dict with case {
      set src [readFile $filename]
      ${ns}::assemble $src
    }
  }}
}}


proc pass1 {src} {
  set labels [dict create]
  set constants [dict create]
  set pos 0
  set result [list]
  foreach line $src {
    set linePos 0
    while {$linePos < [string length $line]} {
      set linePos [skipWhitespace $line $linePos]
      lassign [getWord $line $linePos] word wordEnd

      if {[isComment $word]} {
        set wordEnd [string length $line]
      } elseif {[isCommand $word]} {
        # TODO: Error check properly and place in separate procs
        switch $word {
          .equ {
            lassign [getWord $line [expr {$wordEnd+1}]] name wordEnd
            lassign [getWord $line [expr {$wordEnd+1}]] val wordEnd
            dict set constants $name $val
          }
          .word {
            while {1} {
              lassign [getWord $line [expr {$wordEnd+1}]] val wordEnd
              if {[isComment $val]} {
                set wordEnd [string length $line]
                break
              }
              if {$val eq ""} {break}
              lappend result $val
              incr pos
            }
          }
          .ascii {
            set start [skipWhitespace $line [expr {$wordEnd+1}]]
            lassign [getString $line $start] charNums wordEnd
            if {[llength $charNums] > 0} {
              lappend result {*}$charNums
              incr pos [llength $charNums]
            }
          }
        }
      } elseif {[isDefineLabel $word]} {
        dict set labels [string trimright $word :] $pos
      } else {
        lassign [getInstruction $word $line [expr {$wordEnd+1}]] \
                instruction wordEnd
        if {[llength $instruction] == 3} {
          lappend result {*}$instruction
          incr pos 3
        }
      }
      set linePos [expr {$wordEnd+1}]
    }
  }
  return [list $result $constants $labels]
}

xproc::proc calcLabelOffsets {pos labels} {
  return [dict map {name labelPos} $labels {
    set offset [expr {$labelPos-$pos}]
    set newX [format {?%+i} $offset]
  }]
}


xproc::proc pass2 {pass1Output constants labels} {
  set pos 0
  return [lmap x $pass1Output {
    set newX $x
    if {![string is integer $x]} {
      set labelOffsets [calcLabelOffsets $pos $labels]
      if {[dict exists $labelOffsets $x]} {
        set newX [dict get $labelOffsets $x]
      } elseif {[dict exists $constants $x]} {
        set newX [dict get $constants $x]
      } else {
        set labelOffsets [sortLabelsByLength $labelOffsets]
        set newX [string map $labelOffsets $x]
      }
    }
    incr pos
    set newX
  }]
} -test {{ns t} {
  # TODO: Add test for label that doesn't exist
  # TODO: Add test for $var not being substituted
  # TODO: Add support for calculations on constants
  set cases {
    { pass1Output {4 2 4 hello 2}
      labels {ell 4 hello 1 ll 3}
      constants {OUT -1}
      result {4 2 4 ?-2 2}}
    { pass1Output {4 2 4 hello+9 2}
      labels {ell 4 hello 1 ll 3}
      constants {}
      result {4 2 4 ?-2+9 2}}
    { pass1Output {4 2 4 ? 2}
      labels {ell 4 hello 1 ll 3}
      constants {}
      result {4 2 4 ? 2}}
    { pass1Output {4 2 4 ?+5 2}
      labels {ell 4 hello 1 ll 3}
      constants {}
      result {4 2 4 ?+5 2}}
    { pass1Output {4 2 4 OUT 2}
      labels {ell 4 hello 1 ll 3}
      constants {OUT -1}
      result {4 2 4 -1 2}}
  }
  xproc::testCases $t $cases {{ns case} {
    dict with case {${ns}::pass2 $pass1Output $constants $labels}
  }}
}}


# Resolve relative addresses to fixed addresses
xproc::proc pass3 {pass2Output} {
  set pos 0
  return [lmap x $pass2Output {
    set newX [expr [list [string map [list ? $pos] $x]]]
    incr pos
    set newX
  }]
}

proc labelCmp {a b} {
  return [expr {[string length $a] < [string length $b]}]
}

proc sortLabelsByLength {labels} {
  return [lsort -stride 2 -command labelCmp $labels]
}


# Get remainder of instruction operands
proc getInstruction {aOp line linePos} {
  if {$aOp eq ""} {return [list {} $linePos]}
  set start [nextWhitespace $line $linePos]
  lassign [getWord $line $start] bOp bEnd
  lassign [getWord $line [expr {$bEnd+1}]] cOp cEnd

  if {$bOp eq "" || [isComment $bOp]} {
    puts stderr "Invalid line: $line"
    return [list {} $linePos]
  }
  if {$cOp eq "" || [isComment $cOp]} {
    set cEnd $bEnd
    set cOp {?+1}
  }
  return [list [list $aOp $bOp $cOp] $cEnd]
}


xproc::proc getString {line linePos} {
  if {[string index $line $linePos] ne "\""} {
    puts stderr "Invalid line: $line"
    return [list "" $linePos]
  }
  set start [expr {$linePos+1}]
  set end [string first "\"" $line $start]
  if {$end == -1} {
    puts stderr "Invalid line: $line"
    return [list "" $linePos]
  }
  set str [string range $line $start [expr {$end-1}]]
  set str [subst -nocommands -novariables $str]
  set chars [split $str ""]
  set nums [lmap ch $chars {scan $ch "%c"}]
  return [list $nums $end]
} -test {{ns t} {
  set cases {
    {line {.ascii "hello"} linePos 7 result {{104 101 108 108 111} 13}}
    {line {.ascii "hello\n"} linePos 7 result {{104 101 108 108 111 10} 15}}
    {line {.ascii ""} linePos 7 result {{} 8}}
  }
  xproc::testCases $t $cases {{ns case} {
    dict with case {${ns}::getString $line $linePos}
  }}
}}


proc skipWhitespace {line pos} {
  if {[regexp -indices -start $pos {[^\s]} $line location]} {
    return [lindex $location 0]
  }
  return [string length $line]
}

proc nextWhitespace {line pos} {
  if {[regexp -indices -start $pos {\s} $line location]} {
    return [lindex $location 0]
  }
  return [string length $line]
}

# Get the next word
# Returns {word end}
proc getWord {line pos} {
  set start [skipWhitespace $line $pos]
  set end [expr {$start-1}]
  for {set i $start} {$i < [string length $line]} {incr i} {
    set ch [string index $line $i]
    if {![string is space $ch]} {
      incr end
    } else {
      break
    }
  }
  set word [string range $line $start $end]
  return [list $word $end]
}


proc isDefineLabel {word} {
  return [string match {?*:} $word]
}


proc isComment {word} {
  return [string match {#*} $word]
}


proc isCommand {word} {
  return [string match {.?*} $word]
}


set src [readFile $filename]
set asm [assemble $src]
puts $asm

# TODO: Put in separate file
xproc::runTests
